import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/app_formatters.dart';
import '../../core/utils/category_catalog.dart';
import '../../data/models/app_budget.dart';
import '../../data/models/app_transaction.dart';
import '../../data/repositories/firebase_auth_error_mapper.dart';
import '../../data/repositories/firestore_repository.dart';
import '../../data/services/gemini_ai_service.dart';

class AiInsightsScreen extends StatefulWidget {
  const AiInsightsScreen({super.key});

  @override
  State<AiInsightsScreen> createState() => _AiInsightsScreenState();
}

class _AiInsightsScreenState extends State<AiInsightsScreen> {
  final _repository = FirestoreRepository();
  final _aiService = GeminiAiService();

  Future<_InsightResult>? _insightsFuture;
  var _isGenerating = false;

  void _generateInsights(
    List<AppTransaction> transactions,
    List<AppBudget> budgets,
  ) {
    if (_isGenerating) return;

    final prompt = _buildExpensePrompt(transactions, budgets);
    final fallback = _buildLocalInsight(transactions, budgets);
    final primaryPrompt = _buildRewritePrompt(
      baseline: fallback,
      originalPrompt: prompt,
    );
    final retryPrompt = _buildRewritePrompt(
      baseline: fallback,
      originalPrompt: _buildExpensePrompt(transactions, budgets, strict: true),
      strict: true,
    );
    final future = _generateGeminiFirst(
      prompt: primaryPrompt,
      retryPrompt: retryPrompt,
      fallback: fallback,
    );

    setState(() {
      _isGenerating = true;
      _insightsFuture = future;
    });

    future.whenComplete(() {
      if (mounted) setState(() => _isGenerating = false);
    });
  }

  Future<_InsightResult> _generateGeminiFirst({
    required String prompt,
    required String retryPrompt,
    required String fallback,
  }) async {
    String? firstText;
    String? retryText;
    try {
      firstText = await _aiService.generateExpenseInsights(
        prompt,
        maxOutputTokens: 2200,
      );
      if (_usefulAiText(firstText, fallback: fallback)) {
        return _InsightResult(
          text: firstText.trim(),
          source: _InsightSource.gemini,
        );
      }
    } catch (_) {
      return _InsightResult(text: fallback, source: _InsightSource.fallback);
    }

    try {
      retryText = await _aiService.generateExpenseInsights(
        retryPrompt,
        maxOutputTokens: 2800,
      );
      if (_usefulAiText(retryText, fallback: fallback)) {
        return _InsightResult(
          text: retryText.trim(),
          source: _InsightSource.gemini,
        );
      }
    } catch (_) {
      if (firstText.trim().isNotEmpty) {
        return _InsightResult(
          text: firstText.trim(),
          source: _InsightSource.gemini,
        );
      }
    }

    final shortText = retryText?.trim().isNotEmpty == true
        ? retryText!.trim()
        : firstText.trim();
    if (shortText.isNotEmpty) {
      try {
        final expandedText = await _aiService.generateExpenseInsights(
          _buildExpandPrompt(retryPrompt, shortText, fallback),
          maxOutputTokens: 3200,
        );
        if (_usefulAiText(expandedText, fallback: fallback)) {
          return _InsightResult(
            text: expandedText.trim(),
            source: _InsightSource.gemini,
          );
        }
      } catch (_) {}
    }

    return _InsightResult(text: fallback, source: _InsightSource.fallback);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          tooltip: 'Quay lại',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
          color: AppColors.onSurfaceVariant,
        ),
        title: Text(
          'AI phân tích',
          style: AppTextStyles.headlineLargeMobile.copyWith(
            color: AppColors.onSurface,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: StreamBuilder<List<AppTransaction>>(
              stream: _repository.watchTransactions(),
              builder: (context, transactionSnapshot) {
                if (transactionSnapshot.connectionState ==
                        ConnectionState.waiting &&
                    !transactionSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (transactionSnapshot.hasError) {
                  return _ErrorState(
                    message: firebaseAuthErrorMessage(
                      transactionSnapshot.error!,
                    ),
                  );
                }

                return StreamBuilder<List<AppBudget>>(
                  stream: _repository.watchBudgets(),
                  builder: (context, budgetSnapshot) {
                    if (budgetSnapshot.connectionState ==
                            ConnectionState.waiting &&
                        !budgetSnapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (budgetSnapshot.hasError) {
                      return _ErrorState(
                        message: firebaseAuthErrorMessage(
                          budgetSnapshot.error!,
                        ),
                      );
                    }

                    final transactions = transactionSnapshot.data ?? [];
                    final budgets = budgetSnapshot.data ?? [];
                    return _AiInsightsBody(
                      transactions: transactions,
                      budgets: budgets,
                      insightsFuture: _insightsFuture,
                      isGenerating: _isGenerating,
                      onGenerate: () =>
                          _generateInsights(transactions, budgets),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _AiInsightsBody extends StatelessWidget {
  const _AiInsightsBody({
    required this.transactions,
    required this.budgets,
    required this.insightsFuture,
    required this.isGenerating,
    required this.onGenerate,
  });

  final List<AppTransaction> transactions;
  final List<AppBudget> budgets;
  final Future<_InsightResult>? insightsFuture;
  final bool isGenerating;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final currentMonthKey = monthKey(now);
    final monthTransactions = transactions
        .where((item) => monthKey(item.transactionDate) == currentMonthKey)
        .toList();
    final monthIncome = _sumByType(monthTransactions, AppTransactionType.income);
    final monthExpense = _sumByType(
      monthTransactions,
      AppTransactionType.expense,
    );
    final monthBalance = monthIncome - monthExpense;
    final savingsRate = monthIncome <= 0
        ? 0.0
        : (monthBalance / monthIncome * 100).clamp(0, 100);
    final categoryTotals = _expenseCategoryTotals(monthTransactions);
    final currentBudgets = budgets
        .where((budget) => budget.periodKey == currentMonthKey)
        .toList();
    final monthlySpent = _monthlyExpenseByCategory(
      transactions,
      currentMonthKey,
    );
    final totalBudget = currentBudgets.fold<int>(
      0,
      (sum, budget) => sum + budget.limitAmount,
    );
    final spentThisMonth = monthlySpent.values.fold<int>(
      0,
      (sum, amount) => sum + amount,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        _HeroCard(
          monthLabel: 'Tháng ${now.month}/${now.year}',
          totalIncome: monthIncome,
          totalExpense: monthExpense,
          balance: monthBalance,
          savingsRate: savingsRate.toDouble(),
          monthTransactionCount: monthTransactions.length,
          allTransactionCount: transactions.length,
        ),
        const SizedBox(height: 14),
        _BudgetSummaryCard(
          totalBudget: totalBudget,
          spentThisMonth: spentThisMonth,
          budgetCount: currentBudgets.length,
        ),
        const SizedBox(height: 14),
        _CategorySummaryCard(
          categoryTotals: categoryTotals,
          totalExpense: monthExpense,
        ),
        const SizedBox(height: 14),
        _GenerateCard(
          canGenerate: transactions.isNotEmpty && !isGenerating,
          hasTransactions: transactions.isNotEmpty,
          isGenerating: isGenerating,
          onGenerate: onGenerate,
        ),
        if (insightsFuture != null) ...[
          const SizedBox(height: 14),
          _InsightResultCard(future: insightsFuture!),
        ],
        const SizedBox(height: 16),
        Text(
          'AI chỉ mang tính tham khảo, không thay thế tư vấn tài chính chuyên nghiệp.',
          textAlign: TextAlign.center,
          style: AppTextStyles.labelMedium.copyWith(
            color: AppColors.outline,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.monthLabel,
    required this.totalIncome,
    required this.totalExpense,
    required this.balance,
    required this.savingsRate,
    required this.monthTransactionCount,
    required this.allTransactionCount,
  });

  final String monthLabel;
  final int totalIncome;
  final int totalExpense;
  final int balance;
  final double savingsRate;
  final int monthTransactionCount;
  final int allTransactionCount;

  @override
  Widget build(BuildContext context) {
    final balancePositive = balance >= 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryContainer.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Trợ lý tài chính AI',
                      style: AppTextStyles.titleMedium.copyWith(
                        color: AppColors.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$monthLabel · $monthTransactionCount GD tháng này',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.onPrimaryContainer.withValues(
                          alpha: 0.85,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Số dư tháng',
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.onPrimaryContainer.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            formatVnd(balance, withSign: true),
            style: AppTextStyles.displayCurrency.copyWith(
              color: AppColors.onPrimaryContainer,
              fontSize: 32,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            balancePositive
                ? 'Tiết kiệm khoảng ${savingsRate.toStringAsFixed(0)}% thu nhập tháng'
                : 'Chi đang vượt thu trong tháng',
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.onPrimaryContainer.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: 'Thu',
                  value: formatVnd(totalIncome),
                  icon: Icons.north_east_rounded,
                  accent: const Color(0xFF86EFAC),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricTile(
                  label: 'Chi',
                  value: formatVnd(totalExpense),
                  icon: Icons.south_west_rounded,
                  accent: const Color(0xFFFCA5A5),
                ),
              ),
            ],
          ),
          if (allTransactionCount != monthTransactionCount) ...[
            const SizedBox(height: 10),
            Text(
              'Phân tích AI dùng toàn bộ $allTransactionCount giao dịch đã ghi',
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.onPrimaryContainer.withValues(alpha: 0.7),
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 15, color: accent),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.onPrimaryContainer.withValues(alpha: 0.8),
                  ),
                ),
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetSummaryCard extends StatelessWidget {
  const _BudgetSummaryCard({
    required this.totalBudget,
    required this.spentThisMonth,
    required this.budgetCount,
  });

  final int totalBudget;
  final int spentThisMonth;
  final int budgetCount;

  @override
  Widget build(BuildContext context) {
    final hasBudget = totalBudget > 0;
    final progress = hasBudget ? spentThisMonth / totalBudget : 0.0;
    final over = progress > 1;
    final remaining = totalBudget - spentThisMonth;
    final percent = (progress * 100).clamp(0, 999);

    return _SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Ngân sách tháng này',
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: hasBudget
                      ? (over
                            ? AppColors.expense.withValues(alpha: 0.12)
                            : AppColors.primary.withValues(alpha: 0.1))
                      : AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  hasBudget
                      ? (over
                            ? 'Vượt ${percent.toStringAsFixed(0)}%'
                            : 'Đã dùng ${percent.toStringAsFixed(0)}%')
                      : 'Chưa đặt',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: hasBudget
                        ? (over ? AppColors.expense : AppColors.primary)
                        : AppColors.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (!hasBudget) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 20,
                    color: AppColors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Chưa có hạn mức. Vào Quản lý ngân sách, bấm bút chì từng danh mục để đặt.',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Đã chi tháng này: ${formatVnd(spentThisMonth)}',
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ] else ...[
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: formatVnd(spentThisMonth),
                    style: AppTextStyles.headlineLargeMobile.copyWith(
                      color: over ? AppColors.expense : AppColors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  TextSpan(
                    text: ' / ${formatVnd(totalBudget)}',
                    style: AppTextStyles.titleMedium.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              over
                  ? 'Đã vượt ${formatVnd(spentThisMonth - totalBudget)} · $budgetCount mục'
                  : 'Còn lại ${formatVnd(remaining)} · $budgetCount mục',
              style: AppTextStyles.labelMedium,
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 8,
                value: progress.clamp(0, 1),
                backgroundColor: AppColors.surfaceContainerHigh,
                color: over ? AppColors.expense : AppColors.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CategorySummaryCard extends StatelessWidget {
  const _CategorySummaryCard({
    required this.categoryTotals,
    required this.totalExpense,
  });

  final List<_CategoryTotal> categoryTotals;
  final int totalExpense;

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Chi theo danh mục',
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Trong tháng hiện tại',
            style: AppTextStyles.labelMedium,
          ),
          const SizedBox(height: 14),
          if (categoryTotals.isEmpty)
            Text(
              'Chưa có khoản chi tháng này để phân tích.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            )
          else ...[
            for (var i = 0; i < categoryTotals.length && i < 5; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              _CategoryBar(
                item: categoryTotals[i],
                totalExpense: totalExpense,
                rank: i + 1,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _CategoryBar extends StatelessWidget {
  const _CategoryBar({
    required this.item,
    required this.totalExpense,
    required this.rank,
  });

  final _CategoryTotal item;
  final int totalExpense;
  final int rank;

  @override
  Widget build(BuildContext context) {
    final share = totalExpense <= 0 ? 0.0 : item.amount / totalExpense;

    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: item.meta.backgroundColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(item.meta.icon, color: item.meta.color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.category,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    formatVnd(item.amount),
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 6,
                  value: share.clamp(0, 1),
                  backgroundColor: AppColors.surfaceContainerHigh,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '#$rank · ${(share * 100).toStringAsFixed(0)}% tổng chi tháng',
                style: AppTextStyles.labelMedium.copyWith(fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GenerateCard extends StatelessWidget {
  const _GenerateCard({
    required this.canGenerate,
    required this.hasTransactions,
    required this.isGenerating,
    required this.onGenerate,
  });

  final bool canGenerate;
  final bool hasTransactions;
  final bool isGenerating;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline_rounded, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Gợi ý thông minh',
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            hasTransactions
                ? 'AI đọc thu/chi, ngân sách và danh mục để đưa ra gợi ý quản lý tiền cụ thể.'
                : 'Thêm ít nhất một giao dịch trước khi tạo phân tích.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: canGenerate ? onGenerate : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryContainer,
                foregroundColor: AppColors.onPrimaryContainer,
                disabledBackgroundColor: AppColors.primaryContainer.withValues(
                  alpha: 0.45,
                ),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: isGenerating
                  ? SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: AppColors.onPrimaryContainer,
                      ),
                    )
                  : const Icon(Icons.auto_awesome_rounded, size: 18),
              label: Text(
                isGenerating ? 'Đang phân tích…' : 'Tạo phân tích AI',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightResultCard extends StatelessWidget {
  const _InsightResultCard({required this.future});

  final Future<_InsightResult> future;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_InsightResult>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _SoftCard(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Column(
                children: [
                  SizedBox.square(
                    dimension: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.6,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Đang tổng hợp dữ liệu và tạo gợi ý…',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        if (snapshot.hasError) {
          return _SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Không tạo được phân tích',
                  style: AppTextStyles.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  snapshot.error.toString(),
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.error,
                  ),
                ),
              ],
            ),
          );
        }

        final result = snapshot.data;
        if (result == null) return const SizedBox.shrink();
        final bullets = _parseInsightBullets(result.text);

        return _SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.psychology_alt_rounded,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      result.source == _InsightSource.gemini
                          ? 'Kết quả phân tích'
                          : 'Phân tích cục bộ',
                      style: AppTextStyles.titleMedium.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  _InsightSourceBadge(source: result.source),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                result.source == _InsightSource.gemini
                    ? 'Gemini đọc dữ liệu thu chi của bạn.'
                    : 'Dùng phân tích dự phòng trên thiết bị.',
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),
              if (bullets.isEmpty)
                SelectableText(
                  result.text,
                  style: AppTextStyles.bodyMedium.copyWith(height: 1.55),
                )
              else
                for (var i = 0; i < bullets.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  _InsightBullet(index: i + 1, text: bullets[i]),
                ],
            ],
          ),
        );
      },
    );
  }
}

class _InsightBullet extends StatelessWidget {
  const _InsightBullet({required this.index, required this.text});

  final int index;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$index',
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SelectableText(
              text,
              style: AppTextStyles.bodyMedium.copyWith(height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightSourceBadge extends StatelessWidget {
  const _InsightSourceBadge({required this.source});

  final _InsightSource source;

  @override
  Widget build(BuildContext context) {
    final isGemini = source == _InsightSource.gemini;
    final color = isGemini ? AppColors.primary : AppColors.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isGemini ? 'Gemini' : 'Cục bộ',
        style: AppTextStyles.labelMedium.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error),
        ),
      ),
    );
  }
}

class _SoftCard extends StatelessWidget {
  const _SoftCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.14),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }
}

List<String> _parseInsightBullets(String text) {
  final lines = text
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();

  final bullets = <String>[];
  for (final line in lines) {
    if (line.startsWith('- ') ||
        line.startsWith('• ') ||
        line.startsWith('* ')) {
      bullets.add(line.substring(2).trim());
    } else if (RegExp(r'^\d+[\.\)]\s+').hasMatch(line)) {
      bullets.add(line.replaceFirst(RegExp(r'^\d+[\.\)]\s+'), '').trim());
    }
  }
  return bullets;
}

class _CategoryTotal {
  const _CategoryTotal({
    required this.category,
    required this.amount,
    required this.meta,
  });

  final String category;
  final int amount;
  final CategoryMeta meta;
}

class _InsightResult {
  const _InsightResult({required this.text, required this.source});

  final String text;
  final _InsightSource source;
}

enum _InsightSource { gemini, fallback }

int _sumByType(List<AppTransaction> transactions, AppTransactionType type) {
  return transactions
      .where((transaction) => transaction.type == type)
      .fold<int>(0, (sum, transaction) => sum + transaction.amount);
}

List<_CategoryTotal> _expenseCategoryTotals(List<AppTransaction> transactions) {
  final totals = <String, int>{};
  for (final transaction in transactions) {
    if (transaction.type != AppTransactionType.expense) continue;
    totals.update(
      transaction.category,
      (value) => value + transaction.amount,
      ifAbsent: () => transaction.amount,
    );
  }

  final result =
      totals.entries
          .map(
            (entry) => _CategoryTotal(
              category: entry.key,
              amount: entry.value,
              meta: categoryMeta(entry.key),
            ),
          )
          .toList()
        ..sort((left, right) => right.amount.compareTo(left.amount));
  return result;
}

Map<String, int> _monthlyExpenseByCategory(
  List<AppTransaction> transactions,
  String periodKey,
) {
  final result = <String, int>{};
  for (final transaction in transactions) {
    if (transaction.type != AppTransactionType.expense ||
        monthKey(transaction.transactionDate) != periodKey) {
      continue;
    }
    result.update(
      transaction.category,
      (value) => value + transaction.amount,
      ifAbsent: () => transaction.amount,
    );
  }
  return result;
}

String _buildExpensePrompt(
  List<AppTransaction> transactions,
  List<AppBudget> budgets, {
  bool strict = false,
}) {
  final sortedTransactions = [...transactions]
    ..sort(
      (left, right) => right.transactionDate.compareTo(left.transactionDate),
    );
  final totalIncome = _sumByType(transactions, AppTransactionType.income);
  final totalExpense = _sumByType(transactions, AppTransactionType.expense);
  final balance = totalIncome - totalExpense;
  final currentMonthKey = monthKey(DateTime.now());
  final categoryTotals = _expenseCategoryTotals(transactions);
  final monthlySpent = _monthlyExpenseByCategory(transactions, currentMonthKey);
  final currentBudgets = budgets
      .where((budget) => budget.periodKey == currentMonthKey)
      .toList();
  final strictInstruction = strict
      ? '''

Lần trả lời trước quá ngắn. Lần này bắt buộc phải phân tích đầy đủ theo đúng dữ liệu, không viết lời chào, không viết phần mở bài.
Trả lời tối thiểu 350 từ, gồm 6 đến 8 gạch đầu dòng. Mỗi gạch đầu dòng phải có 2 câu: câu 1 nêu nhận xét có số liệu, câu 2 nêu hành động cụ thể.
'''
      : '';

  return '''
Bạn là trợ lý tài chính cá nhân cho sinh viên Việt Nam.
Hãy phân tích dữ liệu thu chi dưới đây và trả lời bằng tiếng Việt.
$strictInstruction

Bắt buộc:
- Không được chỉ chào hỏi hoặc giới thiệu bản thân.
- Bắt đầu ngay bằng dòng "- Tổng quan:".
- Trả lời 6 đến 8 gạch đầu dòng, mỗi dòng phải bắt đầu bằng "- ".
- Mỗi gạch đầu dòng phải có 2 câu, dài vừa đủ, có số liệu cụ thể từ dữ liệu bên dưới.
- Tổng câu trả lời tối thiểu 350 từ hoặc khoảng 1800 ký tự.
- Không dừng ở phần tổng quan; phải có đủ phần ngân sách, danh mục chi nhiều, tỷ lệ tiết kiệm và việc nên làm.
- Không bịa số liệu ngoài dữ liệu được cung cấp.
- Nếu dữ liệu còn ít, hãy nói rõ cần thêm dữ liệu để phân tích chính xác hơn.
- Không đưa lời khuyên đầu tư rủi ro.
- Kết thúc bằng 1 việc nên làm tiếp theo trong tuần này.

Tổng quan:
- Số giao dịch: ${transactions.length}
- Tổng thu: ${_amountForPrompt(totalIncome)}
- Tổng chi: ${_amountForPrompt(totalExpense)}
- Số dư: ${_amountForPrompt(balance)}

Chi tiêu theo danh mục:
${_categoryLines(categoryTotals)}

Ngân sách tháng hiện tại ($currentMonthKey):
${_budgetLines(currentBudgets, monthlySpent)}

Giao dịch gần đây:
${_transactionLines(sortedTransactions.take(20))}
''';
}

String _buildRewritePrompt({
  required String baseline,
  required String originalPrompt,
  bool strict = false,
}) {
  final strictText = strict
      ? 'Bản trả lời trước quá ngắn. Lần này phải viết dài hơn bản phân tích chuẩn, không được rút gọn.'
      : 'Hãy viết lại bản phân tích chuẩn bên dưới cho tự nhiên hơn nhưng không được ngắn hơn.';

  return '''
$strictText

Bản phân tích chuẩn do app đã tính đúng từ Firestore:
$baseline

Yêu cầu với câu trả lời Gemini:
- Giữ toàn bộ ý chính và toàn bộ số liệu quan trọng từ bản phân tích chuẩn.
- Có thể diễn đạt tự nhiên hơn và thêm 1-2 gợi ý hợp lý dựa trên dữ liệu gốc.
- Không được chỉ viết tổng quan một dòng.
- Không được ngắn hơn bản phân tích chuẩn.
- Trả lời 6 đến 8 gạch đầu dòng, mỗi gạch đầu dòng có 2 câu.
- Nếu dữ liệu ít, vẫn phải giải thích rõ dữ liệu ít ảnh hưởng thế nào đến độ chính xác.

Dữ liệu gốc để đối chiếu:
$originalPrompt
''';
}

String _buildExpandPrompt(
  String originalPrompt,
  String shortAnswer,
  String baseline,
) {
  return '''
Câu trả lời Gemini trước đó quá ngắn:
$shortAnswer

Hãy viết lại câu trả lời dài hơn và cụ thể hơn dựa trên bản phân tích chuẩn và dữ liệu gốc dưới đây.

Bản phân tích chuẩn, không được viết ngắn hơn bản này:
$baseline

Bắt buộc:
- Chỉ trả lời bằng tiếng Việt.
- Trả lời 6 đến 8 gạch đầu dòng.
- Mỗi gạch đầu dòng có 2 câu: câu 1 phân tích với số liệu, câu 2 đề xuất hành động.
- Tổng câu trả lời tối thiểu 350 từ hoặc khoảng 1800 ký tự.
- Không chào hỏi, không xin lỗi, không giới thiệu bản thân.
- Không bịa thêm giao dịch hoặc số tiền ngoài dữ liệu.
- Phải nhắc đến tổng thu, tổng chi, số dư, danh mục chi nhiều nhất, ngân sách và việc nên làm tuần này.

Dữ liệu gốc:
$originalPrompt
''';
}

bool _usefulAiText(String text, {required String fallback}) {
  final normalized = text.trim();
  final bulletCount = RegExp(r'(^|\n)\s*[-•]').allMatches(normalized).length;
  final minLength = fallback.length > 650
      ? (fallback.length * 0.9).round()
      : 650;
  return normalized.length >= minLength && bulletCount >= 5;
}

String _buildLocalInsight(
  List<AppTransaction> transactions,
  List<AppBudget> budgets,
) {
  final totalIncome = _sumByType(transactions, AppTransactionType.income);
  final totalExpense = _sumByType(transactions, AppTransactionType.expense);
  final balance = totalIncome - totalExpense;
  final savingsRate = totalIncome <= 0 ? 0.0 : balance / totalIncome * 100;
  final categoryTotals = _expenseCategoryTotals(transactions);
  final currentMonthKey = monthKey(DateTime.now());
  final currentBudgets = budgets
      .where((budget) => budget.periodKey == currentMonthKey)
      .toList();
  final monthlySpent = _monthlyExpenseByCategory(transactions, currentMonthKey);
  final totalBudget = currentBudgets.fold<int>(
    0,
    (sum, budget) => sum + budget.limitAmount,
  );
  final spentThisMonth = monthlySpent.values.fold<int>(
    0,
    (sum, amount) => sum + amount,
  );
  final remainingBudget = totalBudget - spentThisMonth;
  final topCategory = categoryTotals.isEmpty ? null : categoryTotals.first;
  final topPercent = topCategory == null || totalExpense <= 0
      ? 0.0
      : topCategory.amount / totalExpense * 100;
  final overBudgetCategories = currentBudgets.where((budget) {
    final spent = monthlySpent[budget.category] ?? 0;
    return spent > budget.limitAmount;
  }).toList();

  final lines = <String>[
    '- Tổng quan: Bạn có ${transactions.length} giao dịch, tổng thu ${formatVnd(totalIncome)}, tổng chi ${formatVnd(totalExpense)}, số dư ${formatVnd(balance)}.',
    '- Tỷ lệ tiết kiệm hiện tại khoảng ${savingsRate.clamp(0, 100).toStringAsFixed(1)}%, phù hợp nếu bạn muốn giữ lại một phần thu nhập để dự phòng.',
  ];

  if (topCategory != null) {
    lines.add(
      '- Danh mục chi nhiều nhất là ${topCategory.category} với ${formatVnd(topCategory.amount)}, chiếm khoảng ${topPercent.toStringAsFixed(1)}% tổng chi.',
    );
  } else {
    lines.add(
      '- Hiện chưa có khoản chi nào, bạn cần thêm giao dịch chi tiêu để AI phân tích thói quen chi tiêu rõ hơn.',
    );
  }

  if (totalBudget > 0) {
    lines.add(
      '- Ngân sách tháng này đã dùng ${formatVnd(spentThisMonth)} / ${formatVnd(totalBudget)}, còn lại ${formatVnd(remainingBudget)}.',
    );
  } else {
    lines.add(
      '- Bạn chưa đặt ngân sách tháng này, nên đặt giới hạn cho các nhóm như ăn uống, đi lại, mua sắm và học tập.',
    );
  }

  if (overBudgetCategories.isNotEmpty) {
    final names = overBudgetCategories
        .map((budget) => budget.category)
        .join(', ');
    lines.add(
      '- Cần chú ý các danh mục vượt ngân sách: $names. Hãy giảm chi hoặc tăng ngân sách nếu đây là khoản bắt buộc.',
    );
  } else if (currentBudgets.isNotEmpty) {
    lines.add(
      '- Chưa có danh mục nào vượt ngân sách, bạn đang kiểm soát chi tiêu tháng này khá ổn.',
    );
  }

  if (transactions.length < 5) {
    lines.add(
      '- Dữ liệu còn ít, hãy ghi thêm giao dịch trong vài ngày tới để phần phân tích chính xác hơn.',
    );
  } else {
    lines.add(
      '- Việc nên làm tiếp theo trong tuần này: xem lại danh mục chi lớn nhất và đặt mục tiêu giảm 5-10% nếu đó là khoản không bắt buộc.',
    );
  }

  return lines.join('\n');
}

String _amountForPrompt(int amount) => '$amount VND';

String _categoryLines(List<_CategoryTotal> totals) {
  if (totals.isEmpty) return '- Chưa có khoản chi.';
  return totals
      .map((item) => '- ${item.category}: ${_amountForPrompt(item.amount)}')
      .join('\n');
}

String _budgetLines(List<AppBudget> budgets, Map<String, int> spentByCategory) {
  if (budgets.isEmpty) return '- Chưa đặt ngân sách.';
  return budgets
      .map((budget) {
        final spent = spentByCategory[budget.category] ?? 0;
        return '- ${budget.category}: đã chi ${_amountForPrompt(spent)} / ngân sách ${_amountForPrompt(budget.limitAmount)}';
      })
      .join('\n');
}

String _transactionLines(Iterable<AppTransaction> transactions) {
  if (transactions.isEmpty) return '- Chưa có giao dịch.';
  return transactions
      .map((transaction) {
        final type = transaction.type == AppTransactionType.income
            ? 'thu nhập'
            : 'chi tiêu';
        final title = transaction.title?.trim().isNotEmpty == true
            ? transaction.title!.trim()
            : transaction.category;
        return '- ${_dateForPrompt(transaction.transactionDate)} | $type | $title | ${transaction.category} | ${_amountForPrompt(transaction.amount)}';
      })
      .join('\n');
}

String _dateForPrompt(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';
}

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

  void _generateInsights(
    List<AppTransaction> transactions,
    List<AppBudget> budgets,
  ) {
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
    setState(() {
      _insightsFuture = _generateGeminiFirst(
        prompt: primaryPrompt,
        retryPrompt: retryPrompt,
        fallback: fallback,
      );
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
        centerTitle: true,
        leading: IconButton(
          tooltip: 'Quay lại',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text(
          'AI phân tích',
          style: AppTextStyles.headlineLargeMobile.copyWith(
            color: AppColors.primary,
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
    required this.onGenerate,
  });

  final List<AppTransaction> transactions;
  final List<AppBudget> budgets;
  final Future<_InsightResult>? insightsFuture;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    final totalIncome = _sumByType(transactions, AppTransactionType.income);
    final totalExpense = _sumByType(transactions, AppTransactionType.expense);
    final balance = totalIncome - totalExpense;
    final categoryTotals = _expenseCategoryTotals(transactions);
    final currentMonthKey = monthKey(DateTime.now());
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        _HeroCard(
          totalIncome: totalIncome,
          totalExpense: totalExpense,
          balance: balance,
          transactionCount: transactions.length,
        ),
        const SizedBox(height: 16),
        _BudgetSummaryCard(
          totalBudget: totalBudget,
          spentThisMonth: spentThisMonth,
          budgetCount: currentBudgets.length,
        ),
        const SizedBox(height: 16),
        _CategorySummaryCard(categoryTotals: categoryTotals),
        const SizedBox(height: 16),
        _GenerateCard(
          canGenerate: transactions.isNotEmpty,
          hasTransactions: transactions.isNotEmpty,
          onGenerate: onGenerate,
        ),
        const SizedBox(height: 16),
        if (insightsFuture != null) _InsightResultCard(future: insightsFuture!),
        const SizedBox(height: 16),
        Text(
          'AI chỉ mang tính tham khảo, không thay thế tư vấn tài chính chuyên nghiệp.',
          textAlign: TextAlign.center,
          style: AppTextStyles.labelMedium.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.totalIncome,
    required this.totalExpense,
    required this.balance,
    required this.transactionCount,
  });

  final int totalIncome;
  final int totalExpense;
  final int balance;
  final int transactionCount;

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      color: AppColors.primaryContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.onPrimaryContainer.withValues(
                  alpha: 0.14,
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
                      ),
                    ),
                    Text(
                      '$transactionCount giao dịch đang được tổng hợp',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MetricPill(label: 'Thu', value: formatVnd(totalIncome)),
              _MetricPill(label: 'Chi', value: formatVnd(totalExpense)),
              _MetricPill(label: 'Số dư', value: formatVnd(balance)),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.onPrimaryContainer.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.onPrimaryContainer,
            ),
          ),
          Text(
            value,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.onPrimaryContainer,
              fontWeight: FontWeight.w800,
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
    final progress = totalBudget <= 0 ? 0.0 : spentThisMonth / totalBudget;
    return _SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ngân sách tháng này', style: AppTextStyles.titleMedium),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${formatVnd(spentThisMonth)} / ${formatVnd(totalBudget)}',
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.headlineLargeMobile.copyWith(
                    color: progress > 1 ? AppColors.error : AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text('$budgetCount mục', style: AppTextStyles.labelMedium),
            ],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            minHeight: 10,
            value: progress.clamp(0, 1),
            borderRadius: BorderRadius.circular(999),
            backgroundColor: AppColors.surfaceContainerHigh,
            color: progress > 1 ? AppColors.error : AppColors.primary,
          ),
        ],
      ),
    );
  }
}

class _CategorySummaryCard extends StatelessWidget {
  const _CategorySummaryCard({required this.categoryTotals});

  final List<_CategoryTotal> categoryTotals;

  @override
  Widget build(BuildContext context) {
    final maxAmount = categoryTotals.isEmpty ? 1 : categoryTotals.first.amount;
    return _SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Danh mục chi nhiều', style: AppTextStyles.titleMedium),
          const SizedBox(height: 14),
          if (categoryTotals.isEmpty)
            Text(
              'Chưa có khoản chi để phân tích.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            )
          else
            for (final item in categoryTotals.take(5)) ...[
              _CategoryBar(item: item, maxAmount: maxAmount),
              const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }
}

class _CategoryBar extends StatelessWidget {
  const _CategoryBar({required this.item, required this.maxAmount});

  final _CategoryTotal item;
  final int maxAmount;

  @override
  Widget build(BuildContext context) {
    final factor = maxAmount <= 0 ? 0.0 : item.amount / maxAmount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(item.meta.icon, size: 18, color: item.meta.color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                item.category,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(formatVnd(item.amount), style: AppTextStyles.bodyMedium),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 8,
            value: factor.clamp(0, 1),
            backgroundColor: AppColors.surfaceContainerHigh,
            color: item.meta.color,
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
    required this.onGenerate,
  });

  final bool canGenerate;
  final bool hasTransactions;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Gợi ý thông minh', style: AppTextStyles.titleMedium),
          const SizedBox(height: 8),
          Text(
            hasTransactions
                ? 'AI sẽ đọc tổng thu, tổng chi, ngân sách và danh mục chi tiêu để gợi ý cách quản lý tiền.'
                : 'Bạn cần thêm ít nhất một giao dịch trước khi tạo phân tích AI.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: canGenerate ? onGenerate : null,
              icon: const Icon(Icons.auto_awesome_rounded),
              label: const Text('Tạo phân tích AI'),
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
          return const _SoftCard(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(child: CircularProgressIndicator()),
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

        return _SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.psychology_alt_rounded, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      result.source == _InsightSource.gemini
                          ? 'Kết quả AI Gemini'
                          : 'Phân tích tự động',
                      style: AppTextStyles.titleMedium,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _InsightSourceBadge(source: result.source),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                result.source == _InsightSource.gemini
                    ? 'Gemini phân tích dữ liệu thu chi từ Firestore.'
                    : 'App tự phân tích dự phòng vì Gemini trả lời quá ngắn.',
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              SelectableText(
                result.text,
                style: AppTextStyles.bodyMedium.copyWith(height: 1.55),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _InsightSourceBadge extends StatelessWidget {
  const _InsightSourceBadge({required this.source});

  final _InsightSource source;

  @override
  Widget build(BuildContext context) {
    final isGemini = source == _InsightSource.gemini;
    final color = isGemini ? AppColors.primary : AppColors.tertiary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isGemini ? 'Gemini' : 'Dự phòng',
        style: AppTextStyles.labelMedium.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
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
  const _SoftCard({required this.child, this.color});

  final Widget child;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color ?? AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.20),
        ),
      ),
      child: child,
    );
  }
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

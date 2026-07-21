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

  Future<String>? _insightsFuture;

  void _generateInsights(
    List<AppTransaction> transactions,
    List<AppBudget> budgets,
  ) {
    final prompt = _buildExpensePrompt(transactions, budgets);
    setState(() {
      _insightsFuture = _aiService.generateExpenseInsights(prompt);
    });
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
  final Future<String>? insightsFuture;
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

  final Future<String> future;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
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

        return _SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.psychology_alt_rounded, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text('Kết quả AI', style: AppTextStyles.titleMedium),
                ],
              ),
              const SizedBox(height: 12),
              SelectableText(
                snapshot.data ?? '',
                style: AppTextStyles.bodyMedium.copyWith(height: 1.55),
              ),
            ],
          ),
        );
      },
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
  List<AppBudget> budgets,
) {
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

  return '''
Bạn là trợ lý tài chính cá nhân cho sinh viên Việt Nam.
Hãy phân tích dữ liệu thu chi dưới đây và trả lời bằng tiếng Việt.

Yêu cầu:
- Không bịa số liệu ngoài dữ liệu được cung cấp.
- Viết ngắn gọn, dễ hiểu, dùng gạch đầu dòng.
- Nêu 4 đến 6 nhận xét/gợi ý cụ thể.
- Nếu dữ liệu còn ít, hãy nói rõ cần thêm dữ liệu để phân tích chính xác hơn.
- Không đưa lời khuyên đầu tư rủi ro.

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

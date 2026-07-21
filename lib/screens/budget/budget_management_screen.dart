import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/app_formatters.dart';
import '../../core/utils/category_catalog.dart';
import '../../data/models/app_budget.dart';
import '../../data/models/app_notification.dart';
import '../../data/models/app_transaction.dart';
import '../../data/repositories/firebase_auth_error_mapper.dart';
import '../../data/repositories/firestore_repository.dart';

class BudgetManagementScreen extends StatelessWidget {
  const BudgetManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = FirestoreRepository();
    final key = monthKey(DateTime.now());

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
          'Quản lý ngân sách',
          style: AppTextStyles.headlineLargeMobile.copyWith(
            color: AppColors.primary,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: StreamBuilder<List<AppBudget>>(
              stream: repository.watchBudgets(periodKey: key),
              builder: (context, budgetSnapshot) {
                if (budgetSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (budgetSnapshot.hasError) {
                  return Center(
                    child: Text(
                      firebaseAuthErrorMessage(budgetSnapshot.error!),
                    ),
                  );
                }

                return StreamBuilder<List<AppTransaction>>(
                  stream: repository.watchTransactions(),
                  builder: (context, transactionSnapshot) {
                    if (transactionSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (transactionSnapshot.hasError) {
                      return Center(
                        child: Text(
                          firebaseAuthErrorMessage(transactionSnapshot.error!),
                        ),
                      );
                    }

                    final budgets = budgetSnapshot.data ?? [];
                    final transactions = transactionSnapshot.data ?? [];
                    return _BudgetBody(
                      repository: repository,
                      periodKey: key,
                      budgets: budgets,
                      transactions: transactions,
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

class _BudgetBody extends StatelessWidget {
  const _BudgetBody({
    required this.repository,
    required this.periodKey,
    required this.budgets,
    required this.transactions,
  });

  final FirestoreRepository repository;
  final String periodKey;
  final List<AppBudget> budgets;
  final List<AppTransaction> transactions;

  @override
  Widget build(BuildContext context) {
    final expenseThisMonth = transactions.where(
      (item) =>
          item.type == AppTransactionType.expense &&
          monthKey(item.transactionDate) == periodKey,
    );
    final spentByCategory = <String, int>{};
    for (final transaction in expenseThisMonth) {
      spentByCategory.update(
        transaction.category,
        (value) => value + transaction.amount,
        ifAbsent: () => transaction.amount,
      );
    }

    final totalLimit = budgets.fold<int>(
      0,
      (sum, budget) => sum + budget.limitAmount,
    );
    final totalSpent = spentByCategory.values.fold<int>(0, (a, b) => a + b);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _SummaryCard(totalLimit: totalLimit, totalSpent: totalSpent),
        const SizedBox(height: 20),
        for (final category in expenseCategories) ...[
          _BudgetCategoryCard(
            repository: repository,
            periodKey: periodKey,
            category: category,
            budget: budgets
                .where((budget) => budget.category == category.label)
                .firstOrNull,
            spent: spentByCategory[category.label] ?? 0,
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.totalLimit, required this.totalSpent});

  final int totalLimit;
  final int totalSpent;

  @override
  Widget build(BuildContext context) {
    final percent = totalLimit <= 0 ? 0.0 : totalSpent / totalLimit;
    return _SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ngân sách tháng này', style: AppTextStyles.titleMedium),
          const SizedBox(height: 12),
          Text(
            '${formatVnd(totalSpent)} / ${formatVnd(totalLimit)}',
            style: AppTextStyles.displayCurrency.copyWith(
              color: percent > 1 ? AppColors.error : AppColors.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Đã chi / Tổng ngân sách',
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: percent.clamp(0, 1),
            minHeight: 10,
            color: percent > 1 ? AppColors.error : AppColors.secondary,
            backgroundColor: AppColors.surfaceContainerHighest,
          ),
        ],
      ),
    );
  }
}

class _BudgetCategoryCard extends StatelessWidget {
  const _BudgetCategoryCard({
    required this.repository,
    required this.periodKey,
    required this.category,
    required this.budget,
    required this.spent,
  });

  final FirestoreRepository repository;
  final String periodKey;
  final CategoryMeta category;
  final AppBudget? budget;
  final int spent;

  @override
  Widget build(BuildContext context) {
    final limit = budget?.limitAmount ?? 0;
    final percent = limit <= 0 ? 0.0 : spent / limit;

    return _SoftCard(
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: category.backgroundColor,
            child: Icon(category.icon, color: category.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(category.label, style: AppTextStyles.titleMedium),
                const SizedBox(height: 4),
                Text(
                  limit == 0
                      ? 'Chưa đặt ngân sách'
                      : '${formatVnd(spent)} / ${formatVnd(limit)}',
                  style: AppTextStyles.labelMedium,
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: percent.clamp(0, 1),
                  color: percent > 1 ? AppColors.error : category.color,
                  backgroundColor: AppColors.surfaceContainerHighest,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Đặt ngân sách',
            onPressed: () => _showBudgetSheet(context),
            icon: const Icon(Icons.edit_outlined),
          ),
          if (budget != null)
            IconButton(
              tooltip: 'Xóa ngân sách',
              onPressed: () async {
                await repository.deleteBudget(budget!.id);
              },
              icon: const Icon(Icons.delete_outline),
              color: AppColors.error,
            ),
        ],
      ),
    );
  }

  Future<void> _showBudgetSheet(BuildContext context) async {
    final amount = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _BudgetInputSheet(
        category: category.label,
        initialAmount: budget?.limitAmount,
      ),
    );

    if (!context.mounted || amount == null) return;

    final saved = AppBudget(
      id: budget?.id ?? '',
      category: category.label,
      limitAmount: amount,
      period: BudgetPeriod.monthly,
      periodKey: periodKey,
    );
    try {
      await repository.setBudget(saved);
      await repository.addNotificationIfEnabled(
        AppNotification(
          id: '',
          title: 'Đã cập nhật ngân sách',
          body: '${category.label}: ${formatVnd(amount)}',
          type: 'budget',
          isRead: false,
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(firebaseAuthErrorMessage(error))));
    }
  }
}

class _BudgetInputSheet extends StatefulWidget {
  const _BudgetInputSheet({required this.category, this.initialAmount});

  final String category;
  final int? initialAmount;

  @override
  State<_BudgetInputSheet> createState() => _BudgetInputSheetState();
}

class _BudgetInputSheetState extends State<_BudgetInputSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialAmount == null ? '' : widget.initialAmount.toString(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(context).pop(int.parse(_controller.text));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedPadding(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Đặt ngân sách ${widget.category}',
              style: AppTextStyles.titleMedium,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Số tiền',
                suffixText: 'VND',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final amount = int.tryParse(value ?? '') ?? 0;
                if (amount <= 0) return 'Nhập số tiền lớn hơn 0';
                return null;
              },
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submit,
                child: const Text('Lưu ngân sách'),
              ),
            ),
          ],
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.20),
        ),
      ),
      child: child,
    );
  }
}

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
    final now = DateTime.now();
    final key = monthKey(now);

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
          'Quản lý ngân sách',
          style: AppTextStyles.headlineLargeMobile.copyWith(
            color: AppColors.onSurface,
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
                      monthLabel: 'Tháng ${now.month}/${now.year}',
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
    required this.monthLabel,
    required this.budgets,
    required this.transactions,
  });

  final FirestoreRepository repository;
  final String periodKey;
  final String monthLabel;
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
    final trackedSpent = budgets.fold<int>(0, (sum, budget) {
      return sum + (spentByCategory[budget.category] ?? 0);
    });
    final allSpent = spentByCategory.values.fold<int>(0, (a, b) => a + b);
    final setCount = budgets.length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        _SummaryCard(
          monthLabel: monthLabel,
          totalLimit: totalLimit,
          trackedSpent: trackedSpent,
          allSpent: allSpent,
          setCount: setCount,
        ),
        const SizedBox(height: 16),
        Text(
          'Hạn mức theo danh mục',
          style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'Bấm vào danh mục để đặt hoặc sửa hạn mức tháng.',
          style: AppTextStyles.labelMedium,
        ),
        const SizedBox(height: 12),
        Container(
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
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < expenseCategories.length; i++)
                _BudgetCategoryTile(
                  repository: repository,
                  periodKey: periodKey,
                  category: expenseCategories[i],
                  budget: budgets
                      .where(
                        (budget) =>
                            budget.category == expenseCategories[i].label,
                      )
                      .firstOrNull,
                  spent: spentByCategory[expenseCategories[i].label] ?? 0,
                  showDivider: i != expenseCategories.length - 1,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.monthLabel,
    required this.totalLimit,
    required this.trackedSpent,
    required this.allSpent,
    required this.setCount,
  });

  final String monthLabel;
  final int totalLimit;
  final int trackedSpent;
  final int allSpent;
  final int setCount;

  @override
  Widget build(BuildContext context) {
    final hasBudget = totalLimit > 0;
    final progress = hasBudget ? trackedSpent / totalLimit : 0.0;
    final over = progress > 1;
    final remaining = totalLimit - trackedSpent;
    final percentLabel = (progress * 100).clamp(0, 999).toStringAsFixed(0);
    final barValue = _visibleProgress(progress, trackedSpent > 0);

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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ngân sách tháng này',
                      style: AppTextStyles.titleMedium.copyWith(
                        color: AppColors.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$monthLabel · $setCount danh mục đã đặt',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.onPrimaryContainer.withValues(
                          alpha: 0.85,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  hasBudget
                      ? (over ? 'Vượt mức' : 'Đã dùng $percentLabel%')
                      : 'Chưa đặt',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (!hasBudget) ...[
            Text(
              'Chưa có tổng ngân sách',
              style: AppTextStyles.headlineLargeMobile.copyWith(
                color: AppColors.onPrimaryContainer,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Đặt hạn mức từng danh mục bên dưới. Tổng sẽ cộng tự động.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.onPrimaryContainer.withValues(alpha: 0.85),
                height: 1.35,
              ),
            ),
            if (allSpent > 0) ...[
              const SizedBox(height: 12),
              Text(
                'Đã chi tháng này: ${formatVnd(allSpent)}',
                style: AppTextStyles.labelMedium.copyWith(
                  color: const Color(0xFFFCA5A5),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ] else ...[
            Text(
              over ? 'Đã vượt' : 'Còn lại',
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.onPrimaryContainer.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              formatVnd(over ? trackedSpent - totalLimit : remaining),
              style: AppTextStyles.displayCurrency.copyWith(
                color: over
                    ? const Color(0xFFFCA5A5)
                    : AppColors.onPrimaryContainer,
                fontSize: 32,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _HeroMetric(
                    label: 'Đã chi',
                    value: formatVnd(trackedSpent),
                    accent: const Color(0xFFFCA5A5),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _HeroMetric(
                    label: 'Tổng hạn mức',
                    value: formatVnd(totalLimit),
                    accent: const Color(0xFF86EFAC),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 8,
                value: barValue,
                backgroundColor: Colors.white.withValues(alpha: 0.18),
                color: over
                    ? const Color(0xFFFCA5A5)
                    : AppColors.onPrimaryContainer,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
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
    );
  }
}

class _BudgetCategoryTile extends StatelessWidget {
  const _BudgetCategoryTile({
    required this.repository,
    required this.periodKey,
    required this.category,
    required this.budget,
    required this.spent,
    required this.showDivider,
  });

  final FirestoreRepository repository;
  final String periodKey;
  final CategoryMeta category;
  final AppBudget? budget;
  final int spent;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final limit = budget?.limitAmount ?? 0;
    final hasLimit = limit > 0;
    final progress = hasLimit ? spent / limit : 0.0;
    final over = progress > 1;
    final near = progress >= 0.8 && !over;
    final remaining = limit - spent;
    final barValue = _visibleProgress(progress, spent > 0 && hasLimit);
    final statusColor = !hasLimit
        ? AppColors.onSurfaceVariant
        : over
        ? AppColors.expense
        : near
        ? const Color(0xFFD97706)
        : AppColors.primary;
    final statusText = !hasLimit
        ? 'Chưa đặt'
        : over
        ? 'Vượt mức'
        : near
        ? 'Sắp hết'
        : 'An toàn';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showBudgetSheet(context),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
          decoration: BoxDecoration(
            border: showDivider
                ? Border(
                    bottom: BorderSide(
                      color: AppColors.outlineVariant.withValues(alpha: 0.16),
                    ),
                  )
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: category.backgroundColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(category.icon, color: category.color),
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
                            category.label,
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            statusText,
                            style: AppTextStyles.labelMedium.copyWith(
                              color: statusColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (!hasLimit)
                      Text(
                        spent > 0
                            ? 'Đã chi ${formatVnd(spent)} · bấm để đặt hạn mức'
                            : 'Bấm để đặt hạn mức tháng',
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      )
                    else ...[
                      Text(
                        '${formatVnd(spent)} / ${formatVnd(limit)}',
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        over
                            ? 'Vượt ${formatVnd(spent - limit)}'
                            : 'Còn ${formatVnd(remaining)}',
                        style: AppTextStyles.labelMedium.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          minHeight: 6,
                          value: barValue,
                          backgroundColor: AppColors.surfaceContainerHigh,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: hasLimit ? 'Sửa hạn mức' : 'Đặt hạn mức',
                onPressed: () => _showBudgetSheet(context),
                icon: Icon(
                  hasLimit ? Icons.edit_outlined : Icons.add_rounded,
                  color: AppColors.primary,
                ),
              ),
              if (budget != null)
                IconButton(
                  tooltip: 'Xóa ngân sách',
                  onPressed: () => _confirmDelete(context),
                  icon: const Icon(Icons.delete_outline_rounded),
                  color: AppColors.expense,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final budget = this.budget;
    if (budget == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surfaceContainerLowest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Xóa ngân sách?'),
          content: Text(
            'Gỡ hạn mức “${category.label}” tháng này.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.expense,
                foregroundColor: Colors.white,
              ),
              child: const Text('Xóa'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) return;
    try {
      await repository.deleteBudget(budget.id);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(firebaseAuthErrorMessage(error))));
    }
  }

  Future<void> _showBudgetSheet(BuildContext context) async {
    final amount = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) => _BudgetInputSheet(
        category: category.label,
        categoryMeta: category,
        initialAmount: budget?.limitAmount,
        spent: spent,
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
  const _BudgetInputSheet({
    required this.category,
    required this.categoryMeta,
    required this.spent,
    this.initialAmount,
  });

  final String category;
  final CategoryMeta categoryMeta;
  final int spent;
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
        top: 12,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.outlineVariant.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: widget.categoryMeta.backgroundColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    widget.categoryMeta.icon,
                    color: widget.categoryMeta.color,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hạn mức ${widget.category}',
                        style: AppTextStyles.titleMedium.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        widget.spent > 0
                            ? 'Đã chi tháng này: ${formatVnd(widget.spent)}'
                            : 'Chưa có chi tiêu danh mục này',
                        style: AppTextStyles.labelMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              'Số tiền hạn mức',
              style: AppTextStyles.labelMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: AppTextStyles.displayCurrency.copyWith(
                fontSize: 34,
                color: AppColors.primary,
                height: 1.1,
              ),
              decoration: InputDecoration(
                hintText: '0',
                hintStyle: AppTextStyles.displayCurrency.copyWith(
                  fontSize: 34,
                  color: AppColors.primary.withValues(alpha: 0.28),
                  height: 1.1,
                ),
                suffixText: 'đ',
                suffixStyle: AppTextStyles.titleMedium.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
                border: InputBorder.none,
                errorStyle: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.error,
                ),
              ),
              validator: (value) {
                final amount = int.tryParse(value ?? '') ?? 0;
                if (amount <= 0) return 'Nhập số tiền lớn hơn 0';
                return null;
              },
              onFieldSubmitted: (_) => _submit(),
            ),
            Container(
              height: 2,
              margin: const EdgeInsets.symmetric(horizontal: 48),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryContainer,
                  foregroundColor: AppColors.onPrimaryContainer,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text('Lưu hạn mức'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Keep a tiny visible fill when there is spend but ratio is near 0.
double _visibleProgress(double progress, bool hasSpend) {
  if (!hasSpend || progress <= 0) return 0;
  if (progress >= 1) return 1;
  return progress < 0.04 ? 0.04 : progress;
}

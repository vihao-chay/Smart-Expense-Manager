import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/app_formatters.dart';
import '../../core/utils/category_catalog.dart';
import '../../core/widgets/app_top_bar.dart';
import '../../data/models/app_transaction.dart';
import '../../data/models/app_user_profile.dart';
import '../../data/repositories/firebase_auth_error_mapper.dart';
import '../../data/repositories/firestore_repository.dart';
import '../add_transaction/add_transaction_screen.dart';
import '../transaction_detail/transaction_detail_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = FirestoreRepository();

    return Scaffold(
      backgroundColor: AppColors.surface,
      bottomNavigationBar: const _BottomNavBar(),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 768),
            child: StreamBuilder<AppUserProfile?>(
              stream: repository.watchProfile(),
              builder: (context, profileSnapshot) {
                final profile = profileSnapshot.data;
                return Column(
                  children: [
                    AppTopBar(profile: profile),
                    Expanded(
                      child: StreamBuilder<List<AppTransaction>>(
                        stream: repository.watchTransactions(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          if (snapshot.hasError) {
                            return Center(
                              child: Text(
                                firebaseAuthErrorMessage(snapshot.error!),
                                textAlign: TextAlign.center,
                              ),
                            );
                          }

                          final transactions = snapshot.data ?? [];
                          return _HomeContent(transactions: transactions);
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({required this.transactions});

  final List<AppTransaction> transactions;

  @override
  Widget build(BuildContext context) {
    final totalIncome = transactions
        .where((item) => item.type == AppTransactionType.income)
        .fold<int>(0, (sum, item) => sum + item.amount);
    final totalExpense = transactions
        .where((item) => item.type == AppTransactionType.expense)
        .fold<int>(0, (sum, item) => sum + item.amount);
    final balance = totalIncome - totalExpense;
    final recent = transactions.take(5).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        _BalanceCard(
          balance: balance,
          income: totalIncome,
          expense: totalExpense,
        ),
        const SizedBox(height: 20),
        const _QuickActions(),
        const SizedBox(height: 20),
        _MiniStatistics(transactions: transactions),
        const SizedBox(height: 20),
        _RecentTransactions(transactions: recent),
      ],
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.balance,
    required this.income,
    required this.expense,
  });

  final int balance;
  final int income;
  final int expense;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.primaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tổng số dư',
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                formatVnd(balance),
                style: AppTextStyles.displayCurrency.copyWith(
                  color: AppColors.onPrimaryContainer,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                label: 'Thu nhập',
                amount: income,
                icon: Icons.arrow_downward_rounded,
                color: AppColors.secondary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryCard(
                label: 'Chi tiêu',
                amount: expense,
                icon: Icons.arrow_upward_rounded,
                color: AppColors.error,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.amount,
    required this.icon,
    required this.color,
  });

  final String label;
  final int amount;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.12),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.labelMedium),
                Text(
                  formatVnd(amount),
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.titleMedium.copyWith(color: color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    void openAddTransaction(AddTransactionType type) {
      Navigator.of(context).pushNamed(
        AppRoutes.addTransaction,
        arguments: AddTransactionArgs(initialType: type),
      );
    }

    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 0.82,
      children: [
        _QuickActionButton(
          label: 'Thêm thu',
          icon: Icons.add_circle_outline_rounded,
          color: AppColors.secondary,
          onTap: () => openAddTransaction(AddTransactionType.income),
        ),
        _QuickActionButton(
          label: 'Thêm chi',
          icon: Icons.remove_circle_outline_rounded,
          color: AppColors.error,
          onTap: () => openAddTransaction(AddTransactionType.expense),
        ),
        _QuickActionButton(
          label: 'Đổi tiền',
          icon: Icons.currency_exchange_rounded,
          color: AppColors.primary,
          onTap: () =>
              Navigator.of(context).pushNamed(AppRoutes.currencyConverter),
        ),
        _QuickActionButton(
          label: 'Ngân sách',
          icon: Icons.pie_chart_outline_rounded,
          color: AppColors.tertiary,
          onTap: () =>
              Navigator.of(context).pushNamed(AppRoutes.budgetManagement),
        ),
      ],
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      padding: const EdgeInsets.all(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: 8),
            FittedBox(child: Text(label, style: AppTextStyles.labelMedium)),
          ],
        ),
      ),
    );
  }
}

class _MiniStatistics extends StatelessWidget {
  const _MiniStatistics({required this.transactions});

  final List<AppTransaction> transactions;

  @override
  Widget build(BuildContext context) {
    final days = List.generate(7, (index) {
      final date = DateTime.now().subtract(Duration(days: 6 - index));
      final income = transactions
          .where(
            (item) =>
                item.type == AppTransactionType.income &&
                _sameDay(item.transactionDate, date),
          )
          .fold<int>(0, (sum, item) => sum + item.amount);
      final expense = transactions
          .where(
            (item) =>
                item.type == AppTransactionType.expense &&
                _sameDay(item.transactionDate, date),
          )
          .fold<int>(0, (sum, item) => sum + item.amount);
      return _ChartDay(date, income, expense);
    });
    final maxValue = days.fold<int>(
      1,
      (max, item) =>
          [max, item.income, item.expense].reduce((a, b) => a > b ? a : b),
    );
    final axisMaxValue = _niceChartMax(maxValue);
    final yTicks = _buildChartTicks(axisMaxValue);

    return _SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Thống kê 7 ngày',
                  style: AppTextStyles.titleMedium,
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pushNamed(AppRoutes.statistics);
                },
                child: const Text('Chi tiết'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 172,
            child: LayoutBuilder(
              builder: (context, constraints) {
                const axisWidth = 34.0;
                const axisGap = 6.0;

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: axisWidth,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 26),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            for (final tick in yTicks.reversed)
                              Text(
                                _formatChartAxisValue(tick),
                                style: AppTextStyles.labelMedium.copyWith(
                                  fontSize: 9,
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: axisGap),
                    Expanded(
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Padding(
                              padding: const EdgeInsets.only(
                                top: 4,
                                bottom: 26,
                              ),
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  for (final _ in yTicks)
                                    Container(
                                      height: 1,
                                      color: AppColors.outlineVariant
                                          .withValues(alpha: 0.45),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            left: 0,
                            top: 4,
                            bottom: 26,
                            child: Container(
                              width: 1.2,
                              color: AppColors.outlineVariant,
                            ),
                          ),
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 26,
                            child: Container(
                              height: 1.2,
                              color: AppColors.outlineVariant,
                            ),
                          ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              for (final day in days)
                                Expanded(
                                  child: _ChartColumn(
                                    day: day,
                                    maxValue: axisMaxValue,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _MiniLegendItem(color: AppColors.secondary, label: 'Thu nhập'),
              const SizedBox(width: 14),
              _MiniLegendItem(color: AppColors.error, label: 'Chi tiêu'),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _AxisHint(
                label: 'Trục X: ngày',
                icon: Icons.calendar_today_rounded,
              ),
              const SizedBox(width: 8),
              _AxisHint(label: 'Trục Y: VND', icon: Icons.payments_outlined),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniLegendItem extends StatelessWidget {
  const _MiniLegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppTextStyles.labelMedium.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _AxisHint extends StatelessWidget {
  const _AxisHint({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: AppColors.primary),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.primary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentTransactions extends StatelessWidget {
  const _RecentTransactions({required this.transactions});

  final List<AppTransaction> transactions;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Giao dịch gần đây',
                style: AppTextStyles.titleMedium,
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pushNamed(AppRoutes.transactions);
              },
              child: const Text('Xem tất cả'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        _SoftCard(
          padding: EdgeInsets.zero,
          child: transactions.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(18),
                  child: Text(
                    'Chưa có giao dịch. Hãy thêm khoản thu hoặc chi đầu tiên.',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                )
              : Column(
                  children: [
                    for (var index = 0; index < transactions.length; index++)
                      _TransactionTile(
                        transaction: transactions[index],
                        showDivider: index != transactions.length - 1,
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({
    required this.transaction,
    required this.showDivider,
  });

  final AppTransaction transaction;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final meta = categoryMeta(transaction.category, type: transaction.type);
    final isIncome = transaction.type == AppTransactionType.income;
    return InkWell(
      onTap: () {
        Navigator.of(context).pushNamed(
          AppRoutes.transactionDetail,
          arguments: TransactionDetailArgs(transactionId: transaction.id),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          border: showDivider
              ? Border(
                  bottom: BorderSide(
                    color: AppColors.outlineVariant.withValues(alpha: 0.16),
                  ),
                )
              : null,
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: meta.backgroundColor,
              child: Icon(meta.icon, color: meta.color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.title ?? transaction.category,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    formatShortDate(transaction.transactionDate),
                    style: AppTextStyles.labelMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                formatTransactionAmount(transaction),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: AppTextStyles.titleMedium.copyWith(
                  color: isIncome ? AppColors.secondary : AppColors.error,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartColumn extends StatelessWidget {
  const _ChartColumn({required this.day, required this.maxValue});

  final _ChartDay day;
  final int maxValue;

  @override
  Widget build(BuildContext context) {
    final incomeFactor = day.income == 0 ? 0.02 : day.income / maxValue;
    final expenseFactor = day.expense == 0 ? 0.02 : day.expense / maxValue;

    return Stack(
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: 4,
          bottom: 26,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FractionallySizedBox(
                heightFactor: incomeFactor.clamp(0.02, 1),
                alignment: Alignment.bottomCenter,
                child: Container(
                  width: 10,
                  decoration: BoxDecoration(
                    color: AppColors.secondary,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              FractionallySizedBox(
                heightFactor: expenseFactor.clamp(0.02, 1),
                alignment: Alignment.bottomCenter,
                child: Container(
                  width: 10,
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Text(
            '${day.date.day}/${day.date.month}',
            textAlign: TextAlign.center,
            style: AppTextStyles.labelMedium.copyWith(fontSize: 10),
          ),
        ),
      ],
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        color: AppColors.surface,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            const _NavItem(
              label: 'Trang chủ',
              icon: Icons.home_rounded,
              selected: true,
            ),
            _NavItem(
              label: 'Giao dịch',
              icon: Icons.receipt_long_outlined,
              onTap: () {
                Navigator.of(context).pushNamed(AppRoutes.transactions);
              },
            ),
            _NavItem(
              label: 'Thống kê',
              icon: Icons.leaderboard_outlined,
              onTap: () {
                Navigator.of(context).pushNamed(AppRoutes.statistics);
              },
            ),
            _NavItem(
              label: 'Cá nhân',
              icon: Icons.person_outline_rounded,
              onTap: () {
                Navigator.of(context).pushNamed(AppRoutes.profile);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    this.selected = false,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: InkWell(
        onTap: selected ? null : onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: selected
                    ? AppColors.primary
                    : AppColors.onSurfaceVariant,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: AppTextStyles.labelMedium.copyWith(
                  color: selected
                      ? AppColors.primary
                      : AppColors.onSurfaceVariant,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SoftCard extends StatelessWidget {
  const _SoftCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      padding: padding,
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

class _ChartDay {
  const _ChartDay(this.date, this.income, this.expense);

  final DateTime date;
  final int income;
  final int expense;
}

int _niceChartMax(int value) {
  if (value <= 0) return 1;
  final exponent = math.pow(10, value.toString().length - 1).toInt();
  final normalized = value / exponent;
  final nice = normalized <= 1
      ? 1
      : normalized <= 2
      ? 2
      : normalized <= 5
      ? 5
      : 10;
  return nice * exponent;
}

List<num> _buildChartTicks(int maxValue) {
  return List.generate(5, (index) => maxValue * index / 4);
}

String _formatChartAxisValue(num value) {
  final rounded = value.round();
  final absolute = rounded.abs();
  if (absolute >= 1000000000) {
    return '${_trimChartNumber(rounded / 1000000000)}B';
  }
  if (absolute >= 1000000) {
    return '${_trimChartNumber(rounded / 1000000)}M';
  }
  if (absolute >= 1000) return '${_trimChartNumber(rounded / 1000)}K';
  return rounded.toString();
}

String _trimChartNumber(num value) {
  final rounded = (value * 10).round() / 10;
  if (rounded == rounded.roundToDouble()) return rounded.toInt().toString();
  return rounded.toStringAsFixed(1);
}

bool _sameDay(DateTime left, DateTime right) {
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}

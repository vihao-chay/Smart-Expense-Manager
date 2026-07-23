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
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
      children: [
        _BalanceHero(
          balance: balance,
          income: totalIncome,
          expense: totalExpense,
        ),
        const SizedBox(height: 16),
        const _QuickActions(),
        const SizedBox(height: 12),
        const _AiInsightsBanner(),
        const SizedBox(height: 20),
        _MiniStatistics(transactions: transactions),
        const SizedBox(height: 20),
        _RecentTransactions(transactions: recent),
      ],
    );
  }
}

class _BalanceHero extends StatelessWidget {
  const _BalanceHero({
    required this.balance,
    required this.income,
    required this.expense,
  });

  final int balance;
  final int income;
  final int expense;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryContainer,
            AppColors.primary,
            AppColors.tertiary,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Positioned(
              right: -28,
              top: -36,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
            Positioned(
              right: 28,
              bottom: -48,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tổng số dư',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.onPrimaryContainer.withValues(
                        alpha: 0.9,
                      ),
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    formatVnd(balance),
                    style: AppTextStyles.displayCurrency.copyWith(
                      color: Colors.white,
                      fontSize: 34,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.14),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _HeroMetric(
                            label: 'Thu nhập',
                            amount: income,
                            icon: Icons.north_east_rounded,
                            accent: const Color(0xFF86EFAC),
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 36,
                          color: Colors.white.withValues(alpha: 0.18),
                        ),
                        Expanded(
                          child: _HeroMetric(
                            label: 'Chi tiêu',
                            amount: expense,
                            icon: Icons.south_west_rounded,
                            accent: const Color(0xFFFCA5A5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.label,
    required this.amount,
    required this.icon,
    required this.accent,
  });

  final String label;
  final int amount;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: accent),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: Colors.white.withValues(alpha: 0.78),
                  ),
                ),
                Text(
                  formatVnd(amount),
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
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

    final actions = [
      (
        label: 'Thêm thu',
        icon: Icons.add_rounded,
        color: AppColors.income,
        onTap: () => openAddTransaction(AddTransactionType.income),
      ),
      (
        label: 'Thêm chi',
        icon: Icons.remove_rounded,
        color: AppColors.expense,
        onTap: () => openAddTransaction(AddTransactionType.expense),
      ),
      (
        label: 'Đổi tiền',
        icon: Icons.currency_exchange_rounded,
        color: AppColors.primary,
        onTap: () =>
            Navigator.of(context).pushNamed(AppRoutes.currencyConverter),
      ),
      (
        label: 'Ngân sách',
        icon: Icons.pie_chart_outline_rounded,
        color: AppColors.tertiary,
        onTap: () =>
            Navigator.of(context).pushNamed(AppRoutes.budgetManagement),
      ),
    ];

    return _SoftCard(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      child: Row(
        children: [
          for (final action in actions)
            Expanded(
              child: _QuickActionButton(
                label: action.label,
                icon: action.icon,
                color: action.color,
                onTap: action.onTap,
              ),
            ),
        ],
      ),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AiInsightsBanner extends StatelessWidget {
  const _AiInsightsBanner();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.of(context).pushNamed(AppRoutes.aiInsights),
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                AppColors.primary.withValues(alpha: 0.10),
                AppColors.secondaryContainer.withValues(alpha: 0.35),
              ],
            ),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.16),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
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
                      'Gợi ý thông minh',
                      style: AppTextStyles.titleMedium.copyWith(fontSize: 16),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Xem phân tích chi tiêu bằng AI',
                      style: AppTextStyles.labelMedium,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: AppColors.primary,
              ),
            ],
          ),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Thống kê 7 ngày',
                      style: AppTextStyles.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Thu nhập và chi tiêu gần đây',
                      style: AppTextStyles.labelMedium,
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pushNamed(AppRoutes.statistics);
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: const Text('Chi tiết'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 168,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 34,
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
                const SizedBox(width: 6),
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 4, bottom: 26),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              for (final _ in yTicks)
                                Container(
                                  height: 1,
                                  color: AppColors.outlineVariant.withValues(
                                    alpha: 0.35,
                                  ),
                                ),
                            ],
                          ),
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
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _MiniLegendItem(color: AppColors.income, label: 'Thu nhập'),
              const SizedBox(width: 16),
              _MiniLegendItem(color: AppColors.expense, label: 'Chi tiêu'),
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
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Text('Xem tất cả'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        _SoftCard(
          padding: EdgeInsets.zero,
          child: transactions.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 28,
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Icon(
                          Icons.receipt_long_outlined,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Chưa có giao dịch',
                        style: AppTextStyles.titleMedium.copyWith(fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Thêm khoản thu hoặc chi đầu tiên để bắt đầu.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
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
                  color: isIncome ? AppColors.income : AppColors.expense,
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
                    color: AppColors.income,
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
                    color: AppColors.expense,
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
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.16),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
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

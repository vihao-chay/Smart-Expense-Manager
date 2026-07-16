import 'package:flutter/material.dart';

import '../../app/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../add_transaction/add_transaction_screen.dart';
import '../transaction_detail/transaction_detail_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const _transactions = [
    _TransactionItem(
      title: 'Lương tháng 10',
      time: 'Hôm nay, 10:00',
      amount: '+15.000.000 ₫',
      icon: Icons.payments_outlined,
      color: AppColors.secondary,
      tint: Color(0x336DF5E1),
      isIncome: true,
    ),
    _TransactionItem(
      title: 'Ăn trưa',
      time: 'Hôm nay, 12:30',
      amount: '-55.000 ₫',
      icon: Icons.restaurant_outlined,
      color: AppColors.error,
      tint: Color(0x4DFFDAD6),
    ),
    _TransactionItem(
      title: 'Mua sắm siêu thị',
      time: 'Hôm qua, 18:45',
      amount: '-450.000 ₫',
      icon: Icons.shopping_bag_outlined,
      color: AppColors.tertiary,
      tint: Color(0x332F746F),
    ),
    _TransactionItem(
      title: 'Đổ xăng',
      time: '25 Thg 10, 08:15',
      amount: '-80.000 ₫',
      icon: Icons.local_gas_station_outlined,
      color: AppColors.error,
      tint: Color(0x4DFFDAD6),
    ),
    _TransactionItem(
      title: 'Tiền điện',
      time: '24 Thg 10, 15:00',
      amount: '-1.250.000 ₫',
      icon: Icons.bolt_outlined,
      color: AppColors.error,
      tint: Color(0x4DFFDAD6),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Màn thêm giao dịch sẽ được thêm sau.'),
            ),
          );
        },
        backgroundColor: AppColors.primaryContainer,
        foregroundColor: AppColors.onPrimaryContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add_rounded, size: 28),
      ),
      bottomNavigationBar: const _BottomNavBar(),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 768),
            child: Column(
              children: [
                const _HomeTopBar(),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: const [
                      _BalanceSection(),
                      SizedBox(height: 24),
                      _QuickActions(),
                      SizedBox(height: 24),
                      _StatisticsCard(),
                      SizedBox(height: 24),
                      _RecentTransactions(transactions: _transactions),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeTopBar extends StatelessWidget {
  const _HomeTopBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.outlineVariant.withValues(alpha: 0.30),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Image.network(
              'https://lh3.googleusercontent.com/aida-public/AB6AXuBO4JuZ1mcjsgydpQM0EWYqInN9oaBg3D1xDTrIaiUBNek0GUwaxWAeK2uC--c5-v7d0H2HjAdwM4OdQVqb5tw80muYqovlLLCeENhd_BjzOhhzFdZ3Doy-Ut4V504baVel_DXQ7jfPWSWXwsGm6AUPWbQvVfYqTuvS__8kz8wib1fZ67xmS9bLwgc74sSS0nQ6oSqrMIAtwtWBLXEXChn-4slSUgTwEOdCwnqhuokiFl0zyEXZ_Q',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(
                  Icons.person_rounded,
                  color: AppColors.onSurfaceVariant,
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Xin chào,',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                Text(
                  'Nguyễn Minh Khang',
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.titleMedium.copyWith(
                    color: AppColors.onSurface,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Thông báo',
            onPressed: () {
              Navigator.of(context).pushNamed(AppRoutes.notifications);
            },
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(
                  Icons.notifications_none_rounded,
                  color: AppColors.onSurfaceVariant,
                ),
                Positioned(
                  top: 2,
                  right: 3,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.surface),
                    ),
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

class _BalanceSection extends StatelessWidget {
  const _BalanceSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _MainBalanceCard(),
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _AmountSummaryCard(
                label: 'Thu nhập',
                amount: '15.000.000 ₫',
                icon: Icons.arrow_downward_rounded,
                iconColor: AppColors.secondary,
                iconBackground: Color(0x336DF5E1),
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: _AmountSummaryCard(
                label: 'Chi tiêu',
                amount: '8.350.000 ₫',
                icon: Icons.arrow_upward_rounded,
                iconColor: AppColors.error,
                iconBackground: Color(0x80FFDAD6),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MainBalanceCard extends StatelessWidget {
  const _MainBalanceCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.10),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -48,
            right: -36,
            child: _GlowCircle(
              size: 128,
              color: AppColors.primary.withValues(alpha: 0.20),
              blurRadius: 32,
            ),
          ),
          Positioned(
            bottom: -44,
            left: -32,
            child: _GlowCircle(
              size: 96,
              color: AppColors.tertiary.withValues(alpha: 0.20),
              blurRadius: 24,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Tổng số dư',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.onPrimaryContainer.withValues(
                        alpha: 0.90,
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Ẩn/hiện số dư',
                    onPressed: () {},
                    color: AppColors.onPrimaryContainer,
                    iconSize: 20,
                    icon: const Icon(Icons.visibility_outlined),
                  ),
                ],
              ),
              Text(
                '12.500.000 ₫',
                style: AppTextStyles.displayCurrency.copyWith(
                  color: AppColors.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.trending_up_rounded,
                    color: AppColors.secondaryContainer,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '+15%',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.secondaryContainer,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'so với tháng trước',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.onPrimaryContainer.withValues(
                        alpha: 0.80,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AmountSummaryCard extends StatelessWidget {
  const _AmountSummaryCard({
    required this.label,
    required this.amount,
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
  });

  final String label;
  final String amount;
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _RoundIcon(
            icon: icon,
            color: iconColor,
            backgroundColor: iconBackground,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                Text(
                  amount,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.titleMedium.copyWith(color: iconColor),
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
          tint: const Color(0x336DF5E1),
          onTap: () => openAddTransaction(AddTransactionType.income),
        ),
        _QuickActionButton(
          label: 'Thêm chi',
          icon: Icons.remove_circle_outline_rounded,
          color: AppColors.error,
          tint: const Color(0x4DFFDAD6),
          onTap: () => openAddTransaction(AddTransactionType.expense),
        ),
        _QuickActionButton(
          label: 'Chuyển đổi',
          icon: Icons.currency_exchange_rounded,
          color: AppColors.onSurface,
          tint: AppColors.surfaceContainerHighest,
          onTap: () =>
              Navigator.of(context).pushNamed(AppRoutes.currencyConverter),
        ),
        _QuickActionButton(
          label: 'Ngân sách',
          icon: Icons.pie_chart_outline_rounded,
          color: AppColors.tertiary,
          tint: const Color(0x332F746F),
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
    required this.tint,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final Color tint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      padding: const EdgeInsets.all(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _RoundIcon(
              icon: icon,
              color: color,
              backgroundColor: tint,
              size: 48,
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatisticsCard extends StatelessWidget {
  const _StatisticsCard();

  static const _data = [
    _ChartDay('T2', 0.40, 0.20),
    _ChartDay('T3', 0.60, 0.30),
    _ChartDay('T4', 0.10, 0.80),
    _ChartDay('T5', 0.90, 0.40),
    _ChartDay('T6', 0.30, 0.25),
    _ChartDay('T7', 0.15, 0.60),
    _ChartDay('CN', 0.50, 0.70),
  ];

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Thống kê (7 ngày)',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: AppColors.onSurface,
                  ),
                ),
              ),
              const _SegmentedPeriodControl(),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 160,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final day in _data)
                  Expanded(child: _ChartColumn(day: day)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentedPeriodControl extends StatelessWidget {
  const _SegmentedPeriodControl();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          _PeriodChip(label: 'Tuần', selected: true),
          _PeriodChip(label: 'Tháng'),
          _PeriodChip(label: 'Năm'),
        ],
      ),
    );
  }
}

class _PeriodChip extends StatelessWidget {
  const _PeriodChip({required this.label, this.selected = false});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: selected ? AppColors.surface : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Text(
        label,
        style: AppTextStyles.labelMedium.copyWith(
          color: selected ? AppColors.onSurface : AppColors.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _ChartColumn extends StatelessWidget {
  const _ChartColumn({required this.day});

  final _ChartDay day;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FractionallySizedBox(
                heightFactor: day.income,
                alignment: Alignment.bottomCenter,
                child: Container(
                  width: 10,
                  decoration: const BoxDecoration(
                    color: AppColors.secondary,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              FractionallySizedBox(
                heightFactor: day.expense,
                alignment: Alignment.bottomCenter,
                child: Container(
                  width: 10,
                  decoration: const BoxDecoration(
                    color: AppColors.error,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          height: 1,
          color: AppColors.outlineVariant.withValues(alpha: 0.20),
        ),
        const SizedBox(height: 4),
        Text(
          day.label,
          style: AppTextStyles.labelMedium.copyWith(
            color: AppColors.onSurfaceVariant,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

class _RecentTransactions extends StatelessWidget {
  const _RecentTransactions({required this.transactions});

  final List<_TransactionItem> transactions;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Giao dịch gần đây',
                style: AppTextStyles.titleMedium.copyWith(
                  color: AppColors.onSurface,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pushNamed(AppRoutes.transactions);
              },
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                textStyle: AppTextStyles.labelMedium,
              ),
              child: const Text('Xem tất cả'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        _SoftCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < transactions.length; i++)
                _TransactionTile(
                  item: transactions[i],
                  showDivider: i != transactions.length - 1,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.item, required this.showDivider});

  final _TransactionItem item;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.of(context).pushNamed(
            AppRoutes.transactionDetail,
            arguments: item.toDetailArgs(),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            border: showDivider
                ? Border(
                    bottom: BorderSide(
                      color: AppColors.outlineVariant.withValues(alpha: 0.10),
                    ),
                  )
                : null,
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _RoundIcon(
                icon: item.icon,
                color: item.color,
                backgroundColor: item.tint,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      item.time,
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  item.amount,
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.titleMedium.copyWith(
                    color: item.isIncome
                        ? AppColors.secondary
                        : AppColors.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            const _NavItem(
              label: 'Home',
              icon: Icons.home_rounded,
              selected: true,
            ),
            _NavItem(
              label: 'Transactions',
              icon: Icons.receipt_long_outlined,
              onTap: () {
                Navigator.of(context).pushNamed(AppRoutes.transactions);
              },
            ),
            _NavItem(
              label: 'Statistics',
              icon: Icons.leaderboard_outlined,
              onTap: () {
                Navigator.of(context).pushNamed(AppRoutes.statistics);
              },
            ),
            _NavItem(
              label: 'Profile',
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
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? AppColors.secondaryContainer : Colors.transparent,
            borderRadius: selected
                ? BorderRadius.circular(999)
                : BorderRadius.circular(12),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: selected
                      ? AppColors.onSecondaryContainer
                      : AppColors.onSurfaceVariant,
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: selected
                        ? AppColors.onSecondaryContainer
                        : AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
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
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({
    required this.icon,
    required this.color,
    required this.backgroundColor,
    this.size = 40,
  });

  final IconData icon;
  final Color color;
  final Color backgroundColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: backgroundColor, shape: BoxShape.circle),
      child: Icon(icon, color: color, size: size * 0.52),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  const _GlowCircle({
    required this.size,
    required this.color,
    required this.blurRadius,
  });

  final double size;
  final Color color;
  final double blurRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: color, blurRadius: blurRadius, spreadRadius: 8),
        ],
      ),
    );
  }
}

class _ChartDay {
  const _ChartDay(this.label, this.income, this.expense);

  final String label;
  final double income;
  final double expense;
}

class _TransactionItem {
  const _TransactionItem({
    required this.title,
    required this.time,
    required this.amount,
    required this.icon,
    required this.color,
    required this.tint,
    this.isIncome = false,
  });

  final String title;
  final String time;
  final String amount;
  final IconData icon;
  final Color color;
  final Color tint;
  final bool isIncome;

  TransactionDetailArgs toDetailArgs() {
    return TransactionDetailArgs(
      title: title,
      amount: amount,
      transactionType: isIncome ? 'Thu nhập' : 'Chi tiêu',
      category: _category,
      date: _dateText,
      time: _timeText,
      paymentMethod: isIncome ? 'Chuyển khoản' : 'Ví cá nhân',
      note: isIncome
          ? 'Khoản thu nhập được ghi nhận từ tài khoản chính.'
          : 'Giao dịch được ghi nhận từ dashboard.',
      createdAt: _createdAt,
      updatedAt: _createdAt,
      icon: icon,
      accentColor: isIncome ? AppColors.primary : color,
      iconBackgroundColor: tint,
      isIncome: isIncome,
    );
  }

  String get _category {
    if (isIncome) return 'Lương';
    final lowerTitle = title.toLowerCase();
    if (lowerTitle.contains('ăn')) return 'Ăn uống';
    if (lowerTitle.contains('mua')) return 'Mua sắm';
    if (lowerTitle.contains('xăng')) return 'Di chuyển';
    if (lowerTitle.contains('điện')) return 'Nhà cửa';
    return 'Khác';
  }

  String get _dateText {
    if (time.startsWith('Hôm nay')) return 'Hôm nay, 24 Th10 2023';
    if (time.startsWith('Hôm qua')) return 'Hôm qua, 23 Th10 2023';
    return time.split(',').first;
  }

  String get _timeText {
    final parts = time.split(',');
    if (parts.length < 2) return '--:--';
    return parts.last.trim();
  }

  String get _createdAt {
    if (time.startsWith('Hôm nay')) return '24/10/2023 $_timeText';
    if (time.startsWith('Hôm qua')) return '23/10/2023 $_timeText';
    return '24/10/2023 $_timeText';
  }
}

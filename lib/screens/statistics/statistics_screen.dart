import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/app_formatters.dart';
import '../../core/utils/category_catalog.dart';
import '../../data/models/app_transaction.dart';
import '../../data/repositories/firebase_auth_error_mapper.dart';
import '../../data/repositories/firestore_repository.dart';

enum _Period { week, month, year }

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  final _repository = FirestoreRepository();
  var _selectedPeriod = _Period.month;
  var _anchorDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        shadowColor: const Color(0xFF0F172A).withValues(alpha: 0.05),
        centerTitle: true,
        leading: IconButton(
          tooltip: 'Quay lại',
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              Navigator.of(context).pushReplacementNamed(AppRoutes.home);
            }
          },
          icon: const Icon(Icons.arrow_back_rounded),
          color: AppColors.onSurfaceVariant,
        ),
        title: Text(
          'Thống kê',
          style: AppTextStyles.headlineLargeMobile.copyWith(
            color: AppColors.primary,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Tùy chọn',
            onPressed: () {},
            icon: const Icon(Icons.more_vert_rounded),
            color: AppColors.onSurfaceVariant,
          ),
        ],
      ),
      bottomNavigationBar: const _StatisticsBottomNavBar(),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: StreamBuilder<List<AppTransaction>>(
              stream: _repository.watchTransactions(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      firebaseAuthErrorMessage(snapshot.error!),
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                final allTransactions = snapshot.data ?? [];
                final transactions = allTransactions
                    .where(_isInsideSelectedPeriod)
                    .toList();
                final stats = _Stats.fromTransactions(transactions);
                final bars = _buildBars(transactions);
                final categories = _buildCategoryStats(transactions);

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  children: [
                    _TimeFilterSection(
                      selectedPeriod: _selectedPeriod,
                      periodLabel: _periodLabel,
                      onPeriodChanged: (period) {
                        setState(() => _selectedPeriod = period);
                      },
                      onPrevious: () => setState(() {
                        _anchorDate = _shiftAnchor(-1);
                      }),
                      onNext: () => setState(() {
                        _anchorDate = _shiftAnchor(1);
                      }),
                    ),
                    const SizedBox(height: 24),
                    _SummaryGrid(stats: stats),
                    const SizedBox(height: 24),
                    _ChartsSection(
                      bars: bars,
                      categories: categories,
                      totalExpense: stats.expense,
                    ),
                    const SizedBox(height: 24),
                    _TopSpendingCard(
                      categories: categories,
                      totalExpense: stats.expense,
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

  String get _periodLabel {
    return switch (_selectedPeriod) {
      _Period.week => _weekLabel(_anchorDate),
      _Period.month => 'Tháng ${_anchorDate.month}, ${_anchorDate.year}',
      _Period.year => 'Năm ${_anchorDate.year}',
    };
  }

  DateTime _shiftAnchor(int direction) {
    return switch (_selectedPeriod) {
      _Period.week => _anchorDate.add(Duration(days: direction * 7)),
      _Period.month => DateTime(
        _anchorDate.year,
        _anchorDate.month + direction,
        1,
      ),
      _Period.year => DateTime(_anchorDate.year + direction, 1, 1),
    };
  }

  bool _isInsideSelectedPeriod(AppTransaction transaction) {
    final date = transaction.transactionDate;
    return switch (_selectedPeriod) {
      _Period.week =>
        _startOfDay(date).difference(_startOfWeek(_anchorDate)).inDays >= 0 &&
            _startOfDay(date).difference(_startOfWeek(_anchorDate)).inDays < 7,
      _Period.month =>
        date.year == _anchorDate.year && date.month == _anchorDate.month,
      _Period.year => date.year == _anchorDate.year,
    };
  }

  List<_BarPoint> _buildBars(List<AppTransaction> transactions) {
    return switch (_selectedPeriod) {
      _Period.week => _buildWeekBars(transactions),
      _Period.month => _buildMonthBars(transactions),
      _Period.year => _buildYearBars(transactions),
    };
  }

  List<_BarPoint> _buildWeekBars(List<AppTransaction> transactions) {
    final start = _startOfWeek(_anchorDate);
    const labels = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    return List.generate(7, (index) {
      final date = start.add(Duration(days: index));
      final dayTransactions = transactions.where((item) {
        return _sameDay(item.transactionDate, date);
      });
      return _BarPoint(
        labels[index],
        _sumIncome(dayTransactions),
        _sumExpense(dayTransactions),
      );
    });
  }

  List<_BarPoint> _buildMonthBars(List<AppTransaction> transactions) {
    return List.generate(4, (index) {
      final fromDay = index * 7 + 1;
      final toDay = index == 3
          ? DateTime(_anchorDate.year, _anchorDate.month + 1, 0).day
          : (index + 1) * 7;
      final bucket = transactions.where((item) {
        final day = item.transactionDate.day;
        return day >= fromDay && day <= toDay;
      });
      return _BarPoint(
        'T${index + 1}',
        _sumIncome(bucket),
        _sumExpense(bucket),
      );
    });
  }

  List<_BarPoint> _buildYearBars(List<AppTransaction> transactions) {
    return List.generate(12, (index) {
      final month = index + 1;
      final bucket = transactions.where(
        (item) => item.transactionDate.month == month,
      );
      return _BarPoint('T$month', _sumIncome(bucket), _sumExpense(bucket));
    });
  }

  List<_CategoryStat> _buildCategoryStats(List<AppTransaction> transactions) {
    final totals = <String, int>{};
    for (final transaction in transactions) {
      if (transaction.type != AppTransactionType.expense) continue;
      totals.update(
        transaction.category,
        (value) => value + transaction.amount,
        ifAbsent: () => transaction.amount,
      );
    }

    final entries = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.map((entry) {
      return _CategoryStat(
        meta: categoryMeta(entry.key, type: AppTransactionType.expense),
        amount: entry.value,
      );
    }).toList();
  }
}

class _TimeFilterSection extends StatelessWidget {
  const _TimeFilterSection({
    required this.selectedPeriod,
    required this.periodLabel,
    required this.onPeriodChanged,
    required this.onPrevious,
    required this.onNext,
  });

  final _Period selectedPeriod;
  final String periodLabel;
  final ValueChanged<_Period> onPeriodChanged;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PeriodPill(
                label: 'Tuần',
                selected: selectedPeriod == _Period.week,
                onTap: () => onPeriodChanged(_Period.week),
              ),
              _PeriodPill(
                label: 'Tháng',
                selected: selectedPeriod == _Period.month,
                onTap: () => onPeriodChanged(_Period.month),
              ),
              _PeriodPill(
                label: 'Năm',
                selected: selectedPeriod == _Period.year,
                onTap: () => onPeriodChanged(_Period.year),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: 320,
          constraints: const BoxConstraints(maxWidth: double.infinity),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Kỳ trước',
                onPressed: onPrevious,
                icon: const Icon(Icons.chevron_left_rounded),
                color: AppColors.onSurfaceVariant,
              ),
              Expanded(
                child: Text(
                  periodLabel,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.titleMedium,
                ),
              ),
              IconButton(
                tooltip: 'Kỳ sau',
                onPressed: onNext,
                icon: const Icon(Icons.chevron_right_rounded),
                color: AppColors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PeriodPill extends StatelessWidget {
  const _PeriodPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: AppTextStyles.labelMedium.copyWith(
            color: selected
                ? AppColors.onPrimaryContainer
                : AppColors.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.stats});

  final _Stats stats;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;
        return GridView.count(
          crossAxisCount: isWide ? 4 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: isWide ? 1.7 : 1.55,
          children: [
            _MetricCard(
              label: 'Tổng thu nhập',
              amount: formatVnd(stats.income),
              icon: Icons.arrow_downward_rounded,
              color: AppColors.secondary,
            ),
            _MetricCard(
              label: 'Tổng chi tiêu',
              amount: formatVnd(stats.expense),
              icon: Icons.arrow_upward_rounded,
              color: AppColors.error,
            ),
            _MetricCard(
              label: 'Tiền tiết kiệm',
              amount: formatVnd(stats.savings),
              icon: Icons.savings_outlined,
              color: AppColors.primary,
            ),
            _MetricCard(
              label: 'Tỷ lệ tiết kiệm',
              amount: '${stats.savingsRate.toStringAsFixed(1)}%',
              icon: Icons.percent_rounded,
              color: AppColors.tertiary,
            ),
          ],
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.amount,
    required this.icon,
    required this.color,
  });

  final String label;
  final String amount;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              amount,
              style: AppTextStyles.titleMedium.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartsSection extends StatelessWidget {
  const _ChartsSection({
    required this.bars,
    required this.categories,
    required this.totalExpense,
  });

  final List<_BarPoint> bars;
  final List<_CategoryStat> categories;
  final int totalExpense;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;
        final chartCards = [
          _IncomeExpenseChart(bars: bars),
          _CategoryDonutCard(
            categories: categories,
            totalExpense: totalExpense,
          ),
        ];

        if (!isWide) {
          return Column(
            children: [
              chartCards[0],
              const SizedBox(height: 24),
              chartCards[1],
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: chartCards[0]),
            const SizedBox(width: 24),
            Expanded(child: chartCards[1]),
          ],
        );
      },
    );
  }
}

class _IncomeExpenseChart extends StatelessWidget {
  const _IncomeExpenseChart({required this.bars});

  final List<_BarPoint> bars;

  @override
  Widget build(BuildContext context) {
    final maxValue = bars.fold<int>(1, (max, item) {
      return math.max(max, math.max(item.income, item.expense));
    });

    return _SoftCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Thu nhập vs Chi tiêu', style: AppTextStyles.titleMedium),
          const SizedBox(height: 16),
          Container(
            height: 192,
            padding: const EdgeInsets.fromLTRB(8, 20, 8, 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final point in bars)
                  Expanded(
                    child: _BarGroup(point: point, maxValue: maxValue),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              _LegendItem(color: AppColors.secondary, label: 'Thu nhập'),
              SizedBox(width: 18),
              _LegendItem(color: AppColors.error, label: 'Chi tiêu'),
            ],
          ),
        ],
      ),
    );
  }
}

class _BarGroup extends StatelessWidget {
  const _BarGroup({required this.point, required this.maxValue});

  final _BarPoint point;
  final int maxValue;

  @override
  Widget build(BuildContext context) {
    final incomeHeight = _barFactor(point.income, maxValue);
    final expenseHeight = _barFactor(point.expense, maxValue);

    return Column(
      children: [
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FractionallySizedBox(
                heightFactor: incomeHeight,
                alignment: Alignment.bottomCenter,
                child: Container(
                  width: 12,
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
                heightFactor: expenseHeight,
                alignment: Alignment.bottomCenter,
                child: Container(
                  width: 12,
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
        const SizedBox(height: 8),
        Text(
          point.label,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.labelMedium.copyWith(fontSize: 10),
        ),
      ],
    );
  }

  double _barFactor(int value, int maxValue) {
    if (value <= 0) return 0.02;
    return (value / maxValue).clamp(0.08, 1);
  }
}

class _CategoryDonutCard extends StatelessWidget {
  const _CategoryDonutCard({
    required this.categories,
    required this.totalExpense,
  });

  final List<_CategoryStat> categories;
  final int totalExpense;

  @override
  Widget build(BuildContext context) {
    final visibleCategories = categories.take(4).toList();

    return _SoftCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Danh mục chi tiêu', style: AppTextStyles.titleMedium),
          const SizedBox(height: 12),
          SizedBox(
            height: 192,
            child: Center(
              child: SizedBox(
                width: 148,
                height: 148,
                child: CustomPaint(
                  painter: _DonutChartPainter(
                    categories: visibleCategories,
                    total: totalExpense,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          totalExpense == 0 ? '0%' : '100%',
                          style: AppTextStyles.titleMedium,
                        ),
                        Text('Chi tiêu', style: AppTextStyles.labelMedium),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (visibleCategories.isEmpty)
            Center(
              child: Text(
                'Chưa có chi tiêu',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            )
          else
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 8,
              children: [
                for (final item in visibleCategories)
                  _LegendItem(
                    color: item.meta.color,
                    label:
                        '${item.meta.label} (${_percentText(item.amount, totalExpense)})',
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _TopSpendingCard extends StatelessWidget {
  const _TopSpendingCard({
    required this.categories,
    required this.totalExpense,
  });

  final List<_CategoryStat> categories;
  final int totalExpense;

  @override
  Widget build(BuildContext context) {
    final top = categories.take(5).toList();

    return _SoftCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Chi tiêu nhiều nhất',
                  style: AppTextStyles.titleMedium,
                ),
              ),
              TextButton(onPressed: () {}, child: const Text('Xem tất cả')),
            ],
          ),
          const SizedBox(height: 8),
          if (top.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Chưa có dữ liệu chi tiêu trong kỳ này.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            )
          else
            for (final item in top) ...[
              _TopCategoryRow(
                item: item,
                percent: totalExpense == 0 ? 0 : item.amount / totalExpense,
              ),
              const SizedBox(height: 16),
            ],
        ],
      ),
    );
  }
}

class _TopCategoryRow extends StatelessWidget {
  const _TopCategoryRow({required this.item, required this.percent});

  final _CategoryStat item;
  final double percent;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: item.meta.backgroundColor,
              child: Icon(item.meta.icon, color: item.meta.color, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                item.meta.label,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              formatVnd(item.amount),
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: percent.clamp(0, 1),
            minHeight: 8,
            color: item.meta.color,
            backgroundColor: AppColors.surfaceContainerLow,
          ),
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
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

class _StatisticsBottomNavBar extends StatelessWidget {
  const _StatisticsBottomNavBar();

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
            _NavItem(
              label: 'Home',
              icon: Icons.home_outlined,
              onTap: () {
                Navigator.of(context).pushReplacementNamed(AppRoutes.home);
              },
            ),
            _NavItem(
              label: 'Transactions',
              icon: Icons.receipt_long_outlined,
              onTap: () {
                Navigator.of(
                  context,
                ).pushReplacementNamed(AppRoutes.transactions);
              },
            ),
            const _NavItem(
              label: 'Statistics',
              icon: Icons.leaderboard_rounded,
              selected: true,
            ),
            _NavItem(
              label: 'Profile',
              icon: Icons.person_outline_rounded,
              onTap: () {
                Navigator.of(context).pushReplacementNamed(AppRoutes.profile);
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: EdgeInsets.symmetric(
            horizontal: selected ? 14 : 8,
            vertical: selected ? 5 : 6,
          ),
          decoration: BoxDecoration(
            color: selected ? AppColors.secondaryContainer : Colors.transparent,
            borderRadius: selected
                ? BorderRadius.circular(999)
                : BorderRadius.circular(12),
          ),
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
              FittedBox(
                child: Text(
                  label,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: selected
                        ? AppColors.onSecondaryContainer
                        : AppColors.onSurfaceVariant,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
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

class _DonutChartPainter extends CustomPainter {
  const _DonutChartPainter({required this.categories, required this.total});

  final List<_CategoryStat> categories;
  final int total;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final strokeWidth = size.shortestSide * 0.16;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    paint.color = AppColors.surfaceContainerLow;
    canvas.drawArc(
      rect.deflate(strokeWidth / 2),
      -math.pi / 2,
      math.pi * 2,
      false,
      paint,
    );

    if (total <= 0 || categories.isEmpty) return;

    var startAngle = -math.pi / 2;
    for (final category in categories) {
      final sweepAngle = (category.amount / total) * math.pi * 2;
      paint.color = category.meta.color;
      canvas.drawArc(
        rect.deflate(strokeWidth / 2),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.categories != categories || oldDelegate.total != total;
  }
}

class _Stats {
  const _Stats({required this.income, required this.expense});

  factory _Stats.fromTransactions(List<AppTransaction> transactions) {
    return _Stats(
      income: _sumIncome(transactions),
      expense: _sumExpense(transactions),
    );
  }

  final int income;
  final int expense;

  int get savings => income - expense;

  double get savingsRate => income == 0 ? 0 : (savings / income) * 100;
}

class _BarPoint {
  const _BarPoint(this.label, this.income, this.expense);

  final String label;
  final int income;
  final int expense;
}

class _CategoryStat {
  const _CategoryStat({required this.meta, required this.amount});

  final CategoryMeta meta;
  final int amount;
}

int _sumIncome(Iterable<AppTransaction> transactions) {
  return transactions
      .where((item) => item.type == AppTransactionType.income)
      .fold<int>(0, (sum, item) => sum + item.amount);
}

int _sumExpense(Iterable<AppTransaction> transactions) {
  return transactions
      .where((item) => item.type == AppTransactionType.expense)
      .fold<int>(0, (sum, item) => sum + item.amount);
}

DateTime _startOfWeek(DateTime date) {
  final start = DateTime(date.year, date.month, date.day);
  return start.subtract(Duration(days: start.weekday - 1));
}

DateTime _startOfDay(DateTime date) {
  return DateTime(date.year, date.month, date.day);
}

bool _sameDay(DateTime left, DateTime right) {
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}

String _weekLabel(DateTime date) {
  final start = _startOfWeek(date);
  final end = start.add(const Duration(days: 6));
  return '${start.day}/${start.month} - ${end.day}/${end.month}, ${end.year}';
}

String _percentText(int amount, int total) {
  if (total <= 0) return '0%';
  return '${((amount / total) * 100).round()}%';
}

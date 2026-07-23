import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

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
import '../../data/repositories/storage_repository.dart';
import '../transactions/transactions_screen.dart';

enum _Period { week, month, year }

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  final _repository = FirestoreRepository();
  final _storageRepository = StorageRepository();
  var _selectedPeriod = _Period.month;
  var _anchorDate = DateTime.now();
  var _isExportingPdf = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      bottomNavigationBar: const _StatisticsBottomNavBar(),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: StreamBuilder<AppUserProfile?>(
              stream: _repository.watchProfile(),
              builder: (context, snapshot) {
                return Column(
                  children: [
                    AppTopBar(profile: snapshot.data),
                    Expanded(
                      child: StreamBuilder<List<AppTransaction>>(
                        stream: _repository.watchTransactions(),
                        builder: (context, transactionSnapshot) {
                          if (transactionSnapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          if (transactionSnapshot.hasError) {
                            return Center(
                              child: Text(
                                firebaseAuthErrorMessage(
                                  transactionSnapshot.error!,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            );
                          }

                          final allTransactions =
                              transactionSnapshot.data ?? [];
                          final transactions = allTransactions
                              .where(_isInsideSelectedPeriod)
                              .toList();
                          final stats = _Stats.fromTransactions(transactions);
                          final bars = _buildBars(transactions);
                          final categories = _buildCategoryStats(transactions);
                          final profile = snapshot.data;

                          return ListView(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                            children: [
                              _PeriodToolbar(
                                selectedPeriod: _selectedPeriod,
                                periodLabel: _periodLabel,
                                isExportingPdf: _isExportingPdf,
                                onPeriodChanged: (period) {
                                  setState(() => _selectedPeriod = period);
                                },
                                onPrevious: () => setState(() {
                                  _anchorDate = _shiftAnchor(-1);
                                }),
                                onNext: () => setState(() {
                                  _anchorDate = _shiftAnchor(1);
                                }),
                                onExportPdf: () => _exportPdfReport(
                                  profile: profile,
                                  transactions: transactions,
                                  stats: stats,
                                  bars: bars,
                                  categories: categories,
                                ),
                              ),
                              const SizedBox(height: 14),
                              _ChartsSection(
                                bars: bars,
                                categories: categories,
                                totalExpense: stats.expense,
                                hasData: transactions.isNotEmpty,
                              ),
                              const SizedBox(height: 14),
                              _TopSpendingCard(
                                categories: categories,
                                totalExpense: stats.expense,
                              ),
                            ],
                          );
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
    const labels = ['Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7', 'CN'];
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
        '$fromDay-$toDay',
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
      return _BarPoint('Th$month', _sumIncome(bucket), _sumExpense(bucket));
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

  Future<void> _exportPdfReport({
    required AppUserProfile? profile,
    required List<AppTransaction> transactions,
    required _Stats stats,
    required List<_BarPoint> bars,
    required List<_CategoryStat> categories,
  }) async {
    if (_isExportingPdf) return;
    setState(() => _isExportingPdf = true);

    try {
      final fileName = _pdfFileName;
      final periodLabel = _pdfPeriodLabel;
      final bytes = await _buildStatisticsPdf(
        profile: profile,
        periodLabel: periodLabel,
        transactions: transactions,
        stats: stats,
        bars: bars,
        categories: categories,
      );

      final uploadResult = await _storageRepository.uploadReportPdf(
        bytes: bytes,
        fileName: fileName,
        fullName: profile?.fullName ?? '',
      );

      await _repository.createStatisticsReportDocument(
        title: 'Báo cáo thống kê $periodLabel',
        description:
            'Báo cáo được xuất từ trang Thống kê trên mobile Smart Expense.',
        fileName: fileName,
        fileUrl: uploadResult.downloadUrl,
        storagePath: uploadResult.storagePath,
        periodLabel: periodLabel,
        profile: profile,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã xuất PDF lên Firebase. Web admin có thể quản lý.'),
        ),
      );

      try {
        await Printing.sharePdf(
          bytes: bytes,
          filename: fileName,
          subject: 'Bao cao thong ke Smart Expense',
          body: 'Bao cao thong ke tai chinh ca nhan tu Smart Expense.',
        );
      } catch (shareError) {
        debugPrint('Cannot open PDF share sheet: $shareError');
      }
    } catch (error, stackTrace) {
      debugPrint('Export statistics PDF failed: $error\n$stackTrace');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_pdfExportErrorMessage(error))));
    } finally {
      if (mounted) setState(() => _isExportingPdf = false);
    }
  }

  String get _pdfPeriodLabel {
    return switch (_selectedPeriod) {
      _Period.week => _pdfWeekLabel(_anchorDate),
      _Period.month => 'Tháng ${_anchorDate.month}/${_anchorDate.year}',
      _Period.year => 'Năm ${_anchorDate.year}',
    };
  }

  String get _pdfFileName {
    final period = switch (_selectedPeriod) {
      _Period.week =>
        'tuan_${_startOfWeek(_anchorDate).millisecondsSinceEpoch}',
      _Period.month =>
        '${_anchorDate.year}_${_anchorDate.month.toString().padLeft(2, '0')}',
      _Period.year => '${_anchorDate.year}',
    };
    return 'smart_expense_report_${period}_${DateTime.now().millisecondsSinceEpoch}.pdf';
  }
}

class _PeriodToolbar extends StatelessWidget {
  const _PeriodToolbar({
    required this.selectedPeriod,
    required this.periodLabel,
    required this.isExportingPdf,
    required this.onPeriodChanged,
    required this.onPrevious,
    required this.onNext,
    required this.onExportPdf,
  });

  final _Period selectedPeriod;
  final String periodLabel;
  final bool isExportingPdf;
  final ValueChanged<_Period> onPeriodChanged;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onExportPdf;

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      for (final period in _Period.values)
                        Expanded(
                          child: _PeriodPill(
                            label: switch (period) {
                              _Period.week => 'Tuần',
                              _Period.month => 'Tháng',
                              _Period.year => 'Năm',
                            },
                            selected: selectedPeriod == period,
                            onTap: () => onPeriodChanged(period),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: isExportingPdf ? 'Đang xuất PDF…' : 'Xuất PDF',
                onPressed: isExportingPdf ? null : onExportPdf,
                style: IconButton.styleFrom(
                  foregroundColor: AppColors.onSurfaceVariant,
                  disabledForegroundColor: AppColors.primary,
                  backgroundColor: AppColors.surfaceContainerLow,
                  disabledBackgroundColor: AppColors.surfaceContainerLow,
                  overlayColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  fixedSize: const Size(44, 44),
                  padding: EdgeInsets.zero,
                ),
                icon: isExportingPdf
                    ? SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: AppColors.primary,
                        ),
                      )
                    : const Icon(Icons.picture_as_pdf_rounded),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              IconButton(
                tooltip: 'Kỳ trước',
                onPressed: onPrevious,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.chevron_left_rounded),
                color: AppColors.primary,
              ),
              Expanded(
                child: Text(
                  periodLabel,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.titleMedium.copyWith(fontSize: 16),
                ),
              ),
              IconButton(
                tooltip: 'Kỳ sau',
                onPressed: onNext,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.chevron_right_rounded),
                color: AppColors.primary,
              ),
            ],
          ),
        ],
      ),
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
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppTextStyles.labelMedium.copyWith(
            color: selected
                ? AppColors.onPrimaryContainer
                : AppColors.onSurfaceVariant,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _ChartsSection extends StatelessWidget {
  const _ChartsSection({
    required this.bars,
    required this.categories,
    required this.totalExpense,
    required this.hasData,
  });

  final List<_BarPoint> bars;
  final List<_CategoryStat> categories;
  final int totalExpense;
  final bool hasData;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;
        final barChart = _IncomeExpenseChart(bars: bars, hasData: hasData);
        final lineChart = _BalanceLineChart(bars: bars, hasData: hasData);
        final donutChart = _CategoryDonutCard(
          categories: categories,
          totalExpense: totalExpense,
        );

        if (!isWide) {
          return Column(
            children: [
              barChart,
              const SizedBox(height: 16),
              lineChart,
              const SizedBox(height: 16),
              donutChart,
            ],
          );
        }

        return Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: barChart),
                const SizedBox(width: 16),
                Expanded(child: donutChart),
              ],
            ),
            const SizedBox(height: 16),
            lineChart,
          ],
        );
      },
    );
  }
}

class _IncomeExpenseChart extends StatefulWidget {
  const _IncomeExpenseChart({required this.bars, required this.hasData});

  final List<_BarPoint> bars;
  final bool hasData;

  @override
  State<_IncomeExpenseChart> createState() => _IncomeExpenseChartState();
}

class _IncomeExpenseChartState extends State<_IncomeExpenseChart> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maxValue = widget.bars.fold<int>(1, (max, item) {
      return math.max(max, math.max(item.income, item.expense));
    });
    final axisMaxValue = _niceChartMax(maxValue);
    final yTicks = _buildChartTicks(axisMaxValue);

    return _SoftCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Thu nhập vs Chi tiêu', style: AppTextStyles.titleMedium),
          const SizedBox(height: 4),
          Text(
            'So sánh theo kỳ đã chọn',
            style: AppTextStyles.labelMedium,
          ),
          const SizedBox(height: 16),
          if (!widget.hasData)
            const _ChartEmptyState(
              message: 'Chưa có giao dịch trong kỳ này để vẽ biểu đồ.',
            )
          else
            LayoutBuilder(
            builder: (context, constraints) {
              const axisWidth = 42.0;
              const axisGap = 8.0;
              final viewportWidth = math
                  .max(constraints.maxWidth - axisWidth - axisGap, 0)
                  .toDouble();
              final chartWidth = math
                  .max(viewportWidth, widget.bars.length * 52.0)
                  .toDouble();
              final canScroll = chartWidth > viewportWidth;

              return Container(
                height: 228,
                padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: axisWidth,
                      child: Padding(
                        padding: EdgeInsets.only(
                          top: 4,
                          bottom: canScroll ? 42 : 28,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            for (final tick in yTicks.reversed)
                              Text(
                                _formatChartAxisValue(tick),
                                style: AppTextStyles.labelMedium.copyWith(
                                  fontSize: 10,
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: axisGap),
                    Expanded(
                      child: Scrollbar(
                        controller: _scrollController,
                        thumbVisibility: canScroll,
                        trackVisibility: canScroll,
                        radius: const Radius.circular(999),
                        thickness: 4,
                        scrollbarOrientation: ScrollbarOrientation.bottom,
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: chartWidth,
                            child: Padding(
                              padding: EdgeInsets.only(
                                bottom: canScroll ? 14 : 0,
                              ),
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: Padding(
                                      padding: const EdgeInsets.only(
                                        top: 4,
                                        bottom: 28,
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          for (final _ in yTicks)
                                            Container(
                                              height: 1,
                                              color: AppColors.outlineVariant
                                                  .withValues(alpha: 0.35),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      for (final point in widget.bars)
                                        Expanded(
                                          child: _BarGroup(
                                            point: point,
                                            maxValue: axisMaxValue,
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          if (widget.hasData) ...[
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _LegendItem(color: AppColors.income, label: 'Thu nhập'),
                const SizedBox(width: 18),
                _LegendItem(color: AppColors.expense, label: 'Chi tiêu'),
              ],
            ),
          ],
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
                heightFactor: expenseHeight,
                alignment: Alignment.bottomCenter,
                child: Container(
                  width: 12,
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

class _BalanceLineChart extends StatefulWidget {
  const _BalanceLineChart({required this.bars, required this.hasData});

  final List<_BarPoint> bars;
  final bool hasData;

  @override
  State<_BalanceLineChart> createState() => _BalanceLineChartState();
}

class _BalanceLineChartState extends State<_BalanceLineChart> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final values = widget.bars.map((item) => item.balance).toList();
    final bounds = _buildLineChartBounds(values);
    final ticks = _buildChartTicksBetween(bounds.min, bounds.max);

    return _SoftCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Xu hướng số dư', style: AppTextStyles.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Theo dõi biến động qua kỳ',
            style: AppTextStyles.labelMedium,
          ),
          const SizedBox(height: 16),
          if (!widget.hasData)
            const _ChartEmptyState(
              message: 'Thêm giao dịch để xem xu hướng số dư.',
            )
          else
            LayoutBuilder(
            builder: (context, constraints) {
              const axisWidth = 42.0;
              const axisGap = 8.0;
              final viewportWidth = math
                  .max(constraints.maxWidth - axisWidth - axisGap, 0)
                  .toDouble();
              final chartWidth = math
                  .max(viewportWidth, widget.bars.length * 52.0)
                  .toDouble();
              final canScroll = chartWidth > viewportWidth;

              return Container(
                height: 228,
                padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: axisWidth,
                      child: Padding(
                        padding: EdgeInsets.only(
                          top: 4,
                          bottom: canScroll ? 42 : 28,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            for (final tick in ticks.reversed)
                              Text(
                                _formatChartAxisValue(tick),
                                style: AppTextStyles.labelMedium.copyWith(
                                  fontSize: 10,
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: axisGap),
                    Expanded(
                      child: Scrollbar(
                        controller: _scrollController,
                        thumbVisibility: canScroll,
                        trackVisibility: canScroll,
                        radius: const Radius.circular(999),
                        thickness: 4,
                        scrollbarOrientation: ScrollbarOrientation.bottom,
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: chartWidth,
                            child: Padding(
                              padding: EdgeInsets.only(
                                bottom: canScroll ? 14 : 0,
                              ),
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: Padding(
                                      padding: const EdgeInsets.only(
                                        top: 4,
                                        bottom: 28,
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          for (final _ in ticks)
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
                                    bottom: 28,
                                    child: Container(
                                      width: 1.2,
                                      color: AppColors.outlineVariant,
                                    ),
                                  ),
                                  Positioned.fill(
                                    child: Padding(
                                      padding: const EdgeInsets.only(
                                        top: 4,
                                        bottom: 28,
                                      ),
                                      child: CustomPaint(
                                        painter: _LineChartPainter(
                                          values: values,
                                          minValue: bounds.min,
                                          maxValue: bounds.max,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    bottom: 0,
                                    height: 24,
                                    child: Row(
                                      children: [
                                        for (final point in widget.bars)
                                          Expanded(
                                            child: Center(
                                              child: Text(
                                                point.label,
                                                overflow: TextOverflow.ellipsis,
                                                style: AppTextStyles.labelMedium
                                                    .copyWith(fontSize: 10),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          if (widget.hasData) ...[
            const SizedBox(height: 14),
            Center(
              child: _LegendItem(color: AppColors.primary, label: 'Số dư'),
            ),
          ],
        ],
      ),
    );
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
    final visibleCategories = categories;

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
              TextButton(
                onPressed: () {
                  Navigator.of(context).pushReplacementNamed(
                    AppRoutes.transactions,
                    arguments: const TransactionsArgs(
                      initialType: AppTransactionType.expense,
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: const Text('Xem tất cả'),
              ),
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
        decoration: BoxDecoration(color: AppColors.surface),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(
              label: 'Trang chủ',
              icon: Icons.home_outlined,
              onTap: () {
                Navigator.of(context).pushReplacementNamed(AppRoutes.home);
              },
            ),
            _NavItem(
              label: 'Giao dịch',
              icon: Icons.receipt_long_outlined,
              onTap: () {
                Navigator.of(
                  context,
                ).pushReplacementNamed(AppRoutes.transactions);
              },
            ),
            const _NavItem(
              label: 'Thống kê',
              icon: Icons.leaderboard_rounded,
              selected: true,
            ),
            _NavItem(
              label: 'Cá nhân',
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
              FittedBox(
                child: Text(
                  label,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: selected
                        ? AppColors.primary
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

class _ChartEmptyState extends StatelessWidget {
  const _ChartEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(
            Icons.insert_chart_outlined_rounded,
            size: 36,
            color: AppColors.onSurfaceVariant,
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.labelMedium,
          ),
        ],
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
      clipBehavior: Clip.antiAlias,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.14),
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

class _LineChartPainter extends CustomPainter {
  const _LineChartPainter({
    required this.values,
    required this.minValue,
    required this.maxValue,
  });

  final List<int> values;
  final num minValue;
  final num maxValue;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final range = maxValue - minValue == 0 ? 1 : maxValue - minValue;
    const horizontalPadding = 8.0;
    final plotWidth = math.max(size.width - horizontalPadding * 2, 1);
    final points = <Offset>[];
    for (var index = 0; index < values.length; index++) {
      final x = values.length == 1
          ? size.width / 2
          : horizontalPadding + (plotWidth / (values.length - 1)) * index;
      final y =
          size.height - ((values[index] - minValue) / range) * size.height;
      points.add(Offset(x, y.toDouble()));
    }

    if (minValue < 0 && maxValue > 0) {
      final zeroY = size.height - ((0 - minValue) / range) * size.height;
      final zeroPaint = Paint()
        ..color = AppColors.outlineVariant.withValues(alpha: 0.70)
        ..strokeWidth = 1.4;
      canvas.drawLine(
        Offset(horizontalPadding, zeroY.toDouble()),
        Offset(size.width - horizontalPadding, zeroY.toDouble()),
        zeroPaint,
      );
    }

    if (points.length > 1) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      final linePaint = Paint()
        ..color = AppColors.primary
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      canvas.drawPath(path, linePaint);
    }

    final dotFill = Paint()
      ..color = AppColors.surfaceContainerLowest
      ..style = PaintingStyle.fill;
    final dotStroke = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 2.8
      ..style = PaintingStyle.stroke;

    for (final point in points) {
      canvas.drawCircle(point, 4.5, dotFill);
      canvas.drawCircle(point, 4.5, dotStroke);
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.minValue != minValue ||
        oldDelegate.maxValue != maxValue;
  }
}

Future<Uint8List> _buildStatisticsPdf({
  required AppUserProfile? profile,
  required String periodLabel,
  required List<AppTransaction> transactions,
  required _Stats stats,
  required List<_BarPoint> bars,
  required List<_CategoryStat> categories,
}) async {
  final pdf = pw.Document(
    title: 'Smart Expense Statistics Report',
    author: 'Smart Expense Manager',
  );
  final recentTransactions = [...transactions]
    ..sort((a, b) => b.transactionDate.compareTo(a.transactionDate));

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      footer: (context) {
        return pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Page ${context.pageNumber}/${context.pagesCount}',
            style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        );
      },
      build: (context) {
        return [
          pw.Text(
            'SMART EXPENSE MANAGER',
            style: pw.TextStyle(
              color: PdfColors.teal800,
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'Bao cao thong ke tai chinh',
            style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Ky thong ke: ${_safePdfText(periodLabel)}',
            style: const pw.TextStyle(fontSize: 12),
          ),
          pw.Text(
            'Nguoi dung: ${_safePdfText(profile?.fullName ?? 'Nguoi dung')}'
            '${profile?.email.trim().isNotEmpty == true ? ' - ${profile!.email}' : ''}',
            style: const pw.TextStyle(fontSize: 12),
          ),
          pw.Text(
            'Ngay xuat: ${_formatPdfDate(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 12),
          ),
          pw.SizedBox(height: 18),
          pw.Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _pdfMetric('Tong thu', _formatPdfVnd(stats.income)),
              _pdfMetric('Tong chi', _formatPdfVnd(stats.expense)),
              _pdfMetric('So du', _formatPdfVnd(stats.savings)),
              _pdfMetric(
                'Ty le tiet kiem',
                '${stats.savingsRate.toStringAsFixed(1)}%',
              ),
            ],
          ),
          pw.SizedBox(height: 22),
          _pdfSectionTitle('Thu chi theo ky'),
          _pdfTable(
            headers: const ['Moc', 'Thu', 'Chi', 'So du'],
            rows: bars
                .map(
                  (item) => [
                    _safePdfText(item.label),
                    _formatPdfVnd(item.income),
                    _formatPdfVnd(item.expense),
                    _formatPdfVnd(item.balance),
                  ],
                )
                .toList(),
            emptyText: 'Khong co du lieu thu chi.',
          ),
          pw.SizedBox(height: 18),
          _pdfSectionTitle('Top danh muc chi tieu'),
          _pdfTable(
            headers: const ['Danh muc', 'So tien', 'Ty trong'],
            rows: categories
                .map(
                  (item) => [
                    _safePdfText(item.meta.label),
                    _formatPdfVnd(item.amount),
                    _percentText(item.amount, stats.expense),
                  ],
                )
                .toList(),
            emptyText: 'Khong co du lieu chi tieu.',
          ),
          pw.SizedBox(height: 18),
          _pdfSectionTitle('Giao dich gan nhat'),
          _pdfTable(
            headers: const ['Ngay', 'Loai', 'Danh muc', 'Tieu de', 'So tien'],
            rows: recentTransactions
                .take(12)
                .map(
                  (item) => [
                    _formatPdfDate(item.transactionDate),
                    item.type == AppTransactionType.income ? 'Thu' : 'Chi',
                    _safePdfText(item.category),
                    _safePdfText(item.title ?? item.note ?? '-'),
                    _formatPdfVnd(
                      item.type == AppTransactionType.income
                          ? item.amount
                          : -item.amount,
                    ),
                  ],
                )
                .toList(),
            emptyText: 'Khong co giao dich trong ky nay.',
          ),
        ];
      },
    ),
  );

  return pdf.save();
}

pw.Widget _pdfMetric(String label, String value) {
  return pw.Container(
    width: 126,
    padding: const pw.EdgeInsets.all(10),
    decoration: pw.BoxDecoration(
      color: PdfColors.teal50,
      border: pw.Border.all(color: PdfColors.teal100),
      borderRadius: pw.BorderRadius.circular(8),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 5),
        pw.Text(
          value,
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
      ],
    ),
  );
}

pw.Widget _pdfSectionTitle(String title) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 8),
    child: pw.Text(
      title,
      style: pw.TextStyle(
        color: PdfColors.teal800,
        fontSize: 15,
        fontWeight: pw.FontWeight.bold,
      ),
    ),
  );
}

pw.Widget _pdfTable({
  required List<String> headers,
  required List<List<String>> rows,
  required String emptyText,
}) {
  if (rows.isEmpty) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Text(emptyText, style: const pw.TextStyle(fontSize: 11)),
    );
  }

  return pw.TableHelper.fromTextArray(
    headers: headers,
    data: rows,
    border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
    headerDecoration: const pw.BoxDecoration(color: PdfColors.teal100),
    headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
    cellStyle: const pw.TextStyle(fontSize: 9),
    cellAlignment: pw.Alignment.centerLeft,
    headerAlignment: pw.Alignment.centerLeft,
    cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
  );
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

  int get balance => income - expense;
}

class _ChartBounds {
  const _ChartBounds({required this.min, required this.max});

  final num min;
  final num max;
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

String _pdfWeekLabel(DateTime date) {
  final start = _startOfWeek(date);
  final end = start.add(const Duration(days: 6));
  return 'Tuần ${_formatPdfDate(start)} - ${_formatPdfDate(end)}';
}

String _formatPdfDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';
}

String _formatPdfVnd(num value) {
  final rounded = value.round();
  final sign = rounded < 0 ? '-' : '';
  final digits = rounded.abs().toString();
  final buffer = StringBuffer();

  for (var index = 0; index < digits.length; index++) {
    final positionFromEnd = digits.length - index;
    buffer.write(digits[index]);
    if (positionFromEnd > 1 && positionFromEnd % 3 == 1) {
      buffer.write('.');
    }
  }

  return '$sign${buffer.toString()} VND';
}

String _pdfExportErrorMessage(Object error) {
  final details = error.toString();
  if (details.contains('permission-denied') ||
      details.contains('unauthorized')) {
    return 'Firebase Rules đang chặn xuất PDF. Hãy deploy firestore.rules và storage.rules mới.';
  }
  if (details.contains('MissingPluginException')) {
    return 'Bạn cần dừng app rồi chạy lại flutter run sau khi thêm package PDF.';
  }

  final mapped = firebaseAuthErrorMessage(error);
  if (mapped.contains('Đã có lỗi')) {
    return 'Không xuất được PDF. Vui lòng thử lại sau.';
  }
  return mapped;
}

String _safePdfText(String value) {
  final replacements = <String, String>{
    'à': 'a',
    'á': 'a',
    'ả': 'a',
    'ã': 'a',
    'ạ': 'a',
    'ă': 'a',
    'ằ': 'a',
    'ắ': 'a',
    'ẳ': 'a',
    'ẵ': 'a',
    'ặ': 'a',
    'â': 'a',
    'ầ': 'a',
    'ấ': 'a',
    'ẩ': 'a',
    'ẫ': 'a',
    'ậ': 'a',
    'è': 'e',
    'é': 'e',
    'ẻ': 'e',
    'ẽ': 'e',
    'ẹ': 'e',
    'ê': 'e',
    'ề': 'e',
    'ế': 'e',
    'ể': 'e',
    'ễ': 'e',
    'ệ': 'e',
    'ì': 'i',
    'í': 'i',
    'ỉ': 'i',
    'ĩ': 'i',
    'ị': 'i',
    'ò': 'o',
    'ó': 'o',
    'ỏ': 'o',
    'õ': 'o',
    'ọ': 'o',
    'ô': 'o',
    'ồ': 'o',
    'ố': 'o',
    'ổ': 'o',
    'ỗ': 'o',
    'ộ': 'o',
    'ơ': 'o',
    'ờ': 'o',
    'ớ': 'o',
    'ở': 'o',
    'ỡ': 'o',
    'ợ': 'o',
    'ù': 'u',
    'ú': 'u',
    'ủ': 'u',
    'ũ': 'u',
    'ụ': 'u',
    'ư': 'u',
    'ừ': 'u',
    'ứ': 'u',
    'ử': 'u',
    'ữ': 'u',
    'ự': 'u',
    'ỳ': 'y',
    'ý': 'y',
    'ỷ': 'y',
    'ỹ': 'y',
    'ỵ': 'y',
    'đ': 'd',
  };

  final buffer = StringBuffer();
  for (final rune in value.runes) {
    final char = String.fromCharCode(rune);
    final lower = char.toLowerCase();
    final replacement = replacements[lower];
    if (replacement == null) {
      buffer.write(char.codeUnitAt(0) < 128 ? char : '');
    } else if (char == lower) {
      buffer.write(replacement);
    } else {
      buffer.write(replacement.toUpperCase());
    }
  }
  return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
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

_ChartBounds _buildLineChartBounds(List<int> values) {
  if (values.isEmpty) return const _ChartBounds(min: 0, max: 1);
  final minValue = values.reduce(math.min);
  final maxValue = values.reduce(math.max);

  if (minValue >= 0) {
    return _ChartBounds(min: 0, max: _niceChartMax(maxValue));
  }
  if (maxValue <= 0) {
    return _ChartBounds(min: -_niceChartMax(minValue.abs()), max: 0);
  }

  final maxAbs = _niceChartMax(math.max(minValue.abs(), maxValue));
  return _ChartBounds(min: -maxAbs, max: maxAbs);
}

List<num> _buildChartTicksBetween(num minValue, num maxValue) {
  return List.generate(5, (index) {
    return minValue + ((maxValue - minValue) * index / 4);
  });
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

String _percentText(int amount, int total) {
  if (total <= 0) return '0%';
  return '${((amount / total) * 100).round()}%';
}

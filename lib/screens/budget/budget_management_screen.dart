import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class BudgetManagementScreen extends StatelessWidget {
  const BudgetManagementScreen({super.key});

  static const _categories = [
    _BudgetCategory(
      name: 'Ăn uống',
      spent: '3.500.000 ₫',
      budget: '8.000.000 ₫',
      percent: 0.43,
      icon: Icons.restaurant_rounded,
      color: AppColors.primary,
      tint: Color(0x330F766E),
    ),
    _BudgetCategory(
      name: 'Di chuyển',
      spent: '2.500.000 ₫',
      budget: '3.000.000 ₫',
      percent: 0.83,
      icon: Icons.directions_car_rounded,
      color: AppColors.tertiary,
      tint: Color(0x332F746F),
    ),
    _BudgetCategory(
      name: 'Mua sắm',
      spent: '4.800.000 ₫',
      budget: '5.000.000 ₫',
      percent: 0.96,
      icon: Icons.shopping_bag_rounded,
      color: AppColors.error,
      tint: Color(0x66FFDAD6),
    ),
    _BudgetCategory(
      name: 'Điện nước',
      spent: '1.200.000 ₫',
      budget: '2.000.000 ₫',
      percent: 0.60,
      icon: Icons.bolt_rounded,
      color: AppColors.primary,
      tint: Color(0x330F766E),
    ),
  ];

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
          color: AppColors.onSurfaceVariant,
        ),
        title: Text(
          'Smart Expense',
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
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.92),
            border: Border(
              top: BorderSide(
                color: AppColors.outlineVariant.withValues(alpha: 0.30),
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SizedBox(
            height: 54,
            child: FilledButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Form thêm ngân sách sẽ được thêm sau.'),
                  ),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: AppTextStyles.titleMedium,
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Thêm ngân sách'),
            ),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 672),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                Text(
                  'Ngân sách tháng này',
                  style: AppTextStyles.headlineLarge.copyWith(
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Theo dõi và kiểm soát chi tiêu của bạn',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                const _BudgetSummaryCard(),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Theo danh mục',
                        style: AppTextStyles.titleMedium.copyWith(
                          color: AppColors.onSurface,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {},
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        textStyle: AppTextStyles.labelMedium.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      iconAlignment: IconAlignment.end,
                      icon: const Icon(Icons.sort_rounded, size: 16),
                      label: const Text('Sắp xếp'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                for (final category in _categories) ...[
                  _BudgetCategoryCard(category: category),
                  const SizedBox(height: 16),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BudgetSummaryCard extends StatelessWidget {
  const _BudgetSummaryCard();

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: -64,
            right: -56,
            child: Container(
              width: 128,
              height: 128,
              decoration: BoxDecoration(
                color: AppColors.primaryFixed.withValues(alpha: 0.30),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryFixed.withValues(alpha: 0.30),
                    blurRadius: 32,
                    spreadRadius: 16,
                  ),
                ],
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tổng ngân sách',
                style: AppTextStyles.titleMedium.copyWith(
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '25.000.000 ₫',
                style: AppTextStyles.displayCurrency.copyWith(
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _BudgetAmountColumn(
                      label: 'Đã chi',
                      amount: '15.500.000 ₫',
                      color: AppColors.onSurface,
                    ),
                  ),
                  Expanded(
                    child: _BudgetAmountColumn(
                      label: 'Còn lại',
                      amount: '9.500.000 ₫',
                      color: AppColors.secondary,
                      alignEnd: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const _ProgressBar(value: 0.62, color: AppColors.primary),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '62% đã sử dụng',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BudgetAmountColumn extends StatelessWidget {
  const _BudgetAmountColumn({
    required this.label,
    required this.amount,
    required this.color,
    this.alignEnd = false,
  });

  final String label;
  final String amount;
  final Color color;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: AppTextStyles.labelMedium.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        Text(
          amount,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.bodyLarge.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _BudgetCategoryCard extends StatelessWidget {
  const _BudgetCategoryCard({required this.category});

  final _BudgetCategory category;

  @override
  Widget build(BuildContext context) {
    final percentLabel = '${(category.percent * 100).round()}%';

    return _SoftCard(
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: category.tint,
                  shape: BoxShape.circle,
                ),
                child: Icon(category.icon, color: category.color, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.name,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.titleMedium.copyWith(
                        color: AppColors.onSurface,
                      ),
                    ),
                    Text(
                      '${category.spent} / ${category.budget}',
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                percentLabel,
                style: AppTextStyles.bodyLarge.copyWith(
                  color: category.color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _ProgressBar(value: category.percent, color: category.color),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        value: value,
        minHeight: 8,
        backgroundColor: AppColors.surfaceVariant,
        valueColor: AlwaysStoppedAnimation<Color>(color),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
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

class _BudgetCategory {
  const _BudgetCategory({
    required this.name,
    required this.spent,
    required this.budget,
    required this.percent,
    required this.icon,
    required this.color,
    required this.tint,
  });

  final String name;
  final String spent;
  final String budget;
  final double percent;
  final IconData icon;
  final Color color;
  final Color tint;
}

import 'package:flutter/material.dart';

import '../../data/models/app_transaction.dart';
import '../theme/app_colors.dart';

class CategoryMeta {
  const CategoryMeta({
    required this.label,
    required this.icon,
    required this.color,
    required this.backgroundColor,
  });

  final String label;
  final IconData icon;
  final Color color;
  final Color backgroundColor;
}

const expenseCategories = [
  CategoryMeta(
    label: 'Ăn uống',
    icon: Icons.restaurant_outlined,
    color: AppColors.error,
    backgroundColor: Color(0x4DFFDAD6),
  ),
  CategoryMeta(
    label: 'Đi lại',
    icon: Icons.directions_car_outlined,
    color: AppColors.tertiary,
    backgroundColor: Color(0x332F746F),
  ),
  CategoryMeta(
    label: 'Mua sắm',
    icon: Icons.shopping_bag_outlined,
    color: AppColors.primary,
    backgroundColor: Color(0x330F766E),
  ),
  CategoryMeta(
    label: 'Học tập',
    icon: Icons.school_outlined,
    color: AppColors.secondary,
    backgroundColor: Color(0x336DF5E1),
  ),
  CategoryMeta(
    label: 'Khác',
    icon: Icons.more_horiz_rounded,
    color: AppColors.onSurfaceVariant,
    backgroundColor: AppColors.surfaceVariant,
  ),
];

const incomeCategories = [
  CategoryMeta(
    label: 'Lương',
    icon: Icons.payments_outlined,
    color: AppColors.secondary,
    backgroundColor: Color(0x336DF5E1),
  ),
  CategoryMeta(
    label: 'Thưởng',
    icon: Icons.card_giftcard_outlined,
    color: AppColors.primary,
    backgroundColor: Color(0x330F766E),
  ),
  CategoryMeta(
    label: 'Đầu tư',
    icon: Icons.trending_up_rounded,
    color: AppColors.tertiary,
    backgroundColor: Color(0x332F746F),
  ),
  CategoryMeta(
    label: 'Bán hàng',
    icon: Icons.storefront_outlined,
    color: AppColors.secondary,
    backgroundColor: Color(0x336DF5E1),
  ),
  CategoryMeta(
    label: 'Khác',
    icon: Icons.more_horiz_rounded,
    color: AppColors.onSurfaceVariant,
    backgroundColor: AppColors.surfaceVariant,
  ),
];

List<CategoryMeta> categoriesForType(AppTransactionType type) {
  return type == AppTransactionType.expense
      ? expenseCategories
      : incomeCategories;
}

CategoryMeta categoryMeta(
  String category, {
  AppTransactionType type = AppTransactionType.expense,
}) {
  final categories = categoriesForType(type);
  return categories.firstWhere(
    (item) => item.label.toLowerCase() == category.toLowerCase(),
    orElse: () => categories.last,
  );
}

List<String> get allCategoryLabels {
  return {
    ...expenseCategories.map((item) => item.label),
    ...incomeCategories.map((item) => item.label),
  }.toList();
}

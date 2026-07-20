import 'package:flutter/material.dart';

import '../../data/models/app_transaction.dart';

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
    color: Color(0xFFEF4444),
    backgroundColor: Color(0xFFFFE4E6),
  ),
  CategoryMeta(
    label: 'Đi lại',
    icon: Icons.directions_car_outlined,
    color: Color(0xFF2563EB),
    backgroundColor: Color(0xFFDBEAFE),
  ),
  CategoryMeta(
    label: 'Mua sắm',
    icon: Icons.shopping_bag_outlined,
    color: Color(0xFF9333EA),
    backgroundColor: Color(0xFFF3E8FF),
  ),
  CategoryMeta(
    label: 'Học tập',
    icon: Icons.school_outlined,
    color: Color(0xFFD97706),
    backgroundColor: Color(0xFFFEF3C7),
  ),
  CategoryMeta(
    label: 'Khác',
    icon: Icons.more_horiz_rounded,
    color: Color(0xFF64748B),
    backgroundColor: Color(0xFFE2E8F0),
  ),
];

const incomeCategories = [
  CategoryMeta(
    label: 'Lương',
    icon: Icons.payments_outlined,
    color: Color(0xFF059669),
    backgroundColor: Color(0xFFD1FAE5),
  ),
  CategoryMeta(
    label: 'Thưởng',
    icon: Icons.card_giftcard_outlined,
    color: Color(0xFF0F766E),
    backgroundColor: Color(0xFFCCFBF1),
  ),
  CategoryMeta(
    label: 'Đầu tư',
    icon: Icons.trending_up_rounded,
    color: Color(0xFF4F46E5),
    backgroundColor: Color(0xFFE0E7FF),
  ),
  CategoryMeta(
    label: 'Bán hàng',
    icon: Icons.storefront_outlined,
    color: Color(0xFF0891B2),
    backgroundColor: Color(0xFFCFFAFE),
  ),
  CategoryMeta(
    label: 'Khác',
    icon: Icons.more_horiz_rounded,
    color: Color(0xFF64748B),
    backgroundColor: Color(0xFFE2E8F0),
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

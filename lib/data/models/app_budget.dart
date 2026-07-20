import 'package:cloud_firestore/cloud_firestore.dart';

enum BudgetPeriod {
  weekly,
  monthly,
  yearly;

  String get value => switch (this) {
    BudgetPeriod.weekly => 'weekly',
    BudgetPeriod.monthly => 'monthly',
    BudgetPeriod.yearly => 'yearly',
  };

  static BudgetPeriod fromValue(String? value) {
    return switch (value) {
      'weekly' => BudgetPeriod.weekly,
      'yearly' => BudgetPeriod.yearly,
      _ => BudgetPeriod.monthly,
    };
  }
}

class AppBudget {
  const AppBudget({
    required this.id,
    required this.category,
    required this.limitAmount,
    required this.period,
    required this.periodKey,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String category;
  final int limitAmount;
  final BudgetPeriod period;
  final String periodKey;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory AppBudget.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? {};
    return AppBudget(
      id: snapshot.id,
      category: data['category'] as String? ?? 'other',
      limitAmount: (data['limitAmount'] as num?)?.toInt() ?? 0,
      period: BudgetPeriod.fromValue(data['period'] as String?),
      periodKey: data['periodKey'] as String? ?? '',
      createdAt: _dateFromFirestore(data['createdAt']),
      updatedAt: _dateFromFirestore(data['updatedAt']),
    );
  }

  Map<String, dynamic> toCreateMap() {
    return {
      'category': category,
      'limitAmount': limitAmount,
      'period': period.value,
      'periodKey': periodKey,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> toUpdateMap() {
    return {
      'category': category,
      'limitAmount': limitAmount,
      'period': period.value,
      'periodKey': periodKey,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

DateTime? _dateFromFirestore(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}

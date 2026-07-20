import 'package:cloud_firestore/cloud_firestore.dart';

enum AppTransactionType {
  income,
  expense;

  String get value => switch (this) {
    AppTransactionType.income => 'income',
    AppTransactionType.expense => 'expense',
  };

  static AppTransactionType fromValue(String? value) {
    return value == 'income'
        ? AppTransactionType.income
        : AppTransactionType.expense;
  }
}

class AppTransaction {
  const AppTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.category,
    required this.transactionDate,
    this.title,
    this.note,
    this.paymentMethod,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final AppTransactionType type;
  final int amount;
  final String category;
  final DateTime transactionDate;
  final String? title;
  final String? note;
  final String? paymentMethod;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory AppTransaction.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? {};
    return AppTransaction(
      id: snapshot.id,
      type: AppTransactionType.fromValue(data['type'] as String?),
      amount: (data['amount'] as num?)?.toInt() ?? 0,
      category: data['category'] as String? ?? 'other',
      transactionDate:
          _dateFromFirestore(data['transactionDate']) ?? DateTime.now(),
      title: data['title'] as String?,
      note: data['note'] as String?,
      paymentMethod: data['paymentMethod'] as String?,
      createdAt: _dateFromFirestore(data['createdAt']),
      updatedAt: _dateFromFirestore(data['updatedAt']),
    );
  }

  Map<String, dynamic> toCreateMap() {
    return {
      'type': type.value,
      'amount': amount,
      'category': category,
      'transactionDate': Timestamp.fromDate(transactionDate),
      'title': title,
      'note': note,
      'paymentMethod': paymentMethod,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> toUpdateMap() {
    return {
      'type': type.value,
      'amount': amount,
      'category': category,
      'transactionDate': Timestamp.fromDate(transactionDate),
      'title': title,
      'note': note,
      'paymentMethod': paymentMethod,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  AppTransaction copyWith({
    String? id,
    AppTransactionType? type,
    int? amount,
    String? category,
    DateTime? transactionDate,
    String? title,
    String? note,
    String? paymentMethod,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AppTransaction(
      id: id ?? this.id,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      transactionDate: transactionDate ?? this.transactionDate,
      title: title ?? this.title,
      note: note ?? this.note,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

DateTime? _dateFromFirestore(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}

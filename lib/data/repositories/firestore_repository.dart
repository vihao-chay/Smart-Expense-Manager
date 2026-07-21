import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_budget.dart';
import '../models/app_notification.dart';
import '../models/app_transaction.dart';
import '../models/app_user_profile.dart';
import '../models/user_settings.dart';

class FirestoreRepository {
  FirestoreRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String get _uid {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('User must be signed in before accessing Firestore.');
    }
    return user.uid;
  }

  DocumentReference<Map<String, dynamic>> get _userDoc {
    return _firestore.collection('users').doc(_uid);
  }

  CollectionReference<Map<String, dynamic>> get _transactions {
    return _userDoc.collection('transactions');
  }

  CollectionReference<Map<String, dynamic>> get _budgets {
    return _userDoc.collection('budgets');
  }

  CollectionReference<Map<String, dynamic>> get _notifications {
    return _userDoc.collection('notifications');
  }

  DocumentReference<Map<String, dynamic>> get _settingsDoc {
    return _userDoc.collection('settings').doc('app');
  }

  Future<AppUserProfile?> fetchProfile() async {
    final snapshot = await _userDoc.get();
    if (!snapshot.exists) return null;
    return AppUserProfile.fromFirestore(snapshot);
  }

  Stream<AppUserProfile?> watchProfile() {
    return _userDoc.snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      return AppUserProfile.fromFirestore(snapshot);
    });
  }

  Future<void> updateProfile(AppUserProfile profile) {
    return _userDoc.set(profile.toUpdateMap(), SetOptions(merge: true));
  }

  Future<void> markOnboardingCompleted() {
    return _userDoc.set({
      'hasCompletedOnboarding': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<String> addTransaction(AppTransaction transaction) async {
    final doc = await _transactions.add(transaction.toCreateMap());
    return doc.id;
  }

  Future<AppTransaction?> fetchTransaction(String transactionId) async {
    final snapshot = await _transactions.doc(transactionId).get();
    if (!snapshot.exists) return null;
    return AppTransaction.fromFirestore(snapshot);
  }

  Stream<AppTransaction?> watchTransaction(String transactionId) {
    return _transactions.doc(transactionId).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      return AppTransaction.fromFirestore(snapshot);
    });
  }

  Future<void> updateTransaction(AppTransaction transaction) {
    return _transactions.doc(transaction.id).update(transaction.toUpdateMap());
  }

  Future<void> deleteTransaction(String transactionId) {
    return _transactions.doc(transactionId).delete();
  }

  Stream<List<AppTransaction>> watchTransactions({
    AppTransactionType? type,
    String? category,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return _transactions
        .orderBy('transactionDate', descending: true)
        .snapshots()
        .map((snapshot) {
          final transactions = snapshot.docs
              .map(AppTransaction.fromFirestore)
              .where((transaction) {
                if (type != null && transaction.type != type) return false;
                if (category != null &&
                    category.isNotEmpty &&
                    transaction.category != category) {
                  return false;
                }
                if (startDate != null &&
                    transaction.transactionDate.isBefore(startDate)) {
                  return false;
                }
                if (endDate != null &&
                    transaction.transactionDate.isAfter(endDate)) {
                  return false;
                }
                return true;
              })
              .toList();
          return transactions;
        });
  }

  Future<String> setBudget(AppBudget budget) async {
    final doc = budget.id.isEmpty ? _budgets.doc() : _budgets.doc(budget.id);
    await doc.set(
      budget.id.isEmpty ? budget.toCreateMap() : budget.toUpdateMap(),
      SetOptions(merge: true),
    );
    return doc.id;
  }

  Future<void> deleteBudget(String budgetId) {
    return _budgets.doc(budgetId).delete();
  }

  Stream<List<AppBudget>> watchBudgets({String? periodKey}) {
    Query<Map<String, dynamic>> query = _budgets;
    if (periodKey != null && periodKey.isNotEmpty) {
      query = query.where('periodKey', isEqualTo: periodKey);
    }

    return query.snapshots().map((snapshot) {
      final budgets = snapshot.docs.map(AppBudget.fromFirestore).toList()
        ..sort((a, b) => a.category.compareTo(b.category));
      return budgets;
    });
  }

  Stream<List<AppNotification>> watchNotifications() {
    return _notifications
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map(AppNotification.fromFirestore).toList();
        });
  }

  Future<void> addNotification(AppNotification notification) {
    return _notifications.add(notification.toCreateMap());
  }

  Future<void> addNotificationIfEnabled(AppNotification notification) async {
    final settings = await fetchSettings();
    if (!settings.notificationEnabled) return;
    await addNotification(notification);
  }

  Future<void> createDailyReminderIfNeeded([UserSettings? settings]) async {
    final currentSettings = settings ?? await fetchSettings();
    if (!currentSettings.notificationEnabled ||
        !currentSettings.dailyReminderEnabled) {
      return;
    }

    final today = _dateKey(DateTime.now());
    if (currentSettings.lastDailyReminderDate == today) return;

    await addNotification(
      const AppNotification(
        id: '',
        title: 'Nhắc ghi chép chi tiêu',
        body: 'Đừng quên cập nhật các khoản thu chi hôm nay.',
        type: 'reminder',
        isRead: false,
      ),
    );
    await saveSettings(currentSettings.copyWith(lastDailyReminderDate: today));
  }

  Future<void> markNotificationAsRead(String notificationId) {
    return _notifications.doc(notificationId).update({'isRead': true});
  }

  Future<void> updateDefaultCurrency(String currency) {
    return _userDoc.set({
      'defaultCurrency': currency,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<UserSettings> fetchSettings() async {
    final snapshot = await _settingsDoc.get();
    if (!snapshot.exists) return const UserSettings();
    return UserSettings.fromFirestore(snapshot);
  }

  Stream<UserSettings> watchSettings() {
    return _settingsDoc.snapshots().map((snapshot) {
      if (!snapshot.exists) return const UserSettings();
      return UserSettings.fromFirestore(snapshot);
    });
  }

  Future<void> saveSettings(UserSettings settings) {
    return _settingsDoc.set(settings.toFirestore(), SetOptions(merge: true));
  }
}

String _dateKey(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

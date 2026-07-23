import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/app_budget.dart';
import '../models/app_document.dart';
import '../models/app_notification.dart';
import '../models/app_transaction.dart';
import '../models/app_user_profile.dart';
import '../models/bug_report.dart';
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

  CollectionReference<Map<String, dynamic>> get _devices {
    return _userDoc.collection('devices');
  }

  CollectionReference<Map<String, dynamic>> get _documents {
    return _firestore.collection('documents');
  }

  CollectionReference<Map<String, dynamic>> get _bugReports {
    return _firestore.collection('bugReports');
  }

  CollectionReference<Map<String, dynamic>> get _campaigns {
    return _firestore.collection('notificationCampaigns');
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

  Future<void> deleteNotification(String notificationId) {
    return _notifications.doc(notificationId).delete();
  }

  Future<void> deleteAllNotifications() async {
    final snapshot = await _notifications.get();
    if (snapshot.docs.isEmpty) return;

    var batch = _firestore.batch();
    var operationCount = 0;
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
      operationCount++;
      if (operationCount == 450) {
        await batch.commit();
        batch = _firestore.batch();
        operationCount = 0;
      }
    }

    if (operationCount > 0) {
      await batch.commit();
    }
  }

  Future<void> markAllNotificationsAsRead() async {
    final snapshot = await _notifications
        .where('isRead', isEqualTo: false)
        .get();
    if (snapshot.docs.isEmpty) return;

    var batch = _firestore.batch();
    var operationCount = 0;
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
      });
      operationCount++;
      if (operationCount == 450) {
        await batch.commit();
        batch = _firestore.batch();
        operationCount = 0;
      }
    }

    if (operationCount > 0) {
      await batch.commit();
    }
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
    return _markNotification(
      notificationId: notificationId,
      fields: {'isRead': true, 'readAt': FieldValue.serverTimestamp()},
      recipientFields: {'isRead': true, 'readAt': FieldValue.serverTimestamp()},
    );
  }

  Future<void> markNotificationAsOpened({
    String? notificationId,
    String? campaignId,
  }) async {
    if (notificationId != null && notificationId.trim().isNotEmpty) {
      await _markNotification(
        notificationId: notificationId.trim(),
        fields: {'openedAt': FieldValue.serverTimestamp()},
        recipientFields: {'openedAt': FieldValue.serverTimestamp()},
      );
      return;
    }

    if (campaignId == null || campaignId.trim().isEmpty) return;
    await _campaigns
        .doc(campaignId.trim())
        .collection('recipients')
        .doc(_uid)
        .set({
          'openedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  Future<void> _markNotification({
    required String notificationId,
    required Map<String, dynamic> fields,
    required Map<String, dynamic> recipientFields,
  }) async {
    final doc = _notifications.doc(notificationId);
    final snapshot = await doc.get();
    if (!snapshot.exists) return;

    final notification = AppNotification.fromFirestore(snapshot);
    await doc.update(fields);

    final campaignId = notification.campaignId;
    if (campaignId == null || campaignId.trim().isEmpty) return;
    await _campaigns
        .doc(campaignId.trim())
        .collection('recipients')
        .doc(_uid)
        .set(recipientFields, SetOptions(merge: true));
  }

  Future<void> saveDeviceToken({
    required String token,
    required String platform,
  }) async {
    final trimmedToken = token.trim();
    if (trimmedToken.isEmpty) return;

    await _devices.doc(_deviceIdFromToken(trimmedToken)).set({
      'fcmToken': trimmedToken,
      'platform': platform,
      'lastActiveAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<List<AppDocument>> watchPublishedDocuments({
    String? category,
    String? searchQuery,
  }) {
    return _documents
        .where(
          Filter.or(
            Filter('isPublished', isEqualTo: true),
            Filter('userId', isEqualTo: _uid),
          ),
        )
        .snapshots()
        .map((snapshot) {
          final query = searchQuery?.trim().toLowerCase() ?? '';
          final selectedCategory = category?.trim() ?? '';
          final documents =
              snapshot.docs.map(AppDocument.fromFirestore).where((document) {
                if (selectedCategory.isNotEmpty &&
                    selectedCategory != 'Tất cả' &&
                    document.category != selectedCategory) {
                  return false;
                }
                if (query.isEmpty) return true;
                return document.title.toLowerCase().contains(query) ||
                    document.description.toLowerCase().contains(query) ||
                    document.category.toLowerCase().contains(query);
              }).toList()..sort((a, b) {
                final left =
                    a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
                final right =
                    b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
                return right.compareTo(left);
              });
          return documents;
        });
  }

  Stream<List<BugReport>> watchMyBugReports() {
    return _bugReports.where('userId', isEqualTo: _uid).snapshots().map((
      snapshot,
    ) {
      return snapshot.docs.map(BugReport.fromFirestore).toList()..sort((a, b) {
        final left = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final right = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return right.compareTo(left);
      });
    });
  }

  Future<String> createBugReport({
    required String title,
    required String description,
    required String severity,
    String? screenName,
    String? imageUrl,
    String? imageStoragePath,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('User must be signed in before reporting a bug.');
    }

    final profile = await fetchProfile();
    final report = BugReport(
      id: '',
      userId: user.uid,
      userEmail: user.email ?? profile?.email,
      userName: profile?.fullName ?? user.displayName,
      title: title,
      description: description,
      severity: severity,
      status: 'pending',
      screenName: screenName,
      imageUrl: imageUrl,
      imageStoragePath: imageStoragePath,
      deviceInfo: {'platform': platformName, 'app': 'Smart Expense Manager'},
    );
    final doc = await _bugReports.add(report.toCreateMap());
    return doc.id;
  }

  Future<String> createStatisticsReportDocument({
    required String title,
    required String description,
    required String fileName,
    required String fileUrl,
    required String storagePath,
    required String periodLabel,
    AppUserProfile? profile,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('User must be signed in before exporting a report.');
    }

    final doc = await _documents.add({
      'title': title,
      'description': description,
      'category': 'Báo cáo thống kê',
      'fileName': fileName,
      'fileUrl': fileUrl,
      'storagePath': storagePath,
      'isPublished': false,
      'source': 'mobile_statistics_export',
      'uploadedBy': user.uid,
      'userId': user.uid,
      'userEmail': user.email ?? profile?.email ?? '',
      'userName': profile?.fullName ?? user.displayName ?? '',
      'periodLabel': periodLabel,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
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

String get platformName {
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => 'android',
    TargetPlatform.iOS => 'ios',
    TargetPlatform.windows => 'windows',
    TargetPlatform.macOS => 'macos',
    TargetPlatform.linux => 'linux',
    TargetPlatform.fuchsia => 'fuchsia',
  };
}

String _deviceIdFromToken(String token) {
  final normalized = token.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  if (normalized.length <= 120) return normalized;
  return normalized.substring(0, 120);
}

String _dateKey(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

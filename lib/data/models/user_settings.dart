import 'package:cloud_firestore/cloud_firestore.dart';

class UserSettings {
  const UserSettings({
    this.themeMode = 'light',
    this.notificationEnabled = true,
    this.dailyReminderEnabled = true,
    this.currency = 'VND',
    this.lastDailyReminderDate,
    this.updatedAt,
  });

  final String themeMode;
  final bool notificationEnabled;
  final bool dailyReminderEnabled;
  final String currency;
  final String? lastDailyReminderDate;
  final DateTime? updatedAt;

  factory UserSettings.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? {};
    return UserSettings(
      themeMode: data['themeMode'] as String? ?? 'light',
      notificationEnabled: data['notificationEnabled'] as bool? ?? true,
      dailyReminderEnabled: data['dailyReminderEnabled'] as bool? ?? true,
      currency: data['currency'] as String? ?? 'VND',
      lastDailyReminderDate: data['lastDailyReminderDate'] as String?,
      updatedAt: _dateFromFirestore(data['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'themeMode': themeMode,
      'notificationEnabled': notificationEnabled,
      'dailyReminderEnabled': dailyReminderEnabled,
      'currency': currency,
      'lastDailyReminderDate': lastDailyReminderDate,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  UserSettings copyWith({
    String? themeMode,
    bool? notificationEnabled,
    bool? dailyReminderEnabled,
    String? currency,
    String? lastDailyReminderDate,
    DateTime? updatedAt,
  }) {
    return UserSettings(
      themeMode: themeMode ?? this.themeMode,
      notificationEnabled: notificationEnabled ?? this.notificationEnabled,
      dailyReminderEnabled: dailyReminderEnabled ?? this.dailyReminderEnabled,
      currency: currency ?? this.currency,
      lastDailyReminderDate:
          lastDailyReminderDate ?? this.lastDailyReminderDate,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

DateTime? _dateFromFirestore(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}

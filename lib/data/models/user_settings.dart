import 'package:cloud_firestore/cloud_firestore.dart';

class UserSettings {
  const UserSettings({
    this.themeMode = 'light',
    this.notificationEnabled = true,
    this.dailyReminderEnabled = true,
    this.language = 'vi',
    this.currency = 'VND',
    this.updatedAt,
  });

  final String themeMode;
  final bool notificationEnabled;
  final bool dailyReminderEnabled;
  final String language;
  final String currency;
  final DateTime? updatedAt;

  factory UserSettings.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? {};
    return UserSettings(
      themeMode: data['themeMode'] as String? ?? 'light',
      notificationEnabled: data['notificationEnabled'] as bool? ?? true,
      dailyReminderEnabled: data['dailyReminderEnabled'] as bool? ?? true,
      language: data['language'] as String? ?? 'vi',
      currency: data['currency'] as String? ?? 'VND',
      updatedAt: _dateFromFirestore(data['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'themeMode': themeMode,
      'notificationEnabled': notificationEnabled,
      'dailyReminderEnabled': dailyReminderEnabled,
      'language': language,
      'currency': currency,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  UserSettings copyWith({
    String? themeMode,
    bool? notificationEnabled,
    bool? dailyReminderEnabled,
    String? language,
    String? currency,
    DateTime? updatedAt,
  }) {
    return UserSettings(
      themeMode: themeMode ?? this.themeMode,
      notificationEnabled: notificationEnabled ?? this.notificationEnabled,
      dailyReminderEnabled: dailyReminderEnabled ?? this.dailyReminderEnabled,
      language: language ?? this.language,
      currency: currency ?? this.currency,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

DateTime? _dateFromFirestore(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}

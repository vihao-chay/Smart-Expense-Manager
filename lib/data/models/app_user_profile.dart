import 'package:cloud_firestore/cloud_firestore.dart';

class AppUserProfile {
  const AppUserProfile({
    required this.uid,
    required this.fullName,
    required this.email,
    this.avatarUrl,
    this.defaultCurrency = 'VND',
    this.hasCompletedOnboarding = false,
    this.createdAt,
    this.updatedAt,
  });

  final String uid;
  final String fullName;
  final String email;
  final String? avatarUrl;
  final String defaultCurrency;
  final bool hasCompletedOnboarding;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory AppUserProfile.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? {};
    return AppUserProfile(
      uid: snapshot.id,
      fullName: data['fullName'] as String? ?? '',
      email: data['email'] as String? ?? '',
      avatarUrl: data['avatarUrl'] as String?,
      defaultCurrency: data['defaultCurrency'] as String? ?? 'VND',
      hasCompletedOnboarding: data['hasCompletedOnboarding'] as bool? ?? false,
      createdAt: _dateFromFirestore(data['createdAt']),
      updatedAt: _dateFromFirestore(data['updatedAt']),
    );
  }

  Map<String, dynamic> toCreateMap() {
    return {
      'fullName': fullName,
      'email': email,
      'avatarUrl': avatarUrl,
      'defaultCurrency': defaultCurrency,
      'hasCompletedOnboarding': hasCompletedOnboarding,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> toUpdateMap() {
    return {
      'fullName': fullName,
      'email': email,
      'avatarUrl': avatarUrl,
      'defaultCurrency': defaultCurrency,
      'hasCompletedOnboarding': hasCompletedOnboarding,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

DateTime? _dateFromFirestore(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}

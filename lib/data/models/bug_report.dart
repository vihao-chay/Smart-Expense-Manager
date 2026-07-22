import 'package:cloud_firestore/cloud_firestore.dart';

class BugReport {
  const BugReport({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.severity,
    required this.status,
    this.userEmail,
    this.userName,
    this.screenName,
    this.imageUrl,
    this.imageStoragePath,
    this.deviceInfo,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String userId;
  final String? userEmail;
  final String? userName;
  final String title;
  final String description;
  final String severity;
  final String status;
  final String? screenName;
  final String? imageUrl;
  final String? imageStoragePath;
  final Map<String, dynamic>? deviceInfo;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory BugReport.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? {};
    return BugReport(
      id: snapshot.id,
      userId: data['userId'] as String? ?? '',
      userEmail: data['userEmail'] as String?,
      userName: data['userName'] as String?,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      severity: data['severity'] as String? ?? 'medium',
      status: data['status'] as String? ?? 'pending',
      screenName: data['screenName'] as String?,
      imageUrl: data['imageUrl'] as String?,
      imageStoragePath: data['imageStoragePath'] as String?,
      deviceInfo: Map<String, dynamic>.from(
        data['deviceInfo'] as Map? ?? const {},
      ),
      createdAt: _dateFromFirestore(data['createdAt']),
      updatedAt: _dateFromFirestore(data['updatedAt']),
    );
  }

  Map<String, dynamic> toCreateMap() {
    return {
      'userId': userId,
      'userEmail': userEmail,
      'userName': userName,
      'title': title,
      'description': description,
      'severity': severity,
      'status': status,
      'screenName': screenName,
      'imageUrl': imageUrl,
      'imageStoragePath': imageStoragePath,
      'deviceInfo': deviceInfo ?? const {},
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

DateTime? _dateFromFirestore(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}

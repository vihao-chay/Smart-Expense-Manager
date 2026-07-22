import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.isRead,
    this.campaignId,
    this.data = const {},
    this.createdAt,
    this.readAt,
    this.openedAt,
  });

  final String id;
  final String title;
  final String body;
  final String type;
  final bool isRead;
  final String? campaignId;
  final Map<String, dynamic> data;
  final DateTime? createdAt;
  final DateTime? readAt;
  final DateTime? openedAt;

  factory AppNotification.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? {};
    return AppNotification(
      id: snapshot.id,
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      type: data['type'] as String? ?? 'general',
      isRead: data['isRead'] as bool? ?? false,
      campaignId: data['campaignId'] as String?,
      data: Map<String, dynamic>.from(data['data'] as Map? ?? const {}),
      createdAt: _dateFromFirestore(data['createdAt']),
      readAt: _dateFromFirestore(data['readAt']),
      openedAt: _dateFromFirestore(data['openedAt']),
    );
  }

  Map<String, dynamic> toCreateMap() {
    return {
      'title': title,
      'body': body,
      'type': type,
      'isRead': isRead,
      'campaignId': campaignId,
      'data': data,
      'createdAt': FieldValue.serverTimestamp(),
      'readAt': readAt == null ? null : Timestamp.fromDate(readAt!),
      'openedAt': openedAt == null ? null : Timestamp.fromDate(openedAt!),
    };
  }

  Map<String, dynamic> toReadMap() {
    return {'isRead': true, 'readAt': FieldValue.serverTimestamp()};
  }
}

DateTime? _dateFromFirestore(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}

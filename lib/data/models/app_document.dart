import 'package:cloud_firestore/cloud_firestore.dart';

class AppDocument {
  const AppDocument({
    required this.id,
    required this.title,
    required this.description,
    required this.fileUrl,
    required this.storagePath,
    required this.category,
    required this.isPublished,
    this.fileName,
    this.createdAt,
    this.updatedAt,
    this.uploadedBy,
  });

  final String id;
  final String title;
  final String description;
  final String fileUrl;
  final String storagePath;
  final String category;
  final bool isPublished;
  final String? fileName;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? uploadedBy;

  factory AppDocument.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? {};
    return AppDocument(
      id: snapshot.id,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      fileUrl: data['fileUrl'] as String? ?? '',
      storagePath: data['storagePath'] as String? ?? '',
      category: data['category'] as String? ?? 'Chung',
      isPublished: data['isPublished'] as bool? ?? false,
      fileName: data['fileName'] as String?,
      createdAt: _dateFromFirestore(data['createdAt']),
      updatedAt: _dateFromFirestore(data['updatedAt']),
      uploadedBy: data['uploadedBy'] as String?,
    );
  }
}

DateTime? _dateFromFirestore(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}

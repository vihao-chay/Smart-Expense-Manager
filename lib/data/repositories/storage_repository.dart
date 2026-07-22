import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class AvatarUploadResult {
  const AvatarUploadResult({
    required this.downloadUrl,
    required this.storagePath,
  });

  final String downloadUrl;
  final String storagePath;
}

class BugImageUploadResult {
  const BugImageUploadResult({
    required this.downloadUrl,
    required this.storagePath,
  });

  final String downloadUrl;
  final String storagePath;
}

class ReportPdfUploadResult {
  const ReportPdfUploadResult({
    required this.downloadUrl,
    required this.storagePath,
  });

  final String downloadUrl;
  final String storagePath;
}

class StorageRepository {
  StorageRepository({FirebaseStorage? storage, FirebaseAuth? auth})
    : _storage = storage ?? FirebaseStorage.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseStorage _storage;
  final FirebaseAuth _auth;

  Future<AvatarUploadResult> uploadAvatar({
    required XFile image,
    required String fullName,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'Bạn cần đăng nhập để tải ảnh đại diện.',
      );
    }

    final bytes = await image.readAsBytes();
    final extension = _imageExtension(image.name);
    final contentType = _contentTypeForExtension(extension);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final storagePath = 'avatars/${user.uid}/avatar_$timestamp.$extension';

    final ref = _storage.ref(storagePath);
    await ref.putData(
      bytes,
      SettableMetadata(
        contentType: contentType,
        customMetadata: {'ownerUid': user.uid, 'profileName': fullName.trim()},
      ),
    );

    return AvatarUploadResult(
      downloadUrl: await ref.getDownloadURL(),
      storagePath: storagePath,
    );
  }

  Future<void> deleteFileIfExists(String? storagePath) async {
    if (storagePath == null || storagePath.trim().isEmpty) return;

    try {
      await _storage.ref(storagePath).delete();
    } on FirebaseException catch (error) {
      if (error.code != 'object-not-found') rethrow;
    }
  }

  Future<BugImageUploadResult> uploadBugImage({required XFile image}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'Bạn cần đăng nhập để tải ảnh lỗi.',
      );
    }

    final bytes = await image.readAsBytes();
    final extension = _imageExtension(image.name);
    final contentType = _contentTypeForExtension(extension);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final storagePath = 'bug_reports/${user.uid}/bug_$timestamp.$extension';

    final ref = _storage.ref(storagePath);
    await ref.putData(
      bytes,
      SettableMetadata(
        contentType: contentType,
        customMetadata: {'ownerUid': user.uid, 'type': 'bug_report'},
      ),
    );

    return BugImageUploadResult(
      downloadUrl: await ref.getDownloadURL(),
      storagePath: storagePath,
    );
  }

  Future<ReportPdfUploadResult> uploadReportPdf({
    required Uint8List bytes,
    required String fileName,
    required String fullName,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'Bạn cần đăng nhập để xuất báo cáo PDF.',
      );
    }

    final safeFileName = _safeFileName(fileName);
    final storagePath = 'report_exports/${user.uid}/$safeFileName';
    final ref = _storage.ref(storagePath);

    await ref.putData(
      bytes,
      SettableMetadata(
        contentType: 'application/pdf',
        customMetadata: {
          'ownerUid': user.uid,
          'profileName': fullName.trim(),
          'type': 'statistics_report',
        },
      ),
    );

    return ReportPdfUploadResult(
      downloadUrl: await ref.getDownloadURL(),
      storagePath: storagePath,
    );
  }

  String _imageExtension(String fileName) {
    final name = fileName.toLowerCase();
    final extension = name.contains('.') ? name.split('.').last : 'jpg';
    return switch (extension) {
      'jpeg' => 'jpg',
      'jpg' || 'png' || 'webp' || 'gif' || 'heic' => extension,
      _ => 'jpg',
    };
  }

  String _contentTypeForExtension(String extension) {
    return switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      'heic' => 'image/heic',
      _ => 'image/jpeg',
    };
  }

  String _safeFileName(String fileName) {
    final cleaned = fileName.trim().replaceAll(
      RegExp(r'[^a-zA-Z0-9._-]+'),
      '_',
    );
    return cleaned.isEmpty ? 'smart_expense_report.pdf' : cleaned;
  }
}

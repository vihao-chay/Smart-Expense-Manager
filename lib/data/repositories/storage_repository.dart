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
    final folderName = _safeUserFolderName(fullName, user.uid);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final storagePath = '$folderName/avatar_${user.uid}_$timestamp.$extension';

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

  String _safeUserFolderName(String fullName, String uid) {
    final cleaned = fullName
        .trim()
        .replaceAll(RegExp(r'[\\/#?%\[\]*]+'), '-')
        .replaceAll(RegExp(r'\s+'), ' ');
    final folderName = cleaned.isEmpty ? 'user_$uid' : cleaned;
    return folderName.length <= 80 ? folderName : folderName.substring(0, 80);
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
}

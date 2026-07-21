import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/app_user_profile.dart';

class AuthRepository {
  AuthRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    GoogleSignIn? googleSignIn,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _googleSignIn =
           googleSignIn ??
           GoogleSignIn(
             scopes: const ['email', 'profile'],
             serverClientId: _googleServerClientId,
           );

  static const _googleServerClientId =
      '620730155211-dpv7g0fe7hdjpjlfenfs5kqa2sa603g4.apps.googleusercontent.com';

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn _googleSignIn;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user;
    if (user != null) {
      await _ensureUserProfile(user);
    }
    return credential;
  }

  Future<UserCredential> signInWithGoogle() async {
    if (!_isGoogleSignInSupported) {
      throw UnsupportedError(
        'Google Sign-In hiện chỉ được bật cho Android trong project này.',
      );
    }

    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      throw PlatformException(
        code: GoogleSignIn.kSignInCanceledError,
        message: 'Bạn đã hủy đăng nhập bằng Google.',
      );
    }

    final googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;
    final accessToken = googleAuth.accessToken;
    if ((idToken == null || idToken.isEmpty) &&
        (accessToken == null || accessToken.isEmpty)) {
      throw FirebaseAuthException(
        code: 'missing-google-id-token',
        message: 'Không nhận được Google ID token.',
      );
    }

    final credential = GoogleAuthProvider.credential(
      accessToken: accessToken,
      idToken: idToken,
    );
    final userCredential = await _auth.signInWithCredential(credential);
    final user = userCredential.user;

    if (user != null) {
      await _ensureUserProfile(user);
    }

    return userCredential;
  }

  Future<UserCredential> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user;

    if (user != null) {
      await user.updateDisplayName(fullName.trim());
      await _ensureUserProfile(user, fallbackFullName: fullName.trim());
    }

    return credential;
  }

  Future<void> sendPasswordResetEmail(String email) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> updateCurrentUserProfile({
    required String fullName,
    String? avatarUrl,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'Bạn cần đăng nhập để cập nhật hồ sơ.',
      );
    }

    await user.updateDisplayName(fullName.trim());
    await user.updatePhotoURL(
      avatarUrl?.trim().isEmpty == true ? null : avatarUrl?.trim(),
    );
  }

  Future<void> signOut() async {
    await _auth.signOut();
    if (!_isGoogleSignInSupported) return;

    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // Firebase sign-out is the source of truth for app session state.
    }
  }

  bool get _isGoogleSignInSupported {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android;
  }

  Future<void> _ensureUserProfile(User user, {String? fallbackFullName}) async {
    final userDoc = _firestore.collection('users').doc(user.uid);
    final snapshot = await userDoc.get();

    final status = snapshot.data()?['status'] as String? ?? 'active';
    if (status == 'locked') {
      await signOut();
      throw FirebaseAuthException(
        code: 'user-disabled',
        message: 'Tài khoản đã bị khóa bởi quản trị viên.',
      );
    }

    if (!snapshot.exists) {
      final profile = AppUserProfile(
        uid: user.uid,
        fullName: user.displayName?.trim().isNotEmpty == true
            ? user.displayName!.trim()
            : fallbackFullName ?? '',
        email: user.email ?? '',
        avatarUrl: user.photoURL,
      );
      await userDoc.set(profile.toCreateMap(), SetOptions(merge: true));
      return;
    }

    await userDoc.set({
      'fullName': user.displayName?.trim().isNotEmpty == true
          ? user.displayName!.trim()
          : fallbackFullName,
      'email': user.email,
      'avatarUrl': user.photoURL,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../repositories/firestore_repository.dart';

class NotificationService {
  NotificationService._();

  static final instance = NotificationService._();

  final _auth = FirebaseAuth.instance;
  final _messaging = FirebaseMessaging.instance;
  var _initialized = false;

  Future<void> initialize() async {
    if (_initialized || !_supportsMessaging) return;
    _initialized = true;

    await _requestPermission();

    _auth.authStateChanges().listen((user) {
      if (user != null) _registerCurrentDevice();
    });

    FirebaseMessaging.instance.onTokenRefresh.listen(_saveToken);
    FirebaseMessaging.onMessageOpenedApp.listen(_markMessageOpened);

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      await _markMessageOpened(initialMessage);
    }
  }

  Future<void> refreshDeviceToken() async {
    if (!_supportsMessaging) return;
    await _requestPermission();
    await _registerCurrentDevice();
  }

  Future<void> _requestPermission() async {
    try {
      await _messaging.requestPermission(alert: true, badge: true, sound: true);
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (_) {
      // Some desktop/debug targets do not implement messaging permission APIs.
    }
  }

  Future<void> _registerCurrentDevice() async {
    try {
      final token = await _messaging.getToken();
      if (token == null || token.trim().isEmpty) return;
      await _saveToken(token);
    } catch (_) {
      // The app can still work without a push token.
    }
  }

  Future<void> _saveToken(String token) async {
    if (_auth.currentUser == null) return;
    try {
      await FirestoreRepository().saveDeviceToken(
        token: token,
        platform: platformName,
      );
    } catch (_) {
      // Token sync is retried on next login/token refresh.
    }
  }

  Future<void> _markMessageOpened(RemoteMessage message) async {
    if (_auth.currentUser == null) return;
    final notificationId = message.data['notificationId']?.toString();
    final campaignId = message.data['campaignId']?.toString();

    try {
      await FirestoreRepository().markNotificationAsOpened(
        notificationId: notificationId,
        campaignId: campaignId,
      );
    } catch (_) {
      // Analytics should not block opening the app.
    }
  }
}

bool get _supportsMessaging {
  if (kIsWeb) return false;
  return switch (defaultTargetPlatform) {
    TargetPlatform.android || TargetPlatform.iOS => true,
    TargetPlatform.fuchsia ||
    TargetPlatform.linux ||
    TargetPlatform.macOS ||
    TargetPlatform.windows => false,
  };
}

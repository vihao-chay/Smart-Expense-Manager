import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../app/app_navigator.dart';
import '../../app/app_routes.dart';
import '../repositories/firestore_repository.dart';

class NotificationService {
  NotificationService._();

  static final instance = NotificationService._();

  final _auth = FirebaseAuth.instance;
  final _messaging = FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();
  RemoteMessage? _initialTapMessage;
  var _initialized = false;

  static const _androidChannelId = 'smart_expense_push';
  static const _androidChannelName = 'Smart Expense';
  static const _androidChannelDescription =
      'Thong bao tu Smart Expense Manager';
  static const _androidChannel = AndroidNotificationChannel(
    _androidChannelId,
    _androidChannelName,
    description: _androidChannelDescription,
    importance: Importance.high,
  );

  Future<void> initialize() async {
    if (_initialized || !_supportsMessaging) return;
    _initialized = true;

    await _requestPermission();
    await _initializeLocalNotifications();

    _auth.authStateChanges().listen((user) {
      if (user != null) _registerCurrentDevice();
    });

    FirebaseMessaging.instance.onTokenRefresh.listen(_saveToken);
    FirebaseMessaging.onMessage.listen(_showForegroundNotification);
    FirebaseMessaging.onMessageOpenedApp.listen(_handlePushTap);

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _initialTapMessage = initialMessage;
    }
  }

  Future<bool> consumeInitialNotificationTap() async {
    final message = _initialTapMessage;
    if (message == null) return false;
    _initialTapMessage = null;
    await _markMessageOpened(message);
    return true;
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

  Future<void> _initializeLocalNotifications() async {
    try {
      const initializationSettings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      );

      await _localNotifications.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: _handleLocalNotificationTap,
      );

      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidPlugin?.createNotificationChannel(_androidChannel);
    } catch (_) {
      // Push still works in background even if local notification setup fails.
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

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;

    final title =
        message.notification?.title ?? message.data['title']?.toString();
    final body = message.notification?.body ?? message.data['body']?.toString();
    if ((title == null || title.trim().isEmpty) &&
        (body == null || body.trim().isEmpty)) {
      return;
    }

    try {
      await _localNotifications.show(
        id: _notificationId(message),
        title: title?.trim().isEmpty == false ? title : 'Smart Expense',
        body: body?.trim() ?? '',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _androidChannelId,
            _androidChannelName,
            channelDescription: _androidChannelDescription,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
        ),
        payload: jsonEncode(_messagePayload(message)),
      );
    } catch (_) {
      // Foreground notification display should not block app usage.
    }
  }

  Future<void> _handlePushTap(RemoteMessage message) async {
    await _markMessageOpened(message);
    _openHomeFromPush();
  }

  Future<void> _handleLocalNotificationTap(NotificationResponse response) async {
    await _markOpenedFromPayload(response.payload);
    _openHomeFromPush();
  }

  Future<void> _markMessageOpened(RemoteMessage message) async {
    await _markOpenedFromData(message.data);
  }

  Future<void> _markOpenedFromPayload(String? payload) async {
    if (payload == null || payload.trim().isEmpty) return;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map) {
        await _markOpenedFromData(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {
      // Ignore invalid local-notification payloads.
    }
  }

  Future<void> _markOpenedFromData(Map<String, dynamic> data) async {
    if (_auth.currentUser == null) return;
    final notificationId = data['notificationId']?.toString();
    final campaignId = data['campaignId']?.toString();

    try {
      await FirestoreRepository().markNotificationAsOpened(
        notificationId: notificationId,
        campaignId: campaignId,
      );
    } catch (_) {
      // Analytics should not block opening the app.
    }
  }

  void _openHomeFromPush() {
    final navigator = appNavigatorKey.currentState;
    if (navigator == null) return;
    navigator.pushNamedAndRemoveUntil(AppRoutes.home, (route) => false);
  }
}

Map<String, dynamic> _messagePayload(RemoteMessage message) {
  return {
    ...message.data,
    if (message.notification?.title != null)
      'title': message.notification!.title!,
    if (message.notification?.body != null) 'body': message.notification!.body!,
  };
}

int _notificationId(RemoteMessage message) {
  final source = message.messageId ?? message.sentTime?.toIso8601String();
  return (source ?? DateTime.now().microsecondsSinceEpoch.toString()).hashCode &
      0x7fffffff;
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

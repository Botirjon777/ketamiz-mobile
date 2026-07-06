import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../resources/repository.dart';
import '../ui/menu/notifications/notifications_screen.dart';

/// Handles messages that arrive while the app is in the background or fully
/// terminated. Must be a top-level (or static) function annotated with
/// `@pragma('vm:entry-point')` so it survives tree-shaking and can run in its
/// own isolate. The OS renders the system banner automatically when the payload
/// carries a `notification` block, so there is nothing to draw here — the
/// handler only needs to exist for delivery to work.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Intentionally empty. Add logging/local persistence here if ever needed.
}

/// Central place for everything FCM: permission, token registration with the
/// backend, foreground banners (via flutter_local_notifications) and routing
/// when a notification is tapped.
class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  /// Wired into [MaterialApp.navigatorKey] so notification taps can push routes
  /// without needing a [BuildContext].
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Must match the id in AndroidManifest's
  /// `com.google.firebase.messaging.default_notification_channel_id`.
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'high_importance_channel',
    'Notifications',
    description: 'General notifications from Ketamiz',
    importance: Importance.high,
  );

  bool _initialised = false;
  bool _tokenListenerAttached = false;

  /// One-time setup — call once at startup, right after
  /// `Firebase.initializeApp()`. Sets up the local-notifications plugin, the
  /// Android channel, iOS foreground presentation and the message listeners.
  /// Does NOT request permission or fetch a token; that happens in
  /// [registerToken] once the user is authenticated.
  Future<void> init() async {
    if (kIsWeb || _initialised) return;
    _initialised = true;

    // iOS: show the banner even when the app is in the foreground.
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _localNotifications.initialize(
      settings:
          const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) _routeFromType(payload);
      },
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // App open → draw our own banner (the OS suppresses its own on Android).
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    // App in background, brought to front by tapping the notification.
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final type = message.data['type'];
      if (type != null) _routeFromType(type.toString());
    });

    // App was terminated and launched by tapping the notification.
    final initialMessage = await _messaging.getInitialMessage();
    final initialType = initialMessage?.data['type'];
    if (initialType != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _routeFromType(initialType.toString()),
      );
    }
  }

  /// Ask for notification permission, grab the FCM token and send it to the
  /// backend. Call this once the JWT is available (after login / on startup
  /// when already logged in). Safe to call more than once.
  Future<void> registerToken() async {
    if (kIsWeb) return;
    try {
      await _messaging.requestPermission(alert: true, badge: true, sound: true);

      final token = await _messaging.getToken();
      if (token != null && token.isNotEmpty) {
        await _sendTokenToBackend(token);
      }

      // Firebase rotates tokens occasionally — keep the backend in sync.
      if (!_tokenListenerAttached) {
        _tokenListenerAttached = true;
        _messaging.onTokenRefresh.listen(_sendTokenToBackend);
      }
    } catch (e) {
      debugPrint('PushNotificationService.registerToken error: $e');
    }
  }

  /// Tell the backend to stop pushing to this device, then drop the local
  /// token. Call on logout BEFORE the JWT is wiped, and on account deletion.
  Future<void> unregisterToken() async {
    if (kIsWeb) return;
    try {
      await Repository().fetchDeleteDeviceToken();
    } catch (e) {
      debugPrint('PushNotificationService.unregisterToken (backend) error: $e');
    }
    try {
      await _messaging.deleteToken();
    } catch (e) {
      debugPrint('PushNotificationService.unregisterToken (local) error: $e');
    }
  }

  Future<void> _sendTokenToBackend(String token) async {
    final platform = Platform.isIOS ? 'ios' : 'android';
    try {
      await Repository().fetchRegisterDeviceToken(token, platform);
    } catch (e) {
      debugPrint('device-token register failed: $e');
    }
  }

  void _onForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;
    _localNotifications.show(
      id: notification.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: message.data['type']?.toString(),
    );
  }

  /// Routes a tapped notification. Every type currently opens the notifications
  /// screen; extend here for deep-links (e.g. `broadcast` → a specific item).
  void _routeFromType(String type) {
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;
    navigator.push(
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
  }
}

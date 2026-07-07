import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../boot/crest_config.dart';
import 'agent_client.dart';
import 'vault_keeper.dart';

// ---------------------------------------------------------------------------
// BeaconDispatcher — FCM push receiver + local notification presenter
// ---------------------------------------------------------------------------
// Two responsibilities:
//   1) obtain the FCM token so the verdict endpoint can wire push targeting
//   2) route incoming push URLs to the right place depending on app state:
//
//        cold start   → save URL in vault (PortalGate claims it on next boot)
//        background   → hot-load into PortalStage WebView, DO NOT save
//        foreground   → show a local notification; if tapped, same as above
//
// Every failure path is swallowed so a missing google-services.json only
// disables push; the game itself keeps working.
// ---------------------------------------------------------------------------

@pragma('vm:entry-point')
Future<void> _bgHandler(RemoteMessage message) async {
  // Nothing to do — the OS renders the notification and we only care about
  // the tap, which arrives via onMessageOpenedApp / getInitialMessage.
}

class BeaconDispatcher {
  final VaultKeeper _vault;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  FirebaseMessaging? _fcm;
  String? _token;
  bool _initDone = false;

  /// Fired when the user taps a warm push (background / foreground) — the
  /// value is the URL from `data.url`. PortalStage listens to this and hot
  /// loads the URL into the WebView.
  void Function(String url)? onWarmTap;

  /// Fired when FCM rotates the token. PortalGate re-POSTs the verdict body.
  void Function(String newToken)? onTokenRefresh;

  BeaconDispatcher(this._vault);

  String? get token => _token;

  Future<void> boot() async {
    // Phase 1 — one-time wiring that does NOT need connectivity. Registering
    // the listeners and channel must survive an offline first run, otherwise a
    // later online retry (No-WiFi → Reconnect) reuses this same instance and
    // would leave the message listeners unregistered forever.
    if (!_initDone) {
      try {
        await Firebase.initializeApp();
        _fcm = FirebaseMessaging.instance;
        FirebaseMessaging.onBackgroundMessage(_bgHandler);
        await _wireLocalNotifications();

        _fcm!.onTokenRefresh.listen((refreshed) {
          _token = refreshed;
          onTokenRefresh?.call(refreshed);
        });
        FirebaseMessaging.onMessage.listen(_onForegroundMessage);
        FirebaseMessaging.onMessageOpenedApp.listen(_onBackgroundTap);

        final cold = await _fcm!.getInitialMessage();
        if (cold != null) _onColdTap(cold);

        _initDone = true;
      } catch (_) {
        // Firebase genuinely unavailable — retry the whole wiring next boot().
        return;
      }
    }

    // Phase 2 — token acquisition needs the network and is safe to retry. On an
    // offline first run getToken() fails; the online retry calls boot() again
    // and finally obtains the token so the verdict POST can carry it to the
    // backend for push targeting.
    await _ensureToken();
  }

  /// Fetch the FCM token, retrying across boot() calls until it succeeds.
  /// Idempotent: no-op once a token is cached.
  Future<void> _ensureToken() async {
    if (_token != null || _fcm == null) return;
    try {
      _token = await _fcm!.getToken();
    } catch (_) {
      // Still offline / FCM not reachable — a later boot() will retry.
    }
  }

  Future<void> _wireLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@drawable/ic_notification');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _local.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: (response) {
        final raw = response.payload;
        if (raw == null || raw.isEmpty) return;
        try {
          final decoded = jsonDecode(raw) as Map<String, dynamic>;
          final url = decoded['url'] as String?;
          if (url != null && url.isNotEmpty) onWarmTap?.call(url);
        } catch (_) {}
      },
    );

    if (Platform.isAndroid) {
      final plugin = _local.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await plugin?.createNotificationChannel(
        AndroidNotificationChannel(
          CrestConfig.notificationChannelId,
          CrestConfig.notificationChannelName,
          description: 'Push notifications from the Beacon of Olympus.',
          importance: Importance.high,
        ),
      );
    }
  }

  /// Ask the OS for notification permission (Android 13+ system dialog).
  /// Persists both the grant AND the "explicit denial" flag so the promo
  /// screen never re-nags a user who tapped "Don't allow".
  Future<bool> askPermission() async {
    final messaging = _fcm;
    if (messaging == null) return false;

    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    switch (settings.authorizationStatus) {
      case AuthorizationStatus.authorized:
      case AuthorizationStatus.provisional:
        await _vault.markPushGranted();
        return true;
      case AuthorizationStatus.denied:
        await _vault.markPushSystemDenied();
        return false;
      case AuthorizationStatus.notDetermined:
        // Older devices — no dialog to show. Treat as "granted" so we don't
        // gate the flow on nothing.
        await _vault.markPushGranted();
        return true;
    }
  }

  void _onColdTap(RemoteMessage message) {
    final url = message.data['url'] as String?;
    if (url != null && url.isNotEmpty) _vault.writePushUrl(url);
  }

  void _onBackgroundTap(RemoteMessage message) {
    final url = message.data['url'] as String?;
    if (url != null && url.isNotEmpty) onWarmTap?.call(url);
  }

  void _onForegroundMessage(RemoteMessage message) async {
    if (!Platform.isAndroid) return;
    final notification = message.notification;
    if (notification == null) return;

    AndroidNotificationDetails details;
    final bigPictureUrl = notification.android?.imageUrl;
    Uint8List? picture;
    if (bigPictureUrl != null && bigPictureUrl.isNotEmpty) {
      picture = await _fetchImage(bigPictureUrl);
    }

    if (picture != null) {
      details = AndroidNotificationDetails(
        CrestConfig.notificationChannelId,
        CrestConfig.notificationChannelName,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@drawable/ic_notification',
        styleInformation: BigPictureStyleInformation(
          ByteArrayAndroidBitmap(picture),
          largeIcon:
              const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        ),
      );
    } else {
      details = AndroidNotificationDetails(
        CrestConfig.notificationChannelId,
        CrestConfig.notificationChannelName,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@drawable/ic_notification',
      );
    }

    final payload =
        message.data.isNotEmpty ? jsonEncode(message.data) : null;

    await _local.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(android: details),
      payload: payload,
    );
  }

  Future<Uint8List?> _fetchImage(String url) async {
    try {
      final resp = await agent
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) return resp.bodyBytes;
    } catch (_) {}
    return null;
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'package:flutter/foundation.dart';

import '../boot/crest_config.dart';
import '../boot/verdict_wire.dart';
import 'agent_client.dart';

// ---------------------------------------------------------------------------
// AttributionSeer — AppsFlyer wrapper for the gray flow
// ---------------------------------------------------------------------------
// Responsibilities:
//   * initialise the AppsFlyer SDK exactly once, wire every callback we care
//     about (conversion, deep link, app-open)
//   * expose two awaitables — [conversionArrived] and [deepLinkArrived] —
//     so PortalGate can proceed as soon as either produces useful data
//   * treat a first-shot af_status=="Organic" as untrusted: wait
//     [CrestConfig.attributionRetryDelay] and try the GCD REST endpoint
//     directly, replacing the payload if we can
//   * merge everything into a single POST body preserving every attribution
//     field verbatim — the backend depends on the full set
// ---------------------------------------------------------------------------

class AttributionSeer {
  AppsflyerSdk? _sdk;

  final Map<String, dynamic> _conversion = {};
  final Map<String, dynamic> _deepLink = {};
  final Map<String, dynamic> _appOpen = {};

  final Completer<Map<String, dynamic>> _conversionReady = Completer();
  final Completer<void> _deepLinkReady = Completer();

  bool _wired = false;

  Future<Map<String, dynamic>> get conversionArrived =>
      _conversionReady.future;
  Future<void> get deepLinkArrived => _deepLinkReady.future;

  Future<void> ignite() async {
    if (_wired) return;
    _wired = true;

    final options = AppsFlyerOptions(
      afDevKey: CrestConfig.appsFlyerDevKey,
      appId: CrestConfig.storefrontNumericId,
      showDebug: kDebugMode,
      timeToWaitForATTUserAuthorization: 10,
    );

    _sdk = AppsflyerSdk(options);

    _sdk!.onInstallConversionData((payload) async {
      final map = _flattenPayload(payload);
      final status = '${map['af_status'] ?? ''}';
      if (status == 'Organic') {
        // AppsFlyer sometimes fires Organic even for paid installs. Give the
        // SDK a beat, then ask GCD directly for the truth.
        await Future.delayed(CrestConfig.attributionRetryDelay);
        final refined = await _pullGcd();
        _conversion
          ..clear()
          ..addAll(refined ?? map);
      } else {
        _conversion
          ..clear()
          ..addAll(map);
      }
      if (!_conversionReady.isCompleted) {
        _conversionReady.complete(Map<String, dynamic>.from(_conversion));
      }
    });

    _sdk!.onAppOpenAttribution((payload) {
      _appOpen
        ..clear()
        ..addAll(_flattenPayload(payload));
    });

    _sdk!.onDeepLinking((result) {
      try {
        final click = result.deepLink?.clickEvent;
        if (click != null && click.isNotEmpty) {
          _deepLink
            ..clear()
            ..addAll(Map<String, dynamic>.from(click));
        }
      } catch (_) {}
      if (!_deepLinkReady.isCompleted) _deepLinkReady.complete();
    });

    try {
      await _sdk!.initSdk(
        registerConversionDataCallback: true,
        registerOnAppOpenAttributionCallback: true,
        registerOnDeepLinkingCallback: true,
      );
    } catch (_) {
      // SDK init failing must not kill the app; the verdict endpoint will
      // still receive whatever device-side fields we have.
      if (!_conversionReady.isCompleted) {
        _conversionReady.complete(<String, dynamic>{});
      }
      if (!_deepLinkReady.isCompleted) _deepLinkReady.complete();
    }
  }

  Map<String, dynamic> _flattenPayload(dynamic payload) {
    try {
      if (payload is Map && payload['payload'] is Map) {
        return Map<String, dynamic>.from(payload['payload'] as Map);
      }
      if (payload is Map) return Map<String, dynamic>.from(payload);
    } catch (_) {}
    return <String, dynamic>{};
  }

  Future<Map<String, dynamic>?> _pullGcd() async {
    try {
      final uid = await _sdk?.getAppsFlyerUID();
      if (uid == null || uid.isEmpty) return null;
      final url = buildGcdUrl(CrestConfig.bundleId, uid);
      if (url.isEmpty) return null;

      final response = await agent
          .get(Uri.parse(url), headers: {
            'authorization': 'Bearer ${CrestConfig.appsFlyerDevKey}',
          })
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  Future<String?> uid() async {
    try {
      return await _sdk?.getAppsFlyerUID();
    } catch (_) {
      return null;
    }
  }

  /// Merge attribution + deep link + device data into the POST body sent to
  /// the verdict endpoint. Ordering matters: attribution first, then
  /// putIfAbsent for the softer sources, then device fields overwrite
  /// duplicates.
  Future<Map<String, dynamic>> assemblePayload({
    required String locale,
    String? pushToken,
  }) async {
    final body = <String, dynamic>{};
    body.addAll(_conversion);
    _deepLink.forEach((k, v) => body.putIfAbsent(k, () => v));
    _appOpen.forEach((k, v) => body.putIfAbsent(k, () => v));

    body['af_id'] = (await uid()) ?? '';
    body['bundle_id'] = CrestConfig.bundleId;
    body['os'] = Platform.isAndroid ? 'Android' : 'iOS';
    body['store_id'] = CrestConfig.storeId;
    body['locale'] = locale;
    if (pushToken != null && pushToken.isNotEmpty) {
      body['push_token'] = pushToken;
    }
    final senderId = CrestConfig.firebaseSenderId;
    if (senderId.isNotEmpty) {
      body['firebase_project_id'] = senderId;
    }

    if (kDebugMode) {
      // ignore: avoid_print
      print('[AttributionSeer] payload => ${jsonEncode(body)}');
    }
    return body;
  }
}

import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;

import '../boot/crest_config.dart';
import '../cipher/veil.dart';

// ---------------------------------------------------------------------------
// AgentClient — HTTP client with a real-device User-Agent
// ---------------------------------------------------------------------------
// A raw Dart/Flutter User-Agent gets a request flagged as automated by both
// AppsFlyer and the affiliate networks, so every outgoing call is stamped
// with a browser-shaped UA built from real device info collected via
// device_info_plus.
//
// The Zeus/Olympus slot theme also requires an appid/appname suffix at the
// tail of the UA (see gray_user_agent rule). It's applied to both the HTTP
// client and the WebView, so the two traffic streams look uniform.
// ---------------------------------------------------------------------------

// "132.0.6834.163"
const List<int> _chromeVersionEnc = <int>[
  0xC7, 0xCA, 0x2E, 0x24, 0x43, 0x2A, 0xC9, 0x2E,
  0xA4, 0xE1, 0x86, 0x64, 0xB3, 0xF1,
];

// "537.36"
const List<int> _webkitVersionEnc = <int>[
  0xC3, 0xCA, 0x2B, 0x24, 0x40, 0x32,
];

String get _chromeVersion => unveil(_chromeVersionEnc);
String get _webkitVersion => unveil(_webkitVersionEnc);

class AgentClient extends http.BaseClient {
  final http.Client _delegate = http.Client();
  String? _ua;
  bool _prepared = false;

  /// Build the UA once, on app boot. Cheap on real devices.
  Future<void> prepare() async {
    if (_prepared) return;
    _prepared = true;
    _ua = await _composeUserAgent();
  }

  /// Final UA string. Guaranteed non-null even if [prepare] wasn't awaited —
  /// falls back to a generic Pixel 8 UA so calls don't crash.
  String get userAgent => _ua ?? _fallbackUa();

  Future<String> _composeUserAgent() async {
    final chrome = _chromeVersion.isEmpty ? '132.0.6834.163' : _chromeVersion;
    final wk = _webkitVersion.isEmpty ? '537.36' : _webkitVersion;
    final tail =
        'appid/${CrestConfig.bundleId} appname/${CrestConfig.uaName}';

    try {
      if (Platform.isAndroid) {
        final info = await DeviceInfoPlugin().androidInfo;
        final buildTag = info.display.isNotEmpty ? info.display : info.id;
        // Use the marketing release ("16"), NOT version.sdkInt (API level 36).
        final release =
            info.version.release.isNotEmpty ? info.version.release : '15';
        final base =
            'Mozilla/5.0 (Linux; Android $release; '
            '${info.brand} ${info.model} Build/$buildTag) '
            'AppleWebKit/$wk (KHTML, like Gecko) '
            'Chrome/$chrome Mobile Safari/$wk';
        return '$base $tail';
      } else {
        final info = await DeviceInfoPlugin().iosInfo;
        final osVer = info.systemVersion.replaceAll('.', '_');
        final base =
            'Mozilla/5.0 (iPhone; CPU iPhone OS $osVer like Mac OS X) '
            'AppleWebKit/$wk (KHTML, like Gecko) '
            'Version/${info.systemVersion} Mobile/15E148 Safari/$wk';
        return '$base $tail';
      }
    } catch (_) {
      return _fallbackUa();
    }
  }

  String _fallbackUa() {
    final chrome = _chromeVersion.isEmpty ? '132.0.6834.163' : _chromeVersion;
    final wk = _webkitVersion.isEmpty ? '537.36' : _webkitVersion;
    final tail =
        'appid/${CrestConfig.bundleId} appname/${CrestConfig.uaName}';
    if (Platform.isAndroid) {
      return 'Mozilla/5.0 (Linux; Android 15; Pixel 9) '
          'AppleWebKit/$wk (KHTML, like Gecko) '
          'Chrome/$chrome Mobile Safari/$wk $tail';
    }
    return 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) '
        'AppleWebKit/$wk (KHTML, like Gecko) '
        'Version/18.0 Mobile/15E148 Safari/$wk $tail';
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.putIfAbsent('User-Agent', () => userAgent);
    request.headers.putIfAbsent('Accept-Language', () => 'en-US,en;q=0.9');
    return _delegate.send(request);
  }

  @override
  void close() => _delegate.close();
}

/// Shared client — instantiated once in main().
final AgentClient agent = AgentClient();

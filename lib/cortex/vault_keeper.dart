import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../boot/crest_config.dart';
import '../verdict/launch_mode.dart';

// ---------------------------------------------------------------------------
// VaultKeeper — persistence layer
// ---------------------------------------------------------------------------
// URLs live in encrypted secure storage (Keystore-backed on Android). Small
// bookkeeping flags live in SharedPreferences.
//
// Push permission bookkeeping is the trickiest part:
//   * `pushGranted`        — set to true only when the OS confirms grant.
//   * `pushSkipUntilEpoch` — filled with a future epoch when user taps Skip
//                            or the OS denies; the promo re-shows past it.
//   * `pushSystemDenied`   — set once the OS reports `denied` in the SDK
//                            answer. From that moment the promo must NEVER
//                            re-appear because Android will silently swallow
//                            requestPermission() on API 33+ once the user has
//                            picked "Don't allow".
//
// Missing this last flag is exactly the "3-days-later Accept button that does
// nothing" bug called out in the guide.
// ---------------------------------------------------------------------------

class VaultKeeper {
  static const String _kMode = 'launch.mode.v2';
  static const String _kSkipUntil = 'push.skipUntil';
  static const String _kGranted = 'push.granted';
  static const String _kSystemDenied = 'push.sysDenied';
  static const String _kExpires = 'verdict.expires';

  // Secure storage keys deliberately use short, non-descriptive names.
  static const String _sVerdictUrl = 'v_u';
  static const String _sPushUrl = 'p_u';

  late SharedPreferences _prefs;
  final FlutterSecureStorage _secure = const FlutterSecureStorage();

  Future<void> boot() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ------------------ Launch mode -------------------
  LaunchMode readMode() => LaunchMode.decode(_prefs.getString(_kMode));
  Future<void> writeMode(LaunchMode mode) =>
      _prefs.setString(_kMode, mode.encode());

  // ------------------ Verdict URL -------------------
  Future<String?> readVerdictUrl() => _secure.read(key: _sVerdictUrl);
  Future<void> writeVerdictUrl(String url) =>
      _secure.write(key: _sVerdictUrl, value: url);
  Future<void> writeExpires(int epoch) => _prefs.setInt(_kExpires, epoch);
  int? readExpires() => _prefs.getInt(_kExpires);
  bool isVerdictExpired() {
    final e = readExpires();
    if (e == null) return true;
    return DateTime.now().millisecondsSinceEpoch ~/ 1000 >= e;
  }

  // ------------------ Push URL (one-shot) -------------------
  Future<String?> readPushUrl() => _secure.read(key: _sPushUrl);
  Future<void> writePushUrl(String url) =>
      _secure.write(key: _sPushUrl, value: url);
  Future<void> dropPushUrl() => _secure.delete(key: _sPushUrl);

  Future<String?> claimPushUrl() async {
    final url = await readPushUrl();
    if (url != null) await dropPushUrl();
    return url;
  }

  // ------------------ Push permission bookkeeping -------------------
  bool get pushGranted => _prefs.getBool(_kGranted) ?? false;
  Future<void> markPushGranted() => _prefs.setBool(_kGranted, true);

  bool get pushSystemDenied => _prefs.getBool(_kSystemDenied) ?? false;
  Future<void> markPushSystemDenied() => _prefs.setBool(_kSystemDenied, true);

  int? get pushSkipUntilEpoch => _prefs.getInt(_kSkipUntil);
  Future<void> setPushSkipCooldown() {
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return _prefs.setInt(
      _kSkipUntil,
      nowSec + CrestConfig.pushSkipCooldown.inSeconds,
    );
  }

  /// Should the promo screen show up before opening the portal?
  ///
  /// The check ladder — first "true" wins:
  ///   1) already granted → no
  ///   2) OS said "denied" once → no (never again)
  ///   3) never asked → yes
  ///   4) inside the skip cooldown → no
  ///   5) past the cooldown → yes
  bool shouldOfferPushPromo() {
    if (pushGranted) return false;
    if (pushSystemDenied) return false;
    final skipUntil = pushSkipUntilEpoch;
    if (skipUntil == null) return true;
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return nowSec >= skipUntil;
  }
}

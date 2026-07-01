import 'portal_wire.dart';
import 'verdict_wire.dart';
import 'legal_wire.dart';

// ---------------------------------------------------------------------------
// CrestConfig — one-stop-shop for app identity + resolved secrets
// ---------------------------------------------------------------------------
// Every runtime component (routing, HTTP, WebView UA, push channel) reads
// its inputs from CrestConfig, so swapping bundle id / build variant only
// needs edits in this one file plus the underlying wire modules.
// ---------------------------------------------------------------------------

class CrestConfig {
  // Immutable identity
  static const String bundleId = 'com.olympcrown.crownofolympus';
  static const String storeId = 'com.olympcrown.crownofolympus';
  static const String humanName = 'Crown of Olympus';

  // Space-free identity token appended to the WebView / HTTP User-Agent.
  // The gray-flow SLOT-theme rules (Zeus lineage) require appname/... to be
  // camel-cased and free of whitespace.
  static const String uaName = 'CrownOfOlympus';

  // Empty on Android — iOS App Store numeric id would live here.
  static const String storefrontNumericId = '';

  // How long to wait between retries of the push permission prompt when the
  // user tapped "Skip". 3 days, per TZ.
  static const Duration pushSkipCooldown = Duration(days: 3);

  // AppsFlyer sometimes returns af_status=="Organic" on the first callback
  // even for paid installs — retry via GCD after this delay.
  static const Duration attributionRetryDelay = Duration(seconds: 5);

  // Notification channel id — shared with AndroidManifest meta-data.
  static const String notificationChannelId = 'olympus_beacon_channel';
  static const String notificationChannelName = 'Beacon of Olympus';

  // Lazy secret resolution — never store plaintext in a field.
  static String get verdictEndpoint => resolveVerdictUrl();
  static String get appsFlyerDevKey => resolveAfDevKey();
  static String get firebaseSenderId => resolveFirebaseSenderId();

  // Legal pass-through so the game menu only needs to import CrestConfig.
  static String get privacyPolicyUrl => LegalWire.privacy;
  static String get supportUrl => LegalWire.support;
  static String get siteUrl => LegalWire.site;
}

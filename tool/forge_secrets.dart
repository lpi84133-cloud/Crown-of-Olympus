// ignore_for_file: avoid_print
//
// Run with: dart run tool/forge_secrets.dart
//
// Emits XOR-encoded byte arrays that go into lib/boot/*.dart alongside their
// unveil() call sites. Uses the same [_stream] as lib/cipher/veil.dart so
// values round-trip at runtime.
//
// NEVER use PowerShell foreach loops for this — 32-bit integer overflow on
// Windows silently produces wrong bytes.

import 'package:crownofolympus/cipher/veil.dart';

const _plaintexts = <String, String>{
  // --- verdict endpoint (portal_wire.dart) ---
  'verdictHost': 'https://crownofollympus.com',
  'verdictPath': '/config.php',

  // --- AppsFlyer + Firebase (verdict_wire.dart) ---
  'appsFlyerDevKey': 'uWqxSpaEjsvnBuFe7VDGMN',
  'firebaseSenderId': '344599505311',
  'gcdHost': 'https://gcdsdk.appsflyer.com',
  'gcdPath': '/install_data/v4.0/',

  // --- Browser UA fragments (agent_client.dart) ---
  'chromeVersion': '132.0.6834.163',
  'safariVersion': '537.36',
};

void main() {
  for (final entry in _plaintexts.entries) {
    final label = entry.key;
    final plain = entry.value;
    final bytes = shroud(plain);
    final decoded = unveil(bytes);
    final roundtripOk = decoded == plain;

    print('');
    print('// $label  (plain: "$plain")  roundtrip=$roundtripOk');
    print('const <int>[');
    for (int i = 0; i < bytes.length; i += 8) {
      final chunk = bytes.sublist(i, (i + 8).clamp(0, bytes.length));
      final hex = chunk
          .map((b) => '0x${b.toRadixString(16).padLeft(2, '0').toUpperCase()}')
          .join(', ');
      print('  $hex,');
    }
    print(']');
  }
}

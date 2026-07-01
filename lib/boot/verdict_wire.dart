import '../cipher/veil.dart';

// ---------------------------------------------------------------------------
// verdict_wire — obfuscated AppsFlyer + Firebase identifiers
// ---------------------------------------------------------------------------
// AppsFlyer dev-key, Firebase sender id and the GCD fallback endpoint. Every
// value is XOR-encoded — refresh via `dart run tool/forge_secrets.dart`.
// ---------------------------------------------------------------------------

// AppsFlyer Dev Key
const List<int> _afDevKey = <int>[
  0x83, 0xAE, 0x6D, 0x72, 0x20, 0x74, 0x9E, 0x53,
  0xFD, 0xA6, 0xDE, 0x3B, 0xC7, 0xB7, 0x0D, 0x06,
  0xD9, 0x15, 0xB0, 0x90, 0xBB, 0xB7,
];

// Firebase project number (sender id)
const List<int> _firebaseSender = <int>[
  0xC5, 0xCD, 0x28, 0x3F, 0x4A, 0x3D, 0xCA, 0x26,
  0xA2, 0xE6, 0x99, 0x64,
];

// "https://gcdsdk.appsflyer.com"
const List<int> _gcdHost = <int>[
  0x9E, 0x8D, 0x68, 0x7A, 0x00, 0x3E, 0xD0, 0x39,
  0xF0, 0xB6, 0xCC, 0x26, 0xE1, 0xA9, 0x65, 0x02,
  0x9E, 0x33, 0x87, 0xB1, 0x9A, 0x80, 0x79, 0x78,
  0x5D, 0x67, 0x90, 0x7B,
];

// "/install_data/v4.0/"
const List<int> _gcdPath = <int>[
  0xD9, 0x90, 0x72, 0x79, 0x07, 0x65, 0x93, 0x7A,
  0xC8, 0xB1, 0xC9, 0x21, 0xE4, 0xED, 0x3D, 0x57,
  0xC0, 0x73, 0xDB,
];

/// AppsFlyer Dev Key — used as SDK init key and as Bearer token for GCD.
String resolveAfDevKey() =>
    _afDevKey.isEmpty ? '' : unveil(_afDevKey);

/// Firebase project number (sender id) — attached to the verdict payload so
/// the backend can wire push targeting to the right project.
String resolveFirebaseSenderId() =>
    _firebaseSender.isEmpty ? '' : unveil(_firebaseSender);

/// Build the GCD conversion-data URL for a given app / device pair.
///
/// Format: `${host}${path}${appId}?device_id=${deviceId}`
String buildGcdUrl(String appId, String deviceId) {
  if (_gcdHost.isEmpty) return '';
  return '${unveil(_gcdHost)}${unveil(_gcdPath)}$appId?device_id=$deviceId';
}

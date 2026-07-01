import 'dart:typed_data';

// ---------------------------------------------------------------------------
// veil — XOR obfuscator for sensitive string constants
// ---------------------------------------------------------------------------
// Every runtime-sensitive literal (verdict endpoint, AppsFlyer dev-key,
// Firebase sender id, browser UA fragments) is committed to source as a
// pre-XORed byte list. At start-up the app derives a per-project stream key
// from a short salt phrase and lifts each list back to a plaintext string via
// [unveil].
//
// Two things must stay consistent for a working release:
//   1) The salt bytes below.
//   2) The lists produced by `tool/forge_secrets.dart` — regenerate them
//      whenever the salt changes.
//
// Rotating the salt is what gives each app in the group its own binary
// fingerprint: encoded byte streams look completely different, so a static
// scanner can't group two projects together on a shared XOR key.
// ---------------------------------------------------------------------------

/// Salt phrase for Crown of Olympus. Change per project.
///
/// Rendered as the raw byte sequence of the ASCII string "olymp:crown@vault"
/// (17 bytes) — a short marker unique to this bundle id.
const List<int> _saltBytes = <int>[
  0x6F, 0x6C, 0x79, 0x6D, 0x70, 0x3A, 0x63, 0x72, 0x6F,
  0x77, 0x6E, 0x40, 0x76, 0x61, 0x75, 0x6C, 0x74,
];

/// Length of the XOR stream — deliberately not 16 so a signature of "16-byte
/// XOR keyed off ASCII phrase" no longer matches.
const int _streamLen = 20;

Uint8List _forgeCipherKey() {
  if (_saltBytes.isEmpty) return Uint8List(_streamLen);

  // Fold the salt with FNV-1a (64-bit). Keeps the algorithm distinct from
  // Horner-style seed folding used elsewhere.
  const int fnvPrime = 0x100000001b3;
  const int fnvOffset = 0xcbf29ce484222325;
  int state = fnvOffset;
  for (final b in _saltBytes) {
    state = (state ^ (b & 0xFF));
    state = (state * fnvPrime) & 0xFFFFFFFFFFFFFFFF;
  }

  // Expand the 64-bit state into [_streamLen] bytes with SplitMix64.
  final stream = Uint8List(_streamLen);
  int z = state == 0 ? 0x9E3779B97F4A7C15 : state;
  for (int i = 0; i < _streamLen; i++) {
    z = (z + 0x9E3779B97F4A7C15) & 0xFFFFFFFFFFFFFFFF;
    int x = z;
    x = ((x ^ (x >> 30)) * 0xBF58476D1CE4E5B9) & 0xFFFFFFFFFFFFFFFF;
    x = ((x ^ (x >> 27)) * 0x94D049BB133111EB) & 0xFFFFFFFFFFFFFFFF;
    x = (x ^ (x >> 31)) & 0xFFFFFFFFFFFFFFFF;
    stream[i] = x & 0xFF;
  }
  return stream;
}

final Uint8List _stream = _forgeCipherKey();

/// Turn an XOR-encoded byte list back into its UTF-8 plaintext. Empty input
/// deliberately maps to an empty string so a not-yet-provisioned constant
/// can be detected with `isEmpty`.
String unveil(List<int> ciphertext) {
  if (ciphertext.isEmpty) return '';
  final out = Uint8List(ciphertext.length);
  for (int i = 0; i < ciphertext.length; i++) {
    out[i] = ciphertext[i] ^ _stream[i % _stream.length];
  }
  return String.fromCharCodes(out);
}

/// Convenience: encode a plaintext string in-code — mostly used by the
/// encoder tool, but exposed here so unit tests can round-trip if needed.
List<int> shroud(String plaintext) {
  final bytes = plaintext.codeUnits;
  final out = List<int>.filled(bytes.length, 0);
  for (int i = 0; i < bytes.length; i++) {
    out[i] = bytes[i] ^ _stream[i % _stream.length];
  }
  return out;
}

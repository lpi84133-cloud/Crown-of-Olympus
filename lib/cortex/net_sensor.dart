import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

// ---------------------------------------------------------------------------
// NetSensor — connectivity + reachability probe
// ---------------------------------------------------------------------------
// Two things must be true for the app to consider the device online:
//   1) At least one connectivity plane is present.
//   2) DNS resolves within the probe timeout.
//
// The probe host is intentionally boring (cloudflare's DNS-over-HTTPS
// endpoint), so it doesn't pattern-match to a specific analytics vendor.
//
// VPN nuance (gray_part_pitfalls #3):
//   connectivity_plus flashes `[ConnectivityResult.none]` for a few hundred
//   milliseconds when a VPN tunnel is being brought up. VPN itself IS an
//   active interface, so it must be whitelisted alongside wifi / mobile /
//   ethernet, and callers that react to the stream must debounce at least
//   ~700ms before routing to the offline screen.
// ---------------------------------------------------------------------------

const Set<ConnectivityResult> _activeChannels = {
  ConnectivityResult.wifi,
  ConnectivityResult.mobile,
  ConnectivityResult.ethernet,
  ConnectivityResult.vpn,
  ConnectivityResult.bluetooth,
  ConnectivityResult.other,
};

class NetSensor {
  static const String _probeHost = 'one.one.one.one';
  static const Duration _probeTimeout = Duration(seconds: 7);

  final Connectivity _connectivity = Connectivity();

  /// Full "am I really online?" check: interface + DNS lookup.
  Future<bool> isOnline() async {
    try {
      final channels = await _connectivity.checkConnectivity();
      if (!channels.any(_activeChannels.contains)) return false;
    } catch (_) {
      // If we can't even ask connectivity_plus, fall through to DNS.
    }

    try {
      final results = await InternetAddress.lookup(_probeHost)
          .timeout(_probeTimeout);
      return results.isNotEmpty && results.first.rawAddress.isNotEmpty;
    } on SocketException {
      return false;
    } catch (_) {
      return false;
    }
  }

  Stream<List<ConnectivityResult>> get channelStream =>
      _connectivity.onConnectivityChanged;

  /// Convenience helper for stream listeners: true when every channel in the
  /// snapshot is `none`.
  static bool allInactive(List<ConnectivityResult> snapshot) {
    if (snapshot.isEmpty) return true;
    return snapshot.every((c) => c == ConnectivityResult.none);
  }
}

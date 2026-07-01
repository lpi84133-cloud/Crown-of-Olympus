// ---------------------------------------------------------------------------
// LaunchMode — persisted routing decision for this install
// ---------------------------------------------------------------------------
// Set once the verdict endpoint has spoken. On every subsequent cold boot
// the persisted value branches the router in PortalGate:
//   web   -> re-fetch verdict, open portal (WebView)
//   game  -> skip the network entirely, straight to the maze
//   probe -> first launch, run the full verdict pipeline
// ---------------------------------------------------------------------------

enum LaunchMode {
  web,
  game,
  probe;

  static LaunchMode decode(String? persisted) {
    switch (persisted) {
      case 'web':
        return LaunchMode.web;
      case 'game':
        return LaunchMode.game;
      default:
        return LaunchMode.probe;
    }
  }

  String encode() {
    switch (this) {
      case LaunchMode.web:
        return 'web';
      case LaunchMode.game:
        return 'game';
      case LaunchMode.probe:
        return 'probe';
    }
  }
}

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../cortex/attribution_seer.dart';
import '../cortex/beacon_dispatcher.dart';
import '../cortex/net_sensor.dart';
import '../cortex/vault_keeper.dart';
import '../cortex/verdict_gateway.dart';
import '../data/progress.dart';
import '../screens/menu_screen.dart';
import '../ui/theme.dart';
import '../verdict/launch_mode.dart';
import 'connection_lost.dart';
import 'portal_stage.dart' deferred as stage;
import 'push_promo.dart' deferred as promo;

// ---------------------------------------------------------------------------
// PortalGate — the single splash + boot router
// ---------------------------------------------------------------------------
// One splash screen for the whole boot cycle. The progress bar reflects the
// actual work being done — every phase advances a milestone, so the fill
// visibly grows in real time (not a fake 2.4s ramp).
//
// Terminal routes:
//   LaunchMode.game  → MenuScreen (portrait, no network needed)
//   LaunchMode.web   → PortalStage (deferred WebView engine)
//   LaunchMode.probe → verdict pipeline → one of the above
//   offline first-run→ MenuScreen (product ask: white part boots without net)
// ---------------------------------------------------------------------------

// Progress milestones — each phase reports its final fraction. The renderer
// eases toward the target continuously so the bar never snaps.
const double _pBoot = 0.10;
const double _pMode = 0.20;
const double _pNetCheck = 0.32;
const double _pAttrKick = 0.46;
const double _pAttrDone = 0.68;
const double _pVerdict = 0.84;
const double _pEngine = 0.94;
const double _pReady = 1.00;

class PortalGate extends StatefulWidget {
  final VaultKeeper vault;
  final NetSensor sensor;
  final AttributionSeer seer;
  final VerdictGateway gateway;
  final BeaconDispatcher beacon;

  const PortalGate({
    super.key,
    required this.vault,
    required this.sensor,
    required this.seer,
    required this.gateway,
    required this.beacon,
  });

  @override
  State<PortalGate> createState() => _PortalGateState();
}

class _PortalGateState extends State<PortalGate> {
  bool _routed = false;

  /// Target the bar is easing toward — advanced by [_advance] as phases hit.
  double _target = 0.0;

  /// Currently rendered fill — animated via a periodic tick so we never
  /// snap directly to [_target].
  double _shown = 0.0;

  int _dots = 0;

  Timer? _tickTimer;
  Timer? _dotsTimer;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _dotsTimer = Timer.periodic(const Duration(milliseconds: 380), (_) {
      if (mounted) setState(() => _dots = (_dots + 1) % 4);
    });

    // Ease the rendered bar toward the target every 40ms.
    _tickTimer = Timer.periodic(const Duration(milliseconds: 40), (_) {
      if (!mounted) return;
      if ((_shown - _target).abs() < 0.0005) return;
      setState(() {
        _shown += (_target - _shown) * 0.14;
        if (_shown > 0.995 && _target >= 0.999) _shown = 1.0;
      });
    });

    _run();
  }

  void _advance(double target) {
    if (!mounted) return;
    if (target <= _target) return;
    _target = target.clamp(0.0, 1.0);
  }

  Future<void> _run() async {
    widget.beacon.onTokenRefresh = _handleTokenRefresh;
    await widget.beacon.boot().catchError((_) {});
    _advance(_pBoot);

    // Give the eye something to see even on very fast paths.
    await Future<void>.delayed(const Duration(milliseconds: 220));

    final mode = widget.vault.readMode();
    _advance(_pMode);

    switch (mode) {
      case LaunchMode.game:
        await _finishToMenu();
        return;

      case LaunchMode.web:
        await _resumeWebFlow();
        return;

      case LaunchMode.probe:
        await _firstRunFlow();
        return;
    }
  }

  // ------------------ Routing helpers -------------------

  Future<void> _resumeWebFlow() async {
    final pushUrl = await widget.vault.claimPushUrl();
    if (pushUrl != null && pushUrl.isNotEmpty) {
      _advance(_pEngine);
      await _finishToPortal(pushUrl);
      return;
    }

    final online = await widget.sensor.isOnline();
    _advance(_pNetCheck);

    if (!online) {
      final cached = await widget.gateway.cachedUrl();
      if (cached != null && cached.isNotEmpty) {
        _advance(_pEngine);
        await _finishToPortal(cached);
        return;
      }
      await _finishToLost();
      return;
    }

    unawaited(widget.seer.ignite());
    _advance(_pAttrKick);

    await Future.wait<dynamic>([
      widget.seer.conversionArrived
          .timeout(const Duration(seconds: 10), onTimeout: () => const {}),
      widget.seer.deepLinkArrived
          .timeout(const Duration(seconds: 5), onTimeout: () {}),
    ]);
    _advance(_pAttrDone);

    final locale = Platform.localeName.replaceAll('-', '_');
    final body = await widget.seer.assemblePayload(
      locale: locale,
      pushToken: widget.beacon.token,
    );
    final reply = await widget.gateway.ask(body);
    _advance(_pVerdict);

    if (reply.ok && reply.hasUrl) {
      await _finishToPortal(reply.url!);
      return;
    }

    final cached = await widget.gateway.cachedUrl();
    if (cached != null && cached.isNotEmpty) {
      await _finishToPortal(cached);
      return;
    }
    await _finishToLost();
  }

  Future<void> _firstRunFlow() async {
    final online = await widget.sensor.isOnline();
    _advance(_pNetCheck);

    if (!online) {
      // First run mode is still undetermined (we haven't reached config.php),
      // so a fresh onelink install with no network MUST show the No-WiFi
      // screen — never the white game, never the offer. Reconnect re-runs
      // PortalGate, which then resolves the verdict (test site / gray part).
      // The game boots offline only once the mode is already persisted as
      // LaunchMode.game (see _run()).
      await _finishToLost();
      return;
    }

    await widget.seer.ignite();
    _advance(_pAttrKick);

    await Future.wait<dynamic>([
      widget.seer.conversionArrived
          .timeout(const Duration(seconds: 30), onTimeout: () => const {}),
      widget.seer.deepLinkArrived
          .timeout(const Duration(seconds: 5), onTimeout: () {}),
    ]);
    _advance(_pAttrDone);

    final locale = Platform.localeName.replaceAll('-', '_');
    final body = await widget.seer.assemblePayload(
      locale: locale,
      pushToken: widget.beacon.token,
    );
    final reply = await widget.gateway.ask(body);
    _advance(_pVerdict);

    if (reply.ok && reply.hasUrl) {
      await widget.vault.writeMode(LaunchMode.web);
      await _finishToPortal(reply.url!);
    } else {
      await widget.vault.writeMode(LaunchMode.game);
      await _finishToMenu();
    }
  }

  void _handleTokenRefresh(String newToken) async {
    try {
      final locale = Platform.localeName.replaceAll('-', '_');
      final body = await widget.seer.assemblePayload(
        locale: locale,
        pushToken: newToken,
      );
      widget.gateway.ask(body);
    } catch (_) {}
  }

  // ------------------ Terminal navigations -------------------

  /// Waits until the eased bar has visibly reached [_pReady] before pushing,
  /// so the user always sees the last few tens-of-percents actually fill.
  Future<void> _waitForFillThen(VoidCallback push) async {
    _advance(_pReady);
    for (int i = 0; i < 40; i++) {
      if (!mounted) return;
      if (_shown >= 0.995) break;
      await Future<void>.delayed(const Duration(milliseconds: 30));
    }
    // Small dwell so users register the "100%" state before the transition.
    await Future<void>.delayed(const Duration(milliseconds: 220));
    if (!mounted) return;
    push();
  }

  Future<void> _finishToMenu() async {
    if (_routed) return;
    _routed = true;
    // The game itself is strictly portrait; also make sure Progress is
    // available before MenuScreen reads unlockedLevel.
    await Progress.instance.init();
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    await _waitForFillThen(() {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 450),
          pageBuilder: (_, _, _) => const MenuScreen(),
          transitionsBuilder: (_, anim, _, child) =>
              FadeTransition(opacity: anim, child: child),
        ),
      );
    });
  }

  Future<void> _finishToPortal(String url) async {
    if (_routed) return;
    _routed = true;
    await stage.loadLibrary();
    await stage.warmupPortalStage();
    _advance(_pEngine);

    if (widget.vault.shouldOfferPushPromo()) {
      await promo.loadLibrary();
      await _waitForFillThen(() {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => promo.PushPromoView(
              vault: widget.vault,
              beacon: widget.beacon,
              sensor: widget.sensor,
              portalUrl: url,
            ),
          ),
        );
      });
      return;
    }

    await _waitForFillThen(() {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => stage.PortalStage(
            entryUrl: url,
            vault: widget.vault,
            beacon: widget.beacon,
            sensor: widget.sensor,
          ),
        ),
      );
    });
  }

  Future<void> _finishToLost() async {
    if (_routed) return;
    _routed = true;
    await _waitForFillThen(() {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ConnectionLostView(
            retryBuilder: (_) => PortalGate(
              vault: widget.vault,
              sensor: widget.sensor,
              seer: widget.seer,
              gateway: widget.gateway,
              beacon: widget.beacon,
            ),
          ),
        ),
      );
    });
  }

  @override
  void dispose() {
    widget.beacon.onTokenRefresh = null;
    _tickTimer?.cancel();
    _dotsTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.night,
      body: OrientationBuilder(
        builder: (context, orientation) {
          final portrait = orientation == Orientation.portrait;
          final bg = portrait
              ? 'assets/verticalload.webp'
              : 'assets/horizontalload.webp';
          return Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(bg, fit: BoxFit.cover),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.center,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black87],
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: EdgeInsets.only(
                    left: 32,
                    right: 32,
                    bottom: portrait ? 70 : 34,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Loading${'.' * _dots}',
                        style: TextStyle(
                          color: AppTheme.brightGold,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 3,
                          shadows: AppTheme.titleShadow,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _EasedProgressBar(fill: _shown.clamp(0.0, 1.0)),
                      const SizedBox(height: 10),
                      Text(
                        '${(_shown.clamp(0.0, 1.0) * 100).round()}%',
                        style: const TextStyle(
                          color: AppTheme.marble,
                          fontSize: 14,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EasedProgressBar extends StatelessWidget {
  final double fill;
  const _EasedProgressBar({required this.fill});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        return Container(
          height: 20,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.gold, width: 2),
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              width: (maxW - 6).clamp(0.0, double.infinity) * fill,
              height: 12,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                gradient: AppTheme.goldGradient,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.brightGold.withValues(alpha: 0.6),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

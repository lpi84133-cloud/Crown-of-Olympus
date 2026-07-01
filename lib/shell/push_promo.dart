import 'package:flutter/material.dart';

import '../cortex/beacon_dispatcher.dart';
import '../cortex/net_sensor.dart';
import '../cortex/vault_keeper.dart';
import 'portal_stage.dart' deferred as stage;

// ---------------------------------------------------------------------------
// PushPromoView — one-shot pre-portal permission prompt
// ---------------------------------------------------------------------------
// Shows a full-bleed screen with a marble scroll on top of the artwork and
// two buttons — Accept / Skip — anchored at the bottom.
//
// The screen must respect gray_part_pitfalls guidance:
//   * A "denied" answer from the OS dialog persists forever (see VaultKeeper
//     .markPushSystemDenied) — the promo won't re-open on the next 3-day
//     cooldown expiry.
//   * A "skip" tap only sets a 3-day cooldown.
// After either interaction we always continue to the PortalStage.
// ---------------------------------------------------------------------------

class PushPromoView extends StatefulWidget {
  final VaultKeeper vault;
  final BeaconDispatcher beacon;
  final NetSensor sensor;
  final String portalUrl;

  const PushPromoView({
    super.key,
    required this.vault,
    required this.beacon,
    required this.sensor,
    required this.portalUrl,
  });

  @override
  State<PushPromoView> createState() => _PushPromoViewState();
}

class _PushPromoViewState extends State<PushPromoView> {
  bool _navigating = false;

  Future<void> _handleAccept() async {
    if (_navigating) return;
    _navigating = true;

    final ok = await widget.beacon.askPermission();
    if (!ok) {
      // Cover both "OS denied" (already persisted) and "user just declined";
      // either way we should stop nagging for a while.
      await widget.vault.setPushSkipCooldown();
    }
    if (!mounted) return;
    _openPortal();
  }

  Future<void> _handleSkip() async {
    if (_navigating) return;
    _navigating = true;
    await widget.vault.setPushSkipCooldown();
    if (!mounted) return;
    _openPortal();
  }

  Future<void> _openPortal() async {
    await stage.loadLibrary();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => stage.PortalStage(
          entryUrl: widget.portalUrl,
          vault: widget.vault,
          beacon: widget.beacon,
          sensor: widget.sensor,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final landscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final bg = landscape
        ? 'assets/Horizontal_Notifications_Screen.webp'
        : 'assets/Vertical_Notifications_Screen.webp';

    // Compact button block — deliberately narrow so it doesn't cover the
    // marble title baked into the background art. Landscape gets a further
    // narrower footprint since the visual area is much wider.
    final buttonWidth = landscape ? size.width * 0.32 : size.width * 0.58;
    final bottomInset = landscape ? size.height * 0.06 : size.height * 0.05;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SizedBox(
        width: size.width,
        height: size.height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(bg, fit: BoxFit.cover),
            Positioned(
              left: 0,
              right: 0,
              bottom: bottomInset,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: buttonWidth,
                    child: _MeanderButton(
                      label: 'Accept',
                      filled: true,
                      onTap: _handleAccept,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: buttonWidth,
                    child: _MeanderButton(
                      label: 'Skip',
                      filled: false,
                      onTap: _handleSkip,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Marble + gold meander-styled button used across the gray flow.
class _MeanderButton extends StatefulWidget {
  final String label;
  final bool filled;
  final VoidCallback onTap;

  const _MeanderButton({
    required this.label,
    required this.filled,
    required this.onTap,
  });

  @override
  State<_MeanderButton> createState() => _MeanderButtonState();
}

class _MeanderButtonState extends State<_MeanderButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      child: AnimatedScale(
        duration: const Duration(milliseconds: 90),
        scale: _pressed ? 0.96 : 1.0,
        child: Container(
          height: 42,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFFD873), width: 1.6),
            gradient: widget.filled
                ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF23345F),
                      Color(0xFF0B1E3B),
                    ],
                  )
                : null,
            color: widget.filled
                ? null
                : const Color(0xFF0B1E3B).withValues(alpha: 0.55),
            boxShadow: widget.filled
                ? [
                    BoxShadow(
                      color: const Color(0xFFFFD873).withValues(alpha: 0.28),
                      blurRadius: 10,
                      spreadRadius: 0,
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              widget.label.toUpperCase(),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.0,
                color: widget.filled
                    ? const Color(0xFFFFEFB4)
                    : const Color(0xFFF4ECD8),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

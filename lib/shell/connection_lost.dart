import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// ConnectionLostView — full-bleed background + single "Try Again" button
// ---------------------------------------------------------------------------
// Chooses the orientation-matched artwork (portrait / landscape) at build
// time. The button just re-runs whatever screen the caller passed in as
// [retryBuilder] — usually PortalGate.
// ---------------------------------------------------------------------------

class ConnectionLostView extends StatefulWidget {
  final WidgetBuilder retryBuilder;

  const ConnectionLostView({super.key, required this.retryBuilder});

  @override
  State<ConnectionLostView> createState() => _ConnectionLostViewState();
}

class _ConnectionLostViewState extends State<ConnectionLostView>
    with SingleTickerProviderStateMixin {
  bool _busy = false;
  late final AnimationController _shine;

  @override
  void initState() {
    super.initState();
    _shine = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _shine.dispose();
    super.dispose();
  }

  Future<void> _onRetry() async {
    if (_busy) return;
    setState(() => _busy = true);
    // Small delay so the user sees the button react even on lightning-fast
    // recovery paths (e.g. wifi flapping).
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: widget.retryBuilder),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final bg = isLandscape
        ? 'assets/Horizontal_Nowifi_Screen.webp'
        : 'assets/Vertical_Nowifi_Screen.webp';

    return Scaffold(
      backgroundColor: Colors.black,
      body: SizedBox(
        width: size.width,
        height: size.height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(bg,
                fit: BoxFit.cover, width: size.width, height: size.height),
            Positioned(
              left: isLandscape ? size.width * 0.32 : size.width * 0.12,
              right: isLandscape ? size.width * 0.32 : size.width * 0.12,
              bottom: isLandscape ? size.height * 0.10 : size.height * 0.11,
              child: _TryAgainButton(
                busy: _busy,
                onTap: _onRetry,
                pulse: _shine,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TryAgainButton extends StatelessWidget {
  final bool busy;
  final VoidCallback onTap;
  final Animation<double> pulse;

  const _TryAgainButton({
    required this.busy,
    required this.onTap,
    required this.pulse,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (_, _) {
        final glow = 0.35 + pulse.value * 0.35;
        return GestureDetector(
          onTap: busy ? null : onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: const Color(0xFFFFD873),
                width: 2.4,
              ),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF23345F),
                  Color(0xFF0B1E3B),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFD873).withValues(alpha: glow),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Center(
              child: busy
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Color(0xFFFFD873)),
                      ),
                    )
                  : const Text(
                      'TRY AGAIN',
                      style: TextStyle(
                        color: Color(0xFFFFEFB4),
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.6,
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/progress.dart';
import '../ui/theme.dart';
import 'menu_screen.dart';

/// Splash / loading screen.
///
/// This is the only screen allowed to be shown in landscape as well as
/// portrait. It picks the matching background art for the current orientation,
/// shows a left-to-right progress bar and an animated "Loading..." caption.
/// The bar only fills to 100% at the very last moment before launching the menu.
class LoadingScreen extends StatefulWidget {
  /// When true (default) the screen finishes by pushing the [MenuScreen].
  /// PortalGate renders this widget with [autoNavigate] disabled so it can
  /// keep the branded splash artwork on screen while the gray routing runs.
  final bool autoNavigate;

  const LoadingScreen({super.key, this.autoNavigate = true});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with SingleTickerProviderStateMixin {
  double _progress = 0.0;
  int _dots = 0;
  Timer? _progressTimer;
  Timer? _dotsTimer;
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    // Allow both orientations while on the loading screen.
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _dotsTimer = Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (mounted) setState(() => _dots = (_dots + 1) % 4);
    });

    // Ease the bar toward 90% so it feels like real work is happening.
    _progressTimer = Timer.periodic(const Duration(milliseconds: 60), (_) {
      if (!mounted || _finishing) return;
      setState(() => _progress += (0.9 - _progress) * 0.06);
    });

    _boot();
  }

  Future<void> _boot() async {
    final work = Future.wait([
      Progress.instance.init(),
      Future<void>.delayed(const Duration(milliseconds: 2400)),
    ]);
    await work;
    if (!mounted) return;

    // Fill the bar to 100% only right before launching.
    setState(() {
      _finishing = true;
      _progress = 1.0;
    });
    _progressTimer?.cancel();

    await Future<void>.delayed(const Duration(milliseconds: 550));
    if (!mounted) return;

    if (!widget.autoNavigate) return;

    // From here on the game itself is strictly vertical.
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, _, _) => const MenuScreen(),
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _dotsTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.night,
      body: OrientationBuilder(
        builder: (context, orientation) {
          final isPortrait = orientation == Orientation.portrait;
          final bgAsset = isPortrait
              ? 'assets/verticalload.webp'
              : 'assets/horizontalload.webp';
          return Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(bgAsset, fit: BoxFit.cover),
              // Subtle darkening at the bottom for text legibility.
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
                    bottom: isPortrait ? 70 : 34,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _LoadingCaption(dots: _dots),
                      const SizedBox(height: 16),
                      _ProgressBar(progress: _progress.clamp(0.0, 1.0)),
                      const SizedBox(height: 10),
                      Text(
                        '${(_progress.clamp(0.0, 1.0) * 100).round()}%',
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

class _LoadingCaption extends StatelessWidget {
  final int dots;
  const _LoadingCaption({required this.dots});

  @override
  Widget build(BuildContext context) {
    return Text(
      'Loading${'.' * dots}',
      style: TextStyle(
        color: AppTheme.brightGold,
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: 3,
        shadows: AppTheme.titleShadow,
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final double progress;
  const _ProgressBar({required this.progress});

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
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              width: (maxW - 6).clamp(0.0, double.infinity) * progress,
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

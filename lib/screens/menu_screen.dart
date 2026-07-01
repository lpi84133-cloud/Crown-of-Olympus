import 'package:flutter/material.dart';

import '../boot/crest_config.dart';
import '../data/progress.dart';
import '../shell/legal_reader.dart';
import '../ui/theme.dart';
import 'game_screen.dart';
import 'levels_screen.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  static String get privacyUrl => CrestConfig.privacyPolicyUrl;
  static String get supportUrl => CrestConfig.supportUrl;

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  void _openLevels() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const LevelsScreen()))
        .then((_) => setState(() {}));
  }

  void _play() {
    final lvl = Progress.instance.unlockedLevel;
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => GameScreen(level: lvl)))
        .then((_) => setState(() {}));
  }

  void _openWeb(String title, String url) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LegalReaderScreen(title: title, url: url),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unlocked = Progress.instance.unlockedLevel;
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/bggreek.webp', fit: BoxFit.cover),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppTheme.night.withValues(alpha: 0.35),
                  AppTheme.night.withValues(alpha: 0.85),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Expanded(
                    flex: 5,
                    child: Center(
                      child: Image.asset(
                        'assets/logogGreek.webp',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 6,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: OlympusButton(
                            label: unlocked > 1
                                ? 'Continue  ·  Level $unlocked'
                                : 'Play',
                            icon: Icons.play_arrow_rounded,
                            onTap: _play,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: OlympusButton(
                            label: 'Select Level',
                            icon: Icons.grid_view_rounded,
                            primary: false,
                            onTap: _openLevels,
                          ),
                        ),
                        const SizedBox(height: 28),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _MiniLink(
                              icon: Icons.privacy_tip_outlined,
                              label: 'Privacy Policy',
                              onTap: () => _openWeb(
                                'Privacy Policy',
                                MenuScreen.privacyUrl,
                              ),
                            ),
                            const SizedBox(width: 12),
                            _MiniLink(
                              icon: Icons.support_agent_outlined,
                              label: 'Support',
                              onTap: () =>
                                  _openWeb('Support', MenuScreen.supportUrl),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniLink extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MiniLink({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18, color: AppTheme.gold),
      label: Text(
        label,
        style: const TextStyle(color: AppTheme.marble, fontSize: 13),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
    );
  }
}

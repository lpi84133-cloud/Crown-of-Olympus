import 'package:flutter/material.dart';

import '../data/progress.dart';
import '../game/level_config.dart';
import '../ui/theme.dart';
import 'game_screen.dart';

class LevelsScreen extends StatefulWidget {
  const LevelsScreen({super.key});

  @override
  State<LevelsScreen> createState() => _LevelsScreenState();
}

class _LevelsScreenState extends State<LevelsScreen> {
  void _openLevel(int level) {
    if (!Progress.instance.isUnlocked(level)) return;
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => GameScreen(level: level)))
        .then((_) => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/bg21greek.webp', fit: BoxFit.cover),
          Container(color: AppTheme.night.withValues(alpha: 0.78)),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_rounded,
                            color: AppTheme.brightGold),
                      ),
                      Text(
                        'Select Level',
                        style: TextStyle(
                          color: AppTheme.brightGold,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                          shadows: AppTheme.titleShadow,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                    ),
                    itemCount: LevelConfig.totalLevels,
                    itemBuilder: (context, index) {
                      final level = index + 1;
                      final unlocked = Progress.instance.isUnlocked(level);
                      return _LevelTile(
                        level: level,
                        unlocked: unlocked,
                        onTap: () => _openLevel(level),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelTile extends StatelessWidget {
  final int level;
  final bool unlocked;
  final VoidCallback onTap;

  const _LevelTile({
    required this.level,
    required this.unlocked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: unlocked
              ? const LinearGradient(
                  colors: [Color(0xFF1B3D6B), Color(0xFF0B1E3B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: unlocked ? null : Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: unlocked
                ? AppTheme.gold
                : AppTheme.gold.withValues(alpha: 0.25),
            width: 2,
          ),
          boxShadow: unlocked
              ? [
                  BoxShadow(
                    color: AppTheme.gold.withValues(alpha: 0.25),
                    blurRadius: 8,
                  ),
                ]
              : null,
        ),
        child: Center(
          child: unlocked
              ? Text(
                  '$level',
                  style: const TextStyle(
                    color: AppTheme.marble,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                )
              : Icon(
                  Icons.lock_rounded,
                  color: AppTheme.gold.withValues(alpha: 0.5),
                  size: 22,
                ),
        ),
      ),
    );
  }
}

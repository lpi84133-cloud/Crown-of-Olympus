import 'dart:math' as math;

/// Configuration for a single level.
///
/// The difficulty ramps up across the 40 levels: the maze gets larger, the
/// vision radius (how far the torch light reaches through the fog) gets
/// smaller, and there are more collectible torches to help the player.
class LevelConfig {
  final int level;

  /// Maze size in logical cells (before adding wall separators).
  final int cols;
  final int rows;

  /// How many tiles around the hero are lit through the fog.
  final double visionRadius;

  /// Number of collectible torches scattered around the maze.
  final int torches;

  const LevelConfig({
    required this.level,
    required this.cols,
    required this.rows,
    required this.visionRadius,
    required this.torches,
  });

  static const int totalLevels = 40;

  /// Builds the configuration for a level (1..40) using a smooth curve so the
  /// game clearly goes from easy to hard.
  factory LevelConfig.forLevel(int level) {
    final int lvl = level.clamp(1, totalLevels);
    final double t = (lvl - 1) / (totalLevels - 1); // 0.0 .. 1.0

    // Maze grows from 4x4 up to 15x15 cells.
    final int cells = (4 + (t * 11)).round();

    // Vision shrinks from a modest 2.6 tiles down to a very tense 1.15 tiles,
    // so the fog matters right from the first level.
    final double vision = 2.6 - t * 1.45;

    // Torch pickups grow from 1 to 6 as levels get darker/larger.
    final int torches = (1 + (t * 5)).round();

    return LevelConfig(
      level: lvl,
      cols: cells,
      rows: cells,
      visionRadius: double.parse(vision.toStringAsFixed(2)),
      torches: torches,
    );
  }

  /// A short difficulty label for the UI.
  String get difficultyLabel {
    if (level <= 10) return 'Novice';
    if (level <= 20) return 'Seeker';
    if (level <= 30) return 'Champion';
    return 'Legend';
  }

  /// Deterministic RNG so a given level always looks the same.
  math.Random newRandom() => math.Random(level * 7919 + 13);
}

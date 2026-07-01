import 'package:flutter_test/flutter_test.dart';

import 'package:crownofolympus/game/level_config.dart';
import 'package:crownofolympus/game/maze.dart';

void main() {
  test('there are 40 levels with increasing difficulty', () {
    expect(LevelConfig.totalLevels, 40);
    final first = LevelConfig.forLevel(1);
    final last = LevelConfig.forLevel(40);
    expect(first.cols, lessThan(last.cols));
    expect(first.visionRadius, greaterThan(last.visionRadius));
  });

  test('every level generates a solvable maze with a reachable crown & exit',
      () {
    for (var lvl = 1; lvl <= LevelConfig.totalLevels; lvl++) {
      final maze = Maze.generate(LevelConfig.forLevel(lvl));
      expect(maze.isFloor(maze.start.x, maze.start.y), isTrue);
      expect(maze.isFloor(maze.crown.x, maze.crown.y), isTrue);
      expect(maze.isFloor(maze.exit.x, maze.exit.y), isTrue);
      expect(maze.crown == maze.exit, isFalse);
    }
  });
}

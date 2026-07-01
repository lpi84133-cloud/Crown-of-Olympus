import 'dart:collection';
import 'dart:math' as math;

import 'level_config.dart';

/// A grid coordinate (in tile units).
class Coord {
  final int x;
  final int y;
  const Coord(this.x, this.y);

  @override
  bool operator ==(Object other) =>
      other is Coord && other.x == x && other.y == y;

  @override
  int get hashCode => x * 73856093 ^ y * 19349663;

  @override
  String toString() => '($x, $y)';
}

/// A generated maze made of a tile grid where each tile is either a wall or a
/// walkable floor. Passages are carved with a randomized depth-first search
/// (recursive backtracker), which always produces a "perfect" maze (exactly one
/// path between any two floor tiles).
class Maze {
  final int width; // tiles
  final int height; // tiles
  final List<List<bool>> grid; // true = wall

  final Coord start;
  final Coord crown;
  final Coord exit;
  final List<Coord> torches;

  Maze._({
    required this.width,
    required this.height,
    required this.grid,
    required this.start,
    required this.crown,
    required this.exit,
    required this.torches,
  });

  bool isWall(int x, int y) {
    if (x < 0 || y < 0 || x >= width || y >= height) return true;
    return grid[y][x];
  }

  bool isFloor(int x, int y) => !isWall(x, y);

  factory Maze.generate(LevelConfig config) {
    final rng = config.newRandom();
    final int cols = config.cols;
    final int rows = config.rows;

    final int w = cols * 2 + 1;
    final int h = rows * 2 + 1;

    // Start with everything walled.
    final wall = List.generate(h, (_) => List<bool>.filled(w, true));

    Coord cellTile(int cx, int cy) => Coord(cx * 2 + 1, cy * 2 + 1);

    final visited = List.generate(rows, (_) => List<bool>.filled(cols, false));

    // Iterative DFS carving.
    final stack = <Coord>[];
    final startCell = const Coord(0, 0);
    visited[0][0] = true;
    wall[cellTile(0, 0).y][cellTile(0, 0).x] = false;
    stack.add(startCell);

    const dirs = [Coord(0, -1), Coord(1, 0), Coord(0, 1), Coord(-1, 0)];

    while (stack.isNotEmpty) {
      final current = stack.last;
      final neighbors = <Coord>[];
      for (final d in dirs) {
        final nx = current.x + d.x;
        final ny = current.y + d.y;
        if (nx >= 0 &&
            ny >= 0 &&
            nx < cols &&
            ny < rows &&
            !visited[ny][nx]) {
          neighbors.add(Coord(nx, ny));
        }
      }
      if (neighbors.isEmpty) {
        stack.removeLast();
        continue;
      }
      final next = neighbors[rng.nextInt(neighbors.length)];
      visited[next.y][next.x] = true;

      // Carve the wall between current and next.
      final ct = cellTile(current.x, current.y);
      final nt = cellTile(next.x, next.y);
      wall[(ct.y + nt.y) ~/ 2][(ct.x + nt.x) ~/ 2] = false;
      wall[nt.y][nt.x] = false;

      stack.add(next);
    }

    final startTile = cellTile(0, 0);
    final exitTile = cellTile(cols - 1, rows - 1);

    // Place the crown at the floor tile farthest (by path length) from start,
    // so the player has to actually explore. Avoid landing on the exit.
    final crownTile = _farthestFloor(wall, w, h, startTile, avoid: exitTile);

    // Scatter torches on random floor tiles, avoiding key tiles.
    final reserved = {startTile, exitTile, crownTile};
    final floors = <Coord>[];
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        if (!wall[y][x] && !reserved.contains(Coord(x, y))) {
          floors.add(Coord(x, y));
        }
      }
    }
    floors.shuffle(rng);
    final torches = floors.take(config.torches).toList();

    return Maze._(
      width: w,
      height: h,
      grid: wall,
      start: startTile,
      crown: crownTile,
      exit: exitTile,
      torches: torches,
    );
  }

  /// BFS from [from] to find the floor tile with the greatest distance.
  static Coord _farthestFloor(
    List<List<bool>> wall,
    int w,
    int h,
    Coord from, {
    required Coord avoid,
  }) {
    final dist = List.generate(h, (_) => List<int>.filled(w, -1));
    final queue = Queue<Coord>();
    dist[from.y][from.x] = 0;
    queue.add(from);

    Coord best = from;
    int bestD = -1;

    const dirs = [Coord(0, -1), Coord(1, 0), Coord(0, 1), Coord(-1, 0)];
    while (queue.isNotEmpty) {
      final c = queue.removeFirst();
      final d = dist[c.y][c.x];
      if (d > bestD && !(c == avoid) && !(c == from)) {
        bestD = d;
        best = c;
      }
      for (final dir in dirs) {
        final nx = c.x + dir.x;
        final ny = c.y + dir.y;
        if (nx >= 0 &&
            ny >= 0 &&
            nx < w &&
            ny < h &&
            !wall[ny][nx] &&
            dist[ny][nx] == -1) {
          dist[ny][nx] = d + 1;
          queue.add(Coord(nx, ny));
        }
      }
    }
    return best;
  }

  /// Chebyshev distance helper (used for fog/vision).
  static double distance(Coord a, Coord b) {
    final dx = (a.x - b.x).toDouble();
    final dy = (a.y - b.y).toDouble();
    return math.sqrt(dx * dx + dy * dy);
  }
}

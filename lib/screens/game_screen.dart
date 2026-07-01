import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../data/progress.dart';
import '../game/game_images.dart';
import '../game/level_config.dart';
import '../game/maze.dart';
import '../ui/theme.dart';

class GameScreen extends StatefulWidget {
  final int level;
  const GameScreen({super.key, required this.level});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  late LevelConfig _config;
  late Maze _maze;
  GameImages? _images;

  late Coord _player;
  Coord _prev = const Coord(0, 0);
  late AnimationController _moveCtrl;

  // Hero facing (radians). Base sprite faces DOWN, so down = 0.
  double _facing = 0;
  double _prevFacing = 0;

  bool _crownCollected = false;
  final Set<Coord> _collectedTorches = {};
  bool _won = false;
  int _moves = 0;

  String? _hint;
  Timer? _hintTimer;

  // Number of tiles shown horizontally (camera zoom). Fewer = closer.
  static const double _visibleTilesX = 7.0;

  Offset _dragDelta = Offset.zero;

  @override
  void initState() {
    super.initState();
    _moveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 110),
    );
    _loadLevel(widget.level);
    _loadImages();
  }

  Future<void> _loadImages() async {
    final imgs = await GameImages.loadAll();
    if (mounted) setState(() => _images = imgs);
  }

  void _loadLevel(int level) {
    _config = LevelConfig.forLevel(level);
    _maze = Maze.generate(_config);
    _player = _maze.start;
    _prev = _maze.start;
    _crownCollected = false;
    _collectedTorches.clear();
    _won = false;
    _moves = 0;
    _facing = 0;
    _prevFacing = 0;
  }

  /// Target facing angle for a movement direction (base sprite faces down).
  double _angleFor(int dx, int dy) {
    if (dx > 0) return -math.pi / 2; // right
    if (dx < 0) return math.pi / 2; // left
    if (dy < 0) return math.pi; // up
    return 0; // down
  }

  // Each torch gives only a small light bonus, so they help a bit without
  // trivializing the fog.
  double get _currentVision =>
      _config.visionRadius + _collectedTorches.length * 0.22;

  void _tryMove(int dx, int dy) {
    if (_won) return;

    // Rotate the hero toward the pressed direction (even if blocked by a wall),
    // choosing the shortest rotation so turns look natural.
    _prevFacing = _facing;
    double target = _angleFor(dx, dy);
    while (target - _prevFacing > math.pi) {
      target -= 2 * math.pi;
    }
    while (target - _prevFacing < -math.pi) {
      target += 2 * math.pi;
    }
    _facing = target;

    final nx = _player.x + dx;
    final ny = _player.y + dy;
    final blocked = _maze.isWall(nx, ny);

    setState(() {
      _prev = _player;
      if (!blocked) {
        _player = Coord(nx, ny);
        _moves++;
      }
      _moveCtrl.forward(from: 0);
    });

    if (!blocked) _handleTileEffects();
  }

  void _handleTileEffects() {
    // Collect torch.
    if (_maze.torches.contains(_player) &&
        !_collectedTorches.contains(_player)) {
      setState(() => _collectedTorches.add(_player));
    }
    // Collect crown.
    if (_player == _maze.crown && !_crownCollected) {
      setState(() => _crownCollected = true);
      _showFloatingHint('The Crown is yours! Reach the gate.');
    }
    // Reach exit gate.
    if (_player == _maze.exit) {
      if (_crownCollected) {
        _win();
      } else {
        _showFloatingHint('Find the Crown first!');
      }
    }
  }

  void _showFloatingHint(String text) {
    setState(() => _hint = text);
    _hintTimer?.cancel();
    _hintTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _hint = null);
    });
  }

  Future<void> _win() async {
    setState(() => _won = true);
    await Progress.instance.completeLevel(widget.level);
    if (!mounted) return;
    _showWinDialog();
  }

  void _showWinDialog() {
    final hasNext = widget.level < LevelConfig.totalLevels;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: AppTheme.deepBlue,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppTheme.gold, width: 2),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/crown.webp', height: 90),
              const SizedBox(height: 8),
              Text(
                'Level ${widget.level} Complete!',
                style: TextStyle(
                  color: AppTheme.brightGold,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  shadows: AppTheme.titleShadow,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Steps: $_moves   ·   Torches: ${_collectedTorches.length}/${_maze.torches.length}',
                style: const TextStyle(color: AppTheme.marble, fontSize: 13),
              ),
              const SizedBox(height: 20),
              if (hasNext)
                OlympusButton(
                  label: 'Next Level',
                  icon: Icons.arrow_forward_rounded,
                  onTap: () {
                    Navigator.of(ctx).pop();
                    setState(() => _loadLevel(widget.level + 1));
                    // Rebuild with the new level in a fresh screen for clarity.
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => GameScreen(level: widget.level + 1),
                      ),
                    );
                  },
                ),
              const SizedBox(height: 12),
              OlympusButton(
                label: 'Replay',
                icon: Icons.replay_rounded,
                primary: false,
                onTap: () {
                  Navigator.of(ctx).pop();
                  setState(() => _loadLevel(widget.level));
                },
              ),
              const SizedBox(height: 12),
              OlympusButton(
                label: 'Menu',
                icon: Icons.home_rounded,
                primary: false,
                onTap: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onPanEnd() {
    if (_dragDelta.distance < 18) {
      _dragDelta = Offset.zero;
      return;
    }
    if (_dragDelta.dx.abs() > _dragDelta.dy.abs()) {
      _tryMove(_dragDelta.dx > 0 ? 1 : -1, 0);
    } else {
      _tryMove(0, _dragDelta.dy > 0 ? 1 : -1);
    }
    _dragDelta = Offset.zero;
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _moveCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final images = _images;
    return Scaffold(
      backgroundColor: AppTheme.night,
      body: Stack(
        children: [
          // The maze fills the whole screen as a single continuous surface, so
          // there is no seam between the play area and the controls.
          Positioned.fill(
            child: images == null
                ? const Center(
                    child: CircularProgressIndicator(color: AppTheme.gold),
                  )
                : GestureDetector(
                    onPanStart: (_) => _dragDelta = Offset.zero,
                    onPanUpdate: (d) => _dragDelta += d.delta,
                    onPanEnd: (_) => _onPanEnd(),
                    child: AnimatedBuilder(
                      animation: _moveCtrl,
                      builder: (context, _) {
                        return CustomPaint(
                          size: Size.infinite,
                          painter: _MazePainter(
                            maze: _maze,
                            images: images,
                            prev: _prev,
                            player: _player,
                            t: Curves.easeOut.transform(_moveCtrl.value),
                            facing: ui.lerpDouble(
                              _prevFacing,
                              _facing,
                              Curves.easeOut.transform(_moveCtrl.value),
                            )!,
                            vision: _currentVision,
                            crownCollected: _crownCollected,
                            collectedTorches: _collectedTorches,
                            visibleTilesX: _visibleTilesX,
                          ),
                        );
                      },
                    ),
                  ),
          ),
          // UI overlay (top bar + arrow controls) floats on top of the maze.
          SafeArea(
            child: Column(
              children: [
                _topBar(),
                const Spacer(),
                _controls(),
              ],
            ),
          ),
          _buildHint(),
        ],
      ),
    );
  }

  Widget _buildHint() {
    return IgnorePointer(
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: ScaleTransition(
              scale: Tween(begin: 0.9, end: 1.0).animate(anim),
              child: child,
            ),
          ),
          child: _hint == null
              ? const SizedBox.shrink()
              : Container(
                  key: ValueKey(_hint),
                  margin: const EdgeInsets.symmetric(horizontal: 28),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 26, vertical: 18),
                  decoration: BoxDecoration(
                    color: AppTheme.night.withValues(alpha: 0.82),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppTheme.brightGold, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.brightGold.withValues(alpha: 0.35),
                        blurRadius: 18,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Text(
                    _hint!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.brightGold,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      shadows: AppTheme.titleShadow,
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _topBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      color: AppTheme.deepBlue.withValues(alpha: 0.6),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_rounded,
                color: AppTheme.brightGold),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Level ${widget.level}',
                style: const TextStyle(
                  color: AppTheme.brightGold,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                _config.difficultyLabel,
                style: const TextStyle(color: AppTheme.marble, fontSize: 11),
              ),
            ],
          ),
          const Spacer(),
          _statusChip(
            icon: Icons.emoji_events_rounded,
            active: _crownCollected,
            label: _crownCollected ? 'Crown' : 'Seek',
          ),
          const SizedBox(width: 8),
          _statusChip(
            icon: Icons.local_fire_department_rounded,
            active: _collectedTorches.isNotEmpty,
            label: '${_collectedTorches.length}/${_maze.torches.length}',
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: () => setState(() => _loadLevel(widget.level)),
            icon: const Icon(Icons.replay_rounded, color: AppTheme.gold),
          ),
        ],
      ),
    );
  }

  Widget _statusChip({
    required IconData icon,
    required bool active,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: active
              ? AppTheme.brightGold
              : AppTheme.gold.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 16,
              color: active
                  ? AppTheme.brightGold
                  : AppTheme.gold.withValues(alpha: 0.5)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(color: AppTheme.marble, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _controls() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _dirButton(Icons.keyboard_arrow_up_rounded, 0, -1),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _dirButton(Icons.keyboard_arrow_left_rounded, -1, 0),
              const SizedBox(width: 52),
              _dirButton(Icons.keyboard_arrow_right_rounded, 1, 0),
            ],
          ),
          _dirButton(Icons.keyboard_arrow_down_rounded, 0, 1),
        ],
      ),
    );
  }

  Widget _dirButton(IconData icon, int dx, int dy) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _tryMove(dx, dy),
          child: Ink(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF13315C), Color(0xFF0B1E3B)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.gold, width: 2),
            ),
            child: Icon(icon, color: AppTheme.brightGold, size: 32),
          ),
        ),
      ),
    );
  }
}

class _MazePainter extends CustomPainter {
  final Maze maze;
  final GameImages images;
  final Coord prev;
  final Coord player;
  final double t;
  final double facing;
  final double vision;
  final bool crownCollected;
  final Set<Coord> collectedTorches;
  final double visibleTilesX;

  _MazePainter({
    required this.maze,
    required this.images,
    required this.prev,
    required this.player,
    required this.t,
    required this.facing,
    required this.vision,
    required this.crownCollected,
    required this.collectedTorches,
    required this.visibleTilesX,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final tileSize = size.width / visibleTilesX;

    // Smoothly interpolated player center (in tile units).
    final playerU = ui.lerpDouble(prev.x, player.x, t)! + 0.5;
    final playerV = ui.lerpDouble(prev.y, player.y, t)! + 0.5;

    // Camera centers on the player but is clamped so we never scroll past the
    // maze edges (prevents empty space showing "out of bounds"). If the maze is
    // smaller than the viewport on an axis, it is centered instead.
    final halfViewX = size.width / tileSize / 2;
    final halfViewY = size.height / tileSize / 2;
    final camX = maze.width <= halfViewX * 2
        ? maze.width / 2
        : playerU.clamp(halfViewX, maze.width - halfViewX);
    final camY = maze.height <= halfViewY * 2
        ? maze.height / 2
        : playerV.clamp(halfViewY, maze.height - halfViewY);

    Offset tileToScreen(double u, double v) => Offset(
          (u - camX) * tileSize + size.width / 2,
          (v - camY) * tileSize + size.height / 2,
        );

    // Where the hero actually appears on screen given the clamped camera.
    final playerScreen = tileToScreen(playerU, playerV);

    // Background.
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = AppTheme.night,
    );

    // Determine visible tile bounds (with a small margin).
    final marginTilesX = (size.width / tileSize / 2).ceil() + 2;
    final marginTilesY = (size.height / tileSize / 2).ceil() + 2;
    final minX = (camX - marginTilesX).floor();
    final maxX = (camX + marginTilesX).ceil();
    final minY = (camY - marginTilesY).floor();
    final maxY = (camY + marginTilesY).ceil();

    final imgPaint = Paint()..filterQuality = FilterQuality.medium;

    void drawImg(ui.Image img, Rect dst, {double inset = 0}) {
      final d = inset == 0 ? dst : dst.deflate(inset);
      canvas.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        d,
        imgPaint,
      );
    }

    // Floor & walls.
    for (int ty = minY; ty <= maxY; ty++) {
      for (int tx = minX; tx <= maxX; tx++) {
        final topLeft = tileToScreen(tx.toDouble(), ty.toDouble());
        final rect = topLeft & Size(tileSize + 1, tileSize + 1);
        if (tx < 0 || ty < 0 || tx >= maze.width || ty >= maze.height) {
          continue;
        }
        if (maze.isWall(tx, ty)) {
          drawImg(images.wall, rect);
        } else {
          drawImg(images.floor, rect);
        }
      }
    }

    // Exit gate.
    {
      final r = tileToScreen(maze.exit.x.toDouble(), maze.exit.y.toDouble()) &
          Size(tileSize, tileSize);
      if (crownCollected) {
        canvas.drawCircle(
          r.center,
          tileSize * 0.7,
          Paint()
            ..color = AppTheme.brightGold.withValues(alpha: 0.35)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
        );
      }
      drawImg(images.exit, r, inset: tileSize * 0.06);
    }

    // Torches (not yet collected).
    for (final t in maze.torches) {
      if (collectedTorches.contains(t)) continue;
      final r = tileToScreen(t.x.toDouble(), t.y.toDouble()) &
          Size(tileSize, tileSize);
      drawImg(images.torch, r, inset: tileSize * 0.16);
    }

    // Crown (if not collected).
    if (!crownCollected) {
      final r = tileToScreen(maze.crown.x.toDouble(), maze.crown.y.toDouble()) &
          Size(tileSize, tileSize);
      canvas.drawCircle(
        r.center,
        tileSize * 0.55,
        Paint()
          ..color = AppTheme.brightGold.withValues(alpha: 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
      drawImg(images.crown, r, inset: tileSize * 0.12);
    }

    // Hero, rotated toward the facing direction, keeping its aspect ratio.
    canvas.save();
    canvas.translate(playerScreen.dx, playerScreen.dy);
    canvas.rotate(facing);
    final heroAspect = images.hero.width / images.hero.height;
    final heroH = tileSize * 0.98;
    final heroW = heroH * heroAspect;
    final heroDst = Rect.fromCenter(
      center: Offset.zero,
      width: heroW,
      height: heroH,
    );
    canvas.drawImageRect(
      images.hero,
      Rect.fromLTWH(
          0, 0, images.hero.width.toDouble(), images.hero.height.toDouble()),
      heroDst,
      imgPaint,
    );
    canvas.restore();

    // Fog of war: everything beyond the vision radius (around the hero) fades
    // to black.
    final center = playerScreen;
    final radiusPx = vision * tileSize;
    final fogPaint = Paint()
      ..shader = ui.Gradient.radial(
        center,
        radiusPx,
        const [
          Color(0x00000000),
          Color(0x00000000),
          Color(0xF2061223),
          Color(0xFF061223),
        ],
        const [0.0, 0.62, 0.9, 1.0],
        TileMode.clamp,
      );
    canvas.drawRect(Offset.zero & size, fogPaint);

    // Warm torch-light tint near the hero.
    final glowPaint = Paint()
      ..blendMode = BlendMode.plus
      ..shader = ui.Gradient.radial(
        center,
        radiusPx * 0.75,
        const [Color(0x33FFD873), Color(0x00000000)],
        const [0.0, 1.0],
        TileMode.clamp,
      );
    canvas.drawRect(Offset.zero & size, glowPaint);
  }

  @override
  bool shouldRepaint(covariant _MazePainter old) => true;
}

import 'dart:ui' as ui;

import 'package:flutter/services.dart';

/// Decoded [ui.Image] assets used by the maze [CustomPainter].
class GameImages {
  final ui.Image hero;
  final ui.Image wall;
  final ui.Image floor;
  final ui.Image crown;
  final ui.Image exit;
  final ui.Image torch;

  GameImages({
    required this.hero,
    required this.wall,
    required this.floor,
    required this.crown,
    required this.exit,
    required this.torch,
  });

  static Future<ui.Image> _load(String path) async {
    final data = await rootBundle.load(path);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  static Future<GameImages> loadAll() async {
    final results = await Future.wait([
      _load('assets/hero.webp'),
      _load('assets/wall.webp'),
      _load('assets/tail.webp'),
      _load('assets/crown.webp'),
      _load('assets/entrance.webp'),
      _load('assets/torch.webp'),
    ]);
    return GameImages(
      hero: results[0],
      wall: results[1],
      floor: results[2],
      crown: results[3],
      exit: results[4],
      torch: results[5],
    );
  }
}

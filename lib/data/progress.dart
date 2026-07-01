import 'package:shared_preferences/shared_preferences.dart';

import '../game/level_config.dart';

/// Persists how far the player has progressed and simple settings.
class Progress {
  Progress._();
  static final Progress instance = Progress._();

  static const _kUnlocked = 'unlocked_level';
  static const _kSound = 'sound_on';

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Highest unlocked level (at least 1).
  int get unlockedLevel {
    final v = _prefs?.getInt(_kUnlocked) ?? 1;
    return v.clamp(1, LevelConfig.totalLevels);
  }

  bool isUnlocked(int level) => level <= unlockedLevel;

  /// Marks [level] complete and unlocks the next one.
  Future<void> completeLevel(int level) async {
    if (level >= unlockedLevel && level < LevelConfig.totalLevels) {
      await _prefs?.setInt(_kUnlocked, level + 1);
    }
  }

  bool get soundOn => _prefs?.getBool(_kSound) ?? true;

  Future<void> setSound(bool value) async {
    await _prefs?.setBool(_kSound, value);
  }
}

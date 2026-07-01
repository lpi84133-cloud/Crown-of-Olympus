import 'package:flutter/material.dart';

/// Shared colors and helpers for the Greek "marble & gold" look.
class AppTheme {
  static const Color deepBlue = Color(0xFF0B1E3B);
  static const Color night = Color(0xFF061223);
  static const Color gold = Color(0xFFE9C46A);
  static const Color brightGold = Color(0xFFFFD873);
  static const Color marble = Color(0xFFF4ECD8);
  static const Color terracotta = Color(0xFFC1663B);

  static ThemeData build() {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: night,
      colorScheme: ColorScheme.fromSeed(
        seedColor: gold,
        brightness: Brightness.dark,
      ).copyWith(primary: gold, surface: deepBlue),
      fontFamily: 'serif',
    );
  }

  static const LinearGradient goldGradient = LinearGradient(
    colors: [brightGold, gold, terracotta],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static List<Shadow> get titleShadow => const [
        Shadow(color: Colors.black87, blurRadius: 8, offset: Offset(0, 3)),
      ];
}

/// A stylized gold-bordered button used across menus.
class OlympusButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onTap;
  final bool primary;

  const OlympusButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.primary = true,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            gradient: primary
                ? const LinearGradient(
                    colors: [Color(0xFF13315C), Color(0xFF0B1E3B)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  )
                : null,
            color: primary ? null : Colors.black.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.gold, width: 2),
            boxShadow: [
              BoxShadow(
                color: AppTheme.gold.withValues(alpha: 0.25),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, color: AppTheme.brightGold, size: 22),
                const SizedBox(width: 10),
              ],
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.marble,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

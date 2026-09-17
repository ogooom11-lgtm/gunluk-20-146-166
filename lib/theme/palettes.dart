import 'package:flutter/material.dart';

/// لوحة ألوان التطبيق (تُختار من الإعدادات) — هادئة وعصرية.
class AppPalette {
  const AppPalette({
    required this.key,
    required this.seed,
    required this.gradient,
    required this.darkGradient,
    required this.accent,
  });

  final String key;
  final Color seed;

  /// تدرّج للبطاقات في الوضع الفاتح.
  final List<Color> gradient;

  /// تدرّج للبطاقات في الوضع الغامق.
  final List<Color> darkGradient;

  /// لون مميز للإشعارات.
  final Color accent;

  Color get deep => gradient.last;
}

/// كل اللوحات المتاحة.
class Palettes {
  Palettes._();

  static const List<AppPalette> all = <AppPalette>[
    AppPalette(
      key: 'accent.aurora',
      seed: Color(0xFF5B6BF0),
      gradient: <Color>[Color(0xFF6C6CF2), Color(0xFF8E6CF0)],
      darkGradient: <Color>[Color(0xFF3C3F86), Color(0xFF4B3A80)],
      accent: Color(0xFF6C6CF2),
    ),
    AppPalette(
      key: 'accent.ocean',
      seed: Color(0xFF2F6FE0),
      gradient: <Color>[Color(0xFF2F6FE0), Color(0xFF3E9BE0)],
      darkGradient: <Color>[Color(0xFF23426F), Color(0xFF235C7A)],
      accent: Color(0xFF2F6FE0),
    ),
    AppPalette(
      key: 'accent.lagoon',
      seed: Color(0xFF1FA8A0),
      gradient: <Color>[Color(0xFF1FA8A0), Color(0xFF38C5B0)],
      darkGradient: <Color>[Color(0xFF155C5A), Color(0xFF1B6E62)],
      accent: Color(0xFF1FA8A0),
    ),
    AppPalette(
      key: 'accent.meadow',
      seed: Color(0xFF3E9E5B),
      gradient: <Color>[Color(0xFF3E9E5B), Color(0xFF7CC46A)],
      darkGradient: <Color>[Color(0xFF235A38), Color(0xFF3B6B34)],
      accent: Color(0xFF3E9E5B),
    ),
    AppPalette(
      key: 'accent.sunset',
      seed: Color(0xFFE07A2E),
      gradient: <Color>[Color(0xFFE07A2E), Color(0xFFE8A93C)],
      darkGradient: <Color>[Color(0xFF7A4520), Color(0xFF7C5B22)],
      accent: Color(0xFFE07A2E),
    ),
    AppPalette(
      key: 'accent.rose',
      seed: Color(0xFFD6497F),
      gradient: <Color>[Color(0xFFD6497F), Color(0xFFE8799F)],
      darkGradient: <Color>[Color(0xFF6F2743), Color(0xFF7C3C54)],
      accent: Color(0xFFD6497F),
    ),
    AppPalette(
      key: 'accent.sand',
      seed: Color(0xFFB08B3E),
      gradient: <Color>[Color(0xFFB08B3E), Color(0xFFD8B65C)],
      darkGradient: <Color>[Color(0xFF5E4A24), Color(0xFF6E5C2B)],
      accent: Color(0xFFB08B3E),
    ),
    AppPalette(
      key: 'accent.ink',
      seed: Color(0xFF3C4A5E),
      gradient: <Color>[Color(0xFF3C4A5E), Color(0xFF5C6B80)],
      darkGradient: <Color>[Color(0xFF26303D), Color(0xFF35404F)],
      accent: Color(0xFF3C4A5E),
    ),
  ];

  static AppPalette of(int index) {
    if (index < 0 || index >= all.length) return all.first;
    return all[index];
  }
}

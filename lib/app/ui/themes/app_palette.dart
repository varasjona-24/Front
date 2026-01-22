import 'package:flutter/material.dart';

class AppPalette {
  final Color primary;
  final Color secondary;
  final Color accent;
  final Color neutral;

  const AppPalette({
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.neutral,
  });
}

/// Texto ideal encima de un color
Color onColorFor(Color bg) {
  // umbral práctico para UI (más estricto que 0.5)
  return bg.computeLuminance() > 0.45 ? Colors.black : Colors.white;
}

/// Mezcla simple
Color mix(Color a, Color b, double t) => Color.lerp(a, b, t)!;

/// Ajuste de color por HSL (muy útil para dark)
Color tweakHsl(Color c, {double? lightness, double? saturation}) {
  final hsl = HSLColor.fromColor(c);
  return hsl
      .withLightness(lightness ?? hsl.lightness)
      .withSaturation(saturation ?? hsl.saturation)
      .toColor();
}

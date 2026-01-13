import 'package:flutter/material.dart';

import 'app_palette.dart';
import 'app_text_styles.dart';
import 'app_components_theme.dart';

/// 🔧 Helper para mezclar colores (light mode)
Color _blend(Color a, Color b, double t) {
  return Color.fromARGB(
    (a.alpha + (b.alpha - a.alpha) * t).round(),
    (a.red + (b.red - a.red) * t).round(),
    (a.green + (b.green - a.green) * t).round(),
    (a.blue + (b.blue - a.blue) * t).round(),
  );
}

ThemeData buildTheme({
  required AppPalette palette,
  required Brightness brightness,
}) {
  final isDark = brightness == Brightness.dark;

  final surface = isDark
      ? Colors.black
      : _blend(palette.neutral, Colors.white, 0.92);

  final surfaceBar = isDark
      ? const Color(0xFF0B0B0B)
      : _blend(surface, Colors.black, 0.035);

  final onSurface = isDark ? Colors.white : const Color(0xFF111111);

  final colorScheme = ColorScheme(
    brightness: brightness,
    primary: palette.primary,
    secondary: palette.secondary,
    tertiary: palette.accent,
    surface: surface,
    onSurface: onSurface,
    onPrimary: isDark ? Colors.black : Colors.white,
    onSecondary: isDark ? Colors.black : Colors.white,
    error: Colors.redAccent,
    onError: Colors.white,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: surface,

    textTheme: TextTheme(
      titleLarge: AppTextStyles.title.copyWith(color: onSurface),
      titleMedium: AppTextStyles.sectionTitle.copyWith(color: onSurface),
      bodyLarge: AppTextStyles.body.copyWith(color: onSurface),
      bodyMedium: AppTextStyles.body.copyWith(
        color: onSurface.withOpacity(isDark ? 0.86 : 0.78),
      ),
      bodySmall: AppTextStyles.caption.copyWith(
        color: onSurface.withOpacity(isDark ? 0.62 : 0.55),
      ),
    ),

    appBarTheme: AppComponentsTheme.appBarTheme(colorScheme).copyWith(
      backgroundColor: surfaceBar,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),

    iconTheme: AppComponentsTheme.iconTheme(colorScheme),
    dividerTheme: AppComponentsTheme.dividerTheme(colorScheme),
    cardColor: surfaceBar,
  );
}

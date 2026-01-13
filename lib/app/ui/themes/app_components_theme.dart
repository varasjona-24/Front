import 'package:flutter/material.dart';

class AppComponentsTheme {
  static AppBarTheme appBarTheme(ColorScheme scheme) {
    final isDark = scheme.brightness == Brightness.dark;

    return AppBarTheme(
      backgroundColor: isDark
          ? Colors.black
          : scheme.surface.withOpacity(0.96), // 🔥 separa barra del fondo
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      iconTheme: IconThemeData(color: scheme.onSurface, size: 22),
    );
  }

  static IconThemeData iconTheme(ColorScheme scheme) {
    return IconThemeData(color: scheme.onSurface.withOpacity(0.90), size: 22);
  }

  static DividerThemeData dividerTheme(ColorScheme scheme) {
    final isDark = scheme.brightness == Brightness.dark;

    return DividerThemeData(
      color: isDark
          ? Colors.white.withOpacity(0.10)
          : Colors.black.withOpacity(0.08),
      thickness: 1,
      space: 1,
    );
  }
}

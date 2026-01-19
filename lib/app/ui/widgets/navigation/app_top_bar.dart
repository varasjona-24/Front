import 'package:flutter/material.dart';

enum AppMediaMode { audio, video }

class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget title;
  final VoidCallback onSearch;
  final VoidCallback onToggleMode;
  final AppMediaMode mode;

  const AppTopBar({
    super.key,
    required this.title,
    required this.onSearch,
    required this.onToggleMode,
    required this.mode,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final barBg = Color.alphaBlend(
      scheme.primary.withOpacity(isDark ? 0.22 : 0.18),
      scheme.surface,
    );

    return AppBar(
      backgroundColor: barBg,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      // ✅ “highlight” sutil + borde inferior muy leve
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          color: scheme.primary.withOpacity(isDark ? 0.18 : 0.14),
        ),
      ),

      title: title,
      actions: [
        IconButton(icon: const Icon(Icons.search), onPressed: onSearch),
        IconButton(
          icon: Icon(
            Icons.music_note,
            color: mode == AppMediaMode.audio
                ? scheme.primary
                : scheme.onSurface.withOpacity(0.50),
          ),
          onPressed: onToggleMode,
        ),
        IconButton(
          icon: Icon(
            Icons.play_arrow,
            color: mode == AppMediaMode.video
                ? scheme.primary
                : scheme.onSurface.withOpacity(0.50),
          ),
          onPressed: onToggleMode,
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

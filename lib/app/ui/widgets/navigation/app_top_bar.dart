import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../../app/routes/app_routes.dart';

enum AppMediaMode { audio, video }

class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget title;
  final VoidCallback onSearch;
  final Widget? leading;
  final VoidCallback? onToggleMode; // ✅ optional
  final AppMediaMode mode;

  const AppTopBar({
    super.key,
    required this.title,
    required this.onSearch,
    this.leading,
    this.onToggleMode, // ✅ no required
    this.mode = AppMediaMode.audio, // ✅ default
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final barColor = isDark ? const Color(0xFF0B0B0B) : Colors.white;

    return AppBar(
      backgroundColor: barColor,
      surfaceTintColor: barColor,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      leading: leading,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(0),
        child: const SizedBox.shrink(),
      ),
      title: title,
      actions: [
        IconButton(icon: const Icon(Icons.search), onPressed: onSearch),

        if (onToggleMode != null) ...[
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

        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () => Get.toNamed(AppRoutes.settings),
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

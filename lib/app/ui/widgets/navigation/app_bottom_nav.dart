import 'package:flutter/material.dart';

class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final navBg = isDark ? const Color(0xFF0B0B0B) : Colors.white;
    // si tu Flutter no tiene outlineVariant, usa:
    // final divider = scheme.outline.withOpacity(isDark ? 0.35 : 0.45);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: navBg,
      ),
      child: SafeArea(
        top: false,
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: onTap,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          elevation: 0,

          selectedItemColor: scheme.primary,
          unselectedItemColor: scheme.onSurface.withOpacity(
            isDark ? 0.70 : 0.62,
          ),

          selectedFontSize: 11,
          unselectedFontSize: 11,
          selectedLabelStyle: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),

          iconSize: 24,

          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.queue_music_outlined),
              activeIcon: Icon(Icons.queue_music),
              label: 'Playlists',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Artists',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.download_outlined),
              activeIcon: Icon(Icons.download),
              label: 'Imports',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.source_outlined),
              activeIcon: Icon(Icons.source),
              label: 'Sources',
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controller/sources_controller.dart';

import '../domain/source_theme.dart';
import 'source_library_page.dart';

// UI widgets
import '../../../app/ui/widgets/navigation/app_top_bar.dart';
import '../../../app/ui/widgets/navigation/app_bottom_nav.dart';
import '../../../app/ui/themes/app_spacing.dart';
import '../../../app/ui/widgets/branding/listenfy_logo.dart';
import '../../../app/ui/widgets/layout/app_gradient_background.dart';
import 'package:flutter_listenfy/Modules/home/controller/home_controller.dart';

class SourcesPage extends GetView<SourcesController> {
  const SourcesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final barBg = Color.alphaBlend(
      scheme.primary.withOpacity(isDark ? 0.24 : 0.28),
      scheme.surface,
    );

    final HomeController home = Get.find<HomeController>();

    return Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        appBar: AppTopBar(
          title: ListenfyLogo(size: 28, color: scheme.primary),
          onSearch: home.onSearch,
        ),
        body: AppGradientBackground(
          child: Stack(
            children: [
              Positioned.fill(
                child: ScrollConfiguration(
                  behavior: const _NoGlowScrollBehavior(),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(
                      top: AppSpacing.md,
                      bottom: kBottomNavigationBarHeight + 18,
                      left: AppSpacing.md,
                      right: AppSpacing.md,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _header(theme: theme, scheme: scheme, home: home),
                        const SizedBox(height: AppSpacing.lg),

                        ..._themeSections(
                          theme: theme,
                          themes: controller.themes,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              _bottomNav(
                barBg: barBg,
                scheme: scheme,
                isDark: isDark,
                home: home,
              ),
            ],
          ),
        ),
      );
  }

  // ===========================================================================
  // UI SECTIONS
  // ===========================================================================

  Widget _header({
    required ThemeData theme,
    required ColorScheme scheme,
    required HomeController home,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Fuentes',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Explora tu contenido organizado por temáticas.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  List<Widget> _themeSections({
    required ThemeData theme,
    required List<SourceTheme> themes,
  }) {
    return [
      for (final t in themes) ...[
        _ThemeCard(
          theme: t,
          onOpen: () => _openTheme(t),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    ];
  }


  Widget _bottomNav({
    required Color barBg,
    required ColorScheme scheme,
    required bool isDark,
    required HomeController home,
  }) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: barBg,
          border: Border(
            top: BorderSide(
              color: scheme.primary.withOpacity(isDark ? 0.22 : 0.18),
              width: 56,
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: AppBottomNav(
            currentIndex: 4,
            onTap: (index) {
              switch (index) {
                case 0:
                  home.enterHome();
                  break;
                case 1:
                  home.goToPlaylists();
                  break;
                case 2:
                  home.goToArtists();
                  break;
                case 3:
                  home.goToDownloads();
                  break;
                case 4:
                  home.goToSources();
                  break;
              }
            },
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // ACTIONS
  // ===========================================================================


  void _openTheme(SourceTheme theme) {
    final origins = theme.defaultOrigins;
    Get.to(
      () => SourceLibraryPage(
        title: theme.title,
        onlyOffline: theme.onlyOffline,
        origins: origins.isNotEmpty ? origins : null,
        forceKind: theme.forceKind,
        themeId: theme.id,
      ),
    );
  }

}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    required this.theme,
    required this.onOpen,
  });

  final SourceTheme theme;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final textColor = Colors.white;
    final subColor = Colors.white.withOpacity(0.85);

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: theme.colors,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                blurRadius: 12,
                offset: const Offset(0, 6),
                color: Colors.black.withOpacity(0.18),
              ),
            ],
          ),
          child: InkWell(
            onTap: onOpen,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(theme.icon, color: textColor, size: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    theme.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: t.textTheme.titleMedium?.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    theme.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: t.textTheme.bodySmall?.copyWith(
                      color: subColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NoGlowScrollBehavior extends ScrollBehavior {
  const _NoGlowScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}

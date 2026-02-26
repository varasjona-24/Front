import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../home/controller/home_controller.dart';
import '../controller/sources_controller.dart';
import '../domain/source_theme.dart';

import '../../../app/ui/widgets/navigation/app_top_bar.dart';
import '../../../app/ui/widgets/navigation/app_bottom_nav.dart';
import '../../../app/ui/themes/app_spacing.dart';
import '../../../app/ui/widgets/branding/listenfy_logo.dart';
import '../../../app/ui/widgets/layout/app_gradient_background.dart';
import '../../../app/routes/app_routes.dart';

// ============================
// 🧭 PAGE: SOURCES
// ============================
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
      appBar: AppTopBar(title: ListenfyLogo(size: 28, color: scheme.primary)),
      body: AppGradientBackground(
        child: Stack(
          children: [
            Positioned.fill(
              child: RefreshIndicator(
                onRefresh: controller.refreshAll,
                child: ScrollConfiguration(
                  behavior: const _NoGlowScrollBehavior(),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
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
        _ThemeCard(theme: t, onOpen: () => _openTheme(t)),
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
    Get.toNamed(
      AppRoutes.sourceLibrary,
      arguments: {
        'title': theme.title,
        'onlyOffline': theme.onlyOffline,
        'origins': origins.isNotEmpty ? origins : null,
        'forceKind': theme.forceKind,
        'themeId': theme.id,
      },
    );
  }
}

class _ThemeCard extends StatefulWidget {
  const _ThemeCard({required this.theme, required this.onOpen});

  final SourceTheme theme;
  final VoidCallback onOpen;

  @override
  State<_ThemeCard> createState() => _ThemeCardState();
}

class _ThemeCardState extends State<_ThemeCard> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final theme = widget.theme;
    final textColor = Colors.white;
    final subColor = Colors.white.withOpacity(0.85);
    final scale = _isPressed ? 0.96 : (_isHovered ? 1.02 : 1.0);

    return AnimatedScale(
      scale: scale,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.onOpen();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: theme.colors,
                    stops: const [0.1, 0.9],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colors.last.withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Subtle glass overlay
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withOpacity(0.15),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: 20,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                    width: 1.5,
                                  ),
                                ),
                                child: Icon(
                                  theme.icon,
                                  color: textColor,
                                  size: 24,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            theme.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: t.textTheme.titleLarge?.copyWith(
                              color: textColor,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            theme.subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: t.textTheme.bodyMedium?.copyWith(
                              color: subColor,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
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

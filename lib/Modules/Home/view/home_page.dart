import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controller/home_controller.dart';
import '../../../app/ui/widgets/navigation/app_top_bar.dart';
import '../../../app/ui/widgets/navigation/app_bottom_nav.dart';
import '../../../app/ui/widgets/list/media_horizontal_list.dart';
import '../../../app/ui/themes/app_spacing.dart';
import '../../../app/ui/widgets/branding/listenfy_logo.dart';

class HomePage extends GetView<HomeController> {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final mode = controller.mode.value;

      final theme = Theme.of(context);
      final scheme = theme.colorScheme;
      final isDark = theme.brightness == Brightness.dark;

      // ✅ Fondo general con tinte primary (para que no quede “plano/blanco” abajo)
      final bg = Color.alphaBlend(
        scheme.primary.withOpacity(isDark ? 0.02 : 0.06),
        scheme.surface,
      );

      // ✅ Fondo de barra (un poco más marcado)
      final barBg = Color.alphaBlend(
        scheme.primary.withOpacity(isDark ? 0.24 : 0.28),
        scheme.surface,
      );

      return Scaffold(
        backgroundColor: bg,
        extendBody: true, // 🔥 CLAVE: permite pintar debajo del nav

        appBar: AppTopBar(
          title: ListenfyLogo(size: 28, color: scheme.primary),
          mode: mode == HomeMode.audio
              ? AppMediaMode.audio
              : AppMediaMode.video,
          onSearch: controller.onSearch,
          onToggleMode: controller.toggleMode,
        ),

        // ✅ Body con Stack para controlar nav + safe area inferior
        body: Stack(
          children: [
            // CONTENIDO
            Positioned.fill(
              child: controller.isLoading.value
                  ? const Center(child: CircularProgressIndicator())
                  : ScrollConfiguration(
                      behavior: const _NoGlowScrollBehavior(),
                      child: SingleChildScrollView(
                        padding: EdgeInsets.only(
                          top: AppSpacing.md,
                          // ✅ Deja espacio para que el contenido no quede bajo la barra
                          bottom: kBottomNavigationBarHeight + 18,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (controller.recentlyPlayed.isNotEmpty)
                              MediaHorizontalList(
                                title: 'Mis escuchados',
                                items: controller.recentlyPlayed,
                                onItemTap: (item, index) =>
                                    controller.openMedia(
                                      item,
                                      index,
                                      controller.recentlyPlayed,
                                    ),
                              ),

                            if (controller.latestDownloads.isNotEmpty) ...[
                              const SizedBox(height: AppSpacing.lg),
                              MediaHorizontalList(
                                title: 'Últimas descargas',
                                items: controller.latestDownloads,
                                onItemTap: (item, index) =>
                                    controller.openMedia(
                                      item,
                                      index,
                                      controller.latestDownloads,
                                    ),
                              ),
                            ],

                            if (controller.favorites.isNotEmpty) ...[
                              const SizedBox(height: AppSpacing.lg),
                              MediaHorizontalList(
                                title: 'Favoritos',
                                items: controller.favorites,
                                onItemTap: (item, index) =>
                                    controller.openMedia(
                                      item,
                                      index,
                                      controller.favorites,
                                    ),
                              ),
                            ],

                            const SizedBox(height: 28),
                          ],
                        ),
                      ),
                    ),
            ),

            // ✅ NAV + SAFE AREA pintado (esto es lo que iOS necesita)
            Positioned(
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
                  top: false, // ✅ SOLO safe area inferior
                  child: AppBottomNav(
                    currentIndex: 0,
                    onTap: (index) {
                      switch (index) {
                        case 1:
                          controller.goToPlaylists();
                          break;
                        case 2:
                          controller.goToArtists();
                          break;
                        case 3:
                          controller.goToDownloads();
                          break;
                        case 4:
                          controller.goToSources();
                          break;
                        case 5:
                          controller.goToSettings();
                          break;
                      }
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });
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

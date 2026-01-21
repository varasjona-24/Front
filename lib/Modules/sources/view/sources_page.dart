import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controller/sources_controller.dart';
import '../../../app/models/media_item.dart';
import '../../player/audio/view/audio_player_page.dart';

import '../domain/source_origin.dart';
import '../domain/source_pill_data.dart';
import '../ui/source_pill_tile.dart';
import 'source_library_page.dart';

// UI widgets
import '../../../app/ui/widgets/navigation/app_top_bar.dart';
import '../../../app/ui/widgets/navigation/app_bottom_nav.dart';
import '../../../app/ui/themes/app_spacing.dart';
import '../../../app/ui/widgets/branding/listenfy_logo.dart';
import 'package:flutter_listenfy/Modules/home/controller/home_controller.dart';

class SourcesPage extends GetView<SourcesController> {
  const SourcesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final bg = Color.alphaBlend(
      scheme.primary.withOpacity(isDark ? 0.02 : 0.06),
      scheme.surface,
    );

    final barBg = Color.alphaBlend(
      scheme.primary.withOpacity(isDark ? 0.24 : 0.28),
      scheme.surface,
    );

    final HomeController home = Get.find<HomeController>();
    final pills = _buildPills(controller);

    return Obx(() {
      final mode = home.mode.value;

      return Scaffold(
        backgroundColor: bg,
        extendBody: true,
        appBar: AppTopBar(
          title: ListenfyLogo(size: 28, color: scheme.primary),
          onSearch: home.onSearch,
        ),
        body: Stack(
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

                      _pillsSection(pills),
                      const SizedBox(height: AppSpacing.lg),

                      _selectedSectionTitle(theme),
                      const SizedBox(height: AppSpacing.sm),

                      _selectedSectionList(theme),
                      const SizedBox(height: AppSpacing.lg),
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
      );
    });
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
          'Explora tu contenido organizado por origen.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _pillsSection(List<SourcePillData> pills) {
    return Column(
      children: pills
          .map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SourcePillTile(data: p),
            ),
          )
          .toList(),
    );
  }

  Widget _selectedSectionTitle(ThemeData theme) {
    return Text(
      'Seleccionados (Dispositivo)',
      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
    );
  }

  Widget _selectedSectionList(ThemeData theme) {
    return Obx(() {
      final list = controller.localFiles;

      if (list.isEmpty) {
        return Text(
          'No hay archivos seleccionados.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        );
      }

      return Column(
        children: List.generate(
          list.length,
          (i) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _selectedItemTile(
              theme: theme,
              item: list[i],
              index: i,
              list: list,
            ),
          ),
        ),
      );
    });
  }

  Widget _selectedItemTile({
    required ThemeData theme,
    required MediaItem item,
    required int index,
    required List<MediaItem> list,
  }) {
    final variant = item.variants.first;
    final isVideo = variant.kind == MediaVariantKind.video;

    // Solo para display (no dependas de esto para reproducir)
    final displaySubtitle = _displayLocalSubtitle(item);

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: Icon(
          isVideo ? Icons.videocam_rounded : Icons.music_note_rounded,
        ),
        title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          displaySubtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Wrap(
          spacing: 6,
          children: [
            IconButton(
              icon: const Icon(Icons.save_alt_rounded),
              tooltip: 'Importar a la app (offline)',
              onPressed: () => _onImportPressed(item),
            ),
            IconButton(
              icon: const Icon(Icons.play_arrow_rounded),
              tooltip: 'Reproducir',
              onPressed: () => _onPlayPressed(list: list, index: index),
            ),
          ],
        ),
      ),
    );
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

  Future<void> _onImportPressed(MediaItem item) async {
    final imported = await controller.importToAppStorage(item);

    if (imported == null) {
      Get.snackbar(
        'Import',
        'Falló la importación',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(12),
      );
      return;
    }

    final idx = controller.localFiles.indexWhere((e) => e.id == item.id);
    if (idx != -1) controller.localFiles[idx] = imported;

    Get.snackbar(
      'Import',
      'Guardado en Biblioteca offline ✅',
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(12),
    );
  }

  void _onPlayPressed({required List<MediaItem> list, required int index}) {
    final item = list[index];

    // ✅ AQUÍ está el fix de “link/url”: usar playableUrl (file:///... si es local)
    final playableUrl = item.playableUrl;

    Get.to(
      () => const AudioPlayerPage(),
      arguments: {
        'queue': list,
        'index': index,
        // Si tu player no usa esto, no pasa nada.
        // Pero si lo soportas, ya queda listo.
        'playableUrl': playableUrl,
      },
    );
  }

  String _displayLocalSubtitle(MediaItem item) {
    final v = item.variants.first;

    // Preferimos mostrar el nombre del archivo si existe.
    final name = v.fileName.trim();
    if (name.isNotEmpty) return name;

    // Si no, mostramos el final del path.
    final lp = v.localPath?.trim() ?? '';
    if (lp.isEmpty) return '';

    // recorta para que no se vea todo el path
    final parts = lp.split(RegExp(r'[\\/]+'));
    if (parts.isEmpty) return lp;
    return parts.last;
  }

  // ===========================================================================
  // PILLS
  // ===========================================================================

  List<SourcePillData> _buildPills(SourcesController controller) {
    SourcePillData pill({
      required SourceOrigin origin,
      required String title,
      required String subtitle,
      required IconData icon,
      required List<Color> colors,
      required VoidCallback onTap,
      bool forceDarkText = false,
    }) {
      return SourcePillData(
        origin: origin,
        title: title,
        subtitle: subtitle,
        icon: icon,
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: colors,
        ),
        onTap: onTap,
        forceDarkText: forceDarkText,
      );
    }

    VoidCallback openOrigin(SourceOrigin origin, String title) {
      return () => Get.to(
        () =>
            SourceLibraryPage(title: title, origin: origin, onlyOffline: false),
      );
    }

    return [
      pill(
        origin: SourceOrigin.device,
        title: 'Dispositivo local',
        subtitle: 'Selecciona música o videos del teléfono',
        icon: Icons.folder_open_rounded,
        colors: const [Color(0xFF00C6FF), Color(0xFF0072FF)],
        onTap: () async => controller.pickLocalFiles(),
      ),

      pill(
        origin: SourceOrigin.generic,
        title: 'Biblioteca offline',
        subtitle: 'Todo lo guardado dentro de la app',
        icon: Icons.offline_pin_rounded,
        colors: const [Color(0xFF00C853), Color(0xFF7CFFB2)],
        onTap: () => Get.to(
          () => const SourceLibraryPage(
            title: 'Biblioteca offline',
            onlyOffline: true,
          ),
        ),
      ),

      pill(
        origin: SourceOrigin.youtube,
        title: 'YouTube',
        subtitle: 'youtube.com / youtu.be',
        icon: Icons.play_circle_fill_rounded,
        colors: const [Color(0xFFFF0000), Color(0xFFFF6A6A)],
        onTap: openOrigin(SourceOrigin.youtube, 'YouTube'),
      ),
      pill(
        origin: SourceOrigin.instagram,
        title: 'Instagram',
        subtitle: 'instagram.com',
        icon: Icons.camera_alt_rounded,
        colors: const [Color(0xFFF58529), Color(0xFFDD2A7B), Color(0xFF8134AF)],
        onTap: openOrigin(SourceOrigin.instagram, 'Instagram'),
      ),
      pill(
        origin: SourceOrigin.vimeo,
        title: 'Vimeo',
        subtitle: 'vimeo.com',
        icon: Icons.video_library_rounded,
        colors: const [Color(0xFF1AB7EA), Color(0xFF6ED6F3)],
        onTap: openOrigin(SourceOrigin.vimeo, 'Vimeo'),
      ),
      pill(
        origin: SourceOrigin.reddit,
        title: 'Reddit',
        subtitle: 'reddit.com',
        icon: Icons.forum_rounded,
        colors: const [Color(0xFFFF4500), Color(0xFFFF7A45)],
        onTap: openOrigin(SourceOrigin.reddit, 'Reddit'),
      ),
      pill(
        origin: SourceOrigin.telegram,
        title: 'Telegram',
        subtitle: 't.me',
        icon: Icons.send_rounded,
        colors: const [Color(0xFF0088CC), Color(0xFF58C7FF)],
        onTap: openOrigin(SourceOrigin.telegram, 'Telegram'),
      ),
      pill(
        origin: SourceOrigin.x,
        title: 'X',
        subtitle: 'x.com / twitter.com',
        icon: Icons.close_rounded,
        colors: const [Color(0xFF111111), Color(0xFF505050)],
        onTap: openOrigin(SourceOrigin.x, 'X'),
      ),
      pill(
        origin: SourceOrigin.facebook,
        title: 'Facebook',
        subtitle: 'facebook.com / fb.watch',
        icon: Icons.facebook_rounded,
        colors: const [Color(0xFF1877F2), Color(0xFF5AA7FF)],
        onTap: openOrigin(SourceOrigin.facebook, 'Facebook'),
      ),
      pill(
        origin: SourceOrigin.pinterest,
        title: 'Pinterest',
        subtitle: 'pinterest.*',
        icon: Icons.push_pin_rounded,
        colors: const [Color(0xFFBD081C), Color(0xFFFF5A6A)],
        onTap: openOrigin(SourceOrigin.pinterest, 'Pinterest'),
      ),
      pill(
        origin: SourceOrigin.amino,
        title: 'Amino',
        subtitle: 'aminoapps.com',
        icon: Icons.groups_rounded,
        colors: const [Color(0xFF00C853), Color(0xFF7CFFB2)],
        onTap: openOrigin(SourceOrigin.amino, 'Amino'),
      ),
      pill(
        origin: SourceOrigin.blogger,
        title: 'Blogger',
        subtitle: 'blogspot.* / blogger.com',
        icon: Icons.article_rounded,
        colors: const [Color(0xFFFF9800), Color(0xFFFFD180)],
        onTap: openOrigin(SourceOrigin.blogger, 'Blogger'),
      ),
      pill(
        origin: SourceOrigin.twitch,
        title: 'Twitch',
        subtitle: 'twitch.tv',
        icon: Icons.sports_esports_rounded,
        colors: const [Color(0xFF6441A5), Color(0xFF9146FF)],
        onTap: openOrigin(SourceOrigin.twitch, 'Twitch'),
      ),
      pill(
        origin: SourceOrigin.kick,
        title: 'Kick',
        subtitle: 'kick.com',
        icon: Icons.bolt_rounded,
        colors: const [Color(0xFF00E676), Color(0xFF1DE9B6)],
        onTap: openOrigin(SourceOrigin.kick, 'Kick'),
      ),
      pill(
        origin: SourceOrigin.snapchat,
        title: 'Snapchat',
        subtitle: 'snapchat.com',
        icon: Icons.chat_bubble_rounded,
        colors: const [Color(0xFFFFEB3B), Color(0xFFFFF59D)],
        onTap: openOrigin(SourceOrigin.snapchat, 'Snapchat'),
        forceDarkText: true,
      ),
      pill(
        origin: SourceOrigin.qq,
        title: 'QQ',
        subtitle: 'qq.com',
        icon: Icons.language_rounded,
        colors: const [Color(0xFF1976D2), Color(0xFF64B5F6)],
        onTap: openOrigin(SourceOrigin.qq, 'QQ'),
      ),
      pill(
        origin: SourceOrigin.threads,
        title: 'Threads',
        subtitle: 'threads.net',
        icon: Icons.alternate_email_rounded,
        colors: const [Color(0xFF000000), Color(0xFF6B6B6B)],
        onTap: openOrigin(SourceOrigin.threads, 'Threads'),
      ),
      pill(
        origin: SourceOrigin.vk,
        title: 'VK',
        subtitle: 'vk.com',
        icon: Icons.people_alt_rounded,
        colors: const [Color(0xFF4C75A3), Color(0xFF86A9D6)],
        onTap: openOrigin(SourceOrigin.vk, 'VK'),
      ),
      pill(
        origin: SourceOrigin.chan4,
        title: '4chan',
        subtitle: '4chan.org',
        icon: Icons.warning_amber_rounded,
        colors: const [Color(0xFF2E7D32), Color(0xFF81C784)],
        onTap: openOrigin(SourceOrigin.chan4, '4chan'),
      ),
      pill(
        origin: SourceOrigin.mega,
        title: 'Mega',
        subtitle: 'mega.nz',
        icon: Icons.cloud_rounded,
        colors: const [Color(0xFFE53935), Color(0xFFFF8A80)],
        onTap: openOrigin(SourceOrigin.mega, 'Mega'),
      ),
      pill(
        origin: SourceOrigin.generic,
        title: 'Genérico',
        subtitle: 'Cualquier URL soportada',
        icon: Icons.link_rounded,
        colors: const [Color(0xFF616161), Color(0xFF9E9E9E)],
        onTap: openOrigin(SourceOrigin.generic, 'Genérico'),
      ),
    ];
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

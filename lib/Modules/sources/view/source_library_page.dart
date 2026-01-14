import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/data/repo/media_repository.dart';
import '../../../app/models/media_item.dart';
import '../../player/audio/view/audio_player_page.dart';
import '../domain/source_origin.dart';

// UI
import '../../../app/ui/widgets/navigation/app_top_bar.dart';
import '../../../app/ui/widgets/navigation/app_bottom_nav.dart';
import 'package:flutter_listenfy/Modules/home/controller/home_controller.dart';

class SourceLibraryPage extends StatefulWidget {
  const SourceLibraryPage({
    super.key,
    this.origin,
    this.onlyOffline = false,
    required this.title,
  });

  final SourceOrigin? origin;
  final bool onlyOffline;
  final String title;

  @override
  State<SourceLibraryPage> createState() => _SourceLibraryPageState();
}

class _SourceLibraryPageState extends State<SourceLibraryPage> {
  final MediaRepository _repo = Get.find<MediaRepository>();

  Future<List<MediaItem>> _load([HomeMode? mode]) async {
    final all = await _repo.getLibrary();
    Iterable<MediaItem> items = all;

    if (widget.onlyOffline) {
      items = items.where((e) => e.isOfflineStored);
    }

    if (widget.origin != null) {
      items = items.where((e) => e.origin == widget.origin);
    }

    // Filtrado por modo (audio/video) si se provee
    if (mode != null) {
      final isAudio = mode == HomeMode.audio;
      items = items.where((e) => isAudio ? e.hasAudio : e.hasVideo);
    }

    // opcional: ordenar por createdAt del primer variant (nuevo primero)
    final list = items.toList();
    list.sort(
      (a, b) =>
          (b.variants.first.createdAt).compareTo(a.variants.first.createdAt),
    );
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final HomeController home = Get.find<HomeController>();

    final bg = Color.alphaBlend(
      scheme.primary.withOpacity(isDark ? 0.02 : 0.06),
      scheme.surface,
    );

    final barBg = Color.alphaBlend(
      scheme.primary.withOpacity(isDark ? 0.24 : 0.28),
      scheme.surface,
    );

    return Obx(() {
      final mode = home.mode.value;

      return Scaffold(
        backgroundColor: bg,
        extendBody: true,
        appBar: AppTopBar(
          title: Text(widget.title),
          onSearch: home.onSearch,
          onToggleMode: home.toggleMode,
          mode: mode == HomeMode.audio
              ? AppMediaMode.audio
              : AppMediaMode.video,
        ),
        body: Stack(
          children: [
            Positioned.fill(
              child: FutureBuilder<List<MediaItem>>(
                future: _load(mode),
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final list = snap.data ?? const <MediaItem>[];

                  // separar audio / video
                  final audio = list.where((e) => e.hasAudio).toList();
                  final video = list.where((e) => e.hasVideo).toList();

                  if (audio.isEmpty && video.isEmpty) {
                    return Center(
                      child: Text(
                        'No hay contenido aquí todavía.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  }

                  return ScrollConfiguration(
                    behavior: const _NoGlowScrollBehavior(),
                    child: SingleChildScrollView(
                      padding: EdgeInsets.only(
                        top: 12,
                        bottom: kBottomNavigationBarHeight + 18,
                        left: 12,
                        right: 12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (audio.isNotEmpty) ...[
                            Text(
                              'Audio',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...audio.map((item) => _itemTile(item, list)),
                            const SizedBox(height: 18),
                          ],

                          if (video.isNotEmpty) ...[
                            Text(
                              'Videos',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...video.map((item) => _itemTile(item, list)),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // NAV
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
                  top: false,
                  child: AppBottomNav(
                    currentIndex: 4,
                    onTap: (index) {
                      final HomeController home = Get.find<HomeController>();
                      switch (index) {
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
                        case 5:
                          home.goToSettings();
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

  Widget _itemTile(MediaItem item, List<MediaItem> queue) {
    final v = item.audioVariant ?? item.variants.first;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(
          v.kind == MediaVariantKind.video
              ? Icons.videocam_rounded
              : Icons.music_note_rounded,
        ),
        title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          item.subtitle.isNotEmpty ? item.subtitle : item.origin.key,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Wrap(
          spacing: 6,
          children: [
            IconButton(
              icon: const Icon(Icons.play_arrow_rounded),
              onPressed: () {
                final idx = queue.indexWhere((e) => e.id == item.id);
                Get.to(
                  () => const AudioPlayerPage(),
                  arguments: {'queue': queue, 'index': idx == -1 ? 0 : idx},
                );
              },
            ),

            IconButton(
              icon: const Icon(Icons.cloud_download_rounded),
              tooltip: 'Descargar',
              onPressed: () async {
                final hasAudio = item.hasAudio;
                final hasVideo = item.hasVideo;

                final options = <String>[];
                if (hasAudio) options.addAll(['mp3', 'm4a']);
                if (hasVideo) options.addAll(['mp4']);

                if (options.isEmpty) {
                  Get.snackbar(
                    'Download',
                    'No hay formatos disponibles para descargar',
                    snackPosition: SnackPosition.BOTTOM,
                  );
                  return;
                }

                final choice = await showModalBottomSheet<String>(
                  context: Get.context!,
                  builder: (ctx) {
                    return SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final fmt in options)
                            ListTile(
                              leading: const Icon(Icons.file_download_outlined),
                              title: Text(fmt.toUpperCase()),
                              onTap: () => Navigator.of(ctx).pop(fmt),
                            ),
                          ListTile(
                            leading: const Icon(Icons.close),
                            title: const Text('Cancelar'),
                            onTap: () => Navigator.of(ctx).pop(),
                          ),
                        ],
                      ),
                    );
                  },
                );

                if (choice == null) return;

                final kind = hasAudio && ['mp3', 'm4a'].contains(choice)
                    ? 'audio'
                    : 'video';
                final mediaId = item.publicId.isNotEmpty
                    ? item.publicId
                    : item.id;

                // feedback: muestra diálogo de progreso
                showDialog(
                  context: Get.context!,
                  barrierDismissible: false,
                  builder: (_) =>
                      const Center(child: CircularProgressIndicator()),
                );

                final ok = await _repo.requestAndFetchMedia(
                  mediaId: mediaId,
                  url: null,
                  kind: kind,
                  format: choice,
                );

                // dismiss progress dialog
                if (Get.isDialogOpen ?? false) Navigator.of(Get.context!).pop();

                if (ok) {
                  Get.snackbar(
                    'Download',
                    'Descarga guardada en downloads ✅',
                    snackPosition: SnackPosition.BOTTOM,
                  );
                } else {
                  Get.snackbar(
                    'Download',
                    'Falló la descarga',
                    snackPosition: SnackPosition.BOTTOM,
                  );
                }
              },
            ),
          ],
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

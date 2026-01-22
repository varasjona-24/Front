import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/data/repo/media_repository.dart';
import '../../../app/models/media_item.dart';
import '../../player/audio/view/audio_player_page.dart';
import '../domain/source_origin.dart';
import '../../settings/controller/settings_controller.dart';

// UI
import '../../../app/ui/widgets/navigation/app_top_bar.dart';
import '../../../app/ui/widgets/navigation/app_bottom_nav.dart';
import '../../../app/ui/widgets/layout/app_gradient_background.dart';
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
  final SettingsController _settings = Get.find<SettingsController>();

  Future<List<MediaItem>> _load([HomeMode? mode]) async {
    final all = await _repo.getLibrary();
    Iterable<MediaItem> items = all;

    if (widget.onlyOffline) {
      items = items.where((e) => e.isOfflineStored);
    }

    if (widget.origin != null) {
      items = items.where((e) => e.origin == widget.origin);
    }

    // ✅ FIX: Filtrado por modo (audio/video) por KIND, no por "local"
    if (mode != null) {
      final isAudio = mode == HomeMode.audio;
      items = items.where(
        (e) => isAudio
            ? e.variants.any((v) => v.kind == MediaVariantKind.audio)
            : e.variants.any((v) => v.kind == MediaVariantKind.video),
      );
    }

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

    final barBg = Color.alphaBlend(
      scheme.primary.withOpacity(isDark ? 0.24 : 0.28),
      scheme.surface,
    );

    return Obx(() {
      final mode = home.mode.value;

      return Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        appBar: AppTopBar(
          title: Text(widget.title),
          onSearch: home.onSearch,
          onToggleMode: home.toggleMode,
          mode: mode == HomeMode.audio
              ? AppMediaMode.audio
              : AppMediaMode.video,
        ),
        body: AppGradientBackground(
          child: Stack(
            children: [
              Positioned.fill(
                child: FutureBuilder<List<MediaItem>>(
                  future: _load(mode),
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final list = snap.data ?? const <MediaItem>[];

                    final hasAudio = (MediaItem e) => e.variants.any(
                          (v) => v.kind == MediaVariantKind.audio,
                        );
                    final hasVideo = (MediaItem e) => e.variants.any(
                          (v) => v.kind == MediaVariantKind.video,
                        );

                    final modeList = mode == HomeMode.audio
                        ? list.where(hasAudio).toList()
                        : list.where(hasVideo).toList();

                    if (modeList.isEmpty) {
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
                            ...modeList.map((item) => _itemTile(item, modeList)),
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
                        }
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _itemTile(MediaItem item, List<MediaItem> queue) {
    final v =
        item.localAudioVariant ?? item.localVideoVariant ?? item.variants.first;

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
                final safeIdx = idx == -1 ? 0 : idx;

                Get.to(
                  () => const AudioPlayerPage(),
                  arguments: {
                    'queue': queue,
                    'index': safeIdx,
                    'playableUrl': item.playableUrl, // ✅ FIX LINK
                  },
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.cloud_download_rounded),
              tooltip: 'Descargar',
              onPressed: () async {
                final hasAudio = item.variants.any(
                  (v) => v.kind == MediaVariantKind.audio,
                );
                final hasVideo = item.variants.any(
                  (v) => v.kind == MediaVariantKind.video,
                );

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

                Get.dialog(
                  const Center(child: CircularProgressIndicator()),
                  barrierDismissible: false,
                );

                final ok = await _repo.requestAndFetchMedia(
                  mediaId: mediaId,
                  url: null,
                  kind: kind,
                  format: choice,
                  quality: _settings.downloadQuality.value,
                );

                if (Get.isDialogOpen ?? false) Get.back();

                if (ok) {
                  Get.snackbar(
                    'Download',
                    'Descarga guardada en downloads ✅',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: Colors.green,
                  );
                } else {
                  Get.snackbar(
                    'Download',
                    'Falló la descarga',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: Colors.orange,
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

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:file_picker/file_picker.dart';

import '../../../app/models/media_item.dart';
import '../../../app/ui/widgets/navigation/app_top_bar.dart';
import '../../../app/ui/widgets/navigation/app_bottom_nav.dart';
import '../../../app/ui/widgets/layout/app_gradient_background.dart';
import '../../home/controller/home_controller.dart';
import '../../player/audio/view/audio_player_page.dart';
import '../../settings/controller/settings_controller.dart';
import '../controller/sources_controller.dart';
import '../domain/source_origin.dart';
import '../domain/source_theme.dart';
import '../domain/source_theme_topic.dart';
import '../ui/source_color_picker_field.dart';
import 'source_theme_topic_page.dart';

// ============================
// 🧭 PAGE: SOURCE LIBRARY
// ============================
class SourceLibraryPage extends StatefulWidget {
  const SourceLibraryPage({
    super.key,
    this.origin,
    this.origins,
    this.onlyOffline = false,
    this.forceKind,
    this.themeId,
    required this.title,
  });

  final SourceOrigin? origin;
  final List<SourceOrigin>? origins;
  final bool onlyOffline;
  final MediaVariantKind? forceKind;
  final String? themeId;
  final String title;

  @override
  State<SourceLibraryPage> createState() => _SourceLibraryPageState();
}

class _SourceLibraryPageState extends State<SourceLibraryPage> {
  final SettingsController _settings = Get.find<SettingsController>();
  final SourcesController _sources = Get.find<SourcesController>();

  // ============================
  // 📚 DATA
  // ============================
  Future<List<MediaItem>> _load([HomeMode? mode]) async {
    final modeKind = mode == null
        ? null
        : (mode == HomeMode.audio
            ? MediaVariantKind.audio
            : MediaVariantKind.video);

    return _sources.loadLibraryItems(
      onlyOffline: widget.onlyOffline,
      origin: widget.origin,
      origins: widget.origins,
      forceKind: widget.forceKind,
      modeKind: modeKind,
    );
  }

  // ============================
  // 🧱 UI
  // ============================
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final HomeController home = Get.find<HomeController>();
    SourceTheme? themeMeta;
    if (widget.themeId != null) {
      for (final t in _sources.themes) {
        if (t.id == widget.themeId) {
          themeMeta = t;
          break;
        }
      }
    }

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
                    onToggleMode: widget.forceKind == null ? home.toggleMode : null,
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
                            if (themeMeta != null &&
                                themeMeta.onlyOffline != true) ...[
                              _topicHeader(themeMeta),
                              const SizedBox(height: 8),
                              _topicList(themeMeta),
                              const SizedBox(height: 18),
                            ],
                            if (modeList.isEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Text(
                                  'No hay contenido aquí todavía.',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              )
                            else
                              ...modeList.map(
                                (item) => _itemTile(item, modeList),
                              ),
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

                final ok = await _sources.requestAndFetchMedia(
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

  Widget _topicHeader(SourceTheme themeMeta) {
    final limitReached = _sources.topicsForTheme(themeMeta.id).length >= 10;
    return Row(
      children: [
        Text(
          'Temáticas',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.add_rounded),
          onPressed: () {
            if (limitReached) {
              Get.snackbar(
                'Temáticas',
                'Límite de 10 temáticas alcanzado',
                snackPosition: SnackPosition.BOTTOM,
              );
              return;
            }
            _openCreateTopic(themeMeta);
          },
        ),
      ],
    );
  }

  Widget _topicList(SourceTheme themeMeta) {
    return Obx(() {
      final topics = _sources.topicsForTheme(themeMeta.id);
      if (topics.isEmpty) {
        return Text(
          'Crea una temática para agrupar contenidos.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        );
      }

      return Column(
        children: [
          for (final topic in topics)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _TopicCard(
                themeMeta: themeMeta,
                topic: topic,
                listCount: _sources.playlistsForTopic(topic.id).length,
                onOpen: () => Get.to(
                  () => SourceThemeTopicPage(
                    topicId: topic.id,
                    theme: themeMeta,
                    origins: widget.origins,
                  ),
                ),
                onEdit: () => _openEditTopic(themeMeta, topic),
                onDelete: () => _confirmDeleteTopic(topic),
              ),
            ),
        ],
      );
    });
  }

  Widget _topicThumb(SourceThemeTopic topic) {
    final scheme = Theme.of(context).colorScheme;
    final path = topic.coverLocalPath?.trim();
    final url = topic.coverUrl?.trim();
    ImageProvider? provider;
    if (path != null && path.isNotEmpty) {
      provider = FileImage(File(path));
    } else if (url != null && url.isNotEmpty) {
      provider = NetworkImage(url);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 48,
        height: 48,
        color: scheme.surfaceContainerHighest,
        child: provider != null
            ? Image(image: provider, fit: BoxFit.cover)
            : Icon(Icons.folder_rounded, color: scheme.onSurfaceVariant),
      ),
    );
  }

  // ============================
  // 🪄 DIALOGOS
  // ============================
  Future<void> _openCreateTopic(SourceTheme themeMeta) async {
    String name = '';
    String? coverUrl;
    String? coverLocal;
    int? colorValue;
    Color draftColor = Theme.of(context).colorScheme.primary;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Nueva temática (${themeMeta.title})'),
          content: StatefulBuilder(
            builder: (ctx2, setState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      onChanged: (v) => name = v,
                      decoration: const InputDecoration(
                        hintText: 'Nombre',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      onChanged: (v) => coverUrl = v,
                      decoration: const InputDecoration(
                        hintText: 'URL de imagen (opcional)',
                      ),
                    ),
                    const SizedBox(height: 10),
                    SourceColorPickerField(
                      color:
                          colorValue != null ? Color(colorValue!) : draftColor,
                      onChanged: (c) => setState(() {
                        draftColor = c;
                        colorValue = c.value;
                      }),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final res = await FilePicker.platform.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: const [
                            'jpg',
                            'jpeg',
                            'png',
                            'webp',
                          ],
                        );
                        final file = (res != null && res.files.isNotEmpty)
                            ? res.files.first
                            : null;
                        if (file?.path != null) {
                          coverLocal = file!.path!;
                        }
                      },
                      icon: const Icon(Icons.folder_open_rounded),
                      label: const Text('Elegir imagen'),
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await _sources.addTopic(
                  themeId: themeMeta.id,
                  title: name,
                  coverUrl: coverUrl,
                  coverLocalPath: coverLocal,
                  colorValue: colorValue,
                );
              },
              child: const Text('Crear'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openEditTopic(
    SourceTheme themeMeta,
    SourceThemeTopic topic,
  ) async {
    String name = topic.title;
    String? coverUrl = topic.coverUrl;
    String? coverLocal = topic.coverLocalPath;
    int? colorValue = topic.colorValue;
    Color draftColor = colorValue != null
        ? Color(colorValue!)
        : Theme.of(context).colorScheme.primary;
    final controller = TextEditingController(text: name);

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Editar temática (${themeMeta.title})'),
          content: StatefulBuilder(
            builder: (ctx2, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    onChanged: (v) => name = v,
                    decoration: const InputDecoration(
                      hintText: 'Nombre',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    onChanged: (v) => setState(() => coverUrl = v),
                    decoration: InputDecoration(
                      hintText: 'URL de imagen (opcional)',
                      hintStyle:
                          Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SourceColorPickerField(
                    color: colorValue != null ? Color(colorValue!) : draftColor,
                    onChanged: (c) => setState(() {
                      draftColor = c;
                      colorValue = c.value;
                    }),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final res = await FilePicker.platform.pickFiles(
                              type: FileType.custom,
                              allowedExtensions: const [
                                'jpg',
                                'jpeg',
                                'png',
                                'webp'
                              ],
                            );
                            final file = (res != null && res.files.isNotEmpty)
                                ? res.files.first
                                : null;
                            if (file?.path != null) {
                              setState(() => coverLocal = file!.path!);
                            }
                          },
                          icon: const Icon(Icons.folder_open_rounded),
                          label: const Text('Elegir imagen'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () {
                          setState(() {
                            coverUrl = null;
                            coverLocal = null;
                          });
                        },
                        child: const Text('Quitar'),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await _sources.updateTopic(
                  topic.copyWith(
                    title: name.trim(),
                    coverUrl: coverUrl?.trim().isEmpty == true ? null : coverUrl,
                    coverLocalPath:
                        coverLocal?.trim().isEmpty == true ? null : coverLocal,
                    colorValue: colorValue,
                  ),
                );
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );

    controller.dispose();
  }

  Future<void> _confirmDeleteTopic(SourceThemeTopic topic) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar temática'),
        content: Text('¿Eliminar "${topic.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _sources.deleteTopic(topic);
    }
  }
}

class _TopicCard extends StatelessWidget {
  const _TopicCard({
    required this.themeMeta,
    required this.topic,
    required this.listCount,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  final SourceTheme themeMeta;
  final SourceThemeTopic topic;
  final int listCount;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final base = topic.colorValue != null
        ? Color(topic.colorValue!)
        : themeMeta.colors.first;
    final textColor = Colors.white;

    ImageProvider? provider;
    final path = topic.coverLocalPath?.trim();
    final url = topic.coverUrl?.trim();
    if (path != null && path.isNotEmpty) {
      provider = FileImage(File(path));
    } else if (url != null && url.isNotEmpty) {
      provider = NetworkImage(url);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            color: base.withOpacity(0.92),
          ),
          child: InkWell(
            onTap: onOpen,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 52,
                      height: 52,
                      color: Colors.black.withOpacity(0.18),
                      child: provider != null
                          ? Image(image: provider, fit: BoxFit.cover)
                          : Icon(Icons.folder_rounded, color: textColor),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          topic.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.textTheme.titleMedium?.copyWith(
                            color: textColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${topic.itemIds.length} items · $listCount listas',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.textTheme.bodySmall?.copyWith(
                            color: textColor.withOpacity(0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<_TopicAction>(
                    onSelected: (value) {
                      if (value == _TopicAction.edit) onEdit();
                      if (value == _TopicAction.delete) onDelete();
                    },
                    icon: Icon(Icons.more_vert_rounded, color: textColor),
                    itemBuilder: (ctx) => const [
                      PopupMenuItem(
                        value: _TopicAction.edit,
                        child: Text('Editar'),
                      ),
                      PopupMenuItem(
                        value: _TopicAction.delete,
                        child: Text('Eliminar'),
                      ),
                    ],
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

enum _TopicAction { edit, delete }

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

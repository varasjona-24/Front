import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/data/repo/media_repository.dart';
import '../../../app/models/media_item.dart';
import '../../../app/ui/themes/app_spacing.dart';
import '../../../app/ui/widgets/layout/app_gradient_background.dart';
import '../../../app/ui/widgets/navigation/app_top_bar.dart';
import '../../home/controller/home_controller.dart';
import '../../downloads/view/edit_media_page.dart';
import '../controller/sources_controller.dart';
import '../domain/source_origin.dart';
import '../domain/source_theme.dart';
import '../domain/source_theme_topic_playlist.dart';

class SourceThemeTopicPlaylistPage extends StatefulWidget {
  const SourceThemeTopicPlaylistPage({
    super.key,
    required this.playlistId,
    required this.theme,
    required this.origins,
  });

  final String playlistId;
  final SourceTheme theme;
  final List<SourceOrigin>? origins;

  @override
  State<SourceThemeTopicPlaylistPage> createState() =>
      _SourceThemeTopicPlaylistPageState();
}

class _SourceThemeTopicPlaylistPageState
    extends State<SourceThemeTopicPlaylistPage> {
  final SourcesController _sources = Get.find<SourcesController>();
  final MediaRepository _repo = Get.find<MediaRepository>();

  SourceThemeTopicPlaylist? get _playlist {
    for (final p in _sources.topicPlaylists) {
      if (p.id == widget.playlistId) return p;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final home = Get.find<HomeController>();

    return Obx(() {
      final playlist = _playlist;
      if (playlist == null) {
        return const Scaffold(
          body: Center(child: Text('Lista no encontrada')),
        );
      }

      final children = _sources.playlistsForTopic(
        playlist.topicId,
        parentId: playlist.id,
      );

      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppTopBar(
          title: Text(playlist.name),
          onSearch: home.onSearch,
          onToggleMode: null,
        ),
        body: AppGradientBackground(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.lg,
            ),
            children: [
              Text(
                '${playlist.itemIds.length} items · ${children.length} listas',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              _actionRow(playlist),
              const SizedBox(height: 18),
              _itemsSection(playlist),
              const SizedBox(height: 18),
              _subListsSection(playlist, children),
            ],
          ),
        ),
      );
    });
  }

  Widget _actionRow(SourceThemeTopicPlaylist playlist) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: () => _addItems(playlist),
            icon: const Icon(Icons.add),
            label: const Text('Agregar item'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _addSubList(playlist),
            icon: const Icon(Icons.create_new_folder_rounded),
            label: const Text('Agregar lista'),
          ),
        ),
      ],
    );
  }

  Widget _itemsSection(SourceThemeTopicPlaylist playlist) {
    return FutureBuilder<List<MediaItem>>(
      future: _loadItems(playlist),
      builder: (context, snap) {
        final items = snap.data ?? const <MediaItem>[];
        if (items.isEmpty) {
          return Text(
            'No hay items todavía.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Items',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            ...items.map(
              (item) => ListTile(
                leading: Icon(
                  item.hasVideoLocal
                      ? Icons.videocam_rounded
                      : Icons.music_note_rounded,
                ),
                title: Text(item.title),
                subtitle: Text(item.displaySubtitle),
                trailing: IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => _removeItem(playlist, item),
                ),
                onTap: () => _playItem(items, item),
                onLongPress: () => _showItemActions(playlist, item),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _subListsSection(
    SourceThemeTopicPlaylist playlist,
    List<SourceThemeTopicPlaylist> lists,
  ) {
    if (lists.isEmpty) {
      return Text(
        'No hay listas aún.',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Listas',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        ...lists.map(
          (pl) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _PlaylistCard(
              theme: widget.theme,
              playlist: pl,
              onOpen: () => Get.to(
                () => SourceThemeTopicPlaylistPage(
                  playlistId: pl.id,
                  theme: widget.theme,
                  origins: widget.origins,
                ),
              ),
              onEdit: () => _openEditPlaylist(pl),
              onDelete: () => _sources.deleteTopicPlaylist(pl),
            ),
          ),
        ),
      ],
    );
  }

  Future<List<MediaItem>> _loadItems(SourceThemeTopicPlaylist playlist) async {
    final all = await _repo.getLibrary();
    final origins = widget.origins;
    final allowedOrigins = origins != null && origins.isNotEmpty
        ? origins.toSet()
        : widget.theme.defaultOrigins.toSet();

    Iterable<MediaItem> items = all;
    if (widget.theme.forceKind != null) {
      final kind = widget.theme.forceKind!;
      items = items.where((e) => e.variants.any((v) => v.kind == kind));
    }

    final filtered = allowedOrigins.isNotEmpty
        ? items.where((e) => allowedOrigins.contains(e.origin)).toList()
        : items.toList();

    final idSet = playlist.itemIds.toSet();
    final base = filtered.isNotEmpty ? filtered : items.toList();
    return base.where((e) => idSet.contains(_keyForItem(e))).toList();
  }

  Future<void> _addItems(SourceThemeTopicPlaylist playlist) async {
    final list = await _candidateItems();
    final selected = <String>{};

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx2, setState) {
            return SafeArea(
              child: SizedBox(
                height: MediaQuery.of(ctx2).size.height * 0.7,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.playlist_add_rounded),
                          const SizedBox(width: 8),
                          Text(
                            'Agregar items',
                            style: Theme.of(ctx2).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () => Navigator.of(ctx2).pop(),
                            child: const Text('Cerrar'),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: list.isEmpty
                          ? Center(
                              child: Text(
                                'No hay items disponibles para esta temática.',
                                style: Theme.of(ctx2)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(ctx2)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                              ),
                            )
                          : ListView.builder(
                              itemCount: list.length,
                              itemBuilder: (ctx3, i) {
                                final item = list[i];
                                final key = _keyForItem(item);
                                final checked = selected.contains(key);
                                return CheckboxListTile(
                                  value: checked,
                                  onChanged: (v) {
                                    setState(() {
                                      if (v == true) {
                                        selected.add(key);
                                      } else {
                                        selected.remove(key);
                                      }
                                    });
                                  },
                                  title: Text(item.title),
                                  subtitle: Text(item.displaySubtitle),
                                );
                              },
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: FilledButton(
                        onPressed: () async {
                          final toAdd = list
                              .where((item) =>
                                  selected.contains(_keyForItem(item)))
                              .toList();
                          final mergedIds = {
                            ...playlist.itemIds,
                            ...toAdd.map(_keyForItem),
                          }.toList();
                          await _sources.updateTopicPlaylist(
                            playlist.copyWith(itemIds: mergedIds),
                          );
                          if (ctx2.mounted) Navigator.of(ctx2).pop();
                        },
                        child: const Text('Agregar seleccionados'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _addSubList(SourceThemeTopicPlaylist playlist) async {
    String name = '';
    String? coverUrl;
    String? coverLocal;
    int? colorValue;
    Color draftColor = Theme.of(context).colorScheme.primary;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx2, setState) {
            return SafeArea(
              child: SizedBox(
                height: MediaQuery.of(ctx2).size.height * 0.7,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.create_new_folder_rounded),
                          const SizedBox(width: 8),
                          Text(
                            'Nueva lista',
                            style: Theme.of(ctx2).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () => Navigator.of(ctx2).pop(),
                            child: const Text('Cerrar'),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        onChanged: (v) => setState(() => name = v),
                        decoration: const InputDecoration(
                          hintText: 'Nombre de la lista',
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        onChanged: (v) => setState(() => coverUrl = v),
                        decoration: const InputDecoration(
                          hintText: 'URL de imagen (opcional)',
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _ColorPickerField(
                        color: colorValue != null
                            ? Color(colorValue!)
                            : draftColor,
                        onChanged: (c) => setState(() {
                          draftColor = c;
                          colorValue = c.value;
                        }),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
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
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: FilledButton(
                        onPressed: () async {
                          final trimmed = name.trim();
                          if (trimmed.isEmpty) return;
                          final ok = await _sources.addTopicPlaylist(
                            topicId: playlist.topicId,
                            name: trimmed,
                            items: const [],
                            parentId: playlist.id,
                            depth: playlist.depth + 1,
                            coverUrl: coverUrl,
                            coverLocalPath: coverLocal,
                            colorValue: colorValue,
                          );
                          if (!ok && context.mounted) {
                            Get.snackbar(
                              'Listas',
                              'Límite de 10 niveles alcanzado',
                              snackPosition: SnackPosition.BOTTOM,
                            );
                          }
                          if (ctx2.mounted) Navigator.of(ctx2).pop();
                        },
                        child: const Text('Crear lista'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _removeItem(
    SourceThemeTopicPlaylist playlist,
    MediaItem item,
  ) async {
    final key = _keyForItem(item);
    final updated = playlist.copyWith(
      itemIds: playlist.itemIds.where((e) => e != key).toList(),
    );
    await _sources.updateTopicPlaylist(updated);
  }

  String _keyForItem(MediaItem item) {
    final pid = item.publicId.trim();
    return pid.isNotEmpty ? pid : item.id.trim();
  }

  void _playItem(List<MediaItem> list, MediaItem item) {
    final home = Get.find<HomeController>();
    final idx = list.indexWhere((e) => e.id == item.id);
    final safeIdx = idx == -1 ? 0 : idx;

    if (item.hasVideoLocal && !item.hasAudioLocal) {
      home.mode.value = HomeMode.video;
    } else if (item.hasAudioLocal && !item.hasVideoLocal) {
      home.mode.value = HomeMode.audio;
    }

    home.openMedia(item, safeIdx, list);
  }

  Future<List<MediaItem>> _candidateItems() async {
    final all = await _repo.getLibrary();
    final origins = widget.origins;
    final allowedOrigins = origins != null && origins.isNotEmpty
        ? origins.toSet()
        : widget.theme.defaultOrigins.toSet();

    Iterable<MediaItem> items = all;
    if (widget.theme.forceKind != null) {
      final kind = widget.theme.forceKind!;
      items = items.where((e) => e.variants.any((v) => v.kind == kind));
    }

    final filtered = allowedOrigins.isNotEmpty
        ? items.where((e) => allowedOrigins.contains(e.origin)).toList()
        : items.toList();

    return filtered.isNotEmpty ? filtered : items.toList();
  }

  Future<void> _showItemActions(
    SourceThemeTopicPlaylist playlist,
    MediaItem item,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit_rounded),
                title: const Text('Editar'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await Get.to(() => EditMediaMetadataPage(item: item));
                  if (mounted) setState(() {});
                },
              ),
              ListTile(
                leading: const Icon(Icons.remove_circle_outline),
                title: const Text('Quitar de la lista'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await _removeItem(playlist, item);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openEditPlaylist(SourceThemeTopicPlaylist playlist) async {
    String name = playlist.name;
    String? coverUrl = playlist.coverUrl;
    String? coverLocal = playlist.coverLocalPath;
    int? colorValue = playlist.colorValue;
    Color draftColor = colorValue != null
        ? Color(colorValue!)
        : Theme.of(context).colorScheme.primary;
    final controller = TextEditingController(text: name);

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Editar lista'),
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
                    decoration: const InputDecoration(
                      hintText: 'URL de imagen (opcional)',
                    ),
                  ),
                  const SizedBox(height: 10),
                  _ColorPickerField(
                    color: colorValue != null
                        ? Color(colorValue!)
                        : draftColor,
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
                await _sources.updateTopicPlaylist(
                  playlist.copyWith(
                    name: name.trim(),
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

  Widget _playlistThumb(SourceThemeTopicPlaylist pl) {
    final scheme = Theme.of(context).colorScheme;
    final path = pl.coverLocalPath?.trim();
    final url = pl.coverUrl?.trim();
    ImageProvider? provider;
    if (path != null && path.isNotEmpty) {
      provider = FileImage(File(path));
    } else if (url != null && url.isNotEmpty) {
      provider = NetworkImage(url);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 52,
        height: 52,
        color: Colors.black.withOpacity(0.18),
        child: provider != null
            ? Image(image: provider, fit: BoxFit.cover)
            : Icon(Icons.queue_music_rounded, color: scheme.onSurfaceVariant),
      ),
    );
  }
}

class _PlaylistCard extends StatelessWidget {
  const _PlaylistCard({
    required this.theme,
    required this.playlist,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  final SourceTheme theme;
  final SourceThemeTopicPlaylist playlist;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final base = playlist.colorValue != null
        ? Color(playlist.colorValue!)
        : theme.colors.first;
    final textColor = Colors.white;

    ImageProvider? provider;
    final path = playlist.coverLocalPath?.trim();
    final url = playlist.coverUrl?.trim();
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
                          : Icon(Icons.queue_music_rounded, color: textColor),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          playlist.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.textTheme.titleMedium?.copyWith(
                            color: textColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${playlist.itemIds.length} items',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.textTheme.bodySmall?.copyWith(
                            color: textColor.withOpacity(0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<_PlaylistAction>(
                    onSelected: (value) {
                      if (value == _PlaylistAction.edit) onEdit();
                      if (value == _PlaylistAction.delete) onDelete();
                    },
                    icon: Icon(Icons.more_vert_rounded, color: textColor),
                    itemBuilder: (ctx) => const [
                      PopupMenuItem(
                        value: _PlaylistAction.edit,
                        child: Text('Editar'),
                      ),
                      PopupMenuItem(
                        value: _PlaylistAction.delete,
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

class _ColorPickerField extends StatelessWidget {
  const _ColorPickerField({
    required this.color,
    required this.onChanged,
  });

  final Color color;
  final ValueChanged<Color> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface;
    final r = color.red;
    final g = color.green;
    final b = color.blue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Color',
          style: theme.textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        Container(
          height: 36,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: theme.colorScheme.onSurface.withOpacity(0.2),
            ),
          ),
        ),
        const SizedBox(height: 10),
        _colorSlider(
          context,
          label: 'R',
          value: r.toDouble(),
          color: const Color(0xFFE53935),
          onChanged: (v) => onChanged(
            Color.fromARGB(255, v.round(), g, b),
          ),
        ),
        _colorSlider(
          context,
          label: 'G',
          value: g.toDouble(),
          color: const Color(0xFF43A047),
          onChanged: (v) => onChanged(
            Color.fromARGB(255, r, v.round(), b),
          ),
        ),
        _colorSlider(
          context,
          label: 'B',
          value: b.toDouble(),
          color: const Color(0xFF1E88E5),
          onChanged: (v) => onChanged(
            Color.fromARGB(255, r, g, v.round()),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '#${color.value.toRadixString(16).padLeft(8, '0').toUpperCase()}',
          style: theme.textTheme.labelMedium?.copyWith(color: textColor),
        ),
      ],
    );
  }

  Widget _colorSlider(
    BuildContext context, {
    required String label,
    required double value,
    required Color color,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 18,
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: color,
              thumbColor: color,
              overlayColor: color.withOpacity(0.2),
            ),
            child: Slider(
              min: 0,
              max: 255,
              divisions: 255,
              value: value,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

enum _PlaylistAction { edit, delete }

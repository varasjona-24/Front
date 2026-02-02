import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/ui/themes/app_spacing.dart';
import '../../../app/ui/widgets/layout/app_gradient_background.dart';
import '../../../app/ui/widgets/navigation/app_top_bar.dart';
import '../../../app/models/media_item.dart';
import '../../home/controller/home_controller.dart';
import '../controller/playlists_controller.dart';
import '../domain/playlist.dart';
import '../../../app/utils/format_bytes.dart';

class PlaylistDetailPage extends GetView<PlaylistsController> {
  const PlaylistDetailPage._({required this.playlistId, required this.isSmart});

  factory PlaylistDetailPage.smart({required String playlistId}) {
    return PlaylistDetailPage._(playlistId: playlistId, isSmart: true);
  }

  factory PlaylistDetailPage.custom({required String playlistId}) {
    return PlaylistDetailPage._(playlistId: playlistId, isSmart: false);
  }

  final String playlistId;
  final bool isSmart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final home = Get.find<HomeController>();

    return Obx(() {
      final smart = isSmart ? controller.getSmartById(playlistId) : null;
      final playlist = !isSmart ? controller.getPlaylistById(playlistId) : null;

      final title = isSmart ? smart?.title : playlist?.name;
      final items = isSmart
          ? (smart?.items ?? const <MediaItem>[])
          : (playlist != null
                ? controller.resolvePlaylistItems(playlist)
                : const <MediaItem>[]);

      final cover = _resolveCover(playlist, items);
      final totalBytes = _totalBytes(items);

      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppTopBar(
          title: Text(title ?? 'Lista'),
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
              _header(theme, title, cover, items.length, totalBytes),
              const SizedBox(height: 14),
              _actionRow(items),
              const SizedBox(height: 16),
              if (!isSmart)
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: () => _openAddSongs(context, playlist),
                    icon: const Icon(Icons.add),
                    label: const Text('Agregar canciones'),
                  ),
                ),
              if (!isSmart) const SizedBox(height: 10),
              if (items.isEmpty)
                Text(
                  'No hay canciones en esta lista.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              else
                ...items.asMap().entries.map(
                  (entry) => _trackTile(
                    theme,
                    entry.value,
                    entry.key,
                    items,
                    isSmart ? null : playlist,
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }

  Widget _header(
    ThemeData theme,
    String? title,
    ImageProvider? cover,
    int count,
    int totalBytes,
  ) {
    final scheme = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 96,
            height: 96,
            color: scheme.surfaceContainer,
            child: cover != null
                ? Image(image: cover, fit: BoxFit.cover)
                : Icon(
                    Icons.music_note_rounded,
                    color: scheme.onSurfaceVariant,
                    size: 36,
                  ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title ?? 'Lista',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _buildMetaLine(count, totalBytes),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _buildMetaLine(int count, int totalBytes) {
    final sizeLabel = totalBytes > 0 ? formatBytes(totalBytes) : '';
    if (sizeLabel.isEmpty) return '$count canciones';
    return '$count canciones · $sizeLabel';
  }

  int _totalBytes(List<MediaItem> items) {
    var total = 0;
    for (final item in items) {
      final v = item.localAudioVariant ?? item.localVideoVariant;
      final size = v?.size ?? 0;
      if (size > 0) total += size;
    }
    return total;
  }

  Widget _actionRow(List<MediaItem> items) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: items.isEmpty ? null : () => _play(items, 0),
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Reproducir'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: items.isEmpty ? null : () => _playShuffled(items),
            icon: const Icon(Icons.shuffle_rounded),
            label: const Text('Aleatorio'),
          ),
        ),
      ],
    );
  }

  Widget _trackTile(
    ThemeData theme,
    MediaItem item,
    int index,
    List<MediaItem> queue,
    Playlist? playlist,
  ) {
    final scheme = theme.colorScheme;
    final thumb = item.effectiveThumbnail;
    ImageProvider? provider;
    if (thumb != null && thumb.isNotEmpty) {
      provider = thumb.startsWith('http')
          ? NetworkImage(thumb)
          : FileImage(File(thumb));
    }

    return ListTile(
      onTap: () => _play(queue, index),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 44,
          height: 44,
          color: scheme.surfaceContainerHighest,
          child: provider != null
              ? Image(image: provider, fit: BoxFit.cover)
              : Icon(Icons.music_note_rounded, color: scheme.onSurfaceVariant),
        ),
      ),
      title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        item.displaySubtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: playlist == null
          ? null
          : IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () => _removeFromPlaylist(item, playlist),
            ),
    );
  }

  void _play(List<MediaItem> queue, int index) {
    if (queue.isEmpty) return;
    Get.toNamed(
      AppRoutes.audioPlayer,
      arguments: {'queue': queue, 'index': index},
    );
  }

  void _playShuffled(List<MediaItem> items) {
    if (items.isEmpty) return;
    final shuffled = List<MediaItem>.from(items)..shuffle();
    _play(shuffled, 0);
  }

  ImageProvider? _resolveCover(Playlist? playlist, List<MediaItem> items) {
    if (playlist != null) {
      final local = playlist.coverLocalPath?.trim();
      if (local != null && local.isNotEmpty) {
        return FileImage(File(local));
      }
      final url = playlist.coverUrl?.trim();
      if (url != null && url.isNotEmpty) {
        return NetworkImage(url);
      }
    }
    final thumb = items.isNotEmpty ? items.first.effectiveThumbnail : null;
    if (thumb != null && thumb.isNotEmpty) {
      return thumb.startsWith('http')
          ? NetworkImage(thumb)
          : FileImage(File(thumb));
    }
    return null;
  }

  Future<void> _openAddSongs(BuildContext context, Playlist? playlist) async {
    if (playlist == null) return;
    final existing = playlist.itemIds.toSet();
    final selected = <String>{};
    final items = controller.libraryAudio.where((item) {
      final key = item.publicId.trim().isNotEmpty
          ? item.publicId.trim()
          : item.id.trim();
      return !existing.contains(key);
    }).toList();

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
                            'Agregar canciones',
                            style: Theme.of(ctx2).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
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
                      child: ListView.builder(
                        itemCount: items.length,
                        itemBuilder: (ctx3, i) {
                          final item = items[i];
                          final key = item.publicId.trim().isNotEmpty
                              ? item.publicId.trim()
                              : item.id.trim();
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
                          final toAdd = items.where((item) {
                            final key = item.publicId.trim().isNotEmpty
                                ? item.publicId.trim()
                                : item.id.trim();
                            return selected.contains(key);
                          }).toList();
                          await controller.addItemsToPlaylist(
                            playlist.id,
                            toAdd,
                          );
                          if (ctx2.mounted) Navigator.of(ctx2).pop();
                        },
                        child: const Text('Agregar seleccionadas'),
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

  Future<void> _removeFromPlaylist(MediaItem item, Playlist playlist) async {
    await controller.removeItemFromPlaylist(playlist.id, item);
  }
}

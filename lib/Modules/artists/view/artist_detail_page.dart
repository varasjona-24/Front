import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/models/media_item.dart';
import '../../../app/controllers/media_actions_controller.dart';
import '../../../app/utils/artist_credit_parser.dart';
import 'package:flutter_listenfy/Modules/home/controller/home_controller.dart';
import '../../../app/routes/app_routes.dart';
import '../controller/artists_controller.dart';
import '../../edit/controller/edit_entity_controller.dart';
import '../../../app/ui/widgets/layout/app_gradient_background.dart';
import 'widgets/artist_avatar.dart';
import '../../../app/ui/widgets/branding/listenfy_logo.dart';

class ArtistDetailPage extends GetView<ArtistsController> {
  const ArtistDetailPage({super.key, required this.artistKey});

  final String artistKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final home = Get.find<HomeController>();
    final actions = Get.find<MediaActionsController>();

    return Obx(() {
      ArtistGroup? artist;
      for (final entry in controller.artists) {
        if (entry.key == artistKey) {
          artist = entry;
          break;
        }
      }

      if (artist == null) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Artista'),
            backgroundColor: theme.colorScheme.surface,
            surfaceTintColor: theme.colorScheme.surface,
            foregroundColor: theme.colorScheme.onSurface,
            elevation: 0,
          ),
          body: const Center(child: Text('Artista no encontrado')),
        );
      }

      final resolved = artist;
      final primarySongs = resolved.items.where((item) {
        final credits = ArtistCreditParser.parse(item.subtitle);
        return credits.isPrimaryArtistKey(resolved.key);
      }).toList();
      final collaborationSongs = resolved.items.where((item) {
        final credits = ArtistCreditParser.parse(item.subtitle);
        return credits.isCollaborationForArtistKey(resolved.key);
      }).toList();
      final displayQueue = <MediaItem>[
        ...primarySongs,
        ...collaborationSongs,
      ];

      final thumb = resolved.thumbnailLocalPath ?? resolved.thumbnail;

      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: ListenfyLogo(
            size: 28,
            color: theme.colorScheme.primary,
          ),
          backgroundColor: theme.colorScheme.surface,
          surfaceTintColor: theme.colorScheme.surface,
          foregroundColor: theme.colorScheme.onSurface,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () => Get.toNamed(
                AppRoutes.editEntity,
                arguments: EditEntityArgs.artist(resolved),
              ),
            ),
          ],
        ),
        body: AppGradientBackground(
          child: RefreshIndicator(
            onRefresh: controller.load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  elevation: 0,
                  color: theme.colorScheme.surfaceContainer,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        ArtistAvatar(thumb: thumb, radius: 36),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                resolved.name,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${resolved.count} canciones',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _SongSection(
                  title: 'Canciones',
                  subtitle: '${primarySongs.length} como artista principal',
                  items: primarySongs,
                  onPlay: (item) => home.openMedia(
                    item,
                    displayQueue.indexWhere((entry) => entry.id == item.id),
                    displayQueue,
                  ),
                  onMore: (item) => actions.showItemActions(
                    context,
                    item,
                    onChanged: controller.load,
                  ),
                ),
                if (collaborationSongs.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _SongSection(
                    title: 'Colaboraciones',
                    subtitle: '${collaborationSongs.length} como invitado',
                    items: collaborationSongs,
                    onPlay: (item) => home.openMedia(
                      item,
                      displayQueue.indexWhere((entry) => entry.id == item.id),
                      displayQueue,
                    ),
                    onMore: (item) => actions.showItemActions(
                      context,
                      item,
                      onChanged: controller.load,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    });
  }
}

class _SongSection extends StatelessWidget {
  const _SongSection({
    required this.title,
    required this.subtitle,
    required this.items,
    required this.onPlay,
    required this.onMore,
  });

  final String title;
  final String subtitle;
  final List<MediaItem> items;
  final ValueChanged<MediaItem> onPlay;
  final ValueChanged<MediaItem> onMore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        for (final item in items)
          _SongTile(
            item: item,
            onPlay: () => onPlay(item),
            onMore: () => onMore(item),
          ),
      ],
    );
  }
}

class _SongTile extends StatelessWidget {
  const _SongTile({
    required this.item,
    required this.onPlay,
    required this.onMore,
  });

  final MediaItem item;
  final VoidCallback onPlay;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isVideo = item.hasVideoLocal || item.localVideoVariant != null;
    final thumb = item.effectiveThumbnail ?? '';
    final hasThumb = thumb.isNotEmpty;
    final isLocal = hasThumb && thumb.startsWith('/');

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: hasThumb
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: isLocal
                    ? Image.file(
                        File(thumb),
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                      )
                    : Image.network(
                        thumb,
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                      ),
              )
            : Icon(
                isVideo ? Icons.videocam_rounded : Icons.music_note_rounded,
              ),
        title: Text(
          item.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          item.displaySubtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: onMore,
        ),
        onTap: onPlay,
      ),
    );
  }
}

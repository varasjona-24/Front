import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/models/media_item.dart';
import 'package:flutter_listenfy/Modules/home/controller/home_controller.dart';
import '../controller/artists_controller.dart';
import 'edit_artist_page.dart';
import '../../../app/ui/widgets/layout/app_gradient_background.dart';

class ArtistDetailPage extends GetView<ArtistsController> {
  const ArtistDetailPage({super.key, required this.artistKey});

  final String artistKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final home = Get.find<HomeController>();

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
          appBar: AppBar(title: const Text('Artista')),
          body: const Center(child: Text('Artista no encontrado')),
        );
      }

      final resolved = artist;

      final thumb = resolved.thumbnailLocalPath ?? resolved.thumbnail;

      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(resolved.name),
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.edit_rounded),
              onPressed: () => Get.to(
                () => EditArtistPage(artist: resolved),
              ),
            ),
          ],
        ),
        body: AppGradientBackground(
          child: ListView(
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
                      _ArtistAvatar(thumb: thumb),
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
              Text(
                'Canciones',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              for (int i = 0; i < resolved.items.length; i++)
                _SongTile(
                  item: resolved.items[i],
                  onPlay: () => home.openMedia(
                    resolved.items[i],
                    i,
                    resolved.items,
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }
}

class _ArtistAvatar extends StatelessWidget {
  const _ArtistAvatar({required this.thumb});

  final String? thumb;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (thumb != null && thumb!.isNotEmpty) {
      return CircleAvatar(
        radius: 36,
        backgroundColor: scheme.surface,
        backgroundImage: thumb!.startsWith('http')
            ? NetworkImage(thumb!)
            : FileImage(File(thumb!)) as ImageProvider,
      );
    }

    return CircleAvatar(
      radius: 36,
      backgroundColor: scheme.surface,
      child: Icon(
        Icons.person_rounded,
        color: scheme.onSurfaceVariant,
      ),
    );
  }
}

class _SongTile extends StatelessWidget {
  const _SongTile({
    required this.item,
    required this.onPlay,
  });

  final MediaItem item;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isVideo = item.hasVideoLocal || item.localVideoVariant != null;

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: Icon(
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
          icon: const Icon(Icons.play_arrow_rounded),
          onPressed: onPlay,
        ),
        onTap: onPlay,
      ),
    );
  }
}

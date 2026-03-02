import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controller/video_player_controller.dart';
import '../../../../app/models/media_item.dart';

class VideoQueuePage extends GetView<VideoPlayerController> {
  const VideoQueuePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cola de reproducción'),
        centerTitle: true,
      ),
      body: Obx(() {
        final queue = controller.queue;
        final idx = controller.currentIndex.value;

        if (queue.isEmpty) {
          return const Center(child: Text('La cola está vacía'));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: queue.length,
          separatorBuilder: (_, __) => const SizedBox(height: 6),
          itemBuilder: (context, i) {
            final it = queue[i];
            final selected = i == idx;
            return ListTile(
              selected: selected,
              leading: _thumb(theme: theme, item: it, selected: selected),
              title: Text(
                it.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle:
                  it.subtitle.isNotEmpty ? Text(it.subtitle) : null,
              onTap: () async {
                await controller.playAt(i);
                Get.back();
              },
              trailing: selected ? const Text('Reproduciendo') : null,
            );
          },
        );
      }),
    );
  }

  Widget _thumb({
    required ThemeData theme,
    required MediaItem item,
    required bool selected,
  }) {
    final thumb = item.effectiveThumbnail?.trim();

    Widget image;
    if (thumb != null && thumb.isNotEmpty) {
      final looksLikeUrl =
          thumb.startsWith('http://') || thumb.startsWith('https://');
      if (looksLikeUrl) {
        image = Image.network(
          thumb,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _thumbFallback(theme),
        );
      } else {
        image = Image.file(
          File(thumb),
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _thumbFallback(theme),
        );
      }
    } else {
      image = _thumbFallback(theme);
    }

    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ClipRRect(borderRadius: BorderRadius.circular(6), child: image),
          if (selected)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: theme.colorScheme.surface,
                    width: 2,
                  ),
                ),
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.play_arrow,
                  size: 12,
                  color: theme.colorScheme.onPrimary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _thumbFallback(ThemeData theme) {
    return Container(
      width: 48,
      height: 48,
      color: theme.colorScheme.surfaceVariant,
      alignment: Alignment.center,
      child: Icon(Icons.videocam, color: theme.colorScheme.onSurfaceVariant),
    );
  }
}

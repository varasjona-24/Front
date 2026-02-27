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
        final _ = controller.queueVersion.value;
        final queue = controller.queue;
        final idx = controller.currentIndex.value;

        if (queue.isEmpty) {
          return const Center(child: Text('La cola está vacía'));
        }

        return ReorderableListView.builder(
          padding: const EdgeInsets.all(12),
          buildDefaultDragHandles: false,
          itemCount: queue.length,
          onReorder: controller.reorderQueue,
          itemBuilder: (context, i) {
            final it = queue[i];
            final selected = i == idx;
            return Dismissible(
              key: ValueKey('video_queue_${it.id}_$i'),
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.delete_outline,
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
              direction: DismissDirection.endToStart,
              onDismissed: (_) async {
                final removeIndex = controller.queue.indexOf(it);
                if (removeIndex >= 0) {
                  await controller.removeFromQueue(removeIndex);
                }
              },
              child: Card(
                margin: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  selected: selected,
                  leading: _thumb(theme: theme, item: it, selected: selected),
                  title: Text(
                    it.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: it.subtitle.isNotEmpty ? Text(it.subtitle) : null,
                  onTap: () async {
                    await controller.playAt(i);
                    Get.back();
                  },
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (selected)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Text(
                            'Reproduciendo',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ReorderableDragStartListener(
                        index: i,
                        child: const Icon(Icons.drag_handle_rounded),
                      ),
                    ],
                  ),
                ),
              ),
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

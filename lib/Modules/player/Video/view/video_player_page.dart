import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart' as vp;

import 'package:flutter_listenfy/Modules/player/Video/Controller/video_player_controller.dart';
import '../../audio/view/queue_page.dart';

class VideoPlayerPage extends GetView<VideoPlayerController> {
  const VideoPlayerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Obx(() {
          final queue = controller.queue;
          final idx = controller.currentIndex.value;
          final item = (queue.isNotEmpty && idx >= 0 && idx < queue.length)
              ? queue[idx]
              : null;

          if (item == null) return const Center(child: Text('No hay vídeo'));

          final vpCtrl = controller.player;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: Get.back,
                    ),
                    Expanded(
                      child: Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Ver cola',
                      icon: const Icon(Icons.playlist_play),
                      onPressed: () => Get.to(() => const QueuePage()),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Video area / Error handling
              Expanded(
                child: Center(
                  child: Obx(() {
                    final err = controller.error.value;
                    if (err != null) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 64,
                              color: theme.colorScheme.error,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              err,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ElevatedButton(
                                  onPressed: () =>
                                      Get.to(() => const QueuePage()),
                                  child: const Text('Seleccionar otro'),
                                ),
                                const SizedBox(width: 12),
                                OutlinedButton(
                                  onPressed: controller.retry,
                                  child: const Text('Reintentar'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }

                    if (vpCtrl == null || vpCtrl.value.isInitialized == false) {
                      return Container(
                        color: theme.colorScheme.surfaceVariant,
                        child: const Center(child: CircularProgressIndicator()),
                      );
                    }

                    return AspectRatio(
                      aspectRatio: vpCtrl.value.aspectRatio,
                      child: vp.VideoPlayer(vpCtrl),
                    );
                  }),
                ),
              ),

              // Controls
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  children: [
                    // Progress + timestamps
                    Row(
                      children: [
                        Obx(
                          () => Text(
                            _fmt(controller.position.value),
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                        Expanded(
                          child: Obx(() {
                            final maxSeconds =
                                controller.duration.value.inSeconds <= 0
                                ? 1.0
                                : controller.duration.value.inSeconds
                                      .toDouble();
                            final pos = controller.position.value.inSeconds
                                .toDouble()
                                .clamp(0.0, maxSeconds)
                                .toDouble();

                            return Slider(
                              value: pos,
                              min: 0.0,
                              max: maxSeconds,
                              onChanged: (v) {
                                controller.seek(Duration(seconds: v.toInt()));
                              },
                            );
                          }),
                        ),
                        Obx(
                          () => Text(
                            _fmt(controller.duration.value),
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.skip_previous),
                          onPressed: controller.previous,
                        ),
                        const SizedBox(width: 12),
                        Obx(() {
                          final playing = controller.isPlaying.value;
                          return ElevatedButton(
                            onPressed: controller.togglePlay,
                            style: ElevatedButton.styleFrom(
                              shape: const CircleBorder(),
                              padding: EdgeInsets.zero,
                              backgroundColor: theme.colorScheme.primary
                                  .withOpacity(0.25),
                              elevation: 0,
                            ),
                            child: Icon(
                              playing ? Icons.pause : Icons.play_arrow,
                              size: 30,
                              color: theme.colorScheme.onSurface,
                            ),
                          );
                        }),
                        const SizedBox(width: 12),
                        IconButton(
                          icon: const Icon(Icons.skip_next),
                          onPressed: controller.next,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = d.inHours;

    if (h > 0) {
      final hh = h.toString().padLeft(2, '0');
      return '$hh:$m:$s';
    }
    return '$m:$s';
  }
}

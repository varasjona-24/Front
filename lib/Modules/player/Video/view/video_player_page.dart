import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart' as vp;

import 'package:flutter_listenfy/Modules/player/Video/controller/video_player_controller.dart';
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

          if (item == null) {
            return const Center(child: Text('No hay vídeo'));
          }

          return Column(
            children: [
              // ───────────────────────────────────────────────────────────────
              // Top bar
              // ───────────────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
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

              const SizedBox(height: 10),

              // ───────────────────────────────────────────────────────────────
              // Video area (robust layout)
              // ───────────────────────────────────────────────────────────────
              Expanded(
                child: Obx(() {
                  // Fuerza rebuild cuando cambia el estado de reproducción
                  final _ = controller.state.value;

                  final err = controller.error.value;
                  if (err != null) {
                    return _ErrorPanel(
                      message: err,
                      onPickOther: () => Get.to(() => const QueuePage()),
                      onRetry: controller.retry,
                    );
                  }

                  final vpCtrl = controller.playerController;

                  // Loader si aún no hay controller o no inicializa
                  if (vpCtrl == null || !vpCtrl.value.isInitialized) {
                    return Container(
                      color: theme.colorScheme.surfaceVariant,
                      child: const Center(child: CircularProgressIndicator()),
                    );
                  }

                  // Size del video (si es 0, algo raro pasa)
                  final size = vpCtrl.value.size;
                  if (size.width <= 0 || size.height <= 0) {
                    return Container(
                      color: theme.colorScheme.surfaceVariant,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: const Center(
                        child: Text(
                          'No se pudo obtener el tamaño del vídeo.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  // ✅ Layout ultra robusto: evita AspectRatio unbounded constraints
                  return Container(
                    color: Colors.black,
                    child: SizedBox.expand(
                      child: FittedBox(
                        fit: BoxFit.contain,
                        alignment: Alignment.center,
                        child: SizedBox(
                          width: size.width,
                          height: size.height,
                          child: vp.VideoPlayer(vpCtrl),
                        ),
                      ),
                    ),
                  );
                }),
              ),

              // ───────────────────────────────────────────────────────────────
              // Controls
              // ───────────────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  children: [
                    // Progress + timestamps
                    Obx(() {
                      final dur = controller.duration.value;
                      final pos = controller.position.value;

                      final maxSeconds = dur.inSeconds > 0
                          ? dur.inSeconds.toDouble()
                          : 1.0;
                      final posSeconds = pos.inSeconds.toDouble().clamp(
                        0.0,
                        maxSeconds,
                      );

                      return Row(
                        children: [
                          Text(_fmt(pos), style: theme.textTheme.bodySmall),
                          Expanded(
                            child: Slider(
                              value: posSeconds,
                              min: 0.0,
                              max: maxSeconds,
                              // 👇 NO spamear seek en cada pixel, mejor al soltar
                              onChanged: (_) {},
                              onChangeEnd: (v) {
                                controller.seek(Duration(seconds: v.toInt()));
                              },
                            ),
                          ),
                          Text(_fmt(dur), style: theme.textTheme.bodySmall),
                        ],
                      );
                    }),

                    const SizedBox(height: 6),

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

  static String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (h > 0) {
      final hh = h.toString().padLeft(2, '0');
      return '$hh:$m:$s';
    }
    return '$m:$s';
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({
    required this.message,
    required this.onPickOther,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onPickOther;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton(
                  onPressed: onPickOther,
                  child: const Text('Seleccionar otro'),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: onRetry,
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

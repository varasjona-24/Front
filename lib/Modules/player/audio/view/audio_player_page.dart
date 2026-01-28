import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controller/audio_player_controller.dart';
import 'queue_page.dart';
import '../widgets/cover_art.dart';
import '../widgets/playback_controls.dart';
import '../widgets/progress_bar.dart';
import '../../../../app/ui/widgets/layout/app_gradient_background.dart';
import '../../../../app/services/spatial_audio_service.dart';

class AudioPlayerPage extends GetView<AudioPlayerController> {
  const AudioPlayerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppGradientBackground(
        child: SafeArea(
          child: Obx(() {
            final queue = controller.queue;
            final idx = controller.currentIndex.value;
            final item = (queue.isNotEmpty && idx >= 0 && idx < queue.length)
                ? queue[idx]
                : null;

            if (item == null) {
              return const Center(child: Text('No hay nada reproduciéndose'));
            }

            return Column(
              children: [
                // ───────────────── Top Bar ─────────────────
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
                        tooltip: 'Cambiar estilo de portada',
                        icon: const Icon(Icons.checkroom),
                        onPressed: controller.toggleCoverStyle,
                      ),
                      IconButton(
                        tooltip: 'Ver cola',
                        icon: const Icon(Icons.playlist_play),
                        onPressed: () => Get.to(() => const QueuePage()),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // ───────────────── Cover ─────────────────
                CoverArt(controller: controller, item: item),

                const SizedBox(height: 24),

                // ───────────────── Info ─────────────────
                Text(
                  item.title,
                  style: theme.textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(item.subtitle, style: theme.textTheme.bodyMedium),

                const SizedBox(height: 24),

                // ───────────────── Progress ─────────────────
                const ProgressBar(),
                const SizedBox(height: 8),

                // ───────────────── Audio mode + Repeat ─────────────────
                Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Obx(() {
                          final enabled = controller.spatialMode.value ==
                              SpatialAudioMode.virtualizer;
                          return IconButton(
                            tooltip: 'Envolvente',
                            icon: Icon(
                              Icons.surround_sound,
                              color: enabled
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurface.withOpacity(
                                      0.55,
                                    ),
                            ),
                            onPressed: () => controller.setSpatialMode(
                              enabled
                                  ? SpatialAudioMode.off
                                  : SpatialAudioMode.virtualizer,
                            ),
                          );
                        }),
                        const SizedBox(width: 18),
                        Obx(() {
                          final active =
                              controller.repeatMode.value == RepeatMode.once;
                          return IconButton(
                            tooltip: 'Repetir una vez',
                            icon: Icon(
                              Icons.repeat_one,
                              color: active
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurface.withOpacity(
                                      0.55,
                                    ),
                            ),
                            onPressed: controller.toggleRepeatOnce,
                          );
                        }),
                        Obx(() {
                          final active =
                              controller.repeatMode.value == RepeatMode.loop;
                          return IconButton(
                            tooltip: 'Bucle infinito',
                            icon: Icon(
                              Icons.repeat,
                              color: active
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurface.withOpacity(
                                      0.55,
                                    ),
                            ),
                            onPressed: controller.toggleRepeatLoop,
                          );
                        }),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // ───────────────── Controls ─────────────────
                const PlaybackControls(),

                const Spacer(),
              ],
            );
          }),
        ),
      ),
    );
  }
}

class _AudioModeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const _AudioModeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final enabled = onTap != null;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? colors.primary.withOpacity(0.18)
              : colors.surface.withOpacity(enabled ? 0.12 : 0.06),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? colors.primary.withOpacity(0.5)
                : colors.onSurface.withOpacity(enabled ? 0.08 : 0.04),
          ),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: selected
                ? colors.primary
                : colors.onSurface.withOpacity(enabled ? 1 : 0.6),
          ),
        ),
      ),
    );
  }
}

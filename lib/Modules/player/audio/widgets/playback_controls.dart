import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../audio/controller/audio_player_controller.dart';

class PlaybackControls extends StatelessWidget {
  const PlaybackControls({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<AudioPlayerController>();
    final theme = Theme.of(context);

    return Obx(() {
      final loading = c.audioService.isLoading.value;
      final playing = c.audioService.isPlaying.value;

      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Shuffle
          IconButton(
            icon: Icon(
              Icons.shuffle,
              color: c.isShuffling.value ? theme.colorScheme.primary : null,
            ),
            onPressed: loading ? null : c.toggleShuffle,
            tooltip: 'Shuffle',
          ),

          IconButton(
            icon: const Icon(Icons.skip_previous),
            onPressed: loading ? null : c.previous,
          ),

          const SizedBox(width: 12),

          SizedBox(
            width: 64,
            height: 64,
            child: loading
                ? Center(
                    child: SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation(
                          theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  )
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      shape: const CircleBorder(),
                      padding: EdgeInsets.zero,
                      backgroundColor: theme.colorScheme.primary.withOpacity(
                        0.25,
                      ),
                      elevation: 0,
                    ),
                    onPressed: c.togglePlay,
                    child: Icon(
                      playing ? Icons.pause : Icons.play_arrow,
                      size: 30,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
          ),

          const SizedBox(width: 12),

          IconButton(
            icon: const Icon(Icons.skip_next),
            onPressed: loading ? null : c.next,
          ),

          // Speed
          IconButton(
            icon: Obx(
              () => Text(
                '${c.audioService.speed.value.toStringAsFixed(2)}x',
                style: theme.textTheme.bodySmall,
              ),
            ),
            onPressed: loading ? null : c.cyclePlaybackSpeed,
            tooltip: 'Speed',
          ),
        ],
      );
    });
  }
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../models/media_item.dart';
import '../../../routes/app_routes.dart';
import '../../../services/audio_service.dart';
import '../../../services/video_service.dart';

class MiniPlayerBar extends StatelessWidget {
  const MiniPlayerBar({super.key});

  @override
  Widget build(BuildContext context) {
    final audio = Get.find<AudioService>();
    final video = Get.find<VideoService>();

    return Obx(() {
      final audioItem = audio.currentItem.value;
      final videoItem = video.currentItem.value;
      final audioActive = audioItem != null &&
          audio.state.value != PlaybackState.stopped;
      final videoActive = videoItem != null &&
          video.state.value != VideoPlaybackState.stopped;

      if (!audioActive && !videoActive) {
        return const SizedBox.shrink();
      }

      final isVideo = videoActive && !audioActive;
      final item = isVideo ? videoItem! : audioItem!;
      final isPlaying =
          isVideo ? video.isPlaying.value : audio.isPlaying.value;

      return _MiniBar(
        item: item,
        isVideo: isVideo,
        isPlaying: isPlaying,
        onToggle: () async {
          if (isVideo) {
            await video.toggle();
          } else {
            await audio.toggle();
          }
        },
        onClose: () async {
          if (isVideo) {
            await video.stop();
          } else {
            await audio.stop();
          }
        },
        onOpen: () {
          final route =
              isVideo ? AppRoutes.videoPlayer : AppRoutes.audioPlayer;
          Get.toNamed(route, arguments: {
            'queue': <MediaItem>[item],
            'index': 0,
          });
        },
      );
    });
  }
}

class _MiniBar extends StatelessWidget {
  const _MiniBar({
    required this.item,
    required this.isVideo,
    required this.isPlaying,
    required this.onToggle,
    required this.onClose,
    required this.onOpen,
  });

  final MediaItem item;
  final bool isVideo;
  final bool isPlaying;
  final VoidCallback onToggle;
  final VoidCallback onClose;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final thumb = item.effectiveThumbnail;

    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onOpen,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: scheme.primary.withOpacity(0.18),
              ),
              boxShadow: [
                BoxShadow(
                  color: scheme.shadow.withOpacity(0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: SizedBox(
              height: 64,
              child: Row(
                children: [
                  const SizedBox(width: 10),
                  _Thumb(thumb: thumb, isVideo: isVideo),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.displaySubtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: isPlaying ? 'Pausar' : 'Reproducir',
                    icon: Icon(
                      isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    ),
                    onPressed: onToggle,
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: onClose,
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.thumb, required this.isVideo});

  final String? thumb;
  final bool isVideo;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = scheme.primary.withOpacity(0.12);

    if (thumb != null && thumb!.isNotEmpty) {
      final provider = thumb!.startsWith('http')
          ? NetworkImage(thumb!)
          : FileImage(File(thumb!)) as ImageProvider;
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image(
          image: provider,
          width: 46,
          height: 46,
          fit: BoxFit.cover,
        ),
      );
    }

    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        isVideo ? Icons.videocam_rounded : Icons.music_note_rounded,
        color: scheme.primary,
      ),
    );
  }
}

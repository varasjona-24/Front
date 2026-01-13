import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/models/media_item.dart';
import '../controller/audio_player_controller.dart';
import 'turntable_needle.dart';

class CoverArt extends StatelessWidget {
  final AudioPlayerController controller;
  final MediaItem item;

  const CoverArt({super.key, required this.controller, required this.item});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Obx(() {
      final isVinyl = controller.coverStyle.value == CoverStyle.vinyl;

      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: isVinyl
            ? _VinylCover(colors: colors, item: item)
            : _SquareCover(colors: colors, item: item),
      );
    });
  }
}

class _SquareCover extends StatelessWidget {
  final ColorScheme colors;
  final MediaItem item;

  const _SquareCover({required this.colors, required this.item});

  @override
  Widget build(BuildContext context) {
    final thumb = item.thumbnail;
    final hasThumb = thumb != null && thumb.isNotEmpty;

    return Container(
      key: const ValueKey('square'),
      width: 260,
      height: 260,
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: hasThumb
          ? Image.network(
              thumb,
              width: 260,
              height: 260,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Icon(
                Icons.music_note_rounded,
                size: 72,
                color: colors.onSurfaceVariant.withOpacity(0.7),
              ),
            )
          : Icon(
              Icons.music_note_rounded,
              size: 72,
              color: colors.onSurfaceVariant.withOpacity(0.7),
            ),
    );
  }
}

class _VinylCover extends StatefulWidget {
  final ColorScheme colors;
  final MediaItem item;

  const _VinylCover({required this.colors, required this.item});

  @override
  State<_VinylCover> createState() => _VinylCoverState();
}

class _VinylCoverState extends State<_VinylCover>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotationCtrl;
  late final AudioPlayerController controller;

  Worker? _playingWorker;

  @override
  void initState() {
    super.initState();

    controller = Get.find<AudioPlayerController>();

    _rotationCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    );

    _playingWorker = ever(controller.audioService.isPlaying, (_) {
      if (!mounted) return;
      _syncRotation();
    });

    _syncRotation();
  }

  void _syncRotation() {
    if (!mounted) return;

    final playing = controller.audioService.isPlaying.value;
    if (playing) {
      _rotationCtrl.repeat();
    } else {
      _rotationCtrl.stop();
    }
  }

  @override
  void dispose() {
    _playingWorker?.dispose();
    _rotationCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final thumb = widget.item.thumbnail;
    final hasThumb = thumb != null && thumb.isNotEmpty;

    const double diskSize = 280;
    const double labelSize = 215;

    return SizedBox(
      key: const ValueKey('vinyl'),
      width: diskSize,
      height: diskSize,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // 1) VINILO (NO rota)
          Transform.translate(
            offset: const Offset(0, 1), // 👈 bajadito para que se vea “debajo”
            child: Image.asset(
              'assets/ui/vinyl.png', // <-- tu png del disco
              width: diskSize,
              height: diskSize,
              fit: BoxFit.contain,
            ),
          ),

          // 2) LABEL / COVER (SÍ rota)
          ClipOval(
            child: SizedBox(
              width: labelSize,
              height: labelSize,
              child: RotationTransition(
                turns: _rotationCtrl,
                child: hasThumb
                    ? Image.network(
                        thumb,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Center(
                          child: Icon(
                            Icons.music_note_rounded,
                            size: 52,
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      )
                    : Center(
                        child: Icon(
                          Icons.music_note_rounded,
                          size: 52,
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
              ),
            ),
          ),

          // 3) AGUJA (siempre Positioned para no romper centrado)
          const Positioned(top: -16, right: 23, child: TurntableNeedle()),
        ],
      ),
    );
  }
}

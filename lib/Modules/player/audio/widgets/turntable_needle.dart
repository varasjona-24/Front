import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controller/audio_player_controller.dart';

class TurntableNeedle extends StatefulWidget {
  const TurntableNeedle({super.key});

  @override
  State<TurntableNeedle> createState() => _TurntableNeedleState();
}

class _TurntableNeedleState extends State<TurntableNeedle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _needleCtrl;
  late final Animation<double> _rotation;
  late final AudioPlayerController controller;

  Worker? _playingWorker; // ✅

  @override
  void initState() {
    super.initState();

    controller = Get.find<AudioPlayerController>();

    _needleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _rotation = Tween<double>(
      begin: -0.35,
      end: -0.05,
    ).animate(CurvedAnimation(parent: _needleCtrl, curve: Curves.easeOut));

    _playingWorker = ever(controller.audioService.isPlaying, (_) {
      if (!mounted) return;
      _syncNeedle();
    });

    _syncNeedle();
  }

  void _syncNeedle() {
    if (!mounted) return;

    final playing = controller.audioService.isPlaying.value;
    if (playing) {
      _needleCtrl.forward();
    } else {
      _needleCtrl.reverse();
    }
  }

  @override
  void dispose() {
    _playingWorker?.dispose(); // ✅ IMPORTANTÍSIMO
    _needleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: -20,
      right: 40,
      child: AnimatedBuilder(
        animation: _rotation,
        builder: (_, child) {
          return Transform.rotate(
            angle: _rotation.value,
            alignment: Alignment.topCenter,
            child: child,
          );
        },
        child: _NeedleBody(),
      ),
    );
  }
}

class _NeedleBody extends StatelessWidget {
  const _NeedleBody();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Base
        Container(
          width: 14,
          height: 14,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.grey,
          ),
        ),
        // Brazo
        Container(width: 4, height: 110, color: Colors.grey),
        // Punta
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black,
          ),
        ),
      ],
    );
  }
}

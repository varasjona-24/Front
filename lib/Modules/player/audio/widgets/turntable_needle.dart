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
    return AnimatedBuilder(
      animation: _rotation,
      builder: (_, child) {
        return Transform.rotate(
          angle: _rotation.value,
          alignment: Alignment.topCenter,
          child: child,
        );
      },
      child: const _NeedleBody(),
    );
  }
}

class _NeedleBody extends StatelessWidget {
  const _NeedleBody();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/ui/aguja.png',
      width: 49,
      height: 152,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, _, _) => const _NeedleVectorBody(),
    );
  }
}

class _NeedleVectorBody extends StatelessWidget {
  const _NeedleVectorBody();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 62,
      height: 152,
      child: Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          // Pivot superior
          Positioned(
            top: 0,
            child: Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFC8CFD9), Color(0xFF626A77)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x3F000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF2D3440),
                  ),
                ),
              ),
            ),
          ),

          // Brazo metalico
          Positioned(
            top: 14,
            child: Transform.rotate(
              angle: 0.04,
              child: Container(
                width: 9,
                height: 108,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFDCE2EB), Color(0xFF7A8493)],
                  ),
                  border: Border.all(
                    color: const Color(0x55222B35),
                    width: 0.8,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x30000000),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Brillo del brazo
          Positioned(
            top: 20,
            child: Transform.translate(
              offset: const Offset(1.4, 0),
              child: Container(
                width: 1.2,
                height: 92,
                color: const Color(0x66FFFFFF),
              ),
            ),
          ),

          // Capsula / cartucho
          Positioned(
            top: 112,
            child: Transform.rotate(
              angle: 0.12,
              child: Container(
                width: 22,
                height: 24,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF404853), Color(0xFF1E252E)],
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x2F000000),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Porta-aguja
          Positioned(
            top: 134,
            child: Transform.rotate(
              angle: 0.12,
              child: Container(
                width: 3,
                height: 13,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: const Color(0xFF596270),
                ),
              ),
            ),
          ),

          // Punta
          const Positioned(
            top: 145,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF101419),
              ),
              child: SizedBox(width: 4, height: 4),
            ),
          ),
        ],
      ),
    );
  }
}

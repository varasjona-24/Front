import 'dart:async';
import 'dart:math' as math;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/models/media_item.dart';
import '../../../../app/services/audio_visualizer_service.dart';
import '../../../../app/services/audio_waveform_service.dart';
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
      final style = controller.coverStyle.value;

      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: switch (style) {
          CoverStyle.square => _SquareCover(colors: colors, item: item),
          CoverStyle.vinyl => _VinylCover(colors: colors, item: item),
          CoverStyle.wave => _WaveCover(
            colors: colors,
            item: item,
            controller: controller,
          ),
        },
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
    final thumb = item.effectiveThumbnail ?? '';
    final hasThumb = thumb.isNotEmpty;
    final isLocal = hasThumb && thumb.startsWith('/');

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
          ? (isLocal
                ? Image.file(
                    File(thumb),
                    width: 260,
                    height: 260,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.music_note_rounded,
                      size: 72,
                      color: colors.onSurfaceVariant.withOpacity(0.7),
                    ),
                  )
                : Image.network(
                    thumb,
                    width: 260,
                    height: 260,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.music_note_rounded,
                      size: 72,
                      color: colors.onSurfaceVariant.withOpacity(0.7),
                    ),
                  ))
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
    final thumb = widget.item.effectiveThumbnail ?? '';
    final hasThumb = thumb.isNotEmpty;
    final isLocal = hasThumb && thumb.startsWith('/');

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
                    ? (isLocal
                          ? Image.file(
                              File(thumb),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Center(
                                child: Icon(
                                  Icons.music_note_rounded,
                                  size: 52,
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.6),
                                ),
                              ),
                            )
                          : Image.network(
                              thumb,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Center(
                                child: Icon(
                                  Icons.music_note_rounded,
                                  size: 52,
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.6),
                                ),
                              ),
                            ))
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

class _WaveCover extends StatefulWidget {
  final ColorScheme colors;
  final MediaItem item;
  final AudioPlayerController controller;

  const _WaveCover({
    required this.colors,
    required this.item,
    required this.controller,
  });

  @override
  State<_WaveCover> createState() => _WaveCoverState();
}

class _WaveCoverState extends State<_WaveCover>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationCtrl;
  late final List<double> _fallbackHeights;
  late List<double> _baseHeights;
  List<double> _liveBars = const [];
  late final AudioVisualizerService? _visualizerService;
  late final AudioWaveformService? _waveformService;
  StreamSubscription<int?>? _sessionIdSub;
  StreamSubscription<List<double>>? _liveBarsSub;
  int? _attachedSessionId;
  Worker? _playingWorker;

  @override
  void initState() {
    super.initState();
    _fallbackHeights = _buildBaseHeights(widget.item);
    _baseHeights = _fallbackHeights;
    _visualizerService = Get.isRegistered<AudioVisualizerService>()
        ? Get.find<AudioVisualizerService>()
        : null;
    _waveformService = Get.isRegistered<AudioWaveformService>()
        ? Get.find<AudioWaveformService>()
        : null;
    _animationCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _playingWorker = ever(widget.controller.audioService.isPlaying, (_) {
      _syncAnimation();
    });
    _syncAnimation();
    _loadRealWaveform();
    _bindRealtimeVisualizer();
  }

  void _syncAnimation() {
    final playing = widget.controller.audioService.isPlaying.value;
    if (playing) {
      if (!_animationCtrl.isAnimating) _animationCtrl.repeat();
    } else {
      _animationCtrl.stop();
    }
  }

  @override
  void dispose() {
    _playingWorker?.dispose();
    _sessionIdSub?.cancel();
    _liveBarsSub?.cancel();
    _visualizerService?.detach();
    _animationCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;

    return Obx(() {
      final positionMs = widget.controller.position.value.inMilliseconds;
      final totalDurationMs = widget.controller.duration.value.inMilliseconds;
      final playhead = totalDurationMs > 0
          ? (positionMs / totalDurationMs).clamp(0.0, 1.0)
          : 0.0;
      final isPlaying = widget.controller.audioService.isPlaying.value;

      return Container(
        key: ValueKey('wave-${widget.item.id}'),
        width: 280,
        height: 220,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colors.surfaceContainerHighest.withValues(alpha: 0.92),
              colors.surfaceContainerHigh.withValues(alpha: 0.88),
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: colors.outlineVariant.withValues(alpha: 0.58),
          ),
        ),
        child: AnimatedBuilder(
          animation: _animationCtrl,
          builder: (context, _) {
            final phase =
                (positionMs / 550.0) + (_animationCtrl.value * math.pi * 2);

            return CustomPaint(
              painter: _WaveformPainter(
                baseHeights: _baseHeights,
                liveBars: _liveBars,
                phase: phase,
                playhead: playhead,
                isPlaying: isPlaying,
                baseColor: colors.primary,
                idleColor: colors.onSurfaceVariant,
              ),
              child: const SizedBox.expand(),
            );
          },
        ),
      );
    });
  }

  void _bindRealtimeVisualizer() {
    final service = _visualizerService;
    if (service == null) return;

    _liveBarsSub = service.barsStream.listen((bars) {
      if (!mounted || bars.isEmpty) return;
      setState(() {
        _liveBars = bars;
      });
    });

    _sessionIdSub = widget.controller.audioService.androidAudioSessionIdStream
        .listen((sessionId) {
          _attachToSession(sessionId);
        });

    _attachToSession(widget.controller.audioService.androidAudioSessionId);
  }

  Future<void> _attachToSession(int? sessionId) async {
    final service = _visualizerService;
    if (service == null) return;
    final id = sessionId ?? 0;
    if (id <= 0 || _attachedSessionId == id) return;

    try {
      await service.attachToSession(id, barCount: 56);
      _attachedSessionId = id;
    } catch (_) {}
  }

  Future<void> _loadRealWaveform() async {
    final service = _waveformService;
    if (service == null) return;

    final localPath = widget.item.localAudioVariant?.localPath?.trim() ?? '';
    if (localPath.isEmpty) return;

    try {
      final data = await service.extractWaveform(
        localPath: localPath,
        buckets: 56,
      );
      if (!mounted || data == null || data.buckets.isEmpty) return;

      setState(() {
        _baseHeights = data.buckets;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _baseHeights = _fallbackHeights;
      });
    }
  }

  List<double> _buildBaseHeights(MediaItem item) {
    final seedSource = '${item.id}|${item.publicId}|${item.title}';
    var seed = seedSource.codeUnits.fold<int>(7, (acc, c) => (acc * 31 + c));
    seed &= 0x7fffffff;
    if (seed == 0) seed = 1;

    const count = 56;
    final raw = <double>[];

    double nextRandom() {
      seed = (1103515245 * seed + 12345) & 0x7fffffff;
      return seed / 0x7fffffff;
    }

    for (int i = 0; i < count; i++) {
      final center = (count - 1) / 2;
      final dist = ((i - center).abs() / center);
      final profile = (1.0 - dist * 0.55).clamp(0.35, 1.0).toDouble();
      final random = 0.22 + (nextRandom() * 0.78);
      raw.add((random * profile).clamp(0.14, 1.0).toDouble());
    }

    final smooth = List<double>.filled(count, 0);
    for (int i = 0; i < count; i++) {
      final prev = i > 0 ? raw[i - 1] : raw[i];
      final curr = raw[i];
      final next = i < count - 1 ? raw[i + 1] : raw[i];
      smooth[i] = ((prev + curr * 2 + next) / 4).clamp(0.14, 1.0).toDouble();
    }

    return smooth;
  }
}

class _WaveformPainter extends CustomPainter {
  final List<double> baseHeights;
  final List<double> liveBars;
  final double phase;
  final double playhead;
  final bool isPlaying;
  final Color baseColor;
  final Color idleColor;

  const _WaveformPainter({
    required this.baseHeights,
    required this.liveBars,
    required this.phase,
    required this.playhead,
    required this.isPlaying,
    required this.baseColor,
    required this.idleColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (baseHeights.isEmpty) return;

    final baseY = size.height - 4;
    final count = baseHeights.length;
    final spacing = count >= 64 ? 1.4 : 2.2;
    final barWidth = ((size.width - spacing * (count - 1)) / count)
        .clamp(1.2, 8.0)
        .toDouble();
    final maxHeight = (size.height * 0.76).clamp(18.0, 170.0).toDouble();

    var x = 0.0;
    final hasLive = liveBars.isNotEmpty;
    for (int i = 0; i < count; i++) {
      final barProgress = count > 1 ? i / (count - 1) : 0.0;
      final distanceToPlayhead = (barProgress - playhead).abs();
      final nearPlayheadBoost = (1.0 - distanceToPlayhead * 8.0)
          .clamp(0.0, 1.0)
          .toDouble();
      final liveValue = hasLive ? _sampleLiveBar(i, count) : baseHeights[i];
      final pulse = 0.45 + 0.55 * (0.5 + 0.5 * math.sin(phase + i * 0.43));
      final dynamicGain = hasLive
          ? (isPlaying ? (0.18 + liveValue * 0.94) : (0.14 + liveValue * 0.42))
          : (isPlaying ? (pulse * (1.0 + nearPlayheadBoost * 0.22)) : 0.34);
      final shape = hasLive
          ? ((baseHeights[i] * 0.22) + (liveValue * 0.78))
                .clamp(0.06, 1.0)
                .toDouble()
          : baseHeights[i];
      final barHeight = (maxHeight * shape * dynamicGain).clamp(6.0, maxHeight);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, baseY - barHeight, barWidth, barHeight),
        Radius.circular(barWidth * 0.7),
      );

      final hue = 22.0 + (barProgress * 200.0);
      final rainbow = HSLColor.fromAHSL(1.0, hue, 0.78, 0.56).toColor();
      final t = ((dynamicGain + liveValue) / 2.0).clamp(0.0, 1.0);
      final progressed = barProgress <= playhead;
      final barColor = Color.lerp(
        rainbow.withValues(alpha: progressed ? 0.52 : 0.26),
        rainbow.withValues(alpha: progressed ? 0.98 : 0.70),
        t,
      )!;

      canvas.drawRRect(rect, Paint()..color = barColor);
      x += barWidth + spacing;
    }
  }

  double _sampleLiveBar(int index, int targetCount) {
    if (liveBars.isEmpty || targetCount <= 1) return 0.0;
    if (liveBars.length == 1) return liveBars.first;
    if (targetCount == liveBars.length) {
      final safe = index.clamp(0, liveBars.length - 1);
      return liveBars[safe];
    }

    final sourceMax = liveBars.length - 1;
    final targetMax = targetCount - 1;
    final sourcePos = (index / targetMax) * sourceMax;
    final low = sourcePos.floor().clamp(0, sourceMax);
    final high = sourcePos.ceil().clamp(0, sourceMax);
    if (low == high) return liveBars[low];
    final t = (sourcePos - low).clamp(0.0, 1.0);
    return (liveBars[low] * (1.0 - t)) + (liveBars[high] * t);
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.phase != phase ||
        oldDelegate.playhead != playhead ||
        oldDelegate.isPlaying != isPlaying ||
        oldDelegate.baseColor != baseColor ||
        oldDelegate.idleColor != idleColor ||
        oldDelegate.liveBars != liveBars ||
        oldDelegate.baseHeights != baseHeights;
  }
}

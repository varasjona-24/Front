import 'dart:async';
import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';

import '../../../../app/models/media_item.dart';
import '../../../../app/services/audio_service.dart';

enum CoverStyle { square, vinyl }

enum RepeatMode { off, once, loop }

class AudioPlayerController extends GetxController {
  final AudioService audioService;

  final List<MediaItem> queue;
  final int initialIndex;

  final coverStyle = CoverStyle.square.obs;
  final repeatMode = RepeatMode.off.obs;

  final RxInt currentIndex = 0.obs;

  final Rx<Duration> position = Duration.zero.obs;
  final Rx<Duration> duration = Duration.zero.obs;

  // opciones extra
  final RxBool isShuffling = false.obs;
  // Historia de indices para shuffle (para poder volver atrás)
  final List<int> _shuffleHistory = [];
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration?>? _durSub;
  StreamSubscription<ProcessingState>? _procSub;
  bool _handlingCompleted = false;

  AudioPlayerController({
    required this.queue,
    required this.initialIndex,
    required this.audioService,
  });

  @override
  void onInit() {
    super.onInit();

    if (queue.isEmpty) {
      currentIndex.value = 0;
    } else {
      final safeIndex = initialIndex.clamp(0, queue.length - 1).toInt();
      currentIndex.value = safeIndex;
    }

    _posSub = audioService.positionStream.listen((p) {
      position.value = p;
    });

    _durSub = audioService.durationStream.listen((d) {
      duration.value = d ?? Duration.zero;
    });

    _procSub = audioService.processingStateStream.listen((state) async {
      if (state != ProcessingState.completed) return;

      // ✅ evita doble ejecución
      if (_handlingCompleted) return;
      _handlingCompleted = true;

      try {
        // 🔁 Loop infinito: just_audio lo maneja
        if (repeatMode.value == RepeatMode.loop) return;

        // 🔂 Repeat once: replay UNA vez y apagar el modo
        if (repeatMode.value == RepeatMode.once) {
          repeatMode.value = RepeatMode.off;
          await audioService.setLoopOff();
          await audioService.replay(); // ✅ seek(0) + play
          return;
        }

        // ▶️ Normal: siguiente
        if (currentIndex.value < queue.length - 1) {
          await next();
          return;
        }

        // final de cola
        await audioService.stop();
      } finally {
        await Future.delayed(const Duration(milliseconds: 200));
        _handlingCompleted = false;
      }
    });

    // Al entrar al player: si el item actual NO es el cargado, reproducir automáticamente.
    _ensurePlayingCurrent();
  }

  @override
  void onClose() {
    _procSub?.cancel();
    _posSub?.cancel();
    _durSub?.cancel();

    super.onClose();
  }

  Future<void> _ensurePlayingCurrent() async {
    final item = currentItemOrNull;
    final variant = currentAudio;
    if (item == null || variant == null) return;

    // Si la fuente cargada es la misma pista
    if (audioService.hasSourceLoaded &&
        audioService.isSameTrack(item, variant)) {
      // Reanuda si está en pausa
      if (!audioService.isPlaying.value) {
        await audioService.resume();
      }
      return;
    }

    // Si no es la misma pista, carga y reproduce la nueva
    await audioService.play(item, variant);
  }

  void toggleCoverStyle() {
    coverStyle.value = coverStyle.value == CoverStyle.square
        ? CoverStyle.vinyl
        : CoverStyle.square;
  }

  bool get hasQueue => queue.isNotEmpty;

  MediaItem? get currentItemOrNull {
    if (queue.isEmpty) return null;
    final i = currentIndex.value;
    if (i < 0 || i >= queue.length) return null;
    return queue[i];
  }

  MediaItem get currentItem {
    final item = currentItemOrNull;
    if (item == null) throw StateError('currentItem is null');
    return item;
  }

  MediaVariant? get currentAudio => currentItemOrNull?.audioVariant;

  bool get isPlaying => audioService.isPlaying.value;

  Future<void> togglePlay() async {
    final item = currentItemOrNull;
    final v = currentAudio;
    if (item == null || v == null) return;

    if (!audioService.hasSourceLoaded || !audioService.isSameTrack(item, v)) {
      await audioService.play(item, v);
      return;
    }

    await audioService.toggle();
  }

  Future<void> toggleRepeatOnce() async {
    final next = repeatMode.value == RepeatMode.once
        ? RepeatMode.off
        : RepeatMode.once;
    repeatMode.value = next;

    // 🔂 once siempre usa loop off
    await audioService.setLoopOff();
  }

  Future<void> toggleRepeatLoop() async {
    final next = repeatMode.value == RepeatMode.loop
        ? RepeatMode.off
        : RepeatMode.loop;
    repeatMode.value = next;

    if (next == RepeatMode.loop) {
      await audioService.setLoopOne(); // 🔁 infinito (LoopMode.one)
    } else {
      await audioService.setLoopOff();
    }
  }

  Future<void> next() async {
    if (!hasQueue) return;

    if (isShuffling.value && queue.length > 1) {
      // guarda en el historial la pista actual para permitir "previous" en shuffle
      _shuffleHistory.add(currentIndex.value);

      // Elige un índice pseudoaleatorio distinto del actual
      int nextIdx;
      final max = queue.length;
      do {
        nextIdx = DateTime.now().millisecondsSinceEpoch % max;
      } while (nextIdx == currentIndex.value && max > 1);

      currentIndex.value = nextIdx;
      await _playCurrent();
      return;
    }

    if (currentIndex.value < queue.length - 1) {
      currentIndex.value++;
      await _playCurrent();
    }
  }

  Future<void> previous() async {
    if (!hasQueue) return;

    if (isShuffling.value && _shuffleHistory.isNotEmpty) {
      final idx = _shuffleHistory.removeLast();
      currentIndex.value = idx;
      await _playCurrent();
      return;
    }

    if (currentIndex.value > 0) {
      currentIndex.value--;
      await _playCurrent();
    }
  }

  Future<void> toggleShuffle() async {
    final next = !isShuffling.value;
    isShuffling.value = next;
    if (next) {
      // start history with current
      _shuffleHistory.clear();
      _shuffleHistory.add(currentIndex.value);
    } else {
      // clear history on disable
      _shuffleHistory.clear();
    }
  }

  /// Play at an index (used by queue screen)
  Future<void> playAt(int index) async {
    if (index < 0 || index >= queue.length) return;
    if (isShuffling.value) {
      // guarda la anterior en el historial para poder volver
      _shuffleHistory.add(currentIndex.value);
      // limita tamaño por si acaso
      if (_shuffleHistory.length > 200) _shuffleHistory.removeAt(0);
    }

    currentIndex.value = index;
    await _playCurrent();
  }

  /// Reordena la cola (usado por la UI con drag & drop)
  Future<void> reorderQueue(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= queue.length) return;
    if (newIndex < 0 || newIndex > queue.length) return;

    // Flutter devuelve newIndex como la posición *después* de la extracción
    if (newIndex > oldIndex) newIndex -= 1;

    final item = queue.removeAt(oldIndex);
    queue.insert(newIndex, item);

    // Actualiza currentIndex
    if (currentIndex.value == oldIndex) {
      currentIndex.value = newIndex;
    } else if (oldIndex < newIndex) {
      if (currentIndex.value > oldIndex && currentIndex.value <= newIndex) {
        currentIndex.value -= 1;
      }
    } else if (oldIndex > newIndex) {
      if (currentIndex.value >= newIndex && currentIndex.value < oldIndex) {
        currentIndex.value += 1;
      }
    }

    // Ajusta historial de shuffle
    for (var i = 0; i < _shuffleHistory.length; i++) {
      final idx = _shuffleHistory[i];
      if (idx == oldIndex) {
        _shuffleHistory[i] = newIndex;
      } else if (oldIndex < newIndex) {
        if (idx > oldIndex && idx <= newIndex) _shuffleHistory[i] = idx - 1;
      } else if (oldIndex > newIndex) {
        if (idx >= newIndex && idx < oldIndex) _shuffleHistory[i] = idx + 1;
      }
    }
  }

  /// Cambia velocidad (cicla entre presets si no se pasa valor)
  Future<void> cyclePlaybackSpeed() async {
    final presets = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    final cur = audioService.speed.value;
    final idx = presets.indexWhere((p) => p == cur);
    final next = presets[(idx + 1) % presets.length];
    await audioService.setSpeed(next);
  }

  /// Salta +10s
  Future<void> skipForward10() async {
    final pos = position.value;
    final dur = duration.value;
    final target = pos + const Duration(seconds: 10);
    final clamped = target > dur ? dur : target;
    await seek(clamped);
  }

  /// Salta -10s
  Future<void> skipBackward10() async {
    final pos = position.value;
    final target = pos - const Duration(seconds: 10);
    final clamped = target.isNegative ? Duration.zero : target;
    await seek(clamped);
  }

  Future<void> seek(Duration value) async {
    await audioService.seek(value);
  }

  Future<void> _playCurrent() async {
    final item = currentItemOrNull;
    final variant = currentAudio;
    if (item == null || variant == null) return;

    // ✅ reset visual inmediato
    position.value = Duration.zero;
    duration.value = Duration.zero;

    await audioService.play(item, variant);
  }
}

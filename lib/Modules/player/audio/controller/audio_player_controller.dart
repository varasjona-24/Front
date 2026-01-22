import 'dart:async';
import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';

import '../../../../app/models/media_item.dart';
import '../../../../app/services/audio_service.dart';
import '../../../../app/data/local/local_library_store.dart';

enum CoverStyle { square, vinyl }

enum RepeatMode { off, once, loop }

class AudioPlayerController extends GetxController {
  final AudioService audioService;
  final LocalLibraryStore _store = Get.find<LocalLibraryStore>();

  /// Cola reactiva (para que el UI se actualice bien)
  final RxList<MediaItem> queue = <MediaItem>[].obs;

  /// Index actual
  final RxInt currentIndex = 0.obs;

  final coverStyle = CoverStyle.square.obs;
  final repeatMode = RepeatMode.off.obs;

  final Rx<Duration> position = Duration.zero.obs;
  final Rx<Duration> duration = Duration.zero.obs;

  final RxBool isShuffling = false.obs;
  final List<int> _shuffleHistory = [];

  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration?>? _durSub;
  StreamSubscription<ProcessingState>? _procSub;

  bool _handlingCompleted = false;

  AudioPlayerController({required this.audioService});

  @override
  void onInit() {
    super.onInit();

    _readArgs();

    _posSub = audioService.positionStream.listen((p) {
      position.value = p;
    });

    _durSub = audioService.durationStream.listen((d) {
      duration.value = d ?? Duration.zero;
    });

    _procSub = audioService.processingStateStream.listen((state) async {
      if (state != ProcessingState.completed) return;

      if (_handlingCompleted) return;
      _handlingCompleted = true;

      try {
        // 🔁 Loop infinito: just_audio lo maneja
        if (repeatMode.value == RepeatMode.loop) return;

        // 🔂 Repeat once: replay UNA vez y apagar el modo
        if (repeatMode.value == RepeatMode.once) {
          repeatMode.value = RepeatMode.off;
          await audioService.setLoopOff();
          await audioService.replay();
          return;
        }

        // ▶️ Normal: siguiente
        if (currentIndex.value < queue.length - 1) {
          await next();
          return;
        }

        await audioService.stop();
      } finally {
        await Future.delayed(const Duration(milliseconds: 200));
        _handlingCompleted = false;
      }
    });

    _ensurePlayingCurrent();
  }

  void _readArgs() {
    final args = Get.arguments;

    if (args is Map) {
      final rawQueue = args['queue'];
      final rawIndex = args['index'];

      if (rawQueue is List<MediaItem>) {
        queue.assignAll(rawQueue);
      } else if (rawQueue is List) {
        // por si viene List<dynamic>
        queue.assignAll(rawQueue.whereType<MediaItem>().toList());
      }

      final idx = (rawIndex is int) ? rawIndex : 0;
      if (queue.isEmpty) {
        currentIndex.value = 0;
      } else {
        currentIndex.value = idx.clamp(0, queue.length - 1).toInt();
      }

      return;
    }

    // fallback: vacío
    queue.clear();
    currentIndex.value = 0;
  }

  @override
  void onClose() {
    _procSub?.cancel();
    _posSub?.cancel();
    _durSub?.cancel();
    super.onClose();
  }

  // ===========================================================================
  // STATE / GETTERS
  // ===========================================================================

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

  /// ✅ “peluche”: siempre intenta conseguir una variante reproducible.
  /// Prioridad:
  /// 1) audio local (debe tener localPath válido)
  /// 2) cualquier audio válido (remoto o no)
  /// 3) si no hay audio válido, null
  MediaVariant? get currentAudioVariant {
    final item = currentItemOrNull;
    if (item == null) return null;

    // 1️⃣ Buscar audio local con localPath válido
    final localAudio = item.variants.firstWhereOrNull(
      (v) =>
          v.kind == MediaVariantKind.audio &&
          v.localPath != null &&
          v.localPath!.trim().isNotEmpty &&
          v.isValid,
    );
    if (localAudio != null) return localAudio;

    // 2️⃣ Buscar cualquier audio válido (local o remoto)
    final anyAudio = item.variants.firstWhereOrNull(
      (v) => v.kind == MediaVariantKind.audio && v.isValid,
    );
    return anyAudio;
  }

  bool get isPlaying => audioService.isPlaying.value;

  // ===========================================================================
  // PLAYBACK
  // ===========================================================================

  Future<void> _ensurePlayingCurrent() async {
    final item = currentItemOrNull;
    final variant = currentAudioVariant;
    if (item == null || variant == null) return;

    // Si la fuente cargada es la misma pista
    if (audioService.hasSourceLoaded &&
        audioService.isSameTrack(item, variant)) {
      if (!audioService.isPlaying.value) {
        await audioService.resume();
      }
      return;
    }

    await _playItem(item, variant);
  }

  Future<void> togglePlay() async {
    final item = currentItemOrNull;
    final v = currentAudioVariant;
    if (item == null || v == null) return;

    if (!audioService.hasSourceLoaded || !audioService.isSameTrack(item, v)) {
      await _playItem(item, v);
      return;
    }

    await audioService.toggle();
  }

  Future<void> _playItem(MediaItem item, MediaVariant variant) async {
    // ✅ reset visual inmediato
    position.value = Duration.zero;
    duration.value = Duration.zero;

    // ✅ Validar que tenemos una variante reproducible
    if (!variant.isValid) {
      print('❌ Cannot play: variant is not valid');
      throw Exception('Variante no válida para reproducción');
    }

    try {
      print('▶️ Playing: ${item.title} (${variant.kind}/${variant.format})');
      await audioService.play(item, variant);
      await _trackPlay(item);
    } catch (e) {
      print('❌ Error in _playItem: $e');
      position.value = Duration.zero;
      duration.value = Duration.zero;
      rethrow;
    }
  }

  Future<void> _trackPlay(MediaItem item) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final all = await _store.readAll();

    MediaItem updated = item.copyWith(
      playCount: item.playCount + 1,
      lastPlayedAt: now,
    );

    for (final existing in all) {
      if (existing.id == item.id ||
          (item.publicId.isNotEmpty &&
              existing.publicId == item.publicId)) {
        updated = existing.copyWith(
          playCount: existing.playCount + 1,
          lastPlayedAt: now,
        );
        break;
      }
    }

    await _store.upsert(updated);
  }

  // ===========================================================================
  // REPEAT
  // ===========================================================================

  Future<void> toggleRepeatOnce() async {
    final next = repeatMode.value == RepeatMode.once
        ? RepeatMode.off
        : RepeatMode.once;
    repeatMode.value = next;

    await audioService.setLoopOff();
  }

  Future<void> toggleRepeatLoop() async {
    final next = repeatMode.value == RepeatMode.loop
        ? RepeatMode.off
        : RepeatMode.loop;
    repeatMode.value = next;

    if (next == RepeatMode.loop) {
      await audioService.setLoopOne();
    } else {
      await audioService.setLoopOff();
    }
  }

  // ===========================================================================
  // NEXT / PREVIOUS / SHUFFLE
  // ===========================================================================

  Future<void> reorderQueue(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= queue.length) return;
    if (newIndex < 0 || newIndex > queue.length) return;

    if (newIndex > oldIndex) newIndex -= 1;

    final item = queue.removeAt(oldIndex);
    queue.insert(newIndex, item);

    // Ajusta currentIndex
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

    // Ajusta historial shuffle
    for (var i = 0; i < _shuffleHistory.length; i++) {
      final idx = _shuffleHistory[i];
      if (idx == oldIndex) {
        _shuffleHistory[i] = newIndex;
      } else if (oldIndex < newIndex) {
        if (idx > oldIndex && idx <= newIndex) _shuffleHistory[i] = idx - 1;
      } else {
        if (idx >= newIndex && idx < oldIndex) _shuffleHistory[i] = idx + 1;
      }
    }
  }

  Future<void> next() async {
    if (!hasQueue) return;

    if (isShuffling.value && queue.length > 1) {
      _shuffleHistory.add(currentIndex.value);

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
      _shuffleHistory.clear();
      _shuffleHistory.add(currentIndex.value);
    } else {
      _shuffleHistory.clear();
    }
  }

  Future<void> playAt(int index) async {
    if (index < 0 || index >= queue.length) return;

    if (isShuffling.value) {
      _shuffleHistory.add(currentIndex.value);
      if (_shuffleHistory.length > 200) _shuffleHistory.removeAt(0);
    }

    currentIndex.value = index;
    await _playCurrent();
  }

  Future<void> _playCurrent() async {
    final item = currentItemOrNull;
    final variant = currentAudioVariant;
    if (item == null || variant == null) return;

    await _playItem(item, variant);
  }

  // ===========================================================================
  // SEEK / SPEED
  // ===========================================================================

  Future<void> cyclePlaybackSpeed() async {
    final presets = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    final cur = audioService.speed.value;
    final idx = presets.indexWhere((p) => p == cur);
    final next = presets[(idx + 1) % presets.length];
    await audioService.setSpeed(next);
  }

  Future<void> skipForward10() async {
    final pos = position.value;
    final dur = duration.value;
    final target = pos + const Duration(seconds: 10);
    final clamped = target > dur ? dur : target;
    await seek(clamped);
  }

  Future<void> skipBackward10() async {
    final pos = position.value;
    final target = pos - const Duration(seconds: 10);
    final clamped = target.isNegative ? Duration.zero : target;
    await seek(clamped);
  }

  Future<void> seek(Duration value) async {
    await audioService.seek(value);
  }
}

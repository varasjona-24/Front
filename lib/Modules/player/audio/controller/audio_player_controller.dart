import 'dart:async';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:just_audio/just_audio.dart';

import '../../../../app/models/media_item.dart';
import '../../../../app/services/audio_service.dart';
import '../../../../app/data/local/local_library_store.dart';
import '../../../settings/controller/settings_controller.dart';

enum CoverStyle { square, vinyl }

enum RepeatMode { off, once, loop }

class AudioPlayerController extends GetxController {
  final AudioService audioService;
  final LocalLibraryStore _store = Get.find<LocalLibraryStore>();
  final SettingsController _settings = Get.find<SettingsController>();
  final GetStorage _storage = GetStorage();

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
  bool _hydratedFromStorage = false;

  static const _queueKey = 'audio_queue_items';
  static const _queueIndexKey = 'audio_queue_index';
  static const _resumePosKey = 'audio_resume_positions';
  static const _shuffleKey = 'audio_shuffle_on';
  static const _shuffleHistoryKey = 'audio_shuffle_history';

  AudioPlayerController({required this.audioService});

  @override
  void onInit() {
    super.onInit();

    final hasArgs = _readArgs();
    if (!hasArgs) {
      _restoreQueue();
    }
    _loadShuffleState();
    _loadCoverStyle();

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

        if (!_settings.autoPlayNext.value) {
          await audioService.stop();
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

    ever<List<MediaItem>>(queue, (_) => _persistQueue());
    ever<int>(currentIndex, (_) => _persistQueue());
    debounce<Duration>(
      position,
      (p) => _persistPosition(p),
      time: const Duration(seconds: 2),
    );

    _ensurePlayingCurrent();
  }

  bool _readArgs() {
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

      _persistQueue();
      return true;
    }

    // fallback: vacío
    queue.clear();
    currentIndex.value = 0;
    return false;
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
    _storage.write('playerCoverStyle', coverStyle.value.name);
  }

  void _loadCoverStyle() {
    final raw = _storage.read('playerCoverStyle') as String?;
    if (raw == CoverStyle.vinyl.name) {
      coverStyle.value = CoverStyle.vinyl;
    } else {
      coverStyle.value = CoverStyle.square;
    }
  }

  void _restoreQueue() {
    if (_hydratedFromStorage) return;
    _hydratedFromStorage = true;

    final raw = _storage.read<List>(_queueKey);
    if (raw == null || raw.isEmpty) return;

    final items = raw
        .whereType<Map>()
        .map((m) => MediaItem.fromJson(Map<String, dynamic>.from(m)))
        .toList();
    if (items.isEmpty) return;

    queue.assignAll(items);
    final idx = _storage.read(_queueIndexKey);
    if (idx is int && idx >= 0 && idx < queue.length) {
      currentIndex.value = idx;
    } else {
      currentIndex.value = 0;
    }
  }

  void _loadShuffleState() {
    final on = _storage.read(_shuffleKey);
    if (on is bool) {
      isShuffling.value = on;
    }

    final rawHistory = _storage.read<List>(_shuffleHistoryKey);
    if (rawHistory != null) {
      _shuffleHistory
        ..clear()
        ..addAll(
          rawHistory
              .whereType<num>()
              .map((e) => e.toInt())
              .where((i) => i >= 0 && i < queue.length),
        );
    }
  }

  void _persistShuffleState() {
    _storage.write(_shuffleKey, isShuffling.value);
    _storage.write(_shuffleHistoryKey, List<int>.from(_shuffleHistory));
  }

  void _persistQueue() {
    if (queue.isEmpty) return;
    _storage.write(_queueKey, queue.map((e) => e.toJson()).toList());
    _storage.write(_queueIndexKey, currentIndex.value);
  }

  void _persistPosition(Duration p) {
    final item = currentItemOrNull;
    if (item == null) return;
    final key = item.publicId.isNotEmpty ? item.publicId : item.id;
    if (key.trim().isEmpty) return;

    final map = _storage.read<Map>(_resumePosKey);
    final next = <String, dynamic>{};
    if (map != null) {
      for (final entry in map.entries) {
        next[entry.key.toString()] = entry.value;
      }
    }

    final ms = p.inMilliseconds;
    if (ms <= 1000) {
      next.remove(key);
    } else {
      next[key] = ms;
    }
    _storage.write(_resumePosKey, next);
  }

  Future<void> _resumeIfAny(MediaItem item) async {
    final key = item.publicId.isNotEmpty ? item.publicId : item.id;
    final map = _storage.read<Map>(_resumePosKey);
    if (map == null) return;
    final raw = map[key];
    if (raw is! int) return;
    if (raw < 1500) return;

    try {
      final d = await audioService.durationStream
          .firstWhere((d) => d != null && d > Duration.zero)
          .timeout(const Duration(seconds: 2));
      final dur = d ?? Duration.zero;
      final resume = Duration(milliseconds: raw);
      if (resume < dur - const Duration(seconds: 2)) {
        await audioService.seek(resume);
      }
    } catch (_) {
      // ignore resume failures
    }
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

  void addToQueue(List<MediaItem> items) {
    if (items.isEmpty) return;
    queue.addAll(items);
  }

  void insertNext(List<MediaItem> items) {
    if (items.isEmpty) return;
    final insertAt = (currentIndex.value + 1).clamp(0, queue.length);
    queue.insertAll(insertAt, items);
  }

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
      await _resumeIfAny(item);
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
    if (isShuffling.value) {
      _persistShuffleState();
    }
  }

  Future<void> next() async {
    if (!hasQueue) return;

    if (isShuffling.value && queue.length > 1) {
      _shuffleHistory.add(currentIndex.value);
      _persistShuffleState();

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
      _persistShuffleState();
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
    _persistShuffleState();
  }

  Future<void> playAt(int index) async {
    if (index < 0 || index >= queue.length) return;

    if (isShuffling.value) {
      _shuffleHistory.add(currentIndex.value);
      if (_shuffleHistory.length > 200) _shuffleHistory.removeAt(0);
      _persistShuffleState();
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

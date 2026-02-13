import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:just_audio/just_audio.dart';

import '../../../../app/models/media_item.dart';
import '../../../../app/services/audio_service.dart';
import '../../../../app/services/spatial_audio_service.dart';
import '../../../../app/data/local/local_library_store.dart';
import '../../../settings/controller/settings_controller.dart';

enum CoverStyle { square, vinyl }

enum RepeatMode { off, once, loop }

class AudioPlayerController extends GetxController {
  final AudioService audioService;
  final SpatialAudioService _spatial = Get.find<SpatialAudioService>();
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
  final List<MediaItem> _originalQueueOrder = [];
  bool _shuffleApplied = false;
  final Random _rng = Random.secure();

  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration?>? _durSub;
  StreamSubscription<ProcessingState>? _procSub;

  bool _handlingCompleted = false;
  bool _hydratedFromStorage = false;
  String? _lastArgsSignature;
  Future<void>? _activePlaybackTask;

  static const _queueKey = 'audio_queue_items';
  static const _queueIndexKey = 'audio_queue_index';
  static const _resumePosKey = 'audio_resume_positions';
  static const _shuffleKey = 'audio_shuffle_on';
  static const _repeatModeKey = 'audio_repeat_mode';

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
    _loadRepeatMode();
    _cleanup8dVariants();
    if (isShuffling.value) {
      _applyShuffleOrder();
    }

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

    ever<MediaItem?>(audioService.currentItem, (item) {
      if (item == null) return;
      final idx = queue.indexWhere((e) {
        if (e.id == item.id) return true;
        final pid = item.publicId.trim();
        return pid.isNotEmpty && e.publicId.trim() == pid;
      });
      if (idx >= 0) {
        if (idx != currentIndex.value) {
          currentIndex.value = idx;
        }
        return;
      }

      // Si no está en la cola local, intenta resync desde AudioService.
      final serviceQueue = audioService.queueItems;
      if (serviceQueue.isEmpty) return;

      final serviceIdx = serviceQueue.indexWhere((e) {
        if (e.id == item.id) return true;
        final pid = item.publicId.trim();
        return pid.isNotEmpty && e.publicId.trim() == pid;
      });
      if (serviceIdx < 0) return;

      _resetShuffleBookkeeping();
      queue.assignAll(serviceQueue);
      currentIndex.value = serviceIdx;
    });

    ever<List<MediaItem>>(queue, (_) => _persistQueue());
    ever<int>(currentIndex, (_) => _persistQueue());
    debounce<Duration>(
      position,
      (p) => _persistPosition(p),
      time: const Duration(seconds: 2),
    );

    _ensurePlayingCurrent().catchError((_) {});
  }

  Future<void> _cleanup8dVariants() async {
    try {
      final items = await _store.readAll();
      for (final item in items) {
        final variants = item.variants;
        if (variants.isEmpty) continue;
        final toRemove = variants.where(_is8dVariant).toList();
        if (toRemove.isEmpty) continue;

        for (final v in toRemove) {
          final path = v.localPath?.trim();
          if (path != null && path.isNotEmpty) {
            final f = File(path);
            if (await f.exists()) {
              await f.delete();
            }
          }
        }

        final kept = variants.where((v) => !_is8dVariant(v)).toList();
        final updated = item.copyWith(variants: kept);
        await _store.upsert(updated);

        final idx = queue.indexWhere((e) => e.id == item.id);
        if (idx >= 0) {
          queue[idx] = updated;
        }
      }
    } catch (_) {}
  }

  bool _is8dVariant(MediaVariant v) {
    final name = v.fileName.toLowerCase();
    final path = v.localPath?.toLowerCase() ?? '';
    return name.contains('_8d') ||
        path.contains('/converted/') ||
        path.contains('_8d.');
  }

  bool _readArgs() {
    final args = Get.arguments;

    if (args is Map) {
      final rawQueue = args['queue'];
      final rawIndex = args['index'];

      List<MediaItem> incoming = [];
      if (rawQueue is List<MediaItem>) {
        incoming = rawQueue;
      } else if (rawQueue is List) {
        // por si viene List<dynamic>
        incoming = rawQueue.whereType<MediaItem>().toList();
      }

      // Si no hay cola en los argumentos, dejamos que se restaure desde storage.
      if (incoming.isEmpty) {
        return false;
      }

      _resetShuffleBookkeeping();
      queue.assignAll(incoming);

      final idx = (rawIndex is int) ? rawIndex : 0;
      if (queue.isEmpty) {
        currentIndex.value = 0;
      } else {
        currentIndex.value = idx.clamp(0, queue.length - 1).toInt();
      }

      _persistQueue();
      return true;
    }

    return false;
  }

  void applyRouteArgs(dynamic args) {
    if (args is! Map) return;

    final rawQueue = args['queue'];
    final rawIndex = args['index'];

    List<MediaItem> incoming = [];
    if (rawQueue is List<MediaItem>) {
      incoming = rawQueue;
    } else if (rawQueue is List) {
      incoming = rawQueue.whereType<MediaItem>().toList();
    }
    if (incoming.isEmpty) return;

    final idx = (rawIndex is int) ? rawIndex : 0;
    final safeIndex = idx.clamp(0, incoming.length - 1).toInt();
    final signature =
        '${incoming.length}:${safeIndex}:${incoming.map((e) => e.id).join(",")}';
    if (_lastArgsSignature == signature) return;
    _lastArgsSignature = signature;

    _resetShuffleBookkeeping();
    queue.assignAll(incoming);
    currentIndex.value = safeIndex;
    _hydratedFromStorage = true;
    _persistQueue();

    if (isShuffling.value) {
      _applyShuffleOrder();
    }

    _ensurePlayingCurrent();
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
  Rx<SpatialAudioMode> get spatialMode => _spatial.mode;

  Future<void> setSpatialMode(SpatialAudioMode mode) async {
    final ok = await _spatial.setMode(mode);
    if (!ok) {
      const msg = 'El efecto envolvente no está disponible en este dispositivo.';
      Get.snackbar(
        'Audio',
        msg,
        snackPosition: SnackPosition.BOTTOM,
      );
      await _spatial.setMode(SpatialAudioMode.off);
    }
  }

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

    _resetShuffleBookkeeping();
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
  }

  void _persistShuffleState() {
    _storage.write(_shuffleKey, isShuffling.value);
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

  Duration? _getResumePosition(MediaItem item) {
    final key = item.publicId.isNotEmpty ? item.publicId : item.id;
    final map = _storage.read<Map>(_resumePosKey);
    if (map == null) return null;
    final raw = map[key];
    if (raw is! int) return null;
    if (raw < 1500) return null;
    return Duration(milliseconds: raw);
  }

  Future<bool> _shouldResume(MediaItem item, Duration resume) async {
    final ctx = Get.context;
    if (ctx == null) return true;
    final mins = resume.inMinutes;
    final secs = (resume.inSeconds % 60).toString().padLeft(2, '0');
    final timeLabel = '$mins:$secs';
    final result = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Reanudar reproducción'),
        content: Text(
          '¿Quieres continuar "${item.title}" desde $timeLabel o iniciar desde el comienzo?',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Desde inicio'),
          ),
          FilledButton(
            onPressed: () => Get.back(result: true),
            child: const Text('Continuar'),
          ),
        ],
      ),
      barrierDismissible: false,
    );
    return result ?? true;
  }

  void _clearResumeForKey(String key) {
    final map = _storage.read<Map>(_resumePosKey);
    if (map == null) return;
    final next = <String, dynamic>{};
    for (final entry in map.entries) {
      if (entry.key.toString() == key) continue;
      next[entry.key.toString()] = entry.value;
    }
    _storage.write(_resumePosKey, next);
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

    try {
      await _playItem(item, variant);
    } catch (e) {
      // Evita propagar interrupciones transitorias en arranque/race conditions.
      final msg = e.toString().toLowerCase();
      if (msg.contains('loading interrupted')) return;
      rethrow;
    }
  }

  Future<void> togglePlay() async {
    _touchActivity();
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
    await _enqueuePlayback(() async {
      _touchActivity();
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
        final resume = _getResumePosition(item);
        final needsPrompt = resume != null;
        await audioService.play(
          item,
          variant,
          autoPlay: !needsPrompt,
          queue: queue.toList(),
          queueIndex: currentIndex.value,
        );
        if (resume != null) {
          final shouldResume = await _shouldResume(item, resume);
          if (!shouldResume) {
            final key = item.publicId.isNotEmpty ? item.publicId : item.id;
            _clearResumeForKey(key);
            await audioService.seek(Duration.zero);
          } else {
            final d = await audioService.durationStream
                .firstWhere((d) => d != null && d > Duration.zero)
                .timeout(const Duration(seconds: 2));
            final dur = d ?? Duration.zero;
            if (resume < dur - const Duration(seconds: 2)) {
              await audioService.seek(resume);
            }
          }
          await audioService.resume();
          _touchActivity();
        }
        await _trackPlay(item);
      } catch (e) {
        print('❌ Error in _playItem: $e');
        position.value = Duration.zero;
        duration.value = Duration.zero;
        rethrow;
      }
    });
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
    _storage.write(_repeatModeKey, next.name);

    await audioService.setLoopOff();
  }

  Future<void> toggleRepeatLoop() async {
    final next = repeatMode.value == RepeatMode.loop
        ? RepeatMode.off
        : RepeatMode.loop;
    repeatMode.value = next;
    _storage.write(_repeatModeKey, next.name);

    if (next == RepeatMode.loop) {
      await audioService.setLoopOne();
    } else {
      await audioService.setLoopOff();
    }
  }

  void _loadRepeatMode() {
    final raw = _storage.read(_repeatModeKey) as String?;
    if (raw == RepeatMode.once.name) {
      repeatMode.value = RepeatMode.once;
    } else if (raw == RepeatMode.loop.name) {
      repeatMode.value = RepeatMode.loop;
    } else {
      repeatMode.value = RepeatMode.off;
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

    if (isShuffling.value) {
      _persistShuffleState();
    }
  }

  Future<void> next() async {
    _touchActivity();
    if (!hasQueue) return;

    if (currentIndex.value < queue.length - 1) {
      currentIndex.value++;
      await _playCurrent();
    }
  }

  Future<void> previous() async {
    _touchActivity();
    if (!hasQueue) return;

    if (currentIndex.value > 0) {
      currentIndex.value--;
      await _playCurrent();
    }
  }

  Future<void> toggleShuffle() async {
    final next = !isShuffling.value;
    isShuffling.value = next;

    if (next) {
      _applyShuffleOrder();
    } else {
      _restoreOriginalOrder();
    }
    await _rebuildPlaybackQueuePreservingState();
    _persistShuffleState();
  }

  Future<void> playAt(int index) async {
    _touchActivity();
    if (index < 0 || index >= queue.length) return;

    currentIndex.value = index;
    await _playCurrent();
  }

  void _applyShuffleOrder() {
    if (queue.length <= 1) return;
    if (!_shuffleApplied) {
      _originalQueueOrder
        ..clear()
        ..addAll(queue);
    }

    final current = currentItemOrNull;
    final rest = queue
        .where((e) => current == null || e.id != current.id)
        .toList();

    if (rest.length > 1) {
      final originalRestOrder = List<MediaItem>.from(rest);
      var attempts = 0;
      do {
        rest.shuffle(_rng);
        attempts++;
      } while (attempts < 5 && _sameOrder(rest, originalRestOrder));
    }

    if (current != null) {
      queue.assignAll([current, ...rest]);
      currentIndex.value = 0;
    } else {
      queue.assignAll(rest);
      currentIndex.value = 0;
    }

    _shuffleApplied = true;
    _persistQueue();
  }

  bool _sameOrder(List<MediaItem> a, List<MediaItem> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  void _restoreOriginalOrder() {
    if (!_shuffleApplied || _originalQueueOrder.isEmpty) return;
    final current = currentItemOrNull;
    queue.assignAll(_originalQueueOrder);
    if (current != null) {
      final idx = queue.indexWhere((e) => e.id == current.id);
      currentIndex.value = idx >= 0 ? idx : 0;
    } else {
      currentIndex.value = 0;
    }
    _shuffleApplied = false;
    _persistQueue();
  }

  void _resetShuffleBookkeeping() {
    _shuffleApplied = false;
    _originalQueueOrder.clear();
  }

  Future<void> _rebuildPlaybackQueuePreservingState() async {
    final item = currentItemOrNull;
    final variant = currentAudioVariant;
    if (item == null || variant == null) return;

    final shouldResume = audioService.isPlaying.value;
    final currentPos = audioService.player.position;

    await _enqueuePlayback(() async {
      try {
        await audioService.play(
          item,
          variant,
          autoPlay: false,
          queue: queue.toList(),
          queueIndex: currentIndex.value,
          forceReload: true,
        );

        if (currentPos > Duration.zero) {
          await audioService.seek(currentPos);
        }

        if (shouldResume) {
          await audioService.resume();
        }
      } catch (_) {
        // No interrumpimos la UI si falla el rebuild de la cola.
      }
    });
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
    _touchActivity();
    final presets = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    final cur = audioService.speed.value;
    final idx = presets.indexWhere((p) => p == cur);
    final next = presets[(idx + 1) % presets.length];
    await audioService.setSpeed(next);
  }

  Future<void> skipForward10() async {
    _touchActivity();
    final pos = position.value;
    final dur = duration.value;
    final target = pos + const Duration(seconds: 10);
    final clamped = target > dur ? dur : target;
    await seek(clamped);
  }

  Future<void> skipBackward10() async {
    _touchActivity();
    final pos = position.value;
    final target = pos - const Duration(seconds: 10);
    final clamped = target.isNegative ? Duration.zero : target;
    await seek(clamped);
  }

  Future<void> seek(Duration value) async {
    _touchActivity();
    await audioService.seek(value);
  }

  Future<void> _enqueuePlayback(Future<void> Function() action) async {
    final previous = _activePlaybackTask;

    final task = () async {
      if (previous != null) {
        try {
          await previous;
        } catch (_) {}
      }
      await action();
    }();

    _activePlaybackTask = task;
    try {
      await task;
    } finally {
      if (identical(_activePlaybackTask, task)) {
        _activePlaybackTask = null;
      }
    }
  }

  void _touchActivity() {
    _settings.notifyPlaybackActivity();
  }
}

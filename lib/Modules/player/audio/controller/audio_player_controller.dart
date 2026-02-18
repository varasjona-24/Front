import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:just_audio/just_audio.dart';

import '../../../../app/data/local/local_library_store.dart';
import '../../../../app/models/media_item.dart';
import '../../../../app/services/audio_service.dart';
import '../../../../app/services/spatial_audio_service.dart';
import '../../../settings/controller/settings_controller.dart';

enum CoverStyle { square, vinyl }

enum RepeatMode { off, once, loop }

class AudioPlayerController extends GetxController {
  final AudioService audioService;
  final SpatialAudioService _spatial = Get.find<SpatialAudioService>();
  final LocalLibraryStore _store = Get.find<LocalLibraryStore>();
  final SettingsController _settings = Get.find<SettingsController>();
  final GetStorage _storage = GetStorage();

  AudioPlayerController({required this.audioService});

  final RxList<MediaItem> queue = <MediaItem>[].obs;
  final RxInt currentIndex = 0.obs;

  final Rx<CoverStyle> coverStyle = CoverStyle.square.obs;
  final Rx<RepeatMode> repeatMode = RepeatMode.off.obs;

  final Rx<Duration> position = Duration.zero.obs;
  final Rx<Duration> duration = Duration.zero.obs;

  final RxBool isShuffling = false.obs;

  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration?>? _durSub;
  StreamSubscription<ProcessingState>? _procSub;

  Future<void> _chain = Future.value();

  bool _hydrated = false;
  bool _handlingCompleted = false;
  bool _queueDirty = false;
  String? _lastArgsSignature;

  static const _queueKey = 'audio_queue_items';
  static const _queueIndexKey = 'audio_queue_index';
  static const _resumePosKey = 'audio_resume_positions';
  static const _shuffleKey = 'audio_shuffle_on';
  static const _repeatModeKey = 'audio_repeat_mode';
  static const _coverStyleKey = 'playerCoverStyle';

  @override
  void onInit() {
    super.onInit();

    final hasArgs = _readArgs();
    if (!hasArgs) {
      _restoreQueue();
    }

    _loadShuffleState();
    _loadRepeatMode();
    _loadCoverStyle();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cleanup8dVariants();
    });

    _posSub = audioService.positionStream.listen((p) => position.value = p);
    _durSub = audioService.durationStream.listen(
      (d) => duration.value = d ?? Duration.zero,
    );

    _procSub = audioService.processingStateStream.listen((state) async {
      if (state != ProcessingState.completed) return;
      if (_handlingCompleted) return;

      _handlingCompleted = true;
      try {
        if (repeatMode.value == RepeatMode.loop) return;

        if (repeatMode.value == RepeatMode.once) {
          repeatMode.value = RepeatMode.off;
          _storage.write(_repeatModeKey, RepeatMode.off.name);
          await audioService.setLoopOff();
          await audioService.replay();
          return;
        }

        if (!_settings.autoPlayNext.value) {
          await audioService.stop();
          return;
        }

        await next();
      } finally {
        await Future.delayed(const Duration(milliseconds: 200));
        _handlingCompleted = false;
      }
    });

    ever<MediaItem?>(audioService.currentItem, (_) {
      _syncFromServiceQueue();
    });

    ever<List<MediaItem>>(queue, (_) => _persistQueue());
    ever<int>(currentIndex, (_) => _persistQueue());

    debounce<Duration>(
      position,
      (p) => _persistPosition(p),
      time: const Duration(seconds: 2),
    );

    _ensureLoadedCurrent().catchError((_) {});
  }

  @override
  void onClose() {
    _procSub?.cancel();
    _posSub?.cancel();
    _durSub?.cancel();
    super.onClose();
  }

  Rx<SpatialAudioMode> get spatialMode => _spatial.mode;

  Future<void> setSpatialMode(SpatialAudioMode mode) async {
    final ok = await _spatial.setMode(mode);
    if (!ok) {
      Get.snackbar(
        'Audio',
        'El efecto envolvente no está disponible en este dispositivo.',
        snackPosition: SnackPosition.BOTTOM,
      );
      await _spatial.setMode(SpatialAudioMode.off);
    }
  }

  void toggleCoverStyle() {
    coverStyle.value = coverStyle.value == CoverStyle.square
        ? CoverStyle.vinyl
        : CoverStyle.square;
    _storage.write(_coverStyleKey, coverStyle.value.name);
  }

  bool _readArgs() {
    final args = Get.arguments;
    if (args is! Map) return false;

    final rawQueue = args['queue'];
    final rawIndex = args['index'];

    final incoming = _extractItems(rawQueue);
    if (incoming.isEmpty) return false;

    queue.assignAll(incoming);

    final idx = rawIndex is int ? rawIndex : 0;
    currentIndex.value = idx.clamp(0, incoming.length - 1).toInt();

    _hydrated = true;
    _queueDirty = true;
    _persistQueue();
    return true;
  }

  void applyRouteArgs(dynamic args) {
    if (args is! Map) return;

    final incoming = _extractItems(args['queue']);
    if (incoming.isEmpty) return;

    final rawIndex = args['index'];
    final safeIndex = (rawIndex is int ? rawIndex : 0)
        .clamp(0, incoming.length - 1)
        .toInt();

    final signature =
        '${incoming.length}:$safeIndex:${incoming.map((e) => e.id).join(',')}';
    if (_lastArgsSignature == signature) return;
    _lastArgsSignature = signature;

    final oldQueue = List<MediaItem>.from(queue);
    final oldIndex = currentIndex.value;

    queue.assignAll(incoming);
    currentIndex.value = safeIndex;

    _hydrated = true;
    _queueDirty = true;
    _persistQueue();

    final queueChanged =
        oldQueue.length != queue.length ||
        oldIndex != currentIndex.value ||
        !_sameQueue(oldQueue, queue);

    _ensureLoadedCurrent(forceReload: queueChanged).catchError((_) {});
  }

  List<MediaItem> _extractItems(dynamic rawQueue) {
    if (rawQueue is List<MediaItem>) return rawQueue;
    if (rawQueue is List) return rawQueue.whereType<MediaItem>().toList();
    return <MediaItem>[];
  }

  bool _sameQueue(List<MediaItem> a, List<MediaItem> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  void _restoreQueue() {
    if (_hydrated) return;
    _hydrated = true;

    final raw = _storage.read<List>(_queueKey);
    if (raw == null) return;

    final items = raw
        .whereType<Map>()
        .map((m) => MediaItem.fromJson(Map<String, dynamic>.from(m)))
        .toList();

    queue.assignAll(items);

    final idx = _storage.read(_queueIndexKey);
    if (idx is int && idx >= 0 && idx < queue.length) {
      currentIndex.value = idx;
    } else {
      currentIndex.value = 0;
    }

    _queueDirty = true;
  }

  void _loadShuffleState() {
    final on = _storage.read(_shuffleKey);
    if (on is bool) isShuffling.value = on;
  }

  void _persistShuffleState() {
    _storage.write(_shuffleKey, isShuffling.value);
  }

  void _loadRepeatMode() {
    final raw = _storage.read<String>(_repeatModeKey);
    if (raw == RepeatMode.once.name) {
      repeatMode.value = RepeatMode.once;
    } else if (raw == RepeatMode.loop.name) {
      repeatMode.value = RepeatMode.loop;
    } else {
      repeatMode.value = RepeatMode.off;
    }
  }

  void _loadCoverStyle() {
    final raw = _storage.read<String>(_coverStyleKey);
    coverStyle.value =
        raw == CoverStyle.vinyl.name ? CoverStyle.vinyl : CoverStyle.square;
  }

  void _persistQueue() {
    _storage.write(_queueKey, queue.map((e) => e.toJson()).toList());
    _storage.write(_queueIndexKey, currentIndex.value);
  }

  void _persistPosition(Duration value) {
    final item = currentItemOrNull;
    if (item == null) return;

    final key = item.publicId.trim().isNotEmpty
        ? item.publicId.trim()
        : item.id.trim();
    if (key.isEmpty) return;

    final map = _storage.read<Map>(_resumePosKey);
    final next = <String, dynamic>{};
    if (map != null) {
      for (final entry in map.entries) {
        next[entry.key.toString()] = entry.value;
      }
    }

    if (value.inMilliseconds <= 1000) {
      next.remove(key);
    } else {
      next[key] = value.inMilliseconds;
    }

    _storage.write(_resumePosKey, next);
  }

  Duration? _getResumePosition(MediaItem item) {
    final key = item.publicId.trim().isNotEmpty
        ? item.publicId.trim()
        : item.id.trim();
    if (key.isEmpty) return null;

    final map = _storage.read<Map>(_resumePosKey);
    if (map == null) return null;

    final raw = map[key];
    if (raw is! int || raw < 1500) return null;
    return Duration(milliseconds: raw);
  }

  Future<bool> _shouldResume(MediaItem item, Duration resume) async {
    if (Get.context == null) return true;

    final mm = resume.inMinutes;
    final ss = (resume.inSeconds % 60).toString().padLeft(2, '0');

    final result = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Reanudar reproducción'),
        content: Text(
          '¿Quieres continuar "${item.title}" desde $mm:$ss o iniciar desde el comienzo?',
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

  void _clearResumeFor(MediaItem item) {
    final key = item.publicId.trim().isNotEmpty
        ? item.publicId.trim()
        : item.id.trim();
    if (key.isEmpty) return;

    final map = _storage.read<Map>(_resumePosKey);
    if (map == null) return;

    final next = <String, dynamic>{};
    for (final entry in map.entries) {
      if (entry.key.toString() == key) continue;
      next[entry.key.toString()] = entry.value;
    }

    _storage.write(_resumePosKey, next);
  }

  Future<void> _cleanup8dVariants() async {
    try {
      final items = await _store.readAll();
      for (final item in items) {
        final variants = item.variants;
        if (variants.isEmpty) continue;

        final toRemove = variants.where((v) {
          final name = v.fileName.toLowerCase();
          final path = v.localPath?.toLowerCase() ?? '';
          return name.contains('_8d') ||
              path.contains('/converted/') ||
              path.contains('_8d.');
        }).toList();

        if (toRemove.isEmpty) continue;

        for (final variant in toRemove) {
          final path = variant.localPath?.trim();
          if (path == null || path.isEmpty) continue;
          final file = File(path);
          if (await file.exists()) {
            await file.delete();
          }
        }

        final kept = variants.where((v) => !toRemove.contains(v)).toList();
        final updated = item.copyWith(variants: kept);
        await _store.upsert(updated);

        final idx = queue.indexWhere((e) => e.id == item.id);
        if (idx >= 0) queue[idx] = updated;
      }
    } catch (_) {}
  }

  bool get hasQueue => queue.isNotEmpty;

  MediaItem? get currentItemOrNull {
    if (queue.isEmpty) return null;
    final idx = currentIndex.value;
    if (idx < 0 || idx >= queue.length) return null;
    return queue[idx];
  }

  MediaVariant? get currentAudioVariant {
    final item = currentItemOrNull;
    if (item == null) return null;

    for (final v in item.variants) {
      final local = v.localPath?.trim();
      if (v.kind == MediaVariantKind.audio &&
          v.isValid &&
          local != null &&
          local.isNotEmpty) {
        return v;
      }
    }

    for (final v in item.variants) {
      if (v.kind == MediaVariantKind.audio && v.isValid) return v;
    }

    return null;
  }

  bool get isPlaying => audioService.isPlaying.value;

  void addToQueue(List<MediaItem> items) {
    if (items.isEmpty) return;
    queue.addAll(items);
    _queueDirty = true;
  }

  void insertNext(List<MediaItem> items) {
    if (items.isEmpty) return;
    final insertAt = (currentIndex.value + 1).clamp(0, queue.length);
    queue.insertAll(insertAt, items);
    _queueDirty = true;
  }

  Future<void> reorderQueue(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= queue.length) return;
    if (newIndex < 0 || newIndex > queue.length) return;

    if (newIndex > oldIndex) newIndex -= 1;

    final item = queue.removeAt(oldIndex);
    queue.insert(newIndex, item);

    if (currentIndex.value == oldIndex) {
      currentIndex.value = newIndex;
    } else if (oldIndex < newIndex) {
      if (currentIndex.value > oldIndex && currentIndex.value <= newIndex) {
        currentIndex.value -= 1;
      }
    } else {
      if (currentIndex.value >= newIndex && currentIndex.value < oldIndex) {
        currentIndex.value += 1;
      }
    }

    _queueDirty = true;
    await _rebuildServiceQueue(preservePosition: true);
  }

  Future<void> _ensureLoadedCurrent({bool forceReload = false}) async {
    final item = currentItemOrNull;
    final variant = currentAudioVariant;
    if (item == null || variant == null) return;

    if (!forceReload &&
        audioService.hasSourceLoaded &&
        audioService.isSameTrack(item, variant) &&
        !_queueNeedsRebuild()) {
      return;
    }

    await _playItem(
      item,
      variant,
      userInitiated: false,
      forceReload: forceReload || _queueNeedsRebuild(),
    );
  }

  Future<void> togglePlay() async {
    _touchActivity();

    final item = currentItemOrNull;
    final variant = currentAudioVariant;
    if (item == null || variant == null) return;

    if (!audioService.hasSourceLoaded ||
        !audioService.isSameTrack(item, variant) ||
        _queueNeedsRebuild()) {
      await _playItem(item, variant, userInitiated: true, forceReload: true);
      return;
    }

    await audioService.toggle();
  }

  Future<void> playAt(int index) async {
    _touchActivity();
    if (index < 0 || index >= queue.length) return;

    currentIndex.value = index;
    _queueDirty = false;

    final item = currentItemOrNull;
    final variant = currentAudioVariant;
    if (item == null || variant == null) return;

    await _playItem(item, variant, userInitiated: true, forceReload: true);
  }

  Future<void> _playItem(
    MediaItem item,
    MediaVariant variant, {
    required bool userInitiated,
    bool forceReload = false,
  }) async {
    await _enqueue(() async {
      _touchActivity();

      if (!variant.isValid) {
        throw Exception('Variante no válida para reproducción');
      }

      final isSameLoadedTrack =
          audioService.hasSourceLoaded &&
          audioService.isSameTrack(item, variant) &&
          !forceReload &&
          !_queueNeedsRebuild();

      if (!isSameLoadedTrack) {
        position.value = Duration.zero;
        duration.value = Duration.zero;
      }

      final resume = userInitiated ? _getResumePosition(item) : null;

      await audioService.play(
        item,
        variant,
        autoPlay: userInitiated && resume == null,
        queue: queue.toList(),
        queueIndex: currentIndex.value,
        forceReload: forceReload || _queueNeedsRebuild(),
      );

      if (repeatMode.value == RepeatMode.loop) {
        await audioService.setLoopOne();
      } else {
        await audioService.setLoopOff();
      }

      try {
        await audioService.setShuffle(isShuffling.value);
      } catch (_) {}

      _syncFromServiceQueue();
      _queueDirty = false;

      if (resume != null) {
        final keep = await _shouldResume(item, resume);
        if (keep) {
          final d = await audioService.durationStream
              .firstWhere((x) => x != null && x > Duration.zero)
              .timeout(const Duration(seconds: 2), onTimeout: () => null);

          final full = d ?? Duration.zero;
          if (full > Duration.zero && resume < full - const Duration(seconds: 2)) {
            await audioService.seek(resume);
          }
        } else {
          _clearResumeFor(item);
          await audioService.seek(Duration.zero);
        }

        await audioService.resume();
      }

      if (userInitiated) {
        await _trackPlay(item);
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
          (item.publicId.trim().isNotEmpty &&
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

  bool _queueNeedsRebuild() {
    if (_queueDirty) return true;

    final serviceQueue = audioService.queueItems;
    if (serviceQueue.length != queue.length) return true;

    for (var i = 0; i < queue.length; i++) {
      if (serviceQueue[i].id != queue[i].id) return true;
    }

    return false;
  }

  void _syncFromServiceQueue() {
    final serviceQueue = audioService.queueItems;
    if (serviceQueue.isNotEmpty) {
      queue.assignAll(serviceQueue);
    }

    final idx = audioService.currentQueueIndex;
    if (idx >= 0 && idx < queue.length) {
      currentIndex.value = idx;
    } else {
      final current = audioService.currentItem.value;
      if (current != null) {
        final matched = queue.indexWhere((e) {
          if (e.id == current.id) return true;
          final pid = current.publicId.trim();
          return pid.isNotEmpty && e.publicId.trim() == pid;
        });
        if (matched >= 0) currentIndex.value = matched;
      }
    }

    _queueDirty = false;
  }

  Future<void> _rebuildServiceQueue({required bool preservePosition}) async {
    final item = currentItemOrNull;
    final variant = currentAudioVariant;
    if (item == null || variant == null) return;

    final wasPlaying = audioService.isPlaying.value;
    final oldPosition = position.value;

    await audioService.play(
      item,
      variant,
      autoPlay: wasPlaying,
      queue: queue.toList(),
      queueIndex: currentIndex.value,
      forceReload: true,
    );

    if (repeatMode.value == RepeatMode.loop) {
      await audioService.setLoopOne();
    } else {
      await audioService.setLoopOff();
    }

    try {
      await audioService.setShuffle(isShuffling.value);
    } catch (_) {}

    if (preservePosition && oldPosition > Duration.zero) {
      await audioService.seek(oldPosition);
    }

    _syncFromServiceQueue();
  }

  Future<void> next() async {
    _touchActivity();
    if (!hasQueue) return;

    await _enqueue(() async {
      if (_queueNeedsRebuild()) {
        await _rebuildServiceQueue(preservePosition: false);
      }

      final before = audioService.currentQueueIndex;
      await audioService.next();
      _syncFromServiceQueue();

      if (audioService.currentQueueIndex == before &&
          currentIndex.value < queue.length - 1) {
        currentIndex.value += 1;
        final item = currentItemOrNull;
        final variant = currentAudioVariant;
        if (item != null && variant != null) {
          await _playItem(item, variant, userInitiated: true, forceReload: true);
        }
      }
    });
  }

  Future<void> previous() async {
    _touchActivity();
    if (!hasQueue) return;

    await _enqueue(() async {
      if (_queueNeedsRebuild()) {
        await _rebuildServiceQueue(preservePosition: false);
      }

      final before = audioService.currentQueueIndex;
      await audioService.previous();
      _syncFromServiceQueue();

      if (audioService.currentQueueIndex == before && currentIndex.value > 0) {
        currentIndex.value -= 1;
        final item = currentItemOrNull;
        final variant = currentAudioVariant;
        if (item != null && variant != null) {
          await _playItem(item, variant, userInitiated: true, forceReload: true);
        }
      }
    });
  }

  Future<void> toggleShuffle() async {
    _touchActivity();
    isShuffling.value = !isShuffling.value;
    _persistShuffleState();

    await _enqueue(() async {
      try {
        await audioService.setShuffle(isShuffling.value);
      } catch (_) {}
      _syncFromServiceQueue();
    });
  }

  Future<void> toggleRepeatOnce() async {
    final next =
        repeatMode.value == RepeatMode.once ? RepeatMode.off : RepeatMode.once;
    repeatMode.value = next;
    _storage.write(_repeatModeKey, next.name);
    await audioService.setLoopOff();
  }

  Future<void> toggleRepeatLoop() async {
    final next =
        repeatMode.value == RepeatMode.loop ? RepeatMode.off : RepeatMode.loop;
    repeatMode.value = next;
    _storage.write(_repeatModeKey, next.name);

    if (next == RepeatMode.loop) {
      await audioService.setLoopOne();
    } else {
      await audioService.setLoopOff();
    }
  }

  Future<void> cyclePlaybackSpeed() async {
    _touchActivity();
    const presets = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    final current = audioService.speed.value;
    final idx = presets.indexWhere((p) => p == current);
    final next = presets[(idx + 1) % presets.length];
    await audioService.setSpeed(next);
  }

  Future<void> skipForward10() async {
    _touchActivity();
    final target = position.value + const Duration(seconds: 10);
    await seek(target > duration.value ? duration.value : target);
  }

  Future<void> skipBackward10() async {
    _touchActivity();
    final target = position.value - const Duration(seconds: 10);
    await seek(target.isNegative ? Duration.zero : target);
  }

  Future<void> seek(Duration value) async {
    _touchActivity();
    await audioService.seek(value);
  }

  Future<void> _enqueue(Future<void> Function() action) {
    _chain = _chain.then((_) => action()).catchError((_) {});
    return _chain;
  }

  void _touchActivity() {
    _settings.notifyPlaybackActivity();
  }
}

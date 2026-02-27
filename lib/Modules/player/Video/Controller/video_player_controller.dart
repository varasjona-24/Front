import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:video_player/video_player.dart' as vp;

import '../../../../app/models/media_item.dart';
import '../../../../app/models/subtitle_track.dart';
import '../../../../app/services/video_service.dart';
import '../../../../app/data/local/local_library_store.dart';
import '../../../settings/controller/playback_settings_controller.dart';

class VideoPlayerController extends GetxController {
  final VideoService videoService;
  final LocalLibraryStore _store = Get.find<LocalLibraryStore>();
  final PlaybackSettingsController _settings =
      Get.find<PlaybackSettingsController>();
  final GetStorage _storage = GetStorage();
  final List<MediaItem> queue;
  final int initialIndex;

  final RxInt currentIndex = 0.obs;
  final Rxn<String> error = Rxn<String>();
  final RxBool isLoading = false.obs;
  final Rxn<SubtitleTrack> currentSubtitle = Rxn<SubtitleTrack>();
  final RxInt queueVersion = 0.obs;
  Worker? _playbackErrorWorker;

  static const _queueKey = 'video_queue_items';
  static const _queueIndexKey = 'video_queue_index';
  static const _resumePosKey = 'video_resume_positions';

  VideoPlayerController({
    required this.videoService,
    required this.queue,
    required this.initialIndex,
  });

  // Delegación de streams al VideoService
  Rx<Duration> get position => videoService.position;
  Rx<Duration> get duration => videoService.duration;
  RxBool get isPlaying => videoService.isPlaying;
  Rx<VideoPlaybackState> get state => videoService.state;

  vp.VideoPlayerController? get playerController =>
      videoService.playerController;

  @override
  void onInit() {
    super.onInit();

    if (queue.isEmpty) {
      currentIndex.value = 0;
    } else {
      final safeIndex = initialIndex.clamp(0, queue.length - 1).toInt();
      currentIndex.value = safeIndex;
      _persistQueue();
    }

    debounce<Duration>(
      position,
      (p) => _persistPosition(p),
      time: const Duration(seconds: 2),
    );

    ever<int>(videoService.completedTick, (_) async {
      if (!_settings.autoPlayNext.value) return;
      await next();
    });

    _playbackErrorWorker = ever<String?>(videoService.playbackError, (err) {
      if (err == null || err.trim().isEmpty) return;
      _setError(err);
    });
  }

  @override
  void onReady() {
    super.onReady();
    // Evita actualizaciones de Rx durante el build inicial.
    Future.microtask(_playCurrent);
  }

  // ===========================================================================
  // STATE / GETTERS
  // ===========================================================================

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

  /// Lógica para seleccionar la variante de video preferida
  /// Prioridad:
  /// 1) video local con localPath válido
  /// 2) mp4 remoto
  /// 3) cualquier video válido
  MediaVariant? get currentVideoVariant {
    final item = currentItemOrNull;
    if (item == null) return null;

    // 1️⃣ Buscar video local con localPath válido
    final localVideo = item.variants.firstWhereOrNull(
      (v) =>
          v.kind == MediaVariantKind.video &&
          v.localPath != null &&
          v.localPath!.trim().isNotEmpty &&
          v.isValid,
    );
    if (localVideo != null) return localVideo;

    // 2️⃣ Preferir mp4 formato si disponible (remoto)
    final mp4 = item.variants.firstWhereOrNull(
      (v) =>
          v.kind == MediaVariantKind.video &&
          v.format.toLowerCase() == 'mp4' &&
          v.isValid,
    );
    if (mp4 != null) return mp4;

    // 3️⃣ Buscar cualquier video válido
    final anyVideo = item.variants.firstWhereOrNull(
      (v) => v.kind == MediaVariantKind.video && v.isValid,
    );
    return anyVideo;
  }

  // ===========================================================================
  // PLAYBACK CONTROL
  // ===========================================================================

  Future<void> _playCurrent() async {
    clearError();

    final item = currentItemOrNull;
    final variant = currentVideoVariant;
    if (item == null || variant == null) {
      _setError('Este archivo está corrupto o no existe, selecciona otro.');
      return;
    }

    await _playItem(item, variant);
  }

  Future<void> _playItem(MediaItem item, MediaVariant variant) async {
    // Validar variante
    if (!variant.isValid) {
      _setError('Variante de video no válida.');
      return;
    }

    isLoading.value = true;
    try {
      print('▶️ Playing: ${item.title} (${variant.kind}/${variant.format})');
      await videoService.play(item, variant);
      await _resumeIfAny(item);
      await _trackPlay(item);
      clearError();
    } catch (e) {
      print('❌ Error in _playItem: $e');
      _setError('Error al reproducir: $e');
    } finally {
      isLoading.value = false;
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
          (item.publicId.isNotEmpty && existing.publicId == item.publicId)) {
        updated = existing.copyWith(
          playCount: existing.playCount + 1,
          lastPlayedAt: now,
        );
        break;
      }
    }

    await _store.upsert(updated);
  }

  Future<void> togglePlay() async {
    await videoService.toggle();
  }

  Future<void> seek(Duration value) async {
    await videoService.seek(value);
  }

  Future<void> next() async {
    if (currentIndex.value < queue.length - 1) {
      currentIndex.value++;
      _persistQueue();
      await _playCurrent();
    }
  }

  Future<void> previous() async {
    if (currentIndex.value > 0) {
      currentIndex.value--;
      _persistQueue();
      await _playCurrent();
    }
  }

  Future<void> playAt(int index) async {
    if (index < 0 || index >= queue.length) return;
    currentIndex.value = index;
    _persistQueue();
    await _playCurrent();
  }

  /// Reintentar cargar el mismo vídeo
  Future<void> retry() async {
    await _playCurrent();
  }

  void clearError() {
    error.value = null;
  }

  void _setError(String message) {
    error.value = message;
    Get.snackbar(
      'Error',
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFFD32F2F),
      colorText: const Color(0xFFFFFFFF),
      duration: const Duration(seconds: 3),
    );
  }

  Future<void> updateQueue(
    List<MediaItem> newQueue,
    int index, {
    bool autoPlay = true,
  }) async {
    final hasItems = newQueue.isNotEmpty;
    final safeIndex = hasItems ? index.clamp(0, newQueue.length - 1) : 0;
    final sameQueue = _sameQueue(queue, newQueue);
    final sameIndex = currentIndex.value == safeIndex;
    if (sameQueue && sameIndex) return;

    queue
      ..clear()
      ..addAll(newQueue);
    currentIndex.value = safeIndex;
    _persistQueue();
    queueVersion.value++;
    clearError();

    if (autoPlay && hasItems) {
      await _playCurrent();
    }
  }

  bool _sameQueue(List<MediaItem> a, List<MediaItem> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id == b[i].id) continue;
      final ap = a[i].publicId.trim();
      final bp = b[i].publicId.trim();
      if (ap.isEmpty || bp.isEmpty || ap != bp) return false;
    }
    return true;
  }

  void reorderQueue(int oldIndex, int newIndex) {
    if (queue.length <= 1) return;
    if (oldIndex < 0 || oldIndex >= queue.length) return;
    if (newIndex < 0 || newIndex > queue.length) return;

    if (oldIndex < newIndex) newIndex -= 1;
    if (oldIndex == newIndex) return;

    final moved = queue.removeAt(oldIndex);
    queue.insert(newIndex, moved);

    if (currentIndex.value == oldIndex) {
      currentIndex.value = newIndex;
    } else if (currentIndex.value > oldIndex &&
        currentIndex.value <= newIndex) {
      currentIndex.value--;
    } else if (currentIndex.value < oldIndex &&
        currentIndex.value >= newIndex) {
      currentIndex.value++;
    }

    _persistQueue();
    queueVersion.value++;
  }

  Future<void> removeFromQueue(int index) async {
    if (index < 0 || index >= queue.length) return;

    final removedCurrent = index == currentIndex.value;
    queue.removeAt(index);

    if (queue.isEmpty) {
      currentIndex.value = 0;
      _persistQueue();
      queueVersion.value++;
      await videoService.stop();
      clearError();
      return;
    }

    if (index < currentIndex.value) {
      currentIndex.value--;
    } else if (currentIndex.value >= queue.length) {
      currentIndex.value = queue.length - 1;
    }

    _persistQueue();
    queueVersion.value++;

    if (removedCurrent) {
      await _playCurrent();
    }
  }

  void _persistQueue() {
    if (queue.isEmpty) {
      _storage.remove(_queueKey);
      _storage.remove(_queueIndexKey);
      return;
    }
    _storage.write(_queueKey, queue.map((e) => e.toJson()).toList());
    _storage.write(_queueIndexKey, currentIndex.value);
  }

  void _persistPosition(Duration p) {
    final item = currentItemOrNull;
    if (item == null) return;
    final key = item.publicId.isNotEmpty ? item.publicId : item.id;
    if (key.trim().isNotEmpty) {
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
  }

  Future<void> _resumeIfAny(MediaItem item) async {
    if (GetPlatform.isAndroid) {
      // TODO: Re-enable Android auto-resume once seek no longer forces a black
      // frame on hybrid/platform-view rendering paths.
      return;
    }

    final key = item.publicId.isNotEmpty ? item.publicId : item.id;
    final map = _storage.read<Map>(_resumePosKey);
    if (map == null) return;
    final raw = map[key];
    if (raw is! int) return;
    if (raw < 1500) return;

    try {
      Duration d = videoService.duration.value;
      for (var i = 0; i < 10 && d == Duration.zero; i++) {
        await Future.delayed(const Duration(milliseconds: 200));
        d = videoService.duration.value;
      }
      if (d == Duration.zero) return;

      final resume = Duration(milliseconds: raw);
      if (resume < d - const Duration(seconds: 2)) {
        await videoService.seek(resume);
      }
    } catch (_) {
      // ignore resume failures
    }
  }

  Future<void> loadSubtitle(SubtitleTrack track) async {
    currentSubtitle.value = track;
    await videoService.loadSubtitle(track);
  }

  // TODO: Integrate Android/iOS background playback session handoff.
  // TODO: Connect controller lifecycle with platform PiP resume/restore events.

  @override
  void onClose() {
    _playbackErrorWorker?.dispose();
    super.onClose();
  }
}

import 'dart:async';
import 'dart:io';

import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:video_player/video_player.dart' as vp;

import '../models/media_item.dart';
import '../config/api_config.dart';
import '../../Modules/settings/controller/settings_controller.dart';

enum VideoPlaybackState { stopped, loading, playing, paused }

class VideoService extends GetxService {
  final GetStorage _storage = GetStorage();

  static const _lastItemKey = 'video_last_item';
  static const _lastVariantKey = 'video_last_variant';
  bool _keepLastItem = false;

  bool get keepLastItem => _keepLastItem;
  final Rx<VideoPlaybackState> state = VideoPlaybackState.stopped.obs;
  final RxBool isPlaying = false.obs;
  final RxBool isLoading = false.obs;

  final Rx<Duration> position = Duration.zero.obs;
  final Rx<Duration> duration = Duration.zero.obs;
  final RxDouble volume = 1.0.obs;
  final RxDouble speed = 1.0.obs;
  final RxInt completedTick = 0.obs;
  bool _completedOnce = false;

  MediaItem? _currentItem;
  MediaVariant? _currentVariant;
  final Rxn<MediaItem> currentItem = Rxn<MediaItem>();
  final Rxn<MediaVariant> currentVariant = Rxn<MediaVariant>();

  vp.VideoPlayerController? _player;
  Timer? _posTimer;

  bool get hasSourceLoaded => _player != null;

  bool isSameVideo(MediaItem item, MediaVariant v) {
    return _currentItem?.id == item.id &&
        _currentVariant?.format == v.format &&
        _currentVariant?.kind == v.kind;
  }

  @override
  void onInit() {
    super.onInit();
    if (Get.isRegistered<SettingsController>()) {
      final settings = Get.find<SettingsController>();
      setVolume(settings.defaultVolume.value / 100);
    }
    _restoreLastItem();
  }

  @override
  void onClose() {
    _posTimer?.cancel();
    _player?.dispose();
    super.onClose();
  }

  // ===========================================================================
  // PLAYBACK CONTROL
  // ===========================================================================

  Future<void> play(MediaItem item, MediaVariant variant) async {
    if (!variant.isValid) {
      throw Exception('No existe archivo para reproducir (variant inválido).');
    }

    final sameTrack = isSameVideo(item, variant);
    if (sameTrack && hasSourceLoaded) {
      if (!isPlaying.value) await _player?.play();
      return;
    }

    // Detener reproductor anterior
    await _disposePlayer();

    // UI inmediato
    isLoading.value = true;
    isPlaying.value = false;
    state.value = VideoPlaybackState.loading;
    _completedOnce = false;

    // -----------------------------------------------------------------------
    // ✅ LOCAL
    // -----------------------------------------------------------------------
    final localPath = variant.localPath?.trim();
    final hasLocal = localPath != null && localPath.isNotEmpty;

    String? videoUrl;

    if (hasLocal) {
      final f = File(localPath);
      if (!await f.exists()) {
        // debug útil
        print('❌ Local video file not found');
        print('fileName = ${variant.fileName}');
        print('localPath = ${variant.localPath}');
        print('using path = $localPath');

        isLoading.value = false;
        isPlaying.value = false;
        state.value = VideoPlaybackState.stopped;

        throw Exception('Archivo local no encontrado: $localPath');
      }

      try {
        videoUrl = Uri.file(localPath).toString();
        print('🎬 Playing local video: $videoUrl');

        _player = vp.VideoPlayerController.file(File(localPath));

        await _player!.initialize().timeout(const Duration(seconds: 12));
        final v = _player!.value;
        print(
          '🎥 LOCAL init=${v.isInitialized} '
          'size=${v.size} '
          'dur=${v.duration} '
          'buffering=${v.isBuffering} '
          'error=${v.hasError ? v.errorDescription : "none"}',
        );
        _currentItem = item;
        _currentVariant = variant;
        currentItem.value = item;
        currentVariant.value = variant;
        _persistLastItem(item, variant);
        _keepLastItem = true;

        _setupPlayerListener();

      duration.value = _player!.value.duration;
      await _player!.setVolume(volume.value);
      await _player!.setPlaybackSpeed(speed.value);
      await _player!.play();
        isPlaying.value = true;
        state.value = VideoPlaybackState.playing;

        return;
      } catch (e) {
        await _disposePlayer();
        isLoading.value = false;
        isPlaying.value = false;
        state.value = VideoPlaybackState.stopped;

        print('❌ Error playing local video: $e');
        throw Exception('Error al reproducir video local: $e');
      } finally {
        isLoading.value = false;
      }
    }

    // -----------------------------------------------------------------------
    // 🌐 REMOTO (backend)
    // -----------------------------------------------------------------------
    final fileId = item.fileId.trim();
    final format = variant.format.trim();

    if (fileId.isEmpty || format.isEmpty) {
      isLoading.value = false;
      isPlaying.value = false;
      state.value = VideoPlaybackState.stopped;

      throw Exception(
        'Faltan datos para reproducción remota (fileId o format vacíos)',
      );
    }

    videoUrl = '${ApiConfig.baseUrl}/api/v1/media/file/$fileId/video/$format';

    print('🎬 VideoService.play (remote)');
    print('🌐 Video URL: $videoUrl');

    try {
      _player = vp.VideoPlayerController.network(videoUrl);

      await _player!.initialize().timeout(const Duration(seconds: 12));

      _currentItem = item;
      _currentVariant = variant;
      currentItem.value = item;
      currentVariant.value = variant;
      _persistLastItem(item, variant);
      _keepLastItem = true;

      _setupPlayerListener();

      duration.value = _player!.value.duration;
      await _player!.setVolume(volume.value);
      await _player!.setPlaybackSpeed(speed.value);
      await _player!.play();
      isPlaying.value = true;
      state.value = VideoPlaybackState.playing;
    } catch (e) {
      await _disposePlayer();
      isLoading.value = false;
      isPlaying.value = false;
      state.value = VideoPlaybackState.stopped;

      print('❌ Error playing remote video: $e');
      throw Exception('Error al reproducir video remoto: $e');
    } finally {
      isLoading.value = false;
    }
  }

  void _setupPlayerListener() {
    _posTimer?.cancel();
    _posTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (_player == null) return;
      final v = _player!.value;
      position.value = v.position;
      isPlaying.value = v.isPlaying;
      duration.value = v.duration;

      if (v.isPlaying) {
        state.value = VideoPlaybackState.playing;
      } else {
        state.value = VideoPlaybackState.paused;
      }

      final d = v.duration;
      final completed = d > Duration.zero &&
          v.position >= d - const Duration(milliseconds: 200);
      if (!_completedOnce && completed) {
        _completedOnce = true;
        completedTick.value++;
      }
    });
  }

  Future<void> _disposePlayer() async {
    _posTimer?.cancel();
    _posTimer = null;

    if (_player != null) {
      try {
        await _player!.pause();
      } catch (_) {}
      try {
        await _player!.dispose();
      } catch (_) {}
      _player = null;
    }

    position.value = Duration.zero;
    duration.value = Duration.zero;
    if (_keepLastItem) {
      state.value = VideoPlaybackState.paused;
      isPlaying.value = false;
    } else {
      _currentItem = null;
      _currentVariant = null;
      currentItem.value = null;
      currentVariant.value = null;
    }
  }

  Future<void> toggle() async {
    if (_player == null) {
      print('❌ No video loaded. Call play(item, variant) first.');
      return;
    }

    if (_player!.value.isPlaying) {
      await _player!.pause();
      state.value = VideoPlaybackState.paused;
    } else {
      await _player!.play();
      state.value = VideoPlaybackState.playing;
    }
  }

  Future<void> pause() async {
    if (_player == null) return;
    await _player!.pause();
    state.value = VideoPlaybackState.paused;
  }

  Future<void> resume() async {
    if (_player == null) return;
    await _player!.play();
    state.value = VideoPlaybackState.playing;
  }

  Future<void> seek(Duration position) async {
    if (_player == null) return;
    await _player!.seekTo(position);
  }

  Future<void> replay() async {
    if (_player == null) return;
    await _player!.seekTo(Duration.zero);
    await _player!.play();
    state.value = VideoPlaybackState.playing;
  }

  Future<void> setVolume(double v) async {
    final clamped = v.clamp(0.0, 1.0);
    volume.value = clamped;
    await _player?.setVolume(clamped);
  }

  Future<void> setSpeed(double v) async {
    final clamped = v.clamp(0.5, 2.0);
    speed.value = clamped;
    await _player?.setPlaybackSpeed(clamped);
  }

  Future<void> stop() async {
    await _disposePlayer();
    state.value = VideoPlaybackState.stopped;
    _keepLastItem = false;
  }

  void clearLastItem() {
    _storage.remove(_lastItemKey);
    _storage.remove(_lastVariantKey);
    _keepLastItem = false;
  }

  void _persistLastItem(MediaItem item, MediaVariant variant) {
    _storage.write(_lastItemKey, item.toJson());
    _storage.write(_lastVariantKey, variant.toJson());
  }

  void _restoreLastItem() {
    final rawItem = _storage.read<Map>(_lastItemKey);
    if (rawItem == null) return;
    try {
      final item = MediaItem.fromJson(Map<String, dynamic>.from(rawItem));
      final rawVariant = _storage.read<Map>(_lastVariantKey);
      MediaVariant? variant;
      if (rawVariant != null) {
        variant = MediaVariant.fromJson(Map<String, dynamic>.from(rawVariant));
      }

      _currentItem = item;
      _currentVariant = variant;
      currentItem.value = item;
      currentVariant.value = variant;
      state.value = VideoPlaybackState.paused;
      isPlaying.value = false;
      _keepLastItem = true;
    } catch (_) {
      // ignore restore failures
    }
  }

  // Getter para acceso al controlador si es necesario en UI
  vp.VideoPlayerController? get playerController => _player;
}

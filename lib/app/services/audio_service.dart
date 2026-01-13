import 'dart:async';
import 'dart:io';
import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';

import '../models/media_item.dart';
import '../config/api_config.dart';

enum PlaybackState { stopped, loading, playing, paused }

class AudioService extends GetxService {
  final AudioPlayer _player = AudioPlayer();

  final Rx<PlaybackState> state = PlaybackState.stopped.obs;
  final RxBool isPlaying = false.obs;
  final RxBool isLoading = false.obs;

  MediaItem? _currentItem;
  MediaVariant? _currentVariant;

  StreamSubscription<PlayerState>? _playerStateSub;

  bool get hasSourceLoaded => _player.processingState != ProcessingState.idle;

  bool isSameTrack(MediaItem item, MediaVariant v) {
    return _currentItem?.id == item.id &&
        _currentVariant?.format == v.format &&
        _currentVariant?.kind == v.kind;
  }

  @override
  Future<void> onInit() async {
    super.onInit();

    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    _playerStateSub = _player.playerStateStream.listen((ps) {
      final proc = ps.processingState;

      final loading =
          proc == ProcessingState.loading || proc == ProcessingState.buffering;

      isLoading.value = loading;
      isPlaying.value = ps.playing;

      if (loading) {
        state.value = PlaybackState.loading;
      } else if (ps.playing) {
        state.value = PlaybackState.playing;
      } else if (proc == ProcessingState.ready) {
        state.value = PlaybackState.paused;
      } else if (proc == ProcessingState.completed ||
          proc == ProcessingState.idle) {
        state.value = PlaybackState.stopped;
        isPlaying.value = false;
      }
    });
  }

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<ProcessingState> get processingStateStream =>
      _player.processingStateStream;

  // Loop mode observable (UI puede leerlo)
  final Rx<LoopMode> loopMode = LoopMode.off.obs;

  // Playback speed
  final RxDouble speed = 1.0.obs;

  Future<void> setLoopOff() async {
    loopMode.value = LoopMode.off;
    await _player.setLoopMode(LoopMode.off);
  }

  Future<void> setLoopOne() async {
    loopMode.value = LoopMode.one;
    await _player.setLoopMode(LoopMode.one);
  }

  /// Ajusta la velocidad de reproducción
  Future<void> setSpeed(double s) async {
    speed.value = s;
    await _player.setSpeed(s);
  }

  Future<void> seek(Duration position) async {
    if (!hasSourceLoaded) return;
    await _player.seek(position);
  }

  Future<void> replay() async {
    if (!hasSourceLoaded) return;
    await _player.seek(Duration.zero);
    await _player.play();
  }

  Future<void> resume() async {
    if (!hasSourceLoaded) return;
    await _player.play();
  }

  Future<void> play(MediaItem item, MediaVariant variant) async {
    // ✅ si no hay variant válido, no hay archivo
    if (!variant.isValid) {
      throw Exception('No existe archivo para reproducir (variant inválido).');
    }

    // ✅ mismo track: solo resume
    final sameTrack = isSameTrack(item, variant);
    if (sameTrack && hasSourceLoaded) {
      if (!_player.playing) await _player.play();
      return;
    }

    // Si es un archivo local, usa Uri.file
    if (item.source == MediaSource.local) {
      final path = variant.fileName;
      final f = File(path);
      if (!f.existsSync()) {
        throw Exception('Archivo local no encontrado: $path');
      }

      await _player.stop();

      isLoading.value = true;
      isPlaying.value = false;
      state.value = PlaybackState.loading;

      try {
        await _player.setAudioSource(
          AudioSource.uri(Uri.file(path), tag: item.title),
          initialPosition: Duration.zero,
        );

        _currentItem = item;
        _currentVariant = variant;

        await _player.play();
      } on PlayerException catch (pe) {
        await _player.stop();
        _currentItem = null;
        _currentVariant = null;

        isLoading.value = false;
        isPlaying.value = false;
        state.value = PlaybackState.stopped;

        throw Exception(
          'Error al reproducir: ${pe.message} (code: ${pe.code})',
        );
      } catch (e) {
        await _player.stop();
        _currentItem = null;
        _currentVariant = null;

        isLoading.value = false;
        isPlaying.value = false;
        state.value = PlaybackState.stopped;

        rethrow;
      } finally {
        isLoading.value = false;
      }

      return;
    }

    // ✅ ESTE ES EL CAMBIO IMPORTANTE:
    // usa item.id como antes (porque ese endpoint lo soporta)
    final url =
        '${ApiConfig.baseUrl}/api/v1/media/file/${item.id}/audio/${variant.format}';

    print('🎵 AudioService.play');
    print('🌐 Audio URL: $url');

    // ✅ corta audio anterior para que NO quede "playing" fantasma
    await _player.stop();

    // UI inmediato
    isLoading.value = true;
    isPlaying.value = false;
    state.value = PlaybackState.loading;

    try {
      await _player.setAudioSource(
        AudioSource.uri(Uri.parse(url), tag: item.title),
        initialPosition: Duration.zero,
      );

      // ✅ recién aquí confirmas track actual
      _currentItem = item;
      _currentVariant = variant;

      await _player.play();
    } on PlayerException catch (pe) {
      await _player.stop();
      _currentItem = null;
      _currentVariant = null;

      isLoading.value = false;
      isPlaying.value = false;
      state.value = PlaybackState.stopped;

      throw Exception('Error al reproducir: ${pe.message} (code: ${pe.code})');
    } catch (e) {
      await _player.stop();
      _currentItem = null;
      _currentVariant = null;

      isLoading.value = false;
      isPlaying.value = false;
      state.value = PlaybackState.stopped;

      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> toggle() async {
    if (_player.playing) {
      await _player.pause();
      return;
    }
    if (!hasSourceLoaded) {
      print('❌ No source loaded. Call play(item, variant) first.');
      return;
    }
    await _player.play();
  }

  Future<void> pause() => _player.pause();

  Future<void> stop() async {
    await _player.stop();
    _currentItem = null;
    _currentVariant = null;
  }

  @override
  void onClose() {
    _playerStateSub?.cancel();
    _player.dispose();
    super.onClose();
  }
}

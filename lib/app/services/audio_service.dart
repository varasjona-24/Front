import 'dart:async';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:just_audio/just_audio.dart';

import '../models/media_item.dart';
import '../config/api_config.dart';
import '../../Modules/settings/controller/settings_controller.dart';

enum PlaybackState { stopped, loading, playing, paused }

class AudioService extends GetxService {
  final AudioPlayer _player = AudioPlayer();
  final GetStorage _storage = GetStorage();

  static const _lastItemKey = 'audio_last_item';
  static const _lastVariantKey = 'audio_last_variant';
  bool _keepLastItem = false;

  bool get keepLastItem => _keepLastItem;

  final Rx<PlaybackState> state = PlaybackState.stopped.obs;
  final RxBool isPlaying = false.obs;
  final RxBool isLoading = false.obs;

  MediaItem? _currentItem;
  MediaVariant? _currentVariant;
  final Rxn<MediaItem> currentItem = Rxn<MediaItem>();
  final Rxn<MediaVariant> currentVariant = Rxn<MediaVariant>();

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

    if (Get.isRegistered<SettingsController>()) {
      final settings = Get.find<SettingsController>();
      await setVolume(settings.defaultVolume.value / 100);
    }

    _restoreLastItem();

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
        if (_keepLastItem && currentItem.value != null && !ps.playing) {
          state.value = PlaybackState.paused;
          isPlaying.value = false;
        } else {
          state.value = PlaybackState.stopped;
          isPlaying.value = false;
          currentItem.value = null;
          currentVariant.value = null;
        }
      }
    });
  }

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<ProcessingState> get processingStateStream =>
      _player.processingStateStream;

  final Rx<LoopMode> loopMode = LoopMode.off.obs;
  final RxDouble speed = 1.0.obs;
  final RxDouble volume = 1.0.obs;

  Future<void> setLoopOff() async {
    loopMode.value = LoopMode.off;
    await _player.setLoopMode(LoopMode.off);
  }

  Future<void> setLoopOne() async {
    loopMode.value = LoopMode.one;
    await _player.setLoopMode(LoopMode.one);
  }

  Future<void> setSpeed(double s) async {
    speed.value = s;
    await _player.setSpeed(s);
  }

  Future<void> setVolume(double v) async {
    final clamped = v.clamp(0.0, 1.0);
    volume.value = clamped;
    await _player.setVolume(clamped);
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
    if (!variant.isValid) {
      throw Exception('No existe archivo para reproducir (variant inválido).');
    }

    final sameTrack = isSameTrack(item, variant);
    if (sameTrack && hasSourceLoaded) {
      if (!_player.playing) await _player.play();
      return;
    }

    // ✅ corta audio anterior
    await _player.stop();

    // UI inmediato
    isLoading.value = true;
    isPlaying.value = false;
    state.value = PlaybackState.loading;

    // -----------------------------------------------------------------------
    // ✅ LOCAL
    // -----------------------------------------------------------------------
    final localPath = variant.localPath?.trim();
    final hasLocal = localPath != null && localPath.isNotEmpty;

    if (hasLocal) {
      final f = File(localPath);
      if (!f.existsSync()) {
        // debug útil
        print('❌ Local file not found');
        print('fileName = ${variant.fileName}');
        print('localPath = ${variant.localPath}');
        print('using path = $localPath');

        await _player.stop();
        isLoading.value = false;
        isPlaying.value = false;
        state.value = PlaybackState.stopped;

        throw Exception('Archivo local no encontrado: $localPath');
      }

      try {
        final fileUri = Uri.file(localPath);
        print('🎵 Playing local file: $fileUri');

        await _player.setAudioSource(
          AudioSource.uri(fileUri, tag: item.title),
          initialPosition: Duration.zero,
        );

        _currentItem = item;
        _currentVariant = variant;
        currentItem.value = item;
        currentVariant.value = variant;
        _persistLastItem(item, variant);
        _keepLastItem = true;

        await _player.setVolume(volume.value);
        await _player.play();
        return;
      } on PlayerException catch (pe) {
        await _player.stop();
        _currentItem = null;
        _currentVariant = null;

        isLoading.value = false;
        isPlaying.value = false;
        state.value = PlaybackState.stopped;

        print('❌ PlayerException: ${pe.message} (code: ${pe.code})');
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

        print('❌ Error playing local file: $e');
        rethrow;
      } finally {
        isLoading.value = false;
      }
    }

    // -----------------------------------------------------------------------
    // 🌐 REMOTO (backend)
    // -----------------------------------------------------------------------
    final kind = (variant.kind == MediaVariantKind.video) ? 'video' : 'audio';
    final fileId = item.fileId.trim();
    final format = variant.format.trim();

    if (fileId.isEmpty || format.isEmpty) {
      await _player.stop();
      isLoading.value = false;
      isPlaying.value = false;
      state.value = PlaybackState.stopped;

      throw Exception(
        'Faltan datos para reproducción remota (fileId o format vacíos)',
      );
    }

    final url = '${ApiConfig.baseUrl}/api/v1/media/file/$fileId/$kind/$format';

    print('🎵 AudioService.play (remote)');
    print('🌐 Audio URL: $url');

    try {
      await _player.setAudioSource(
        AudioSource.uri(Uri.parse(url), tag: item.title),
        initialPosition: Duration.zero,
      );

      _currentItem = item;
      _currentVariant = variant;
      currentItem.value = item;
      currentVariant.value = variant;
      _persistLastItem(item, variant);
      _keepLastItem = true;

      await _player.setVolume(volume.value);
      await _player.play();
    } on PlayerException catch (pe) {
      await _player.stop();
      _currentItem = null;
      _currentVariant = null;

      isLoading.value = false;
      isPlaying.value = false;
      state.value = PlaybackState.stopped;

      print('❌ PlayerException (remote): ${pe.message} (code: ${pe.code})');
      throw Exception('Error al reproducir: ${pe.message} (code: ${pe.code})');
    } catch (e) {
      await _player.stop();
      _currentItem = null;
      _currentVariant = null;

      isLoading.value = false;
      isPlaying.value = false;
      state.value = PlaybackState.stopped;

      print('❌ Error playing remote file: $e');
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
    state.value = PlaybackState.stopped;
    isPlaying.value = false;
    isLoading.value = false;
    _currentItem = null;
    _currentVariant = null;
    currentItem.value = null;
    currentVariant.value = null;
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
      state.value = PlaybackState.paused;
      isPlaying.value = false;
      _keepLastItem = true;
    } catch (_) {
      // ignore restore failures
    }
  }

  @override
  void onClose() {
    _playerStateSub?.cancel();
    _player.dispose();
    super.onClose();
  }
}

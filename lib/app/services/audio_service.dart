// ============================================================================
// IMPORTS
// ============================================================================
import 'dart:async';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:audio_service/audio_service.dart' as aud;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/services.dart';

import '../models/media_item.dart';
import '../config/api_config.dart';
import '../controllers/theme_controller.dart';
import '../../Modules/settings/controller/settings_controller.dart';

// ============================================================================
// ENUMS
// ============================================================================
enum PlaybackState { stopped, loading, playing, paused }

// ============================================================================
// AUDIO SERVICE (GetxService)
// ============================================================================
/// peluches 🧸:
/// Este servicio es el “cerebro” de reproducción. Maneja:
/// - AudioPlayer (just_audio)
/// - EQ Android (si existe)
/// - cola interna + sincronización con AudioHandler (notificación)
/// - persistencia del último item reproducido
class AudioService extends GetxService {
  static const MethodChannel _widgetChannel =
      MethodChannel('listenfy/player_widget');
  // ==========================================================================
  // STORAGE / KEYS
  // ==========================================================================
  final GetStorage _storage = GetStorage();
  static const _lastItemKey = 'audio_last_item';
  static const _lastVariantKey = 'audio_last_variant';

  // ==========================================================================
  // PLAYER / EQ
  // ==========================================================================
  final AndroidEqualizer? _equalizer;
  late final AudioPlayer _player;

  /// peluches 🧸: handler “externo” (tu AppAudioHandler) que vive en audio_service
  dynamic _handler;

  // ==========================================================================
  // FLAGS
  // ==========================================================================
  bool _keepLastItem = false;
  bool get keepLastItem => _keepLastItem;

  bool get eqSupported => _equalizer != null;
  AudioPlayer get player => _player;

  // ==========================================================================
  // RX STATE (UI)
  // ==========================================================================
  final Rx<PlaybackState> state = PlaybackState.stopped.obs;
  final RxBool isPlaying = false.obs;
  final RxBool isLoading = false.obs;

  // ==========================================================================
  // CURRENT TRACK
  // ==========================================================================
  MediaItem? _currentItem;
  MediaVariant? _currentVariant;

  final Rxn<MediaItem> currentItem = Rxn<MediaItem>();
  final Rxn<MediaVariant> currentVariant = Rxn<MediaVariant>();

  // ==========================================================================
  // SUBSCRIPTIONS
  // ==========================================================================
  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<int?>? _indexSub;

  // ==========================================================================
  // QUEUE (INTERNAL)
  // ==========================================================================
  List<MediaItem> _queueItems = [];
  List<MediaVariant> _queueVariants = [];

  List<MediaItem> get queueItems => List<MediaItem>.from(_queueItems);

  MediaItem? queueItemAt(int index) {
    if (index < 0 || index >= _queueItems.length) return null;
    return _queueItems[index];
  }

  // ==========================================================================
  // CONSTRUCTOR
  // ==========================================================================
  AudioService() : _equalizer = Platform.isAndroid ? AndroidEqualizer() : null {
    // peluches 🧸: pipeline con efectos solo en Android
    if (Platform.isAndroid) {
      _player = AudioPlayer(
        audioPipeline: AudioPipeline(androidAudioEffects: [_equalizer!]),
      );
    } else {
      _player = AudioPlayer();
    }
  }

  // ==========================================================================
  // HANDLER BRIDGE
  // ==========================================================================
  /// peluches 🧸: esto expone tu builder de MediaItem para el background
  aud.MediaItem buildBackgroundItem(MediaItem item) =>
      _buildBackgroundItem(item);

  /// peluches 🧸: aquí “enchufas” tu AppAudioHandler para que el servicio
  /// le pueda mandar queue/mediaItem y refrescar la notificación.
  void attachHandler(dynamic handler) {
    _handler = handler;
    _syncQueueToHandler();
    _updateWidget();
  }

  // ==========================================================================
  // HELPERS / CHECKS
  // ==========================================================================
  bool get hasSourceLoaded => _player.processingState != ProcessingState.idle;

  bool isSameTrack(MediaItem item, MediaVariant v) {
    return _currentItem?.id == item.id &&
        _currentVariant?.format == v.format &&
        _currentVariant?.kind == v.kind;
  }

  // ==========================================================================
  // LIFECYCLE
  // ==========================================================================
  @override
  Future<void> onInit() async {
    super.onInit();

    // peluches 🧸: sesión de audio (ducking, focus, etc.)
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    // peluches 🧸: volumen por defecto desde settings (si existe)
    if (Get.isRegistered<SettingsController>()) {
      final settings = Get.find<SettingsController>();
      await setVolume(settings.defaultVolume.value / 100);
    }

    // peluches 🧸: restaurar último item (solo para UI/estado, NO reproduce)
    _restoreLastItem();
    _updateWidget();

    // ------------------------------------------------------------------------
    // LISTEN: playerStateStream -> actualizar UI state
    // ------------------------------------------------------------------------
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
        // peluches 🧸: si keepLastItem, dejamos el item en UI pausado
        if (_keepLastItem && currentItem.value != null && !ps.playing) {
          state.value = PlaybackState.paused;
          isPlaying.value = false;
        } else {
          // peluches 🧸: si no, limpiamos todo
          state.value = PlaybackState.stopped;
          isPlaying.value = false;
          currentItem.value = null;
          currentVariant.value = null;
        }
      }

      _updateWidget();
    });

    // ------------------------------------------------------------------------
    // LISTEN: currentIndexStream -> cuando cambia pista en cola
    // ------------------------------------------------------------------------
    _indexSub = _player.currentIndexStream.listen((idx) {
      if (idx == null) return;
      if (_queueItems.isEmpty || _queueVariants.isEmpty) return;
      if (idx < 0 || idx >= _queueItems.length) return;

      final item = _queueItems[idx];
      final variant = _queueVariants[idx];

      _currentItem = item;
      _currentVariant = variant;

      currentItem.value = item;
      currentVariant.value = variant;

      _persistLastItem(item, variant);
      _keepLastItem = true;

      // peluches 🧸: importantísimo para notificación:
      // cuando cambia el track, sincroniza handler
      _syncQueueToHandler();
    });
  }

  // ==========================================================================
  // STREAM GETTERS
  // ==========================================================================
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<ProcessingState> get processingStateStream =>
      _player.processingStateStream;
  Stream<int?> get androidAudioSessionIdStream =>
      _player.androidAudioSessionIdStream;
  int? get androidAudioSessionId => _player.androidAudioSessionId;

  // ==========================================================================
  // PLAYBACK SETTINGS
  // ==========================================================================
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

  // ==========================================================================
  // EQ (ANDROID)
  // ==========================================================================
  Future<AndroidEqualizerParameters?> getEqParameters() async {
    if (_equalizer == null) return null;
    return _equalizer!.parameters;
  }

  Future<void> setEqEnabled(bool enabled) async {
    if (_equalizer == null) return;
    await _equalizer!.setEnabled(enabled);
  }

  Future<void> setEqBandGain(int index, double gain) async {
    if (_equalizer == null) return;
    final params = await _equalizer!.parameters;
    if (index < 0 || index >= params.bands.length) return;
    await params.bands[index].setGain(gain);
  }

  // ==========================================================================
  // BASIC CONTROLS
  // ==========================================================================
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

  // ==========================================================================
  // PLAY (MAIN)
  // ==========================================================================
  /// peluches 🧸:
  /// - Reproduce item + variant
  /// - Maneja local vs remoto
  /// - Maneja cola opcional
  Future<void> play(
    MediaItem item,
    MediaVariant variant, {
    bool autoPlay = true,
    List<MediaItem>? queue,
    int? queueIndex, // (peluches 🧸: por ahora no se usa directamente)
  }) async {
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

        // peluches 🧸: cola
        if (queue != null && queue.isNotEmpty) {
          final built = _buildQueueSources(queue, item, variant);
          _queueItems = built.items;
          _queueVariants = built.variants;
          _syncQueueToHandler();

          await _player.setAudioSource(
            ConcatenatingAudioSource(children: built.sources),
            initialIndex: built.startIndex,
            initialPosition: Duration.zero,
          );
        } else {
          // peluches 🧸: single
          _queueItems = [item];
          _queueVariants = [variant];
          _syncQueueToHandler();

          await _player.setAudioSource(
            AudioSource.uri(fileUri, tag: _buildBackgroundItem(item)),
            initialPosition: Duration.zero,
          );
        }

        // peluches 🧸: set current
        _currentItem = item;
        _currentVariant = variant;
        currentItem.value = item;
        currentVariant.value = variant;
        _updateWidget();

        _persistLastItem(item, variant);
        _keepLastItem = true;

        // peluches 🧸: resync handler para notificación/lockscreen
        _syncQueueToHandler();

        await _player.setVolume(volume.value);
        await _applyEqFromSettings();

        if (autoPlay) {
          await _player.play();
        } else {
          isLoading.value = false;
          isPlaying.value = false;
          state.value = PlaybackState.paused;
        }
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
      if (queue != null && queue.isNotEmpty) {
        final built = _buildQueueSources(queue, item, variant);
        _queueItems = built.items;
        _queueVariants = built.variants;
        _syncQueueToHandler();

        await _player.setAudioSource(
          ConcatenatingAudioSource(children: built.sources),
          initialIndex: built.startIndex,
          initialPosition: Duration.zero,
        );
      } else {
        _queueItems = [item];
        _queueVariants = [variant];
        _syncQueueToHandler();

        await _player.setAudioSource(
          AudioSource.uri(Uri.parse(url), tag: _buildBackgroundItem(item)),
          initialPosition: Duration.zero,
        );
      }

      _currentItem = item;
      _currentVariant = variant;
      currentItem.value = item;
      currentVariant.value = variant;
      _updateWidget();

      _persistLastItem(item, variant);
      _keepLastItem = true;

      _syncQueueToHandler();

      await _player.setVolume(volume.value);
      await _applyEqFromSettings();
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

  // ==========================================================================
  // QUEUE BUILDING
  // ==========================================================================
  MediaVariant? _pickAudioVariant(MediaItem item) {
    // peluches 🧸: preferimos local válido
    for (final v in item.variants) {
      if (v.kind == MediaVariantKind.audio &&
          v.localPath != null &&
          v.localPath!.trim().isNotEmpty &&
          v.isValid) {
        return v;
      }
    }
    // peluches 🧸: si no, cualquier audio válido
    for (final v in item.variants) {
      if (v.kind == MediaVariantKind.audio && v.isValid) return v;
    }
    return null;
  }

  _QueueBuild _buildQueueSources(
    List<MediaItem> queue,
    MediaItem currentItem,
    MediaVariant currentVariant,
  ) {
    final sources = <AudioSource>[];
    final items = <MediaItem>[];
    final variants = <MediaVariant>[];
    var startIndex = 0;

    for (final item in queue) {
      final v = item.id == currentItem.id
          ? currentVariant
          : (_pickAudioVariant(item) ?? currentVariant);

      if (!v.isValid) continue;

      final localPath = v.localPath?.trim();
      final uri = (localPath != null && localPath.isNotEmpty)
          ? Uri.file(localPath)
          : Uri.parse(
              '${ApiConfig.baseUrl}/api/v1/media/file/${item.fileId.trim()}/audio/${v.format.trim()}',
            );

      sources.add(AudioSource.uri(uri, tag: _buildBackgroundItem(item)));
      items.add(item);
      variants.add(v);

      // peluches 🧸: detecta el índice inicial (por id o publicId)
      if (item.id == currentItem.id ||
          (currentItem.publicId.trim().isNotEmpty &&
              item.publicId.trim() == currentItem.publicId.trim())) {
        startIndex = items.length - 1;
      }
    }

    return _QueueBuild(
      sources: sources,
      items: items,
      variants: variants,
      startIndex: startIndex,
    );
  }

  // ==========================================================================
  // BACKGROUND MEDIA ITEM (audio_service)
  // ==========================================================================
  /// peluches 🧸:
  /// Esto es CRÍTICO para la notificación:
  /// - id, title, artist
  /// - artUri (si hay)
  /// - duration (si existe) -> sin duration la barra de progreso sufre
  aud.MediaItem _buildBackgroundItem(MediaItem item) {
    Uri? artUri;

    final local = item.thumbnailLocalPath?.trim();
    if (local != null && local.isNotEmpty) {
      artUri = Uri.file(local);
    } else {
      final remote = item.thumbnail?.trim();
      if (remote != null && remote.isNotEmpty) {
        artUri = Uri.tryParse(remote);
      }
    }

    final durSec = item.effectiveDurationSeconds;
    final dur = (durSec != null && durSec > 0)
        ? Duration(seconds: durSec)
        : null;

    String? subtitle = item.displaySubtitle.isNotEmpty
        ? item.displaySubtitle
        : null;
    if (Get.isRegistered<SettingsController>()) {
      final settings = Get.find<SettingsController>();
      final remaining = settings.sleepRemaining.value;
      if (settings.sleepTimerEnabled.value && remaining > Duration.zero) {
        final tag = _formatRemaining(remaining);
        subtitle = (subtitle == null || subtitle.isEmpty)
            ? 'Temporizador $tag'
            : '$subtitle\nTemporizador $tag';
      }
    }

    return aud.MediaItem(
      id: item.id,
      title: item.title,
      artist: subtitle,
      duration: dur,
      artUri: artUri,
    );
  }

  String _formatRemaining(Duration d) {
    final total = d.inSeconds;
    final mm = (total ~/ 60).toString().padLeft(2, '0');
    final ss = (total % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  // ==========================================================================
  // HANDLER SYNC (NOTIFICATION)
  // ==========================================================================
  /// peluches 🧸:
  /// Sincroniza:
  /// - queue del handler
  /// - mediaItem actual
  void _syncQueueToHandler() {
    final handler = _handler;
    if (handler == null) return;

    if (_queueItems.isNotEmpty) {
      handler.updateQueue(_queueItems.map(_buildBackgroundItem).toList());
    }
    if (_currentItem != null) {
      handler.updateMediaItem(_buildBackgroundItem(_currentItem!));
    }

    _updateWidget();
  }

  void refreshNotification() {
    if (_currentItem == null) return;
    _syncQueueToHandler();
  }

  // ==========================================================================
  // STOP + DISMISS NOTIFICATION
  // ==========================================================================
  Future<void> stopAndDismissNotification() async {
    await stop();
    final handler = _handler;
    if (handler != null) {
      try {
        await handler.stop();
      } catch (_) {
        // peluches 🧸: ignorar si falla el stop del handler
      }
    }
  }

  // ==========================================================================
  // APPLY EQ FROM SETTINGS
  // ==========================================================================
  Future<void> _applyEqFromSettings() async {
    if (_equalizer == null) return;
    if (!Get.isRegistered<SettingsController>()) return;

    final settings = Get.find<SettingsController>();
    try {
      await setEqEnabled(settings.eqEnabled.value);
      if (settings.eqGains.isEmpty) return;

      final params = await _equalizer!.parameters;
      final bands = params.bands.length;
      final gains = settings.eqGains;

      for (var i = 0; i < bands && i < gains.length; i++) {
        await params.bands[i].setGain(gains[i]);
      }
    } catch (_) {
      // peluches 🧸: ignorar errores del EQ (no crashear reproducción)
    }
  }

  // ==========================================================================
  // TOGGLE / PAUSE / STOP
  // ==========================================================================
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
    _updateWidget();
  }

  Future<void> _updateWidget() async {
    if (!Platform.isAndroid) return;

    final item = _currentItem;
    final hasItem = item != null;
    final title = hasItem ? item!.title : 'Listenfy';
    final artist = hasItem ? item.displaySubtitle : '';
    String artPath = '';
    if (hasItem) {
      final local = item!.thumbnailLocalPath?.trim();
      if (local != null && local.isNotEmpty) {
        artPath = local;
      }
    }

    Color barColor = const Color(0xFF1E2633);
    if (Get.isRegistered<ThemeController>()) {
      final theme = Get.find<ThemeController>();
      barColor = theme.palette.value.primary;
    }
    final logoColor =
        barColor.computeLuminance() > 0.55 ? Colors.black : Colors.white;

    try {
      await _widgetChannel.invokeMethod('updateWidget', {
        'title': title,
        'artist': artist,
        'artPath': artPath,
        'playing': isPlaying.value,
        'barColor': barColor.value,
        'logoColor': logoColor.value,
      });
    } catch (_) {
      // peluches 🧸: si falla el widget, no afecta reproducción
    }
  }

  // ==========================================================================
  // LAST ITEM PERSISTENCE
  // ==========================================================================
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
      // peluches 🧸: ignorar si la data guardada está corrupta
    }
  }

  // ==========================================================================
  // CLOSE
  // ==========================================================================
  @override
  void onClose() {
    _playerStateSub?.cancel();
    _indexSub?.cancel();
    _player.dispose();
    super.onClose();
  }
}

// ============================================================================
// QUEUE BUILD RESULT MODEL
// ============================================================================
class _QueueBuild {
  final List<AudioSource> sources;
  final List<MediaItem> items;
  final List<MediaVariant> variants;
  final int startIndex;

  const _QueueBuild({
    required this.sources,
    required this.items,
    required this.variants,
    required this.startIndex,
  });
}

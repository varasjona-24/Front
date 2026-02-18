// ============================================================================
// IMPORTS
// ============================================================================
import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:audio_session/audio_session.dart';
import 'package:audio_service/audio_service.dart' as aud;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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
class AudioService extends GetxService {
  static const MethodChannel _widgetChannel = MethodChannel(
    'listenfy/player_widget',
  );

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

  // Guardamos el orden “lineal” original para poder volver al desactivar shuffle.
  List<MediaItem> _linearItems = [];
  List<MediaVariant> _linearVariants = [];
  bool _shuffleEnabled = false;

  List<MediaItem> get queueItems => List<MediaItem>.from(_queueItems);
  int get currentQueueIndex {
    final idx = _player.currentIndex;
    if (idx == null || idx < 0 || idx >= _queueItems.length) return 0;
    return idx;
  }

  MediaItem? queueItemAt(int index) {
    if (index < 0 || index >= _queueItems.length) return null;
    return _queueItems[index];
  }

  // ==========================================================================
  // SERIALIZATION (EVITA RACES EN PLAY/SHUFFLE/NEXT)
  // ==========================================================================
  Future<void>? _op;
  Future<void> _runExclusive(Future<void> Function() action) async {
    final prev = _op;
    final task = () async {
      if (prev != null) {
        try {
          await prev;
        } catch (_) {}
      }
      await action();
    }();
    _op = task;
    try {
      await task;
    } finally {
      if (identical(_op, task)) _op = null;
    }
  }

  // ==========================================================================
  // CONSTRUCTOR
  // ==========================================================================
  AudioService() : _equalizer = Platform.isAndroid ? AndroidEqualizer() : null {
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
  aud.MediaItem buildBackgroundItem(MediaItem item) =>
      _buildBackgroundItem(item);

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

  // Encuentra el index actual dentro del orden LINEAL (para preservar track).
  int _findLinearIndexFor(MediaItem item, MediaVariant variant) {
    for (var i = 0; i < _linearItems.length; i++) {
      final it = _linearItems[i];
      final v = _linearVariants[i];
      if (it.id == item.id &&
          v.kind == variant.kind &&
          v.format == variant.format) {
        return i;
      }
      // fallback por publicId si aplica
      final pid = item.publicId.trim();
      if (pid.isNotEmpty && it.publicId.trim() == pid) {
        return i;
      }
    }
    return 0;
  }

  // ==========================================================================
  // LIFECYCLE
  // ==========================================================================
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
    await _prepareLastItem(); // 🔧 NUEVO: precarga la última canción en pausa
    _updateWidget();

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

      _updateWidget();
    });

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

      _syncQueueToHandler();
    });
  }

  // 🔧 NUEVO: precarga la última canción sin reproducir
  Future<void> _prepareLastItem() async {
    final item = _currentItem;
    final variant = _currentVariant;
    if (item == null || variant == null || !variant.isValid) return;

    try {
      final source = _audioSourceFor(item, variant);
      await _player.setAudioSource(source, initialPosition: Duration.zero);
      _keepLastItem = true;
      state.value = PlaybackState.paused;
      isPlaying.value = false;
      // También actualizamos las listas lineales y de cola con este único ítem
      _linearItems = [item];
      _linearVariants = [variant];
      _queueItems = [item];
      _queueVariants = [variant];
      _syncQueueToHandler();
    } catch (e) {
      // Si falla, limpiamos todo
      _currentItem = null;
      _currentVariant = null;
      state.value = PlaybackState.stopped;
      _linearItems = [];
      _linearVariants = [];
      _queueItems = [];
      _queueVariants = [];
    }
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
  // NEXT / PREVIOUS (AHORA ENVUELTOS EN _runExclusive)
  // ==========================================================================
  Future<void> next() async {
    await _runExclusive(() async {
      if (!hasSourceLoaded || !_player.hasNext) return;
      await _player.seekToNext();
    });
  }

  Future<void> previous() async {
    await _runExclusive(() async {
      if (!hasSourceLoaded || !_player.hasPrevious) return;
      await _player.seekToPrevious();
    });
  }

  // ==========================================================================
  // SHUFFLE (CON ROLLBACK EN CASO DE ERROR)
  // ==========================================================================
  bool get shuffleEnabled => _shuffleEnabled;

  Future<void> setShuffle(bool enabled) async {
    await _runExclusive(() async {
      if (_shuffleEnabled == enabled) return;

      // Si no hay cola o no hay source cargado, solo guardamos el flag
      if (_linearItems.isEmpty || _linearVariants.isEmpty || !hasSourceLoaded) {
        _shuffleEnabled = enabled;
        return;
      }

      final playing = _player.playing;
      final pos = _player.position;

      // Preservar pista actual (por item/variant actual)
      final curItem = _currentItem ?? _linearItems.first;
      final curVar = _currentVariant ?? _linearVariants.first;
      final linearIndex = _findLinearIndexFor(curItem, curVar);

      // Guardar estado anterior por si falla
      final oldQueueItems = _queueItems;
      final oldQueueVariants = _queueVariants;

      try {
        if (enabled) {
          // Construir orden shuffle con current primero
          final indices = List<int>.generate(_linearItems.length, (i) => i);
          indices.remove(linearIndex);
          indices.shuffle(Random());
          indices.insert(0, linearIndex);

          _queueItems = indices.map((i) => _linearItems[i]).toList();
          _queueVariants = indices.map((i) => _linearVariants[i]).toList();

          final sources = _queueItems.asMap().entries.map((e) {
            final i = e.key;
            final item = e.value;
            final v = _queueVariants[i];
            return _audioSourceFor(item, v);
          }).toList();

          await _player.setAudioSource(
            ConcatenatingAudioSource(children: sources),
            initialIndex: 0,
            initialPosition: pos,
          );

          _shuffleEnabled = true;
        } else {
          // Volver a lineal preservando pista actual
          _queueItems = List<MediaItem>.from(_linearItems);
          _queueVariants = List<MediaVariant>.from(_linearVariants);

          final sources = _queueItems.asMap().entries.map((e) {
            final i = e.key;
            final item = e.value;
            final v = _queueVariants[i];
            return _audioSourceFor(item, v);
          }).toList();

          await _player.setAudioSource(
            ConcatenatingAudioSource(children: sources),
            initialIndex: linearIndex.clamp(0, _queueItems.length - 1),
            initialPosition: pos,
          );

          _shuffleEnabled = false;
        }

        // Mantener estado play/pause
        if (playing) {
          await _player.play();
        } else {
          await _player.pause();
        }

        _syncQueueToHandler();
        _updateWidget();
      } catch (e) {
        // Restaurar estado anterior en caso de error
        _queueItems = oldQueueItems;
        _queueVariants = oldQueueVariants;
        rethrow;
      }
    });
  }

  // ==========================================================================
  // EQ (ANDROID)
  // ==========================================================================
  Future<AndroidEqualizerParameters?> getEqParameters() async {
    final eq = _equalizer;
    if (eq == null) return null;
    return eq.parameters;
  }

  Future<void> setEqEnabled(bool enabled) async {
    final eq = _equalizer;
    if (eq == null) return;
    await eq.setEnabled(enabled);
  }

  Future<void> setEqBandGain(int index, double gain) async {
    final eq = _equalizer;
    if (eq == null) return;
    final params = await eq.parameters;
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
  // PLAY (MAIN) CON ROLLBACK Y MEJORA EN SELECCIÓN DE VARIANTES
  // ==========================================================================
  Future<void> play(
    MediaItem item,
    MediaVariant variant, {
    bool autoPlay = true,
    List<MediaItem>? queue,
    int? queueIndex,
    bool forceReload = false,
  }) async {
    await _runExclusive(() async {
      if (!variant.isValid) {
        throw Exception(
          'No existe archivo para reproducir (variant inválido).',
        );
      }

      final sameTrack = isSameTrack(item, variant);
      if (!forceReload && sameTrack && hasSourceLoaded) {
        if (!_player.playing && autoPlay) await _player.play();
        return;
      }

      await _player.stop();

      isLoading.value = true;
      isPlaying.value = false;
      state.value = PlaybackState.loading;

      // Guardar estado anterior por si falla
      final oldLinearItems = _linearItems;
      final oldLinearVariants = _linearVariants;
      final oldQueueItems = _queueItems;
      final oldQueueVariants = _queueVariants;

      try {
        // ---------------------------------------------------------------
        // Construcción de cola lineal (base)
        // ---------------------------------------------------------------
        if (queue != null && queue.isNotEmpty) {
          final built = _buildQueueSources(
            queue,
            item,
            variant,
            queueIndex: queueIndex,
          );

          _linearItems = built.items;
          _linearVariants = built.variants;

          // Aplicar shuffle si está activo (reordenamos)
          if (_shuffleEnabled) {
            final startLinear = built.startIndex.clamp(
              0,
              _linearItems.length - 1,
            );

            final indices = List<int>.generate(_linearItems.length, (i) => i);
            indices.remove(startLinear);
            indices.shuffle(Random());
            indices.insert(0, startLinear);

            _queueItems = indices.map((i) => _linearItems[i]).toList();
            _queueVariants = indices.map((i) => _linearVariants[i]).toList();

            final sources = _queueItems.asMap().entries.map((e) {
              final i = e.key;
              return _audioSourceFor(_queueItems[i], _queueVariants[i]);
            }).toList();

            await _player.setAudioSource(
              ConcatenatingAudioSource(children: sources),
              initialIndex: 0,
              initialPosition: Duration.zero,
            );
          } else {
            _queueItems = List<MediaItem>.from(_linearItems);
            _queueVariants = List<MediaVariant>.from(_linearVariants);

            await _player.setAudioSource(
              ConcatenatingAudioSource(children: built.sources),
              initialIndex: built.startIndex,
              initialPosition: Duration.zero,
            );
          }
        } else {
          // Single item
          _linearItems = [item];
          _linearVariants = [variant];
          _queueItems = [item];
          _queueVariants = [variant];

          await _player.setAudioSource(
            _audioSourceFor(item, variant),
            initialPosition: Duration.zero,
          );
        }

        // set current
        _currentItem = item;
        _currentVariant = variant;
        currentItem.value = item;
        currentVariant.value = variant;

        _persistLastItem(item, variant);
        _keepLastItem = true;

        _syncQueueToHandler();
        _updateWidget();

        await _player.setVolume(volume.value);
        await _applyEqFromSettings();

        if (autoPlay) {
          await _player.play();
        } else {
          state.value = PlaybackState.paused;
          isPlaying.value = false;
        }
      } on PlayerException catch (pe) {
        // Restaurar estado anterior
        _linearItems = oldLinearItems;
        _linearVariants = oldLinearVariants;
        _queueItems = oldQueueItems;
        _queueVariants = oldQueueVariants;

        await _player.stop();
        _currentItem = null;
        _currentVariant = null;

        state.value = PlaybackState.stopped;
        isPlaying.value = false;

        throw Exception(
          'Error al reproducir: ${pe.message} (code: ${pe.code})',
        );
      } catch (e) {
        // Restaurar estado anterior
        _linearItems = oldLinearItems;
        _linearVariants = oldLinearVariants;
        _queueItems = oldQueueItems;
        _queueVariants = oldQueueVariants;

        await _player.stop();
        _currentItem = null;
        _currentVariant = null;

        state.value = PlaybackState.stopped;
        isPlaying.value = false;

        rethrow;
      } finally {
        isLoading.value = false;
      }
    });
  }

  // Construye AudioSource para un item/variant (local vs remoto)
  AudioSource _audioSourceFor(MediaItem item, MediaVariant v) {
    final localPath = v.localPath?.trim();
    final hasLocal = localPath != null && localPath.isNotEmpty;
    if (hasLocal) {
      return AudioSource.uri(
        Uri.file(localPath),
        tag: _buildBackgroundItem(item),
      );
    }

    final kind = (v.kind == MediaVariantKind.video) ? 'video' : 'audio';
    final fileId = item.fileId.trim();
    final format = v.format.trim();
    final url = '${ApiConfig.baseUrl}/api/v1/media/file/$fileId/$kind/$format';

    return AudioSource.uri(Uri.parse(url), tag: _buildBackgroundItem(item));
  }

  // ==========================================================================
  // QUEUE BUILDING (MEJORADO CON _getValidAudioVariant)
  // ==========================================================================

  // 🔧 NUEVO: obtiene la primera variante de audio válida (local > remota)
  MediaVariant? _getValidAudioVariant(MediaItem item) {
    // Priorizar locales
    for (final v in item.variants) {
      if (v.kind == MediaVariantKind.audio &&
          v.isValid &&
          v.localPath != null &&
          v.localPath!.isNotEmpty) {
        return v;
      }
    }
    // Luego cualquier audio remoto válido
    for (final v in item.variants) {
      if (v.kind == MediaVariantKind.audio && v.isValid) {
        return v;
      }
    }
    return null;
  }

  _QueueBuild _buildQueueSources(
    List<MediaItem> queue,
    MediaItem currentItem,
    MediaVariant currentVariant, {
    int? queueIndex,
  }) {
    final sources = <AudioSource>[];
    final items = <MediaItem>[];
    final variants = <MediaVariant>[];
    var startIndex = 0;

    final hasExplicitQueueIndex =
        queueIndex != null && queueIndex >= 0 && queueIndex < queue.length;
    var explicitStartFound = false;

    for (var i = 0; i < queue.length; i++) {
      final item = queue[i];
      MediaVariant? v;
      if (item.id == currentItem.id) {
        v = currentVariant;
      } else {
        v = _getValidAudioVariant(item); // 🔧 usa el nuevo método
      }
      if (v == null || !v.isValid) continue; // Saltar ítems no reproducibles

      sources.add(_audioSourceFor(item, v));
      items.add(item);
      variants.add(v);

      if (hasExplicitQueueIndex && i == queueIndex) {
        startIndex = items.length - 1;
        explicitStartFound = true;
        continue;
      }

      if (!explicitStartFound &&
          (item.id == currentItem.id ||
              (currentItem.publicId.trim().isNotEmpty &&
                  item.publicId.trim() == currentItem.publicId.trim()))) {
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
      } catch (_) {}
    }
  }

  // ==========================================================================
  // APPLY EQ FROM SETTINGS
  // ==========================================================================
  Future<void> _applyEqFromSettings() async {
    final eq = _equalizer;
    if (eq == null) return;
    if (!Get.isRegistered<SettingsController>()) return;

    final settings = Get.find<SettingsController>();
    try {
      await setEqEnabled(settings.eqEnabled.value);
      if (settings.eqGains.isEmpty) return;

      final params = await eq.parameters;
      final bands = params.bands.length;
      final gains = settings.eqGains;

      for (var i = 0; i < bands && i < gains.length; i++) {
        await params.bands[i].setGain(gains[i]);
      }
    } catch (_) {}
  }

  // ==========================================================================
  // TOGGLE / PAUSE / STOP (MEJORADO)
  // ==========================================================================
  Future<void> toggle() async {
    if (_player.playing) {
      await _player.pause();
      return;
    }
    if (!hasSourceLoaded) {
      // Si no hay fuente pero tenemos último ítem, intentar reproducirlo
      if (_currentItem != null && _currentVariant != null) {
        await play(_currentItem!, _currentVariant!, autoPlay: true);
      } else {
        print('❌ No source loaded and no last item to restore.');
      }
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

  // ==========================================================================
  // WIDGET
  // ==========================================================================
  Future<void> _updateWidget() async {
    if (!Platform.isAndroid) return;

    final item = _currentItem;
    String title = 'Listenfy';
    String artist = '';
    String artPath = '';

    if (item != null) {
      title = item.title;
      artist = item.displaySubtitle;
      artPath = await _resolveWidgetArtPath(item);
    }

    Color barColor = const Color(0xFF1E2633);
    if (Get.isRegistered<ThemeController>()) {
      final theme = Get.find<ThemeController>();
      barColor = theme.palette.value.primary;
    }
    final logoColor = barColor.computeLuminance() > 0.55
        ? Colors.black
        : Colors.white;

    try {
      await _widgetChannel.invokeMethod('updateWidget', {
        'title': title,
        'artist': artist,
        'artPath': artPath,
        'playing': isPlaying.value,
        'barColor': barColor.value,
        'logoColor': logoColor.value,
      });
    } catch (_) {}
  }

  Future<String> _resolveWidgetArtPath(MediaItem item) async {
    final local = item.thumbnailLocalPath?.trim();
    if (local != null && local.isNotEmpty) {
      final file = File(local);
      if (await file.exists()) return file.path;
    }

    final remote = item.thumbnail?.trim();
    if (remote == null || remote.isEmpty) return '';

    final uri = Uri.tryParse(remote);
    if (uri == null || (!uri.isScheme('http') && !uri.isScheme('https'))) {
      return '';
    }

    try {
      final dir = await getTemporaryDirectory();
      final fileName = 'widget_thumb_${remote.hashCode}.img';
      final file = File(p.join(dir.path, fileName));
      if (await file.exists() && await file.length() > 0) {
        return file.path;
      }

      final client = HttpClient();
      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        await file.create(recursive: true);
        await response.pipe(file.openWrite());
        return file.path;
      }
    } catch (_) {}

    return '';
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
    } catch (_) {}
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

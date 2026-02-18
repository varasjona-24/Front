import 'dart:async';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:audio_service/audio_service.dart' as aud;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../config/api_config.dart';
import '../controllers/theme_controller.dart';
import '../models/media_item.dart';
import '../../Modules/settings/controller/settings_controller.dart';

enum PlaybackState { stopped, loading, playing, paused }

class AudioService extends GetxService {
  static const MethodChannel _widgetChannel =
      MethodChannel('listenfy/player_widget');

  final GetStorage _storage = GetStorage();
  static const _lastItemKey = 'audio_last_item';
  static const _lastVariantKey = 'audio_last_variant';

  final AndroidEqualizer? _equalizer;
  late final AudioPlayer _player;

  dynamic _handler;

  bool _keepLastItem = false;
  bool get keepLastItem => _keepLastItem;

  bool get eqSupported => _equalizer != null;
  AudioPlayer get player => _player;

  final Rx<PlaybackState> state = PlaybackState.stopped.obs;
  final RxBool isPlaying = false.obs;
  final RxBool isLoading = false.obs;

  MediaItem? _currentItem;
  MediaVariant? _currentVariant;

  final Rxn<MediaItem> currentItem = Rxn<MediaItem>();
  final Rxn<MediaVariant> currentVariant = Rxn<MediaVariant>();

  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<int?>? _indexSub;

  List<MediaItem> _queueItems = <MediaItem>[];
  List<MediaVariant> _queueVariants = <MediaVariant>[];

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

  AudioService() : _equalizer = Platform.isAndroid ? AndroidEqualizer() : null {
    if (Platform.isAndroid) {
      _player = AudioPlayer(
        audioPipeline: AudioPipeline(androidAudioEffects: [_equalizer!]),
      );
    } else {
      _player = AudioPlayer();
    }
  }

  aud.MediaItem buildBackgroundItem(MediaItem item) =>
      _buildBackgroundItem(item);

  void attachHandler(dynamic handler) {
    _handler = handler;
    _syncQueueToHandler();
    _updateWidget();
  }

  bool get hasSourceLoaded => _player.processingState != ProcessingState.idle;

  bool isSameTrack(MediaItem item, MediaVariant variant) {
    return _currentItem?.id == item.id &&
        _currentVariant?.kind == variant.kind &&
        _currentVariant?.format == variant.format;
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
      } else if (proc == ProcessingState.completed || proc == ProcessingState.idle) {
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
      if (idx < 0 || idx >= _queueItems.length) return;
      if (idx >= _queueVariants.length) return;

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

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<ProcessingState> get processingStateStream =>
      _player.processingStateStream;
  Stream<int?> get androidAudioSessionIdStream =>
      _player.androidAudioSessionIdStream;
  int? get androidAudioSessionId => _player.androidAudioSessionId;

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

  Future<void> setSpeed(double value) async {
    speed.value = value;
    await _player.setSpeed(value);
  }

  Future<void> setVolume(double value) async {
    final clamped = value.clamp(0.0, 1.0);
    volume.value = clamped;
    await _player.setVolume(clamped);
  }

  Future<void> setShuffle(bool enabled) async {
    if (!hasSourceLoaded) return;
    await _player.setShuffleModeEnabled(enabled);
    if (enabled) await _player.shuffle();
  }

  Future<void> next() async {
    if (!hasSourceLoaded || !_player.hasNext) return;
    await _player.seekToNext();
  }

  Future<void> previous() async {
    if (!hasSourceLoaded || !_player.hasPrevious) return;
    await _player.seekToPrevious();
  }

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
        throw Exception('No existe archivo para reproducir (variant inválido).');
      }

      if (!forceReload && isSameTrack(item, variant) && hasSourceLoaded) {
        if (autoPlay && !_player.playing) await _player.play();
        return;
      }

      isLoading.value = true;
      isPlaying.value = false;
      state.value = PlaybackState.loading;

      try {
        final built = _buildPlaybackQueue(
          explicitQueue: queue,
          selectedItem: item,
          selectedVariant: variant,
          queueIndex: queueIndex,
        );

        _queueItems = built.items;
        _queueVariants = built.variants;

        await _player.stop();
        await _player.setAudioSources(
          built.sources,
          initialIndex: built.startIndex,
          initialPosition: Duration.zero,
        );

        final selected = built.startIndex;
        _currentItem = _queueItems[selected];
        _currentVariant = _queueVariants[selected];

        currentItem.value = _currentItem;
        currentVariant.value = _currentVariant;

        _persistLastItem(_currentItem!, _currentVariant!);
        _keepLastItem = true;

        await _player.setVolume(volume.value);
        await _applyEqFromSettings();

        _syncQueueToHandler();
        _updateWidget();

        if (autoPlay) {
          await _player.play();
        } else {
          await _player.pause();
          state.value = PlaybackState.paused;
          isPlaying.value = false;
        }
      } on PlayerException catch (e) {
        await _resetAfterPlaybackError();
        throw Exception('Error al reproducir: ${e.message} (code: ${e.code})');
      } catch (_) {
        await _resetAfterPlaybackError();
        rethrow;
      } finally {
        isLoading.value = false;
      }
    });
  }

  _BuiltQueue _buildPlaybackQueue({
    required MediaItem selectedItem,
    required MediaVariant selectedVariant,
    List<MediaItem>? explicitQueue,
    int? queueIndex,
  }) {
    final input = explicitQueue == null || explicitQueue.isEmpty
        ? <MediaItem>[selectedItem]
        : explicitQueue;

    final items = <MediaItem>[];
    final variants = <MediaVariant>[];
    final sources = <AudioSource>[];

    int startIndex = 0;
    final useExplicitIndex =
        queueIndex != null && queueIndex >= 0 && queueIndex < input.length;
    var explicitMatched = false;

    for (var i = 0; i < input.length; i++) {
      final entry = input[i];
      final v = _resolveVariantForQueueEntry(
        queueEntry: entry,
        selectedItem: selectedItem,
        selectedVariant: selectedVariant,
      );
      if (v == null || !v.isValid) continue;

      items.add(entry);
      variants.add(v);
      sources.add(_audioSourceFor(entry, v));

      if (useExplicitIndex && i == queueIndex) {
        startIndex = items.length - 1;
        explicitMatched = true;
        continue;
      }

      if (!explicitMatched && _sameItem(entry, selectedItem)) {
        startIndex = items.length - 1;
      }
    }

    if (items.isEmpty) {
      items.add(selectedItem);
      variants.add(selectedVariant);
      sources.add(_audioSourceFor(selectedItem, selectedVariant));
      startIndex = 0;
    }

    if (startIndex < 0 || startIndex >= items.length) {
      startIndex = 0;
    }

    return _BuiltQueue(
      items: items,
      variants: variants,
      sources: sources,
      startIndex: startIndex,
    );
  }

  MediaVariant? _resolveVariantForQueueEntry({
    required MediaItem queueEntry,
    required MediaItem selectedItem,
    required MediaVariant selectedVariant,
  }) {
    if (_sameItem(queueEntry, selectedItem)) return selectedVariant;

    for (final v in queueEntry.variants) {
      final local = v.localPath?.trim();
      if (v.kind == MediaVariantKind.audio &&
          v.isValid &&
          local != null &&
          local.isNotEmpty) {
        return v;
      }
    }

    for (final v in queueEntry.variants) {
      if (v.kind == MediaVariantKind.audio && v.isValid) return v;
    }

    return null;
  }

  bool _sameItem(MediaItem a, MediaItem b) {
    if (a.id == b.id) return true;
    final ap = a.publicId.trim();
    final bp = b.publicId.trim();
    return ap.isNotEmpty && bp.isNotEmpty && ap == bp;
  }

  AudioSource _audioSourceFor(MediaItem item, MediaVariant variant) {
    final localPath = variant.localPath?.trim();
    if (localPath != null && localPath.isNotEmpty) {
      final file = File(localPath);
      if (!file.existsSync()) {
        throw Exception('Archivo local no encontrado: $localPath');
      }
      return AudioSource.uri(
        Uri.file(localPath),
        tag: _buildBackgroundItem(item),
      );
    }

    final kind = variant.kind == MediaVariantKind.video ? 'video' : 'audio';
    final fileId = item.fileId.trim();
    final format = variant.format.trim();

    if (fileId.isEmpty || format.isEmpty) {
      throw Exception('Faltan datos para reproducción remota.');
    }

    final url = '${ApiConfig.baseUrl}/api/v1/media/file/$fileId/$kind/$format';
    return AudioSource.uri(Uri.parse(url), tag: _buildBackgroundItem(item));
  }

  Future<void> _resetAfterPlaybackError() async {
    try {
      await _player.stop();
    } catch (_) {}

    _currentItem = null;
    _currentVariant = null;
    currentItem.value = null;
    currentVariant.value = null;

    isPlaying.value = false;
    state.value = PlaybackState.stopped;
  }

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

    final sec = item.effectiveDurationSeconds;
    final duration = (sec != null && sec > 0) ? Duration(seconds: sec) : null;

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
      duration: duration,
      artUri: artUri,
    );
  }

  String _formatRemaining(Duration value) {
    final total = value.inSeconds;
    final mm = (total ~/ 60).toString().padLeft(2, '0');
    final ss = (total % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

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

  Future<void> stopAndDismissNotification() async {
    await stop();
    final handler = _handler;
    if (handler != null) {
      try {
        await handler.stop();
      } catch (_) {}
    }
  }

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

  Future<void> toggle() async {
    if (_player.playing) {
      await _player.pause();
      return;
    }

    if (hasSourceLoaded) {
      await _player.play();
      return;
    }

    if (_currentItem != null && _currentVariant != null) {
      await play(_currentItem!, _currentVariant!, autoPlay: true);
    }
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

  @override
  void onClose() {
    _playerStateSub?.cancel();
    _indexSub?.cancel();
    _player.dispose();
    super.onClose();
  }
}

class _BuiltQueue {
  final List<MediaItem> items;
  final List<MediaVariant> variants;
  final List<AudioSource> sources;
  final int startIndex;

  const _BuiltQueue({
    required this.items,
    required this.variants,
    required this.sources,
    required this.startIndex,
  });
}

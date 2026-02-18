import 'dart:io';
import 'dart:math';

import 'package:audio_session/audio_session.dart';
import 'package:audio_service/audio_service.dart' as aud;
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:just_audio/just_audio.dart';

import '../config/api_config.dart';
import '../models/media_item.dart';

enum PlaybackState { stopped, loading, playing, paused }

class AudioService extends GetxService {
  final AudioPlayer _player = AudioPlayer();
  final GetStorage _storage = GetStorage();

  static const _lastItemKey = 'audio_last_item';
  static const _lastVariantKey = 'audio_last_variant';
  static const _shuffleEnabledKey = 'audio_shuffle_enabled';
  static const _speedKey = 'audio_speed';

  final Rx<PlaybackState> state = PlaybackState.stopped.obs;
  final RxBool isPlaying = false.obs;
  final RxBool isLoading = false.obs;
  final RxDouble speed = 1.0.obs;
  final RxDouble volume = 1.0.obs;

  final Rxn<MediaItem> currentItem = Rxn<MediaItem>();
  final Rxn<MediaVariant> currentVariant = Rxn<MediaVariant>();

  bool _keepLastItem = false;
  bool get keepLastItem => _keepLastItem;

  dynamic _handler;
  List<MediaItem> _queueItems = <MediaItem>[];
  List<MediaVariant> _queueVariants = <MediaVariant>[];
  List<MediaItem> _linearItems = <MediaItem>[];
  List<MediaVariant> _linearVariants = <MediaVariant>[];
  int _activeIndex = 0;
  bool _shuffleEnabled = false;
  bool get shuffleEnabled => _shuffleEnabled;

  bool get eqSupported => false;
  int? get androidAudioSessionId => _player.androidAudioSessionId;
  Stream<int?> get androidAudioSessionIdStream =>
      _player.androidAudioSessionIdStream;

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<ProcessingState> get processingStateStream =>
      _player.processingStateStream;

  bool get hasSourceLoaded => _player.processingState != ProcessingState.idle;
  List<MediaItem> get queueItems => List<MediaItem>.from(_queueItems);
  int get currentQueueIndex {
    final idx = _player.currentIndex ?? _activeIndex;
    if (idx < 0 || idx >= _queueItems.length) return 0;
    return idx;
  }

  @override
  Future<void> onInit() async {
    super.onInit();

    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    _shuffleEnabled = _storage.read<bool>(_shuffleEnabledKey) ?? false;
    final storedSpeed = _storage.read<double>(_speedKey);
    if (storedSpeed != null && storedSpeed > 0) {
      speed.value = storedSpeed;
      await _player.setSpeed(storedSpeed);
    }
    _restoreLastItem();

    _player.playerStateStream.listen((ps) {
      final loading = ps.processingState == ProcessingState.loading ||
          ps.processingState == ProcessingState.buffering;
      isLoading.value = loading;
      isPlaying.value = ps.playing;

      if (loading) {
        state.value = PlaybackState.loading;
      } else if (ps.playing) {
        state.value = PlaybackState.playing;
      } else if (ps.processingState == ProcessingState.ready ||
          ps.processingState == ProcessingState.completed) {
        state.value = PlaybackState.paused;
      } else {
        state.value = PlaybackState.stopped;
      }

      _notifyHandler();
    });

    _player.currentIndexStream.listen((idx) {
      if (idx == null) return;
      if (idx < 0 || idx >= _queueItems.length) return;
      if (idx >= _queueVariants.length) return;

      _activeIndex = idx;
      final item = _queueItems[idx];
      final variant = _queueVariants[idx];
      currentItem.value = item;
      currentVariant.value = variant;
      _persistLastItem(item, variant);
      _keepLastItem = true;
      _notifyHandler();
    });
  }

  @override
  void onClose() {
    _player.dispose();
    super.onClose();
  }

  void attachHandler(dynamic handler) {
    _handler = handler;
    _notifyHandler();
  }

  aud.MediaItem buildBackgroundItem(MediaItem item) {
    final sec = item.effectiveDurationSeconds;
    return aud.MediaItem(
      id: item.id,
      title: item.title,
      artist: item.displaySubtitle.isEmpty ? null : item.displaySubtitle,
      duration: (sec != null && sec > 0) ? Duration(seconds: sec) : null,
      artUri: _resolveArtUri(item),
    );
  }

  Uri? _resolveArtUri(MediaItem item) {
    final local = item.thumbnailLocalPath?.trim();
    if (local != null && local.isNotEmpty) return Uri.file(local);
    final remote = item.thumbnail?.trim();
    if (remote != null && remote.isNotEmpty) return Uri.tryParse(remote);
    return null;
  }

  bool isSameTrack(MediaItem item, MediaVariant variant) {
    return currentItem.value?.id == item.id &&
        currentVariant.value?.kind == variant.kind &&
        currentVariant.value?.format == variant.format;
  }

  Future<void> play(
    MediaItem item,
    MediaVariant variant, {
    bool autoPlay = true,
    List<MediaItem>? queue,
    int? queueIndex,
    bool forceReload = false,
  }) async {
    if (!forceReload &&
        isSameTrack(item, variant) &&
        hasSourceLoaded &&
        _queueItems.isNotEmpty) {
      if (autoPlay) await _player.play();
      return;
    }

    isLoading.value = true;
    state.value = PlaybackState.loading;

    try {
      final built = _buildQueue(
        selectedItem: item,
        selectedVariant: variant,
        queue: queue,
        queueIndex: queueIndex,
      );

      _linearItems = List<MediaItem>.from(built.items);
      _linearVariants = List<MediaVariant>.from(built.variants);

      if (_shuffleEnabled && _linearItems.length > 1) {
        final shuffled = _buildShuffledIndices(
          _linearItems.length,
          startAt: built.index,
        );
        _assignActiveQueueFromIndices(shuffled);
        _activeIndex = 0;
      } else {
        _queueItems = List<MediaItem>.from(_linearItems);
        _queueVariants = List<MediaVariant>.from(_linearVariants);
        _activeIndex = built.index;
      }

      final sources = <AudioSource>[];
      for (var i = 0; i < _queueItems.length; i++) {
        sources.add(
          AudioSource.uri(_resolvePlayableUri(_queueItems[i], _queueVariants[i])),
        );
      }
      await _player.setAudioSources(sources, initialIndex: _activeIndex);

      currentItem.value = _queueItems[_activeIndex];
      currentVariant.value = _queueVariants[_activeIndex];
      _persistLastItem(_queueItems[_activeIndex], _queueVariants[_activeIndex]);
      _keepLastItem = true;
      if (autoPlay) {
        await _player.play();
      } else {
        await _player.pause();
      }
      _notifyHandler();
    } finally {
      isLoading.value = false;
    }
  }

  Uri _resolvePlayableUri(MediaItem item, MediaVariant variant) {
    final local = variant.localPath?.trim();
    if (local != null && local.isNotEmpty) {
      final f = File(local);
      if (!f.existsSync()) {
        throw Exception('Archivo no encontrado: $local');
      }
      return Uri.file(local);
    }

    final fileName = variant.fileName.trim();
    if (fileName.startsWith('http://') || fileName.startsWith('https://')) {
      return Uri.parse(fileName);
    }

    if (item.playableUrl.trim().isNotEmpty) {
      return Uri.parse(item.playableUrl.trim());
    }

    final kind = variant.kind == MediaVariantKind.video ? 'video' : 'audio';
    final fileId = item.fileId.trim();
    final format = variant.format.trim();
    if (fileId.isEmpty || format.isEmpty) {
      throw Exception('No hay URL remota disponible para reproducir.');
    }
    return Uri.parse('${ApiConfig.baseUrl}/api/v1/media/file/$fileId/$kind/$format');
  }

  Future<void> toggle() async {
    if (_player.playing) {
      await _player.pause();
      return;
    }
    if (hasSourceLoaded) {
      await _player.play();
    }
  }

  Future<void> pause() => _player.pause();

  Future<void> resume() async {
    if (!hasSourceLoaded) return;
    await _player.play();
  }

  Future<void> stop() async {
    await _player.stop();
    isPlaying.value = false;
    isLoading.value = false;
    state.value = PlaybackState.stopped;
    currentItem.value = null;
    currentVariant.value = null;
    _queueItems = <MediaItem>[];
    _queueVariants = <MediaVariant>[];
    _linearItems = <MediaItem>[];
    _linearVariants = <MediaVariant>[];
    _activeIndex = 0;
    _keepLastItem = false;
    _notifyHandler();
  }

  Future<void> seek(Duration position) async {
    if (!hasSourceLoaded) return;
    await _player.seek(position);
  }

  Future<void> next() async {
    if (_queueItems.isEmpty) return;
    final target = currentQueueIndex + 1;
    if (target < 0 || target >= _queueItems.length) return;
    final wasPlaying = _player.playing;
    await _player.seek(Duration.zero, index: target);
    _activeIndex = target;
    if (wasPlaying) await _player.play();
  }

  Future<void> previous() async {
    if (_queueItems.isEmpty) return;
    final target = currentQueueIndex - 1;
    if (target < 0 || target >= _queueItems.length) return;
    final wasPlaying = _player.playing;
    await _player.seek(Duration.zero, index: target);
    _activeIndex = target;
    if (wasPlaying) await _player.play();
  }

  Future<void> setSpeed(double value) async {
    speed.value = value;
    _storage.write(_speedKey, value);
    await _player.setSpeed(value);
  }

  Future<void> setVolume(double value) async {
    final clamped = value.clamp(0.0, 1.0);
    volume.value = clamped;
    await _player.setVolume(clamped);
  }

  Future<void> setLoopOff() => _player.setLoopMode(LoopMode.off);
  Future<void> setLoopOne() => _player.setLoopMode(LoopMode.one);
  Future<void> setShuffle(bool enabled) async {
    if (_shuffleEnabled == enabled) return;
    _shuffleEnabled = enabled;
    _storage.write(_shuffleEnabledKey, enabled);

    if (_linearItems.isEmpty || _linearVariants.isEmpty || !hasSourceLoaded) {
      return;
    }

    final playing = _player.playing;
    final pos = _player.position;
    final current = currentItem.value;
    final currentV = currentVariant.value;

    final linearIndex = _findLinearIndex(current, currentV);
    if (_shuffleEnabled && _linearItems.length > 1) {
      final shuffled = _buildShuffledIndices(
        _linearItems.length,
        startAt: linearIndex,
      );
      _assignActiveQueueFromIndices(shuffled);
      _activeIndex = 0;
    } else {
      _queueItems = List<MediaItem>.from(_linearItems);
      _queueVariants = List<MediaVariant>.from(_linearVariants);
      _activeIndex = linearIndex.clamp(0, _queueItems.length - 1);
    }

    final sources = <AudioSource>[];
    for (var i = 0; i < _queueItems.length; i++) {
      sources.add(
        AudioSource.uri(_resolvePlayableUri(_queueItems[i], _queueVariants[i])),
      );
    }

    await _player.setAudioSources(
      sources,
      initialIndex: _activeIndex,
      initialPosition: pos,
    );

    if (_queueItems.isNotEmpty) {
      currentItem.value = _queueItems[_activeIndex];
      currentVariant.value = _queueVariants[_activeIndex];
      _persistLastItem(_queueItems[_activeIndex], _queueVariants[_activeIndex]);
      _keepLastItem = true;
    }

    if (playing) {
      await _player.play();
    } else {
      await _player.pause();
    }
    _notifyHandler();
  }

  Future<AndroidEqualizerParameters?> getEqParameters() async => null;
  Future<void> setEqEnabled(bool enabled) async {}
  Future<void> setEqBandGain(int index, double gain) async {}

  Future<void> stopAndDismissNotification() async {
    await stop();
    final handler = _handler;
    if (handler == null) return;
    try {
      await handler.stop();
    } catch (_) {}
  }

  void refreshNotification() => _notifyHandler();

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
      currentItem.value = MediaItem.fromJson(Map<String, dynamic>.from(rawItem));
      final rawVariant = _storage.read<Map>(_lastVariantKey);
      if (rawVariant != null) {
        currentVariant.value = MediaVariant.fromJson(
          Map<String, dynamic>.from(rawVariant),
        );
      }
      _keepLastItem = true;
      state.value = PlaybackState.paused;
    } catch (_) {}
  }

  void _notifyHandler() {
    final handler = _handler;
    if (handler == null) return;
    final item = currentItem.value;
    if (item != null) {
      handler.updateMediaItem(buildBackgroundItem(item));
      if (_queueItems.isNotEmpty) {
        handler.updateQueue(_queueItems.map(buildBackgroundItem).toList());
      } else {
        handler.updateQueue([buildBackgroundItem(item)]);
      }
    }
    handler.updatePlayback(
      playing: isPlaying.value,
      buffering: isLoading.value,
      position: _player.position,
      speed: speed.value,
    );
  }

  _BuiltQueue _buildQueue({
    required MediaItem selectedItem,
    required MediaVariant selectedVariant,
    required List<MediaItem>? queue,
    required int? queueIndex,
  }) {
    if (!selectedVariant.isValid) {
      throw Exception('Variante inválida para reproducir.');
    }

    final source = (queue == null || queue.isEmpty)
        ? <MediaItem>[selectedItem]
        : queue;

    final outItems = <MediaItem>[];
    final outVariants = <MediaVariant>[];
    var start = 0;

    final useExplicit = queueIndex != null &&
        queueIndex >= 0 &&
        queueIndex < source.length;

    for (var i = 0; i < source.length; i++) {
      final qItem = source[i];
      final qVariant = _resolveQueueVariant(
        queueItem: qItem,
        selectedItem: selectedItem,
        selectedVariant: selectedVariant,
      );
      if (qVariant == null) continue;

      outItems.add(qItem);
      outVariants.add(qVariant);

      if (useExplicit && i == queueIndex) {
        start = outItems.length - 1;
      } else if (!useExplicit && _sameItem(qItem, selectedItem)) {
        start = outItems.length - 1;
      }
    }

    if (outItems.isEmpty) {
      outItems.add(selectedItem);
      outVariants.add(selectedVariant);
      start = 0;
    }

    if (start < 0 || start >= outItems.length) start = 0;

    return _BuiltQueue(items: outItems, variants: outVariants, index: start);
  }

  MediaVariant? _resolveQueueVariant({
    required MediaItem queueItem,
    required MediaItem selectedItem,
    required MediaVariant selectedVariant,
  }) {
    if (_sameItem(queueItem, selectedItem)) return selectedVariant;

    for (final v in queueItem.variants) {
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

  int _findLinearIndex(MediaItem? item, MediaVariant? variant) {
    if (item == null || variant == null || _linearItems.isEmpty) return 0;
    for (var i = 0; i < _linearItems.length; i++) {
      final it = _linearItems[i];
      final v = _linearVariants[i];
      if (it.id == item.id && v.kind == variant.kind && v.format == variant.format) {
        return i;
      }
      final pid = item.publicId.trim();
      if (pid.isNotEmpty && it.publicId.trim() == pid) {
        return i;
      }
    }
    return 0;
  }

  List<int> _buildShuffledIndices(int length, {required int startAt}) {
    final out = List<int>.generate(length, (i) => i);
    out.remove(startAt);
    out.shuffle(Random());
    out.insert(0, startAt);
    return out;
  }

  void _assignActiveQueueFromIndices(List<int> indices) {
    _queueItems = indices.map((i) => _linearItems[i]).toList();
    _queueVariants = indices.map((i) => _linearVariants[i]).toList();
  }
}

class _BuiltQueue {
  final List<MediaItem> items;
  final List<MediaVariant> variants;
  final int index;

  const _BuiltQueue({
    required this.items,
    required this.variants,
    required this.index,
  });
}

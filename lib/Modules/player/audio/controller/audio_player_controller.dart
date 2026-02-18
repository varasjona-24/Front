import 'dart:async';

import 'package:get/get.dart';

import '../../../../app/models/media_item.dart';
import '../../../../app/services/audio_service.dart';
import '../../../../app/services/spatial_audio_service.dart';

enum CoverStyle { square, vinyl }
enum RepeatMode { off, once, loop }

class AudioPlayerController extends GetxController {
  final AudioService audioService;
  final SpatialAudioService _spatial = Get.find<SpatialAudioService>();

  AudioPlayerController({required this.audioService});

  final RxList<MediaItem> queue = <MediaItem>[].obs;
  final RxInt currentIndex = 0.obs;

  final Rx<Duration> position = Duration.zero.obs;
  final Rx<Duration> duration = Duration.zero.obs;

  final RxBool isShuffling = false.obs;
  final Rx<RepeatMode> repeatMode = RepeatMode.off.obs;
  final Rx<CoverStyle> coverStyle = CoverStyle.square.obs;

  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration?>? _durSub;
  Worker? _itemWorker;

  Rx<SpatialAudioMode> get spatialMode => _spatial.mode;

  @override
  void onInit() {
    super.onInit();

    _posSub = audioService.positionStream.listen((v) => position.value = v);
    _durSub = audioService.durationStream.listen(
      (v) => duration.value = v ?? Duration.zero,
    );

    _itemWorker = ever<MediaItem?>(audioService.currentItem, (_) {
      _syncFromService();
    });

    _syncFromService();
  }

  @override
  void onClose() {
    _posSub?.cancel();
    _durSub?.cancel();
    _itemWorker?.dispose();
    super.onClose();
  }

  void applyRouteArgs(dynamic args) {
    if (args is! Map) return;
    final rawQueue = args['queue'];
    final rawIndex = args['index'];

    final items = _extractItems(rawQueue);
    if (items.isEmpty) return;

    queue.assignAll(items);
    currentIndex.value = (rawIndex is int ? rawIndex : 0)
        .clamp(0, items.length - 1)
        .toInt();

    _playCurrent(forceReload: true);
  }

  List<MediaItem> _extractItems(dynamic rawQueue) {
    if (rawQueue is List<MediaItem>) return rawQueue;
    if (rawQueue is List) return rawQueue.whereType<MediaItem>().toList();
    return <MediaItem>[];
  }

  MediaItem? get currentItemOrNull {
    if (queue.isEmpty) return null;
    final idx = currentIndex.value;
    if (idx < 0 || idx >= queue.length) return null;
    return queue[idx];
  }

  MediaVariant? _resolveAudioVariant(MediaItem item) {
    for (final v in item.variants) {
      if (v.kind == MediaVariantKind.audio && v.isValid) return v;
    }
    return null;
  }

  Future<void> _playCurrent({bool forceReload = false}) async {
    final item = currentItemOrNull;
    if (item == null) return;
    final variant = _resolveAudioVariant(item);
    if (variant == null) return;

    await audioService.play(
      item,
      variant,
      autoPlay: true,
      queue: queue.toList(),
      queueIndex: currentIndex.value,
      forceReload: forceReload,
    );

    _syncFromService();
  }

  Future<void> togglePlay() async {
    final item = currentItemOrNull;
    final variant = item == null ? null : _resolveAudioVariant(item);
    if (item == null || variant == null) return;

    if (!audioService.hasSourceLoaded || !audioService.isSameTrack(item, variant)) {
      await _playCurrent(forceReload: true);
      return;
    }

    await audioService.toggle();
  }

  Future<void> playAt(int index) async {
    if (index < 0 || index >= queue.length) return;
    currentIndex.value = index;
    await _playCurrent(forceReload: true);
  }

  Future<void> next() async {
    if (queue.isEmpty) return;
    final fallback = currentIndex.value + 1;
    await audioService.next();
    _syncFromService();
    if (audioService.currentQueueIndex == currentIndex.value &&
        fallback >= 0 &&
        fallback < queue.length) {
      await playAt(fallback);
    }
  }

  Future<void> previous() async {
    if (queue.isEmpty) return;
    final fallback = currentIndex.value - 1;
    await audioService.previous();
    _syncFromService();
    if (audioService.currentQueueIndex == currentIndex.value &&
        fallback >= 0 &&
        fallback < queue.length) {
      await playAt(fallback);
    }
  }

  Future<void> seek(Duration value) => audioService.seek(value);

  Future<void> skipForward10() async {
    final target = position.value + const Duration(seconds: 10);
    final max = duration.value;
    await seek(target > max ? max : target);
  }

  Future<void> skipBackward10() async {
    final target = position.value - const Duration(seconds: 10);
    await seek(target.isNegative ? Duration.zero : target);
  }

  Future<void> reorderQueue(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= queue.length) return;
    if (newIndex < 0 || newIndex > queue.length) return;

    if (newIndex > oldIndex) newIndex -= 1;

    final item = queue.removeAt(oldIndex);
    queue.insert(newIndex, item);

    if (currentIndex.value == oldIndex) {
      currentIndex.value = newIndex;
    } else if (oldIndex < newIndex &&
        currentIndex.value > oldIndex &&
        currentIndex.value <= newIndex) {
      currentIndex.value -= 1;
    } else if (oldIndex > newIndex &&
        currentIndex.value >= newIndex &&
        currentIndex.value < oldIndex) {
      currentIndex.value += 1;
    }

    final wasPlaying = audioService.isPlaying.value;
    final pos = position.value;
    await _playCurrent(forceReload: true);
    if (pos > Duration.zero) {
      await audioService.seek(pos);
    }
    if (!wasPlaying) {
      await audioService.pause();
    }
  }

  void addToQueue(List<MediaItem> items) {
    if (items.isEmpty) return;
    queue.addAll(items);
  }

  void insertNext(List<MediaItem> items) {
    if (items.isEmpty) return;
    final insertAt = (currentIndex.value + 1).clamp(0, queue.length);
    queue.insertAll(insertAt, items);
  }

  void _syncFromService() {
    final serviceQueue = audioService.queueItems;
    if (serviceQueue.isNotEmpty) {
      queue.assignAll(serviceQueue);
      final idx = audioService.currentQueueIndex;
      if (idx >= 0 && idx < queue.length) {
        currentIndex.value = idx;
      }
      return;
    }

    final current = audioService.currentItem.value;
    if (current == null || queue.isEmpty) return;

    final idx = queue.indexWhere((e) {
      if (e.id == current.id) return true;
      final ap = e.publicId.trim();
      final bp = current.publicId.trim();
      return ap.isNotEmpty && bp.isNotEmpty && ap == bp;
    });
    if (idx >= 0) currentIndex.value = idx;
  }

  Future<void> setSpatialMode(SpatialAudioMode mode) async {
    await _spatial.setMode(mode);
  }

  void toggleCoverStyle() {
    coverStyle.value = coverStyle.value == CoverStyle.square
        ? CoverStyle.vinyl
        : CoverStyle.square;
  }

  Future<void> toggleShuffle() async {
    isShuffling.value = !isShuffling.value;
    await audioService.setShuffle(isShuffling.value);
  }

  Future<void> toggleRepeatOnce() async {
    repeatMode.value =
        repeatMode.value == RepeatMode.once ? RepeatMode.off : RepeatMode.once;
    if (repeatMode.value == RepeatMode.once) {
      await audioService.setLoopOne();
    } else {
      await audioService.setLoopOff();
    }
  }

  Future<void> toggleRepeatLoop() async {
    repeatMode.value =
        repeatMode.value == RepeatMode.loop ? RepeatMode.off : RepeatMode.loop;
    if (repeatMode.value == RepeatMode.loop) {
      await audioService.setLoopOne();
    } else {
      await audioService.setLoopOff();
    }
  }

  Future<void> cyclePlaybackSpeed() async {
    const presets = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    final current = audioService.speed.value;
    final idx = presets.indexWhere((e) => e == current);
    final next = presets[(idx + 1) % presets.length];
    await audioService.setSpeed(next);
  }
}

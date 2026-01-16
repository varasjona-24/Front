import 'dart:async';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart' as vp;

import '../../../../app/models/media_item.dart';
import '../../../../app/config/api_config.dart';

class VideoPlayerController extends GetxController {
  final List<MediaItem> queue;
  final int initialIndex;

  final RxInt currentIndex = 0.obs;
  final Rx<Duration> position = Duration.zero.obs;
  final Rx<Duration> duration = Duration.zero.obs;
  final RxBool isPlaying = false.obs;
  final Rxn<String> error = Rxn<String>();

  vp.VideoPlayerController? _player;
  Timer? _posTimer;

  VideoPlayerController({required this.queue, required this.initialIndex});

  vp.VideoPlayerController? get player => _player;

  @override
  void onInit() {
    super.onInit();

    final safeIndex = initialIndex.clamp(0, queue.length - 1).toInt();
    currentIndex.value = safeIndex;

    _loadAndPlayCurrent();
  }

  Future<void> _loadAndPlayCurrent() async {
    // limpia estado previo
    error.value = null;

    final item = currentItemOrNull;
    final variant = currentVideoVariant;
    if (item == null || variant == null) {
      error.value = 'Este archivo está corrupto o no existe, selecciona otro.';
      return;
    }

    await _disposePlayer();

    final url =
        '${ApiConfig.baseUrl}/api/v1/media/file/${item.id}/video/${variant.format}';

    _player = vp.VideoPlayerController.network(url);

    try {
      // evita bloqueo indefinido en initialize
      await _player!.initialize().timeout(const Duration(seconds: 12));

      final dur = _player!.value.duration;
      duration.value = dur;
      await _player!.play();
      isPlaying.value = true;

      _posTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
        if (_player == null) return;
        position.value = _player!.value.position;
        isPlaying.value = _player!.value.isPlaying;
      });
    } catch (e) {
      // Si falla la inicialización, limpiamos y mostramos mensaje
      await _disposePlayer();
      isPlaying.value = false;
      error.value = 'Este archivo está corrupto o no existe, selecciona otro.';
      print('Video init error: $e');
    }
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
  }

  MediaItem? get currentItemOrNull {
    if (queue.isEmpty) return null;
    final i = currentIndex.value;
    if (i < 0 || i >= queue.length) return null;
    return queue[i];
  }

  MediaVariant? get currentVideoVariant {
    final item = currentItemOrNull;
    if (item == null) return null;
    // Prefer mp4 format if available
    final mp4 = item.variants.firstWhereOrNull(
      (v) =>
          v.kind == MediaVariantKind.video && v.format.toLowerCase() == 'mp4',
    );
    if (mp4 != null) return mp4;
    return item.localVideoVariant;
  }

  Future<void> togglePlay() async {
    if (_player == null) return;
    if (_player!.value.isPlaying) {
      await _player!.pause();
      isPlaying.value = false;
      return;
    }
    await _player!.play();
    isPlaying.value = true;
  }

  Future<void> seek(Duration value) async {
    if (_player == null) return;
    await _player!.seekTo(value);
    position.value = value;
  }

  Future<void> next() async {
    if (currentIndex.value < queue.length - 1) {
      currentIndex.value++;
      await _loadAndPlayCurrent();
    }
  }

  Future<void> previous() async {
    if (currentIndex.value > 0) {
      currentIndex.value--;
      await _loadAndPlayCurrent();
    }
  }

  Future<void> playAt(int index) async {
    if (index < 0 || index >= queue.length) return;
    currentIndex.value = index;
    await _loadAndPlayCurrent();
  }

  /// Reintentar cargar el mismo vídeo (UI puede llamar esto)
  Future<void> retry() async {
    await _loadAndPlayCurrent();
  }

  /// Helpers legibles desde UI (evita problemas de resolución ocasional)
  String? get errorMessage => error.value;
  Future<void> retryLoad() => retry();

  @override
  void onClose() {
    _disposePlayer();
    super.onClose();
  }
}

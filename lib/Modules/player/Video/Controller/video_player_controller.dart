import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:video_player/video_player.dart' as vp;

import '../../../../app/models/media_item.dart';
import '../../../../app/services/video_service.dart';
import '../../../../app/data/local/local_library_store.dart';
import '../../../settings/controller/settings_controller.dart';

class VideoPlayerController extends GetxController {
  final VideoService videoService;
  final LocalLibraryStore _store = Get.find<LocalLibraryStore>();
  final SettingsController _settings = Get.find<SettingsController>();
  final GetStorage _storage = GetStorage();
  final List<MediaItem> queue;
  final int initialIndex;

  final RxInt currentIndex = 0.obs;
  final Rxn<String> error = Rxn<String>();

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

    final safeIndex = initialIndex.clamp(0, queue.length - 1).toInt();
    currentIndex.value = safeIndex;
    _persistQueue();

    debounce<Duration>(
      position,
      (p) => _persistPosition(p),
      time: const Duration(seconds: 2),
    );

    ever<int>(videoService.completedTick, (_) async {
      if (!_settings.autoPlayNext.value) return;
      await next();
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
    error.value = null;

    final item = currentItemOrNull;
    final variant = currentVideoVariant;
    if (item == null || variant == null) {
      error.value = 'Este archivo está corrupto o no existe, selecciona otro.';
      return;
    }

    await _playItem(item, variant);
  }

  Future<void> _playItem(MediaItem item, MediaVariant variant) async {
    // Validar variante
    if (!variant.isValid) {
      error.value = 'Variante de video no válida.';
      return;
    }

    try {
      print('▶️ Playing: ${item.title} (${variant.kind}/${variant.format})');
      await videoService.play(item, variant);
      await _resumeIfAny(item);
      await _trackPlay(item);
      error.value = null;
    } catch (e) {
      print('❌ Error in _playItem: $e');
      error.value = 'Error al reproducir: $e';
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
          (item.publicId.isNotEmpty &&
              existing.publicId == item.publicId)) {
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
      await _playCurrent();
    }
  }

  Future<void> previous() async {
    if (currentIndex.value > 0) {
      currentIndex.value--;
      await _playCurrent();
    }
  }

  Future<void> playAt(int index) async {
    if (index < 0 || index >= queue.length) return;
    currentIndex.value = index;
    await _playCurrent();
  }

  /// Reintentar cargar el mismo vídeo
  Future<void> retry() async {
    await _playCurrent();
  }

  void _persistQueue() {
    if (queue.isEmpty) return;
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

  @override
  void onClose() {
    super.onClose();
  }
}

import 'package:get/get.dart';

import '../../../app/models/media_item.dart';
import '../../../app/data/repo/media_repository.dart';
import '../../../app/routes/app_routes.dart';

enum HomeMode { audio, video }

class HomeController extends GetxController {
  // 🔌 Repo
  final MediaRepository _repo = Get.find();

  // 🧭 Estado UI
  final Rx<HomeMode> mode = HomeMode.audio.obs;
  final RxBool isLoading = false.obs;

  // 📦 Secciones
  final RxList<MediaItem> recentlyPlayed = <MediaItem>[].obs;
  final RxList<MediaItem> latestDownloads = <MediaItem>[].obs;
  final RxList<MediaItem> favorites = <MediaItem>[].obs;

  @override
  void onInit() {
    super.onInit();
    loadHome();
  }

  // ----------------------------
  // CARGA PRINCIPAL
  // ----------------------------
  Future<void> loadHome() async {
    isLoading.value = true;

    try {
      final items = await _repo.getLibrary();
      _splitHomeSections(items);
    } catch (e) {
      print('Error loading home: $e');
    } finally {
      isLoading.value = false;
    }
  }

  // ----------------------------
  // FILTRADO POR MODO
  // ----------------------------
  void _splitHomeSections(List<MediaItem> items) {
    final isAudioMode = mode.value == HomeMode.audio;

    bool matchesMode(MediaItem item) {
      return isAudioMode ? item.hasAudio : item.hasVideo;
    }

    recentlyPlayed.assignAll(items.where(matchesMode).take(10));

    latestDownloads.assignAll(
      items.where((e) => matchesMode(e) && e.source == MediaSource.local),
    );

    favorites.assignAll(
      items.where((e) => matchesMode(e) && e.source == MediaSource.youtube),
    );
  }

  // ----------------------------
  // ACCIONES UI
  // ----------------------------
  void toggleMode() {
    mode.value = mode.value == HomeMode.audio ? HomeMode.video : HomeMode.audio;
    loadHome();
  }

  void onSearch() {
    // TODO: implementar búsqueda
  }

  // ----------------------------
  // ABRIR MEDIA (🔥 CLAVE)
  // ----------------------------

  void openMedia(MediaItem item, int index, List<MediaItem> list) {
    if (mode.value == HomeMode.audio) {
      Get.toNamed(
        AppRoutes.audioPlayer,
        arguments: {'queue': list, 'index': index},
      );
      return;
    }

    // Video: abre el reproductor de vídeo y reproduce
    Get.toNamed(
      AppRoutes.videoPlayer,
      arguments: {'queue': list, 'index': index},
    );
  }

  // ----------------------------
  // NAVEGACIÓN
  // ----------------------------
  void goToPlaylists() => Get.toNamed(AppRoutes.playlists);
  void goToArtists() => Get.toNamed(AppRoutes.artists);
  void goToDownloads() => Get.toNamed(AppRoutes.downloads);
  void goToSources() async {
    await Get.toNamed(AppRoutes.sources);
    loadHome();
  }

  void goToSettings() => Get.toNamed(AppRoutes.settings);

  void enterHome() {
    Get.offAllNamed(AppRoutes.home);
  }
}

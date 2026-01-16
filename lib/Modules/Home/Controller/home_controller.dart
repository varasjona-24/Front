import 'package:get/get.dart';

import '../../../app/models/media_item.dart';
import '../../../app/data/repo/media_repository.dart';
import '../../../app/routes/app_routes.dart';

enum HomeMode { audio, video }

class HomeController extends GetxController {
  final MediaRepository _repo = Get.find();

  final Rx<HomeMode> mode = HomeMode.audio.obs;
  final RxBool isLoading = false.obs;

  final RxList<MediaItem> recentlyPlayed = <MediaItem>[].obs;
  final RxList<MediaItem> latestDownloads = <MediaItem>[].obs;
  final RxList<MediaItem> favorites = <MediaItem>[].obs;

  // Cache para no recargar del backend al alternar modo
  final RxList<MediaItem> _allItems = <MediaItem>[].obs;

  @override
  void onInit() {
    super.onInit();
    loadHome();
  }

  Future<void> loadHome() async {
    isLoading.value = true;
    try {
      final items = await _repo.getLibrary();
      _allItems.assignAll(items);
      _splitHomeSections(_allItems);
    } catch (e) {
      print('Error loading home: $e');
    } finally {
      isLoading.value = false;
    }
  }

  void _splitHomeSections(List<MediaItem> items) {
    final isAudioMode = mode.value == HomeMode.audio;

    bool matchesMode(MediaItem item) =>
        isAudioMode ? item.hasAudioLocal : item.hasVideoLocal;

    final filtered = items.where(matchesMode).toList();

    // Si luego metes "recently played" real, aquí debería venir ordenado por lastPlayedAt
    recentlyPlayed.assignAll(filtered.take(10));

    // Descargas locales (limítalo también)
    latestDownloads.assignAll(
      filtered.where((e) => e.source == MediaSource.local).take(10),
    );

    // ⚠️ Esto NO son "favoritos" reales, esto es "de YouTube"
    // Si tu modelo tiene isFavorite, cámbialo por eso.
    favorites.assignAll(
      filtered.where((e) => e.source == MediaSource.youtube).take(10),
    );
  }

  void toggleMode() {
    mode.value = mode.value == HomeMode.audio ? HomeMode.video : HomeMode.audio;

    // No vuelvas a pegarle a la API si ya tienes data
    _splitHomeSections(_allItems);
  }

  void onSearch() {
    // TODO
  }

  void openMedia(MediaItem item, int index, List<MediaItem> list) {
    final route = mode.value == HomeMode.audio
        ? AppRoutes.audioPlayer
        : AppRoutes.videoPlayer;

    Get.toNamed(route, arguments: {'queue': list, 'index': index});
  }

  void goToPlaylists() => Get.toNamed(AppRoutes.playlists);
  void goToArtists() => Get.toNamed(AppRoutes.artists);
  void goToDownloads() => Get.toNamed(AppRoutes.downloads);

  void goToSources() async {
    await Get.toNamed(AppRoutes.sources);
    loadHome(); // aquí sí: porque puede cambiar la librería
  }

  void goToSettings() => Get.toNamed(AppRoutes.settings);

  void enterHome() => Get.offAllNamed(AppRoutes.home);
}

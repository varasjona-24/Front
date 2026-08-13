import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../../app/data/repo/media_repository.dart';
import '../controller/sources_controller.dart';
import '../data/source_theme_pill_store.dart';
import '../data/source_theme_topic_store.dart';
import '../data/source_theme_topic_playlist_store.dart';
import '../../playlists/data/playlist_store.dart';
import '../../captures/data/capture_gallery_store.dart';

class SourcesBinding extends Bindings {
  @override
  void dependencies() {
    // ============================
    // ♻️ RESET MODULO
    // ============================
    if (Get.isRegistered<SourcesController>()) {
      Get.delete<SourcesController>(force: true);
    }

    // ============================
    // 💾 STORES / REPO
    // ============================
    if (!Get.isRegistered<GetStorage>()) {
      Get.put(GetStorage(), permanent: true);
    }
    if (!Get.isRegistered<SourceThemePillStore>()) {
      Get.put(SourceThemePillStore(Get.find<GetStorage>()), permanent: true);
    }
    if (!Get.isRegistered<SourceThemeTopicStore>()) {
      Get.put(SourceThemeTopicStore(Get.find<GetStorage>()), permanent: true);
    }
    if (!Get.isRegistered<SourceThemeTopicPlaylistStore>()) {
      Get.put(
        SourceThemeTopicPlaylistStore(Get.find<GetStorage>()),
        permanent: true,
      );
    }
    if (!Get.isRegistered<MediaRepository>()) {
      Get.put(MediaRepository(), permanent: true);
    }
    if (!Get.isRegistered<PlaylistStore>()) {
      Get.put(PlaylistStore(Get.find<GetStorage>()), permanent: true);
    }
    if (!Get.isRegistered<CaptureGalleryStore>()) {
      Get.put(CaptureGalleryStore(Get.find<GetStorage>()), permanent: true);
    }

    // ============================
    // 🧠 CONTROLLER
    // ============================
    Get.put<SourcesController>(SourcesController());
  }
}

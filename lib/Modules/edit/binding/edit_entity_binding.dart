import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../../app/data/local/local_library_store.dart';
import '../../../app/data/repo/media_repository.dart';
import '../../artists/controller/artists_controller.dart';
import '../../artists/data/artist_store.dart';
import '../../playlists/controller/playlists_controller.dart';
import '../../playlists/data/playlist_store.dart';
import '../controller/edit_entity_controller.dart';

class EditEntityBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<GetStorage>()) {
      Get.put(GetStorage(), permanent: true);
    }
    if (!Get.isRegistered<LocalLibraryStore>()) {
      Get.put(LocalLibraryStore(Get.find<GetStorage>()), permanent: true);
    }
    if (!Get.isRegistered<MediaRepository>()) {
      Get.put(MediaRepository(), permanent: true);
    }
    if (!Get.isRegistered<ArtistStore>()) {
      Get.put(ArtistStore(Get.find<GetStorage>()), permanent: true);
    }
    if (!Get.isRegistered<PlaylistStore>()) {
      Get.put(PlaylistStore(Get.find<GetStorage>()), permanent: true);
    }
    if (!Get.isRegistered<ArtistsController>()) {
      Get.put(ArtistsController());
    }
    if (!Get.isRegistered<PlaylistsController>()) {
      Get.put(PlaylistsController());
    }

    Get.lazyPut<EditEntityController>(() => EditEntityController());
  }
}

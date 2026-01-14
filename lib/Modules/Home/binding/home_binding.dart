import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../../app/data/local/local_library_store.dart';
import '../../../app/data/repo/media_repository.dart';
import '../controller/home_controller.dart';

class HomeBinding extends Bindings {
  @override
  void dependencies() {
    // Local storage
    if (!Get.isRegistered<GetStorage>()) {
      Get.put(GetStorage(), permanent: true);
    }
    if (!Get.isRegistered<LocalLibraryStore>()) {
      Get.put(LocalLibraryStore(Get.find<GetStorage>()), permanent: true);
    }

    // Repo (local-first)
    if (!Get.isRegistered<MediaRepository>()) {
      Get.put(MediaRepository(), permanent: true);
    }

    // Controller
    Get.put(HomeController());
  }
}

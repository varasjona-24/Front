import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../../app/data/local/local_library_store.dart';
import '../controller/settings_controller.dart';

class SettingsBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<GetStorage>()) {
      Get.put(GetStorage(), permanent: true);
    }
    if (!Get.isRegistered<LocalLibraryStore>()) {
      Get.put(LocalLibraryStore(Get.find<GetStorage>()), permanent: true);
    }
    Get.lazyPut<SettingsController>(() => SettingsController(), fenix: true);
  }
}

import 'package:get/get.dart';

import '../controller/downloads_controller.dart';

class DownloadsBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<DownloadsController>()) {
      Get.put(DownloadsController());
    }
  }
}

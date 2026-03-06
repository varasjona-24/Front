import 'package:get/get.dart';

import '../controller/downloads_controller.dart';
import '../service/download_task_service.dart';

// ============================
// 📦 BINDINGS
// ============================
class DownloadsBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<DownloadTaskService>()) {
      Get.put(DownloadTaskService(), permanent: true);
    }
    if (!Get.isRegistered<DownloadsController>()) {
      Get.put(DownloadsController());
    }
  }
}

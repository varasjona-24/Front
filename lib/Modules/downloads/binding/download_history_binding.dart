import 'package:get/get.dart';

import '../controller/download_history_controller.dart';

// ============================
// 🧷 BINDING: HISTORIAL DE IMPORTS
// ============================
class DownloadHistoryBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<DownloadHistoryController>()) {
      Get.put(DownloadHistoryController());
    }
  }
}

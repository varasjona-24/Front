import 'package:get/get.dart';

import '../controller/sources_controller.dart';

class SourcesBinding extends Bindings {
  @override
  void dependencies() {
    if (Get.isRegistered<SourcesController>()) {
      Get.delete<SourcesController>(force: true);
    }

    Get.put<SourcesController>(SourcesController());
  }
}

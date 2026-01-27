import 'package:get/get.dart';

class NavigationController extends GetxController {
  final RxString currentRoute = ''.obs;
  final RxBool isEditing = false.obs;
  final RxBool isOverlayOpen = false.obs;

  void setRoute(String route) {
    currentRoute.value = route;
  }

  void setEditing(bool value) {
    isEditing.value = value;
  }

  void setOverlayOpen(bool value) {
    isOverlayOpen.value = value;
  }
}

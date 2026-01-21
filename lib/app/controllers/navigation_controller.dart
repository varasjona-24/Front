import 'package:get/get.dart';

class NavigationController extends GetxController {
  final RxString currentRoute = ''.obs;

  void setRoute(String route) {
    currentRoute.value = route;
  }
}

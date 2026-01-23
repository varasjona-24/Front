import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'app/controllers/theme_controller.dart';
import 'app/controllers/navigation_controller.dart';
import 'app/routes/app_pages.dart';
import 'app/routes/app_routes.dart';
import 'app/ui/themes/app_theme_factory.dart';
import 'app/ui/widgets/player/mini_player_bar.dart';

import 'app/data/network/dio_client.dart';
import 'app/data/repo/media_repository.dart';
import 'app/services/audio_service.dart';
import 'app/services/video_service.dart';
import 'Modules/settings/controller/settings_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // 🎨 Controller global de tema
  Get.put(ThemeController(), permanent: true);

  // 🧭 Controller global de navegación
  Get.put(NavigationController(), permanent: true);

  // ⚙️ Controller global de configuración
  Get.put(SettingsController(), permanent: true);

  // 🎵 Audio global (CLAVE)
  Get.put<AudioService>(AudioService(), permanent: true);

  // 🎬 Video global (CLAVE)
  Get.put<VideoService>(VideoService(), permanent: true);

  // 🌐 Cliente HTTP
  Get.lazyPut<DioClient>(() => DioClient(), fenix: true);

  // 📦 Repositorio de media
  Get.lazyPut<MediaRepository>(() => MediaRepository(), fenix: true);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final themeCtrl = Get.find<ThemeController>();
      final palette = themeCtrl.palette.value;
      final mode = themeCtrl.themeMode.value;

      return GetMaterialApp(
        title: 'Listenfy',
        debugShowCheckedModeBanner: false,
        initialRoute: AppRoutes.entry,
        getPages: AppPages.routes,

        routingCallback: (routing) {
          final current = routing?.current;
          if (current != null) {
            Get.find<NavigationController>().setRoute(current);
          }
        },

        builder: (context, child) {
          if (child == null) {
            return const SizedBox.shrink();
          }

          final safeBottom = MediaQuery.of(context).padding.bottom;
          final bottomOffset = safeBottom + kBottomNavigationBarHeight + 12;

          return Stack(
            children: [
              child,
              Positioned(
                left: 0,
                right: 0,
                bottom: bottomOffset,
                child: const MiniPlayerBar(),
              ),
            ],
          );
        },

        // ✅ Theming correcto
        theme: buildTheme(palette: palette, brightness: Brightness.light),
        darkTheme: buildTheme(palette: palette, brightness: Brightness.dark),
        themeMode: mode,
      );
    });
  }
}

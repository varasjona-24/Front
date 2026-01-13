import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'app/controllers/theme_controller.dart';
import 'app/routes/app_pages.dart';
import 'app/routes/app_routes.dart';
import 'app/ui/themes/app_theme_factory.dart';

import 'app/data/network/dio_client.dart';
import 'app/data/repo/media_repository.dart';
import 'app/services/audio_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // 🎨 Controller global de tema
  Get.put(ThemeController(), permanent: true);

  // 🎵 Audio global (CLAVE)
  Get.put<AudioService>(AudioService(), permanent: true);

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

      return GetMaterialApp(
        title: 'Listenfy',
        debugShowCheckedModeBanner: false,

        // 🚀 Ruta inicial
        initialRoute: AppRoutes.entry,

        // 🧭 Rutas GetX
        getPages: AppPages.routes,

        // 🎨 Theme dinámico
        theme: buildTheme(
          palette: themeCtrl.palette.value,
          brightness: themeCtrl.brightness.value,
        ),
      );
    });
  }
}

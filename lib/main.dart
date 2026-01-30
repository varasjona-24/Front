import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audio_service/audio_service.dart' as aud;
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:permission_handler/permission_handler.dart';

import 'app/controllers/theme_controller.dart';
import 'app/controllers/navigation_controller.dart';
import 'app/routes/app_pages.dart';
import 'app/routes/app_routes.dart';
import 'app/ui/themes/app_theme_factory.dart';
import 'app/ui/widgets/player/mini_player_bar.dart';

import 'app/data/network/dio_client.dart';
import 'app/data/repo/media_repository.dart';
import 'app/data/local/local_library_store.dart';
import 'app/services/audio_service.dart';
import 'app/services/app_audio_handler.dart';
import 'app/services/spatial_audio_service.dart';
import 'app/services/video_service.dart';
import 'Modules/settings/controller/settings_controller.dart';
import 'Modules/downloads/controller/downloads_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init();
  if (Platform.isAndroid) {
    Future.microtask(() async {
      await Permission.notification.request();
    });
  }
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
  final appAudio = AudioService();
  Get.put<AudioService>(appAudio, permanent: true);

  // 🔔 Background controls / lockscreen
  final handler = await aud.AudioService.init(
    builder: () => AppAudioHandler(appAudio),
    config: const aud.AudioServiceConfig(
      androidNotificationChannelId: 'com.example.flutter_listenfy.audio',
      androidNotificationChannelName: 'Reproducción',
      androidNotificationChannelDescription: 'Controles de reproducción',
      androidNotificationOngoing: true,
      androidNotificationIcon: 'mipmap/ic_launcher',
    ),
  );
  appAudio.attachHandler(handler);

  // 🎬 Video global (CLAVE)
  Get.put<VideoService>(VideoService(), permanent: true);

  // 🎧 Spatial audio (8D)
  Get.put<SpatialAudioService>(
    SpatialAudioService(audioService: Get.find<AudioService>()),
    permanent: true,
  );

  // 🌐 Cliente HTTP
  Get.lazyPut<DioClient>(() => DioClient(), fenix: true);

  // 📦 GetStorage (shared)
  Get.put<GetStorage>(GetStorage(), permanent: true);

  // 💾 Local storage
  Get.put(LocalLibraryStore(Get.find<GetStorage>()), permanent: true);

  // 📦 Repositorio de media
  Get.lazyPut<MediaRepository>(() => MediaRepository(), fenix: true);

  // 📥 Imports/Downloads global (share intent listener)
  Get.put(DownloadsController(), permanent: true);

  // 🎚️ Reaplicar ecualizador cuando AudioService ya existe (no bloquear arranque)
  if (Get.isRegistered<SettingsController>()) {
    Future.microtask(() {
      Get.find<SettingsController>().refreshEqualizer();
    });
  }

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

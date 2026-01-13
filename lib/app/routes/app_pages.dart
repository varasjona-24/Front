import 'package:get/get.dart';

import 'app_routes.dart';

// Entry / Home
import '../../modules/home/binding/home_binding.dart';
import '../../modules/home/view/home_entry_page.dart';
import '../../modules/home/view/home_page.dart';

// Player
import '../../modules/player/audio/binding/audio_player_binding.dart';
import '../../modules/player/audio/view/audio_player_page.dart';

// Video
import '../../modules/player/video/binding/video_player_binding.dart';
import '../../modules/player/video/view/video_player_page.dart';

abstract class AppPages {
  static final routes = <GetPage>[
    // Entry
    GetPage(
      name: AppRoutes.entry,
      page: () => const HomeEntryPage(),
      binding: HomeBinding(),
    ),

    // Home
    GetPage(
      name: AppRoutes.home,
      page: () => const HomePage(),
      binding: HomeBinding(),
    ),

    // Audio Player
    GetPage(
      name: AppRoutes.audioPlayer,
      page: () => const AudioPlayerPage(),
      binding: AudioPlayerBinding(),
    ),

    // Video Player
    GetPage(
      name: AppRoutes.videoPlayer,
      page: () => const VideoPlayerPage(),
      binding: VideoPlayerBinding(),
    ),

    // Video Player
    //GetPage(
    //name: AppRoutes.videoPlayer,
    //page: () => const VideoPlayerPage(),
    //binding: VideoPlayerBinding(),
    //),
  ];
}

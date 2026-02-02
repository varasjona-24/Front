import 'package:get/get.dart';

import 'app_routes.dart';

// Entry / Home
import 'package:flutter_listenfy/Modules/home/binding/home_binding.dart';
import 'package:flutter_listenfy/Modules/home/view/home_entry_page.dart';
import 'package:flutter_listenfy/Modules/home/view/home_page.dart';

// Player
import 'package:flutter_listenfy/Modules/player/audio/binding/audio_player_binding.dart';
import 'package:flutter_listenfy/Modules/player/audio/view/audio_player_page.dart';

// Video
import 'package:flutter_listenfy/Modules/player/Video/binding/video_player_binding.dart';
import 'package:flutter_listenfy/Modules/player/Video/view/video_player_page.dart';

// Sources
import 'package:flutter_listenfy/Modules/sources/binding/sources_binding.dart';
import 'package:flutter_listenfy/Modules/sources/view/sources_page.dart';

// Downloads
import 'package:flutter_listenfy/Modules/downloads/binding/downloads_binding.dart';
import 'package:flutter_listenfy/Modules/downloads/view/downloads_page.dart';

// History
import 'package:flutter_listenfy/Modules/history/binding/history_binding.dart';
import 'package:flutter_listenfy/Modules/history/view/history_page.dart';

// Artists
import 'package:flutter_listenfy/Modules/artists/binding/artists_binding.dart';
import 'package:flutter_listenfy/Modules/artists/view/artists_page.dart';

// Playlists
import 'package:flutter_listenfy/Modules/playlists/binding/playlists_binding.dart';
import 'package:flutter_listenfy/Modules/playlists/view/playlists_page.dart';

// Settings
import 'package:flutter_listenfy/Modules/settings/binding/settings_binding.dart';
import 'package:flutter_listenfy/Modules/settings/view/settings_view.dart';

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

    // Sources
    GetPage(
      name: AppRoutes.sources,
      page: () => const SourcesPage(),
      binding: SourcesBinding(),
    ),

    // Downloads
    GetPage(
      name: AppRoutes.downloads,
      page: () => const DownloadsPage(),
      binding: DownloadsBinding(),
    ),

    // History
    GetPage(
      name: AppRoutes.history,
      page: () => const HistoryPage(),
      binding: HistoryBinding(),
    ),

    // Playlists
    GetPage(
      name: AppRoutes.playlists,
      page: () => const PlaylistsPage(),
      binding: PlaylistsBinding(),
    ),

    // Artists
    GetPage(
      name: AppRoutes.artists,
      page: () => const ArtistsPage(),
      binding: ArtistsBinding(),
    ),

    // Settings
    GetPage(
      name: AppRoutes.settings,
      page: () => const SettingsView(),
      binding: SettingsBinding(),
    ),

    // Video Player
    //GetPage(
    //name: AppRoutes.videoPlayer,
    //page: () => const VideoPlayerPage(),
    //binding: VideoPlayerBinding(),
    //),
  ];
}

import 'package:get/get.dart';
import '../../../../app/models/media_item.dart';
import 'package:flutter_listenfy/Modules/player/Video/Controller/video_player_controller.dart';

class VideoPlayerBinding extends Bindings {
  @override
  void dependencies() {
    final args = (Get.arguments as Map?) ?? const {};

    final rawQueue = args['queue'];
    final queue = (rawQueue is List)
        ? rawQueue.whereType<MediaItem>().toList()
        : <MediaItem>[];

    final index = (args['index'] is int) ? args['index'] as int : 0;

    if (Get.isRegistered<VideoPlayerController>()) {
      Get.delete<VideoPlayerController>(force: true);
    }

    Get.put<VideoPlayerController>(
      VideoPlayerController(queue: queue, initialIndex: index),
      permanent: false,
    );
  }
}

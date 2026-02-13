import 'package:get/get.dart';

import '../../../../app/models/media_item.dart';
import '../../../../app/services/video_service.dart';
import '../controller/video_player_controller.dart';

class VideoPlayerBinding extends Bindings {
  @override
  void dependencies() {
    final args = (Get.arguments as Map?) ?? const {};

    final rawQueue = args['queue'];
    var queue = (rawQueue is List)
        ? rawQueue.whereType<MediaItem>().toList()
        : <MediaItem>[];

    var index = (args['index'] is int) ? args['index'] as int : 0;

    // Asegurar que VideoService está disponible
    if (!Get.isRegistered<VideoService>()) {
      Get.put<VideoService>(VideoService(), permanent: true);
    }

    // Si llegamos sin argumentos (ej: mini player), reutilizar cola/sesión actual.
    if (queue.isEmpty) {
      if (Get.isRegistered<VideoPlayerController>()) {
        final existing = Get.find<VideoPlayerController>();
        if (existing.queue.isNotEmpty) {
          queue = List<MediaItem>.from(existing.queue);
          index = existing.currentIndex.value;
        }
      }

      if (queue.isEmpty) {
        final current = Get.find<VideoService>().currentItem.value;
        if (current != null) {
          queue = [current];
          index = 0;
        }
      }
    }

    if (Get.isRegistered<VideoPlayerController>()) {
      Get.delete<VideoPlayerController>(force: true);
    }

    Get.put<VideoPlayerController>(
      VideoPlayerController(
        videoService: Get.find<VideoService>(),
        queue: queue,
        initialIndex: index,
      ),
      permanent: false,
    );
  }
}

import 'dart:async';

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
    final hasIncomingQueue = rawQueue is List && queue.isNotEmpty;

    var index = (args['index'] is int) ? args['index'] as int : 0;

    // Asegurar que VideoService está disponible
    if (!Get.isRegistered<VideoService>()) {
      Get.put<VideoService>(VideoService(), permanent: true);
    }

    // Reusar controlador existente para evitar reconstrucciones costosas.
    if (Get.isRegistered<VideoPlayerController>()) {
      final existing = Get.find<VideoPlayerController>();
      if (hasIncomingQueue) {
        unawaited(existing.updateQueue(queue, index));
        return;
      }

      if (existing.queue.isNotEmpty) {
        return;
      }

      final current = Get.find<VideoService>().currentItem.value;
      if (current != null) {
        unawaited(existing.updateQueue([current], 0, autoPlay: false));
      }
      return;
    }

    // Si no hay controlador, construir estado inicial.
    if (queue.isEmpty) {
      final current = Get.find<VideoService>().currentItem.value;
      if (current != null) {
        queue = [current];
        index = 0;
      }
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

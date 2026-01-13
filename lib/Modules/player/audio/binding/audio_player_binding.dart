import 'package:get/get.dart';
import '../../../../app/services/audio_service.dart';
import '../../../../app/models/media_item.dart';
import '../controller/audio_player_controller.dart';

class AudioPlayerBinding extends Bindings {
  @override
  void dependencies() {
    final args = (Get.arguments as Map?) ?? const {};

    // ✅ Robustez: Get.arguments suele venir como List<dynamic>
    final rawQueue = args['queue'];
    final queue = (rawQueue is List)
        ? rawQueue.whereType<MediaItem>().toList()
        : <MediaItem>[];

    final index = (args['index'] is int) ? args['index'] as int : 0;

    // ✅ Limpia instancia anterior si existiera
    if (Get.isRegistered<AudioPlayerController>()) {
      Get.delete<AudioPlayerController>(force: true);
    }

    // ✅ Crea controller nuevo
    Get.put<AudioPlayerController>(
      AudioPlayerController(
        queue: queue,
        initialIndex: index,
        audioService: Get.find<AudioService>(),
      ),
      permanent: false,
    );
  }
}

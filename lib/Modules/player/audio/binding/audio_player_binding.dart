import 'package:get/get.dart';
import '../../../../app/services/audio_service.dart';
import '../controller/audio_player_controller.dart';

class AudioPlayerBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<AudioPlayerController>(
      AudioPlayerController(audioService: Get.find<AudioService>()),
      permanent: false,
    );
  }
}

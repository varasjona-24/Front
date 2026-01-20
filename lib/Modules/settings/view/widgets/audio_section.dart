import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:app_settings/app_settings.dart';

import '../../controller/settings_controller.dart';

class AudioSection extends GetView<SettingsController> {
  const AudioSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 🔊 Título
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            '🔊 Audio',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: 12),

        // 🎵 Opciones de audio
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Volumen por defecto
                Obx(
                  () => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('🔉 Volumen por defecto'),
                          Text(
                            '${controller.defaultVolume.value.toInt()}%',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Slider(
                        value: controller.defaultVolume.value,
                        min: 0,
                        max: 100,
                        divisions: 10,
                        onChanged: (value) {
                          controller.setDefaultVolume(value);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Reproducción automática
                Obx(
                  () => SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('🎵 Reproducción automática'),
                    subtitle: const Text(
                      'Reproducir siguiente canción automáticamente',
                    ),
                    value: controller.autoPlayNext.value,
                    onChanged: (value) {
                      controller.setAutoPlayNext(value);
                    },
                  ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.bluetooth_audio_rounded),
                  title: const Text('Salida de audio'),
                  subtitle: const Text(
                    'Selecciona el dispositivo Bluetooth',
                  ),
                  trailing: OutlinedButton(
                    onPressed: () =>
                        AppSettings.openAppSettings(type: AppSettingsType.bluetooth),
                    child: const Text('Cambiar'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

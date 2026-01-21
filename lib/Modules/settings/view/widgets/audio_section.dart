import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:app_settings/app_settings.dart';

import '../widgets/section_block.dart';
import '../widgets/value_pill.dart';
import '../widgets/info_tile.dart';
import '../widgets/device_tile.dart';

import '../../controller/settings_controller.dart';
import '../../../../app/services/bluetooth_audio_service.dart';

class AudioSection extends GetView<SettingsController> {
  const AudioSection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              const Icon(Icons.volume_up_rounded, size: 18),
              const SizedBox(width: 8),
              Text(
                'Audio',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16.0),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: theme.dividerColor.withOpacity(.12)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Default volume
                Obx(
                  () => SectionBlock(
                    title: 'Volumen por defecto',
                    subtitle: 'Define el nivel inicial de reproducción.',
                    trailing: ValuePill(
                      text: '${controller.defaultVolume.value.toInt()}%',
                    ),
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 4,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 10,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 18,
                        ),
                      ),
                      child: Slider(
                        value: controller.defaultVolume.value,
                        min: 0,
                        max: 100,
                        divisions: 20,
                        label: '${controller.defaultVolume.value.toInt()}%',
                        onChanged: controller.setDefaultVolume,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 8),
                Divider(color: theme.dividerColor.withOpacity(.12)),
                const SizedBox(height: 8),

                // Autoplay
                Obx(
                  () => SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(
                      'Reproducción automática',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      'Reproduce la siguiente pista al finalizar la actual.',
                      style: theme.textTheme.bodySmall,
                    ),
                    value: controller.autoPlayNext.value,
                    onChanged: controller.setAutoPlayNext,
                  ),
                ),

                const SizedBox(height: 8),
                Divider(color: theme.dividerColor.withOpacity(.12)),
                const SizedBox(height: 8),

                // Output / Bluetooth
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: const Icon(Icons.bluetooth_audio_rounded),
                  title: Text(
                    'Salida de audio',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Gestiona tu dispositivo Bluetooth desde Ajustes.',
                    style: theme.textTheme.bodySmall,
                  ),
                  trailing: OutlinedButton.icon(
                    onPressed: () => AppSettings.openAppSettings(
                      type: AppSettingsType.bluetooth,
                    ),
                    icon: const Icon(Icons.settings_rounded, size: 18),
                    label: const Text('Ajustes'),
                  ),
                ),

                const SizedBox(height: 8),

                // Devices snapshot
                Obx(() {
                  controller.bluetoothTick.value; // keep refresh behavior
                  return FutureBuilder<BluetoothAudioSnapshot>(
                    future: controller.getBluetoothSnapshot(),
                    builder: (context, snap) {
                      final loading =
                          snap.connectionState != ConnectionState.done;

                      if (loading) {
                        return InfoTile(
                          icon: Icons.sync_rounded,
                          title: 'Buscando dispositivos…',
                          subtitle: 'Verificando el estado del Bluetooth.',
                          trailing: const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      }

                      final data = snap.data;
                      final devices =
                          data?.devices ?? const <BluetoothAudioDevice>[];
                      final bluetoothOn = data?.bluetoothOn ?? false;

                      // final outputs = data?.outputs ?? const <String>[]; // kept but not shown (UI only)

                      if (!bluetoothOn) {
                        return InfoTile(
                          icon: Icons.bluetooth_disabled_rounded,
                          title: 'Bluetooth desactivado',
                          subtitle:
                              'Actívalo para detectar y usar dispositivos de audio.',
                          trailing: IconButton(
                            tooltip: 'Abrir ajustes',
                            onPressed: () => AppSettings.openAppSettings(
                              type: AppSettingsType.bluetooth,
                            ),
                            icon: const Icon(Icons.settings_rounded),
                          ),
                        );
                      }

                      if (devices.isEmpty) {
                        return InfoTile(
                          icon: Icons.headphones_rounded,
                          title: 'Sin dispositivos conectados',
                          subtitle:
                              'Conecta un dispositivo para mostrarlo aquí.',
                          trailing: IconButton(
                            tooltip: 'Actualizar',
                            onPressed: controller.refreshBluetoothDevices,
                            icon: const Icon(Icons.refresh_rounded),
                          ),
                        );
                      }

                      return Column(
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Text(
                                'Dispositivos detectados',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),

                          ...devices.map(
                            (device) => DeviceTile(device: device),
                          ),

                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: controller.refreshBluetoothDevices,
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Actualizar'),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

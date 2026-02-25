import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:app_settings/app_settings.dart';

import '../../controller/settings_controller.dart';
import '../../controller/playback_settings_controller.dart';
import '../../controller/sleep_timer_controller.dart';
import '../../controller/equalizer_controller.dart';
import '../../../../app/services/bluetooth_audio_service.dart';

import '../widgets/section_block.dart';
import '../widgets/value_pill.dart';
import '../widgets/info_tile.dart';
import '../widgets/device_tile.dart';

class AudioSection extends StatelessWidget {
  const AudioSection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final playback = Get.find<PlaybackSettingsController>();
    final sleepTimer = Get.find<SleepTimerController>();
    final equalizer = Get.find<EqualizerController>();
    final settings = Get.find<SettingsController>();

    String formatRemaining(Duration d) {
      final total = d.inSeconds;
      final mm = (total ~/ 60).toString().padLeft(2, '0');
      final ss = (total % 60).toString().padLeft(2, '0');
      return '$mm:$ss';
    }

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
                      text: '${playback.defaultVolume.value.toInt()}%',
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
                        value: playback.defaultVolume.value,
                        min: 0,
                        max: 100,
                        divisions: 20,
                        label: '${playback.defaultVolume.value.toInt()}%',
                        onChanged: playback.setDefaultVolume,
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
                    value: playback.autoPlayNext.value,
                    onChanged: playback.setAutoPlayNext,
                  ),
                ),

                const SizedBox(height: 8),
                Obx(
                  () => SectionBlock(
                    title: 'Crossfade',
                    subtitle:
                        'Mezcla canciones al final/inicio de la transición.',
                    trailing: ValuePill(
                      text: playback.crossfadeSeconds.value == 0
                          ? 'Off'
                          : '${playback.crossfadeSeconds.value}s',
                    ),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: const [0, 2, 4, 6].map((seconds) {
                        return _CrossfadeChip(seconds: seconds);
                      }).toList(),
                    ),
                  ),
                ),

                const SizedBox(height: 8),
                Divider(color: theme.dividerColor.withOpacity(.12)),
                const SizedBox(height: 8),

                // Sleep timer
                Obx(
                  () => Column(
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(
                          'Temporizador de sueño',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          'Detiene la reproducción después de un tiempo.',
                          style: theme.textTheme.bodySmall,
                        ),
                        value: sleepTimer.sleepTimerEnabled.value,
                        onChanged: sleepTimer.setSleepTimerEnabled,
                      ),
                      if (sleepTimer.sleepTimerEnabled.value &&
                          sleepTimer.sleepRemaining.value > Duration.zero)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 6.0),
                            child: Text(
                              'Tiempo restante: ${formatRemaining(sleepTimer.sleepRemaining.value)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(
                                  0.7,
                                ),
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 6),

                      // Duración: chips discretos
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Duración',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: SleepTimerController.timerPresets.map((mins) {
                          final selected =
                              sleepTimer.sleepTimerMinutes.value == mins;
                          return ChoiceChip(
                            label: Text('${mins}m'),
                            selected: selected,
                            onSelected: (_) =>
                                sleepTimer.setSleepTimerMinutes(mins),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 12),

                      // Fade-out toggle
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(
                          'Fade-out gradual',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          sleepTimer.fadeOutEnabled.value
                              ? 'El volumen bajará los últimos ~${(sleepTimer.sleepTimerMinutes.value * 60 * 0.05).clamp(10, 60).toInt()}s'
                              : 'La música se detendrá de golpe.',
                          style: theme.textTheme.bodySmall,
                        ),
                        value: sleepTimer.fadeOutEnabled.value,
                        onChanged: sleepTimer.setFadeOutEnabled,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),
                Divider(color: theme.dividerColor.withOpacity(.12)),
                const SizedBox(height: 8),

                // Inactivity pause
                Obx(
                  () => Column(
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(
                          'Pausar por inactividad',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          'Si no interactúas, se pausa automáticamente.',
                          style: theme.textTheme.bodySmall,
                        ),
                        value: sleepTimer.inactivityPauseEnabled.value,
                        onChanged: sleepTimer.setInactivityPauseEnabled,
                      ),
                      const SizedBox(height: 6),
                      SectionBlock(
                        title: 'Tiempo de inactividad',
                        subtitle: 'En minutos',
                        trailing: ValuePill(
                          text: '${sleepTimer.inactivityPauseMinutes.value}m',
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
                            value: sleepTimer.inactivityPauseMinutes.value
                                .toDouble(),
                            min: 5,
                            max: 60,
                            divisions: 11,
                            label:
                                '${sleepTimer.inactivityPauseMinutes.value}m',
                            onChanged: sleepTimer.inactivityPauseEnabled.value
                                ? (v) => sleepTimer.setInactivityPauseMinutes(
                                    v.round(),
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),
                Divider(color: theme.dividerColor.withOpacity(.12)),
                const SizedBox(height: 8),

                // Equalizer
                Obx(() {
                  if (!equalizer.eqAvailable.value) {
                    return InfoTile(
                      icon: Icons.graphic_eq_rounded,
                      title: 'Ecualizador',
                      subtitle: 'Disponible solo en Android.',
                    );
                  }

                  if (equalizer.eqFrequencies.isEmpty ||
                      equalizer.eqGains.isEmpty) {
                    return InfoTile(
                      icon: Icons.graphic_eq_rounded,
                      title: 'Ecualizador',
                      subtitle: 'Cargando parámetros…',
                      trailing: const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  }

                  final presets = const <String, String>{
                    'normal': 'Normal',
                    'bass': 'Bass',
                    'vocal': 'Vocal',
                    'rock': 'Rock',
                    'treble': 'Agudos',
                    'custom': 'Personalizado',
                  };

                  return Column(
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(
                          'Ecualizador',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          'Ajusta las frecuencias de audio.',
                          style: theme.textTheme.bodySmall,
                        ),
                        value: equalizer.eqEnabled.value,
                        onChanged: equalizer.setEqEnabled,
                      ),
                      const SizedBox(height: 8),

                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: presets.entries.map((entry) {
                          final isSelected =
                              equalizer.eqPreset.value == entry.key;
                          return ChoiceChip(
                            label: Text(entry.value),
                            selected: isSelected,
                            onSelected: (_) => equalizer.setEqPreset(entry.key),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 12),

                      ...List.generate(equalizer.eqGains.length, (i) {
                        final freq = equalizer.eqFrequencies[i];
                        final value = equalizer.eqGains[i];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$freq Hz',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 3,
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 9,
                                ),
                              ),
                              child: Slider(
                                value: value,
                                min: equalizer.eqMinDb.value,
                                max: equalizer.eqMaxDb.value,
                                divisions: 20,
                                label: '${value.toStringAsFixed(1)} dB',
                                onChanged: equalizer.eqEnabled.value
                                    ? (v) => equalizer.setEqGain(i, v)
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 6),
                          ],
                        );
                      }),
                    ],
                  );
                }),

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
                  settings.bluetoothTick.value; // keep refresh behavior
                  return FutureBuilder<BluetoothAudioSnapshot>(
                    future: settings.getBluetoothSnapshot(),
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
                            onPressed: settings.refreshBluetoothDevices,
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
                              onPressed: settings.refreshBluetoothDevices,
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

class _CrossfadeChip extends StatelessWidget {
  final int seconds;

  const _CrossfadeChip({required this.seconds});

  @override
  Widget build(BuildContext context) {
    final playback = Get.find<PlaybackSettingsController>();
    return Obx(() {
      final selected = playback.crossfadeSeconds.value == seconds;
      return ChoiceChip(
        label: Text(seconds == 0 ? 'Off' : '${seconds}s'),
        selected: selected,
        onSelected: (_) => playback.setCrossfadeSeconds(seconds),
      );
    });
  }
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:app_settings/app_settings.dart';

import '../../controller/settings_controller.dart';
import '../widgets/section_header.dart';
import '../widgets/choice_chip_row.dart';
import '../widgets/info_tile.dart';

class DataSection extends GetView<SettingsController> {
  const DataSection({super.key});

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
              const Icon(Icons.cloud_download_rounded, size: 18),
              const SizedBox(width: 8),
              Text(
                'Datos y descargas',
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Data usage
                Obx(() {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader(
                        title: 'Uso de datos',
                        subtitle: 'Controla cuándo usar datos móviles.',
                      ),
                      const SizedBox(height: 8),
                      ChoiceChipRow(
                        options: const [
                          ChoiceOption(value: 'wifi_only', label: 'Solo Wi-Fi'),
                          ChoiceOption(value: 'all', label: 'Wi-Fi y móvil'),
                        ],
                        selectedValue: controller.dataUsage.value,
                        onSelected: (v) => controller.setDataUsage(v),
                      ),
                    ],
                  );
                }),

                const SizedBox(height: 12),
                Divider(color: theme.dividerColor.withOpacity(.12)),
                const SizedBox(height: 12),

                // Storage used
                // Storage used removed

                // Actions
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: controller.clearCache,
                    icon: const Icon(Icons.delete_sweep_rounded),
                    label: const Text('Limpiar caché'),
                  ),
                ),

                const SizedBox(height: 12),

                if (Platform.isAndroid) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.primary.withOpacity(.25),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 18,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Para mostrar el reproductor en pantalla de bloqueo, '
                            'desactiva temporalmente el ahorro de batería y '
                            'luego vuelve a activarlo.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  InfoTile(
                    icon: Icons.battery_saver_rounded,
                    title: 'Ahorro de batería',
                    subtitle:
                        'Desactívalo para ver controles en pantalla de bloqueo.',
                    trailing: TextButton(
                      onPressed: () => AppSettings.openAppSettings(
                        type: AppSettingsType.batteryOptimization,
                      ),
                      child: const Text('Abrir'),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: controller.exportLibrary,
                        icon: const Icon(Icons.upload_file_rounded),
                        label: const Text('Exportar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: controller.importLibrary,
                        icon: const Icon(Icons.download_rounded),
                        label: const Text('Importar'),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                Divider(color: theme.dividerColor.withOpacity(.12)),
                const SizedBox(height: 12),

                const SectionHeader(
                  title: 'Cookies de YouTube',
                  subtitle:
                      'Sube el archivo cookies.txt para descargas de YouTube.',
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: controller.ytdlpAdminTokenController,
                  decoration: const InputDecoration(
                    labelText: 'Token admin',
                    hintText: 'Pega tu token',
                  ),
                  onChanged: controller.setYtDlpAdminToken,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: controller.uploadYtDlpCookies,
                    icon: const Icon(Icons.upload_rounded),
                    label: const Text('Actualizar cookies'),
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

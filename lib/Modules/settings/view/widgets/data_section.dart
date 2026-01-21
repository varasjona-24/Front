import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controller/settings_controller.dart';
import '../widgets/section_header.dart';
import '../widgets/value_pill.dart';
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
              children: [
                // Download quality
                Obx(() {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Expanded(
                            child: SectionHeader(
                              title: 'Calidad de descarga',
                              subtitle:
                                  'Equilibra tamaño de archivo y calidad.',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        controller.getQualityDescription(null),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ChoiceChipRow(
                        options: const [
                          ChoiceOption(value: 'low', label: 'Baja'),
                          ChoiceOption(value: 'medium', label: 'Media'),
                          ChoiceOption(value: 'high', label: 'Alta'),
                        ],
                        selectedValue: controller.downloadQuality.value,
                        onSelected: (v) => controller.setDownloadQuality(v),
                      ),
                    ],
                  );
                }),

                const SizedBox(height: 12),
                Divider(color: theme.dividerColor.withOpacity(.12)),
                const SizedBox(height: 12),

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
                Obx(() {
                  controller.storageTick.value;

                  return FutureBuilder<String>(
                    future: controller.getStorageInfo(),
                    builder: (context, snap) {
                      final loading =
                          snap.connectionState != ConnectionState.done;
                      final value = snap.data;

                      if (loading) {
                        return const InfoTile(
                          icon: Icons.storage_rounded,
                          title: 'Almacenamiento usado',
                          subtitle: 'Calculando…',
                          trailing: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      }

                      return InfoTile(
                        icon: Icons.storage_rounded,
                        title: 'Almacenamiento usado',
                        subtitle: value ?? '—',
                        trailing: ValuePill(text: 'Local'),
                      );
                    },
                  );
                }),

                const SizedBox(height: 12),

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
              ],
            ),
          ),
        ),
      ],
    );
  }
}

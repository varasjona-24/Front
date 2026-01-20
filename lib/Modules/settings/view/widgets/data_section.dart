import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controller/settings_controller.dart';

class DataSection extends GetView<SettingsController> {
  const DataSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 📡 Título
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            '📡 Datos y Descargas',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: 12),

        // 📱 Opciones de datos
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Calidad de descarga
                Obx(
                  () => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('📱 Calidad de descarga'),
                      const SizedBox(height: 4),
                      Text(
                        controller.getQualityDescription(null),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          _buildQualityChip('low', 'Baja', context),
                          _buildQualityChip('medium', 'Media', context),
                          _buildQualityChip('high', 'Alta', context),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Uso de datos
                Obx(
                  () => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('📡 Uso de datos'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          _buildUsageChip('wifi_only', 'Solo Wi-Fi', context),
                          _buildUsageChip('all', 'Wi-Fi y móvil', context),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Limpiar caché
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      controller.clearCache();
                    },
                    icon: const Icon(Icons.delete_sweep),
                    label: const Text('🗑️ Limpiar caché'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQualityChip(String value, String label, BuildContext context) {
    return Obx(
      () => FilterChip(
        label: Text(label),
        selected: controller.downloadQuality.value == value,
        onSelected: (selected) {
          if (selected) {
            controller.setDownloadQuality(value);
          }
        },
      ),
    );
  }

  Widget _buildUsageChip(String value, String label, BuildContext context) {
    return Obx(
      () => FilterChip(
        label: Text(label),
        selected: controller.dataUsage.value == value,
        onSelected: (selected) {
          if (selected) {
            controller.setDataUsage(value);
          }
        },
      ),
    );
  }
}

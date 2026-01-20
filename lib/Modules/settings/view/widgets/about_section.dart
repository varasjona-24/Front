import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controller/settings_controller.dart';

class AboutSection extends GetView<SettingsController> {
  const AboutSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ℹ️ Título
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'ℹ️ Información',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: 12),

        // 📦 Información general
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow(context, 'Versión', '1.0.0'),
                const Divider(height: 16),
                Obx(() {
                  controller.storageTick.value;
                  return FutureBuilder<String>(
                    future: controller.getStorageInfo(),
                    builder: (context, snap) {
                      final value =
                          snap.hasData ? snap.data! : 'Calculando...';
                      return _buildInfoRow(
                        context,
                        'Almacenamiento',
                        value,
                      );
                    },
                  );
                }),
                const Divider(height: 16),
                _buildInfoRow(
                  context,
                  'Última actualización',
                  '20 de enero de 2026',
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => controller.resetSettings(),
                    icon: const Icon(Icons.restart_alt_rounded),
                    label: const Text('Restablecer ajustes'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        Text(value, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

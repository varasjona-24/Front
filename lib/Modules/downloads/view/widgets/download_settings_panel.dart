import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controller/downloads_controller.dart';
import '../../../../Modules/settings/controller/settings_controller.dart';
import '../../../../app/ui/themes/app_spacing.dart';

/// Panel de configuración de descargas dinámico (audio vs video)
class DownloadSettingsPanel extends GetView<DownloadsController> {
  const DownloadSettingsPanel({super.key});

  // ============================
  // 🎨 UI
  // ============================
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final settingsCtrl = Get.find<SettingsController>();

    return Card(
      elevation: 0,
      color: scheme.surfaceContainer,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 📥 Header
            Row(
              children: [
                const SizedBox(width: 1),
                Text(
                  'Configuración de descargas',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // 📊 Calidad de descarga (DINÁMICA)
            Obx(
              () => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Calidad de descarga',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    controller.getQualityDescription(
                      settingsCtrl.downloadQuality.value,
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // 📡 Uso de datos
            Obx(
              () => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Uso de datos',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    controller.getDataUsageDescription(
                      settingsCtrl.dataUsage.value,
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // ℹ️ Información
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_rounded, color: scheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Las descargas usarán diferentes estándares según el tipo: audio (MP3/M4A) o video (MP4/MKV).',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================
  // 🧩 HELPERS UI
  // ============================
  Widget _buildQualityChip({
    required BuildContext context,
    required String label,
    required String value,
    required String audioKbps,
    required String videoP,
    required String current,
    required VoidCallback onTap,
  }) {
    final isSelected = current == value;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? scheme.primary : scheme.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: scheme.primary.withOpacity(isSelected ? 1 : 0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: isSelected ? scheme.onPrimary : scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '🎵 $audioKbps',
              style: theme.textTheme.labelSmall?.copyWith(
                color: isSelected
                    ? scheme.onPrimary.withOpacity(0.8)
                    : scheme.onSurfaceVariant.withOpacity(0.7),
                fontSize: 10,
              ),
            ),
            Text(
              '🎬 $videoP',
              style: theme.textTheme.labelSmall?.copyWith(
                color: isSelected
                    ? scheme.onPrimary.withOpacity(0.8)
                    : scheme.onSurfaceVariant.withOpacity(0.7),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================
  // 🧩 HELPERS UI
  // ============================
  Widget _buildDataUsageChip({
    required BuildContext context,
    required String label,
    required String value,
    required String current,
    required VoidCallback onTap,
  }) {
    final isSelected = current == value;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? scheme.secondary : scheme.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: scheme.secondary.withOpacity(isSelected ? 1 : 0.3),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: isSelected ? scheme.onSecondary : scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

}

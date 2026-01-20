import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controller/downloads_controller.dart';
import '../../../../Modules/settings/controller/settings_controller.dart';
import '../../../../app/ui/themes/app_spacing.dart';
import '../../../../app/models/media_item.dart';

/// Widget tipo "pill" con opciones de descargas
class DownloadsPill extends GetView<DownloadsController> {
  const DownloadsPill({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

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
                Icon(Icons.cloud_download_rounded, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Descargas',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // 🔗 Descargar Online
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showDownloadOnlineDialog(context),
                icon: const Icon(Icons.link_rounded),
                label: const Text('🌐 Descargar desde URL'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: scheme.primary,
                  foregroundColor: scheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 📱 Descargar desde Dispositivo
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _pickLocalFiles(context),
                icon: const Icon(Icons.folder_open_rounded),
                label: const Text('📱 Desde dispositivo local'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 🌐 Dialog mejorado de descargas online
  Future<void> _showDownloadOnlineDialog(BuildContext context) async {
    final urlCtrl = TextEditingController();
    final idCtrl = TextEditingController();
    final settingsCtrl = Get.find<SettingsController>();
    String format = 'mp3';

    bool isVideoFormat(String f) => f == 'mp4';
    String kindForFormat(String f) => isVideoFormat(f) ? 'video' : 'audio';

    try {
      final ok = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (ctx2, setState) {
              return AlertDialog(
                title: const Text('🌐 Descargar desde URL'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 🔗 URL
                      TextField(
                        controller: urlCtrl,
                        keyboardType: TextInputType.url,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'URL',
                          hintText: 'https://www.youtube.com/watch?v=...',
                          prefixIcon: Icon(Icons.link_rounded),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 🏷️ Media ID
                      TextField(
                        controller: idCtrl,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          labelText: 'Media ID (opcional)',
                          helperText:
                              'Si lo dejas vacío, el backend genera uno.',
                          prefixIcon: Icon(Icons.tag_rounded),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 📁 Formato
                      DropdownButtonFormField<String>(
                        value: format,
                        items: const [
                          DropdownMenuItem(
                            value: 'mp3',
                            child: Text('MP3 (audio)'),
                          ),
                          DropdownMenuItem(
                            value: 'm4a',
                            child: Text('M4A (audio)'),
                          ),
                          DropdownMenuItem(
                            value: 'mp4',
                            child: Text('MP4 (video)'),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => format = v);
                        },
                        decoration: const InputDecoration(
                          labelText: 'Formato',
                          prefixIcon: Icon(Icons.file_present_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Tipo: ${kindForFormat(format)}',
                          style: Theme.of(ctx2).textTheme.bodySmall?.copyWith(
                            color: Theme.of(ctx2).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const Divider(height: 24),

                      // ⚙️ Configuración de descargas
                      _buildQualityConfig(
                        context: ctx2,
                        settingsCtrl: settingsCtrl,
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx2).pop(false),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton(
                    onPressed: () {
                      final url = urlCtrl.text.trim();
                      if (url.isEmpty) {
                        ScaffoldMessenger.of(ctx2).showSnackBar(
                          const SnackBar(
                            content: Text('Por favor ingresa una URL'),
                          ),
                        );
                        return;
                      }
                      Navigator.of(ctx2).pop(true);
                    },
                    child: const Text('Descargar'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (ok == true) {
        final url = urlCtrl.text.trim();
        final mid = idCtrl.text.trim();

        await controller.downloadFromUrl(
          mediaId: mid.isEmpty ? null : mid,
          url: url,
          format: format,
        );
      }
    } finally {
      urlCtrl.dispose();
      idCtrl.dispose();
    }
  }

  /// 📁 Descargar desde dispositivo local
  Future<void> _pickLocalFiles(BuildContext context) async {
    await controller.pickLocalFilesForImport();
    if (controller.localFilesForImport.isNotEmpty) {
      if (context.mounted) {
        _showImportDialog(context);
      }
    }
  }

  /// 📋 Dialog para importar archivos locales
  Future<void> _showImportDialog(BuildContext context) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('📱 Archivos del dispositivo'),
          content: Obx(() {
            final list = controller.localFilesForImport;

            if (list.isEmpty) {
              return const Text('No hay archivos seleccionados.');
            }

            return SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: list.length,
                itemBuilder: (ctx2, i) {
                  final item = list[i];
                  final v = item.variants.first;
                  final isVideo = v.kind == MediaVariantKind.video;

                  return ListTile(
                    leading: Icon(
                      isVideo
                          ? Icons.videocam_rounded
                          : Icons.music_note_rounded,
                    ),
                    title: Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      v.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Obx(
                      () => controller.importing.value
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : IconButton(
                              icon: const Icon(Icons.save_alt_rounded),
                              tooltip: 'Importar',
                              onPressed: () => _importItem(context, item, i),
                            ),
                    ),
                  );
                },
              ),
            );
          }),
          actions: [
            TextButton(
              onPressed: () {
                controller.clearLocalFilesForImport();
                Navigator.of(ctx).pop();
              },
              child: const Text('Cerrar'),
            ),
            FilledButton.tonal(
              onPressed: () {
                controller.clearLocalFilesForImport();
                Navigator.of(ctx).pop();
              },
              child: const Text('Limpiar'),
            ),
          ],
        );
      },
    );
  }

  /// 📥 Importar un archivo específico
  Future<void> _importItem(
    BuildContext context,
    MediaItem item,
    int index,
  ) async {
    final result = await controller.importLocalFileToApp(item);
    if (result != null && context.mounted) {
      Get.snackbar(
        '✅ Importado',
        '${item.title} agregado a tu biblioteca',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  /// ⚙️ Widget de configuración de descargas
  Widget _buildQualityConfig({
    required BuildContext context,
    required SettingsController settingsCtrl,
  }) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '⚙️ Configuración',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Obx(
          () => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Calidad: ${settingsCtrl.getQualityDescription(null)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: [
                  _buildQualityOption(context, 'Baja', 'low', settingsCtrl),
                  _buildQualityOption(context, 'Media', 'medium', settingsCtrl),
                  _buildQualityOption(context, 'Alta', 'high', settingsCtrl),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Obx(
          () => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Datos: ${settingsCtrl.dataUsage.value == 'wifi_only' ? 'Solo Wi-Fi' : 'Wi-Fi + Móvil'}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: [
                  _buildDataUsageOption(
                    context,
                    'Wi-Fi',
                    'wifi_only',
                    settingsCtrl,
                  ),
                  _buildDataUsageOption(context, 'Móvil', 'all', settingsCtrl),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQualityOption(
    BuildContext context,
    String label,
    String value,
    SettingsController settingsCtrl,
  ) {
    final isSelected = settingsCtrl.downloadQuality.value == value;
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => settingsCtrl.setDownloadQuality(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? scheme.primary : scheme.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: scheme.primary.withOpacity(isSelected ? 1 : 0.3),
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: isSelected ? scheme.onPrimary : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _buildDataUsageOption(
    BuildContext context,
    String label,
    String value,
    SettingsController settingsCtrl,
  ) {
    final isSelected = settingsCtrl.dataUsage.value == value;
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => settingsCtrl.setDataUsage(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? scheme.secondary : scheme.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: scheme.secondary.withOpacity(isSelected ? 1 : 0.3),
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: isSelected ? scheme.onSecondary : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

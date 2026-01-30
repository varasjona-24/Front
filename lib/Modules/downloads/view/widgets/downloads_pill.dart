import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controller/downloads_controller.dart';
import '../../../../app/ui/themes/app_spacing.dart';
import '../../../../app/models/media_item.dart';
import '../imports_webview_page.dart';

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
                  'Imports',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // 🔗 Importar Online
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () =>
                    DownloadsPill.showImportUrlDialog(context, controller),
                icon: const Icon(Icons.link_rounded),
                label: const Text('🌐 Importar desde URL'),
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
            const SizedBox(height: 12),

            // 🌐 WebView limpio
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Get.to(() => const ImportsWebViewPage()),
                icon: const Icon(Icons.public_rounded),
                label: const Text('🧭 Navegador limpio'),
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
  static Future<void> showImportUrlDialog(
    BuildContext context,
    DownloadsController controller, {
    String? initialUrl,
    bool clearSharedOnClose = false,
  }) async {
    try {
      final result = await showDialog<_ImportUrlResult>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          return _ImportUrlDialog(initialUrl: initialUrl);
        },
      );

      if (result != null) {
        await controller.downloadFromUrl(url: result.url, kind: result.kind);
      }
    } finally {
      if (clearSharedOnClose) {
        controller.sharedUrl.value = '';
      }
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
}

class _ImportUrlResult {
  final String url;
  final String kind;

  const _ImportUrlResult({required this.url, required this.kind});
}

class _ImportUrlDialog extends StatefulWidget {
  final String? initialUrl;

  const _ImportUrlDialog({this.initialUrl});

  @override
  State<_ImportUrlDialog> createState() => _ImportUrlDialogState();
}

class _ImportUrlDialogState extends State<_ImportUrlDialog> {
  late final TextEditingController _urlCtrl;
  String _kind = 'audio';

  @override
  void initState() {
    super.initState();
    _urlCtrl = TextEditingController(text: widget.initialUrl?.trim() ?? '');
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('🌐 Importar desde URL'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 🔗 URL
            TextField(
              controller: _urlCtrl,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'URL',
                hintText: 'https://www.youtube.com/watch?v=...',
                prefixIcon: Icon(Icons.link_rounded),
              ),
            ),
            const SizedBox(height: 18),

            // 📁 Tipo
            DropdownButtonFormField<String>(
              value: _kind,
              items: const [
                DropdownMenuItem(value: 'audio', child: Text('Audio')),
                DropdownMenuItem(value: 'video', child: Text('Video')),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() => _kind = v);
              },
              decoration: const InputDecoration(
                labelText: 'Tipo',
                prefixIcon: Icon(Icons.file_present_rounded),
              ),
            ),
            const Divider(height: 24),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            final url = _urlCtrl.text.trim();
            if (url.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Por favor ingresa una URL')),
              );
              return;
            }
            Navigator.of(context).pop(_ImportUrlResult(url: url, kind: _kind));
          },
          child: const Text('Descargar'),
        ),
      ],
    );
  }
}

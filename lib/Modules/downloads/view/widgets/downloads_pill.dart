import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../controller/downloads_controller.dart';
import '../../../../app/ui/themes/app_spacing.dart';
import '../../../../app/models/media_item.dart';
import '../imports_webview_page.dart';

/// Widget tipo "pill" con opciones de descargas
class DownloadsPill extends GetView<DownloadsController> {
  const DownloadsPill({super.key});

  // ============================
  // 🎨 UI
  // ============================
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
                onPressed: () async {
                  final size = MediaQuery.of(context).size;
                  final scheme = Theme.of(context).colorScheme;
                  await showDialog<void>(
                    context: context,
                    barrierDismissible: true,
                    builder: (ctx) {
                      return Dialog(
                        insetPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 20,
                        ),
                        clipBehavior: Clip.antiAlias,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                        backgroundColor: scheme.surface,
                        child: SizedBox(
                          width: size.width * 0.9,
                          height: size.height * 0.54,
                          child: const ImportsWebViewPage(),
                        ),
                      );
                    },
                  );
                },
                icon: const Icon(Icons.public_rounded),
                label: const Text('🧭 Buscador web'),
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

  // ============================
  // 🌐 IMPORTS URL (DIALOG)
  // ============================
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
        await controller.downloadFromUrl(
          url: result.url,
          kind: result.kind,
        );
      }
    } finally {
      if (clearSharedOnClose) {
        controller.sharedUrl.value = '';
      }
    }
  }

  // ============================
  // 📁 IMPORTS LOCAL
  // ============================
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: scheme.primary.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.link_rounded, color: scheme.primary),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Importar desde URL',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Pega el enlace y elige el tipo de archivo a importar.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _urlCtrl,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(context),
                decoration: InputDecoration(
                  labelText: 'URL',
                  hintText: 'https://www.youtube.com/watch?v=...',
                  prefixIcon: const Icon(Icons.link_rounded),
                  suffixIcon: IconButton(
                    tooltip: 'Pegar',
                    icon: const Icon(Icons.content_paste_rounded),
                    onPressed: () async {
                      final data = await Clipboard.getData('text/plain');
                      final text = data?.text?.trim() ?? '';
                      if (text.isEmpty) return;
                      _urlCtrl.text = text;
                      _urlCtrl.selection = TextSelection.fromPosition(
                        TextPosition(offset: _urlCtrl.text.length),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Tipo de importación',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Audio'),
                      selected: _kind == 'audio',
                      onSelected: (_) => setState(() => _kind = 'audio'),
                      avatar: const Icon(Icons.music_note_rounded, size: 18),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Video'),
                      selected: _kind == 'video',
                      onSelected: (_) => setState(() => _kind = 'video'),
                      avatar: const Icon(Icons.videocam_rounded, size: 18),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _submit(context),
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
    );
  }

  void _submit(BuildContext context) {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor ingresa una URL')),
      );
      return;
    }
    Navigator.of(context).pop(_ImportUrlResult(url: url, kind: _kind));
  }
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/models/media_item.dart';
import '../controller/downloads_controller.dart';

class DownloadsPage extends GetView<DownloadsController> {
  const DownloadsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Downloads'),
        actions: [
          Obx(() {
            final loading = controller.isLoading.value;
            return IconButton(
              tooltip: 'Recargar',
              onPressed: loading ? null : controller.loadDownloads,
              icon: const Icon(Icons.refresh_rounded),
            );
          }),
        ],
      ),

      // ============================
      // ➕ NUEVA DESCARGA
      // ============================
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add_rounded),
        label: const Text('Descargar'),
        tooltip: 'Nueva descarga',
        onPressed: () => _openDownloadDialog(context),
      ),

      // ============================
      // 📄 LISTA
      // ============================
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        final list = controller.downloads;
        if (list.isEmpty) {
          return Center(
            child: Text(
              'No hay descargas.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => controller.loadDownloads(),
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(12),
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) => _DownloadTile(
              item: list[i],
              onPlay: controller.play,
              onDelete: (item) => _confirmDelete(context, item),
            ),
          ),
        );
      }),
    );
  }

  // ============================
  // 🧩 DIALOG: DESCARGA
  // ============================
  Future<void> _openDownloadDialog(BuildContext context) async {
    final urlCtrl = TextEditingController();
    final idCtrl = TextEditingController();
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
                title: const Text('Descargar desde URL'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
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
                      TextField(
                        controller: idCtrl,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          labelText: 'Media ID (opcional)',
                          helperText:
                              'Si lo dejas vacío, el backend genera/usa uno.',
                          prefixIcon: Icon(Icons.tag_rounded),
                        ),
                      ),
                      const SizedBox(height: 16),
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
                          'Tipo detectado: ${kindForFormat(format)}',
                          style: Theme.of(ctx2).textTheme.bodySmall?.copyWith(
                            color: Theme.of(ctx2).colorScheme.onSurfaceVariant,
                          ),
                        ),
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

  // ============================
  // 🧩 CONFIRM: ELIMINAR
  // ============================
  Future<void> _confirmDelete(BuildContext context, MediaItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar'),
        content: const Text('¿Eliminar este archivo descargado?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (ok == true) controller.delete(item);
  }
}

// ============================================================================
// Tile
// ============================================================================

class _DownloadTile extends StatelessWidget {
  final MediaItem item;
  final void Function(MediaItem item) onPlay;
  final void Function(MediaItem item) onDelete;

  const _DownloadTile({
    required this.item,
    required this.onPlay,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final v = item.variants.isNotEmpty ? item.variants.first : null;

    final isVideo = v?.kind == MediaVariantKind.video;
    final icon = isVideo ? Icons.videocam_rounded : Icons.music_note_rounded;

    final subtitle = item.subtitle.isNotEmpty
        ? item.subtitle
        : (v?.localPath ?? v?.fileName ?? '');

    return ListTile(
      leading: Icon(icon),
      title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Wrap(
        spacing: 4,
        children: [
          IconButton(
            icon: const Icon(Icons.play_arrow_rounded),
            tooltip: 'Reproducir',
            onPressed: () => onPlay(item),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Eliminar descarga',
            onPressed: () => onDelete(item),
          ),
        ],
      ),
    );
  }
}

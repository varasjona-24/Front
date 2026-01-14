import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controller/downloads_controller.dart';
import '../../../app/models/media_item.dart';

class DownloadsPage extends GetView<DownloadsController> {
  const DownloadsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Downloads')),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        tooltip: 'Nueva descarga',
        onPressed: () async {
          final urlCtrl = TextEditingController();
          final idCtrl = TextEditingController();
          var format = 'mp3';

          final res = await showDialog<bool>(
            context: context,
            builder: (ctx) => StatefulBuilder(
              builder: (ctx2, setState) {
                return AlertDialog(
                  title: const Text('Descargar desde URL'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: urlCtrl,
                        decoration: const InputDecoration(labelText: 'URL'),
                      ),
                      TextField(
                        controller: idCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Media ID (opcional)',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
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
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx2).pop(false),
                      child: const Text('Cancelar'),
                    ),
                    TextButton(
                      onPressed: () {
                        if (urlCtrl.text.trim().isEmpty) return;
                        Navigator.of(ctx2).pop(true);
                      },
                      child: const Text('Descargar'),
                    ),
                  ],
                );
              },
            ),
          );

          if (res == true) {
            final url = urlCtrl.text.trim();
            final mid = idCtrl.text.trim();
            await controller.downloadFromUrl(
              mediaId: mid.isEmpty ? null : mid,
              url: url,
              format: format,
            );
          }
        },
      ),
      body: Obx(() {
        if (controller.isLoading.value)
          return const Center(child: CircularProgressIndicator());

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

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: list.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final item = list[i];
            final v = item.variants.first;

            return ListTile(
              leading: Icon(
                v.kind == MediaVariantKind.video
                    ? Icons.videocam_rounded
                    : Icons.music_note_rounded,
              ),
              title: Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                item.subtitle.isNotEmpty
                    ? item.subtitle
                    : (v.localPath ?? v.fileName),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Wrap(
                spacing: 8,
                children: [
                  IconButton(
                    icon: const Icon(Icons.play_arrow_rounded),
                    onPressed: () => controller.play(item),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Eliminar descarga',
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Eliminar'),
                          content: const Text(
                            '¿Eliminar este archivo descargado?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: const Text('Cancelar'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(true),
                              child: const Text('Eliminar'),
                            ),
                          ],
                        ),
                      );

                      if (ok == true) controller.delete(item);
                    },
                  ),
                ],
              ),
            );
          },
        );
      }),
    );
  }
}

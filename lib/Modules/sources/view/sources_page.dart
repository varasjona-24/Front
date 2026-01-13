import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controller/sources_controller.dart';
import '../../../app/models/media_item.dart';
import '../../player/audio/view/audio_player_page.dart';

class SourcesPage extends GetView<SourcesController> {
  const SourcesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sources'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear local list',
            onPressed: controller.clearLocal,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Fuentes', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.storage),
                title: const Text('Archivos locales'),
                subtitle: const Text(
                  'Selecciona música o vídeos del dispositivo',
                ),
                trailing: ElevatedButton(
                  onPressed: controller.pickLocalFiles,
                  child: const Text('Seleccionar'),
                ),
              ),
            ),

            const SizedBox(height: 16),
            Text('Archivos locales', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Expanded(
              child: Obx(() {
                final list = controller.localFiles;
                if (list.isEmpty) {
                  return Center(
                    child: Text('No hay archivos locales seleccionados'),
                  );
                }

                return ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final item = list[i];
                    final variant = item.variants.first;
                    final isVideo = variant.kind == MediaVariantKind.video;

                    return ListTile(
                      leading: Icon(
                        isVideo ? Icons.videocam : Icons.music_note,
                      ),
                      title: Text(item.title),
                      subtitle: Text(variant.fileName),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.upload_file),
                            tooltip: 'Subir',
                            onPressed: () async {
                              final ok = await controller.uploadFile(item);
                              final msg = ok ? 'Subida OK' : 'Fallo al subir';
                              Get.snackbar('Upload', msg);
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.play_arrow),
                            tooltip: 'Reproducir',
                            onPressed: () {
                              // Abre el AudioPlayer con esta lista local
                              final queue = List.of(list);
                              Get.to(
                                () => const AudioPlayerPage(),
                                arguments: {'queue': queue, 'index': i},
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

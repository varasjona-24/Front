import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../audio/controller/audio_player_controller.dart';

class QueuePage extends GetView<AudioPlayerController> {
  const QueuePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cola de reproducción'),
        centerTitle: true,
      ),
      body: Obx(() {
        final queue = controller.queue;
        final idx = controller.currentIndex.value;

        if (queue.isEmpty) {
          return const Center(child: Text('La cola está vacía'));
        }

        // total duración en segundos
        final totalSeconds = queue.fold<int>(
          0,
          (s, it) => s + (it.effectiveDurationSeconds ?? 0),
        );

        String fmtDurationTotal(int s) {
          if (s <= 0) return '0:00';
          final h = s ~/ 3600;
          final m = (s % 3600) ~/ 60;
          final sec = s % 60;
          if (h > 0)
            return '${h}:${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
          return '${m}:${sec.toString().padLeft(2, '0')}';
        }

        Future<void> _exportQueue() async {
          try {
            final export = queue
                .map(
                  (it) => {
                    'id': it.id,
                    'title': it.title,
                    'subtitle': it.subtitle,
                    'durationSeconds': it.audioVariant?.durationSeconds,
                  },
                )
                .toList();

            final jsonStr = jsonEncode(export);

            // copia al portapapeles
            await Clipboard.setData(ClipboardData(text: jsonStr));

            // guarda en archivo temporal
            final ts = DateTime.now().toIso8601String().replaceAll(':', '-');
            final fileName = 'listenfy_queue_export_$ts.json';
            final tmpPath = Directory.systemTemp.path;

            final f = File(
              '${tmpPath.endsWith('/') ? tmpPath : '$tmpPath/'}$fileName',
            );
            await f.writeAsString(jsonStr);

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Cola exportada: copiada al portapapeles y guardada en ${f.path}',
                ),
              ),
            );
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error exportando la cola: $e')),
            );
          }
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${queue.length} pistas • Total: ${fmtDurationTotal(totalSeconds)}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.save_alt),
                    tooltip: 'Exportar cola',
                    onPressed: _exportQueue,
                  ),
                ],
              ),
            ),

            Expanded(
              child: ReorderableListView.builder(
                itemCount: queue.length,
                onReorder: (oldIndex, newIndex) async {
                  await controller.reorderQueue(oldIndex, newIndex);
                },
                buildDefaultDragHandles: true,
                itemBuilder: (context, i) {
                  final it = queue[i];
                  final selected = i == idx;

                  String fmtDuration(int? s) {
                    if (s == null || s <= 0) return '';
                    final m = s ~/ 60;
                    final sec = s % 60;
                    return '$m:${sec.toString().padLeft(2, '0')}';
                  }

                  final durText = fmtDuration(it.audioVariant?.durationSeconds);

                  return ListTile(
                    key: ValueKey(it.id),
                    selected: selected,
                    leading: SizedBox(
                      width: 48,
                      height: 48,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child:
                                (it.thumbnail != null &&
                                    it.thumbnail!.isNotEmpty)
                                ? Image.network(
                                    it.thumbnail!,
                                    width: 48,
                                    height: 48,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      width: 48,
                                      height: 48,
                                      color: theme.colorScheme.surfaceVariant,
                                      alignment: Alignment.center,
                                      child: Icon(
                                        Icons.music_note,
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  )
                                : Container(
                                    width: 48,
                                    height: 48,
                                    color: theme.colorScheme.surfaceVariant,
                                    alignment: Alignment.center,
                                    child: Icon(
                                      Icons.music_note,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                          ),

                          if (selected)
                            Positioned(
                              right: -2,
                              bottom: -2,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: theme.colorScheme.surface,
                                    width: 2,
                                  ),
                                ),
                                padding: const EdgeInsets.all(4),
                                child: Icon(
                                  Icons.play_arrow,
                                  size: 12,
                                  color: theme.colorScheme.onPrimary,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    title: Text(
                      it.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: it.subtitle.isNotEmpty ? Text(it.subtitle) : null,
                    onTap: () async {
                      await controller.playAt(i);
                      Get.back();
                    },
                    trailing: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (durText.isNotEmpty)
                          Text(durText, style: theme.textTheme.bodySmall),
                        if (selected) const Text('Reproduciendo'),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      }),
    );
  }
}

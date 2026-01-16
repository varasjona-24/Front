import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../audio/controller/audio_player_controller.dart';
import '../../../../app/models/media_item.dart';
import '../../../../Modules/sources/domain/source_origin.dart';

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
        final queue = controller.queue; // RxList
        final idx = controller.currentIndex.value;

        if (queue.isEmpty) {
          return const Center(child: Text('La cola está vacía'));
        }

        final totalSeconds = queue.fold<int>(
          0,
          (s, it) => s + (it.effectiveDurationSeconds ?? 0),
        );

        Future<void> exportQueue() async {
          try {
            final export = queue
                .map(
                  (it) => {
                    'id': it.id,
                    'publicId': it.publicId,
                    'title': it.title,
                    'subtitle': it.subtitle,
                    'origin': it.origin.key,
                    'durationSeconds': it.effectiveDurationSeconds,
                    'playableUrl': it.playableUrl, // ✅ útil para depurar
                  },
                )
                .toList();

            final jsonStr = jsonEncode(export);

            await Clipboard.setData(ClipboardData(text: jsonStr));

            final ts = DateTime.now().toIso8601String().replaceAll(':', '-');
            final fileName = 'listenfy_queue_export_$ts.json';
            final tmpPath = Directory.systemTemp.path;

            final f = File(_joinPath(tmpPath, fileName));
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
            _header(
              theme: theme,
              count: queue.length,
              totalSeconds: totalSeconds,
              onExport: exportQueue,
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

                  final durText = _fmtDurationShort(
                    it.effectiveDurationSeconds,
                  );

                  return ListTile(
                    key: ValueKey(it.id),
                    selected: selected,
                    leading: _thumb(theme: theme, item: it, selected: selected),
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

  // ===========================================================================
  // UI
  // ===========================================================================

  Widget _header({
    required ThemeData theme,
    required int count,
    required int totalSeconds,
    required VoidCallback onExport,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$count pistas • Total: ${_fmtDurationTotal(totalSeconds)}',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.save_alt),
            tooltip: 'Exportar cola',
            onPressed: onExport,
          ),
        ],
      ),
    );
  }

  Widget _thumb({
    required ThemeData theme,
    required MediaItem item,
    required bool selected,
  }) {
    final thumb = item.effectiveThumbnail?.trim();

    Widget image;
    if (thumb != null && thumb.isNotEmpty) {
      // Si es un path local, lo renderizamos con Image.file
      final looksLikeUrl =
          thumb.startsWith('http://') || thumb.startsWith('https://');
      if (looksLikeUrl) {
        image = Image.network(
          thumb,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _thumbFallback(theme),
        );
      } else {
        image = Image.file(
          File(thumb),
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _thumbFallback(theme),
        );
      }
    } else {
      image = _thumbFallback(theme);
    }

    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ClipRRect(borderRadius: BorderRadius.circular(6), child: image),
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
    );
  }

  Widget _thumbFallback(ThemeData theme) {
    return Container(
      width: 48,
      height: 48,
      color: theme.colorScheme.surfaceVariant,
      alignment: Alignment.center,
      child: Icon(Icons.music_note, color: theme.colorScheme.onSurfaceVariant),
    );
  }

  // ===========================================================================
  // HELPERS
  // ===========================================================================

  String _fmtDurationTotal(int s) {
    if (s <= 0) return '0:00';
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = s % 60;
    if (h > 0) {
      return '${h}:${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
    }
    return '${m}:${sec.toString().padLeft(2, '0')}';
  }

  String _fmtDurationShort(int? s) {
    if (s == null || s <= 0) return '';
    final m = s ~/ 60;
    final sec = s % 60;
    return '$m:${sec.toString().padLeft(2, '0')}';
  }

  String _joinPath(String dir, String file) {
    final d = dir.endsWith('/') ? dir : '$dir/';
    return '$d$file';
  }
}

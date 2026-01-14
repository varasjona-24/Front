import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/data/repo/media_repository.dart';
import '../../../app/models/media_item.dart';
import '../../player/audio/view/audio_player_page.dart';
import '../domain/source_origin.dart';

class SourceLibraryPage extends StatefulWidget {
  const SourceLibraryPage({
    super.key,
    this.origin,
    this.onlyOffline = false,
    required this.title,
  });

  final SourceOrigin? origin;
  final bool onlyOffline;
  final String title;

  @override
  State<SourceLibraryPage> createState() => _SourceLibraryPageState();
}

class _SourceLibraryPageState extends State<SourceLibraryPage> {
  final MediaRepository _repo = Get.find<MediaRepository>();

  late Future<List<MediaItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<MediaItem>> _load() async {
    final all = await _repo.getLibrary();
    Iterable<MediaItem> items = all;

    if (widget.onlyOffline) {
      items = items.where((e) => e.isOfflineStored);
    }

    if (widget.origin != null) {
      items = items.where((e) => e.origin == widget.origin);
    }

    // opcional: ordenar por createdAt del primer variant (nuevo primero)
    final list = items.toList();
    list.sort(
      (a, b) =>
          (b.variants.first.createdAt).compareTo(a.variants.first.createdAt),
    );
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: FutureBuilder<List<MediaItem>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snap.data ?? const <MediaItem>[];
          if (list.isEmpty) {
            return Center(
              child: Text(
                'No hay contenido aquí todavía.',
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
              final v = item.audioVariant ?? item.variants.first;

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
                  item.subtitle.isNotEmpty ? item.subtitle : item.origin.key,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.play_arrow_rounded),
                  onPressed: () {
                    Get.to(
                      () => const AudioPlayerPage(),
                      arguments: {'queue': list, 'index': i},
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

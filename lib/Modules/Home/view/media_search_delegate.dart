import 'package:flutter/material.dart';

import '../../../app/models/media_item.dart';
import '../controller/home_controller.dart';

class MediaSearchDelegate extends SearchDelegate<MediaItem?> {
  MediaSearchDelegate(this.controller);

  final HomeController controller;

  @override
  ThemeData appBarTheme(BuildContext context) {
    final theme = Theme.of(context);
    return theme.copyWith(
      appBarTheme: theme.appBarTheme.copyWith(elevation: 0),
      inputDecorationTheme: theme.inputDecorationTheme.copyWith(
        hintStyle: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildResultsList(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.trim().isEmpty) {
      return _buildSuggestions(context);
    }
    return _buildResultsList(context);
  }

  Widget _buildSuggestions(BuildContext context) {
    final recent = controller.recentlyPlayed;
    if (recent.isEmpty) {
      return _emptyState(context, 'Empieza a escribir para buscar.');
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: recent.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = recent[index];
        return _resultTile(context, item, recent, index);
      },
    );
  }

  Widget _buildResultsList(BuildContext context) {
    final list = _searchItems(query);
    if (list.isEmpty) {
      return _emptyState(context, 'No hay resultados.');
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = list[index];
        return _resultTile(context, item, list, index);
      },
    );
  }

  List<MediaItem> _searchItems(String rawQuery) {
    final q = rawQuery.trim().toLowerCase();
    if (q.isEmpty) return <MediaItem>[];

    final isAudioMode = controller.mode.value == HomeMode.audio;

    return controller.allItems.where((item) {
      final matchesMode = isAudioMode ? item.hasAudioLocal : item.hasVideoLocal;
      if (!matchesMode) return false;

      final title = item.title.toLowerCase();
      final subtitle = item.displaySubtitle.toLowerCase();
      return title.contains(q) || subtitle.contains(q);
    }).toList();
  }

  Widget _resultTile(
    BuildContext context,
    MediaItem item,
    List<MediaItem> list,
    int index,
  ) {
    final isVideo = item.hasVideoLocal || item.localVideoVariant != null;
    final icon = isVideo ? Icons.videocam_rounded : Icons.music_note_rounded;

    return ListTile(
      leading: Icon(icon),
      title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        item.displaySubtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () {
        close(context, item);
        controller.openMedia(item, index, list);
      },
    );
  }

  Widget _emptyState(BuildContext context, String text) {
    final theme = Theme.of(context);
    return Center(
      child: Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

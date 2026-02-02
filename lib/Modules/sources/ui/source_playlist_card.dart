import 'dart:io';

import 'package:flutter/material.dart';

import '../domain/source_theme.dart';
import '../domain/source_theme_topic_playlist.dart';

// ============================
// 🧱 UI: CARD DE PLAYLIST
// ============================
class SourcePlaylistCard extends StatelessWidget {
  const SourcePlaylistCard({
    super.key,
    required this.theme,
    required this.playlist,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  final SourceTheme theme;
  final SourceThemeTopicPlaylist playlist;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final base = playlist.colorValue != null
        ? Color(playlist.colorValue!)
        : theme.colors.first;
    final textColor = Colors.white;

    ImageProvider? provider;
    final path = playlist.coverLocalPath?.trim();
    final url = playlist.coverUrl?.trim();
    if (path != null && path.isNotEmpty) {
      provider = FileImage(File(path));
    } else if (url != null && url.isNotEmpty) {
      provider = NetworkImage(url);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            color: base.withOpacity(0.92),
          ),
          child: InkWell(
            onTap: onOpen,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 52,
                      height: 52,
                      color: Colors.black.withOpacity(0.18),
                      child: provider != null
                          ? Image(image: provider, fit: BoxFit.cover)
                          : Icon(Icons.queue_music_rounded, color: textColor),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          playlist.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.textTheme.titleMedium?.copyWith(
                            color: textColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${playlist.itemIds.length} items',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.textTheme.bodySmall?.copyWith(
                            color: textColor.withOpacity(0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<_SourcePlaylistAction>(
                    onSelected: (value) {
                      if (value == _SourcePlaylistAction.edit) onEdit();
                      if (value == _SourcePlaylistAction.delete) onDelete();
                    },
                    itemBuilder: (ctx) => const [
                      PopupMenuItem(
                        value: _SourcePlaylistAction.edit,
                        child: Text('Editar'),
                      ),
                      PopupMenuItem(
                        value: _SourcePlaylistAction.delete,
                        child: Text('Eliminar'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _SourcePlaylistAction { edit, delete }

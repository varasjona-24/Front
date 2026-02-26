import 'dart:io';

import 'package:flutter/material.dart';

import '../domain/source_theme.dart';
import '../domain/source_theme_topic_playlist.dart';

// ============================
// 🧱 UI: CARD DE PLAYLIST
// ============================
class SourcePlaylistCard extends StatefulWidget {
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
  State<SourcePlaylistCard> createState() => _SourcePlaylistCardState();
}

class _SourcePlaylistCardState extends State<SourcePlaylistCard> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final playlist = widget.playlist;
    final base = playlist.colorValue != null
        ? Color(playlist.colorValue!)
        : widget.theme.colors.first;
    final textColor = Colors.white;
    final scale = _isPressed ? 0.97 : (_isHovered ? 1.01 : 1.0);

    ImageProvider? provider;
    final path = playlist.coverLocalPath?.trim();
    final url = playlist.coverUrl?.trim();
    if (path != null && path.isNotEmpty) {
      provider = FileImage(File(path));
    } else if (url != null && url.isNotEmpty) {
      provider = NetworkImage(url);
    }

    return AnimatedScale(
      scale: scale,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.onOpen();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [base.withOpacity(0.95), base.withOpacity(0.8)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: base.withOpacity(0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Subtle glass overlay
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withOpacity(0.12),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.2),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              child: provider != null
                                  ? Image(image: provider, fit: BoxFit.cover)
                                  : Icon(
                                      Icons.queue_music_rounded,
                                      color: textColor,
                                    ),
                            ),
                          ),
                          const SizedBox(width: 14),
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
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${playlist.itemIds.length} items',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: t.textTheme.bodySmall?.copyWith(
                                    color: textColor.withOpacity(0.85),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuButton<_SourcePlaylistAction>(
                            onSelected: (value) {
                              if (value == _SourcePlaylistAction.edit)
                                widget.onEdit();
                              if (value == _SourcePlaylistAction.delete)
                                widget.onDelete();
                            },
                            icon: Icon(
                              Icons.more_vert_rounded,
                              color: textColor.withOpacity(0.9),
                            ),
                            color: t.colorScheme.surface,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(
                                value: _SourcePlaylistAction.edit,
                                child: Text('Editar'),
                              ),
                              const PopupMenuItem(
                                value: _SourcePlaylistAction.delete,
                                child: Text('Eliminar'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _SourcePlaylistAction { edit, delete }

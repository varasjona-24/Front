import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../models/media_item.dart';
import '../../themes/app_spacing.dart';

class MediaCard extends StatefulWidget {
  final MediaItem item;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double width;

  const MediaCard({
    super.key,
    required this.item,
    this.onTap,
    this.onLongPress,
    this.width = 140,
  });

  @override
  State<MediaCard> createState() => _MediaCardState();
}

class _MediaCardState extends State<MediaCard> {
  Timer? _holdTimer;
  bool _fired = false;

  @override
  void dispose() {
    _holdTimer?.cancel();
    super.dispose();
  }

  void _startHold() {
    if (widget.onLongPress == null) return;
    _holdTimer?.cancel();
    _fired = false;
    _holdTimer = Timer(const Duration(seconds: 2), () {
      _fired = true;
      widget.onLongPress?.call();
    });
  }

  void _cancelHold() {
    if (_fired) return;
    _holdTimer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _startHold(),
      onTapUp: (_) => _cancelHold(),
      onTapCancel: _cancelHold,
      onPanStart: (_) => _cancelHold(),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: widget.onTap,
        splashColor: colors.primary.withOpacity(0.1),
        highlightColor: colors.primary.withOpacity(0.05),
        child: SizedBox(
          width: widget.width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🎨 THUMBNAIL / COVER
              AspectRatio(
                aspectRatio: 1,
                child: Container(
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: _buildThumbnail(context),
                ),
              ),

              const SizedBox(height: AppSpacing.sm),

              // 🏷 TITLE
              Text(
                widget.item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),

              const SizedBox(height: AppSpacing.xs),

              // 🏷 SUBTITLE
              Text(
                widget.item.displaySubtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    // 1) ✅ Preferir thumbnail local si existe
    final local = widget.item.thumbnailLocalPath?.trim();
    if (local != null && local.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(
          File(local),
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, __, ___) => _fallbackIcon(colors),
        ),
      );
    }

    // 2) 🌐 Fallback a thumbnail remoto
    final remote = widget.item.thumbnail?.trim();
    if (remote != null && remote.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          remote,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, __, ___) => _fallbackIcon(colors),
        ),
      );
    }

    // 3) 🎵 Placeholder
    return _fallbackIcon(colors);
  }

  Widget _fallbackIcon(ColorScheme colors) {
    final isVideo =
        widget.item.hasVideoLocal || widget.item.localVideoVariant != null;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Icon(
        isVideo ? Icons.videocam_rounded : Icons.music_note_rounded,
        size: 42,
        color: colors.onSurface.withOpacity(0.6),
      ),
    );
  }
}

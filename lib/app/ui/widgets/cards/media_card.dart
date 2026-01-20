import 'dart:io';

import 'package:flutter/material.dart';

import '../../../models/media_item.dart';
import '../../themes/app_spacing.dart';

class MediaCard extends StatelessWidget {
  final MediaItem item;
  final VoidCallback? onTap;
  final double width;

  const MediaCard({
    super.key,
    required this.item,
    this.onTap,
    this.width = 140,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      splashColor: colors.primary.withOpacity(0.1),
      highlightColor: colors.primary.withOpacity(0.05),
      child: SizedBox(
        width: width,
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
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),

            const SizedBox(height: AppSpacing.xs),

            // 🏷 SUBTITLE
            Text(
              item.displaySubtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    // 1) ✅ Preferir thumbnail local si existe
    final local = item.thumbnailLocalPath?.trim();
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
    final remote = item.thumbnail?.trim();
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
    final isVideo = item.hasVideoLocal || item.localVideoVariant != null;

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

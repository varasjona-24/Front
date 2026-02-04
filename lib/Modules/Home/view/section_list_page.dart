import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../app/models/media_item.dart';
import '../../../app/ui/themes/app_spacing.dart';
import '../../../app/ui/widgets/layout/app_gradient_background.dart';

class SectionListPage extends StatelessWidget {
  const SectionListPage({
    super.key,
    required this.title,
    required this.items,
    required this.onItemTap,
    required this.onItemLongPress,
    this.onShuffle,
  });

  final String title;
  final List<MediaItem> items;
  final void Function(MediaItem item, int index) onItemTap;
  final void Function(MediaItem item, int index) onItemLongPress;
  final void Function(List<MediaItem> queue)? onShuffle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: scheme.surface,
        surfaceTintColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
      ),
      body: AppGradientBackground(
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.lg,
          ),
          itemCount: items.length + 1,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            if (index == 0) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (onShuffle != null) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () {
                          final queue = List<MediaItem>.from(items);
                          queue.shuffle(Random());
                          if (queue.isEmpty) return;
                          onShuffle?.call(queue);
                        },
                        icon: const Icon(Icons.shuffle_rounded),
                        label: const Text('Reproducción aleatoria'),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                ],
              );
            }

            final item = items[index - 1];
            return _MediaRow(
              item: item,
              onTap: () => onItemTap(item, index - 1),
              onLongPress: () => onItemLongPress(item, index - 1),
            );
          },
        ),
      ),
    );
  }
}

class _MediaRow extends StatelessWidget {
  const _MediaRow({
    required this.item,
    required this.onTap,
    required this.onLongPress,
  });

  final MediaItem item;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            _Thumb(thumb: item.effectiveThumbnail),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.displaySubtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: scheme.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.play_arrow_rounded,
                color: scheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.thumb});

  final String? thumb;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (thumb != null && thumb!.isNotEmpty) {
      final provider = thumb!.startsWith('http')
          ? NetworkImage(thumb!)
          : FileImage(File(thumb!)) as ImageProvider;
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image(
          image: provider,
          width: 56,
          height: 56,
          fit: BoxFit.cover,
        ),
      );
    }
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(Icons.music_note, color: scheme.onSurfaceVariant),
    );
  }
}

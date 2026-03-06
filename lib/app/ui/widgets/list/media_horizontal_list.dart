import 'package:flutter/material.dart';

import '../../../models/media_item.dart';
import '../../themes/app_spacing.dart';
import '../cards/media_card.dart';
import '../cards/media_cart_skeletton.dart';

class MediaHorizontalList extends StatelessWidget {
  final String title;
  final List<MediaItem> items;
  final bool isLoading;
  final void Function(MediaItem item, int index) onItemTap;
  final void Function(MediaItem item, int index)? onItemLongPress;
  final VoidCallback? onHeaderTap;
  final Widget? headerTrailing;
  final String? Function(MediaItem item, int index)? itemHintBuilder;

  const MediaHorizontalList({
    super.key,
    required this.title,
    required this.items,
    required this.onItemTap,
    this.onItemLongPress,
    this.isLoading = false,
    this.onHeaderTap,
    this.headerTrailing,
    this.itemHintBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final titleStyle = theme.textTheme.titleLarge?.copyWith(
      color: scheme.onSurface,
      fontWeight: FontWeight.w700,
    );

    Widget header() => Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onHeaderTap,
              child: Row(
                children: [
                  Expanded(child: Text(title, style: titleStyle)),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (headerTrailing != null) ...[
            const SizedBox(width: 8),
            headerTrailing!,
          ],
        ],
      ),
    );

    if (isLoading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header(),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 190,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              itemCount: 6,
              separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
              itemBuilder: (_, __) => const MediaCardSkeleton(),
            ),
          ),
        ],
      );
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header(),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: itemHintBuilder == null ? 200 : 216,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
            itemBuilder: (context, index) {
              final item = items[index];
              return MediaCard(
                item: item,
                width: 120,
                hintText: itemHintBuilder?.call(item, index),
                onTap: () => onItemTap(item, index),
                onLongPress: onItemLongPress == null
                    ? null
                    : () => onItemLongPress!(item, index),
              );
            },
          ),
        ),
      ],
    );
  }
}

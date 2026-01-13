import 'package:flutter/material.dart';

import '../../../models/media_item.dart';
import '../../themes/app_spacing.dart';
import 'media_card.dart';

class MediaGrid extends StatelessWidget {
  final List<MediaItem> items;
  final void Function(MediaItem item)? onItemTap;

  const MediaGrid({super.key, required this.items, this.onItemTap});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        int crossAxisCount = 2;

        if (width >= 900) {
          crossAxisCount = 5;
        } else if (width >= 700) {
          crossAxisCount = 4;
        } else if (width >= 600) {
          crossAxisCount = 3;
        }

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: GridView.builder(
            key: ValueKey(crossAxisCount),
            padding: const EdgeInsets.all(AppSpacing.md),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: AppSpacing.md,
              mainAxisSpacing: AppSpacing.md,
              childAspectRatio: 0.75,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];

              return MediaCard(
                item: item,
                onTap: onItemTap != null ? () => onItemTap!(item) : () {},
              );
            },
          ),
        );
      },
    );
  }
}

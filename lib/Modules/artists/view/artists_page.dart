import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/ui/themes/app_spacing.dart';
import '../../../app/ui/widgets/navigation/app_bottom_nav.dart';
import '../../../app/ui/widgets/navigation/app_top_bar.dart';
import '../../../app/ui/widgets/branding/listenfy_logo.dart';
import 'package:flutter_listenfy/Modules/home/controller/home_controller.dart';
import '../controller/artists_controller.dart';
import 'artist_detail_page.dart';
import 'edit_artist_page.dart';

class ArtistsPage extends GetView<ArtistsController> {
  const ArtistsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final bg = Color.alphaBlend(
      scheme.primary.withOpacity(isDark ? 0.02 : 0.06),
      scheme.surface,
    );

    final barBg = Color.alphaBlend(
      scheme.primary.withOpacity(isDark ? 0.24 : 0.28),
      scheme.surface,
    );

    final home = Get.find<HomeController>();

    return Obx(() {
      return Scaffold(
        backgroundColor: bg,
        extendBody: true,
        appBar: AppTopBar(
          title: ListenfyLogo(size: 28, color: scheme.primary),
          onSearch: home.onSearch,
          onToggleMode: home.toggleMode,
          mode: home.mode.value == HomeMode.audio
              ? AppMediaMode.audio
              : AppMediaMode.video,
        ),
        body: Stack(
          children: [
            Positioned.fill(
              child: controller.isLoading.value
                  ? const Center(child: CircularProgressIndicator())
                  : ScrollConfiguration(
                      behavior: const _NoGlowScrollBehavior(),
                      child: SingleChildScrollView(
                        padding: EdgeInsets.only(
                          top: AppSpacing.md,
                          bottom: kBottomNavigationBarHeight + 18,
                          left: AppSpacing.md,
                          right: AppSpacing.md,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _header(theme),
                            const SizedBox(height: AppSpacing.md),
                            _searchBar(theme),
                            const SizedBox(height: AppSpacing.md),
                            _sortBar(theme),
                            const SizedBox(height: AppSpacing.lg),
                            _artistList(),
                          ],
                        ),
                      ),
                    ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: barBg,
                  border: Border(
                    top: BorderSide(
                      color: scheme.primary.withOpacity(isDark ? 0.22 : 0.18),
                      width: 56,
                    ),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: AppBottomNav(
                    currentIndex: 2,
                    onTap: (index) {
                      switch (index) {
                        case 0:
                          home.enterHome();
                          break;
                        case 1:
                          home.goToPlaylists();
                          break;
                        case 2:
                          home.goToArtists();
                          break;
                        case 3:
                          home.goToDownloads();
                          break;
                        case 4:
                          home.goToSources();
                          break;
                      }
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _header(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Artistas',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Biblioteca organizada por artista',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _searchBar(ThemeData theme) {
    return TextField(
      onChanged: controller.setQuery,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search),
        hintText: 'Buscar artista...',
        filled: true,
        fillColor: theme.colorScheme.surfaceContainer,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _sortBar(ThemeData theme) {
    return Obx(
      () => Row(
        children: [
          const Icon(Icons.sort_rounded),
          const SizedBox(width: 8),
          Expanded(
            child: SegmentedButton<ArtistSort>(
              segments: const [
                ButtonSegment(value: ArtistSort.name, label: Text('A-Z')),
                ButtonSegment(value: ArtistSort.count, label: Text('Cantidad')),
              ],
              selected: {controller.sort.value},
              onSelectionChanged: (value) => controller.setSort(value.first),
            ),
          ),
        ],
      ),
    );
  }

  Widget _artistList() {
    return Obx(() {
      final list = controller.filtered;
      if (list.isEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(
              'No hay artistas disponibles.',
              style: Get.textTheme.bodyMedium?.copyWith(
                color: Get.theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        );
      }

      return Column(
        children: [
          for (final artist in list)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ArtistCard(
                artist: artist,
                onOpen: () =>
                    Get.to(() => ArtistDetailPage(artistKey: artist.key)),
                onEdit: () => Get.to(() => EditArtistPage(artist: artist)),
              ),
            ),
        ],
      );
    });
  }
}

class _ArtistCard extends StatelessWidget {
  const _ArtistCard({
    required this.artist,
    required this.onOpen,
    required this.onEdit,
  });

  final ArtistGroup artist;
  final VoidCallback onOpen;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final thumb = artist.thumbnailLocalPath ?? artist.thumbnail;

    return Card(
      elevation: 0,
      color: scheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ListTile(
        leading: _ArtistAvatar(thumb: thumb),
        title: Text(artist.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text('${artist.count} canciones'),
        trailing: IconButton(
          icon: const Icon(Icons.edit_rounded),
          onPressed: onEdit,
        ),
        onTap: onOpen,
      ),
    );
  }
}

class _ArtistAvatar extends StatelessWidget {
  const _ArtistAvatar({required this.thumb});

  final String? thumb;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (thumb != null && thumb!.isNotEmpty) {
      return CircleAvatar(
        radius: 24,
        backgroundColor: scheme.surface,
        backgroundImage: thumb!.startsWith('http')
            ? NetworkImage(thumb!)
            : FileImage(File(thumb!)) as ImageProvider,
      );
    }

    return CircleAvatar(
      radius: 24,
      backgroundColor: scheme.surface,
      child: Icon(Icons.person_rounded, color: scheme.onSurfaceVariant),
    );
  }
}

class _NoGlowScrollBehavior extends ScrollBehavior {
  const _NoGlowScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}

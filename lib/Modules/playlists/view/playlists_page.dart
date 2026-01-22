import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/ui/themes/app_spacing.dart';
import '../../../app/ui/widgets/branding/listenfy_logo.dart';
import '../../../app/ui/widgets/layout/app_gradient_background.dart';
import '../../../app/ui/widgets/navigation/app_bottom_nav.dart';
import '../../../app/ui/widgets/navigation/app_top_bar.dart';
import '../../../app/models/media_item.dart';
import '../../home/controller/home_controller.dart';
import '../../player/audio/controller/audio_player_controller.dart';
import '../controller/playlists_controller.dart';
import '../domain/playlist.dart';
import 'playlist_detail_page.dart';

class PlaylistsPage extends GetView<PlaylistsController> {
  const PlaylistsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final barBg = Color.alphaBlend(
      scheme.primary.withOpacity(isDark ? 0.24 : 0.28),
      scheme.surface,
    );

    final home = Get.find<HomeController>();

    return Obx(() {
      final smart = controller.smartPlaylists;
      final list = controller.playlists;
      final total = smart.length + list.length;

      return Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        appBar: AppTopBar(
          title: ListenfyLogo(size: 28, color: scheme.primary),
          onSearch: home.onSearch,
        ),
        body: AppGradientBackground(
          child: Stack(
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
                              const SizedBox(height: 10),
                              _summaryRow(
                                theme: theme,
                                total: total,
                                onAdd: () => _createPlaylist(context),
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              if (smart.isNotEmpty) ...[
                                _smartGrid(smart),
                                const SizedBox(height: AppSpacing.lg),
                              ],
                              _myPlaylistsHeader(theme, list.length),
                              const SizedBox(height: 10),
                              _myPlaylists(list),
                              const SizedBox(height: AppSpacing.lg),
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
                      currentIndex: 1,
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
        ),
      );
    });
  }

  Widget _header(ThemeData theme) {
    return Text(
      'Listas de reproducción',
      style: theme.textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w800,
      ),
    );
  }

  Widget _summaryRow({
    required ThemeData theme,
    required int total,
    required VoidCallback onAdd,
  }) {
    return Row(
      children: [
        Text(
          '$total listas de reproducción',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.add),
          tooltip: 'Nueva lista',
          onPressed: onAdd,
        ),
      ],
    );
  }

  Widget _smartGrid(List<SmartPlaylist> smart) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: smart.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.15,
      ),
      itemBuilder: (context, index) {
        final data = smart[index];
        return _SmartPlaylistCard(
          data: data,
          onOpen: () => Get.to(
            () => PlaylistDetailPage.smart(playlistId: data.id),
          ),
        );
      },
    );
  }

  Widget _myPlaylistsHeader(ThemeData theme, int count) {
    return Text(
      'Mis listas de reproducción ($count)',
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _myPlaylists(List<Playlist> list) {
    if (list.isEmpty) {
      return Text(
        'Crea tu primera lista para organizar tu música.',
        style: Get.textTheme.bodyMedium?.copyWith(
          color: Get.theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    return Column(
      children: [
        for (final playlist in list)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _PlaylistTile(
              playlist: playlist,
              resolveItems: controller.resolvePlaylistItems,
              onOpen: () => Get.to(
                () => PlaylistDetailPage.custom(playlistId: playlist.id),
              ),
              onMenu: () => _openPlaylistActions(Get.context!, playlist),
            ),
          ),
      ],
    );
  }

  Future<void> _createPlaylist(BuildContext context) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nueva lista'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'Nombre de la lista'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Crear'),
          ),
        ],
      ),
    );

    if (ok == true) {
      await controller.createPlaylist(ctrl.text);
    }
    ctrl.dispose();
  }

  Future<void> _openPlaylistActions(
    BuildContext context,
    Playlist playlist,
  ) async {
    final theme = Theme.of(context);
    final items = controller.resolvePlaylistItems(playlist);
    final thumb = playlist.coverLocalPath?.trim().isNotEmpty == true
        ? playlist.coverLocalPath
        : (playlist.coverUrl?.trim().isNotEmpty == true
            ? playlist.coverUrl
            : items.isNotEmpty
                ? items.first.effectiveThumbnail
                : null);

    ImageProvider? provider;
    if (thumb != null && thumb.isNotEmpty) {
      provider = thumb.startsWith('http')
          ? NetworkImage(thumb)
          : FileImage(File(thumb));
    }

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 44,
                      height: 44,
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: provider != null
                          ? Image(image: provider, fit: BoxFit.cover)
                          : Icon(Icons.music_note_rounded,
                              color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                  title: Text(
                    playlist.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text('${items.length} canciones'),
                ),
                ListTile(
                  leading: const Icon(Icons.play_arrow_rounded),
                  title: const Text('Reproducir'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _playPlaylist(items);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.skip_next_rounded),
                  title: const Text('Reproducir siguiente'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _playNext(items);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.queue_music_rounded),
                  title: const Text('Añadir a la cola'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _addToQueue(items);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.edit_rounded),
                  title: const Text('Renombrar'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _renamePlaylist(context, playlist);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.image_rounded),
                  title: const Text('Cambiar portada'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _changeCover(context, playlist);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded),
                  title: const Text('Eliminar lista de reproducción'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _confirmDelete(context, playlist);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _playPlaylist(List<MediaItem> items) {
    if (items.isEmpty) return;
    Get.toNamed(
      AppRoutes.audioPlayer,
      arguments: {'queue': items, 'index': 0},
    );
  }

  void _playNext(List<MediaItem> items) {
    if (items.isEmpty) return;
    if (Get.isRegistered<AudioPlayerController>()) {
      final audio = Get.find<AudioPlayerController>();
      audio.insertNext(items);
      Get.snackbar('Cola', 'Se agregó como siguiente');
      return;
    }
    Get.snackbar('Cola', 'Abre el reproductor para usar esta opción');
  }

  void _addToQueue(List<MediaItem> items) {
    if (items.isEmpty) return;
    if (Get.isRegistered<AudioPlayerController>()) {
      final audio = Get.find<AudioPlayerController>();
      audio.addToQueue(items);
      Get.snackbar('Cola', 'Se agregaron a la cola');
      return;
    }
    Get.snackbar('Cola', 'Abre el reproductor para usar esta opción');
  }

  Future<void> _renamePlaylist(BuildContext context, Playlist playlist) async {
    final ctrl = TextEditingController(text: playlist.name);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Renombrar'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'Nuevo nombre'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (ok == true) {
      await controller.renamePlaylist(playlist.id, ctrl.text);
    }
    ctrl.dispose();
  }

  Future<void> _changeCover(BuildContext context, Playlist playlist) async {
    final urlCtrl = TextEditingController(text: playlist.coverUrl ?? '');
    String? localPath = playlist.coverLocalPath;
    bool confirmed = false;

    Future<void> pickLocal() async {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
      );
      final file = (res != null && res.files.isNotEmpty) ? res.files.first : null;
      if (file?.path == null) return;
      localPath = file!.path!;
      urlCtrl.text = '';
    }

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cambiar portada'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: urlCtrl,
              decoration: const InputDecoration(
                hintText: 'https://...',
                labelText: 'URL (opcional)',
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () async {
                await pickLocal();
              },
              icon: const Icon(Icons.folder_open_rounded),
              label: const Text('Elegir archivo'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              confirmed = true;
              Navigator.of(ctx).pop();
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (!confirmed) {
      urlCtrl.dispose();
      return;
    }

    final url = urlCtrl.text.trim();
    await controller.updateCover(
      playlist.id,
      coverUrl: url.isNotEmpty ? url : null,
      coverLocalPath: url.isNotEmpty ? null : localPath,
    );
    urlCtrl.dispose();
  }

  Future<void> _confirmDelete(BuildContext context, Playlist playlist) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar lista'),
        content: const Text('¿Seguro que quieres eliminar esta lista?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await controller.deletePlaylist(playlist.id);
    }
  }
}

class _SmartPlaylistCard extends StatelessWidget {
  const _SmartPlaylistCard({required this.data, required this.onOpen});

  final SmartPlaylist data;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final thumb = data.items.isNotEmpty ? data.items.first.effectiveThumbnail : null;
    ImageProvider? provider;
    if (thumb != null && thumb.isNotEmpty) {
      provider = thumb.startsWith('http')
          ? NetworkImage(thumb)
          : FileImage(File(thumb));
    }

    final textColor = isDark ? Colors.white : theme.colorScheme.onSurface;
    final subColor = isDark
        ? Colors.white.withOpacity(0.85)
        : theme.colorScheme.onSurfaceVariant;
    final iconColor = isDark ? Colors.white : theme.colorScheme.onSurface;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onOpen,
      child: Ink(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: data.colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.black.withOpacity(isDark ? 0.12 : 0.08),
          ),
          boxShadow: [
            BoxShadow(
              blurRadius: 18,
              offset: const Offset(0, 10),
              color: Colors.black.withOpacity(isDark ? 0.35 : 0.2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${data.items.length} canciones',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: subColor,
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Icon(data.icon, color: iconColor),
                  const Spacer(),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 40,
                      height: 40,
                      color: Colors.white.withOpacity(isDark ? 0.18 : 0.22),
                      child: provider != null
                          ? Image(image: provider, fit: BoxFit.cover)
                          : Icon(Icons.play_arrow_rounded, color: iconColor),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaylistTile extends StatelessWidget {
  const _PlaylistTile({
    required this.playlist,
    required this.onOpen,
    required this.onMenu,
    required this.resolveItems,
  });

  final Playlist playlist;
  final VoidCallback onOpen;
  final VoidCallback onMenu;
  final List<MediaItem> Function(Playlist) resolveItems;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final items = resolveItems(playlist);
    final thumb = playlist.coverLocalPath?.trim().isNotEmpty == true
        ? playlist.coverLocalPath
        : (playlist.coverUrl?.trim().isNotEmpty == true
            ? playlist.coverUrl
            : items.isNotEmpty
                ? items.first.effectiveThumbnail
                : null);

    ImageProvider? provider;
    if (thumb != null && thumb!.isNotEmpty) {
      provider = thumb!.startsWith('http')
          ? NetworkImage(thumb!)
          : FileImage(File(thumb!));
    }

    return Card(
      elevation: 0,
      color: scheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ListTile(
        onTap: onOpen,
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 54,
            height: 54,
            color: scheme.surfaceContainerHighest,
            child: provider != null
                ? Image(image: provider, fit: BoxFit.cover)
                : Icon(Icons.music_note_rounded,
                    color: scheme.onSurfaceVariant),
          ),
        ),
        title: Text(
          playlist.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text('${items.length} canciones'),
        trailing: IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: onMenu,
        ),
      ),
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

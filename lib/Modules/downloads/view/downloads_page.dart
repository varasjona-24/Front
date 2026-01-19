import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/models/media_item.dart';
import '../controller/downloads_controller.dart';
import '../../../app/ui/widgets/navigation/app_top_bar.dart';
import '../../../app/ui/widgets/navigation/app_bottom_nav.dart';
import '../../../app/ui/themes/app_spacing.dart';
import '../../../app/ui/widgets/branding/listenfy_logo.dart';
import 'package:flutter_listenfy/Modules/home/controller/home_controller.dart';

class DownloadsPage extends GetView<DownloadsController> {
  const DownloadsPage({super.key});

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

    final HomeController home = Get.find<HomeController>();

    return Obx(() {
      final mode = home.mode.value;

      return Scaffold(
        backgroundColor: bg,
        extendBody: true,
        appBar: AppTopBar(
          title: ListenfyLogo(size: 28, color: scheme.primary),
          onSearch: home.onSearch,
          onToggleMode: home.toggleMode,
          mode: mode == HomeMode.audio
              ? AppMediaMode.audio
              : AppMediaMode.video,
        ),

        // ============================
        // 📄 LISTA
        // ============================
        body: Stack(
          children: [
            Positioned.fill(
              child: Obx(() {
                if (controller.isLoading.value) {
                  return const Center(child: CircularProgressIndicator());
                }

                final list = controller.downloads;

                return ScrollConfiguration(
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
                        _header(theme: theme, context: context),
                        const SizedBox(height: AppSpacing.lg),
                        if (list.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpacing.lg),
                              child: Text(
                                'No hay descargas aún.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          )
                        else
                          Column(
                            children: List.generate(
                              list.length,
                              (i) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _DownloadTile(
                                  item: list[i],
                                  onPlay: controller.play,
                                  onDelete: (item) =>
                                      _confirmDelete(context, item),
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                    ),
                  ),
                );
              }),
            ),

            _bottomNav(
              barBg: barBg,
              scheme: scheme,
              isDark: isDark,
              home: home,
            ),
          ],
        ),
      );
    });
  }

  // ============================
  // UI SECTIONS
  // ============================
  Widget _header({required ThemeData theme, required BuildContext context}) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Descargas',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Archivos descargados en tu dispositivo',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        FilledButton.tonalIcon(
          onPressed: () => _openDownloadDialog(context),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Descargar'),
        ),
      ],
    );
  }

  // ============================
  // 🧩 DIALOG: DESCARGA
  // ============================
  Future<void> _openDownloadDialog(BuildContext context) async {
    final urlCtrl = TextEditingController();
    final idCtrl = TextEditingController();
    String format = 'mp3';

    bool isVideoFormat(String f) => f == 'mp4';
    String kindForFormat(String f) => isVideoFormat(f) ? 'video' : 'audio';

    try {
      final ok = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (ctx2, setState) {
              return AlertDialog(
                title: const Text('Descargar desde URL'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: urlCtrl,
                        keyboardType: TextInputType.url,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'URL',
                          hintText: 'https://www.youtube.com/watch?v=...',
                          prefixIcon: Icon(Icons.link_rounded),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: idCtrl,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          labelText: 'Media ID (opcional)',
                          helperText:
                              'Si lo dejas vacío, el backend genera/usa uno.',
                          prefixIcon: Icon(Icons.tag_rounded),
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: format,
                        items: const [
                          DropdownMenuItem(
                            value: 'mp3',
                            child: Text('MP3 (audio)'),
                          ),
                          DropdownMenuItem(
                            value: 'm4a',
                            child: Text('M4A (audio)'),
                          ),
                          DropdownMenuItem(
                            value: 'mp4',
                            child: Text('MP4 (video)'),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => format = v);
                        },
                        decoration: const InputDecoration(
                          labelText: 'Formato',
                          prefixIcon: Icon(Icons.file_present_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Tipo detectado: ${kindForFormat(format)}',
                          style: Theme.of(ctx2).textTheme.bodySmall?.copyWith(
                            color: Theme.of(ctx2).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx2).pop(false),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton(
                    onPressed: () {
                      final url = urlCtrl.text.trim();
                      if (url.isEmpty) {
                        ScaffoldMessenger.of(ctx2).showSnackBar(
                          const SnackBar(
                            content: Text('Por favor ingresa una URL'),
                          ),
                        );
                        return;
                      }
                      Navigator.of(ctx2).pop(true);
                    },
                    child: const Text('Descargar'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (ok == true) {
        final url = urlCtrl.text.trim();
        final mid = idCtrl.text.trim();

        await controller.downloadFromUrl(
          mediaId: mid.isEmpty ? null : mid,
          url: url,
          format: format,
        );
      }
    } finally {
      urlCtrl.dispose();
      idCtrl.dispose();
    }
  }

  // ============================
  // 🧩 CONFIRM: ELIMINAR
  // ============================
  Future<void> _confirmDelete(BuildContext context, MediaItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar'),
        content: const Text('¿Eliminar este archivo descargado?'),
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

    if (ok == true) controller.delete(item);
  }

  Widget _bottomNav({
    required Color barBg,
    required ColorScheme scheme,
    required bool isDark,
    required HomeController home,
  }) {
    return Positioned(
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
            currentIndex: 3,
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
                case 5:
                  home.goToSettings();
                  break;
              }
            },
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Tile
// ============================================================================

class _DownloadTile extends StatelessWidget {
  final MediaItem item;
  final void Function(MediaItem item) onPlay;
  final void Function(MediaItem item) onDelete;

  const _DownloadTile({
    required this.item,
    required this.onPlay,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final v = item.variants.isNotEmpty ? item.variants.first : null;

    final isVideo = v?.kind == MediaVariantKind.video;
    final icon = isVideo ? Icons.videocam_rounded : Icons.music_note_rounded;

    final subtitle = item.subtitle.isNotEmpty
        ? item.subtitle
        : (v?.localPath ?? v?.fileName ?? '');

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: Icon(icon),
        title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Wrap(
          spacing: 4,
          children: [
            IconButton(
              icon: const Icon(Icons.play_arrow_rounded),
              tooltip: 'Reproducir',
              onPressed: () => onPlay(item),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: 'Eliminar descarga',
              onPressed: () => onDelete(item),
            ),
          ],
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

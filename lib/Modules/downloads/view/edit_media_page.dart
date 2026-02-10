import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:get/get.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../app/models/media_item.dart';
import '../../sources/domain/source_origin.dart';
import '../controller/downloads_controller.dart';
import '../../../app/data/local/local_library_store.dart';
import '../../../app/data/repo/media_repository.dart';
import 'package:flutter_listenfy/Modules/home/controller/home_controller.dart';
import '../../../app/ui/widgets/layout/app_gradient_background.dart';
import '../../../app/controllers/navigation_controller.dart';
import '../../../app/utils/format_bytes.dart';
import '../../../app/ui/widgets/dialogs/image_search_dialog.dart';
import 'package:flutter_listenfy/Modules/artists/controller/artists_controller.dart';
import 'package:flutter_listenfy/Modules/playlists/controller/playlists_controller.dart';
import 'package:flutter_listenfy/Modules/sources/controller/sources_controller.dart';

class EditMediaMetadataPage extends StatefulWidget {
  const EditMediaMetadataPage({super.key, required this.item});

  final MediaItem item;

  @override
  State<EditMediaMetadataPage> createState() => _EditMediaMetadataPageState();
}

class _EditMediaMetadataPageState extends State<EditMediaMetadataPage> {
  // ============================
  // 🧭 ESTADO
  // ============================
  final LocalLibraryStore _store = Get.find<LocalLibraryStore>();
  final MediaRepository _repo = Get.find<MediaRepository>();

  late final TextEditingController _titleCtrl;
  late final TextEditingController _artistCtrl;
  late final TextEditingController _thumbCtrl;
  late final TextEditingController _durationCtrl;
  String? _localThumbPath;

  // ============================
  // 🔁 LIFECYCLE
  // ============================
  @override
  void initState() {
    super.initState();
    if (Get.isRegistered<NavigationController>()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Get.find<NavigationController>().setEditing(true);
      });
    }
    _titleCtrl = TextEditingController(text: widget.item.title);
    _artistCtrl = TextEditingController(text: widget.item.subtitle);
    _thumbCtrl = TextEditingController(text: widget.item.thumbnail ?? '');
    _durationCtrl = TextEditingController(
      text: widget.item.durationSeconds?.toString() ?? '',
    );
    _localThumbPath = widget.item.thumbnailLocalPath;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _artistCtrl.dispose();
    _thumbCtrl.dispose();
    _durationCtrl.dispose();
    if (Get.isRegistered<NavigationController>()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Get.find<NavigationController>().setEditing(false);
      });
    }
    super.dispose();
  }

  // ============================
  // 💾 ACCIONES
  // ============================
  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      Get.snackbar(
        'Metadata',
        'El titulo no puede estar vacio',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final rawDuration = _durationCtrl.text.trim();
    int? durationSeconds;
    if (rawDuration.isNotEmpty) {
      final parsed = int.tryParse(rawDuration);
      if (parsed == null || parsed < 0) {
        Get.snackbar(
          'Metadata',
          'La duracion debe ser un numero valido',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }
      durationSeconds = parsed;
    }

    // ----------------------------
    // 🖼️ THUMBNAIL (persistente offline)
    // ----------------------------
    final remoteThumb = _thumbCtrl.text.trim();
    final pickedLocalThumb = _localThumbPath?.trim() ?? '';
    final hasLocal = pickedLocalThumb.isNotEmpty;

    // Si hay URL, la cacheamos a un archivo local antes de guardar
    String? cachedLocalFromRemote;
    if (!hasLocal && remoteThumb.isNotEmpty) {
      try {
        cachedLocalFromRemote = await _repo.cacheThumbnailForItem(
          itemId: widget.item.id,
          thumbnailUrl: remoteThumb,
        );
      } catch (_) {
        cachedLocalFromRemote = null;
      }
    }

    // Local efectivo:
    // - Si hay remote y cache funcionó -> usa cache
    // - Si hay remote pero cache falló -> queda vacío (y dependerá de internet)
    // - Si no hay remote -> usa el local escogido por file picker
    final effectiveLocal = hasLocal
        ? pickedLocalThumb
        : remoteThumb.isNotEmpty
        ? ((cachedLocalFromRemote?.trim().isNotEmpty == true)
              ? cachedLocalFromRemote!.trim()
              : '')
        : pickedLocalThumb;

    final initialRemote = widget.item.thumbnail?.trim() ?? '';
    final initialLocal = widget.item.thumbnailLocalPath?.trim() ?? '';

    final thumbChanged =
        remoteThumb != initialRemote || effectiveLocal != initialLocal;

    final updated = widget.item.copyWith(
      title: title,
      subtitle: _artistCtrl.text.trim(),

      // Si no cambió, null para no re-escribir
      // Si cambió:
      // - con local -> limpia remote
      // - con remote -> guarda remote
      // - sin nada -> guarda ''
      thumbnail: !thumbChanged
          ? null
          : (hasLocal ? '' : (remoteThumb.isNotEmpty ? remoteThumb : '')),

      // Si no cambió, null
      // Si cambió:
      // - con local efectivo -> guarda path
      // - sin local -> guarda ''
      thumbnailLocalPath: !thumbChanged
          ? null
          : (effectiveLocal.isNotEmpty ? effectiveLocal : ''),

      durationSeconds: durationSeconds ?? widget.item.durationSeconds,
    );

    await _store.upsert(updated);

    if (Get.isRegistered<DownloadsController>()) {
      await Get.find<DownloadsController>().load();
    }
    if (Get.isRegistered<HomeController>()) {
      await Get.find<HomeController>().loadHome();
    }
    if (Get.isRegistered<ArtistsController>()) {
      await Get.find<ArtistsController>().load();
    }
    if (Get.isRegistered<PlaylistsController>()) {
      await Get.find<PlaylistsController>().load();
    }
    if (Get.isRegistered<SourcesController>()) {
      await Get.find<SourcesController>().refreshAll();
    }

    if (mounted) {
      Get.back(result: true);
    }
  }

  // ============================
  // 🧩 HELPERS
  // ============================
  Widget _buildThumbnail(BuildContext context) {
    final theme = Theme.of(context);
    final local = _localThumbPath?.trim();
    final remote = _thumbCtrl.text.trim();
    final thumb = (local != null && local.isNotEmpty)
        ? local
        : (remote.isNotEmpty ? remote : widget.item.effectiveThumbnail);

    if (thumb != null && thumb.startsWith('http')) {
      return Image.network(
        thumb,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallbackThumb(theme),
      );
    }

    if (thumb != null && thumb.isNotEmpty) {
      return Image.file(
        File(thumb),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallbackThumb(theme),
      );
    }

    return _fallbackThumb(theme);
  }

  Widget _fallbackThumb(ThemeData theme) {
    final isVideo = widget.item.hasVideoLocal;
    return Center(
      child: Icon(
        isVideo ? Icons.videocam_rounded : Icons.music_note_rounded,
        size: 44,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  String? _audioFormat() {
    final local = widget.item.localAudioVariant?.format.trim();
    if (local != null && local.isNotEmpty) return local;
    final any = widget.item.variants
        .where((v) => v.kind == MediaVariantKind.audio)
        .map((v) => v.format.trim())
        .firstWhere((f) => f.isNotEmpty, orElse: () => '');
    return any.isNotEmpty ? any : null;
  }

  int? _resolveSizeBytes() {
    final local =
        widget.item.localAudioVariant ?? widget.item.localVideoVariant;
    if (local?.size != null && local!.size! > 0) return local.size;

    for (final v in widget.item.variants) {
      if (v.size != null && v.size! > 0) return v.size;
    }

    return null;
  }

  Future<void> _pickLocalThumbnail() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
    );

    final file = (res != null && res.files.isNotEmpty) ? res.files.first : null;
    final path = file?.path;
    if (path == null || path.trim().isEmpty) return;

    final prevLocal = _localThumbPath;
    final cropped = await _cropToSquare(path);
    if (cropped == null || cropped.trim().isEmpty) return;

    final persisted = await _persistCroppedThumb(cropped);
    if (!mounted || persisted == null || persisted.trim().isEmpty) return;

    setState(() {
      _localThumbPath = persisted;
      _thumbCtrl.text = '';
    });

    if (prevLocal != null &&
        prevLocal.trim().isNotEmpty &&
        prevLocal.trim() != persisted.trim()) {
      try {
        final f = File(prevLocal.trim());
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
  }

  Future<void> _searchWebThumbnail() async {
    final rawQuery = _titleCtrl.text.trim();
    final query = rawQuery.isEmpty ? 'album cover' : rawQuery;

    final pickedUrl = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (_) => ImageSearchDialog(initialQuery: query),
    );

    final cleaned = (pickedUrl ?? '').trim();
    if (!mounted || cleaned.isEmpty) return;

    final prevLocal = _localThumbPath;
    // 1) cachea remoto a archivo local base
    String? baseLocal;
    try {
      baseLocal = await _repo.cacheThumbnailForItem(
        itemId: '${widget.item.id}-raw',
        thumbnailUrl: cleaned,
      );
    } catch (_) {
      baseLocal = null;
    }
    if (!mounted || baseLocal == null || baseLocal.trim().isEmpty) return;

    // 2) recorta 1:1
    final cropped = await _cropToSquare(baseLocal);
    if (!mounted || cropped == null || cropped.trim().isEmpty) {
      try {
        await File(baseLocal).delete();
      } catch (_) {}
      return;
    }

    // 3) persiste y limpia URL (solo local)
    final persisted = await _persistCroppedThumb(cropped);
    if (!mounted || persisted == null || persisted.trim().isEmpty) return;

    setState(() {
      _thumbCtrl.text = '';
      _localThumbPath = persisted;
    });

    if (baseLocal != persisted) {
      try {
        await File(baseLocal).delete();
      } catch (_) {}
    }

    if (prevLocal != null &&
        prevLocal.trim().isNotEmpty &&
        prevLocal.trim() != persisted.trim()) {
      try {
        final f = File(prevLocal.trim());
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
  }

  void _clearThumbnail() {
    setState(() {
      _localThumbPath = null;
      _thumbCtrl.text = '';
    });
  }

  Future<void> _deleteCurrentThumbnail() async {
    final paths = <String>{
      if (_localThumbPath != null) _localThumbPath!.trim(),
      if (widget.item.thumbnailLocalPath != null)
        widget.item.thumbnailLocalPath!.trim(),
    }..removeWhere((e) => e.isEmpty);

    for (final pth in paths) {
      try {
        final f = File(pth);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _localThumbPath = null;
      _thumbCtrl.text = '';
    });
  }

  // ============================
  // 🎨 UI
  // ============================
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Editar metadatos'),
        backgroundColor: theme.colorScheme.surface,
        surfaceTintColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: FilledButton(
            onPressed: _save,
            child: const Text('Guardar cambios'),
          ),
        ),
      ),
      body: AppGradientBackground(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainer,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 88,
                        height: 88,
                        child: _buildThumbnail(context),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            widget.item.displaySubtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Origen: ${widget.item.origin.key}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          if (_audioFormat() != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Formato: ${_audioFormat()!.toUpperCase()}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                          if (_resolveSizeBytes() != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Peso: ${formatBytes(_resolveSizeBytes()!)}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Informacion basica',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainer,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      controller: _titleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Titulo',
                        prefixIcon: Icon(Icons.music_note_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _artistCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Artista',
                        prefixIcon: Icon(Icons.person_rounded),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Extras',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainer,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.tonalIcon(
                            onPressed: _pickLocalThumbnail,
                            icon: const Icon(Icons.photo_library_rounded),
                            label: const Text('Elegir imagen'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.tonalIcon(
                            onPressed: _searchWebThumbnail,
                            icon: const Icon(Icons.public_rounded),
                            label: const Text('Buscar en web'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _thumbCtrl,
                            readOnly: true,
                            onTap: _searchWebThumbnail,
                            decoration: const InputDecoration(
                              labelText: 'Imagen web seleccionada',
                              prefixIcon: Icon(Icons.image_rounded),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton(
                          onPressed: _clearThumbnail,
                          child: const Text('Limpiar'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _deleteCurrentThumbnail,
                        icon: const Icon(Icons.delete_outline_rounded),
                        label: const Text('Borrar portada actual'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _durationCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Duracion en segundos (opcional)',
                        prefixIcon: Icon(Icons.timer_rounded),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Fuente: ${widget.item.source.name}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================
  // ✂️ CROP HELPERS
  // ============================
  Future<String?> _cropToSquare(String sourcePath) async {
    try {
      final cropped = await ImageCropper().cropImage(
        sourcePath: sourcePath,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 92,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Recortar',
            lockAspectRatio: true,
            hideBottomControls: true,
          ),
          IOSUiSettings(
            title: 'Recortar',
            aspectRatioLockEnabled: true,
          ),
        ],
      );
      return cropped?.path;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _persistCroppedThumb(String croppedPath) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final coversDir = Directory(p.join(appDir.path, 'downloads', 'covers'));
      if (!await coversDir.exists()) {
        await coversDir.create(recursive: true);
      }

      final targetPath = p.join(coversDir.path, '${widget.item.id}-crop.jpg');
      final src = File(croppedPath);
      if (!await src.exists()) return null;

      final out = await src.copy(targetPath);

      if (croppedPath != targetPath) {
        try {
          await src.delete();
        } catch (_) {}
      }

      return out.path;
    } catch (_) {
      return null;
    }
  }
}

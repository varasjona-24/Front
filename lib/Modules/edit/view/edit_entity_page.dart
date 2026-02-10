import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/models/media_item.dart';
import '../../../app/ui/widgets/layout/app_gradient_background.dart';
import '../../../app/controllers/navigation_controller.dart';
import '../../artists/controller/artists_controller.dart';
import '../../playlists/domain/playlist.dart';
import '../../sources/domain/source_theme_topic.dart';
import '../../sources/domain/source_theme_topic_playlist.dart';
import '../../sources/ui/source_color_picker_field.dart';
import '../controller/edit_entity_controller.dart';
import '../../../app/ui/widgets/dialogs/image_search_dialog.dart';

class EditEntityPage extends StatefulWidget {
  const EditEntityPage({super.key});

  @override
  State<EditEntityPage> createState() => _EditEntityPageState();
}

class _EditEntityPageState extends State<EditEntityPage> {
  final EditEntityController _controller = Get.find<EditEntityController>();

  late final EditEntityArgs _args;
  late final TextEditingController _titleCtrl;
  late final TextEditingController _subtitleCtrl;
  late final TextEditingController _durationCtrl;
  late final TextEditingController _thumbCtrl;

  String? _localThumbPath;
  String? _remoteThumbUrl;
  bool _thumbTouched = false;
  bool _thumbCleared = false;
  int? _colorValue;

  MediaItem? get _media => _args.media;
  ArtistGroup? get _artist => _args.artist;
  Playlist? get _playlist => _args.playlist;
  SourceThemeTopic? get _topic => _args.topic;
  SourceThemeTopicPlaylist? get _topicPlaylist => _args.topicPlaylist;

  @override
  void initState() {
    super.initState();

    _args = Get.arguments as EditEntityArgs;

    if (Get.isRegistered<NavigationController>()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Get.find<NavigationController>().setEditing(true);
      });
    }

    if (_args.type == EditEntityType.media) {
      final item = _media!;
      _titleCtrl = TextEditingController(text: item.title);
      _subtitleCtrl = TextEditingController(text: item.subtitle);
      _durationCtrl = TextEditingController(
        text: item.durationSeconds?.toString() ?? '',
      );
      _thumbCtrl = TextEditingController(text: item.thumbnail ?? '');
      _localThumbPath = item.thumbnailLocalPath;
      _remoteThumbUrl = item.thumbnail;
      _colorValue = null;
    } else if (_args.type == EditEntityType.artist) {
      final artist = _artist!;
      _titleCtrl = TextEditingController(text: artist.name);
      _subtitleCtrl = TextEditingController(text: '');
      _durationCtrl = TextEditingController(text: '');
      _thumbCtrl = TextEditingController(text: artist.thumbnail ?? '');
      _localThumbPath = artist.thumbnailLocalPath;
      _remoteThumbUrl = artist.thumbnail;
      _colorValue = null;
    } else {
      if (_args.type == EditEntityType.playlist) {
        final playlist = _playlist!;
        _titleCtrl = TextEditingController(text: playlist.name);
        _subtitleCtrl = TextEditingController(text: '');
        _durationCtrl = TextEditingController(text: '');
        _thumbCtrl = TextEditingController(text: playlist.coverUrl ?? '');
        _localThumbPath = playlist.coverLocalPath;
        _remoteThumbUrl = playlist.coverUrl;
        _thumbCleared = playlist.coverCleared;
        _colorValue = null;
      } else if (_args.type == EditEntityType.topic) {
        final topic = _topic!;
        _titleCtrl = TextEditingController(text: topic.title);
        _subtitleCtrl = TextEditingController(text: '');
        _durationCtrl = TextEditingController(text: '');
        _thumbCtrl = TextEditingController(text: topic.coverUrl ?? '');
        _localThumbPath = topic.coverLocalPath;
        _remoteThumbUrl = topic.coverUrl;
        _colorValue = topic.colorValue;
      } else {
        final pl = _topicPlaylist!;
        _titleCtrl = TextEditingController(text: pl.name);
        _subtitleCtrl = TextEditingController(text: '');
        _durationCtrl = TextEditingController(text: '');
        _thumbCtrl = TextEditingController(text: pl.coverUrl ?? '');
        _localThumbPath = pl.coverLocalPath;
        _remoteThumbUrl = pl.coverUrl;
        _colorValue = pl.colorValue;
      }
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _subtitleCtrl.dispose();
    _durationCtrl.dispose();
    _thumbCtrl.dispose();
    if (Get.isRegistered<NavigationController>()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Get.find<NavigationController>().setEditing(false);
      });
    }
    super.dispose();
  }

  String _entityId() {
    if (_args.type == EditEntityType.media) return _media!.id;
    if (_args.type == EditEntityType.artist) return _artist!.key;
    if (_args.type == EditEntityType.playlist) return _playlist!.id;
    if (_args.type == EditEntityType.topic) return _topic!.id;
    return _topicPlaylist!.id;
  }

  String _entityTitle() {
    if (_args.type == EditEntityType.media) return 'Editar metadatos';
    if (_args.type == EditEntityType.artist) return 'Editar artista';
    if (_args.type == EditEntityType.playlist) return 'Editar playlist';
    if (_args.type == EditEntityType.topic) return 'Editar temática';
    return 'Editar lista';
  }

  bool get _isMedia => _args.type == EditEntityType.media;
  bool get _isTopic => _args.type == EditEntityType.topic;
  bool get _isTopicPlaylist => _args.type == EditEntityType.topicPlaylist;

  Future<void> _pickLocalThumbnail() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
    );

    final file = (res != null && res.files.isNotEmpty) ? res.files.first : null;
    final path = file?.path;
    if (path == null || path.trim().isEmpty) return;

    final prevLocal = _localThumbPath;
    final cropped = await _controller.cropToSquare(path);
    if (cropped == null || cropped.trim().isEmpty) return;

    final persisted = await _controller.persistCroppedImage(
      id: _entityId(),
      croppedPath: cropped,
    );
    if (!mounted || persisted == null || persisted.trim().isEmpty) return;

    setState(() {
      _localThumbPath = persisted;
      _remoteThumbUrl = '';
      _thumbCtrl.text = '';
      _thumbTouched = true;
      _thumbCleared = false;
    });
    _evictFileImage(persisted);

    if (prevLocal != null &&
        prevLocal.trim().isNotEmpty &&
        prevLocal.trim() != persisted.trim()) {
      _evictFileImage(prevLocal.trim());
      await _controller.deleteFile(prevLocal);
    }
  }

  Future<void> _searchWebThumbnail() async {
    final rawQuery = _titleCtrl.text.trim();
    final fallback = _args.type == EditEntityType.artist
        ? 'artist photo'
        : 'album cover';
    final query = rawQuery.isEmpty ? fallback : rawQuery;

    final pickedUrl = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (_) => ImageSearchDialog(initialQuery: query),
    );

    final cleaned = (pickedUrl ?? '').trim();
    if (!mounted || cleaned.isEmpty) return;

    final prevLocal = _localThumbPath;

    String? baseLocal;
    try {
      baseLocal = await _controller.cacheRemoteToLocal(
        id: '${_entityId()}-raw',
        url: cleaned,
      );
    } catch (_) {
      baseLocal = null;
    }
    if (!mounted || baseLocal == null || baseLocal.trim().isEmpty) return;

    final cropped = await _controller.cropToSquare(baseLocal);
    if (!mounted || cropped == null || cropped.trim().isEmpty) {
      await _controller.deleteFile(baseLocal);
      return;
    }

    final persisted = await _controller.persistCroppedImage(
      id: _entityId(),
      croppedPath: cropped,
    );
    if (!mounted || persisted == null || persisted.trim().isEmpty) return;

    if (baseLocal != persisted) {
      await _controller.deleteFile(baseLocal);
    }

    setState(() {
      _thumbCtrl.text = '';
      _localThumbPath = persisted;
      _remoteThumbUrl = '';
      _thumbTouched = true;
      _thumbCleared = false;
    });
    _evictFileImage(persisted);

    if (prevLocal != null &&
        prevLocal.trim().isNotEmpty &&
        prevLocal.trim() != persisted.trim()) {
      _evictFileImage(prevLocal.trim());
      await _controller.deleteFile(prevLocal);
    }
  }

  void _clearThumbnail() {
    setState(() {
      _localThumbPath = null;
      _remoteThumbUrl = '';
      _thumbCtrl.text = '';
      _thumbTouched = true;
      _thumbCleared = true;
    });
  }

  Future<void> _deleteCurrentThumbnail() async {
    final paths = <String>{
      if (_localThumbPath != null) _localThumbPath!.trim(),
    }..removeWhere((e) => e.isEmpty);

    for (final pth in paths) {
      _evictFileImage(pth);
      await _controller.deleteFile(pth);
    }

    if (!mounted) return;
    setState(() {
      _localThumbPath = null;
      _remoteThumbUrl = '';
      _thumbCtrl.text = '';
      _thumbTouched = true;
      _thumbCleared = true;
    });
  }

  Future<void> _save() async {
    final ok = _args.type == EditEntityType.media
        ? await _controller.saveMedia(
            item: _media!,
            title: _titleCtrl.text,
            subtitle: _subtitleCtrl.text,
            durationText: _durationCtrl.text,
            thumbTouched: _thumbTouched,
            localThumbPath: _localThumbPath,
          )
        : (_args.type == EditEntityType.artist
            ? await _controller.saveArtist(
                artist: _artist!,
                name: _titleCtrl.text,
                thumbTouched: _thumbTouched,
                localThumbPath: _localThumbPath,
              )
            : (_args.type == EditEntityType.playlist
                ? await _controller.savePlaylist(
                    playlist: _playlist!,
                    name: _titleCtrl.text,
                    thumbTouched: _thumbTouched,
                    localThumbPath: _localThumbPath,
                  )
                : (_args.type == EditEntityType.topic
                    ? await _controller.saveTopic(
                        topic: _topic!,
                        name: _titleCtrl.text,
                        thumbTouched: _thumbTouched,
                        localThumbPath: _localThumbPath,
                        colorValue: _colorValue,
                      )
                    : await _controller.saveTopicPlaylist(
                        playlist: _topicPlaylist!,
                        name: _titleCtrl.text,
                        thumbTouched: _thumbTouched,
                        localThumbPath: _localThumbPath,
                        colorValue: _colorValue,
                      ))));

    if (ok && mounted) {
      Get.back(result: true);
    }
  }

  Widget _buildThumbnail(BuildContext context) {
    final theme = Theme.of(context);
    final local = _localThumbPath?.trim();
    final remote = _remoteThumbUrl?.trim() ?? '';
    final thumb = (local != null && local.isNotEmpty)
        ? local
        : (remote.isNotEmpty && !_thumbCleared ? remote : null);

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
    final isVideo = _media?.hasVideoLocal ?? false;
    return Center(
      child: Icon(
        isVideo ? Icons.videocam_rounded : Icons.music_note_rounded,
        size: 44,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  void _evictFileImage(String path) {
    try {
      final file = File(path);
      if (!file.existsSync()) return;
      FileImage(file).evict();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(_entityTitle()),
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
                            _titleCtrl.text.isEmpty
                                ? (_args.type == EditEntityType.playlist
                                    ? 'Sin titulo'
                                    : 'Sin nombre')
                                : _titleCtrl.text,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (_isMedia) ...[
                            const SizedBox(height: 6),
                            Text(
                              _subtitleCtrl.text.isEmpty
                                  ? _media!.displaySubtitle
                                  : _subtitleCtrl.text,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
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
                      decoration: InputDecoration(
                        labelText:
                            _args.type == EditEntityType.media ? 'Titulo' : 'Nombre',
                        prefixIcon: Icon(
                          _args.type == EditEntityType.media
                              ? Icons.music_note_rounded
                              : (_args.type == EditEntityType.artist
                                    ? Icons.person_rounded
                                    : Icons.folder_rounded),
                        ),
                      ),
                    ),
                    if (_isMedia) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _subtitleCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Artista',
                          prefixIcon: Icon(Icons.person_rounded),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              (_isTopic || _isTopicPlaylist) ? 'Portada y color' : 'Portada',
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
                    if (_isTopic || _isTopicPlaylist) ...[
                      const SizedBox(height: 12),
                      SourceColorPickerField(
                        color: _colorValue != null
                            ? Color(_colorValue!)
                            : theme.colorScheme.primary,
                        onChanged: (c) => setState(() {
                          _colorValue = c.value;
                        }),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (_isMedia) ...[
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
                  child: TextField(
                    controller: _durationCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Duracion en segundos (opcional)',
                      prefixIcon: Icon(Icons.timer_rounded),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

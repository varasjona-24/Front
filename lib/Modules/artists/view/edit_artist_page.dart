import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/data/repo/media_repository.dart';
import '../controller/artists_controller.dart';
import 'widgets/artist_avatar.dart';
import '../../../app/ui/widgets/layout/app_gradient_background.dart';
import '../../../app/controllers/navigation_controller.dart';
import '../../../app/ui/widgets/dialogs/image_search_dialog.dart';

class EditArtistPage extends StatefulWidget {
  const EditArtistPage({super.key, required this.artist});

  final ArtistGroup artist;

  @override
  State<EditArtistPage> createState() => _EditArtistPageState();
}

class _EditArtistPageState extends State<EditArtistPage> {
  final ArtistsController _controller = Get.find<ArtistsController>();
  final MediaRepository _repo = Get.find<MediaRepository>();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _thumbCtrl;
  String? _localThumbPath;

  @override
  void initState() {
    super.initState();
    if (Get.isRegistered<NavigationController>()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Get.find<NavigationController>().setEditing(true);
      });
    }
    _nameCtrl = TextEditingController(text: widget.artist.name);
    _thumbCtrl = TextEditingController(text: widget.artist.thumbnail ?? '');
    _localThumbPath = widget.artist.thumbnailLocalPath;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _thumbCtrl.dispose();
    if (Get.isRegistered<NavigationController>()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Get.find<NavigationController>().setEditing(false);
      });
    }
    super.dispose();
  }

  Future<void> _pickLocalThumbnail() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
    );

    final file = (res != null && res.files.isNotEmpty) ? res.files.first : null;
    final path = file?.path;
    if (path == null || path.trim().isEmpty) return;

    setState(() {
      _localThumbPath = path; // preview local
      _thumbCtrl.text = ''; // limpia remoto
    });
  }

  void _clearThumbnail() {
    setState(() {
      _localThumbPath = null;
      _thumbCtrl.text = '';
    });
  }

  Future<void> _searchWebThumbnail() async {
    final rawQuery = _nameCtrl.text.trim();
    final query = rawQuery.isEmpty ? 'artist photo' : rawQuery;

    final pickedUrl = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (_) => ImageSearchDialog(initialQuery: query),
    );

    final cleaned = (pickedUrl ?? '').trim();
    if (!mounted || cleaned.isEmpty) return;

    // Preview inmediato (solo URL; no cache aquí)
    setState(() {
      _thumbCtrl.text = cleaned; // preview remoto
      _localThumbPath = null; // limpia local
    });
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      Get.snackbar(
        'Artista',
        'El nombre no puede estar vacio',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final remote = _thumbCtrl.text.trim();
    final useRemote = remote.isNotEmpty;

    // Si eligieron remoto, cachea aquí (persistencia real)
    String? cached;
    if (useRemote) {
      cached = await _repo.cacheThumbnailForItem(
        itemId: widget.artist.key,
        thumbnailUrl: remote,
      );
    }

    await _controller.updateArtist(
      key: widget.artist.key,
      newName: name,
      thumbnail: useRemote ? remote : null,
      thumbnailLocalPath: useRemote
          ? (cached ?? _localThumbPath)
          : _localThumbPath,
    );

    if (mounted) Get.back(result: true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final remote = _thumbCtrl.text.trim();
    final thumb = _localThumbPath ?? (remote.isNotEmpty ? remote : null);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Editar artista'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
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
                    ArtistAvatar(thumb: thumb, radius: 32),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        widget.artist.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
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
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nombre del artista',
                        prefixIcon: Icon(Icons.person_rounded),
                      ),
                    ),
                    const SizedBox(height: 16),
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
                        FilledButton.tonalIcon(
                          onPressed: _searchWebThumbnail,
                          icon: const Icon(Icons.public_rounded),
                          label: const Text('Buscar'),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton(
                          onPressed: _clearThumbnail,
                          child: const Text('Limpiar'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _thumbCtrl,
                      readOnly: true,
                      onTap: _searchWebThumbnail,
                      decoration: const InputDecoration(
                        labelText: 'Imagen web seleccionada',
                        prefixIcon: Icon(Icons.image_rounded),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

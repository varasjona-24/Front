import 'dart:io';

import 'package:get/get.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../app/data/local/local_library_store.dart';
import '../../../app/data/repo/media_repository.dart';
import '../../../app/models/media_item.dart';
import '../../artists/controller/artists_controller.dart';
import '../../downloads/controller/downloads_controller.dart';
import '../../home/controller/home_controller.dart';
import '../../playlists/controller/playlists_controller.dart';
import '../../playlists/domain/playlist.dart';
import '../../sources/controller/sources_controller.dart';
import '../../sources/domain/source_theme_topic.dart';

enum EditEntityType { media, artist, playlist, topic }

class EditEntityArgs {
  final EditEntityType type;
  final MediaItem? media;
  final ArtistGroup? artist;
  final Playlist? playlist;
  final SourceThemeTopic? topic;

  const EditEntityArgs.media(this.media)
      : type = EditEntityType.media,
        artist = null,
        playlist = null,
        topic = null;

  const EditEntityArgs.artist(this.artist)
      : type = EditEntityType.artist,
        media = null,
        playlist = null,
        topic = null;

  const EditEntityArgs.playlist(this.playlist)
      : type = EditEntityType.playlist,
        media = null,
        artist = null,
        topic = null;

  const EditEntityArgs.topic(this.topic)
      : type = EditEntityType.topic,
        media = null,
        artist = null,
        playlist = null;
}

class EditEntityController extends GetxController {
  final MediaRepository _repo = Get.find<MediaRepository>();
  final LocalLibraryStore _store = Get.find<LocalLibraryStore>();
  final ArtistsController _artists = Get.find<ArtistsController>();
  final PlaylistsController _playlists = Get.find<PlaylistsController>();
  final SourcesController _sources = Get.find<SourcesController>();

  Future<String?> cacheRemoteToLocal({
    required String id,
    required String url,
  }) async {
    return _repo.cacheThumbnailForItem(itemId: id, thumbnailUrl: url.trim());
  }

  Future<String?> cropToSquare(String sourcePath) async {
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

  Future<String?> persistCroppedImage({
    required String id,
    required String croppedPath,
  }) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final coversDir = Directory(p.join(appDir.path, 'downloads', 'covers'));
      if (!await coversDir.exists()) {
        await coversDir.create(recursive: true);
      }

      final ts = DateTime.now().millisecondsSinceEpoch;
      final targetPath = p.join(coversDir.path, '$id-crop-$ts.jpg');
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

  Future<void> deleteFile(String? path) async {
    final pth = path?.trim();
    if (pth == null || pth.isEmpty) return;
    try {
      final f = File(pth);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  Future<bool> saveMedia({
    required MediaItem item,
    required String title,
    required String subtitle,
    required String durationText,
    required bool thumbTouched,
    required String? localThumbPath,
  }) async {
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) {
      Get.snackbar(
        'Metadata',
        'El titulo no puede estar vacio',
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }

    final rawDuration = durationText.trim();
    int? durationSeconds;
    if (rawDuration.isNotEmpty) {
      final parsed = int.tryParse(rawDuration);
      if (parsed == null || parsed < 0) {
        Get.snackbar(
          'Metadata',
          'La duracion debe ser un numero valido',
          snackPosition: SnackPosition.BOTTOM,
        );
        return false;
      }
      durationSeconds = parsed;
    }

    String? thumbRemoteUpdate;
    String? thumbLocalUpdate;
    if (thumbTouched) {
      final local = localThumbPath?.trim() ?? '';
      if (local.isNotEmpty) {
        thumbRemoteUpdate = '';
        thumbLocalUpdate = local;
      } else {
        thumbRemoteUpdate = '';
        thumbLocalUpdate = '';
      }
    }

    final updated = item.copyWith(
      title: trimmedTitle,
      subtitle: subtitle.trim(),
      thumbnail: thumbRemoteUpdate,
      thumbnailLocalPath: thumbLocalUpdate,
      durationSeconds: durationSeconds ?? item.durationSeconds,
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

    return true;
  }

  Future<bool> saveArtist({
    required ArtistGroup artist,
    required String name,
    required bool thumbTouched,
    required String? localThumbPath,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      Get.snackbar(
        'Artista',
        'El nombre no puede estar vacio',
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }

    String? nextThumb = artist.thumbnail;
    String? nextLocal = artist.thumbnailLocalPath;

    if (thumbTouched) {
      final local = localThumbPath?.trim() ?? '';
      if (local.isNotEmpty) {
        nextThumb = '';
        nextLocal = local;
      } else {
        nextThumb = '';
        nextLocal = '';
      }
    }

    await _artists.updateArtist(
      key: artist.key,
      newName: trimmed,
      thumbnail: nextThumb,
      thumbnailLocalPath: nextLocal,
    );

    return true;
  }

  Future<bool> savePlaylist({
    required Playlist playlist,
    required String name,
    required bool thumbTouched,
    required String? localThumbPath,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      Get.snackbar(
        'Playlist',
        'El nombre no puede estar vacio',
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }

    if (trimmed != playlist.name) {
      await _playlists.renamePlaylist(playlist.id, trimmed);
    }

    if (thumbTouched) {
      final local = localThumbPath?.trim() ?? '';
      final cleared = local.isEmpty;
      await _playlists.updateCover(
        playlist.id,
        coverUrl: null,
        coverLocalPath: local.isNotEmpty ? local : null,
        coverCleared: cleared,
      );
    }

    return true;
  }

  Future<bool> saveTopic({
    required SourceThemeTopic topic,
    required String name,
    required bool thumbTouched,
    required String? localThumbPath,
    required int? colorValue,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      Get.snackbar(
        'Tematica',
        'El nombre no puede estar vacio',
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }

    String? coverUrl = topic.coverUrl;
    String? coverLocal = topic.coverLocalPath;
    if (thumbTouched) {
      final local = localThumbPath?.trim() ?? '';
      coverUrl = null;
      coverLocal = local.isNotEmpty ? local : null;
    }

    await _sources.updateTopic(
      topic.copyWith(
        title: trimmed,
        coverUrl: coverUrl?.trim().isEmpty == true ? null : coverUrl,
        coverLocalPath: coverLocal?.trim().isEmpty == true ? null : coverLocal,
        colorValue: colorValue,
      ),
    );

    return true;
  }
}

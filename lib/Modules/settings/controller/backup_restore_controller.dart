import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';

import '../../../app/data/local/local_library_store.dart';
import '../../../app/models/media_item.dart';
import '../../../Modules/playlists/data/playlist_store.dart';
import '../../../Modules/artists/data/artist_store.dart';
import '../../../Modules/sources/data/source_theme_pill_store.dart';
import '../../../Modules/sources/data/source_theme_topic_store.dart';
import '../../../Modules/sources/data/source_theme_topic_playlist_store.dart';
import '../../../Modules/playlists/controller/playlists_controller.dart';
import '../../../Modules/artists/controller/artists_controller.dart';
import '../../../Modules/sources/controller/sources_controller.dart';
import '../../../Modules/playlists/domain/playlist.dart';
import '../../../Modules/artists/domain/artist_profile.dart';
import '../../../Modules/sources/domain/source_theme_pill.dart';
import '../../../Modules/sources/domain/source_theme_topic.dart';
import '../../../Modules/sources/domain/source_theme_topic_playlist.dart';
import '../../../Modules/downloads/controller/downloads_controller.dart';
import '../../../Modules/home/controller/home_controller.dart';

/// Gestiona: exportar e importar copias de seguridad de la librería.
class BackupRestoreController extends GetxController {
  // ============================
  // 📤 EXPORTAR
  // ============================
  Future<void> exportLibrary() async {
    try {
      final libraryStore = Get.find<LocalLibraryStore>();
      final playlistStore = Get.find<PlaylistStore>();
      final artistStore = Get.find<ArtistStore>();
      final pillStore = Get.find<SourceThemePillStore>();
      final topicStore = Get.find<SourceThemeTopicStore>();
      final topicPlaylistStore = Get.find<SourceThemeTopicPlaylistStore>();

      final items = await libraryStore.readAll();
      final playlists = await playlistStore.readAll();
      final artists = await artistStore.readAll();
      final pills = await pillStore.readAll();
      final topics = await topicStore.readAll();
      final topicPlaylists = await topicPlaylistStore.readAll();

      final appDir = await getApplicationDocumentsDirectory();
      final tempDir = Directory(
        p.join(
          appDir.path,
          'backup_tmp_${DateTime.now().millisecondsSinceEpoch}',
        ),
      );
      await tempDir.create(recursive: true);
      final filesDir = Directory(p.join(tempDir.path, 'files'));
      await filesDir.create(recursive: true);

      Future<String?> copyToBackup(String? absPath) async {
        final clean = absPath?.trim() ?? '';
        if (clean.isEmpty) return null;
        final src = File(clean);
        if (!await src.exists()) return null;

        final rel = _relativeBackupPath(appDir.path, clean);
        final dest = File(p.join(filesDir.path, rel));
        await dest.parent.create(recursive: true);
        await src.copy(dest.path);
        return rel;
      }

      final itemsJson = <Map<String, dynamic>>[];
      for (final item in items) {
        final data = Map<String, dynamic>.from(item.toJson());
        final thumbRel = await copyToBackup(item.thumbnailLocalPath);
        if (thumbRel != null) {
          data['thumbnailLocalPath'] = thumbRel;
        }

        final variants = (data['variants'] as List?) ?? const [];
        final updatedVariants = <Map<String, dynamic>>[];
        for (final raw in variants) {
          if (raw is! Map) continue;
          final v = Map<String, dynamic>.from(raw);
          final localPath = (v['localPath'] as String?)?.trim();
          if (localPath != null && localPath.isNotEmpty) {
            final rel = await copyToBackup(localPath);
            if (rel != null) {
              v['localPath'] = rel;
            }
          }
          updatedVariants.add(v);
        }
        data['variants'] = updatedVariants;
        itemsJson.add(data);
      }

      final playlistsJson = <Map<String, dynamic>>[];
      for (final playlist in playlists) {
        final data = Map<String, dynamic>.from(playlist.toJson());
        final coverRel = await copyToBackup(playlist.coverLocalPath);
        if (coverRel != null) {
          data['coverLocalPath'] = coverRel;
        }
        playlistsJson.add(data);
      }

      final artistsJson = <Map<String, dynamic>>[];
      for (final artist in artists) {
        final data = Map<String, dynamic>.from(artist.toJson());
        final thumbRel = await copyToBackup(artist.thumbnailLocalPath);
        if (thumbRel != null) {
          data['thumbnailLocalPath'] = thumbRel;
        }
        artistsJson.add(data);
      }

      final topicsJson = <Map<String, dynamic>>[];
      for (final topic in topics) {
        final data = Map<String, dynamic>.from(topic.toJson());
        final coverRel = await copyToBackup(topic.coverLocalPath);
        if (coverRel != null) {
          data['coverLocalPath'] = coverRel;
        }
        topicsJson.add(data);
      }

      final topicPlaylistsJson = <Map<String, dynamic>>[];
      for (final playlist in topicPlaylists) {
        final data = Map<String, dynamic>.from(playlist.toJson());
        final coverRel = await copyToBackup(playlist.coverLocalPath);
        if (coverRel != null) {
          data['coverLocalPath'] = coverRel;
        }
        topicPlaylistsJson.add(data);
      }

      final manifest = <String, dynamic>{
        'version': 1,
        'createdAt': DateTime.now().toIso8601String(),
        'items': itemsJson,
        'playlists': playlistsJson,
        'artists': artistsJson,
        'sourceThemePills': pills.map((e) => e.toJson()).toList(),
        'sourceThemeTopics': topicsJson,
        'sourceThemeTopicPlaylists': topicPlaylistsJson,
      };

      final manifestFile = File(p.join(tempDir.path, 'manifest.json'));
      await manifestFile.writeAsString(jsonEncode(manifest), flush: true);

      final backupDir = await _resolveBackupDir();
      await backupDir.create(recursive: true);
      final zipPath = p.join(backupDir.path, _backupFileName());

      final encoder = ZipFileEncoder();
      encoder.create(zipPath);
      encoder.addDirectory(tempDir, includeDirName: false);
      encoder.close();

      await tempDir.delete(recursive: true);

      Get.defaultDialog(
        title: 'Copia de seguridad',
        content: Column(
          children: [
            const Text('Backup guardado en:'),
            const SizedBox(height: 8),
            SelectableText(zipPath, textAlign: TextAlign.center),
          ],
        ),
        textConfirm: 'Copiar ruta',
        textCancel: 'Cerrar',
        onConfirm: () async {
          await Clipboard.setData(ClipboardData(text: zipPath));
          Get.back();
          Get.snackbar(
            'Copia de seguridad',
            'Ruta copiada al portapapeles',
            snackPosition: SnackPosition.BOTTOM,
          );
        },
      );
    } catch (e) {
      Get.snackbar(
        'Copia de seguridad',
        'No se pudo exportar',
        snackPosition: SnackPosition.BOTTOM,
      );
      print('exportLibrary error: $e');
    }
  }

  // ============================
  // 📥 IMPORTAR
  // ============================
  Future<void> importLibrary() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['zip'],
      );
      final file = res?.files.first;
      final path = file?.path;
      if (path == null || path.trim().isEmpty) return;

      final appDir = await getApplicationDocumentsDirectory();
      final tempDir = Directory(
        p.join(
          appDir.path,
          'backup_import_${DateTime.now().millisecondsSinceEpoch}',
        ),
      );
      await tempDir.create(recursive: true);

      final bytes = await File(path).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      for (final file in archive) {
        final filename = file.name;
        final outPath = p.join(tempDir.path, filename);
        if (file.isFile) {
          final outFile = File(outPath);
          await outFile.parent.create(recursive: true);
          await outFile.writeAsBytes(file.content as List<int>, flush: true);
        } else {
          await Directory(outPath).create(recursive: true);
        }
      }

      final manifestFile = File(p.join(tempDir.path, 'manifest.json'));
      if (!await manifestFile.exists()) {
        throw Exception('Manifest not found');
      }

      final manifestRaw = await manifestFile.readAsString();
      final manifest = jsonDecode(manifestRaw) as Map<String, dynamic>;

      String? resolveRel(String? rel) {
        final clean = rel?.trim() ?? '';
        if (clean.isEmpty) return null;
        return p.join(appDir.path, clean);
      }

      Future<void> restoreFile(String? rel) async {
        final clean = rel?.trim() ?? '';
        if (clean.isEmpty) return;
        final src = File(p.join(tempDir.path, 'files', clean));
        if (!await src.exists()) return;
        final dest = File(p.join(appDir.path, clean));
        await dest.parent.create(recursive: true);
        await src.copy(dest.path);
      }

      final libraryStore = Get.find<LocalLibraryStore>();
      final itemsRaw = (manifest['items'] as List?) ?? const [];
      for (final raw in itemsRaw) {
        if (raw is! Map) continue;
        final data = Map<String, dynamic>.from(raw);

        final thumbRel = (data['thumbnailLocalPath'] as String?)?.trim();
        if (thumbRel != null && thumbRel.isNotEmpty) {
          await restoreFile(thumbRel);
          data['thumbnailLocalPath'] = resolveRel(thumbRel);
        }

        final variants = (data['variants'] as List?) ?? const [];
        final updatedVariants = <Map<String, dynamic>>[];
        for (final vRaw in variants) {
          if (vRaw is! Map) continue;
          final v = Map<String, dynamic>.from(vRaw);
          final localRel = (v['localPath'] as String?)?.trim();
          if (localRel != null && localRel.isNotEmpty) {
            await restoreFile(localRel);
            v['localPath'] = resolveRel(localRel);
          }
          updatedVariants.add(v);
        }
        data['variants'] = updatedVariants;

        final item = MediaItem.fromJson(data);
        await libraryStore.upsert(item);
      }

      final playlistStore = Get.find<PlaylistStore>();
      final playlistsRaw = (manifest['playlists'] as List?) ?? const [];
      for (final raw in playlistsRaw) {
        if (raw is! Map) continue;
        final data = Map<String, dynamic>.from(raw);
        final coverRel = (data['coverLocalPath'] as String?)?.trim();
        if (coverRel != null && coverRel.isNotEmpty) {
          await restoreFile(coverRel);
          data['coverLocalPath'] = resolveRel(coverRel);
        }
        await playlistStore.upsert(Playlist.fromJson(data));
      }

      final artistStore = Get.find<ArtistStore>();
      final artistsRaw = (manifest['artists'] as List?) ?? const [];
      for (final raw in artistsRaw) {
        if (raw is! Map) continue;
        final data = Map<String, dynamic>.from(raw);
        final thumbRel = (data['thumbnailLocalPath'] as String?)?.trim();
        if (thumbRel != null && thumbRel.isNotEmpty) {
          await restoreFile(thumbRel);
          data['thumbnailLocalPath'] = resolveRel(thumbRel);
        }
        await artistStore.upsert(ArtistProfile.fromJson(data));
      }

      final pillStore = Get.find<SourceThemePillStore>();
      final pillsRaw = (manifest['sourceThemePills'] as List?) ?? const [];
      for (final raw in pillsRaw) {
        if (raw is! Map) continue;
        await pillStore.upsert(
          SourceThemePill.fromJson(Map<String, dynamic>.from(raw)),
        );
      }

      final topicStore = Get.find<SourceThemeTopicStore>();
      final topicsRaw = (manifest['sourceThemeTopics'] as List?) ?? const [];
      for (final raw in topicsRaw) {
        if (raw is! Map) continue;
        final data = Map<String, dynamic>.from(raw);
        final coverRel = (data['coverLocalPath'] as String?)?.trim();
        if (coverRel != null && coverRel.isNotEmpty) {
          await restoreFile(coverRel);
          data['coverLocalPath'] = resolveRel(coverRel);
        }
        await topicStore.upsert(SourceThemeTopic.fromJson(data));
      }

      final topicPlaylistStore = Get.find<SourceThemeTopicPlaylistStore>();
      final topicPlaylistsRaw =
          (manifest['sourceThemeTopicPlaylists'] as List?) ?? const [];
      for (final raw in topicPlaylistsRaw) {
        if (raw is! Map) continue;
        final data = Map<String, dynamic>.from(raw);
        final coverRel = (data['coverLocalPath'] as String?)?.trim();
        if (coverRel != null && coverRel.isNotEmpty) {
          await restoreFile(coverRel);
          data['coverLocalPath'] = resolveRel(coverRel);
        }
        await topicPlaylistStore.upsert(
          SourceThemeTopicPlaylist.fromJson(data),
        );
      }

      await tempDir.delete(recursive: true);

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

      Get.snackbar(
        'Copia de seguridad',
        'Importación completada',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar(
        'Copia de seguridad',
        'No se pudo importar',
        snackPosition: SnackPosition.BOTTOM,
      );
      print('importLibrary error: $e');
    }
  }

  // ============================
  // 🧰 HELPERS
  // ============================
  Future<Directory> _resolveBackupDir() async {
    if (Platform.isAndroid) {
      final picked = await FilePicker.platform.getDirectoryPath();
      if (picked != null && picked.trim().isNotEmpty) {
        return Directory(p.join(picked, 'ListenfyBackups'));
      }
    }

    final appDir = await getApplicationDocumentsDirectory();
    return Directory(p.join(appDir.path, 'ListenfyBackups'));
  }

  String _backupFileName() {
    final now = DateTime.now();
    final stamp =
        '${now.year.toString().padLeft(4, '0')}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    return 'listenfy_backup_$stamp.zip';
  }

  String _relativeBackupPath(String appRoot, String absolutePath) {
    final normalized = p.normalize(absolutePath);
    if (p.isWithin(appRoot, normalized)) {
      return p.relative(normalized, from: appRoot);
    }
    final base = p.basename(normalized);
    final safe = '${normalized.hashCode}_$base';
    return p.join('external', safe);
  }
}

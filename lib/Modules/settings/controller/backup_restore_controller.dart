import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

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

// Función top-level para poder ejecutarse en un Isolate (hilo separado)
// NOTA: Se pasa la ROTA del archivo (String) y no los bytes (List<int>)
// para evitar que Dart congele la UI clonando megabytes en memoria entre Isolates.
void _extractZipIsolate(Map<String, dynamic> params) {
  final path = params['path'] as String;
  final outDir = params['outDir'] as String;

  final bytes = File(path).readAsBytesSync();
  final archive = ZipDecoder().decodeBytes(bytes);

  for (final archivedFile in archive) {
    if (archivedFile.isFile) {
      final outFile = File(p.join(outDir, archivedFile.name));
      outFile.parent.createSync(recursive: true);
      outFile.writeAsBytesSync(archivedFile.content as List<int>, flush: true);
    } else {
      Directory(p.join(outDir, archivedFile.name)).createSync(recursive: true);
    }
  }
}

// Comprime un directorio en ZIP fuera del hilo principal para evitar ANR.
void _createZipIsolate(Map<String, dynamic> params) {
  final sourceDir = params['sourceDir'] as String;
  final zipPath = params['zipPath'] as String;

  final encoder = ZipFileEncoder();
  encoder.create(zipPath);
  encoder.addDirectory(Directory(sourceDir), includeDirName: false);
  encoder.close();
}

/// Gestiona: exportar e importar copias de seguridad de la librería.
class BackupRestoreController extends GetxController {
  // ============================
  // Estado Reactivo (UI)
  // ============================
  final RxBool isExporting = false.obs;
  final RxBool isImporting = false.obs;
  final RxDouble progress = 0.0.obs;
  final RxString currentOperation = ''.obs;

  Future<void> _yieldUi([int ms = 1]) async {
    await Future.delayed(Duration(milliseconds: ms));
  }

  void _showProgressDialog(String title) {
    progress.value = 0.0;
    currentOperation.value = 'Iniciando...';
    Get.dialog(
      PopScope(
        canPop: false, // Prevenir que cierren el diálogo durante la operación
        child: AlertDialog(
          title: Text(title),
          content: Obx(
            () => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(
                  value: progress.value > 0 ? progress.value : null,
                ),
                const SizedBox(height: 16),
                Text(currentOperation.value, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
      barrierDismissible: false,
    );
  }

  void _closeProgressDialog() {
    if (Get.isDialogOpen ?? false) {
      Get.back();
    }
  }

  // ============================
  // 📤 EXPORTAR
  // ============================
  Future<void> exportLibrary() async {
    if (isExporting.value || isImporting.value) return;

    try {
      final backupDir = await _resolveBackupDir();
      if (backupDir == null) return; // Usuario canceló la selección de carpeta

      // Esperar a que la transición de la Activity Nativa termine antes de abrir el Dialog
      await Future.delayed(const Duration(milliseconds: 300));

      isExporting.value = true;
      _showProgressDialog('Respaldo de Librería');
      // Dar tiempo a Flutter/Android para pintar el diálogo antes de trabajo pesado.
      await _yieldUi(50);
      currentOperation.value = 'Recolectando datos...';
      progress.value = 0.1;

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
      for (int i = 0; i < items.length; i++) {
        if (i % 10 == 0) {
          await _yieldUi();
        }
        currentOperation.value =
            'Procesando canciones (${i + 1}/${items.length})';
        progress.value = 0.1 + (0.4 * (i / items.length));

        final item = items[i];
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

      currentOperation.value = 'Procesando Playlists & Fuentes...';
      progress.value = 0.6;

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

      currentOperation.value = 'Comprimiendo archivo ZIP...';
      progress.value = 0.8;

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

      await backupDir.create(recursive: true);
      final zipPath = p.join(backupDir.path, _backupFileName());

      // La compresión ZIP puede bloquear el hilo UI por varios segundos en MIUI.
      await compute(_createZipIsolate, {
        'sourceDir': tempDir.path,
        'zipPath': zipPath,
      });

      currentOperation.value = 'Limpiando archivos temporales...';
      progress.value = 0.95;

      await tempDir.delete(recursive: true);

      _closeProgressDialog();

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
      _closeProgressDialog();
      Get.snackbar(
        'Copia de seguridad',
        'No se pudo exportar',
        snackPosition: SnackPosition.BOTTOM,
      );
      print('exportLibrary error: $e');
    } finally {
      isExporting.value = false;
      progress.value = 0.0;
    }
  }

  // ============================
  // 📥 IMPORTAR
  // ============================
  Future<void> importLibrary() async {
    if (isExporting.value || isImporting.value) return;

    try {
      FilePickerResult? res;
      try {
        res = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: const ['zip'],
        );
      } catch (pickErr) {
        print('Error al abrir FilePicker: $pickErr');
        return;
      }

      final file = res?.files.first;
      final path = file?.path;
      if (path == null || path.trim().isEmpty) return;

      // Esperar a que la transición de la Activity Nativa termine antes de abrir el Dialog
      // Esto previene el clásico crash "fail in deliverResultsIfNeeded" en Android (MIUI).
      await Future.delayed(const Duration(milliseconds: 300));

      isImporting.value = true;
      _showProgressDialog('Restaurando Librería');
      // Permite que el diálogo llegue a pantalla antes de empezar la restauración.
      await _yieldUi(50);
      currentOperation.value = 'Descomprimiendo backup...';
      progress.value = 0.1;

      final appDir = await getApplicationDocumentsDirectory();
      final tempDir = Directory(
        p.join(
          appDir.path,
          'backup_import_${DateTime.now().millisecondsSinceEpoch}',
        ),
      );
      await tempDir.create(recursive: true);

      currentOperation.value =
          'Extrayendo archivos pesados (puede tardar unos segundos)...';
      progress.value = 0.15;

      // Realizar la descompresión y escritura de disco en un Isolate secundario
      // para evitar que el hilo de la UI de Android/Flutter (Main Thread)
      // colapse provocando un cierre forzado ANR (Application Not Responding).
      await compute(_extractZipIsolate, {'path': path, 'outDir': tempDir.path});

      progress.value = 0.3;

      final manifestFile = File(p.join(tempDir.path, 'manifest.json'));
      if (!await manifestFile.exists()) {
        throw Exception('Manifest not found');
      }

      currentOperation.value = 'Leyendo manifiesto...';
      progress.value = 0.3;

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

      currentOperation.value = 'Restaurando canciones...';
      progress.value = 0.4;

      final libraryStore = Get.find<LocalLibraryStore>();
      final itemsRaw = (manifest['items'] as List?) ?? const [];
      for (int i = 0; i < itemsRaw.length; i++) {
        final raw = itemsRaw[i];

        if (i % 10 == 0) {
          await _yieldUi();
          currentOperation.value =
              'Restaurando canciones (${i + 1}/${itemsRaw.length})';
          progress.value = 0.4 + (0.3 * (i / itemsRaw.length));
        }

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

      currentOperation.value = 'Restaurando Playlists & Artistas...';
      progress.value = 0.75;

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

      currentOperation.value = 'Restaurando Fuentes...';
      progress.value = 0.85;

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

      currentOperation.value =
          'Limpiando temporales y actualizando interfaz...';
      progress.value = 0.95;

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

      _closeProgressDialog();

      Get.snackbar(
        'Copia de seguridad',
        'Importación completada',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      _closeProgressDialog();
      Get.snackbar(
        'Copia de seguridad',
        'No se pudo importar',
        snackPosition: SnackPosition.BOTTOM,
      );
      print('importLibrary error: $e');
    } finally {
      isImporting.value = false;
      progress.value = 0.0;
    }
  }

  // ============================
  // 🧰 HELPERS
  // ============================
  Future<Directory?> _resolveBackupDir() async {
    if (Platform.isAndroid) {
      final picked = await FilePicker.platform.getDirectoryPath();
      if (picked == null || picked.trim().isEmpty) {
        return null;
      }
      return Directory(p.join(picked, 'ListenfyBackups'));
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

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart' as dio;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../app/data/local/local_library_store.dart';
import '../../../app/data/repo/media_repository.dart';
import '../../../app/models/media_item.dart';
import '../../../app/routes/app_routes.dart';
import '../../sources/domain/source_origin.dart';

class DownloadsController extends GetxController {
  // ============================
  // 🔌 DEPENDENCIAS
  // ============================
  final MediaRepository _repo = Get.find<MediaRepository>();
  final LocalLibraryStore _store = Get.find<LocalLibraryStore>();

  // ============================
  // 🧭 ESTADO UI
  // ============================
  final RxList<MediaItem> downloads = <MediaItem>[].obs;
  final RxBool isLoading = false.obs;

  // 📁 Archivos locales para importar
  final RxList<MediaItem> localFilesForImport = <MediaItem>[].obs;
  final RxBool importing = false.obs;
  final RxString sharedUrl = ''.obs;
  final RxBool shareDialogOpen = false.obs;
  StreamSubscription<List<SharedMediaFile>>? _shareSub;

  @override
  void onInit() {
    super.onInit();
    load();
    _listenSharedLinks();
  }

  @override
  void onClose() {
    _shareSub?.cancel();
    super.onClose();
  }

  Future<void> _listenSharedLinks() async {
    try {
      final initial = await ReceiveSharingIntent.instance.getInitialMedia();
      if (initial.isNotEmpty) {
        _setSharedUrl(initial.first.path);
      }
      _shareSub =
          ReceiveSharingIntent.instance.getMediaStream().listen((value) {
        if (value.isNotEmpty) {
          _setSharedUrl(value.first.path);
        }
      });
    } catch (e) {
      debugPrint('Share intent error: $e');
    }
  }

  void _setSharedUrl(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return;
    sharedUrl.value = v;
    _openImportsFromShare(v);
  }

  void _openImportsFromShare(String url) {
    if (Get.currentRoute == AppRoutes.downloads) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Get.currentRoute != AppRoutes.downloads) {
        Get.toNamed(
          AppRoutes.downloads,
          arguments: {'sharedUrl': url},
        );
      }
    });
  }

  // ============================
  // 📥 CARGA DE DESCARGAS
  // ============================
  Future<void> load() async {
    isLoading.value = true;

    try {
      final all = await _repo.getLibrary();

      final list = all.where((item) {
        return item.variants.any((v) {
          final pth = v.localPath ?? '';
          return pth.isNotEmpty &&
              pth.contains('${p.separator}downloads${p.separator}');
        });
      }).toList();

      // Ordenar por fecha más reciente
      list.sort((a, b) {
        final aTime = a.variants.firstOrNull?.createdAt ?? 0;
        final bTime = b.variants.firstOrNull?.createdAt ?? 0;
        return bTime.compareTo(aTime);
      });

      downloads.assignAll(list);
    } catch (e) {
      debugPrint('Error loading downloads: $e');
    } finally {
      isLoading.value = false;
    }
  }

  // Alias
  Future<void> loadDownloads() => load();

  // ============================
  // ▶️ REPRODUCIR
  // ============================
  void play(MediaItem item) {
    final queue = List<MediaItem>.from(downloads);
    final idx = queue.indexWhere((e) => e.id == item.id);

    Get.toNamed(
      AppRoutes.audioPlayer,
      arguments: {'queue': queue, 'index': idx < 0 ? 0 : idx},
    );
  }

  // ============================
  // 🗑️ ELIMINAR
  // ============================
  Future<void> delete(MediaItem item) async {
    try {
      // 1) borrar archivos
      for (final v in item.variants) {
        final pth = v.localPath;
        if (pth != null && pth.isNotEmpty) {
          final f = File(pth);
          if (await f.exists()) await f.delete();
        }
      }

      // 2) borrar de store
      await _store.remove(item.id);

      // 3) recargar
      await load();

      Get.snackbar(
        'Imports',
        'Eliminado correctamente',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      debugPrint('Error deleting download: $e');
      Get.snackbar(
        'Imports',
        'Error al eliminar',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  // ============================
  // ✏️ EDITAR METADATOS
  // ============================
  Future<void> updateMetadata(
    MediaItem item, {
    required String title,
    required String subtitle,
    required String thumbnail,
    int? durationSeconds,
  }) async {
    try {
      final updated = item.copyWith(
        title: title,
        subtitle: subtitle,
        thumbnail: thumbnail.isEmpty ? null : thumbnail,
        durationSeconds: durationSeconds ?? item.durationSeconds,
      );

      await _store.upsert(updated);
      await load();
    } catch (e) {
      debugPrint('Error updating metadata: $e');
      Get.snackbar(
        'Metadata',
        'No se pudo actualizar',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  // ============================
  // ⭐️ FAVORITOS
  // ============================
  Future<void> toggleFavorite(MediaItem item) async {
    try {
      final next = !item.isFavorite;
      final all = await _store.readAll();
      final pid = item.publicId.trim();

      final matches = all.where((e) {
        if (e.id == item.id) return true;
        return pid.isNotEmpty && e.publicId.trim() == pid;
      }).toList();

      if (matches.isEmpty) {
        await _store.upsert(item.copyWith(isFavorite: next));
      } else {
        for (final entry in matches) {
          await _store.upsert(entry.copyWith(isFavorite: next));
        }
      }

      await load();
    } catch (e) {
      debugPrint('Error toggling favorite: $e');
      Get.snackbar(
        'Favoritos',
        'No se pudo actualizar',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  // ============================
  // ⬇️ DESCARGAR DESDE URL
  // ============================
  Future<void> downloadFromUrl({
    String? mediaId,
    required String url,
    required String kind,
  }) async {
    if (url.trim().isEmpty) {
      Get.snackbar(
        'Imports',
        'Por favor ingresa una URL válida',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
      );
      return;
    }

    final format = kind == 'video' ? 'mp4' : 'mp3';

    try {
      Get.dialog(
        const Center(child: CircularProgressIndicator()),
        barrierDismissible: false,
      );

      final ok = await _repo.requestAndFetchMedia(
        mediaId: mediaId?.trim().isEmpty == true ? null : mediaId,
        url: url.trim(),
        kind: kind,
        format: format,
      );

      if (Get.isDialogOpen ?? false) Get.back();

      if (ok) {
        await load();
        Get.snackbar(
          'Imports',
          'Importación completada ✅',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
        );
      } else {
        Get.snackbar(
          'Imports',
          'Falló la importación. La web puede ser lenta o no compatible.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.orange,
        );
      }
    } catch (e) {
      if (Get.isDialogOpen ?? false) Get.back();

      String msg = 'Error inesperado';

      if (e is dio.DioException) {
        switch (e.type) {
          case dio.DioExceptionType.receiveTimeout:
            msg =
                'El servidor tardó demasiado en responder. Intenta nuevamente.';
            break;
          case dio.DioExceptionType.connectionTimeout:
          case dio.DioExceptionType.sendTimeout:
            msg = 'No se pudo conectar con el servidor.';
            break;
          default:
            msg = e.message ?? 'Error de red';
        }
      } else {
        msg = e.toString();
      }

      Get.snackbar(
        'Imports',
        msg,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
      );

      debugPrint('downloadFromUrl error: $e');
    }
  }

  // ============================
  // 📁 DESCARGAR DESDE DISPOSITIVO
  // ============================
  Future<void> pickLocalFilesForImport() async {
    final res = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const [
        'mp3',
        'm4a',
        'wav',
        'flac',
        'aac',
        'ogg',
        'mp4',
        'mov',
        'mkv',
        'webm',
      ],
    );

    if (res == null) return;

    final picked = res.files.where((f) => f.path != null).toList();

    for (final pf in picked) {
      final filePath = pf.path!;
      final ext = p.extension(filePath).replaceFirst('.', '').toLowerCase();

      final isVideo = const ['mp4', 'mkv', 'mov', 'webm'].contains(ext);
      final kind = isVideo ? MediaVariantKind.video : MediaVariantKind.audio;

      final id = await _buildStableId(filePath);

      final variant = MediaVariant(
        kind: kind,
        format: ext,
        fileName: p.basename(filePath),
        localPath: filePath,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );

      final item = MediaItem(
        id: id,
        publicId: id,
        title: pf.name,
        subtitle: '',
        source: MediaSource.local,
        origin: SourceOrigin.device,
        thumbnail: null,
        variants: [variant],
        durationSeconds: null,
      );

      if (localFilesForImport.any((e) => e.id == item.id)) continue;
      localFilesForImport.add(item);
    }
  }

  /// 📥 Importar archivo local a la app
  Future<MediaItem?> importLocalFileToApp(MediaItem item) async {
    try {
      importing.value = true;

      final v = item.variants.first;
      final sourcePath = v.localPath ?? v.fileName;
      final sourceFile = File(sourcePath);

      if (!await sourceFile.exists()) {
        throw Exception('File not found: $sourcePath');
      }

      final appDir = await getApplicationDocumentsDirectory();
      final mediaDir = Directory(p.join(appDir.path, 'media'));
      if (!await mediaDir.exists()) {
        await mediaDir.create(recursive: true);
      }

      final ext = v.format.toLowerCase();
      final destPath = p.join(mediaDir.path, '${item.id}.$ext');
      final destFile = File(destPath);

      if (!await destFile.exists()) {
        await sourceFile.copy(destPath);
      }

      final importedVariant = MediaVariant(
        kind: v.kind,
        format: v.format,
        fileName: p.basename(destPath),
        localPath: destPath,
        createdAt: v.createdAt,
        size: await destFile.length(),
        durationSeconds: v.durationSeconds,
      );

      final importedItem = MediaItem(
        id: item.id,
        publicId: item.publicId,
        title: item.title,
        subtitle: item.subtitle,
        source: MediaSource.local,
        origin: item.origin,
        thumbnail: item.thumbnail,
        variants: [importedVariant],
        durationSeconds: item.durationSeconds,
      );

      await _store.upsert(importedItem);
      await load();

      return importedItem;
    } catch (e) {
      debugPrint('Import failed: $e');
      return null;
    } finally {
      importing.value = false;
    }
  }

  /// 🧹 Limpiar lista local
  void clearLocalFilesForImport() => localFilesForImport.clear();

  // ============================
  // 🔧 HELPERS
  // ============================
  Future<String> _buildStableId(String filePath) async {
    try {
      final f = File(filePath);
      final stat = await f.stat();

      final payload = [
        filePath,
        stat.size.toString(),
        stat.modified.millisecondsSinceEpoch.toString(),
      ].join('|');

      return _sha1(payload);
    } catch (_) {
      return _sha1(filePath);
    }
  }

  String _sha1(String input) {
    final bytes = utf8.encode(input);
    return sha1.convert(bytes).toString();
  }
}

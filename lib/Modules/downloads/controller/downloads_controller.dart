import 'dart:io';

import 'package:dio/dio.dart' as dio;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;

import '../../../app/data/local/local_library_store.dart';
import '../../../app/data/repo/media_repository.dart';
import '../../../app/models/media_item.dart';
import '../../../app/routes/app_routes.dart';

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

  @override
  void onInit() {
    super.onInit();
    load();
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
        'Downloads',
        'Eliminado correctamente',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      debugPrint('Error deleting download: $e');
      Get.snackbar(
        'Downloads',
        'Error al eliminar',
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
    required String format,
  }) async {
    if (url.trim().isEmpty) {
      Get.snackbar(
        'Download',
        'Por favor ingresa una URL válida',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
      );
      return;
    }

    final kind = (format.toLowerCase() == 'mp4') ? 'video' : 'audio';

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
          'Download',
          'Descarga completada ✅',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
        );
      } else {
        Get.snackbar(
          'Download',
          'Falló la descarga. La web puede ser lenta o no compatible.',
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
        'Download',
        msg,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
      );

      debugPrint('downloadFromUrl error: $e');
    }
  }
}

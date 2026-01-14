import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;

import '../../../app/data/local/local_library_store.dart';
import '../../../app/data/repo/media_repository.dart';
import '../../../app/models/media_item.dart';

class DownloadsController extends GetxController {
  final MediaRepository _repo = Get.find<MediaRepository>();
  final LocalLibraryStore _store = Get.find<LocalLibraryStore>();

  final RxList<MediaItem> downloads = <MediaItem>[].obs;
  final RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

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

      downloads.assignAll(list);
    } catch (e) {
      print('Error loading downloads: $e');
    } finally {
      isLoading.value = false;
    }
  }

  void play(MediaItem item) {
    final queue = List<MediaItem>.from(downloads);
    final idx = queue.indexWhere((e) => e.id == item.id);

    Get.toNamed(
      '/audio-player',
      arguments: {'queue': queue, 'index': idx == -1 ? 0 : idx},
    );
  }

  Future<void> delete(MediaItem item) async {
    try {
      for (final v in item.variants) {
        final pth = v.localPath;
        if (pth != null && pth.isNotEmpty) {
          final f = File(pth);
          if (await f.exists()) await f.delete();
        }
      }

      await _store.remove(item.id);
      await load();
      Get.snackbar(
        'Downloads',
        'Eliminado correctamente',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar(
        'Downloads',
        'Error al eliminar',
        snackPosition: SnackPosition.BOTTOM,
      );
      print('Error deleting download: $e');
    }
  }

  /// Solicita al backend descargar a partir de la URL y guarda el resultado en downloads
  Future<void> downloadFromUrl({
    String? mediaId,
    required String url,
    required String format,
  }) async {
    final kind = (format == 'mp4') ? 'video' : 'audio';

    try {
      // mostrar progreso con Get.dialog para no depender de BuildContext
      Get.dialog(
        const Center(child: CircularProgressIndicator()),
        barrierDismissible: false,
      );

      final ok = await _repo.requestAndFetchMedia(
        mediaId: mediaId,
        url: url,
        kind: kind,
        format: format,
      );

      // ocultar progreso
      if (Get.isDialogOpen ?? false) Get.back();

      if (ok) {
        await load();
        Get.snackbar(
          'Download',
          'Descarga completada ✅',
          snackPosition: SnackPosition.BOTTOM,
        );
      } else {
        Get.snackbar(
          'Download',
          'Falló la descarga',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      if (Get.isDialogOpen ?? false) Get.back();
      Get.snackbar(
        'Download',
        'Error inesperado',
        snackPosition: SnackPosition.BOTTOM,
      );
      print('downloadFromUrl error: $e');
    }
  }
}

import 'dart:io';

import 'package:dio/dio.dart' as dio;
import 'package:file_picker/file_picker.dart';
import 'package:get/get.dart';

import '../../../app/config/api_config.dart';
import '../../../app/models/media_item.dart';

class SourcesController extends GetxController {
  final RxList<MediaItem> localFiles = <MediaItem>[].obs;
  final RxBool uploading = false.obs;

  Future<void> pickLocalFiles() async {
    final res = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: [
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
      final p = pf.path!;
      final ext = p.split('.').last.toLowerCase();
      final kind = ['mp4', 'mkv', 'mov', 'webm'].contains(ext)
          ? MediaVariantKind.video
          : MediaVariantKind.audio;

      final variant = MediaVariant(
        kind: kind,
        format: ext,
        fileName: p, // store absolute path for local files
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );

      final item = MediaItem(
        id: p, // use path as id for local items
        publicId: p,
        title: pf.name,
        subtitle: '',
        source: MediaSource.local,
        thumbnail: null,
        variants: [variant],
        durationSeconds: null,
      );

      localFiles.add(item);
    }
  }

  /// Trata de subir archivos al backend (si existe un endpoint de upload).
  /// Si falla, devuelve false.
  Future<bool> uploadFile(MediaItem item) async {
    try {
      uploading.value = true;
      final variant = item.variants.first;
      final f = File(variant.fileName);
      if (!await f.exists()) throw Exception('File not found');

      final url = '${ApiConfig.baseUrl}/api/v1/media/upload';
      final client = dio.Dio();
      final mp = dio.FormData.fromMap({
        'file': await dio.MultipartFile.fromFile(
          variant.fileName,
          filename: f.path.split('/').last,
        ),
        'kind': variant.kind == MediaVariantKind.video ? 'video' : 'audio',
      });

      final resp = await client.post(url, data: mp);

      uploading.value = false;
      return resp.statusCode != null &&
          resp.statusCode! >= 200 &&
          resp.statusCode! < 300;
    } catch (e) {
      uploading.value = false;
      print('Upload failed: $e');
      return false;
    }
  }

  void clearLocal() {
    localFiles.clear();
  }
}

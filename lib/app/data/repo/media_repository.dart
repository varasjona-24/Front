import 'dart:io';

import 'package:dio/dio.dart' as dio;
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../models/media_item.dart';
import '../local/local_library_store.dart';
import '../network/dio_client.dart';
import 'package:flutter_listenfy/Modules/sources/domain/source_origin.dart';

class MediaRepository {
  final DioClient _client = Get.find<DioClient>();
  final LocalLibraryStore _store = Get.find<LocalLibraryStore>();

  /// ✅ Local-first
  Future<List<MediaItem>> getLibrary({
    String? query,
    String? order,
    String? source,
  }) async {
    // 1) siempre algo local
    final localItems = await _store.readAll();

    // filtro básico opcional
    Iterable<MediaItem> result = localItems;

    if (source != null && source.trim().isNotEmpty) {
      final s = source.toLowerCase().trim();
      result = result.where(
        (e) =>
            (s == 'local' && e.source == MediaSource.local) ||
            (s == 'youtube' && e.source == MediaSource.youtube),
      );
    }

    if (query != null && query.trim().isNotEmpty) {
      final q = query.toLowerCase().trim();
      result = result.where(
        (e) =>
            e.title.toLowerCase().contains(q) ||
            e.subtitle.toLowerCase().contains(q),
      );
    }

    final localFiltered = result.toList();

    // 2) opcional: luego puedes mezclar backend
    return localFiltered;
  }

  /// ⬇️ Solicita al backend que descargue y luego recupera el archivo y lo guarda localmente.
  /// Devuelve `true` si la operación finalizó con éxito y el archivo fue guardado.
  Future<bool> requestAndFetchMedia({
    String? mediaId,
    String? url,
    required String kind, // 'audio' | 'video'
    required String format, // 'mp3' | 'm4a' | 'mp4' ...
  }) async {
    try {
      // 1) solicitar descarga al backend
      final resp = await _client.post(
        '/media/download',
        data: {
          if (mediaId != null && mediaId.isNotEmpty) 'mediaId': mediaId,
          'url': url,
          'kind': kind,
          'format': format,
        },
      );

      // intentar obtener mediaId del response si no se entregó
      String resolvedId = mediaId ?? '';
      try {
        final data = resp.data;
        if (data is Map &&
            data['mediaId'] is String &&
            (data['mediaId'] as String).isNotEmpty) {
          resolvedId = data['mediaId'] as String;
        }
      } catch (_) {}

      if (resolvedId.isEmpty) {
        // no tenemos id; usar timestamp-based id
        resolvedId = 'dl-${DateTime.now().millisecondsSinceEpoch}';
      }

      // 2) intentar descargar el archivo servido por el backend con retries
      final path = '/media/file/$resolvedId/$kind/$format';

      dio.Response<List<int>>? getResp;
      int attempts = 0;
      while (attempts < 4) {
        attempts += 1;
        try {
          getResp = await _client.dio.get<List<int>>(
            path,
            options: dio.Options(responseType: dio.ResponseType.bytes),
          );
          if (getResp.statusCode == 200 && (getResp.data?.isNotEmpty ?? false))
            break;
        } catch (e) {
          // esperar y reintentar con backoff
          await Future.delayed(Duration(seconds: 1 << attempts));
          continue;
        }
      }

      final bytes = getResp?.data;
      if (bytes == null || bytes.isEmpty) return false;

      final appDir = await getApplicationDocumentsDirectory();
      final downloadsDir = Directory(p.join(appDir.path, 'downloads'));
      if (!await downloadsDir.exists())
        await downloadsDir.create(recursive: true);

      final destPath = p.join(downloadsDir.path, '$resolvedId.$format');
      final f = File(destPath);
      await f.writeAsBytes(bytes);

      // crear un item y persistir en la librería local
      final variant = MediaVariant(
        kind: kind == 'video' ? MediaVariantKind.video : MediaVariantKind.audio,
        format: format,
        fileName: p.basename(destPath),
        localPath: destPath,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        size: await f.length(),
      );

      final item = MediaItem(
        id: '$resolvedId-$format-${DateTime.now().millisecondsSinceEpoch}',
        publicId: resolvedId,
        title: resolvedId,
        subtitle: url ?? '',
        source: MediaSource.youtube,
        origin: SourceOrigin.generic,
        thumbnail: null,
        variants: [variant],
      );

      await _store.upsert(item);

      return true;
    } catch (e) {
      print('Download failed: $e');
      return false;
    }
  }
}

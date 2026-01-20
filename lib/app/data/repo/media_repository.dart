import 'dart:io';

import 'package:dio/dio.dart' as dio;
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../models/media_item.dart';
import '../local/local_library_store.dart';
import '../network/dio_client.dart';
import 'package:flutter_listenfy/Modules/sources/domain/source_origin.dart';
import 'package:flutter_listenfy/Modules/sources/domain/detect_source_origin.dart';

class MediaRepository {
  // ============================
  // 🔌 DEPENDENCIAS
  // ============================
  final DioClient _client = Get.find<DioClient>();
  final LocalLibraryStore _store = Get.find<LocalLibraryStore>();

  // ============================
  // 📚 LIBRERÍA (LOCAL-FIRST)
  // ============================
  Future<List<MediaItem>> getLibrary({
    String? query,
    String? order,
    String? source,
  }) async {
    // 1) siempre algo local
    final localItems = await _store.readAll();
    final normalizedItems = <MediaItem>[];
    final itemsToUpdate = <MediaItem>[];

    for (final item in localItems) {
      if (item.origin == SourceOrigin.generic) {
        final inferred = _inferOriginFromItem(item);
        if (inferred != SourceOrigin.generic) {
          final updated = item.copyWith(origin: inferred);
          normalizedItems.add(updated);
          itemsToUpdate.add(updated);
          continue;
        }
      }
      normalizedItems.add(item);
    }

    if (itemsToUpdate.isNotEmpty) {
      for (final item in itemsToUpdate) {
        await _store.upsert(item);
      }
    }

    // 2) filtros opcionales
    Iterable<MediaItem> result = normalizedItems;

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

    // 3) orden (si luego lo usas)
    // TODO: aplicar "order" si lo necesitas (por fecha, título, etc.)

    return result.toList();
  }

  // ============================
  // ⬇️ DESCARGA DESDE BACKEND + GUARDADO LOCAL
  // ============================
  /// Flujo:
  /// 1) POST /media/download (backend prepara)
  /// 2) GET  /media/file/:id/:kind/:format (app baja a disco)
  /// 3) (B) GET portada (thumbnail) y guardarla offline
  /// 4) Upsert en librería local con variant.localPath
  Future<bool> requestAndFetchMedia({
    String? mediaId,
    String? url,
    required String kind, // 'audio' | 'video'
    required String format, // 'mp3' | 'm4a' | 'mp4'...
  }) async {
    try {
      // ----------------------------
      // ✅ VALIDACIÓN INPUT
      // ----------------------------
      if ((mediaId == null || mediaId.trim().isEmpty) &&
          (url == null || url.trim().isEmpty)) {
        print('Download error: mediaId or url is required');
        return false;
      }

      final normalizedKind = kind.toLowerCase().trim();
      final normalizedFormat = format.toLowerCase().trim();

      // ----------------------------
      // 1) PEDIR AL BACKEND QUE PREPARE LA VARIANTE
      // ----------------------------
      final resolvedId = await _requestBackendDownload(
        mediaId: mediaId,
        url: url,
        kind: normalizedKind,
        format: normalizedFormat,
      );

      if (resolvedId.isEmpty) return false;

      // ----------------------------
      // 2) DESCARGAR ARCHIVO A DISCO (SIN CARGARLO EN RAM)
      // ----------------------------
      final destPath = await _buildDestPath(
        resolvedId: resolvedId,
        kind: normalizedKind,
        format: normalizedFormat,
      );

      final ok = await _downloadWithRetry(
        path: '/media/file/$resolvedId/$normalizedKind/$normalizedFormat',
        savePath: destPath,
      );

      if (!ok) return false;

      // asegurar que existe y no está vacío
      final f = File(destPath);
      if (!await f.exists()) {
        print('Download error: file not found at $destPath');
        return false;
      }
      final fileSize = await f.length();
      if (fileSize <= 0) {
        print('Download error: file is empty at $destPath');
        return false;
      }

      // ----------------------------
      // 3) CREAR VARIANT LOCAL
      // ----------------------------
      final variant = MediaVariant(
        kind: normalizedKind == 'video'
            ? MediaVariantKind.video
            : MediaVariantKind.audio,
        format: normalizedFormat,
        fileName: p.basename(destPath),
        localPath: destPath,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        size: fileSize,
      );

      // ----------------------------
      // 4) (B) RESOLVER METADATA + PORTADA OFFLINE (SI HAY URL)
      // ----------------------------
      MediaItem? resolved;
      String? thumbnailLocalPath;

      final u = url?.trim();
      if (u != null && u.isNotEmpty) {
        resolved = await _fetchResolvedInfo(u);

        final thumb = resolved?.thumbnail?.trim();
        if (thumb != null && thumb.isNotEmpty) {
          thumbnailLocalPath = await _downloadThumbnailToDisk(
            resolvedId: resolvedId,
            thumbnailUrl: thumb,
          );
        }
      }

      // ----------------------------
      // 5) UPSERT EN LIBRERÍA LOCAL (EVITAR DUPLICADOS)
      // ----------------------------
      final source = _detectSource(url);
      await _upsertItemWithVariant(
        resolvedId: resolvedId,
        url: url,
        source: source,
        variant: variant,
        resolved: resolved,
        thumbnailLocalPath: thumbnailLocalPath,
      );

      return true;
    } catch (e) {
      print('Download failed: $e');
      return false;
    }
  }

  // ============================
  // 🧩 HELPERS (BACKEND)
  // ============================
  Future<String> _requestBackendDownload({
    required String? mediaId,
    required String? url,
    required String kind,
    required String format,
  }) async {
    try {
      final resp = await _client.post(
        '/media/download',
        data: {
          if (mediaId != null && mediaId.trim().isNotEmpty)
            'mediaId': mediaId.trim(),
          if (url != null && url.trim().isNotEmpty) 'url': url.trim(),
          'kind': kind,
          'format': format,
        },
      );

      // resolvedId = prefer mediaId param, else resp.data.mediaId, else fallback
      String resolvedId = (mediaId ?? '').trim();

      final data = resp.data;
      if (resolvedId.isEmpty && data is Map) {
        final v = data['mediaId'];
        if (v is String && v.trim().isNotEmpty) {
          resolvedId = v.trim();
        }
      }

      if (resolvedId.isEmpty) {
        // fallback si el backend no devolvió nada útil
        resolvedId = 'dl-${DateTime.now().millisecondsSinceEpoch}';
      }

      return resolvedId;
    } catch (e) {
      if (e is dio.DioException) {
        print('DIO ERROR: ${e.type}');
        print('URL: ${e.requestOptions.uri}');
        print('STATUS: ${e.response?.statusCode}');
        print('DATA: ${e.response?.data}');
      } else {
        print('Error: $e');
      }
      // 🔥 importante: si falla, retorna vacío para que requestAndFetchMedia haga return false
      return '';
    }
  }

  Future<MediaItem?> _fetchResolvedInfo(String url) async {
    try {
      final resp = await _client.get(
        '/media/resolve-info',
        queryParameters: {'url': url},
      );

      final data = resp.data;

      // Caso común: el endpoint devuelve directo el objeto
      if (data is Map) {
        return MediaItem.fromJson(Map<String, dynamic>.from(data));
      }

      return null;
    } catch (e) {
      print('resolve-info failed: $e');
      return null;
    }
  }

  // ============================
  // 🧩 HELPERS (DESCARGA A DISCO)
  // ============================
  Future<String> _buildDestPath({
    required String resolvedId,
    required String kind,
    required String format,
  }) async {
    final appDir = await getApplicationDocumentsDirectory();
    final downloadsDir = Directory(p.join(appDir.path, 'downloads'));
    if (!await downloadsDir.exists()) {
      await downloadsDir.create(recursive: true);
    }

    // Si quieres nombres distintos por kind:
    // final fileName = '$resolvedId-$kind.$format';
    final fileName = '$resolvedId.$format';
    return p.join(downloadsDir.path, fileName);
  }

  Future<bool> _downloadWithRetry({
    required String path,
    required String savePath,
  }) async {
    int attempts = 0;
    const maxAttempts = 4;
    const initialDelay = Duration(seconds: 1);

    while (true) {
      try {
        // Requiere que tengas _client.download(...) en DioClient
        await _client.download(path, savePath);
        return true;
      } catch (e) {
        attempts++;
        if (attempts >= maxAttempts) {
          print('Download failed after $maxAttempts attempts: $e');
          return false;
        }

        // backoff: 1s, 2s, 4s, 8s
        final delay = initialDelay * (1 << (attempts - 1));
        print(
          'Download attempt $attempts failed, retrying in ${delay.inSeconds}s',
        );
        await Future.delayed(delay);
      }
    }
  }

  // ============================
  // 🧩 HELPERS (THUMBNAIL OFFLINE)
  // ============================
  Future<String?> _downloadThumbnailToDisk({
    required String resolvedId,
    required String thumbnailUrl,
  }) async {
    try {
      final u = thumbnailUrl.trim();
      if (u.isEmpty) return null;

      final appDir = await getApplicationDocumentsDirectory();
      final coversDir = Directory(p.join(appDir.path, 'downloads', 'covers'));
      if (!await coversDir.exists()) {
        await coversDir.create(recursive: true);
      }

      // intentar sacar extensión desde la URL
      final uri = Uri.tryParse(u);
      var ext = '';
      if (uri != null) {
        ext = p.extension(uri.path).toLowerCase();
      }
      if (ext.isEmpty || ext.length > 6) ext = '.jpg'; // fallback seguro

      final coverPath = p.join(coversDir.path, '$resolvedId$ext');

      // bajar bytes
      final resp = await _client.dio.get<List<int>>(
        u,
        options: dio.Options(responseType: dio.ResponseType.bytes),
      );

      final bytes = resp.data;
      if (bytes == null || bytes.isEmpty) return null;

      final f = File(coverPath);
      await f.writeAsBytes(bytes, flush: true);

      return coverPath;
    } catch (e) {
      print('thumbnail download failed: $e');
      return null;
    }
  }

  // ============================
  // 🧩 HELPERS (LIBRERÍA / UPSERT)
  // ============================
  MediaSource _detectSource(String? url) {
    if (url == null || url.trim().isEmpty) return MediaSource.local;

    final u = url.toLowerCase();
    if (u.contains('youtube') || u.contains('youtu.be'))
      return MediaSource.youtube;

    return MediaSource.local;
  }

  SourceOrigin _detectOrigin(String? url) {
    if (url == null || url.trim().isEmpty) return SourceOrigin.generic;
    return detectSourceOriginFromUrl(url);
  }

  SourceOrigin _inferOriginFromItem(MediaItem item) {
    final candidates = <String?>[item.thumbnail, item.subtitle];
    for (final candidate in candidates) {
      final s = candidate?.trim() ?? '';
      if (s.isEmpty || !_looksLikeUrl(s)) continue;
      final detected = detectSourceOriginFromUrl(s);
      if (detected != SourceOrigin.generic) return detected;
    }
    return SourceOrigin.generic;
  }

  bool _looksLikeUrl(String value) {
    final s = value.toLowerCase();
    return s.contains('http://') ||
        s.contains('https://') ||
        s.contains('www.') ||
        s.contains('.com') ||
        s.contains('.net') ||
        s.contains('.org');
  }

  Future<void> _upsertItemWithVariant({
    required String resolvedId,
    required String? url,
    required MediaSource source,
    required MediaVariant variant,

    MediaItem? resolved, // ✅ nuevo
    String? thumbnailLocalPath, // ✅ nuevo
  }) async {
    // Buscar si ya existe un item por publicId
    final all = await _store.readAll();
    final existingIndex = all.indexWhere(
      (e) => e.publicId.trim() == resolvedId.trim(),
    );

    if (existingIndex >= 0) {
      final existing = all[existingIndex];

      // merge variants: reemplaza si existe misma kind+format, si no añade
      final merged = [...existing.variants];
      final i = merged.indexWhere(
        (v) =>
            v.kind == variant.kind &&
            v.format.toLowerCase().trim() ==
                variant.format.toLowerCase().trim(),
      );

      if (i >= 0) {
        merged[i] = variant;
      } else {
        merged.add(variant);
      }

      // Si le falta metadata y tenemos url, intentamos resolver info (fallback)
      MediaItem? resolvedFallback;
      final u = url?.trim();
      if (resolved == null &&
          u != null &&
          u.isNotEmpty &&
          (existing.thumbnail == null ||
              existing.thumbnail!.trim().isEmpty ||
              existing.title.trim().isEmpty ||
              existing.subtitle.trim().isEmpty ||
              existing.durationSeconds == null)) {
        resolvedFallback = await _fetchResolvedInfo(u);
      }

      final r = resolved ?? resolvedFallback;

      final detectedOrigin = _detectOrigin(url);
      final resolvedOrigin =
          (r?.origin != null && r!.origin != SourceOrigin.generic)
              ? r!.origin
              : detectedOrigin;
      final finalOrigin = existing.origin != SourceOrigin.generic
          ? existing.origin
          : resolvedOrigin;

      final updated = existing.copyWith(
        // NO toco title/subtitle si ya existen, solo si están vacíos
        title: (existing.title.trim().isEmpty)
            ? (r?.title ?? resolvedId)
            : existing.title,
        subtitle: (existing.subtitle.trim().isEmpty)
            ? (r?.subtitle ?? (u ?? 'Descarga'))
            : existing.subtitle,
        thumbnail:
            (existing.thumbnail == null || existing.thumbnail!.trim().isEmpty)
            ? r?.thumbnail
            : existing.thumbnail,
        thumbnailLocalPath:
            (existing.thumbnailLocalPath == null ||
                existing.thumbnailLocalPath!.trim().isEmpty)
            ? thumbnailLocalPath
            : existing.thumbnailLocalPath,
        durationSeconds: (existing.durationSeconds == null)
            ? r?.durationSeconds
            : existing.durationSeconds,
        origin: finalOrigin,
        source: existing.source, // respeta el original
        variants: merged,
        publicId: resolvedId, // asegurar consistencia
      );

      await _store.upsert(updated);
      return;
    }

    // Si no existe, intentar crear desde resolve-info para tener portada/título
    MediaItem? resolvedFallback;
    final u = url?.trim();
    if (resolved == null && u != null && u.isNotEmpty) {
      resolvedFallback = await _fetchResolvedInfo(u);
    }

    final detectedOrigin = _detectOrigin(url);
    final resolvedForOrigin = resolved ?? resolvedFallback;
    final resolvedOrigin =
        (resolvedForOrigin?.origin != null &&
                resolvedForOrigin!.origin != SourceOrigin.generic)
            ? resolvedForOrigin!.origin
            : detectedOrigin;

    final base =
        resolved ??
        resolvedFallback ??
        MediaItem(
          id: '$resolvedId-${DateTime.now().millisecondsSinceEpoch}',
          publicId: resolvedId,
          title: resolvedId, // luego lo reemplazas por title real si lo tienes
          subtitle: u ?? 'Descarga local',
          source: source,
          origin: resolvedOrigin,
          thumbnail: null,
          thumbnailLocalPath: null,
          durationSeconds: null,
          variants: const [],
        );

    final item = base.copyWith(
      publicId: resolvedId,
      source: source,
      thumbnailLocalPath: thumbnailLocalPath ?? base.thumbnailLocalPath,
      variants: [
        ...((base.variants).where(
          (v) =>
              !(v.kind == variant.kind &&
                  v.format.toLowerCase().trim() ==
                      variant.format.toLowerCase().trim()),
        )),
        variant,
      ],
    );

    await _store.upsert(item);
  }
}

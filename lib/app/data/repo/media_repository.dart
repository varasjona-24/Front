import 'package:get/get.dart';
import '../../models/media_item.dart';
import '../local/local_library_store.dart';
import '../network/dio_client.dart';

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

    // 2) opcional: luego puedes mezclar backend, pero por ahora NO lo llamo
    // porque tú dijiste “cascarón” y te da timeout.
    return localFiltered;
  }

  /// ⬇️ Download media (más adelante)
  Future<void> downloadMedia({
    required String url,
    required String kind,
    required String format,
  }) async {
    await _client.post(
      '/media/download',
      data: {'url': url, 'kind': kind, 'format': format},
    );
  }
}

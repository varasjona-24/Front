// app/data/repo/media_repository.dart
import 'package:get/get.dart';
import '../../models/media_item.dart';
import '../network/dio_client.dart';

class MediaRepository {
  final DioClient _client = Get.find<DioClient>();

  /// 📚 Media library
  Future<List<MediaItem>> getLibrary({
    String? query,
    String? order,
    String? source,
  }) async {
    final response = await _client.get<List>(
      '/media/library',
      queryParameters: {
        if (query != null) 'q': query,
        if (order != null) 'order': order,
        if (source != null) 'source': source,
      },
    );

    final data = response.data as List;
    return data.map((e) => MediaItem.fromJson(e)).toList();
  }

  /// ⬇️ Download media
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

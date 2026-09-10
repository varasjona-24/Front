import '../data/network/dio_client.dart';

class MetadataSearchQueryResolution {
  const MetadataSearchQueryResolution({
    required this.title,
    required this.artist,
    required this.fallbackTitle,
    required this.fallbackArtist,
    required this.confidence,
    this.suggestions,
    this.suggestionsAvailable = true,
  });

  final String title;
  final String artist;
  final String fallbackTitle;
  final String fallbackArtist;
  final double confidence;
  final List<Map<String, dynamic>>? suggestions;
  final bool suggestionsAvailable;

  bool get hasDifferentFallback =>
      title.toLowerCase() != fallbackTitle.toLowerCase() ||
      artist.toLowerCase() != fallbackArtist.toLowerCase();

  factory MetadataSearchQueryResolution.fromJson(
    Map<String, dynamic> json, {
    required String fallbackTitle,
    required String fallbackArtist,
  }) {
    final query = json['query'];
    final fallback = json['fallback'];
    final queryMap = query is Map ? Map<String, dynamic>.from(query) : const {};
    final fallbackMap = fallback is Map
        ? Map<String, dynamic>.from(fallback)
        : const {};
    final title = (queryMap['title']?.toString() ?? '').trim();
    final artist = (queryMap['artist']?.toString() ?? '').trim();
    final rawConfidence = json['confidence'];
    final confidence = rawConfidence is num
        ? rawConfidence.toDouble()
        : double.tryParse(rawConfidence?.toString() ?? '') ?? 0;
    final rawSuggestions = json['suggestions'];
    final suggestions = rawSuggestions is List
        ? rawSuggestions
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList(growable: false)
        : null;

    return MetadataSearchQueryResolution(
      title: title.isEmpty ? fallbackTitle : title,
      artist: artist.isEmpty ? fallbackArtist : artist,
      fallbackTitle: (fallbackMap['title']?.toString() ?? '').trim().isEmpty
          ? fallbackTitle
          : fallbackMap['title'].toString().trim(),
      fallbackArtist: (fallbackMap['artist']?.toString() ?? '').trim().isEmpty
          ? fallbackArtist
          : fallbackMap['artist'].toString().trim(),
      confidence: confidence.clamp(0, 1).toDouble(),
      suggestions: suggestions,
      suggestionsAvailable: json['suggestionsAvailable'] != false,
    );
  }
}

class MetadataSearchQueryResolverService {
  MetadataSearchQueryResolverService({DioClient? client})
    : _client = client ?? DioClient();

  final DioClient _client;

  Future<MetadataSearchQueryResolution> resolve({
    required String title,
    required String artist,
    int? durationSeconds,
  }) async {
    final fallbackTitle = title.trim();
    final fallbackArtist = artist.trim();
    try {
      final response = await _client.post<Map<String, dynamic>>(
        '/media/metadata/resolve-query',
        data: {
          'title': fallbackTitle,
          'artist': fallbackArtist,
          if (durationSeconds != null && durationSeconds > 0)
            'durationSeconds': durationSeconds,
        },
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return MetadataSearchQueryResolution.fromJson(
          data,
          fallbackTitle: fallbackTitle,
          fallbackArtist: fallbackArtist,
        );
      }
    } catch (_) {
      // The direct MusicBrainz lookup remains available when the resolver is offline.
    }

    return MetadataSearchQueryResolution(
      title: fallbackTitle,
      artist: fallbackArtist,
      fallbackTitle: fallbackTitle,
      fallbackArtist: fallbackArtist,
      confidence: 0,
      suggestions: null,
    );
  }
}

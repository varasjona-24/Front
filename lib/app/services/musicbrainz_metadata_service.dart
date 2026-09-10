import 'package:dio/dio.dart';

const _musicBrainzUserAgent =
    'Listenfy/1.1.0 (https://github.com/varasjona-24/Lisenfy-MVP)';
const _musicBrainzRetryDelays = <Duration>[
  Duration(milliseconds: 1200),
  Duration(milliseconds: 2600),
];

class MusicBrainzRecordingSuggestion {
  const MusicBrainzRecordingSuggestion({
    required this.recordingId,
    required this.title,
    required this.artist,
    required this.score,
    this.releaseId,
    this.releaseTitle,
    this.durationMs,
    this.disambiguation,
  });

  final String recordingId;
  final String title;
  final String artist;
  final int score;
  final String? releaseId;
  final String? releaseTitle;
  final int? durationMs;
  final String? disambiguation;

  String? get releaseCoverThumbnailUrl {
    final id = releaseId?.trim() ?? '';
    if (id.isEmpty) return null;
    return 'https://coverartarchive.org/release/$id/front-250';
  }

  factory MusicBrainzRecordingSuggestion.fromJson(Map<String, dynamic> json) {
    final credits = json['artist-credit'];
    final artistBuffer = StringBuffer();
    if (credits is List) {
      for (final rawCredit in credits) {
        if (rawCredit is! Map) continue;
        final credit = Map<String, dynamic>.from(rawCredit);
        final artist = credit['artist'];
        final name =
            (credit['name'] ?? (artist is Map ? artist['name'] : null) ?? '')
                .toString()
                .trim();
        if (name.isNotEmpty) artistBuffer.write(name);
        artistBuffer.write((credit['joinphrase'] ?? '').toString());
      }
    }

    String? releaseId;
    String? releaseTitle;
    final releases = json['releases'];
    if (releases is List) {
      for (final rawRelease in releases) {
        if (rawRelease is! Map) continue;
        final title = rawRelease['title']?.toString().trim() ?? '';
        if (title.isNotEmpty) {
          releaseId = rawRelease['id']?.toString().trim();
          releaseTitle = title;
          break;
        }
      }
    }

    final rawLength = json['length'];
    final durationMs = rawLength is num
        ? rawLength.toInt()
        : int.tryParse(rawLength?.toString() ?? '');
    final rawScore = json['score'];
    final score = rawScore is num
        ? rawScore.round()
        : int.tryParse(rawScore?.toString() ?? '') ?? 0;
    final rawDisambiguation = json['disambiguation']?.toString().trim() ?? '';

    return MusicBrainzRecordingSuggestion(
      recordingId: json['id']?.toString().trim() ?? '',
      title: json['title']?.toString().trim() ?? '',
      artist: artistBuffer.toString().trim(),
      score: score.clamp(0, 100).toInt(),
      releaseId: releaseId?.isEmpty == true ? null : releaseId,
      releaseTitle: releaseTitle,
      durationMs: durationMs,
      disambiguation: rawDisambiguation.isEmpty ? null : rawDisambiguation,
    );
  }
}

class MusicBrainzMetadataService {
  MusicBrainzMetadataService({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: 'https://musicbrainz.org/ws/2',
              connectTimeout: const Duration(seconds: 12),
              receiveTimeout: const Duration(seconds: 18),
              headers: const {
                'Accept': 'application/json',
                'User-Agent': _musicBrainzUserAgent,
              },
            ),
          );

  final Dio _dio;

  Future<String?> findReleaseCoverUrl(
    MusicBrainzRecordingSuggestion suggestion,
  ) async {
    final releaseId = suggestion.releaseId?.trim() ?? '';
    if (releaseId.isEmpty) return null;

    try {
      final response = await Dio(
        BaseOptions(
          baseUrl: 'https://coverartarchive.org',
          connectTimeout: const Duration(seconds: 12),
          receiveTimeout: const Duration(seconds: 18),
          headers: const {
            'Accept': 'application/json',
            'User-Agent': _musicBrainzUserAgent,
          },
        ),
      ).get<Map<String, dynamic>>('/release/$releaseId');
      final images = response.data?['images'];
      if (images is! List) return null;

      Map<String, dynamic>? selected;
      for (final raw in images) {
        if (raw is! Map) continue;
        final image = Map<String, dynamic>.from(raw);
        if (image['front'] == true) {
          selected = image;
          break;
        }
        selected ??= image;
      }
      if (selected == null) return null;

      final thumbnails = selected['thumbnails'];
      if (thumbnails is Map) {
        final url =
            thumbnails['500']?.toString().trim() ??
            thumbnails['250']?.toString().trim() ??
            thumbnails['large']?.toString().trim() ??
            '';
        if (url.isNotEmpty) return url;
      }
      final original = selected['image']?.toString().trim() ?? '';
      return original.isEmpty ? null : original;
    } on DioException {
      return null;
    }
  }

  Future<List<MusicBrainzRecordingSuggestion>> searchRecordings({
    required String title,
    required String artist,
    String? fallbackTitle,
    String? fallbackArtist,
    int limit = 10,
  }) async {
    final suggestions = await _searchRecordings(
      title: title,
      artist: artist,
      limit: limit,
    );
    final safeFallbackTitle = fallbackTitle?.trim() ?? '';
    final safeFallbackArtist = fallbackArtist?.trim() ?? '';
    final differsFromFallback =
        safeFallbackTitle.toLowerCase() != title.trim().toLowerCase() ||
        safeFallbackArtist.toLowerCase() != artist.trim().toLowerCase();
    if (suggestions.isNotEmpty ||
        !differsFromFallback ||
        safeFallbackTitle.isEmpty) {
      return suggestions;
    }
    return _searchRecordings(
      title: safeFallbackTitle,
      artist: safeFallbackArtist,
      limit: limit,
    );
  }

  List<MusicBrainzRecordingSuggestion> suggestionsFromJson(
    List<Map<String, dynamic>> recordings,
  ) {
    return recordings
        .map(MusicBrainzRecordingSuggestion.fromJson)
        .where(
          (suggestion) =>
              suggestion.recordingId.isNotEmpty &&
              suggestion.title.isNotEmpty &&
              suggestion.artist.isNotEmpty,
        )
        .toList(growable: false)
      ..sort((a, b) => b.score.compareTo(a.score));
  }

  Future<List<MusicBrainzRecordingSuggestion>> _searchRecordings({
    required String title,
    required String artist,
    required int limit,
  }) async {
    final cleanTitle = title.trim();
    final cleanArtist = artist.trim();
    if (cleanTitle.isEmpty) return const <MusicBrainzRecordingSuggestion>[];

    final queryParts = <String>[
      'recording:${_lucenePhrase(cleanTitle)}',
      if (cleanArtist.isNotEmpty) 'artistname:${_lucenePhrase(cleanArtist)}',
    ];
    final safeLimit = limit.clamp(1, 10).toInt();
    final response = await _getRecordingsWithRetry(
      queryParameters: {
        'query': queryParts.join(' AND '),
        'fmt': 'json',
        'limit': safeLimit,
      },
    );
    final recordings = response.data?['recordings'];
    if (recordings is! List) {
      return const <MusicBrainzRecordingSuggestion>[];
    }

    return suggestionsFromJson(
      recordings
          .whereType<Map>()
          .map((raw) => Map<String, dynamic>.from(raw))
          .toList(growable: false),
    );
  }

  Future<Response<Map<String, dynamic>>> _getRecordingsWithRetry({
    required Map<String, dynamic> queryParameters,
  }) async {
    for (var attempt = 0; ; attempt++) {
      try {
        return await _dio.get<Map<String, dynamic>>(
          '/recording/',
          queryParameters: queryParameters,
        );
      } on DioException catch (error) {
        final canRetry =
            attempt < _musicBrainzRetryDelays.length && _isRetryable(error);
        if (!canRetry) rethrow;
        await Future<void>.delayed(_musicBrainzRetryDelays[attempt]);
      }
    }
  }

  bool _isRetryable(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return true;
      case DioExceptionType.badResponse:
        final status = error.response?.statusCode ?? 0;
        return status == 429 || status == 502 || status == 503 || status == 504;
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return false;
    }
  }

  String _lucenePhrase(String raw) {
    const specialCharacters = r'+-!(){}[]^"~*?:\\/&|';
    final escaped = StringBuffer();
    for (final char in raw.runes.map(String.fromCharCode)) {
      if (specialCharacters.contains(char)) escaped.write('\\');
      escaped.write(char);
    }
    return '"${escaped.toString()}"';
  }
}

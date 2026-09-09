import 'package:dio/dio.dart';

import '../models/media_item.dart';

const _lrclibUserAgent =
    'Listenfy/1.1.0 (https://github.com/varasjona-24/Lisenfy-MVP)';

class LrclibLyricsResult {
  const LrclibLyricsResult({
    required this.id,
    required this.trackName,
    required this.artistName,
    required this.albumName,
    required this.durationSeconds,
    required this.instrumental,
    this.plainLyrics,
    this.syncedLyrics,
  });

  final int id;
  final String trackName;
  final String artistName;
  final String albumName;
  final double? durationSeconds;
  final bool instrumental;
  final String? plainLyrics;
  final String? syncedLyrics;

  bool get hasLyrics =>
      (plainLyrics?.trim().isNotEmpty ?? false) ||
      (syncedLyrics?.trim().isNotEmpty ?? false);

  List<TimedLyricCue> get timedCues => parseLrc(syncedLyrics);

  String get preferredLyrics => plainLyrics?.trim().isNotEmpty == true
      ? plainLyrics!.trim()
      : timedCues.map((cue) => cue.text).join('\n');

  factory LrclibLyricsResult.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    final rawDuration = json['duration'];
    return LrclibLyricsResult(
      id: rawId is num ? rawId.toInt() : int.tryParse('$rawId') ?? 0,
      trackName: (json['trackName'] ?? json['name'] ?? '').toString().trim(),
      artistName: (json['artistName'] ?? '').toString().trim(),
      albumName: (json['albumName'] ?? '').toString().trim(),
      durationSeconds: rawDuration is num
          ? rawDuration.toDouble()
          : double.tryParse('$rawDuration'),
      instrumental: json['instrumental'] == true,
      plainLyrics: _cleanNullable(json['plainLyrics']),
      syncedLyrics: _cleanNullable(json['syncedLyrics']),
    );
  }

  static String? _cleanNullable(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  static List<TimedLyricCue> parseLrc(String? rawLyrics) {
    final raw = rawLyrics?.replaceAll('\r\n', '\n').trim() ?? '';
    if (raw.isEmpty) return const <TimedLyricCue>[];

    final timestamp = RegExp(
      r'\[(?:(\d+):)?(\d{1,2}):(\d{2})(?:[.:](\d{1,3}))?\]',
    );
    final cues = <TimedLyricCue>[];
    for (final line in raw.split('\n')) {
      final matches = timestamp.allMatches(line).toList(growable: false);
      if (matches.isEmpty) continue;
      final text = line.replaceAll(timestamp, '').trim();
      if (text.isEmpty) continue;
      for (final match in matches) {
        final hours = int.tryParse(match.group(1) ?? '') ?? 0;
        final minutes = int.tryParse(match.group(2) ?? '') ?? 0;
        final seconds = int.tryParse(match.group(3) ?? '') ?? 0;
        final fraction = match.group(4) ?? '';
        final milliseconds = switch (fraction.length) {
          1 => (int.tryParse(fraction) ?? 0) * 100,
          2 => (int.tryParse(fraction) ?? 0) * 10,
          _ => int.tryParse(fraction) ?? 0,
        };
        cues.add(
          TimedLyricCue(
            text: text,
            startMs:
                (((hours * 60 + minutes) * 60 + seconds) * 1000) + milliseconds,
          ),
        );
      }
    }
    cues.sort((a, b) => a.startMs.compareTo(b.startMs));
    return cues;
  }
}

class LrclibLyricsService {
  LrclibLyricsService({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: 'https://lrclib.net/api',
              connectTimeout: const Duration(seconds: 12),
              receiveTimeout: const Duration(seconds: 18),
              headers: const {
                'Accept': 'application/json',
                'User-Agent': _lrclibUserAgent,
              },
            ),
          );

  final Dio _dio;

  Future<LrclibLyricsResult?> findBestMatch({
    required String title,
    required String artist,
    String? album,
    int? durationSeconds,
  }) async {
    final cleanTitle = title.trim();
    final cleanArtist = artist.trim();
    if (cleanTitle.isEmpty || cleanArtist.isEmpty) return null;

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/get',
        queryParameters: {
          'track_name': cleanTitle,
          'artist_name': cleanArtist,
          if (album?.trim().isNotEmpty ?? false) 'album_name': album!.trim(),
          if (durationSeconds != null && durationSeconds > 0)
            'duration': durationSeconds,
        },
      );
      final data = response.data;
      return data == null ? null : LrclibLyricsResult.fromJson(data);
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<List<LrclibLyricsResult>> search({
    required String title,
    required String artist,
    String? album,
  }) async {
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty) return const <LrclibLyricsResult>[];
    final response = await _dio.get<List<dynamic>>(
      '/search',
      queryParameters: {
        'track_name': cleanTitle,
        if (artist.trim().isNotEmpty) 'artist_name': artist.trim(),
        if (album?.trim().isNotEmpty ?? false) 'album_name': album!.trim(),
      },
    );
    return (response.data ?? const <dynamic>[])
        .whereType<Map>()
        .map(
          (raw) => LrclibLyricsResult.fromJson(Map<String, dynamic>.from(raw)),
        )
        .where((result) => result.hasLyrics)
        .take(20)
        .toList(growable: false);
  }
}

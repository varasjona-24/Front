import 'package:collection/collection.dart';

enum MediaSource { local, youtube }

enum MediaVariantKind { audio, video }

class MediaItem {
  final String id; // interno (hash)
  final String publicId; // backend / variantes
  final String title;
  final String subtitle;
  final MediaSource source;
  final String? thumbnail;
  final List<MediaVariant> variants;

  /// Duración base del media
  final int? durationSeconds;

  MediaItem({
    required this.id,
    required this.publicId,
    required this.title,
    required this.subtitle,
    required this.source,
    required this.variants,
    this.thumbnail,
    this.durationSeconds,
  });

  /// ID preferido para endpoints / archivos
  String get fileId => publicId.trim().isNotEmpty ? publicId.trim() : id.trim();

  bool get hasAudio => variants.any((v) => v.kind == MediaVariantKind.audio);
  bool get hasVideo => variants.any((v) => v.kind == MediaVariantKind.video);

  MediaVariant? get audioVariant =>
      variants.firstWhereOrNull((v) => v.kind == MediaVariantKind.audio);

  MediaVariant? get videoVariant =>
      variants.firstWhereOrNull((v) => v.kind == MediaVariantKind.video);

  /// Duración preferida
  int? get effectiveDurationSeconds =>
      audioVariant?.durationSeconds ?? durationSeconds;

  // ---------------------------------------------------------------------------
  // JSON
  // ---------------------------------------------------------------------------

  factory MediaItem.fromJson(Map<String, dynamic> json) {
    final variantsJson = (json['variants'] as List?) ?? const [];
    final variants = variantsJson
        .whereType<Map>()
        .map((m) => MediaVariant.fromJson(Map<String, dynamic>.from(m)))
        .where((v) => v.isValid)
        .toList();

    final id = (json['id'] as String?)?.trim() ?? '';
    final publicId = (json['publicId'] as String?)?.trim() ?? '';

    final titleRaw = (json['title'] as String?)?.trim();
    final title = (titleRaw != null && titleRaw.isNotEmpty)
        ? titleRaw
        : 'Unknown title';

    final subtitle =
        (json['artist'] as String?)?.trim() ??
        (json['subtitle'] as String?)?.trim() ??
        '';

    final sourceStr = (json['source'] as String?)?.toLowerCase().trim();
    final source = sourceStr == 'local'
        ? MediaSource.local
        : MediaSource.youtube;

    final durationSeconds = _parseDurationToSeconds(
      json['duration'] ??
          json['durationSeconds'] ??
          json['length'] ??
          json['lengthSeconds'],
    );

    return MediaItem(
      id: id,
      publicId: publicId,
      title: title,
      subtitle: subtitle,
      source: source,
      thumbnail: (json['thumbnail'] as String?)?.trim(),
      variants: variants,
      durationSeconds: durationSeconds,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'publicId': publicId,
    'title': title,
    'artist': subtitle,
    'source': source == MediaSource.local ? 'local' : 'youtube',
    'thumbnail': thumbnail,
    'duration': durationSeconds,
    'variants': variants.map((v) => v.toJson()).toList(),
  };

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static int? _parseDurationToSeconds(dynamic raw) {
    if (raw == null) return null;

    if (raw is num) {
      var v = raw.toInt();
      if (v > 100000) v = (v / 1000).round(); // ms -> s
      return v >= 0 ? v : null;
    }

    if (raw is String) {
      final s = raw.trim();
      if (s.isEmpty) return null;

      if (s.contains(':')) {
        final parts = s.split(':').map((p) => int.tryParse(p.trim())).toList();
        if (parts.any((e) => e == null)) return null;

        if (parts.length == 3) {
          return parts[0]! * 3600 + parts[1]! * 60 + parts[2]!;
        }
        if (parts.length == 2) {
          return parts[0]! * 60 + parts[1]!;
        }
      }

      var v = int.tryParse(s);
      if (v == null) return null;
      if (v > 100000) v = (v / 1000).round();
      return v >= 0 ? v : null;
    }

    return null;
  }
}

// ============================================================================
// MediaVariant
// ============================================================================

class MediaVariant {
  final MediaVariantKind kind;
  final String format;

  /// Nombre del archivo (ej: song.mp3)
  final String fileName;

  /// Ruta REAL del archivo en el dispositivo (picker o storage interno)
  final String? localPath;

  final int createdAt;
  final int? size;
  final int? durationSeconds;

  MediaVariant({
    required this.kind,
    required this.format,
    required this.fileName,
    required this.createdAt,
    this.localPath,
    this.size,
    this.durationSeconds,
  });

  factory MediaVariant.fromJson(Map<String, dynamic> json) {
    final fileName =
        (json['fileName'] as String?)?.trim() ??
        (json['path'] as String?)?.split('/').last.trim() ??
        '';

    final localPath = (json['localPath'] as String?)?.trim();

    final kindStr = (json['kind'] as String?)?.toLowerCase().trim();
    final kind = kindStr == 'video'
        ? MediaVariantKind.video
        : MediaVariantKind.audio;

    final format = (json['format'] as String?)?.trim() ?? '';
    final createdAt = (json['createdAt'] as num?)?.toInt() ?? 0;
    final size = (json['size'] as num?)?.toInt();

    final rawDur =
        json['durationSeconds'] ??
        json['duration'] ??
        json['lengthSeconds'] ??
        json['length'] ??
        json['durationMs'];

    final durationSeconds = MediaItem._parseDurationToSeconds(rawDur);

    return MediaVariant(
      kind: kind,
      format: format,
      fileName: fileName,
      localPath: localPath,
      createdAt: createdAt,
      size: size,
      durationSeconds: durationSeconds,
    );
  }

  Map<String, dynamic> toJson() => {
    'kind': kind == MediaVariantKind.video ? 'video' : 'audio',
    'format': format,
    'fileName': fileName,
    'localPath': localPath,
    'createdAt': createdAt,
    'size': size,
    'durationSeconds': durationSeconds,
  };

  bool get isValid => fileName.isNotEmpty && format.isNotEmpty;

  /// Ruta usable por el player (si es local)
  String? get playablePath => localPath;
}

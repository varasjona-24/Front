class AudioSilenceSegment {
  const AudioSilenceSegment({
    required this.startMs,
    required this.endMs,
    required this.durationMs,
    required this.meanDb,
  });

  final int startMs;
  final int endMs;
  final int durationMs;
  final double meanDb;

  Map<String, dynamic> toJson() => {
    'startMs': startMs,
    'endMs': endMs,
    'durationMs': durationMs,
    'meanDb': meanDb,
  };

  factory AudioSilenceSegment.fromJson(Map<String, dynamic> json) {
    return AudioSilenceSegment(
      startMs: (json['startMs'] as num?)?.toInt() ?? 0,
      endMs: (json['endMs'] as num?)?.toInt() ?? 0,
      durationMs: (json['durationMs'] as num?)?.toInt() ?? 0,
      meanDb: (json['meanDb'] as num?)?.toDouble() ?? -120.0,
    );
  }
}

class AudioSilenceAnalysis {
  const AudioSilenceAnalysis({
    required this.durationMs,
    required this.sampleRate,
    required this.channels,
    required this.segments,
  });

  final int durationMs;
  final int sampleRate;
  final int channels;
  final List<AudioSilenceSegment> segments;

  factory AudioSilenceAnalysis.fromJson(Map<String, dynamic> json) {
    final rawSegments = (json['segments'] as List?) ?? const <dynamic>[];
    final segments = rawSegments
        .whereType<Map>()
        .map((m) => AudioSilenceSegment.fromJson(Map<String, dynamic>.from(m)))
        .toList(growable: false);

    return AudioSilenceAnalysis(
      durationMs: (json['durationMs'] as num?)?.toInt() ?? 0,
      sampleRate: (json['sampleRate'] as num?)?.toInt() ?? 0,
      channels: (json['channels'] as num?)?.toInt() ?? 0,
      segments: segments,
    );
  }
}

class AudioCleanupRenderResult {
  const AudioCleanupRenderResult({
    required this.outputPath,
    required this.originalDurationMs,
    required this.cleanedDurationMs,
    required this.removedDurationMs,
    required this.sampleRate,
    required this.channels,
    required this.removedSegmentsCount,
  });

  final String outputPath;
  final int originalDurationMs;
  final int cleanedDurationMs;
  final int removedDurationMs;
  final int sampleRate;
  final int channels;
  final int removedSegmentsCount;

  factory AudioCleanupRenderResult.fromJson(Map<String, dynamic> json) {
    return AudioCleanupRenderResult(
      outputPath: (json['outputPath'] as String?)?.trim() ?? '',
      originalDurationMs: (json['originalDurationMs'] as num?)?.toInt() ?? 0,
      cleanedDurationMs: (json['cleanedDurationMs'] as num?)?.toInt() ?? 0,
      removedDurationMs: (json['removedDurationMs'] as num?)?.toInt() ?? 0,
      sampleRate: (json['sampleRate'] as num?)?.toInt() ?? 0,
      channels: (json['channels'] as num?)?.toInt() ?? 0,
      removedSegmentsCount:
          (json['removedSegmentsCount'] as num?)?.toInt() ?? 0,
    );
  }
}

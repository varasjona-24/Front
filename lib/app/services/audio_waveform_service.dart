import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AudioWaveformData {
  const AudioWaveformData({
    required this.durationMs,
    required this.sampleRate,
    required this.channels,
    required this.buckets,
  });

  final int durationMs;
  final int sampleRate;
  final int channels;
  final List<double> buckets;

  factory AudioWaveformData.fromJson(Map<String, dynamic> json) {
    final rawBuckets = (json['buckets'] as List?) ?? const <dynamic>[];
    final buckets = rawBuckets
        .map((e) => (e as num?)?.toDouble() ?? 0.0)
        .map((v) => v.clamp(0.0, 1.0))
        .toList(growable: false);

    return AudioWaveformData(
      durationMs: (json['durationMs'] as num?)?.toInt() ?? 0,
      sampleRate: (json['sampleRate'] as num?)?.toInt() ?? 0,
      channels: (json['channels'] as num?)?.toInt() ?? 0,
      buckets: buckets,
    );
  }
}

class AudioWaveformService {
  static const MethodChannel _channel = MethodChannel(
    'listenfy/audio_waveform',
  );

  Future<AudioWaveformData?> extractWaveform({
    required String localPath,
    int buckets = 72,
  }) async {
    final path = localPath.trim();
    if (path.isEmpty) return null;

    try {
      final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'extractWaveform',
        {'path': path, 'buckets': buckets},
      );
      if (raw == null) return null;
      return AudioWaveformData.fromJson(Map<String, dynamic>.from(raw));
    } on MissingPluginException {
      return null;
    } on PlatformException catch (e) {
      throw Exception(e.message ?? 'No se pudo extraer forma de onda.');
    } catch (e) {
      debugPrint('audio waveform error: $e');
      throw Exception('No se pudo extraer forma de onda.');
    }
  }
}

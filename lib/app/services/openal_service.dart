import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class OpenALPlayResult {
  final int durationMs;
  final int sampleRate;
  final int channels;

  const OpenALPlayResult({
    required this.durationMs,
    required this.sampleRate,
    required this.channels,
  });
}

class OpenALService {
  static const _channel = MethodChannel('listenfy/openal');

  Future<OpenALPlayResult?> playFile(String path) async {
    if (!Platform.isAndroid) return null;
    try {
      final res = await _channel.invokeMethod<Map>('playFile', {
        'path': path,
        'enableHrtf': true,
      });
      if (res == null) return null;
      return OpenALPlayResult(
        durationMs: (res['durationMs'] as num?)?.toInt() ?? 0,
        sampleRate: (res['sampleRate'] as num?)?.toInt() ?? 0,
        channels: (res['channels'] as num?)?.toInt() ?? 0,
      );
    } catch (e) {
      debugPrint('OpenAL play error: $e');
      return null;
    }
  }

  Future<void> pause() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('pause');
    } catch (e) {
      debugPrint('OpenAL pause error: $e');
    }
  }

  Future<void> resume() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('resume');
    } catch (e) {
      debugPrint('OpenAL resume error: $e');
    }
  }

  Future<void> seek(Duration position) async {
    if (!Platform.isAndroid) return;
    try {
      final seconds = position.inMilliseconds / 1000.0;
      await _channel.invokeMethod('seek', {'seconds': seconds});
    } catch (e) {
      debugPrint('OpenAL seek error: $e');
    }
  }

  Future<void> stop() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('stop');
    } catch (e) {
      debugPrint('OpenAL stop error: $e');
    }
  }

  Future<void> release() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('release');
    } catch (e) {
      debugPrint('OpenAL release error: $e');
    }
  }
}

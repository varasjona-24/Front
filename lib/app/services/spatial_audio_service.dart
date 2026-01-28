import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'audio_service.dart';

enum SpatialAudioMode { off, virtualizer }

class SpatialAudioService extends GetxService {
  static const _channel = MethodChannel('listenfy/spatial_audio');

  final AudioService audioService;
  final Rx<SpatialAudioMode> mode = SpatialAudioMode.off.obs;

  StreamSubscription<int?>? _sessionSub;
  SpatialAudioMode? _pendingMode;
  int? _lastSessionId;

  SpatialAudioService({required this.audioService});

  @override
  void onInit() {
    super.onInit();

    if (Platform.isAndroid) {
      _sessionSub =
          audioService.androidAudioSessionIdStream.listen((sessionId) async {
        if (sessionId == null || sessionId == 0) return;
        _lastSessionId = sessionId;
        if (_pendingMode != null || mode.value != SpatialAudioMode.off) {
          final nextMode = _pendingMode ?? mode.value;
          _pendingMode = null;
          await _applyMode(nextMode, sessionId);
        }
      });

      // Reaplicar efectos si la reproducción se reanuda o cambia el estado
      ever(audioService.isPlaying, (_) => _reapplyIfNeeded());
      ever(audioService.state, (_) => _reapplyIfNeeded());
    }
  }

  Future<bool> setMode(SpatialAudioMode value) async {
    mode.value = value;
    if (!Platform.isAndroid) return false;
    final sessionId = audioService.androidAudioSessionId;
    if (sessionId == null || sessionId == 0) {
      _pendingMode = value;
      return true;
    }

    _lastSessionId = sessionId;
    return await _applyMode(value, sessionId);
  }

  Future<bool> _applyMode(SpatialAudioMode value, int sessionId) async {
    try {
      if (value == SpatialAudioMode.virtualizer) {
        await _channel.invokeMethod('enable', {
          'enabled': true,
          'sessionId': sessionId,
        });
      } else {
        await _channel.invokeMethod('enable', {
          'enabled': false,
          'sessionId': sessionId,
        });
      }
      return true;
    } catch (e) {
      debugPrint('Spatial audio error: $e');
      return false;
    }
  }

  Future<void> _reapplyIfNeeded() async {
    if (!Platform.isAndroid) return;
    if (mode.value == SpatialAudioMode.off) return;
    final sessionId = _lastSessionId ?? audioService.androidAudioSessionId;
    if (sessionId == null || sessionId == 0) return;
    await _applyMode(mode.value, sessionId);
  }

  @override
  void onClose() {
    _sessionSub?.cancel();
    if (Platform.isAndroid) {
      _channel.invokeMethod('release');
    }
    super.onClose();
  }
}

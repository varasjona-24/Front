import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class AudioVisualizerService {
  static const MethodChannel _methodChannel = MethodChannel(
    'listenfy/audio_visualizer',
  );
  static const EventChannel _eventChannel = EventChannel(
    'listenfy/audio_visualizer/events',
  );

  final StreamController<List<double>> _barsController =
      StreamController<List<double>>.broadcast();

  StreamSubscription<dynamic>? _eventSub;
  int? _attachedSessionId;

  Stream<List<double>> get barsStream => _barsController.stream;

  Future<void> attachToSession(int sessionId, {int barCount = 64}) async {
    if (!Platform.isAndroid || sessionId <= 0) return;
    if (_attachedSessionId == sessionId) return;

    final granted = await _ensureMicrophonePermission();
    if (!granted) {
      throw Exception('Permiso de microfono requerido para visualizador real.');
    }

    _ensureEventSubscription();

    await _methodChannel.invokeMethod('attach', {
      'sessionId': sessionId,
      'barCount': barCount,
    });
    _attachedSessionId = sessionId;
  }

  Future<void> detach() async {
    if (!Platform.isAndroid) return;
    try {
      await _methodChannel.invokeMethod('detach');
    } catch (e) {
      debugPrint('audio visualizer detach error: $e');
    } finally {
      _attachedSessionId = null;
    }
  }

  Future<bool> _ensureMicrophonePermission() async {
    final current = await Permission.microphone.status;
    if (current.isGranted) return true;
    final requested = await Permission.microphone.request();
    return requested.isGranted;
  }

  void _ensureEventSubscription() {
    if (_eventSub != null) return;
    _eventSub = _eventChannel.receiveBroadcastStream().listen(
      (event) {
        if (event is! Map) return;
        final rawBars = event['bars'];
        if (rawBars is! List) return;
        final bars = rawBars
            .map((v) => (v as num?)?.toDouble() ?? 0.0)
            .map((v) => v.clamp(0.0, 1.0))
            .toList(growable: false);
        if (bars.isEmpty) return;
        _barsController.add(bars);
      },
      onError: (error) {
        debugPrint('audio visualizer events error: $error');
      },
    );
  }
}

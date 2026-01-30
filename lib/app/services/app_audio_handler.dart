import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

import 'audio_service.dart' as app;

/// AppAudioHandler
/// - Puente entre `just_audio` y `audio_service`.
/// - Publica:
///  1) `mediaItem` (metadatos + duration)
///  2) `playbackState` (controles + posición + estado)
///

class AppAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final app.AudioService _app;
  final AudioPlayer _player;
  static const MediaControl _stopControl = MediaControl(
    androidIcon: 'drawable/ic_close',
    label: 'Cerrar',
    action: MediaAction.stop,
  );

  StreamSubscription<PlaybackEvent>? _eventSub;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration?>? _durSub;
  StreamSubscription<int?>? _indexSub;

  Timer? _ticker;

  int _queueLength = 0;
  PlaybackEvent? _lastEvent;

  // 🧸 peluches: duration real cacheada (por si llega antes del mediaItem)
  Duration? _pendingDuration;

  AppAudioHandler(this._app) : _player = _app.player {
    // 🧸 peluches: eventos del reproductor (state, buffering, index, etc.)
    _eventSub = _player.playbackEventStream.listen((event) {
      _lastEvent = event;
      _broadcastState(event);
      _syncTicker();
    });

    // 🧸 peluches: posición (progreso)
    _posSub = _player.positionStream.listen((pos) {
      final event = _lastEvent;
      if (event == null) return;
      _broadcastState(event, position: pos);
    });

    // 🧸 peluches: duración real del audio
    _durSub = _player.durationStream.listen((dur) {
      if (dur == null) return;

      // 🧸 SIEMPRE guarda la duración real
      _pendingDuration = dur;

      final current = mediaItem.value;
      if (current == null) return;

      if (current.duration != dur) {
        mediaItem.add(current.copyWith(duration: dur));
      }
    });

    // 🧸 peluches: cambios de pista (cola)
    _indexSub = _player.currentIndexStream.listen(_handleIndex);
  }

  Future<void> dispose() async {
    _ticker?.cancel();
    await _eventSub?.cancel();
    await _posSub?.cancel();
    await _durSub?.cancel();
    await _indexSub?.cancel();
  }

  // -----------------------
  // Queue / MediaItem
  // -----------------------

  @override
  Future<void> updateQueue(List<MediaItem> queue) async {
    _queueLength = queue.length;
    this.queue.add(queue);
  }

  @override
  Future<void> updateMediaItem(MediaItem item) async {
    final current = mediaItem.value;
    final dur = item.duration ?? _pendingDuration ?? current?.duration;

    // 🧸 nunca dejes que duration vuelva a null si ya la tienes
    if (dur != null && item.duration != dur) {
      mediaItem.add(item.copyWith(duration: dur));
    } else {
      mediaItem.add(item);
    }
  }

  void _handleIndex(int? index) {
    if (index == null) return;
    final item = _app.queueItemAt(index);
    if (item == null) return;

    var bg = _app.buildBackgroundItem(item);

    final current = mediaItem.value;
    final dur = bg.duration ?? _pendingDuration ?? current?.duration;
    if (dur != null && bg.duration != dur) {
      bg = bg.copyWith(duration: dur);
    }

    mediaItem.add(bg);
  }

  // -----------------------
  // Ticker (sin updateTime)
  // -----------------------

  void _syncTicker() {
    if (_player.playing) {
      _ticker ??= Timer.periodic(const Duration(milliseconds: 500), (_) {
        final event = _lastEvent;
        if (event == null) return;
        _broadcastState(event, position: _player.position);
      });
    } else {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  // -----------------------
  // PlaybackState broadcasting
  // -----------------------

  void _broadcastState(PlaybackEvent event, {Duration? position}) {
    final playing = _player.playing;
    final hasSkip = _queueLength > 1;

    final controls = <MediaControl>[
      MediaControl.stop, // ❌ X (Stop)
      if (hasSkip || _player.hasPrevious) MediaControl.skipToPrevious,
      if (playing) MediaControl.pause else MediaControl.play,
      if (hasSkip || _player.hasNext) MediaControl.skipToNext,
    ];

    final compact = <int>[];
    for (var i = 0; i < controls.length; i++) {
      final c = controls[i];
      if (c == MediaControl.skipToPrevious ||
          c == MediaControl.play ||
          c == MediaControl.pause ||
          c == MediaControl.skipToNext) {
        compact.add(i);
      }
      if (compact.length == 3) break;
    }

    playbackState.add(
      playbackState.value.copyWith(
        controls: controls,
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: compact,
        processingState: playing
            ? AudioProcessingState.ready
            : _mapProcessingState(_player.processingState),
        playing: playing,
        updatePosition: position ?? _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: event.currentIndex,
      ),
    );
  }

  AudioProcessingState _mapProcessingState(ProcessingState state) {
    switch (state) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
        return AudioProcessingState.loading;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
    }
  }

  // -----------------------
  // Controls (BaseAudioHandler)
  // -----------------------

  @override
  Future<void> play() async {
    await _player.play();
    _syncTicker(); // 🧸
  }

  @override
  Future<void> pause() async {
    await _player.pause();
    _syncTicker(); // 🧸
  }

  @override
  Future<void> stop() async {
    await _player.stop();

    _ticker?.cancel();
    _ticker = null;

    playbackState.add(
      playbackState.value.copyWith(
        controls: const [],
        playing: false,
        processingState: AudioProcessingState.idle,
        updatePosition: Duration.zero,
        bufferedPosition: Duration.zero,
        speed: 1.0,
        queueIndex: null,
      ),
    );

    await super.stop(); // <- esto tumba el servicio y quita la notificación
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() => _player.seekToNext();

  @override
  Future<void> skipToPrevious() => _player.seekToPrevious();
}

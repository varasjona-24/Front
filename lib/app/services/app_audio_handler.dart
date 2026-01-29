import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

import 'audio_service.dart' as app;

class AppAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final app.AudioService _app;
  final AudioPlayer _player;

  StreamSubscription<PlaybackEvent>? _eventSub;
  StreamSubscription<int?>? _indexSub;
  int _queueLength = 0;

  AppAudioHandler(this._app) : _player = _app.player {
    _eventSub = _player.playbackEventStream.listen(_broadcastState);
    _indexSub = _player.currentIndexStream.listen(_handleIndex);
  }

  Future<void> dispose() async {
    await _eventSub?.cancel();
    await _indexSub?.cancel();
  }

  @override
  Future<void> updateQueue(List<MediaItem> queue) async {
    _queueLength = queue.length;
    this.queue.add(queue);
  }

  @override
  Future<void> updateMediaItem(MediaItem mediaItem) async {
    this.mediaItem.add(mediaItem);
  }

  void _handleIndex(int? index) {
    if (index == null) return;
    final item = _app.queueItemAt(index);
    if (item == null) return;
    mediaItem.add(_app.buildBackgroundItem(item));
  }

  void _broadcastState(PlaybackEvent event) {
    final playing = _player.playing;
    final hasSkip = _queueLength > 1;
    final controls = <MediaControl>[
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
        systemActions: const {},
        androidCompactActionIndices: compact,
        processingState: _mapProcessingState(_player.processingState),
        playing: playing,
        updatePosition: Duration.zero,
        bufferedPosition: Duration.zero,
        speed: 0.0,
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

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    await _player.stop();
    return super.stop();
  }

  @override
  Future<void> skipToNext() => _player.seekToNext();

  @override
  Future<void> skipToPrevious() => _player.seekToPrevious();

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    switch (repeatMode) {
      case AudioServiceRepeatMode.none:
        await _player.setLoopMode(LoopMode.off);
        break;
      case AudioServiceRepeatMode.one:
        await _player.setLoopMode(LoopMode.one);
        break;
      case AudioServiceRepeatMode.all:
      case AudioServiceRepeatMode.group:
        await _player.setLoopMode(LoopMode.all);
        break;
    }
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    await _player.setShuffleModeEnabled(
      shuffleMode == AudioServiceShuffleMode.all,
    );
  }
}

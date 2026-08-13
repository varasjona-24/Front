import 'package:audio_service/audio_service.dart';
import 'package:easy_localization/easy_localization.dart'
    hide StringTranslateExtension;
import 'package:get/get.dart';

import '../../Modules/playlists/data/playlist_store.dart';
import '../../Modules/playlists/domain/playlist.dart';
import '../data/local/local_library_store.dart';
import '../models/media_item.dart' as local;
import 'audio_service.dart' as app;

class AppAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final app.AudioService _audio;
  static const _maxChildrenPageSize = 120;
  static const _songsRootId = 'listenfy:auto:songs';
  static const _favoritesRootId = 'listenfy:auto:favorites';
  static const _playlistsRootId = 'listenfy:auto:playlists';
  static const _queueRootId = 'listenfy:auto:queue';
  static const _songPrefix = 'listenfy:auto:song:';
  static const _playlistPrefix = 'listenfy:auto:playlist:';
  static const _queuePrefix = 'listenfy:auto:queue:';
  static MediaControl get closeControl => MediaControl(
    androidIcon: 'drawable/ic_close',
    label: tr('common.close'),
    action: MediaAction.stop,
  );

  AppAudioHandler(this._audio);

  Future<void> updatePlayback({
    required bool playing,
    required bool buffering,
    required bool hasSourceLoaded,
    required Duration position,
    required double speed,
    required int queueIndex,
  }) async {
    final processingState = buffering
        ? AudioProcessingState.buffering
        : (hasSourceLoaded
              ? AudioProcessingState.ready
              : AudioProcessingState.idle);

    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          closeControl,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
          MediaAction.setSpeed,
        },
        androidCompactActionIndices: const [0, 1, 3],
        processingState: processingState,
        playing: playing,
        updatePosition: position,
        queueIndex: queueIndex,
        speed: speed,
      ),
    );
  }

  @override
  Future<void> updateMediaItem(MediaItem mediaItem) async {
    this.mediaItem.add(mediaItem);
  }

  @override
  Future<void> updateQueue(List<MediaItem> queue) async {
    this.queue.add(queue);
  }

  @override
  Future<void> play() async {
    if (_audio.hasSourceLoaded) {
      await _audio.resume();
      return;
    }
    final restored = await _audio.restorePersistedSession(autoPlay: true);
    if (restored) return;
    final items = _audioItems();
    if (items.isNotEmpty) {
      await _audio.playQueueFromExternalRequest(items: items, index: 0);
    }
  }

  @override
  Future<void> pause() => _audio.pause();

  @override
  Future<void> stop() async {
    if (_audio.consumeNextHandlerStopShouldHardStop()) {
      await _audio.stop();
      await super.stop();
    } else {
      _audio.persistCurrentTrackResumePositionNow();
      await _audio.stopAndHidePreservingSession();
      // No llamamos super.stop() aquí para que el servicio pueda volver
      // a publicar notificación al reanudar desde la app.
    }
  }

  @override
  Future<void> seek(Duration position) => _audio.seek(position);

  @override
  Future<void> skipToNext() => _audio.next();

  @override
  Future<void> skipToPrevious() => _audio.previous();

  @override
  Future<void> setSpeed(double speed) => _audio.setSpeed(speed);

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    if (repeatMode == AudioServiceRepeatMode.one) {
      await _audio.setLoopOne();
    } else {
      await _audio.setLoopOff();
    }
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) {
    return _audio.setShuffle(shuffleMode == AudioServiceShuffleMode.all);
  }

  @override
  Future<void> skipToQueueItem(int index) {
    return _audio.playQueueIndexFromExternalRequest(index);
  }

  @override
  Future<void> playMediaItem(MediaItem mediaItem) {
    return playFromMediaId(mediaItem.id, mediaItem.extras);
  }

  @override
  Future<void> playFromMediaId(
    String mediaId, [
    Map<String, dynamic>? extras,
  ]) async {
    final playlistId = _playlistIdFromMediaId(mediaId);
    if (playlistId != null) {
      final playlist = _playlistById(playlistId);
      if (playlist == null) return;
      final items = _itemsForPlaylist(playlist);
      await _audio.playQueueFromExternalRequest(items: items, index: 0);
      return;
    }

    if (mediaId.startsWith(_queuePrefix)) {
      final index = int.tryParse(mediaId.substring(_queuePrefix.length));
      if (index != null) {
        await _audio.playQueueIndexFromExternalRequest(index);
      }
      return;
    }

    final itemId = _songIdFromMediaId(mediaId);
    if (itemId == null) return;
    final items = _audioItems();
    final index = items.indexWhere((item) => _sameItemId(item, itemId));
    if (index < 0) return;
    await _audio.playQueueFromExternalRequest(items: items, index: index);
  }

  @override
  Future<void> playFromSearch(
    String query, [
    Map<String, dynamic>? extras,
  ]) async {
    final results = await search(query, extras);
    final firstPlayable = results.firstWhereOrNull(
      (item) => item.playable == true,
    );
    if (firstPlayable != null) {
      await playMediaItem(firstPlayable);
    }
  }

  @override
  Future<List<MediaItem>> getChildren(
    String parentMediaId, [
    Map<String, dynamic>? options,
  ]) async {
    List<MediaItem> children;
    switch (parentMediaId) {
      case AudioService.browsableRootId:
      case AudioService.recentRootId:
        children = <MediaItem>[
          _folder(
            _songsRootId,
            tr('android_auto.songs'),
            tr('android_auto.songs_subtitle'),
          ),
          _folder(
            _favoritesRootId,
            tr('android_auto.favorites'),
            tr('android_auto.favorites_subtitle'),
          ),
          _folder(
            _playlistsRootId,
            tr('android_auto.playlists'),
            tr('android_auto.playlists_subtitle'),
          ),
          _folder(
            _queueRootId,
            tr('android_auto.current_queue'),
            tr('android_auto.current_queue_subtitle'),
          ),
        ];
        break;
      case _songsRootId:
        children = _audioItems().map(_songItem).toList(growable: false);
        break;
      case _favoritesRootId:
        children = _audioItems()
            .where((item) => item.isFavorite)
            .map(_songItem)
            .toList(growable: false);
        break;
      case _playlistsRootId:
        children = _playlists().map(_playlistItem).toList(growable: false);
        break;
      case _queueRootId:
        children = _audio.queueItems
            .asMap()
            .entries
            .map(
              (entry) =>
                  _songItem(entry.value, mediaId: '$_queuePrefix${entry.key}'),
            )
            .toList(growable: false);
        break;
      default:
        final playlistId = _playlistIdFromMediaId(parentMediaId);
        if (playlistId == null) return const <MediaItem>[];
        final playlist = _playlistById(playlistId);
        if (playlist == null) return const <MediaItem>[];
        children = _itemsForPlaylist(playlist).map(_songItem).toList();
    }
    return _applyChildrenOptions(children, options);
  }

  @override
  Future<MediaItem?> getMediaItem(String mediaId) async {
    if (mediaId == _songsRootId) {
      return _folder(
        _songsRootId,
        tr('android_auto.songs'),
        tr('android_auto.songs_subtitle'),
      );
    }
    if (mediaId == _favoritesRootId) {
      return _folder(
        _favoritesRootId,
        tr('android_auto.favorites'),
        tr('android_auto.favorites_subtitle'),
      );
    }
    if (mediaId == _playlistsRootId) {
      return _folder(
        _playlistsRootId,
        tr('android_auto.playlists'),
        tr('android_auto.playlists_subtitle'),
      );
    }
    if (mediaId == _queueRootId) {
      return _folder(
        _queueRootId,
        tr('android_auto.current_queue'),
        tr('android_auto.current_queue_subtitle'),
      );
    }

    final playlistId = _playlistIdFromMediaId(mediaId);
    if (playlistId != null) {
      final playlist = _playlistById(playlistId);
      return playlist == null ? null : _playlistItem(playlist);
    }

    if (mediaId.startsWith(_queuePrefix)) {
      final index = int.tryParse(mediaId.substring(_queuePrefix.length));
      final items = _audio.queueItems;
      if (index == null || index < 0 || index >= items.length) return null;
      return _songItem(items[index], mediaId: mediaId);
    }

    final songId = _songIdFromMediaId(mediaId);
    if (songId == null) return null;
    final item = _audioItems().firstWhereOrNull(
      (entry) => _sameItemId(entry, songId),
    );
    return item == null ? null : _songItem(item);
  }

  @override
  Future<List<MediaItem>> search(
    String query, [
    Map<String, dynamic>? extras,
  ]) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      return _audioItems().take(25).map(_songItem).toList(growable: false);
    }
    return _audioItems()
        .where((item) {
          return item.title.toLowerCase().contains(q) ||
              item.displaySubtitle.toLowerCase().contains(q);
        })
        .take(25)
        .map(_songItem)
        .toList(growable: false);
  }

  List<MediaItem> _applyChildrenOptions(
    List<MediaItem> children,
    Map<String, dynamic>? options,
  ) {
    if (children.isEmpty) return children;
    final page = _optionInt(
      options,
      'android.media.browse.extra.PAGE',
      fallback: -1,
    );
    final rawPageSize = _optionInt(
      options,
      'android.media.browse.extra.PAGE_SIZE',
      fallback: -1,
    );
    if (page >= 0 && rawPageSize > 0) {
      final pageSize = rawPageSize.clamp(1, _maxChildrenPageSize).toInt();
      final start = page * pageSize;
      if (start >= children.length) return const <MediaItem>[];
      final end = (start + pageSize).clamp(0, children.length).toInt();
      return children.sublist(start, end);
    }
    if (children.length <= _maxChildrenPageSize) return children;
    return children.take(_maxChildrenPageSize).toList(growable: false);
  }

  int _optionInt(
    Map<String, dynamic>? options,
    String key, {
    required int fallback,
  }) {
    final value = options?[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  MediaItem _folder(String id, String title, String subtitle) {
    return MediaItem(
      id: id,
      title: title,
      playable: false,
      displayTitle: title,
      displaySubtitle: subtitle,
      extras: const <String, dynamic>{
        'android.media.browse.CONTENT_STYLE_BROWSABLE_HINT': 1,
      },
    );
  }

  MediaItem _playlistItem(Playlist playlist) {
    final count = playlist.itemIds.length;
    return MediaItem(
      id: '$_playlistPrefix${playlist.id}',
      title: playlist.name,
      playable: true,
      displayTitle: playlist.name,
      displaySubtitle: count == 1
          ? tr('android_auto.track_count_one')
          : tr('android_auto.track_count_many', args: ['$count']),
      extras: const <String, dynamic>{
        'android.media.browse.CONTENT_STYLE_PLAYABLE_HINT': 1,
      },
    );
  }

  MediaItem _songItem(local.MediaItem item, {String? mediaId}) {
    return _audio
        .buildBackgroundItem(item)
        .copyWith(
          id: mediaId ?? '$_songPrefix${item.id}',
          playable: true,
          displayTitle: item.title,
          displaySubtitle: item.displaySubtitle,
          extras: const <String, dynamic>{
            'android.media.browse.CONTENT_STYLE_PLAYABLE_HINT': 1,
          },
        );
  }

  List<local.MediaItem> _audioItems() {
    final store = Get.isRegistered<LocalLibraryStore>()
        ? Get.find<LocalLibraryStore>()
        : null;
    if (store == null) return const <local.MediaItem>[];
    return store
        .readAllSync()
        .where((item) => item.localAudioVariant != null)
        .toList(growable: false);
  }

  List<Playlist> _playlists() {
    final store = Get.isRegistered<PlaylistStore>()
        ? Get.find<PlaylistStore>()
        : null;
    if (store == null) return const <Playlist>[];
    return store
        .readAllSync()
        .where((playlist) {
          return !playlist.isTemporary &&
              _itemsForPlaylist(playlist).isNotEmpty;
        })
        .toList(growable: false);
  }

  Playlist? _playlistById(String id) {
    return _playlists().firstWhereOrNull((playlist) => playlist.id == id);
  }

  List<local.MediaItem> _itemsForPlaylist(Playlist playlist) {
    final all = _audioItems();
    if (all.isEmpty || playlist.itemIds.isEmpty) {
      return const <local.MediaItem>[];
    }
    final byKey = <String, local.MediaItem>{};
    for (final item in all) {
      byKey[item.id] = item;
      final publicId = item.publicId.trim();
      if (publicId.isNotEmpty) byKey[publicId] = item;
    }
    final items = <local.MediaItem>[];
    final seen = <String>{};
    for (final id in playlist.itemIds) {
      final item = byKey[id.trim()];
      if (item == null || !seen.add(item.id)) continue;
      items.add(item);
    }
    return items;
  }

  String? _songIdFromMediaId(String mediaId) {
    if (mediaId.startsWith(_songPrefix)) {
      return mediaId.substring(_songPrefix.length);
    }
    if (mediaId.isNotEmpty && !mediaId.startsWith('listenfy:auto:')) {
      return mediaId;
    }
    return null;
  }

  String? _playlistIdFromMediaId(String mediaId) {
    if (!mediaId.startsWith(_playlistPrefix)) return null;
    return mediaId.substring(_playlistPrefix.length);
  }

  bool _sameItemId(local.MediaItem item, String id) {
    if (item.id == id) return true;
    final publicId = item.publicId.trim();
    return publicId.isNotEmpty && publicId == id;
  }
}

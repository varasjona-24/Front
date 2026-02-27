import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:flutter_listenfy/Modules/player/Video/controller/video_player_controller.dart';
import 'package:flutter_listenfy/Modules/settings/controller/playback_settings_controller.dart';
import 'package:flutter_listenfy/app/data/local/local_library_store.dart';
import 'package:flutter_listenfy/app/models/media_item.dart';
import 'package:flutter_listenfy/app/models/subtitle_track.dart';
import 'package:flutter_listenfy/app/services/video_service.dart';
import 'package:flutter_listenfy/Modules/sources/domain/source_origin.dart';
import 'video_player_controller_test.mocks.dart';

@GenerateNiceMocks([MockSpec<VideoService>(), MockSpec<LocalLibraryStore>()])
MediaItem _itemWithVariants({
  required String id,
  required List<MediaVariant> variants,
}) {
  return MediaItem(
    id: id,
    publicId: 'pub_$id',
    title: 'Title $id',
    subtitle: 'Subtitle $id',
    source: MediaSource.local,
    variants: variants,
    subtitles: const [SubtitleTrack(language: 'es', url: 'https://sub/es.vtt')],
    origin: SourceOrigin.youtube,
  );
}

MediaVariant _variant({
  required MediaVariantKind kind,
  required String format,
  String fileName = 'file',
  String? localPath,
}) {
  return MediaVariant(
    kind: kind,
    format: format,
    fileName: fileName,
    localPath: localPath,
    createdAt: 1,
  );
}

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.path);

  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockVideoService videoService;
  late MockLocalLibraryStore store;
  late Rx<Duration> positionRx;
  late Rx<Duration> durationRx;
  late RxBool isPlayingRx;
  late Rx<VideoPlaybackState> stateRx;
  late RxInt completedTickRx;
  late Rxn<String> playbackErrorRx;
  late Rxn<MediaItem> currentItemRx;
  late Rxn<MediaVariant> currentVariantRx;
  late RxDouble speedRx;

  setUpAll(() async {
    final path = Directory.systemTemp.createTempSync('listenfy_test_').path;
    PathProviderPlatform.instance = _FakePathProviderPlatform(path);
    await GetStorage.init();
  });

  setUp(() async {
    Get.testMode = true;
    Get.reset();
    await GetStorage().erase();

    videoService = MockVideoService();
    store = MockLocalLibraryStore();

    positionRx = Duration.zero.obs;
    durationRx = const Duration(seconds: 180).obs;
    isPlayingRx = false.obs;
    stateRx = VideoPlaybackState.stopped.obs;
    completedTickRx = 0.obs;
    playbackErrorRx = Rxn<String>();
    currentItemRx = Rxn<MediaItem>();
    currentVariantRx = Rxn<MediaVariant>();
    speedRx = 1.0.obs;

    when(videoService.position).thenReturn(positionRx);
    when(videoService.duration).thenReturn(durationRx);
    when(videoService.isPlaying).thenReturn(isPlayingRx);
    when(videoService.state).thenReturn(stateRx);
    when(videoService.completedTick).thenReturn(completedTickRx);
    when(videoService.playbackError).thenReturn(playbackErrorRx);
    when(videoService.currentItem).thenReturn(currentItemRx);
    when(videoService.currentVariant).thenReturn(currentVariantRx);
    when(videoService.speed).thenReturn(speedRx);
    when(videoService.playerController).thenReturn(null);
    when(videoService.play(any, any)).thenAnswer((invocation) async {
      currentItemRx.value = invocation.positionalArguments[0] as MediaItem;
      currentVariantRx.value =
          invocation.positionalArguments[1] as MediaVariant;
      stateRx.value = VideoPlaybackState.playing;
      isPlayingRx.value = true;
    });
    when(videoService.seek(any)).thenAnswer((invocation) async {
      positionRx.value = invocation.positionalArguments[0] as Duration;
    });
    when(videoService.toggle()).thenAnswer((_) async {});
    when(videoService.stop()).thenAnswer((_) async {});
    when(videoService.loadSubtitle(any)).thenAnswer((_) async {});

    when(store.readAll()).thenAnswer((_) async => <MediaItem>[]);
    when(store.upsert(any)).thenAnswer((_) async {});
    when(store.remove(any)).thenAnswer((_) async {});

    Get.put<LocalLibraryStore>(store);
    Get.put<PlaybackSettingsController>(PlaybackSettingsController());
  });

  tearDown(() {
    Get.reset();
  });

  test(
    'currentVideoVariant prioriza video local, luego mp4 remoto, luego cualquier video',
    () {
      final withLocal = _itemWithVariants(
        id: '1',
        variants: [
          _variant(
            kind: MediaVariantKind.video,
            format: 'mkv',
            fileName: 'a',
            localPath: '/tmp/a.mkv',
          ),
          _variant(kind: MediaVariantKind.video, format: 'mp4', fileName: 'b'),
        ],
      );
      final c1 = VideoPlayerController(
        videoService: videoService,
        queue: [withLocal],
        initialIndex: 0,
      );
      expect(c1.currentVideoVariant?.localPath, equals('/tmp/a.mkv'));

      final withMp4 = _itemWithVariants(
        id: '2',
        variants: [
          _variant(
            kind: MediaVariantKind.video,
            format: 'webm',
            fileName: 'v.webm',
          ),
          _variant(
            kind: MediaVariantKind.video,
            format: 'mp4',
            fileName: 'v.mp4',
          ),
        ],
      );
      final c2 = VideoPlayerController(
        videoService: videoService,
        queue: [withMp4],
        initialIndex: 0,
      );
      expect(c2.currentVideoVariant?.format, equals('mp4'));

      final anyVideo = _itemWithVariants(
        id: '3',
        variants: [
          _variant(
            kind: MediaVariantKind.audio,
            format: 'mp3',
            fileName: 'a.mp3',
          ),
          _variant(
            kind: MediaVariantKind.video,
            format: 'avi',
            fileName: 'v.avi',
          ),
        ],
      );
      final c3 = VideoPlayerController(
        videoService: videoService,
        queue: [anyVideo],
        initialIndex: 0,
      );
      expect(c3.currentVideoVariant?.format, equals('avi'));
    },
  );

  test('persist queue y position en GetStorage', () async {
    final item = _itemWithVariants(
      id: 'persist',
      variants: [
        _variant(
          kind: MediaVariantKind.video,
          format: 'mp4',
          fileName: 'v.mp4',
        ),
      ],
    );

    final controller = VideoPlayerController(
      videoService: videoService,
      queue: [item],
      initialIndex: 0,
    );
    controller.onInit();

    final box = GetStorage();
    final persistedQueue = box.read<List>('video_queue_items');
    final persistedIndex = box.read<int>('video_queue_index');
    expect(persistedQueue, isNotNull);
    expect(persistedQueue!.length, equals(1));
    expect(persistedIndex, equals(0));

    positionRx.value = const Duration(seconds: 5);
    await Future<void>.delayed(const Duration(milliseconds: 2300));
    final resumeMap = box.read<Map>('video_resume_positions');
    expect(resumeMap, isNotNull);
    expect(resumeMap!['pub_persist'], equals(5000));
  });

  test('next y previous respetan límites de cola', () async {
    final queue = [
      _itemWithVariants(
        id: 'a',
        variants: [
          _variant(
            kind: MediaVariantKind.video,
            format: 'mp4',
            fileName: 'a.mp4',
          ),
        ],
      ),
      _itemWithVariants(
        id: 'b',
        variants: [
          _variant(
            kind: MediaVariantKind.video,
            format: 'mp4',
            fileName: 'b.mp4',
          ),
        ],
      ),
    ];

    final controller = VideoPlayerController(
      videoService: videoService,
      queue: queue,
      initialIndex: 0,
    );
    controller.onInit();

    await controller.previous();
    expect(controller.currentIndex.value, equals(0));

    await controller.next();
    expect(controller.currentIndex.value, equals(1));

    await controller.next();
    expect(controller.currentIndex.value, equals(1));

    await controller.previous();
    expect(controller.currentIndex.value, equals(0));
  });

  test('loadSubtitle delega en VideoService', () async {
    final controller = VideoPlayerController(
      videoService: videoService,
      queue: const [],
      initialIndex: 0,
    );

    const track = SubtitleTrack(language: 'en', url: 'https://sub/en.vtt');
    await controller.loadSubtitle(track);

    expect(controller.currentSubtitle.value, equals(track));
    verify(videoService.loadSubtitle(track)).called(1);
  });
}

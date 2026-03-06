import 'dart:io';

import 'package:get/get.dart';

import '../../../app/data/local/local_library_store.dart';
import '../../../app/data/repo/media_repository.dart';
import '../../../app/models/media_item.dart';
import '../../../app/routes/app_routes.dart';
import '../domain/recommendation_models.dart';
import '../service/local_recommendation_service.dart';

enum HomeMode { audio, video }

class RecommendationCollection {
  const RecommendationCollection({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.items,
  });

  final String id;
  final String title;
  final String subtitle;
  final List<MediaItem> items;
}

class HomeController extends GetxController {
  final MediaRepository _repo = Get.find<MediaRepository>();
  final LocalLibraryStore _store = Get.find<LocalLibraryStore>();
  final LocalRecommendationService _recommendationService =
      Get.find<LocalRecommendationService>();

  final Rx<HomeMode> mode = HomeMode.audio.obs;
  final RxBool isLoading = false.obs;

  final RxList<MediaItem> recentlyPlayed = <MediaItem>[].obs;
  final RxList<MediaItem> latestDownloads = <MediaItem>[].obs;
  final RxList<MediaItem> favorites = <MediaItem>[].obs;
  final RxList<MediaItem> mostPlayed = <MediaItem>[].obs;
  final RxList<MediaItem> featured = <MediaItem>[].obs;
  final RxList<MediaItem> fullRecentlyPlayed = <MediaItem>[].obs;
  final RxList<MediaItem> fullFavorites = <MediaItem>[].obs;
  final RxList<MediaItem> fullMostPlayed = <MediaItem>[].obs;
  final RxList<MediaItem> fullLatestDownloads = <MediaItem>[].obs;
  final RxList<MediaItem> fullFeatured = <MediaItem>[].obs;
  final RxList<MediaItem> recommended = <MediaItem>[].obs;
  final RxList<MediaItem> fullRecommended = <MediaItem>[].obs;
  final RxBool isRecommendationsLoading = false.obs;
  final RxBool canRecommendationRefresh = true.obs;
  final RxnString recommendationRefreshHint = RxnString();
  final RxMap<String, String> recommendationReasonsById =
      <String, String>{}.obs;
  final RxList<RecommendationCollection> recommendationCollections =
      <RecommendationCollection>[].obs;

  final RxList<MediaItem> _allItems = <MediaItem>[].obs;

  @override
  void onInit() {
    super.onInit();
    loadHome();
  }

  Future<void> loadHome() async {
    isLoading.value = true;
    try {
      final items = await _repo.getLibrary();
      _allItems.assignAll(items);
      _splitHomeSections(_allItems);
      await _loadRecommendationsForCurrentMode();
    } catch (e) {
      print('Error loading home: $e');
    } finally {
      isLoading.value = false;
    }
  }

  void _splitHomeSections(List<MediaItem> items) {
    final isAudioMode = mode.value == HomeMode.audio;

    bool matchesMode(MediaItem item) =>
        isAudioMode ? item.hasAudioLocal : item.hasVideoLocal;

    final filtered = items.where(matchesMode).toList();

    final recentAll = filtered.where((e) => (e.lastPlayedAt ?? 0) > 0).toList()
      ..sort((a, b) => (b.lastPlayedAt ?? 0).compareTo(a.lastPlayedAt ?? 0));
    fullRecentlyPlayed.assignAll(recentAll);
    recentlyPlayed.assignAll(recentAll.take(10));

    final downloadsAll = filtered.where((e) => e.isOfflineStored).toList()
      ..sort(
        (a, b) =>
            _latestVariantCreatedAt(b).compareTo(_latestVariantCreatedAt(a)),
      );
    fullLatestDownloads.assignAll(downloadsAll);
    latestDownloads.assignAll(downloadsAll.take(10));

    final favoritesAll = filtered.where((e) => e.isFavorite).toList();
    fullFavorites.assignAll(favoritesAll);
    favorites.assignAll(favoritesAll.take(10));

    final mostAll = filtered.where((e) => e.playCount > 0).toList()
      ..sort((a, b) => b.playCount.compareTo(a.playCount));
    fullMostPlayed.assignAll(mostAll);
    mostPlayed.assignAll(mostAll.take(12));

    fullFeatured.assignAll(
      _buildFeatured(
        favorites: favoritesAll,
        mostPlayed: mostAll,
        recent: recentAll,
        maxItems: filtered.length,
      ),
    );

    featured.assignAll(
      _buildFeatured(
        favorites: favoritesAll,
        mostPlayed: mostAll,
        recent: recentAll,
        maxItems: 12,
      ),
    );
  }

  List<MediaItem> _buildFeatured({
    required List<MediaItem> favorites,
    required List<MediaItem> mostPlayed,
    required List<MediaItem> recent,
    int maxItems = 12,
  }) {
    final result = <MediaItem>[];
    final seen = <String>{};

    void addItems(List<MediaItem> items, int limit) {
      var added = 0;
      for (final item in items) {
        if (added >= limit || result.length >= maxItems) return;
        final key = item.publicId.trim().isNotEmpty
            ? item.publicId.trim()
            : item.id.trim();
        if (seen.contains(key)) continue;
        result.add(item);
        seen.add(key);
        added++;
      }
    }

    final favLimit = (maxItems * 0.4).round();
    final mostLimit = (maxItems * 0.3).round();
    final recentLimit = maxItems - favLimit - mostLimit;

    addItems(favorites, favLimit);
    addItems(mostPlayed, mostLimit);
    addItems(recent, recentLimit);

    if (result.length < maxItems) {
      addItems(favorites, maxItems - result.length);
    }
    if (result.length < maxItems) {
      addItems(mostPlayed, maxItems - result.length);
    }
    if (result.length < maxItems) {
      addItems(recent, maxItems - result.length);
    }

    return result;
  }

  int _latestVariantCreatedAt(MediaItem item) {
    var maxTs = 0;
    for (final v in item.variants) {
      if (v.localPath?.trim().isNotEmpty != true) continue;
      if (v.createdAt > maxTs) maxTs = v.createdAt;
    }
    return maxTs;
  }

  void toggleMode() {
    mode.value = mode.value == HomeMode.audio ? HomeMode.video : HomeMode.audio;
    _splitHomeSections(_allItems);
    _loadRecommendationsForCurrentMode();
  }

  Future<void> refreshRecommendations() async {
    final recommendationMode = _currentRecommendationMode();
    if (!_recommendationService.canManualRefreshToday(
      mode: recommendationMode,
    )) {
      final hint =
          _recommendationService.nextRefreshHint(mode: recommendationMode) ??
          'Ya usaste el refresh manual de hoy';
      recommendationRefreshHint.value = hint;
      canRecommendationRefresh.value = false;
      Get.snackbar('Para ti hoy', hint, snackPosition: SnackPosition.BOTTOM);
      return;
    }

    isRecommendationsLoading.value = true;
    try {
      final set = await _recommendationService.refreshManually(
        mode: recommendationMode,
      );
      _applyRecommendationSet(set);
    } catch (e) {
      print('Error refreshing recommendations: $e');
      Get.snackbar(
        'Para ti hoy',
        'No se pudieron actualizar las recomendaciones',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      _syncRecommendationRefreshAvailability();
      isRecommendationsLoading.value = false;
    }
  }

  String? recommendationHintFor(MediaItem item, int index) {
    final byId = recommendationReasonsById[item.id];
    if (byId != null && byId.trim().isNotEmpty) return byId;
    final publicId = item.publicId.trim();
    if (publicId.isNotEmpty) {
      final byPublic = recommendationReasonsById['p:$publicId'];
      if (byPublic != null && byPublic.trim().isNotEmpty) return byPublic;
    }
    return 'Por tu actividad reciente';
  }

  void onSearch() {
    Get.toNamed(AppRoutes.homeSearch);
  }

  Future<void> openMedia(
    MediaItem item,
    int index,
    List<MediaItem> list,
  ) async {
    final route = mode.value == HomeMode.audio
        ? AppRoutes.audioPlayer
        : AppRoutes.videoPlayer;

    await Get.toNamed(route, arguments: {'queue': list, 'index': index});
    await loadHome();
  }

  Future<void> deleteLocalItem(MediaItem item) async {
    try {
      print(
        'Home delete requested id=${item.id} variants=${item.variants.length}',
      );

      _allItems.removeWhere((e) => e.id == item.id);
      recentlyPlayed.removeWhere((e) => e.id == item.id);
      latestDownloads.removeWhere((e) => e.id == item.id);
      favorites.removeWhere((e) => e.id == item.id);

      final all = await _store.readAll();
      final related = all.where((e) {
        if (e.id == item.id) return true;
        final pid = item.publicId.trim();
        return pid.isNotEmpty && e.publicId.trim() == pid;
      }).toList();

      if (related.isEmpty) {
        await _deleteItemFiles(item);
        await _store.remove(item.id);
      } else {
        for (final entry in related) {
          await _deleteItemFiles(entry);
          await _store.remove(entry.id);
        }
      }

      await loadHome();
    } catch (e) {
      print('Error deleting local item: $e');
      Get.snackbar(
        'Downloads',
        'Error al eliminar',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> toggleFavorite(MediaItem item) async {
    try {
      final next = !item.isFavorite;
      final all = await _store.readAll();
      final pid = item.publicId.trim();

      final matches = all.where((e) {
        if (e.id == item.id) return true;
        return pid.isNotEmpty && e.publicId.trim() == pid;
      }).toList();

      if (matches.isEmpty) {
        await _store.upsert(item.copyWith(isFavorite: next));
      } else {
        for (final entry in matches) {
          await _store.upsert(entry.copyWith(isFavorite: next));
        }
      }

      await loadHome();
    } catch (e) {
      print('Error toggling favorite: $e');
      Get.snackbar(
        'Favoritos',
        'No se pudo actualizar',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> _deleteItemFiles(MediaItem item) async {
    for (final v in item.variants) {
      await _deleteFile(v.localPath);
    }
    await _deleteFile(item.thumbnailLocalPath);
  }

  Future<void> _deleteFile(String? path) async {
    final pth = path?.trim();
    if (pth == null || pth.isEmpty) return;
    final f = File(pth);
    if (await f.exists()) await f.delete();
  }

  void goToPlaylists() => Get.toNamed(AppRoutes.playlists);
  void goToArtists() => Get.toNamed(AppRoutes.artists);
  void goToDownloads() => Get.toNamed(AppRoutes.downloads);

  void goToSources() async {
    await Get.toNamed(AppRoutes.sources);
    loadHome();
  }

  void goToSettings() => Get.toNamed(AppRoutes.settings);

  void enterHome() => Get.offAllNamed(AppRoutes.home);

  List<MediaItem> get allItems => List<MediaItem>.from(_allItems);

  Future<void> _loadRecommendationsForCurrentMode() async {
    if (_allItems.isEmpty) {
      recommended.clear();
      fullRecommended.clear();
      recommendationReasonsById.clear();
      recommendationCollections.clear();
      _syncRecommendationRefreshAvailability();
      return;
    }

    isRecommendationsLoading.value = true;
    try {
      final set = await _recommendationService.getOrBuildForDay(
        mode: _currentRecommendationMode(),
      );
      _applyRecommendationSet(set);
    } catch (e) {
      print('Error loading recommendations: $e');
    } finally {
      _syncRecommendationRefreshAvailability();
      isRecommendationsLoading.value = false;
    }
  }

  void _applyRecommendationSet(RecommendationDailySet set) {
    final isAudioMode = mode.value == HomeMode.audio;
    bool matchesMode(MediaItem item) =>
        isAudioMode ? item.hasAudioLocal : item.hasVideoLocal;

    final filtered = _allItems.where(matchesMode).toList();
    final byPublicId = <String, MediaItem>{};
    final byId = <String, MediaItem>{};
    for (final item in filtered) {
      final pid = item.publicId.trim();
      final id = item.id.trim();
      if (pid.isNotEmpty) {
        byPublicId.putIfAbsent(pid, () => item);
      }
      if (id.isNotEmpty) {
        byId.putIfAbsent(id, () => item);
      }
    }

    final seen = <String>{};
    final resolved = <MediaItem>[];
    final reasons = <String, String>{};
    final resolvedEntries = <_ResolvedRecommendation>[];

    for (final entry in set.entries) {
      final item =
          byPublicId[entry.publicId.trim()] ?? byId[entry.itemId.trim()];
      if (item == null) continue;
      final stableKey = _itemStableKey(item);
      if (seen.contains(stableKey)) continue;
      seen.add(stableKey);

      resolved.add(item);
      resolvedEntries.add(_ResolvedRecommendation(item: item, entry: entry));

      final reason = entry.reasonText.trim().isEmpty
          ? 'Por tu actividad reciente'
          : entry.reasonText.trim();
      reasons[item.id] = reason;
      final pid = item.publicId.trim();
      if (pid.isNotEmpty) {
        reasons['p:$pid'] = reason;
      }

      if (resolved.length >= 24) break;
    }

    fullRecommended.assignAll(resolved.take(24));
    recommended.assignAll(resolved.take(12));
    recommendationReasonsById.assignAll(reasons);
    recommendationCollections.assignAll(
      _buildRecommendationCollections(resolvedEntries),
    );
  }

  void _syncRecommendationRefreshAvailability() {
    final mode = _currentRecommendationMode();
    canRecommendationRefresh.value = _recommendationService
        .canManualRefreshToday(mode: mode);
    recommendationRefreshHint.value = _recommendationService.nextRefreshHint(
      mode: mode,
    );
  }

  RecommendationMode _currentRecommendationMode() {
    return mode.value == HomeMode.audio
        ? RecommendationMode.audio
        : RecommendationMode.video;
  }

  String _itemStableKey(MediaItem item) {
    final publicId = item.publicId.trim();
    if (publicId.isNotEmpty) return 'p:$publicId';
    return 'i:${item.id.trim()}';
  }

  List<RecommendationCollection> _buildRecommendationCollections(
    List<_ResolvedRecommendation> entries,
  ) {
    if (entries.isEmpty) return const <RecommendationCollection>[];

    final templates = <_RecommendationCollectionTemplate>[
      const _RecommendationCollectionTemplate(
        id: 'semantic',
        title: 'Escena que te gusta',
        subtitle: 'Por género y región',
        reasonCodes: {
          RecommendationReasonCode.genreMatch,
          RecommendationReasonCode.regionMatch,
        },
      ),
      const _RecommendationCollectionTemplate(
        id: 'affinity',
        title: 'Basado en tus hábitos',
        subtitle: 'Favoritos y escuchas recientes',
        reasonCodes: {
          RecommendationReasonCode.favoriteAffinity,
          RecommendationReasonCode.recentAffinity,
          RecommendationReasonCode.artistAffinity,
        },
      ),
      const _RecommendationCollectionTemplate(
        id: 'fresh',
        title: 'Para descubrir',
        subtitle: 'Picks frescos del día',
        reasonCodes: {
          RecommendationReasonCode.freshPick,
          RecommendationReasonCode.coldStart,
        },
      ),
      const _RecommendationCollectionTemplate(
        id: 'origin',
        title: 'Origen que repites',
        subtitle: 'Fuentes que más usas',
        reasonCodes: {RecommendationReasonCode.originAffinity},
      ),
    ];

    final targetCollections = entries.length >= 20
        ? 4
        : (entries.length >= 14 ? 3 : (entries.length >= 8 ? 2 : 1));
    final used = <String>{};
    final collections = <RecommendationCollection>[];

    List<_ResolvedRecommendation> available() => entries.where((entry) {
      return !used.contains(_itemStableKey(entry.item));
    }).toList();

    List<_ResolvedRecommendation> pickForTemplate(
      _RecommendationCollectionTemplate template,
    ) {
      final free = available();
      final preferred = free
          .where(
            (entry) => template.reasonCodes.contains(entry.entry.reasonCode),
          )
          .toList();

      final picks = <_ResolvedRecommendation>[];
      for (final entry in preferred) {
        if (picks.length >= 6) break;
        picks.add(entry);
      }

      if (picks.length < 3) {
        for (final entry in free) {
          if (picks.length >= 6) break;
          if (picks.contains(entry)) continue;
          picks.add(entry);
        }
      }

      return picks;
    }

    for (final template in templates) {
      if (collections.length >= targetCollections) break;
      final picks = pickForTemplate(template);
      if (picks.length < 3) continue;

      for (final pick in picks) {
        used.add(_itemStableKey(pick.item));
      }

      collections.add(
        RecommendationCollection(
          id: '${template.id}-${collections.length + 1}',
          title: template.title,
          subtitle: template.subtitle,
          items: picks.map((e) => e.item).toList(growable: false),
        ),
      );
    }

    while (collections.length < 2 && available().length >= 3) {
      final free = available();
      final chunk = free.take(6).toList();
      for (final entry in chunk) {
        used.add(_itemStableKey(entry.item));
      }
      collections.add(
        RecommendationCollection(
          id: 'mix-${collections.length + 1}',
          title: 'Mix diario ${collections.length + 1}',
          subtitle: 'Selección variada de hoy',
          items: chunk.map((e) => e.item).toList(growable: false),
        ),
      );
    }

    if (collections.isEmpty) {
      final fallback = entries
          .take(6)
          .map((e) => e.item)
          .toList(growable: false);
      collections.add(
        RecommendationCollection(
          id: 'mix-1',
          title: 'Mix diario',
          subtitle: 'Selección recomendada',
          items: fallback,
        ),
      );
    }

    return collections.take(4).toList(growable: false);
  }
}

class _ResolvedRecommendation {
  const _ResolvedRecommendation({required this.item, required this.entry});

  final MediaItem item;
  final RecommendationEntry entry;
}

class _RecommendationCollectionTemplate {
  const _RecommendationCollectionTemplate({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.reasonCodes,
  });

  final String id;
  final String title;
  final String subtitle;
  final Set<RecommendationReasonCode> reasonCodes;
}

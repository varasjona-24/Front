import 'dart:io';

import 'package:get/get.dart';

import '../../../app/data/local/local_library_store.dart';
import '../../../app/data/repo/media_repository.dart';
import '../../../app/models/media_item.dart';
import '../../../app/routes/app_routes.dart';
import '../view/app_songs_search_page.dart';

enum HomeMode { audio, video }

class HomeController extends GetxController {
  final MediaRepository _repo = Get.find<MediaRepository>();
  final LocalLibraryStore _store = Get.find<LocalLibraryStore>();

  final Rx<HomeMode> mode = HomeMode.audio.obs;
  final RxBool isLoading = false.obs;

  final RxList<MediaItem> recentlyPlayed = <MediaItem>[].obs;
  final RxList<MediaItem> latestDownloads = <MediaItem>[].obs;
  final RxList<MediaItem> favorites = <MediaItem>[].obs;
  final RxList<MediaItem> mostPlayed = <MediaItem>[].obs;
  final RxList<MediaItem> featured = <MediaItem>[].obs;
  final RxList<MediaItem> fullLatestDownloads = <MediaItem>[].obs;
  final RxList<MediaItem> fullFeatured = <MediaItem>[].obs;

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

    final recentAll = filtered
        .where((e) => (e.lastPlayedAt ?? 0) > 0)
        .toList()
      ..sort(
        (a, b) =>
            (b.lastPlayedAt ?? 0).compareTo(a.lastPlayedAt ?? 0),
      );
    recentlyPlayed.assignAll(recentAll.take(10));

    final downloadsAll = filtered
        .where((e) => e.isOfflineStored)
        .toList()
      ..sort(
        (a, b) => _latestVariantCreatedAt(b)
            .compareTo(_latestVariantCreatedAt(a)),
      );
    fullLatestDownloads.assignAll(downloadsAll);
    latestDownloads.assignAll(downloadsAll.take(10));

    final favoritesAll = filtered.where((e) => e.isFavorite).toList();
    favorites.assignAll(favoritesAll.take(10));

    final mostAll = filtered
        .where((e) => e.playCount > 0)
        .toList()
      ..sort((a, b) => b.playCount.compareTo(a.playCount));
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
  }

  void onSearch() {
    Get.to(() => const AppSongsSearchPage());
  }

  void openMedia(MediaItem item, int index, List<MediaItem> list) {
    final route = mode.value == HomeMode.audio
        ? AppRoutes.audioPlayer
        : AppRoutes.videoPlayer;

    Get.toNamed(route, arguments: {'queue': list, 'index': index});
  }

  Future<void> deleteLocalItem(MediaItem item) async {
    try {
      print('Home delete requested id=${item.id} variants=${item.variants.length}');

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
}

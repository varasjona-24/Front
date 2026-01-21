import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/data/local/local_library_store.dart';
import '../../../app/data/repo/media_repository.dart';
import '../../../app/models/media_item.dart';
import '../../../app/routes/app_routes.dart';
import '../view/media_search_delegate.dart';

enum HomeMode { audio, video }

class HomeController extends GetxController {
  final MediaRepository _repo = Get.find<MediaRepository>();
  final LocalLibraryStore _store = Get.find<LocalLibraryStore>();

  final Rx<HomeMode> mode = HomeMode.audio.obs;
  final RxBool isLoading = false.obs;

  final RxList<MediaItem> recentlyPlayed = <MediaItem>[].obs;
  final RxList<MediaItem> latestDownloads = <MediaItem>[].obs;
  final RxList<MediaItem> favorites = <MediaItem>[].obs;

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

    recentlyPlayed.assignAll(filtered.take(10));
    latestDownloads.assignAll(
      filtered.where((e) => e.source == MediaSource.local).take(10),
    );
    favorites.assignAll(
      filtered.where((e) => e.source == MediaSource.youtube).take(10),
    );
  }

  void toggleMode() {
    mode.value = mode.value == HomeMode.audio ? HomeMode.video : HomeMode.audio;
    _splitHomeSections(_allItems);
  }

  void onSearch() {
    final ctx = Get.context;
    if (ctx == null) return;
    showSearch(
      context: ctx,
      delegate: MediaSearchDelegate(this),
    );
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

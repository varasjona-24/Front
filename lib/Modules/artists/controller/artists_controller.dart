import 'dart:io';
import 'dart:math';

import 'package:get/get.dart';

import '../../../app/data/local/local_library_store.dart';
import '../../../app/data/repo/media_repository.dart';
import '../../../app/models/media_item.dart';
import '../data/artist_store.dart';
import '../domain/artist_profile.dart';

enum ArtistSort { name, count, random }

class ArtistGroup {
  final String key;
  final String name;
  final int count;
  final String? thumbnail;
  final String? thumbnailLocalPath;
  final List<MediaItem> items;

  ArtistGroup({
    required this.key,
    required this.name,
    required this.count,
    required this.items,
    this.thumbnail,
    this.thumbnailLocalPath,
  });
}

class ArtistsController extends GetxController {
  final MediaRepository _repo = Get.find<MediaRepository>();
  final LocalLibraryStore _store = Get.find<LocalLibraryStore>();
  final ArtistStore _artistStore = Get.find<ArtistStore>();

  final RxList<ArtistGroup> artists = <ArtistGroup>[].obs;
  final RxList<ArtistGroup> recentArtists = <ArtistGroup>[].obs;
  final RxBool isLoading = false.obs;
  final RxString query = ''.obs;
  final Rx<ArtistSort> sort = ArtistSort.name.obs;
  final RxBool sortAscending = true.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    try {
      final items = (await _repo.getLibrary())
          .where(
            (item) => item.variants.any(
              (v) => v.kind == MediaVariantKind.audio,
            ),
          )
          .toList();
      final profiles = await _artistStore.readAll();
      final profilesByKey = {
        for (final p in profiles) p.key: p,
      };

      final Map<String, List<MediaItem>> grouped = {};
      for (final item in items) {
        final raw = item.subtitle.trim();
        final key = ArtistProfile.normalizeKey(raw);
        grouped.putIfAbsent(key, () => []).add(item);
      }

      final list = <ArtistGroup>[];
      for (final entry in grouped.entries) {
        final key = entry.key;
        final itemsForArtist = entry.value;
        final profile = profilesByKey[key];
        final displayName = (profile?.displayName.trim().isNotEmpty == true)
            ? profile!.displayName
            : (itemsForArtist.first.subtitle.trim().isNotEmpty
                  ? itemsForArtist.first.subtitle.trim()
                  : 'Artista desconocido');

        final fallbackThumb = itemsForArtist.first.effectiveThumbnail;

        list.add(
          ArtistGroup(
            key: key,
            name: displayName,
            count: itemsForArtist.length,
            items: itemsForArtist,
            thumbnail: profile?.thumbnail ?? fallbackThumb,
            thumbnailLocalPath: profile?.thumbnailLocalPath,
          ),
        );
      }

      artists.assignAll(_applySort(list));
      _refreshRecentArtists(list);
    } catch (e) {
      print('Error loading artists: $e');
    } finally {
      isLoading.value = false;
    }
  }

  List<ArtistGroup> get filtered {
    final q = query.value.trim().toLowerCase();
    if (q.isEmpty) return artists.toList();
    return artists
        .where((a) => a.name.toLowerCase().contains(q))
        .toList();
  }

  void setQuery(String value) {
    query.value = value;
  }

  void setSort(ArtistSort value) {
    sort.value = value;
    artists.assignAll(_applySort(artists));
    _refreshRecentArtists(artists);
  }

  void setSortAscending(bool value) {
    sortAscending.value = value;
    artists.assignAll(_applySort(artists));
    _refreshRecentArtists(artists);
  }

  List<ArtistGroup> _applySort(List<ArtistGroup> input) {
    final list = List<ArtistGroup>.from(input);
    switch (sort.value) {
      case ArtistSort.count:
        list.sort((a, b) => a.count.compareTo(b.count));
        break;
      case ArtistSort.random:
        list.shuffle(Random());
        break;
      case ArtistSort.name:
        list.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
    }
    if (sort.value != ArtistSort.random && !sortAscending.value) {
      return list.reversed.toList();
    }
    return list;
  }

  void _refreshRecentArtists(List<ArtistGroup> source) {
    final recent = source
        .map(
          (artist) => MapEntry(
            artist,
            artist.items
                .map((e) => e.lastPlayedAt ?? 0)
                .fold<int>(0, (a, b) => a > b ? a : b),
          ),
        )
        .where((entry) => entry.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    recentArtists.assignAll(
      recent.map((e) => e.key).take(8),
    );
  }

  Future<void> updateArtist({
    required String key,
    required String newName,
    String? thumbnail,
    String? thumbnailLocalPath,
  }) async {
    final normalizedNewKey = ArtistProfile.normalizeKey(newName);
    final profiles = await _artistStore.readAll();
    final existing = profiles.where((p) => p.key == key).toList();

    if (key != normalizedNewKey) {
      await _artistStore.remove(key);
    }

    final profile = ArtistProfile(
      key: normalizedNewKey,
      displayName: newName.trim().isEmpty ? 'Artista desconocido' : newName.trim(),
      thumbnail: thumbnail,
      thumbnailLocalPath: thumbnailLocalPath,
    );
    await _artistStore.upsert(profile);

    if (key != normalizedNewKey || newName.trim().isNotEmpty) {
      final all = await _store.readAll();
      for (final item in all) {
        final itemKey = ArtistProfile.normalizeKey(item.subtitle);
        if (itemKey != key) continue;
        final updated = item.copyWith(subtitle: profile.displayName);
        await _store.upsert(updated);
      }
    }

    if (existing.isEmpty && key != normalizedNewKey) {
      final all = await _store.readAll();
      for (final item in all) {
        final itemKey = ArtistProfile.normalizeKey(item.subtitle);
        if (itemKey == key) {
          final updated = item.copyWith(subtitle: profile.displayName);
          await _store.upsert(updated);
        }
      }
    }

    await load();
  }

  Future<void> removeLocalArtist(ArtistGroup artist) async {
    for (final item in artist.items) {
      for (final v in item.variants) {
        await _deleteFile(v.localPath);
      }
      await _deleteFile(item.thumbnailLocalPath);
      await _store.remove(item.id);
    }
    await _artistStore.remove(artist.key);
    await load();
  }

  Future<void> _deleteFile(String? path) async {
    final pth = path?.trim();
    if (pth == null || pth.isEmpty) return;
    final f = File(pth);
    if (await f.exists()) await f.delete();
  }
}

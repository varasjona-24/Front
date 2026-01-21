import 'package:get_storage/get_storage.dart';

import '../domain/artist_profile.dart';

class ArtistStore {
  ArtistStore(this._box);

  final GetStorage _box;
  static const _key = 'artist_profiles';

  Future<List<ArtistProfile>> readAll() async {
    final raw = _box.read<List>(_key) ?? <dynamic>[];
    return raw
        .whereType<Map>()
        .map((m) => ArtistProfile.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  Future<ArtistProfile?> getByKey(String key) async {
    final list = await readAll();
    for (final profile in list) {
      if (profile.key == key) return profile;
    }
    return null;
  }

  Future<void> upsert(ArtistProfile profile) async {
    final list = await readAll();
    final idx = list.indexWhere((e) => e.key == profile.key);
    if (idx == -1) {
      list.insert(0, profile);
    } else {
      list[idx] = profile;
    }
    await _box.write(_key, list.map((e) => e.toJson()).toList());
  }

  Future<void> remove(String key) async {
    final list = await readAll();
    list.removeWhere((e) => e.key == key);
    await _box.write(_key, list.map((e) => e.toJson()).toList());
  }
}

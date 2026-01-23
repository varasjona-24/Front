import 'package:get_storage/get_storage.dart';

import '../domain/source_theme_pill.dart';

class SourceThemePillStore {
  SourceThemePillStore(this._box);

  final GetStorage _box;
  static const _key = 'source_theme_pills';

  Future<List<SourceThemePill>> readAll() async {
    final raw = _box.read<List>(_key) ?? <dynamic>[];
    return raw
        .whereType<Map>()
        .map((m) => SourceThemePill.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  Future<void> upsert(SourceThemePill pill) async {
    final list = await readAll();
    final idx = list.indexWhere((e) => e.id == pill.id);
    if (idx == -1) {
      list.insert(0, pill);
    } else {
      list[idx] = pill;
    }
    await _box.write(_key, list.map((e) => e.toJson()).toList());
  }

  Future<void> remove(String id) async {
    final list = await readAll();
    list.removeWhere((e) => e.id == id);
    await _box.write(_key, list.map((e) => e.toJson()).toList());
  }
}

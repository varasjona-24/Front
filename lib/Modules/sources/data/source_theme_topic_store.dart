import 'package:get_storage/get_storage.dart';

import '../domain/source_theme_topic.dart';

class SourceThemeTopicStore {
  SourceThemeTopicStore(this._box);

  final GetStorage _box;
  static const _key = 'source_theme_topics';

  Future<List<SourceThemeTopic>> readAll() async {
    final raw = _box.read<List>(_key) ?? <dynamic>[];
    return raw
        .whereType<Map>()
        .map((m) => SourceThemeTopic.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  Future<void> upsert(SourceThemeTopic topic) async {
    final list = await readAll();
    final idx = list.indexWhere((e) => e.id == topic.id);
    if (idx == -1) {
      list.insert(0, topic);
    } else {
      list[idx] = topic;
    }
    await _box.write(_key, list.map((e) => e.toJson()).toList());
  }

  Future<void> remove(String id) async {
    final list = await readAll();
    list.removeWhere((e) => e.id == id);
    await _box.write(_key, list.map((e) => e.toJson()).toList());
  }
}

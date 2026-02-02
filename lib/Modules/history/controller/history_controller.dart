import 'package:get/get.dart';

import '../../../app/data/repo/media_repository.dart';
import '../../../app/models/media_item.dart';
import '../../home/controller/home_controller.dart';

// ============================
// 📅 BLOC: HISTORIAL
// ============================
class HistoryController extends GetxController {
  // ============================
  // 🔌 DEPENDENCIAS
  // ============================
  final MediaRepository _repo = Get.find<MediaRepository>();

  // ============================
  // 🧭 ESTADO
  // ============================
  final RxBool isLoading = false.obs;
  final RxList<MediaItem> items = <MediaItem>[].obs;
  final RxList<MediaItem> filteredItems = <MediaItem>[].obs;
  final RxList<HistoryDayGroup> groups = <HistoryDayGroup>[].obs;
  final Rx<HistoryKindFilter> filter = HistoryKindFilter.audio.obs;
  late final HomeController _home;

  // ============================
  // 🚀 INIT
  // ============================
  @override
  void onInit() {
    super.onInit();
    if (Get.isRegistered<HomeController>()) {
      _home = Get.find<HomeController>();
      _syncFilterWithHome();
      ever<HomeMode>(_home.mode, (_) => _syncFilterWithHome());
    }
    loadHistory();
  }

  // ============================
  // 📥 LOAD
  // ============================
  Future<void> loadHistory() async {
    try {
      isLoading.value = true;

      final library = await _repo.getLibrary();
      final recent = library
          .where((e) => (e.lastPlayedAt ?? 0) > 0)
          .toList()
        ..sort(
          (a, b) => (b.lastPlayedAt ?? 0).compareTo(a.lastPlayedAt ?? 0),
        );

      items.assignAll(recent);
      _applyFilter();
    } finally {
      isLoading.value = false;
    }
  }

  // ============================
  // 🧩 HELPERS
  // ============================
  void setFilter(HistoryKindFilter next) {
    if (filter.value == next) return;
    filter.value = next;
    _applyFilter();
  }

  void _syncFilterWithHome() {
    final desired = _home.mode.value == HomeMode.audio
        ? HistoryKindFilter.audio
        : HistoryKindFilter.video;
    if (filter.value != desired) {
      filter.value = desired;
      _applyFilter();
    }
  }

  void _applyFilter() {
    final filtered = _filterItems(items, filter.value);
    filteredItems.assignAll(filtered);
    groups.assignAll(_groupByDay(filteredItems));
  }

  List<MediaItem> _filterItems(
    List<MediaItem> list,
    HistoryKindFilter kind,
  ) {
    return list.where((item) {
      if (kind == HistoryKindFilter.audio) return item.hasAudioLocal;
      return item.hasVideoLocal;
    }).toList();
  }

  List<HistoryDayGroup> _groupByDay(List<MediaItem> list) {
    final Map<String, List<MediaItem>> bucket = {};

    for (final item in list) {
      final ts = item.lastPlayedAt ?? 0;
      if (ts <= 0) continue;
      final dt = DateTime.fromMillisecondsSinceEpoch(ts);
      final key = _dayKey(dt);
      bucket.putIfAbsent(key, () => []).add(item);
    }

    final keys = bucket.keys.toList()
      ..sort((a, b) => b.compareTo(a)); // desc

    return keys.map((k) {
      final date = _parseDayKey(k);
      final label = _dayLabel(date);
      return HistoryDayGroup(
        date: date,
        label: label,
        items: bucket[k] ?? const <MediaItem>[],
      );
    }).toList();
  }

  String _dayKey(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  DateTime _parseDayKey(String key) {
    final parts = key.split('-');
    if (parts.length != 3) return DateTime.now();
    final y = int.tryParse(parts[0]) ?? DateTime.now().year;
    final m = int.tryParse(parts[1]) ?? DateTime.now().month;
    final d = int.tryParse(parts[2]) ?? DateTime.now().day;
    return DateTime(y, m, d);
  }

  String _dayLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final other = DateTime(date.year, date.month, date.day);
    final diff = today.difference(other).inDays;

    if (diff == 0) return 'Hoy';
    if (diff == 1) return 'Ayer';

    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    final y = date.year.toString();
    return '$d/$m/$y';
  }

  String formatTime(MediaItem item) {
    final ts = item.lastPlayedAt ?? 0;
    if (ts <= 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(ts);
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

// ============================
// 🧩 MODELO: GRUPO POR DÍA
// ============================
enum HistoryKindFilter { audio, video }

class HistoryDayGroup {
  HistoryDayGroup({
    required this.date,
    required this.label,
    required this.items,
  });

  final DateTime date;
  final String label;
  final List<MediaItem> items;
} 

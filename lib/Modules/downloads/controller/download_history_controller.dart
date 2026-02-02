import 'package:get/get.dart';

import '../../../app/data/repo/media_repository.dart';
import '../../../app/models/media_item.dart';
import '../../home/controller/home_controller.dart';

// ============================
// 📅 BLOC: HISTORIAL DE IMPORTS
// ============================
class DownloadHistoryController extends GetxController {
  // ============================
  // 🔌 DEPENDENCIAS
  // ============================
  final MediaRepository _repo = Get.find<MediaRepository>();
  late final HomeController _home;

  // ============================
  // 🧭 ESTADO
  // ============================
  final RxBool isLoading = false.obs;
  final RxList<MediaItem> items = <MediaItem>[].obs;
  final RxList<MediaItem> filteredItems = <MediaItem>[].obs;
  final RxList<DownloadDayGroup> groups = <DownloadDayGroup>[].obs;
  final RxString query = ''.obs;
  final Rx<DownloadHistoryFilter> filter = DownloadHistoryFilter.audio.obs;

  // ============================
  // 🚀 INIT
  // ============================
  @override
  void onInit() {
    super.onInit();
    _home = Get.find<HomeController>();
    _syncFilterWithHome();
    ever<HomeMode>(_home.mode, (_) => _syncFilterWithHome());
    loadHistory();
  }

  // ============================
  // 📥 LOAD
  // ============================
  Future<void> loadHistory() async {
    try {
      isLoading.value = true;

      final library = await _repo.getLibrary();
      final downloaded = library
          .where((e) => e.isOfflineStored)
          .toList()
        ..sort(
          (a, b) => _latestVariantCreatedAt(b)
              .compareTo(_latestVariantCreatedAt(a)),
        );

      items.assignAll(downloaded);
      _applyFilter();
    } finally {
      isLoading.value = false;
    }
  }

  // ============================
  // 🧩 HELPERS
  // ============================
  void _applyFilter() {
    final filtered = _filterItems(items);

    filteredItems.assignAll(filtered);
    groups.assignAll(_groupByDay(filtered));
  }

  void setFilter(DownloadHistoryFilter next) {
    if (filter.value == next) return;
    filter.value = next;
    _applyFilter();
  }

  void setQuery(String value) {
    if (query.value == value) return;
    query.value = value;
    _applyFilter();
  }

  void _syncFilterWithHome() {
    final desired = _home.mode.value == HomeMode.audio
        ? DownloadHistoryFilter.audio
        : DownloadHistoryFilter.video;
    if (filter.value != desired) {
      filter.value = desired;
      _applyFilter();
    }
  }

  List<MediaItem> _filterItems(List<MediaItem> list) {
    final isAudio = filter.value == DownloadHistoryFilter.audio;
    final q = query.value.trim().toLowerCase();

    return list.where((item) {
      final matchesKind = isAudio ? item.hasAudioLocal : item.hasVideoLocal;
      if (!matchesKind) return false;
      if (q.isEmpty) return true;
      return item.title.toLowerCase().contains(q) ||
          item.subtitle.toLowerCase().contains(q);
    }).toList();
  }

  List<DownloadDayGroup> _groupByDay(List<MediaItem> list) {
    final Map<String, List<MediaItem>> bucket = {};

    for (final item in list) {
      final ts = _latestVariantCreatedAt(item);
      if (ts <= 0) continue;
      final dt = DateTime.fromMillisecondsSinceEpoch(ts);
      final key = _dayKey(dt);
      bucket.putIfAbsent(key, () => []).add(item);
    }

    final keys = bucket.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return keys.map((k) {
      final date = _parseDayKey(k);
      final label = _dayLabel(date);
      return DownloadDayGroup(
        date: date,
        label: label,
        items: bucket[k] ?? const <MediaItem>[],
      );
    }).toList();
  }

  int _latestVariantCreatedAt(MediaItem item) {
    var latest = 0;
    for (final v in item.variants) {
      if (v.localPath?.trim().isEmpty ?? true) continue;
      if (v.createdAt > latest) latest = v.createdAt;
    }
    return latest;
  }

  String formatTime(MediaItem item) {
    final ts = _latestVariantCreatedAt(item);
    if (ts <= 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(ts);
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
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
}

// ============================
// 🧩 MODELO: GRUPO POR DÍA
// ============================
class DownloadDayGroup {
  DownloadDayGroup({
    required this.date,
    required this.label,
    required this.items,
  });

  final DateTime date;
  final String label;
  final List<MediaItem> items;
}

enum DownloadHistoryFilter { audio, video }

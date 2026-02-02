import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:audio_session/audio_session.dart';
import 'package:get_storage/get_storage.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../app/controllers/theme_controller.dart';
import '../../../app/data/local/local_library_store.dart';
import '../../../app/models/media_item.dart';
import '../../../app/services/bluetooth_audio_service.dart';
import '../../../app/services/audio_service.dart';
import '../../../app/services/video_service.dart';

class SettingsController extends GetxController {
  final GetStorage _storage = GetStorage();

  // 🎨 Paleta actual
  final Rx<String> selectedPalette = 'green'.obs;

  // 🌗 Modo de brillo
  final Rx<Brightness> brightness = Brightness.dark.obs;

  // 🔊 Volumen por defecto (0-100)
  final RxDouble defaultVolume = 100.0.obs;

  // 📱 Calidad de descarga
  final Rx<String> downloadQuality = 'high'.obs; // low, medium, high

  // 📡 Uso de datos
  final Rx<String> dataUsage = 'all'.obs; // wifi_only, all

  // 🎵 Reproducción automática
  final RxBool autoPlayNext = true.obs;

  // 🌙 Sleep timer
  final RxBool sleepTimerEnabled = false.obs;
  final RxInt sleepTimerMinutes = 30.obs;
  final Rx<Duration> sleepRemaining = Duration.zero.obs;
  Timer? _sleepTimer;

  // 💤 Pausa por inactividad
  final RxBool inactivityPauseEnabled = false.obs;
  final RxInt inactivityPauseMinutes = 15.obs;
  Timer? _inactivityTimer;

  // 🎚️ Ecualizador (Android)
  final RxBool eqEnabled = false.obs;
  final RxString eqPreset = 'custom'.obs;
  final RxList<double> eqGains = <double>[].obs;
  final RxList<int> eqFrequencies = <int>[].obs;
  final RxDouble eqMinDb = (-6.0).obs;
  final RxDouble eqMaxDb = (6.0).obs;
  final RxBool eqAvailable = false.obs;

  // 🔄 Forzar refresco de datos de almacenamiento
  final RxInt storageTick = 0.obs;
  final RxInt bluetoothTick = 0.obs;
  final BluetoothAudioService _bluetoothAudio = BluetoothAudioService();

  @override
  void onInit() {
    super.onInit();
    _loadSettings();
    _configureAudioSession();
    _bindPlaybackActivity();
  }

  /// 📂 Cargar configuración guardada
  void _loadSettings() {
    final saved = _storage.read('selectedPalette') ?? 'green';
    const valid = ['red', 'green', 'blue', 'yellow', 'gray'];
    selectedPalette.value = valid.contains(saved) ? saved : 'green';
    brightness.value = (_storage.read('brightness') == 'light')
        ? Brightness.light
        : Brightness.dark;
    defaultVolume.value = _storage.read('defaultVolume') ?? 100.0;
    downloadQuality.value = _storage.read('downloadQuality') ?? 'high';
    dataUsage.value = _storage.read('dataUsage') ?? 'all';
    autoPlayNext.value = _storage.read('autoPlayNext') ?? true;

    sleepTimerEnabled.value = _storage.read('sleepTimerEnabled') ?? false;
    sleepTimerMinutes.value = _storage.read('sleepTimerMinutes') ?? 30;
    final sleepEndMs = _storage.read('sleepTimerEndMs');
    if (sleepEndMs is int && sleepEndMs > 0) {
      final remaining =
          Duration(milliseconds: sleepEndMs - DateTime.now().millisecondsSinceEpoch);
      if (remaining > Duration.zero) {
        sleepTimerEnabled.value = true;
        _startSleepTimer(remaining);
      } else {
        _clearSleepTimerPersisted();
      }
    }

    inactivityPauseEnabled.value =
        _storage.read('inactivityPauseEnabled') ?? false;
    inactivityPauseMinutes.value =
        _storage.read('inactivityPauseMinutes') ?? 15;

    eqEnabled.value = _storage.read('eqEnabled') ?? false;
    eqPreset.value = _storage.read('eqPreset') ?? 'custom';
    final rawGains = _storage.read<List>('eqGains');
    if (rawGains != null) {
      eqGains.assignAll(
        rawGains.whereType<num>().map((e) => e.toDouble()),
      );
    }

    try {
      final themeCtrl = Get.find<ThemeController>();
      themeCtrl.setPalette(selectedPalette.value);
      themeCtrl.setBrightness(brightness.value);
    } catch (_) {}

    _applyVolumeToPlayers(defaultVolume.value);
    _initEqualizer();
  }

  Future<void> _configureAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
    } catch (e) {
      print('Audio session init error: $e');
    }
  }

  /// 🎨 Cambiar paleta
  void setPalette(String paletteKey) {
    selectedPalette.value = paletteKey;
    _storage.write('selectedPalette', paletteKey);

    // Aplicar tema globalmente
    final themeCtrl = Get.find<ThemeController>();
    themeCtrl.setPalette(paletteKey);
  }

  /// 🌗 Cambiar modo claro/oscuro
  void setBrightness(Brightness mode) {
    brightness.value = mode;
    _storage.write('brightness', mode == Brightness.light ? 'light' : 'dark');

    // Aplicar tema globalmente
    try {
      final themeCtrl = Get.find<ThemeController>();
      themeCtrl.setBrightness(mode);
    } catch (e) {
      print('Error applying brightness: $e');
    }
  }

  /// 🔊 Cambiar volumen por defecto
  void setDefaultVolume(double volume) {
    defaultVolume.value = volume;
    _storage.write('defaultVolume', volume);
    _applyVolumeToPlayers(volume);
  }

  /// 📱 Cambiar calidad de descarga
  void setDownloadQuality(String quality) {
    downloadQuality.value = quality;
    _storage.write('downloadQuality', quality);
  }

  /// 📡 Cambiar uso de datos
  void setDataUsage(String usage) {
    dataUsage.value = usage;
    _storage.write('dataUsage', usage);
  }

  /// 🎵 Cambiar reproducción automática
  void setAutoPlayNext(bool value) {
    autoPlayNext.value = value;
    _storage.write('autoPlayNext', value);
  }

  // ==========================================================================
  // SLEEP TIMER
  // ==========================================================================
  void setSleepTimerEnabled(bool value) {
    sleepTimerEnabled.value = value;
    _storage.write('sleepTimerEnabled', value);
    if (!value) {
      _cancelSleepTimer();
      _clearSleepTimerPersisted();
      if (Get.isRegistered<AudioService>()) {
        Get.find<AudioService>().refreshNotification();
      }
      return;
    }
    final minutes = sleepTimerMinutes.value;
    _startSleepTimer(Duration(minutes: minutes));
  }

  void setSleepTimerMinutes(int minutes) {
    sleepTimerMinutes.value = minutes;
    _storage.write('sleepTimerMinutes', minutes);
    if (sleepTimerEnabled.value) {
      _startSleepTimer(Duration(minutes: minutes));
    }
  }

  void _startSleepTimer(Duration duration) {
    _cancelSleepTimer();
    final endMs =
        DateTime.now().millisecondsSinceEpoch + duration.inMilliseconds;
    _storage.write('sleepTimerEndMs', endMs);
    sleepRemaining.value = duration;
    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (t) async {
      final remaining =
          Duration(milliseconds: endMs - DateTime.now().millisecondsSinceEpoch);
      if (remaining <= Duration.zero) {
        sleepRemaining.value = Duration.zero;
        t.cancel();
        _sleepTimer = null;
        sleepTimerEnabled.value = false;
        _storage.write('sleepTimerEnabled', false);
        _clearSleepTimerPersisted();
        if (Get.isRegistered<AudioService>()) {
          await Get.find<AudioService>().pause();
          Get.find<AudioService>().refreshNotification();
        }
        return;
      }
      sleepRemaining.value = remaining;
      if (Get.isRegistered<AudioService>()) {
        Get.find<AudioService>().refreshNotification();
      }
    });
  }

  void _cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    sleepRemaining.value = Duration.zero;
  }

  void _clearSleepTimerPersisted() {
    _storage.remove('sleepTimerEndMs');
  }

  // ==========================================================================
  // INACTIVITY PAUSE
  // ==========================================================================
  void setInactivityPauseEnabled(bool value) {
    inactivityPauseEnabled.value = value;
    _storage.write('inactivityPauseEnabled', value);
    if (!value) {
      _cancelInactivityTimer();
      return;
    }
    _resetInactivityTimer();
  }

  void setInactivityPauseMinutes(int minutes) {
    inactivityPauseMinutes.value = minutes;
    _storage.write('inactivityPauseMinutes', minutes);
    if (inactivityPauseEnabled.value) {
      _resetInactivityTimer();
    }
  }

  void notifyPlaybackActivity() {
    if (!inactivityPauseEnabled.value) return;
    _resetInactivityTimer();
  }

  void _resetInactivityTimer() {
    _cancelInactivityTimer();
    final minutes = inactivityPauseMinutes.value;
    _inactivityTimer = Timer(Duration(minutes: minutes), () async {
      if (Get.isRegistered<AudioService>()) {
        final audio = Get.find<AudioService>();
        if (audio.isPlaying.value) {
          await audio.pause();
        }
      }
    });
  }

  void _cancelInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
  }

  void _bindPlaybackActivity() {
    if (!Get.isRegistered<AudioService>()) return;
    final audio = Get.find<AudioService>();
    ever<bool>(audio.isPlaying, (playing) {
      if (!playing) {
        _cancelInactivityTimer();
      } else if (inactivityPauseEnabled.value) {
        _resetInactivityTimer();
      }
    });
  }

  Future<void> setEqEnabled(bool value) async {
    eqEnabled.value = value;
    _storage.write('eqEnabled', value);
    if (Get.isRegistered<AudioService>()) {
      await Get.find<AudioService>().setEqEnabled(value);
    }
  }

  Future<void> setEqPreset(String preset) async {
    eqPreset.value = preset;
    _storage.write('eqPreset', preset);
    await _applyPreset();
  }

  Future<void> setEqGain(int index, double gain) async {
    if (index < 0) return;
    if (index >= eqGains.length) return;
    eqGains[index] = gain;
    eqPreset.value = 'custom';
    _storage.write('eqPreset', 'custom');
    _storage.write('eqGains', eqGains.toList());
    if (Get.isRegistered<AudioService>()) {
      await Get.find<AudioService>().setEqBandGain(index, gain);
    }
  }

  void _applyVolumeToPlayers(double volume) {
    final v = (volume / 100).clamp(0.0, 1.0);
    if (Get.isRegistered<AudioService>()) {
      Get.find<AudioService>().setVolume(v);
    }
    if (Get.isRegistered<VideoService>()) {
      Get.find<VideoService>().setVolume(v);
    }
  }

  Future<void> _initEqualizer() async {
    if (!Get.isRegistered<AudioService>()) return;
    final audio = Get.find<AudioService>();
    if (!audio.eqSupported) {
      eqAvailable.value = false;
      return;
    }

    try {
      final params = await audio.getEqParameters();
      if (params == null) return;

      eqAvailable.value = true;
      eqMinDb.value = params.minDecibels;
      eqMaxDb.value = params.maxDecibels;
      eqFrequencies.assignAll(
        params.bands.map((b) => b.centerFrequency.round()),
      );

      // Ajustar tamaño de gains
      if (eqGains.length != params.bands.length) {
        eqGains.assignAll(
          List<double>.filled(params.bands.length, 0.0),
        );
      }

      // Aplicar preset o gains guardados
      await _applyPreset();
      await setEqEnabled(eqEnabled.value);
    } catch (e) {
      print('Equalizer init error: $e');
      eqAvailable.value = false;
    }
  }

  Future<void> refreshEqualizer() => _initEqualizer();

  Future<void> _applyPreset() async {
    if (!Get.isRegistered<AudioService>()) return;
    if (!eqAvailable.value) return;

    final audio = Get.find<AudioService>();
    final bands = eqFrequencies.length;
    if (bands == 0) return;

    List<double> gains;
    if (eqPreset.value == 'custom' && eqGains.length == bands) {
      gains = eqGains.toList();
    } else {
      gains = _presetGains(
        eqPreset.value,
        bands,
        eqMinDb.value,
        eqMaxDb.value,
      );
      eqGains.assignAll(gains);
    }

    _storage.write('eqGains', eqGains.toList());
    for (var i = 0; i < gains.length; i++) {
      await audio.setEqBandGain(i, gains[i]);
    }
  }

  List<double> _presetGains(
    String preset,
    int bands,
    double minDb,
    double maxDb,
  ) {
    final base = switch (preset) {
      'bass' => [0.6, 0.4, 0.0, -0.2, -0.3],
      'vocal' => [-0.2, 0.1, 0.5, 0.4, -0.1],
      'treble' => [-0.3, -0.2, 0.0, 0.4, 0.6],
      'rock' => [0.4, 0.3, 0.1, 0.2, 0.4],
      _ => [0.0, 0.0, 0.0, 0.0, 0.0],
    };

    double clampDb(double v) {
      if (v < minDb) return minDb;
      if (v > maxDb) return maxDb;
      return v;
    }

    final maxAbs = [
      maxDb.abs(),
      minDb.abs(),
    ].reduce((a, b) => a < b ? a : b);

    if (bands <= 1) {
      return [clampDb(base.first * maxAbs)];
    }

    final gains = <double>[];
    for (var i = 0; i < bands; i++) {
      final t = i / (bands - 1);
      final rawIndex = t * (base.length - 1);
      final lo = rawIndex.floor();
      final hi = rawIndex.ceil();
      final frac = rawIndex - lo;
      final v = (lo == hi)
          ? base[lo]
          : (base[lo] + (base[hi] - base[lo]) * frac);
      gains.add(clampDb(v * maxAbs));
    }
    return gains;
  }

  Future<void> resetSettings() async {
    selectedPalette.value = 'olive';
    brightness.value = Brightness.dark;
    defaultVolume.value = 100.0;
    downloadQuality.value = 'high';
    dataUsage.value = 'all';
    autoPlayNext.value = true;

    await _storage.write('selectedPalette', selectedPalette.value);
    await _storage.write(
      'brightness',
      brightness.value == Brightness.light ? 'light' : 'dark',
    );
    await _storage.write('defaultVolume', defaultVolume.value);
    await _storage.write('downloadQuality', downloadQuality.value);
    await _storage.write('dataUsage', dataUsage.value);
    await _storage.write('autoPlayNext', autoPlayNext.value);

    try {
      final themeCtrl = Get.find<ThemeController>();
      themeCtrl.setPalette(selectedPalette.value);
      themeCtrl.setBrightness(brightness.value);
    } catch (_) {}
  }

  void refreshBluetoothDevices() {
    bluetoothTick.value++;
  }

  Future<BluetoothAudioSnapshot> getBluetoothSnapshot() async {
    try {
      final status = await _ensureBluetoothPermissions();
      if (!status) {
        return const BluetoothAudioSnapshot(
          bluetoothOn: false,
          devices: <BluetoothAudioDevice>[],
          outputs: <String>[],
        );
      }

      return await _bluetoothAudio.getSnapshot();
    } catch (e) {
      print('Bluetooth devices error: $e');
      return const BluetoothAudioSnapshot(
        bluetoothOn: false,
        devices: <BluetoothAudioDevice>[],
        outputs: <String>[],
      );
    }
  }

  Future<bool> _ensureBluetoothPermissions() async {
    final results = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    return results.values.every((r) => r.isGranted);
  }

  /// 🗑️ Limpiar caché (mantiene thumbnails)
  Future<void> clearCache() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      // No borrar archivos de audio/video descargados ni thumbnails.
      // Sólo limpiamos temporales y estado de configuración (cache lógica).

      final tmpDir = await getTemporaryDirectory();
      if (await tmpDir.exists()) {
        await for (final entity in tmpDir.list(recursive: true)) {
          try {
            await entity.delete(recursive: true);
          } catch (_) {
            // Ignorar archivos ya inexistentes o bloqueados
          }
        }
      }

      // Limpiar configuración considerada caché
      const cacheKeys = [
        // Tema / UI
        'selectedPalette',
        'brightness',
        // Reproducción
        'defaultVolume',
        'autoPlayNext',
        'audio_shuffle_on',
        'audio_repeat_mode',
        'audio_queue_items',
        'audio_queue_index',
        'audio_resume_positions',
        'video_queue_items',
        'video_queue_index',
        'video_resume_positions',
        'playerCoverStyle',
        // Ecualizador
        'eqEnabled',
        'eqPreset',
        'eqGains',
      ];

      for (final key in cacheKeys) {
        await _storage.remove(key);
      }

      _loadSettings();

      Get.snackbar(
        'Caché',
        'Caché limpiado correctamente',
        snackPosition: SnackPosition.BOTTOM,
      );
      storageTick.value++;
    } catch (e) {
      Get.snackbar(
        'Caché',
        'No se pudo limpiar el caché',
        snackPosition: SnackPosition.BOTTOM,
      );
      print('clearCache error: $e');
    }
  }

  Future<void> exportLibrary() async {
    try {
      final store = Get.find<LocalLibraryStore>();
      final items = await store.readAll();

      final appDir = await getApplicationDocumentsDirectory();
      final exportPath = p.join(appDir.path, 'listenfy_library_export.json');
      final file = File(exportPath);
      await file.writeAsString(
        jsonEncode(items.map((e) => e.toJson()).toList()),
        flush: true,
      );

      Get.snackbar(
        'Biblioteca',
        'Exportado en $exportPath',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar(
        'Biblioteca',
        'No se pudo exportar',
        snackPosition: SnackPosition.BOTTOM,
      );
      print('exportLibrary error: $e');
    }
  }

  Future<void> importLibrary() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['json'],
      );
      final file = res?.files.first;
      final path = file?.path;
      if (path == null || path.trim().isEmpty) return;

      final raw = await File(path).readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        throw Exception('Invalid library file');
      }

      final store = Get.find<LocalLibraryStore>();
      for (final entry in decoded) {
        if (entry is! Map) continue;
        final item = MediaItem.fromJson(Map<String, dynamic>.from(entry));
        await store.upsert(item);
      }

      Get.snackbar(
        'Biblioteca',
        'Importacion completada',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar(
        'Biblioteca',
        'No se pudo importar',
        snackPosition: SnackPosition.BOTTOM,
      );
      print('importLibrary error: $e');
    }
  }

  /// 📊 Obtener información de almacenamiento (descargas/medios)
  Future<String> getStorageInfo() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final downloadsDir = Directory(p.join(appDir.path, 'downloads'));
      final mediaDir = Directory(p.join(appDir.path, 'media'));

      final totalBytes =
          await _dirSize(downloadsDir) + await _dirSize(mediaDir);
      final mb = totalBytes / (1024 * 1024);
      return '${mb.toStringAsFixed(2)} MB';
    } catch (e) {
      print('storage info error: $e');
      return '0 MB';
    }
  }

  Future<int> _dirSize(Directory dir) async {
    if (!await dir.exists()) return 0;
    int total = 0;
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        final len = await entity.length();
        total += len;
      }
    }
    return total;
  }

  /// 🎵 Obtener bitrate de audio según calidad
  String getAudioBitrate(String? quality) {
    final q = quality ?? downloadQuality.value;
    switch (q) {
      case 'low':
        return '128 kbps';
      case 'medium':
        return '192 kbps';
      case 'high':
        return '320 kbps';
      default:
        return '320 kbps';
    }
  }

  /// 🎬 Obtener resolución de video según calidad
  String getVideoResolution(String? quality) {
    final q = quality ?? downloadQuality.value;
    switch (q) {
      case 'low':
        return '360p';
      case 'medium':
        return '720p';
      case 'high':
        return '1080p';
      default:
        return '1080p';
    }
  }

  /// 📦 Obtener descripción completa de calidad
  String getQualityDescription(String? quality) {
    final q = quality ?? downloadQuality.value;
    final audio = getAudioBitrate(q);
    final video = getVideoResolution(q);
    return 'Audio: $audio | Video: $video';
  }
}

extension SettingsControllerQuality on SettingsController {
  /// 🎯 Obtener información completa de descargas
  Map<String, dynamic> getDownloadSpecs() {
    return {
      'quality': downloadQuality.value,
      'audio_bitrate': getAudioBitrate(null),
      'video_resolution': getVideoResolution(null),
      'data_usage': dataUsage.value,
      'wifi_only': dataUsage.value == 'wifi_only',
    };
  }
}

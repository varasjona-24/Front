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
import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart' as dio;

import '../../../app/controllers/theme_controller.dart';
import '../../../app/data/network/dio_client.dart';
import '../../../app/data/local/local_library_store.dart';
import '../../../app/models/media_item.dart';
import '../../../Modules/playlists/data/playlist_store.dart';
import '../../../Modules/artists/data/artist_store.dart';
import '../../../Modules/sources/data/source_theme_pill_store.dart';
import '../../../Modules/sources/data/source_theme_topic_store.dart';
import '../../../Modules/sources/data/source_theme_topic_playlist_store.dart';
import '../../../Modules/playlists/controller/playlists_controller.dart';
import '../../../Modules/artists/controller/artists_controller.dart';
import '../../../Modules/sources/controller/sources_controller.dart';
import '../../../Modules/playlists/domain/playlist.dart';
import '../../../Modules/artists/domain/artist_profile.dart';
import '../../../Modules/sources/domain/source_theme_pill.dart';
import '../../../Modules/sources/domain/source_theme_topic.dart';
import '../../../Modules/sources/domain/source_theme_topic_playlist.dart';
import '../../../Modules/downloads/controller/downloads_controller.dart';
import '../../../Modules/home/controller/home_controller.dart';
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
  final RxInt crossfadeSeconds = 0.obs;

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

  // 🍪 YouTube cookies
  final TextEditingController ytdlpAdminTokenController =
      TextEditingController();
  final RxString ytdlpAdminToken = ''.obs;

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
    const valid = ['red', 'green', 'blue', 'yellow', 'gray', 'purple'];
    selectedPalette.value = valid.contains(saved) ? saved : 'green';
    brightness.value = (_storage.read('brightness') == 'light')
        ? Brightness.light
        : Brightness.dark;
    defaultVolume.value = _storage.read('defaultVolume') ?? 100.0;
    downloadQuality.value = _storage.read('downloadQuality') ?? 'high';
    dataUsage.value = _storage.read('dataUsage') ?? 'all';
    autoPlayNext.value = _storage.read('autoPlayNext') ?? true;
    crossfadeSeconds.value = _storage.read('audio_crossfade_seconds') ?? 0;

    ytdlpAdminToken.value = _storage.read('ytdlpAdminToken') ?? '';
    ytdlpAdminTokenController.text = ytdlpAdminToken.value;

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
    _applyCrossfade();
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

  Future<void> setCrossfadeSeconds(int seconds) async {
    final safe = seconds.clamp(0, 12).toInt();
    crossfadeSeconds.value = safe;
    _storage.write('audio_crossfade_seconds', safe);
    if (Get.isRegistered<AudioService>()) {
      await Get.find<AudioService>().setCrossfadeSeconds(safe);
    }
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

  void _applyCrossfade() {
    if (!Get.isRegistered<AudioService>()) return;
    Get.find<AudioService>().setCrossfadeSeconds(crossfadeSeconds.value);
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
    crossfadeSeconds.value = 0;

    await _storage.write('selectedPalette', selectedPalette.value);
    await _storage.write(
      'brightness',
      brightness.value == Brightness.light ? 'light' : 'dark',
    );
    await _storage.write('defaultVolume', defaultVolume.value);
    await _storage.write('downloadQuality', downloadQuality.value);
    await _storage.write('dataUsage', dataUsage.value);
    await _storage.write('autoPlayNext', autoPlayNext.value);
    await _storage.write('audio_crossfade_seconds', crossfadeSeconds.value);

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
        'audio_crossfade_seconds',
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

  void setYtDlpAdminToken(String value) {
    ytdlpAdminToken.value = value.trim();
    _storage.write('ytdlpAdminToken', ytdlpAdminToken.value);
  }

  Future<void> uploadYtDlpCookies() async {
    try {
      final token = ytdlpAdminTokenController.text.trim();
      if (token.isEmpty) {
        Get.snackbar(
          'Cookies de YouTube',
          'Primero ingresa el token de administrador',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['txt'],
      );
      final file = res?.files.first;
      final path = file?.path;
      if (path == null || path.trim().isEmpty) return;

      final raw = await File(path).readAsString();
      if (!raw.contains('Netscape HTTP Cookie File')) {
        Get.snackbar(
          'Cookies de YouTube',
          'El archivo no parece estar en formato Netscape',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      final b64 = base64.encode(utf8.encode(raw));
      final client = Get.find<DioClient>();
      await client.post(
        '/media/admin/ytdlp-cookies',
        data: {'cookiesBase64': b64},
        options: dio.Options(
          headers: {'x-admin-token': token},
        ),
      );

      Get.snackbar(
        'Cookies de YouTube',
        'Actualizadas correctamente',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar(
        'Cookies de YouTube',
        'No se pudo actualizar',
        snackPosition: SnackPosition.BOTTOM,
      );
      print('uploadYtDlpCookies error: $e');
    }
  }

  Future<void> exportLibrary() async {
    try {
      final libraryStore = Get.find<LocalLibraryStore>();
      final playlistStore = Get.find<PlaylistStore>();
      final artistStore = Get.find<ArtistStore>();
      final pillStore = Get.find<SourceThemePillStore>();
      final topicStore = Get.find<SourceThemeTopicStore>();
      final topicPlaylistStore = Get.find<SourceThemeTopicPlaylistStore>();

      final items = await libraryStore.readAll();
      final playlists = await playlistStore.readAll();
      final artists = await artistStore.readAll();
      final pills = await pillStore.readAll();
      final topics = await topicStore.readAll();
      final topicPlaylists = await topicPlaylistStore.readAll();

      final appDir = await getApplicationDocumentsDirectory();
      final tempDir = Directory(
        p.join(appDir.path, 'backup_tmp_${DateTime.now().millisecondsSinceEpoch}'),
      );
      await tempDir.create(recursive: true);
      final filesDir = Directory(p.join(tempDir.path, 'files'));
      await filesDir.create(recursive: true);

      Future<String?> copyToBackup(String? absPath) async {
        final clean = absPath?.trim() ?? '';
        if (clean.isEmpty) return null;
        final src = File(clean);
        if (!await src.exists()) return null;

        final rel = _relativeBackupPath(appDir.path, clean);
        final dest = File(p.join(filesDir.path, rel));
        await dest.parent.create(recursive: true);
        await src.copy(dest.path);
        return rel;
      }

      final itemsJson = <Map<String, dynamic>>[];
      for (final item in items) {
        final data = Map<String, dynamic>.from(item.toJson());
        final thumbRel = await copyToBackup(item.thumbnailLocalPath);
        if (thumbRel != null) {
          data['thumbnailLocalPath'] = thumbRel;
        }

        final variants = (data['variants'] as List?) ?? const [];
        final updatedVariants = <Map<String, dynamic>>[];
        for (final raw in variants) {
          if (raw is! Map) continue;
          final v = Map<String, dynamic>.from(raw);
          final localPath = (v['localPath'] as String?)?.trim();
          if (localPath != null && localPath.isNotEmpty) {
            final rel = await copyToBackup(localPath);
            if (rel != null) {
              v['localPath'] = rel;
            }
          }
          updatedVariants.add(v);
        }
        data['variants'] = updatedVariants;
        itemsJson.add(data);
      }

      final playlistsJson = <Map<String, dynamic>>[];
      for (final playlist in playlists) {
        final data = Map<String, dynamic>.from(playlist.toJson());
        final coverRel = await copyToBackup(playlist.coverLocalPath);
        if (coverRel != null) {
          data['coverLocalPath'] = coverRel;
        }
        playlistsJson.add(data);
      }

      final artistsJson = <Map<String, dynamic>>[];
      for (final artist in artists) {
        final data = Map<String, dynamic>.from(artist.toJson());
        final thumbRel = await copyToBackup(artist.thumbnailLocalPath);
        if (thumbRel != null) {
          data['thumbnailLocalPath'] = thumbRel;
        }
        artistsJson.add(data);
      }

      final topicsJson = <Map<String, dynamic>>[];
      for (final topic in topics) {
        final data = Map<String, dynamic>.from(topic.toJson());
        final coverRel = await copyToBackup(topic.coverLocalPath);
        if (coverRel != null) {
          data['coverLocalPath'] = coverRel;
        }
        topicsJson.add(data);
      }

      final topicPlaylistsJson = <Map<String, dynamic>>[];
      for (final playlist in topicPlaylists) {
        final data = Map<String, dynamic>.from(playlist.toJson());
        final coverRel = await copyToBackup(playlist.coverLocalPath);
        if (coverRel != null) {
          data['coverLocalPath'] = coverRel;
        }
        topicPlaylistsJson.add(data);
      }

      final manifest = <String, dynamic>{
        'version': 1,
        'createdAt': DateTime.now().toIso8601String(),
        'items': itemsJson,
        'playlists': playlistsJson,
        'artists': artistsJson,
        'sourceThemePills': pills.map((e) => e.toJson()).toList(),
        'sourceThemeTopics': topicsJson,
        'sourceThemeTopicPlaylists': topicPlaylistsJson,
      };

      final manifestFile = File(p.join(tempDir.path, 'manifest.json'));
      await manifestFile.writeAsString(jsonEncode(manifest), flush: true);

      final backupDir = await _resolveBackupDir();
      await backupDir.create(recursive: true);
      final zipPath = p.join(
        backupDir.path,
        _backupFileName(),
      );

      final encoder = ZipFileEncoder();
      encoder.create(zipPath);
      encoder.addDirectory(tempDir, includeDirName: false);
      encoder.close();

      await tempDir.delete(recursive: true);

      Get.defaultDialog(
        title: 'Copia de seguridad',
        content: Column(
          children: [
            const Text('Backup guardado en:'),
            const SizedBox(height: 8),
            SelectableText(zipPath, textAlign: TextAlign.center),
          ],
        ),
        textConfirm: 'Copiar ruta',
        textCancel: 'Cerrar',
        onConfirm: () async {
          await Clipboard.setData(ClipboardData(text: zipPath));
          Get.back();
          Get.snackbar(
            'Copia de seguridad',
            'Ruta copiada al portapapeles',
            snackPosition: SnackPosition.BOTTOM,
          );
        },
      );
    } catch (e) {
      Get.snackbar(
        'Copia de seguridad',
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
        allowedExtensions: const ['zip'],
      );
      final file = res?.files.first;
      final path = file?.path;
      if (path == null || path.trim().isEmpty) return;

      final appDir = await getApplicationDocumentsDirectory();
      final tempDir = Directory(
        p.join(appDir.path, 'backup_import_${DateTime.now().millisecondsSinceEpoch}'),
      );
      await tempDir.create(recursive: true);

      final bytes = await File(path).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      for (final file in archive) {
        final filename = file.name;
        final outPath = p.join(tempDir.path, filename);
        if (file.isFile) {
          final outFile = File(outPath);
          await outFile.parent.create(recursive: true);
          await outFile.writeAsBytes(file.content as List<int>, flush: true);
        } else {
          await Directory(outPath).create(recursive: true);
        }
      }

      final manifestFile = File(p.join(tempDir.path, 'manifest.json'));
      if (!await manifestFile.exists()) {
        throw Exception('Manifest not found');
      }

      final manifestRaw = await manifestFile.readAsString();
      final manifest = jsonDecode(manifestRaw) as Map<String, dynamic>;

      String? resolveRel(String? rel) {
        final clean = rel?.trim() ?? '';
        if (clean.isEmpty) return null;
        return p.join(appDir.path, clean);
      }

      Future<void> restoreFile(String? rel) async {
        final clean = rel?.trim() ?? '';
        if (clean.isEmpty) return;
        final src = File(p.join(tempDir.path, 'files', clean));
        if (!await src.exists()) return;
        final dest = File(p.join(appDir.path, clean));
        await dest.parent.create(recursive: true);
        await src.copy(dest.path);
      }

      final libraryStore = Get.find<LocalLibraryStore>();
      final itemsRaw = (manifest['items'] as List?) ?? const [];
      for (final raw in itemsRaw) {
        if (raw is! Map) continue;
        final data = Map<String, dynamic>.from(raw);

        final thumbRel = (data['thumbnailLocalPath'] as String?)?.trim();
        if (thumbRel != null && thumbRel.isNotEmpty) {
          await restoreFile(thumbRel);
          data['thumbnailLocalPath'] = resolveRel(thumbRel);
        }

        final variants = (data['variants'] as List?) ?? const [];
        final updatedVariants = <Map<String, dynamic>>[];
        for (final vRaw in variants) {
          if (vRaw is! Map) continue;
          final v = Map<String, dynamic>.from(vRaw);
          final localRel = (v['localPath'] as String?)?.trim();
          if (localRel != null && localRel.isNotEmpty) {
            await restoreFile(localRel);
            v['localPath'] = resolveRel(localRel);
          }
          updatedVariants.add(v);
        }
        data['variants'] = updatedVariants;

        final item = MediaItem.fromJson(data);
        await libraryStore.upsert(item);
      }

      final playlistStore = Get.find<PlaylistStore>();
      final playlistsRaw = (manifest['playlists'] as List?) ?? const [];
      for (final raw in playlistsRaw) {
        if (raw is! Map) continue;
        final data = Map<String, dynamic>.from(raw);
        final coverRel = (data['coverLocalPath'] as String?)?.trim();
        if (coverRel != null && coverRel.isNotEmpty) {
          await restoreFile(coverRel);
          data['coverLocalPath'] = resolveRel(coverRel);
        }
        await playlistStore.upsert(Playlist.fromJson(data));
      }

      final artistStore = Get.find<ArtistStore>();
      final artistsRaw = (manifest['artists'] as List?) ?? const [];
      for (final raw in artistsRaw) {
        if (raw is! Map) continue;
        final data = Map<String, dynamic>.from(raw);
        final thumbRel = (data['thumbnailLocalPath'] as String?)?.trim();
        if (thumbRel != null && thumbRel.isNotEmpty) {
          await restoreFile(thumbRel);
          data['thumbnailLocalPath'] = resolveRel(thumbRel);
        }
        await artistStore.upsert(ArtistProfile.fromJson(data));
      }

      final pillStore = Get.find<SourceThemePillStore>();
      final pillsRaw = (manifest['sourceThemePills'] as List?) ?? const [];
      for (final raw in pillsRaw) {
        if (raw is! Map) continue;
        await pillStore.upsert(SourceThemePill.fromJson(Map<String, dynamic>.from(raw)));
      }

      final topicStore = Get.find<SourceThemeTopicStore>();
      final topicsRaw = (manifest['sourceThemeTopics'] as List?) ?? const [];
      for (final raw in topicsRaw) {
        if (raw is! Map) continue;
        final data = Map<String, dynamic>.from(raw);
        final coverRel = (data['coverLocalPath'] as String?)?.trim();
        if (coverRel != null && coverRel.isNotEmpty) {
          await restoreFile(coverRel);
          data['coverLocalPath'] = resolveRel(coverRel);
        }
        await topicStore.upsert(SourceThemeTopic.fromJson(data));
      }

      final topicPlaylistStore = Get.find<SourceThemeTopicPlaylistStore>();
      final topicPlaylistsRaw =
          (manifest['sourceThemeTopicPlaylists'] as List?) ?? const [];
      for (final raw in topicPlaylistsRaw) {
        if (raw is! Map) continue;
        final data = Map<String, dynamic>.from(raw);
        final coverRel = (data['coverLocalPath'] as String?)?.trim();
        if (coverRel != null && coverRel.isNotEmpty) {
          await restoreFile(coverRel);
          data['coverLocalPath'] = resolveRel(coverRel);
        }
        await topicPlaylistStore.upsert(SourceThemeTopicPlaylist.fromJson(data));
      }

      await tempDir.delete(recursive: true);

      if (Get.isRegistered<DownloadsController>()) {
        await Get.find<DownloadsController>().load();
      }
      if (Get.isRegistered<HomeController>()) {
        await Get.find<HomeController>().loadHome();
      }
      if (Get.isRegistered<ArtistsController>()) {
        await Get.find<ArtistsController>().load();
      }
      if (Get.isRegistered<PlaylistsController>()) {
        await Get.find<PlaylistsController>().load();
      }
      if (Get.isRegistered<SourcesController>()) {
        await Get.find<SourcesController>().refreshAll();
      }

      Get.snackbar(
        'Copia de seguridad',
        'Importación completada',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar(
        'Copia de seguridad',
        'No se pudo importar',
        snackPosition: SnackPosition.BOTTOM,
      );
      print('importLibrary error: $e');
    }
  }

  Future<Directory> _resolveBackupDir() async {
    if (Platform.isAndroid) {
      final picked = await FilePicker.platform.getDirectoryPath();
      if (picked != null && picked.trim().isNotEmpty) {
        return Directory(p.join(picked, 'ListenfyBackups'));
      }
    }

    final appDir = await getApplicationDocumentsDirectory();
    return Directory(p.join(appDir.path, 'ListenfyBackups'));
  }

  String _backupFileName() {
    final now = DateTime.now();
    final stamp =
        '${now.year.toString().padLeft(4, '0')}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    return 'listenfy_backup_$stamp.zip';
  }

  String _relativeBackupPath(String appRoot, String absolutePath) {
    final normalized = p.normalize(absolutePath);
    if (p.isWithin(appRoot, normalized)) {
      return p.relative(normalized, from: appRoot);
    }
    final base = p.basename(normalized);
    final safe = '${normalized.hashCode}_$base';
    return p.join('external', safe);
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

  @override
  void onClose() {
    _sleepTimer?.cancel();
    _inactivityTimer?.cancel();
    ytdlpAdminTokenController.dispose();
    super.onClose();
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

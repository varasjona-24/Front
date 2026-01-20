import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../../app/controllers/theme_controller.dart';

class SettingsController extends GetxController {
  final GetStorage _storage = GetStorage();

  // 🎨 Paleta actual
  final Rx<String> selectedPalette = 'olive'.obs;

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

  @override
  void onInit() {
    super.onInit();
    _loadSettings();
  }

  /// 📂 Cargar configuración guardada
  void _loadSettings() {
    selectedPalette.value = _storage.read('selectedPalette') ?? 'olive';
    brightness.value = (_storage.read('brightness') == 'light')
        ? Brightness.light
        : Brightness.dark;
    defaultVolume.value = _storage.read('defaultVolume') ?? 100.0;
    downloadQuality.value = _storage.read('downloadQuality') ?? 'high';
    dataUsage.value = _storage.read('dataUsage') ?? 'all';
    autoPlayNext.value = _storage.read('autoPlayNext') ?? true;
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
      if (mode == Brightness.dark) {
        themeCtrl.brightness.value = Brightness.dark;
      } else {
        themeCtrl.brightness.value = Brightness.light;
      }
      themeCtrl.brightness.refresh();
    } catch (e) {
      print('Error applying brightness: $e');
    }
  }

  /// 🔊 Cambiar volumen por defecto
  void setDefaultVolume(double volume) {
    defaultVolume.value = volume;
    _storage.write('defaultVolume', volume);
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

  /// 🗑️ Limpiar caché (placeholder)
  void clearCache() {
    Get.snackbar(
      'Caché',
      'Caché limpiado correctamente',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  /// 📊 Obtener información de almacenamiento (placeholder)
  String getStorageInfo() {
    return 'Almacenamiento: ~500 MB';
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

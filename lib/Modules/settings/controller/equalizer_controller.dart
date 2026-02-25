import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../../app/services/audio_service.dart';

/// Gestiona: ecualizador completo (presets, gains, bandas).
class EqualizerController extends GetxController {
  final GetStorage _storage = GetStorage();

  // 🎚️ Ecualizador
  final RxBool eqEnabled = false.obs;
  final RxString eqPreset = 'custom'.obs;
  final RxList<double> eqGains = <double>[].obs;
  final RxList<int> eqFrequencies = <int>[].obs;
  final RxDouble eqMinDb = (-6.0).obs;
  final RxDouble eqMaxDb = (6.0).obs;
  final RxBool eqAvailable = false.obs;

  @override
  void onInit() {
    super.onInit();
    _loadSettings();
    _initEqualizer();
  }

  void _loadSettings() {
    eqEnabled.value = _storage.read('eqEnabled') ?? false;
    eqPreset.value = _storage.read('eqPreset') ?? 'custom';
    final rawGains = _storage.read<List>('eqGains');
    if (rawGains != null) {
      eqGains.assignAll(rawGains.whereType<num>().map((e) => e.toDouble()));
    }
  }

  // ============================
  // 🎚️ EQ CONTROL
  // ============================
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

  // ============================
  // 🔧 INIT / REFRESH
  // ============================
  Future<void> refreshEqualizer() => _initEqualizer();

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
        eqGains.assignAll(List<double>.filled(params.bands.length, 0.0));
      }

      // Aplicar preset o gains guardados
      await _applyPreset();
      await setEqEnabled(eqEnabled.value);
    } catch (e) {
      print('Equalizer init error: $e');
      eqAvailable.value = false;
    }
  }

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
      gains = _presetGains(eqPreset.value, bands, eqMinDb.value, eqMaxDb.value);
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

    final maxAbs = [maxDb.abs(), minDb.abs()].reduce((a, b) => a < b ? a : b);

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
}

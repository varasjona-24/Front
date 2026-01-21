import 'dart:async';
import 'package:flutter/services.dart';

class BluetoothAudioDevice {
  final String name;
  final String address;
  final String kind; // bluetooth, wired, speaker, earpiece, unknown
  final int? batteryPercent;

  const BluetoothAudioDevice({
    required this.name,
    required this.address,
    required this.kind,
    this.batteryPercent,
  });
}

class BluetoothAudioSnapshot {
  final bool bluetoothOn;
  final List<BluetoothAudioDevice> devices;
  final List<String> outputs;

  const BluetoothAudioSnapshot({
    required this.bluetoothOn,
    required this.devices,
    required this.outputs,
  });
}

class BluetoothAudioService {
  static const _channel = MethodChannel('listenfy/bluetooth_audio');

  Future<BluetoothAudioSnapshot> getSnapshot() async {
    try {
      final raw = await _channel.invokeMethod<Map>('getAudioDevices');
      final map = raw == null ? <String, dynamic>{} : Map<String, dynamic>.from(raw);

      final bluetoothOn = map['bluetoothOn'] == true;
      final outputsRaw = map['outputs'];
      final outputs = <String>[];
      if (outputsRaw is List) {
        for (final entry in outputsRaw) {
          if (entry is String && entry.trim().isNotEmpty) {
            outputs.add(entry.trim());
          }
        }
      }

      final devicesRaw = map['devices'];
      final devices = <BluetoothAudioDevice>[];

      if (devicesRaw is List) {
        for (final entry in devicesRaw) {
          if (entry is Map) {
            final data = Map<String, dynamic>.from(entry);
            final name = (data['name'] as String?)?.trim() ?? '';
            final address = (data['address'] as String?)?.trim() ?? '';
            final kind = (data['kind'] as String?)?.trim() ?? 'unknown';
            final battery = data['battery'];
            final batteryPercent = battery is num ? battery.toInt() : null;
            if (address.isNotEmpty) {
              devices.add(
                BluetoothAudioDevice(
                  name: name.isNotEmpty ? name : 'Dispositivo Bluetooth',
                  address: address,
                  kind: kind,
                  batteryPercent: batteryPercent,
                ),
              );
            } else if (name.isNotEmpty) {
              devices.add(
                BluetoothAudioDevice(
                  name: name,
                  address: '',
                  kind: kind,
                  batteryPercent: batteryPercent,
                ),
              );
            }
          }
        }
      }

      return BluetoothAudioSnapshot(
        bluetoothOn: bluetoothOn,
        devices: devices,
        outputs: outputs,
      );
    } catch (_) {
      return const BluetoothAudioSnapshot(
        bluetoothOn: false,
        devices: <BluetoothAudioDevice>[],
        outputs: <String>[],
      );
    }
  }
}

import 'dart:async';
import 'package:flutter/services.dart';

class BluetoothAudioDevice {
  final String name;
  final String address;

  const BluetoothAudioDevice({
    required this.name,
    required this.address,
  });
}

class BluetoothAudioSnapshot {
  final bool bluetoothOn;
  final List<BluetoothAudioDevice> devices;

  const BluetoothAudioSnapshot({
    required this.bluetoothOn,
    required this.devices,
  });
}

class BluetoothAudioService {
  static const _channel = MethodChannel('listenfy/bluetooth_audio');

  Future<BluetoothAudioSnapshot> getSnapshot() async {
    try {
      final raw = await _channel.invokeMethod<Map>('getAudioDevices');
      final map = raw == null ? <String, dynamic>{} : Map<String, dynamic>.from(raw);

      final bluetoothOn = map['bluetoothOn'] == true;
      final devicesRaw = map['devices'];
      final devices = <BluetoothAudioDevice>[];

      if (devicesRaw is List) {
        for (final entry in devicesRaw) {
          if (entry is Map) {
            final data = Map<String, dynamic>.from(entry);
            final name = (data['name'] as String?)?.trim() ?? '';
            final address = (data['address'] as String?)?.trim() ?? '';
            if (address.isNotEmpty) {
              devices.add(
                BluetoothAudioDevice(
                  name: name.isNotEmpty ? name : 'Dispositivo Bluetooth',
                  address: address,
                ),
              );
            }
          }
        }
      }

      return BluetoothAudioSnapshot(
        bluetoothOn: bluetoothOn,
        devices: devices,
      );
    } catch (_) {
      return const BluetoothAudioSnapshot(
        bluetoothOn: false,
        devices: <BluetoothAudioDevice>[],
      );
    }
  }
}

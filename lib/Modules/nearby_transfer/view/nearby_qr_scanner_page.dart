import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class NearbyQrScannerPage extends StatefulWidget {
  const NearbyQrScannerPage({super.key});

  @override
  State<NearbyQrScannerPage> createState() => _NearbyQrScannerPageState();
}

class _NearbyQrScannerPageState extends State<NearbyQrScannerPage> {
  bool _handled = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Escanear QR Listenfy')),
      body: MobileScanner(
        controller: MobileScannerController(
          detectionSpeed: DetectionSpeed.noDuplicates,
          facing: CameraFacing.back,
          torchEnabled: false,
        ),
        onDetect: (capture) {
          if (_handled) return;
          if (capture.barcodes.isEmpty) return;
          final raw = capture.barcodes.first.rawValue?.trim() ?? '';
          if (raw.isEmpty) return;
          _handled = true;
          Get.back(result: raw);
        },
      ),
    );
  }
}

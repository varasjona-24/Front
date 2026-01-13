import 'dart:io';
import 'package:flutter/foundation.dart';

class ApiConfig {
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:3000';
    }

    if (Platform.isAndroid) {
      // Android emulator
      return 'http://10.0.2.2:3000';
    }

    // 🔥 iOS (simulator y real) → IP DEL MAC
    return 'http://172.30.5.139:3000';
  }
}

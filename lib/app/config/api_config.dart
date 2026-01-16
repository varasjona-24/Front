import 'dart:io';
import 'package:flutter/foundation.dart';

class ApiConfig {
  static const _port = 3000;
  static const _devHost = '172.30.5.139';

  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:$_port';
    }

    if (kDebugMode) {
      if (Platform.isAndroid) {
        // ✅ Android real apuntando al Mac
        return 'http://$_devHost:$_port';
      }

      // ✅ iOS (simulator/real)
      return 'http://$_devHost:$_port';
    }

    // Producción
    return 'https://api.listenfy.com';
  }
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'source_origin.dart';
import 'source_pill_data.dart';

class SourcePillsCatalog {
  static SourcePillData pill({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> colors,
    required SourceOrigin origin,
    required VoidCallback onTap,
    bool forceDarkText = false,
  }) {
    return SourcePillData(
      origin: origin,
      title: title,
      subtitle: subtitle,
      icon: icon,
      gradient: LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: colors,
      ),
      forceDarkText: forceDarkText,
      onTap: onTap,
    );
  }

  static VoidCallback placeholderTap(String title) {
    return () => Get.snackbar(
      'Source',
      '$title (pendiente)',
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(12),
    );
  }
}

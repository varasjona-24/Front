import 'package:flutter/material.dart';

import '../../../app/models/media_item.dart';
import 'source_origin.dart';

class SourceTheme {
  const SourceTheme({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.colors,
    this.defaultOrigins = const [],
    this.onlyOffline = false,
    this.forceKind,
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> colors;
  final List<SourceOrigin> defaultOrigins;
  final bool onlyOffline;
  final MediaVariantKind? forceKind;
}

import 'dart:io';

import 'package:flutter/material.dart';

// ============================
// 🧱 UI: AVATAR DE ARTISTA
// ============================
class ArtistAvatar extends StatelessWidget {
  const ArtistAvatar({
    super.key,
    required this.thumb,
    required this.radius,
  });

  final String? thumb;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (thumb != null && thumb!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: scheme.surface,
        backgroundImage: thumb!.startsWith('http')
            ? NetworkImage(thumb!)
            : FileImage(File(thumb!)) as ImageProvider,
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: scheme.surface,
      child: Icon(
        Icons.person_rounded,
        color: scheme.onSurfaceVariant,
      ),
    );
  }
}

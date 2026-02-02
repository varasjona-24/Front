import 'package:flutter/material.dart';
import 'source_origin.dart';

// ============================
// 🧩 MODELO UI (PILL)
// ============================
class SourcePillData {
  const SourcePillData({
    required this.origin,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.onTap,
    this.forceDarkText = false,
  });

  // ============================
  // 📌 PROPIEDADES
  // ============================
  final SourceOrigin origin;
  final String title;
  final String subtitle;
  final IconData icon;
  final Gradient gradient;
  final VoidCallback onTap;

  final bool forceDarkText;
}

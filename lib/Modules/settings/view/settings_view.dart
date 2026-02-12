import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controller/settings_controller.dart';
import 'widgets/appearance_section.dart';
import 'widgets/audio_section.dart';
import 'widgets/data_section.dart';
import 'widgets/about_section.dart';
import '../../../app/ui/widgets/layout/app_gradient_background.dart';

class SettingsView extends GetView<SettingsController> {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final barColor = isDark ? Colors.black : Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: const Text(' Configuración'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: barColor,
        surfaceTintColor: barColor,
        foregroundColor: scheme.onSurface,
      ),
      backgroundColor: Colors.transparent,
      body: AppGradientBackground(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Column(
              children: [
                // 🎨 Sección de Apariencia
                const AppearanceSection(),
                const SizedBox(height: 24),

                // 🔊 Sección de Audio
                const AudioSection(),
                const SizedBox(height: 24),

                // 📡 Sección de Datos
                const DataSection(),
                const SizedBox(height: 24),

                // ℹ️ Sección de Información
                const AboutSection(),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

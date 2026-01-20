import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controller/settings_controller.dart';
import 'widgets/appearance_section.dart';
import 'widgets/audio_section.dart';
import 'widgets/data_section.dart';
import 'widgets/about_section.dart';

class SettingsView extends GetView<SettingsController> {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('⚙️ Configuración'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
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
    );
  }
}

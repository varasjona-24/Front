import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controller/settings_controller.dart';

class AppearanceSection extends GetView<SettingsController> {
  const AppearanceSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 🎨 Título
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            '🎨 Apariencia',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: 12),

        // 🌗 Modo claro/oscuro
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('🌗 Modo'),
                    Obx(
                      () => SegmentedButton<Brightness>(
                        segments: const [
                          ButtonSegment(
                            value: Brightness.light,
                            label: Text('☀️'),
                          ),
                          ButtonSegment(
                            value: Brightness.dark,
                            label: Text('🌙'),
                          ),
                        ],
                        selected: {controller.brightness.value},
                        onSelectionChanged: (Set<Brightness> newSelection) {
                          controller.setBrightness(newSelection.first);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 🎨 Selector de paleta
                Obx(
                  () => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Paleta: ${controller.selectedPalette.value.toUpperCase()}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildPaletteOption('earth', '🌍'),
                            _buildPaletteOption('olive', '🌿'),
                            _buildPaletteOption('blue', '🌊'),
                            _buildPaletteOption('sunset', '🌅'),
                            _buildPaletteOption('purple', '🟣'),
                            _buildPaletteOption('gray', '⚫'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPaletteOption(String key, String emoji) {
    return Obx(
      () => GestureDetector(
        onTap: () => controller.setPalette(key),
        child: Container(
          margin: const EdgeInsets.only(right: 8.0),
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            border: Border.all(
              color: controller.selectedPalette.value == key
                  ? Colors.white
                  : Colors.transparent,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(emoji, style: const TextStyle(fontSize: 24)),
        ),
      ),
    );
  }
}

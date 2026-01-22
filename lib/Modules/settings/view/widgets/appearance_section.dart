import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controller/settings_controller.dart';
import 'section_header.dart';
import 'value_pill.dart';
import 'palette_tile.dart';

class AppearanceSection extends GetView<SettingsController> {
  const AppearanceSection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              const Icon(Icons.palette_rounded, size: 18),
              const SizedBox(width: 8),
              Text(
                'Apariencia',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16.0),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: theme.dividerColor.withOpacity(.12)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Theme mode
                Row(
                  children: [
                    const Expanded(
                      child: SectionHeader(
                        title: 'Modo',
                        subtitle: 'Cambia entre claro y oscuro.',
                      ),
                    ),
                    Obx(
                      () => SegmentedButton<Brightness>(
                        segments: const [
                          ButtonSegment(
                            value: Brightness.light,
                            label: Text('Claro'),
                            icon: Icon(Icons.light_mode_rounded),
                          ),
                          ButtonSegment(
                            value: Brightness.dark,
                            label: Text('Oscuro'),
                            icon: Icon(Icons.dark_mode_rounded),
                          ),
                        ],
                        selected: {controller.brightness.value},
                        onSelectionChanged: (selection) {
                          controller.setBrightness(selection.first);
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                Divider(color: theme.dividerColor.withOpacity(.12)),
                const SizedBox(height: 12),

                // Palette selector
                Obx(() {
                  final selected = controller.selectedPalette.value;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: SectionHeader(
                              title: 'Paleta',
                              subtitle: 'Personaliza el estilo de la app.',
                            ),
                          ),
                          ValuePill(text: selected.toUpperCase()),
                        ],
                      ),
                      const SizedBox(height: 12),

                      SizedBox(
                        height: 54,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            PaletteTile(
                              label: 'Rojo',
                              color: const Color.fromARGB(255, 170, 88, 60),
                              selected: selected == 'red',
                              onTap: () => controller.setPalette('red'),
                            ),
                            PaletteTile(
                              label: 'Verde',
                              color: const Color.fromARGB(255, 62, 86, 66),
                              selected: selected == 'green',
                              onTap: () => controller.setPalette('green'),
                            ),
                            PaletteTile(
                              label: 'Azul',
                              color: const Color.fromARGB(255, 54, 90, 150),
                              selected: selected == 'blue',
                              onTap: () => controller.setPalette('blue'),
                            ),
                            PaletteTile(
                              label: 'Amarillo',
                              color: const Color.fromARGB(255, 196, 154, 92),
                              selected: selected == 'yellow',
                              onTap: () => controller.setPalette('yellow'),
                            ),
                            PaletteTile(
                              label: 'Gris',
                              color: const Color(0xFF4F4F4F),
                              selected: selected == 'gray',
                              onTap: () => controller.setPalette('gray'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

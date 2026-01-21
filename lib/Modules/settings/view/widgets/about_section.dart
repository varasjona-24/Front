import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controller/settings_controller.dart';
import '../widgets/info_tile.dart';
import '../widgets/value_pill.dart';

class AboutSection extends GetView<SettingsController> {
  const AboutSection({super.key});

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
              const Icon(Icons.info_outline_rounded, size: 18),
              const SizedBox(width: 8),
              Text(
                'Información',
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
                // Version (aquí sigue fijo porque pediste misma lógica)
                const InfoTile(
                  icon: Icons.verified_rounded,
                  title: 'Versión',
                  subtitle: '1.0.0',
                ),

                const SizedBox(height: 10),

                // Storage
                Obx(() {
                  controller.storageTick.value;
                  return FutureBuilder<String>(
                    future: controller.getStorageInfo(),
                    builder: (context, snap) {
                      final loading =
                          snap.connectionState != ConnectionState.done;
                      final value = snap.data;

                      if (loading) {
                        return const InfoTile(
                          icon: Icons.storage_rounded,
                          title: 'Almacenamiento',
                          subtitle: 'Calculando…',
                          trailing: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      }

                      return InfoTile(
                        icon: Icons.storage_rounded,
                        title: 'Almacenamiento',
                        subtitle: value ?? '—',
                        trailing: const ValuePill(text: 'Local'),
                      );
                    },
                  );
                }),

                const SizedBox(height: 10),

                // Last update (si no es real, idealmente quítalo o automatízalo luego)
                const InfoTile(
                  icon: Icons.update_rounded,
                  title: 'Última actualización',
                  subtitle: '20 de enero de 2026',
                ),

                const SizedBox(height: 14),
                Divider(color: theme.dividerColor.withOpacity(.12)),
                const SizedBox(height: 12),

                // Reset settings (misma lógica, pero con confirmación)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Restablecer ajustes'),
                          content: const Text(
                            'Esto restaurará los ajustes a sus valores por defecto. '
                            'No elimina tu biblioteca, solo preferencias.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancelar'),
                            ),
                            FilledButton.icon(
                              onPressed: () => Navigator.pop(ctx, true),
                              icon: const Icon(Icons.restart_alt_rounded),
                              label: const Text('Restablecer'),
                            ),
                          ],
                        ),
                      );

                      if (ok == true) {
                        controller.resetSettings();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Ajustes restablecidos.'),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.restart_alt_rounded),
                    label: const Text('Restablecer ajustes'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

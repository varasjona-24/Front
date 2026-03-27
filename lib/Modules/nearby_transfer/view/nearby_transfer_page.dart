import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/utils/listenfy_deep_link.dart';
import '../controller/nearby_transfer_controller.dart';
import 'nearby_qr_scanner_page.dart';

class NearbyTransferPage extends GetView<NearbyTransferController> {
  const NearbyTransferPage({super.key});

  Future<void> _showSendInviteQr() async {
    final item = controller.selectedItem.value;
    if (item == null) {
      Get.snackbar(
        'Transferencia',
        'Abre esta pantalla desde una canción para generar QR de envío.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final inviteUri = await controller.prepareInviteUriForSelectedItem();
    if (inviteUri == null) {
      Get.snackbar(
        'Transferencia',
        'No se pudo preparar el envío para esta canción.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    final payload = inviteUri.toString();

    await Get.dialog<void>(
      AlertDialog(
        title: const Text('QR de envío Listenfy'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            QrImageView(
              data: payload,
              version: QrVersions.auto,
              size: 220,
            ),
            const SizedBox(height: 12),
            Text(
              'Canción: ${item.title}\n'
              'Dispositivo emisor: ${controller.nickName}\n\n'
              'Escanea este QR desde Listenfy en el otro teléfono para iniciar descarga con metadata.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: payload));
              Get.snackbar(
                'QR',
                'Código copiado al portapapeles.',
                snackPosition: SnackPosition.BOTTOM,
              );
            },
            child: const Text('Copiar enlace'),
          ),
          FilledButton(
            onPressed: () => Get.back<void>(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Future<void> _scanAndHandleQr() async {
    final raw = await Get.to<String>(() => const NearbyQrScannerPage());
    if (raw == null || raw.trim().isEmpty) return;

    final target = ListenfyDeepLink.parseRaw(raw);
    switch (target) {
      case ListenfyDeepLinkTarget.nearbyInvite:
        final invite = ListenfyDeepLink.parseNearbyInviteRaw(raw);
        if (invite == null) {
          Get.snackbar(
            'QR no válido',
            'No se pudo leer la invitación de transferencia.',
            snackPosition: SnackPosition.BOTTOM,
          );
          return;
        }
        await controller.startReceiveFromInvite(invite);
        Get.snackbar(
          'Transferencia',
          'Conectando con ${invite.senderName} para recibir "${invite.title}".',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      case ListenfyDeepLinkTarget.openLocalImport:
        Get.toNamed(AppRoutes.downloads, arguments: {'openLocalImport': true});
        return;
      case ListenfyDeepLinkTarget.nearbyTransfer:
        if (Get.currentRoute != AppRoutes.nearbyTransfer) {
          Get.toNamed(AppRoutes.nearbyTransfer);
        }
        return;
      case ListenfyDeepLinkTarget.unknown:
        Get.snackbar(
          'QR no válido',
          'Ese código no corresponde a una acción de Listenfy.',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Transferencia offline')),
      body: Obx(() {
        final item = controller.selectedItem.value;
        final isConnected = controller.connectedPeers.isNotEmpty;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (item != null) ...[
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Canción seleccionada',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(item.title, style: theme.textTheme.bodyLarge),
                    if (item.subtitle.trim().isNotEmpty)
                      Text(
                        item.subtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            _SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Estado',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(controller.statusText.value),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: controller.isAdvertising.value
                            ? controller.stopAdvertisingMode
                            : controller.startAdvertisingMode,
                        icon: Icon(
                          controller.isAdvertising.value
                              ? Icons.campaign_outlined
                              : Icons.campaign_rounded,
                        ),
                        label: Text(
                          controller.isAdvertising.value
                              ? 'Detener emisor'
                              : 'Iniciar emisor',
                        ),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: controller.isDiscovering.value
                            ? controller.stopDiscoveryMode
                            : controller.startDiscoveryMode,
                        icon: Icon(
                          controller.isDiscovering.value
                              ? Icons.search_off_rounded
                              : Icons.radar_rounded,
                        ),
                        label: Text(
                          controller.isDiscovering.value
                              ? 'Detener búsqueda'
                              : 'Buscar dispositivos',
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: controller.stopAll,
                        icon: const Icon(Icons.stop_circle_outlined),
                        label: const Text('Detener todo'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _showSendInviteQr,
                        icon: const Icon(Icons.qr_code_rounded),
                        label: const Text('Mostrar QR envío'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _scanAndHandleQr,
                        icon: const Icon(Icons.qr_code_scanner_rounded),
                        label: const Text('Escanear QR'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dispositivos encontrados',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (controller.discoveredPeers.isEmpty)
                    Text(
                      'Sin dispositivos detectados.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    )
                  else
                    ...controller.discoveredPeers.map(
                      (peer) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.devices_rounded),
                        title: Text(peer.name),
                        subtitle: Text(peer.endpointId),
                        trailing: FilledButton.tonal(
                          onPressed: () => controller.connectToPeer(peer),
                          child: const Text('Conectar'),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Conexiones activas',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (controller.connectedPeers.isEmpty)
                    Text(
                      'Sin conexiones activas.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    )
                  else
                    ...controller.connectedPeers.map(
                      (peer) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.bluetooth_connected_rounded),
                        title: Text(peer.name),
                        subtitle: Text(peer.endpointId),
                        trailing: FilledButton(
                          onPressed: item == null
                              ? null
                              : () => controller.sendSelectedItemToPeer(
                                  peer.endpointId,
                                ),
                          child: const Text('Enviar'),
                        ),
                      ),
                    ),
                  if (isConnected && item == null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Abre esta pantalla desde una canción para habilitar "Enviar".',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (controller.transferProgress.isNotEmpty) ...[
              const SizedBox(height: 12),
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Transferencias',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...controller.transferProgress.entries.map((entry) {
                      final progress = entry.value.clamp(0, 1).toDouble();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Payload ${entry.key}'),
                            const SizedBox(height: 4),
                            LinearProgressIndicator(value: progress),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ],
        );
      }),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;

  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: child,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/ui/widgets/layout/app_gradient_background.dart';
import '../../../app/ui/widgets/navigation/app_top_bar.dart';
import '../controller/downloads_controller.dart';

class ImportsWebViewPage extends StatefulWidget {
  const ImportsWebViewPage({super.key});

  @override
  State<ImportsWebViewPage> createState() => _ImportsWebViewPageState();
}

class _ImportsWebViewPageState extends State<ImportsWebViewPage> {
  // ============================
  // 🧭 ESTADO
  // ============================
  final DownloadsController _downloadsController =
      Get.find<DownloadsController>();
  final TextEditingController _urlCtrl = TextEditingController(
    text: 'https://m.youtube.com',
  );

  // ============================
  // 🎨 UI
  // ============================
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final onSurface70 = scheme.onSurface.withAlpha(179);
    final border = scheme.outlineVariant.withAlpha(120);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppTopBar(
        title: const Text('Navegador'),
        onSearch: () {},
        leading: IconButton(
          onPressed: () => Get.back(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: AppGradientBackground(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: scheme.primary.withAlpha(28),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.public_rounded, color: scheme.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Buscador web',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Escribe o pega una URL...',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: onSurface70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: border),
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _urlCtrl,
                      keyboardType: TextInputType.url,
                      textInputAction: TextInputAction.go,
                      onSubmitted: (_) => _downloadsController.openCustomTab(
                        context,
                        _urlCtrl.text,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Pega una URL...',
                        prefixIcon: const Icon(Icons.link_rounded),
                        filled: true,
                        fillColor: scheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: scheme.primary.withAlpha(160),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Obx(() {
                            final opening =
                                _downloadsController.customTabOpening.value;
                            return FilledButton.icon(
                              onPressed: opening
                                  ? null
                                  : () => _downloadsController.openCustomTab(
                                        context,
                                        _urlCtrl.text,
                                      ),
                              icon: opening
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.open_in_new),
                              label: const Text('Abrir navegador'),
                            );
                          }),
                        ),
                        const SizedBox(width: 8),
                        Obx(() {
                          final opening =
                              _downloadsController.customTabOpening.value;
                          return OutlinedButton(
                            onPressed: opening ? null : () => _urlCtrl.clear(),
                            child: const Text('Limpiar'),
                          );
                        }),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: onSurface70, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tip: En caso de querer utilizar el pip, '
                        'descarga la app de un navegador compatible con esta función.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: onSurface70,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                'Escoge un link y vuelve para importarlo.',
                style: theme.textTheme.bodySmall?.copyWith(color: onSurface70),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

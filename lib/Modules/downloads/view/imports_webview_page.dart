import 'package:flutter/material.dart';
import 'package:flutter_custom_tabs/flutter_custom_tabs.dart';
import 'package:get/get.dart';

import '../../../app/ui/widgets/layout/app_gradient_background.dart';
import '../../../app/ui/widgets/navigation/app_top_bar.dart';

class ImportsWebViewPage extends StatefulWidget {
  const ImportsWebViewPage({super.key});

  @override
  State<ImportsWebViewPage> createState() => _ImportsWebViewPageState();
}

class _ImportsWebViewPageState extends State<ImportsWebViewPage> {
  final TextEditingController _urlCtrl = TextEditingController(
    text: 'https://m.youtube.com',
  );

  bool _opening = false;

  String _normalizeUrl(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return 'https://m.youtube.com';
    if (t.startsWith('http://') || t.startsWith('https://')) return t;
    return 'https://$t';
  }

  Future<void> _openCustomTab() async {
    if (_opening) return;

    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final url = _normalizeUrl(_urlCtrl.text);
    final uri = Uri.tryParse(url);
    if (uri == null) {
      Get.snackbar('URL inválida', 'No pude interpretar: $url');
      return;
    }

    setState(() => _opening = true);

    try {
      await launchUrl(
        uri,

        // Evita que YouTube salte a la app por deep links (si eso te rompe el flujo)
        prefersDeepLink: false,

        customTabsOptions: CustomTabsOptions(
          // 👇 CLAVE: aquí decides el provider del Custom Tab
          // - Si el navegador por defecto soporta Custom Tabs, úsalo.
          // - Si no, intenta esta lista en orden.
          browser: const CustomTabsBrowserConfiguration(
            prefersDefaultBrowser: true,
            fallbackCustomTabs: <String>[
              // Reemplaza/ajusta con lo que te salga en adb shell pm list packages
              'com.brave.browser', // Brave (común)
              'com.microsoft.emmx', // Microsoft Edge (común)
              'com.sec.android.app.sbrowser', // Samsung Internet (común)
              'com.opera.browser', // Opera (a veces)
            ],
          ),

          colorSchemes: CustomTabsColorSchemes.defaults(
            toolbarColor: cs.surface,
          ),

          showTitle: true,
          urlBarHidingEnabled: true,
          shareState: CustomTabsShareState.on,
          instantAppsEnabled: false,

          closeButton: CustomTabsCloseButton(
            icon: CustomTabsCloseButtonIcons.back,
          ),

          // En tu versión (2.4.x) esto es "animations"
          animations: CustomTabsSystemAnimations.slideIn(),
        ),

        safariVCOptions: SafariViewControllerOptions(
          preferredBarTintColor: cs.surface,
          preferredControlTintColor: cs.onSurface,
          barCollapsingEnabled: true,
          dismissButtonStyle: SafariViewControllerDismissButtonStyle.close,
        ),
      );
    } catch (e) {
      debugPrint('CustomTab launch error: $e');
      if (mounted) {
        Get.snackbar(
          'No se pudo abrir',
          'No hay navegador compatible (Custom Tabs) disponible o está deshabilitado.',
        );
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface70 = theme.colorScheme.onSurface.withAlpha(179);

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
              TextField(
                controller: _urlCtrl,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.go,
                onSubmitted: (_) => _openCustomTab(),
                decoration: InputDecoration(
                  hintText: 'Pega una URL...',
                  prefixIcon: const Icon(Icons.public_rounded),
                  suffixIcon: IconButton(
                    tooltip: 'Abrir',
                    onPressed: _opening ? null : _openCustomTab,
                    icon: _opening
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.arrow_forward_rounded),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Tip PiP: abre el video, ponlo en pantalla completa y presiona Home.\n'
                'El PiP lo maneja el navegador que abra la Custom Tab.',
                style: theme.textTheme.bodySmall?.copyWith(color: onSurface70),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _opening ? null : _openCustomTab,
                icon: const Icon(Icons.open_in_new),
                label: const Text('Abrir navegador integrado'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../branding/listenfy_logo.dart';

/// Dialog que permite buscar imágenes en Google Images y devuelve la URL
/// seleccionada al caller:

class ImageSearchDialog extends StatefulWidget {
  const ImageSearchDialog({
    super.key,
    required this.initialQuery,
    this.onImageSelected,
  });

  final String initialQuery;
  final ValueChanged<String>? onImageSelected;

  @override
  State<ImageSearchDialog> createState() => _ImageSearchDialogState();
}

class _ImageSearchDialogState extends State<ImageSearchDialog> {
  late final WebViewController _controller;

  bool _loading = true;
  bool _picked = false;

  static const String _imageTapScript = r'''
(function() {
  function pickUrl(img) {
    if (!img) return '';
    try {
      if ((img.naturalWidth || 0) < 120 || (img.naturalHeight || 0) < 120) {
        return '';
      }
    } catch (e) {}

    var dataIurl = img.getAttribute('data-iurl');
    if (dataIurl && dataIurl.startsWith('http')) return dataIurl;

    var dataSrc = img.getAttribute('data-src') || img.getAttribute('data-lowsrc');
    if (dataSrc && dataSrc.startsWith('http')) return dataSrc;

    var src = img.getAttribute('src');
    if (src && src.startsWith('http')) return src;

    var srcset = img.getAttribute('srcset');
    if (srcset) {
      var parts = srcset
        .split(',')
        .map(function(p){ return p.trim().split(' ')[0]; })
        .filter(Boolean);
      if (parts.length) return parts[parts.length - 1];
    }

    return '';
  }

  document.addEventListener('click', function(e) {
    var img = e.target.closest('img');
    if (!img) return;

    var url = pickUrl(img);
    if (url) {
      ListenfyImage.postMessage(url);
      e.preventDefault();
      e.stopPropagation();
    }
  }, true);
})();
''';

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'ListenfyImage',
        onMessageReceived: (msg) async {
          final url = msg.message.trim();
          if (!mounted) return;
          if (url.isEmpty) return;
          if (_picked) return; // evita doble pop por doble click/mensaje
          _picked = true;

          // Llama al callback si fue proporcionado antes de cerrar.
          try {
            if (widget.onImageSelected != null) {
              widget.onImageSelected!(url);
            }
          } catch (_) {}

          // Importante: cerrar el dialog del root navigator para evitar
          // problemas con navegadores anidados (GetX/tabs, etc.)
          Navigator.of(context, rootNavigator: true).pop(url);
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (_) async {
            if (!mounted) return;
            setState(() => _loading = false);
            try {
              await _controller.runJavaScript(_imageTapScript);
            } catch (_) {
              // Ignora si falla la inyección (cambios en la página / WebView)
            }
          },
        ),
      );

    _loadQuery(widget.initialQuery);
  }

  void _loadQuery(String query) {
    final q = query.trim().isEmpty ? 'album cover' : query.trim();
    final encoded = Uri.encodeComponent(q);
    final url = 'https://www.google.com/search?tbm=isch&q=$encoded';
    _controller.loadRequest(Uri.parse(url));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final onSurface70 = scheme.onSurface.withAlpha(179);

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      backgroundColor: scheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.78,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Row(
                children: [
                  const ListenfyLogo(size: 22, showText: false),
                  const SizedBox(width: 10),
                  Text(
                    'Listenfy',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () =>
                        Navigator.of(context, rootNavigator: true).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(18),
                ),
                child: Stack(
                  children: [
                    WebViewWidget(controller: _controller),
                    if (_loading)
                      Positioned.fill(
                        child: Container(
                          color: scheme.surface.withAlpha(230),
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: onSurface70, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Toca una imagen para seleccionarla.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: onSurface70,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

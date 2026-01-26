import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../app/ui/widgets/layout/app_gradient_background.dart';
import '../../../app/ui/widgets/navigation/app_top_bar.dart';

class ImportsWebViewPage extends StatefulWidget {
  const ImportsWebViewPage({super.key});

  @override
  State<ImportsWebViewPage> createState() => _ImportsWebViewPageState();
}

class _ImportsWebViewPageState extends State<ImportsWebViewPage> {
  late final WebViewController _controller;
  final TextEditingController _urlCtrl = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _loading = true),
          onPageFinished: (_) => setState(() => _loading = false),
        ),
      )
      ..loadRequest(Uri.parse('about:blank'));
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  void _openUrl() {
    final raw = _urlCtrl.text.trim();
    if (raw.isEmpty) return;
    final url = raw.startsWith('http') ? raw : 'https://$raw';
    _controller.loadRequest(Uri.parse(url));
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppTopBar(
        title: const Text('Navegador'),
        onSearch: () {},
      ),
      body: AppGradientBackground(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _urlCtrl,
                      keyboardType: TextInputType.url,
                      textInputAction: TextInputAction.go,
                      onSubmitted: (_) => _openUrl(),
                      decoration: const InputDecoration(
                        hintText: 'Pega una URL...',
                        prefixIcon: Icon(Icons.public_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _openUrl,
                    icon: const Icon(Icons.arrow_forward_rounded),
                  ),
                ],
              ),
            ),
            if (_loading)
              LinearProgressIndicator(
                minHeight: 2,
                color: theme.colorScheme.primary,
              ),
            const SizedBox(height: 6),
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(18),
                ),
                child: WebViewWidget(controller: _controller),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

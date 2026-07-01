import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

// ---------------------------------------------------------------------------
// LegalReaderScreen — light-weight WebView for privacy / support pages
// ---------------------------------------------------------------------------
// Intentionally simpler than PortalStage: an AppBar-styled toolbar, portrait
// only, and no IME plumbing (there's nothing to type). Called from the
// white game's menu bar.
// ---------------------------------------------------------------------------

class LegalReaderScreen extends StatefulWidget {
  final String title;
  final String url;

  const LegalReaderScreen({
    super.key,
    required this.title,
    required this.url,
  });

  @override
  State<LegalReaderScreen> createState() => _LegalReaderScreenState();
}

class _LegalReaderScreenState extends State<LegalReaderScreen> {
  late final WebViewController _web;
  bool _spinning = true;

  @override
  void initState() {
    super.initState();
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0B1E3B))
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() => _spinning = true),
        onPageFinished: (_) => setState(() => _spinning = false),
      ))
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1E3B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1E3B),
        foregroundColor: const Color(0xFFFFEFB4),
        elevation: 0,
        title: Text(
          widget.title,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
          ),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _web),
          if (_spinning)
            const Center(
              child: CircularProgressIndicator(
                valueColor:
                    AlwaysStoppedAnimation<Color>(Color(0xFFFFD873)),
              ),
            ),
        ],
      ),
    );
  }
}

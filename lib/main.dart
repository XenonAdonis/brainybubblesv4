import 'dart:io';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BrainyBubblesApp());
}

class BrainyBubblesApp extends StatelessWidget {
  const BrainyBubblesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Brainy Bubbles',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4F46E5)),
        useMaterial3: true,
      ),
      home: const WebGameScreen(),
    );
  }
}

class WebGameScreen extends StatefulWidget {
  const WebGameScreen({super.key});

  @override
  State<WebGameScreen> createState() => _WebGameScreenState();
}

class _WebGameScreenState extends State<WebGameScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String? _lastError;

  // 👉 Put your **exact** Vercel URL here. The query string helps bust cache.
  static String _gameUrl() {
    final ts = DateTime.now().millisecondsSinceEpoch;
    return 'https://brainybubblesv4.vercel.app/?app=android&v=2&t=$ts';
  }

  @override
  void initState() {
    super.initState();

    final params = const PlatformWebViewControllerCreationParams();
    final controller = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0B1224))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            setState(() {
              _isLoading = true;
              _lastError = null;
            });
          },
          onPageFinished: (url) {
            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (err) {
            setState(() {
              _isLoading = false;
              _lastError = err.description;
            });
          },
        ),
      )
      ..setUserAgent(
        // A modern mobile UA helps some frameworks pick mobile layout correctly.
        'Mozilla/5.0 (Linux; Android 14; Pixel 9 Pro XL) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36',
      )
      ..loadRequest(Uri.parse(_gameUrl()));

    // Android-specific tuning: allow media to autoplay, enable debugging
    if (controller.platform is AndroidWebViewController) {
      final androidCtrl = controller.platform as AndroidWebViewController;
      AndroidWebViewController.enableDebugging(true);
      // Allow background audio/video to start without a tap (helps BG music)
      androidCtrl.setMediaPlaybackRequiresUserGesture(false);
      // Optional: make scrolling smoother for canvas games
      androidCtrl.setRendererPriorityPolicy(
        RendererPriority.bound,
        true,
      );
    }

    _controller = controller;
  }

  Future<void> _reload() async {
    setState(() {
      _isLoading = true;
      _lastError = null;
    });
    await _controller.loadRequest(Uri.parse(_gameUrl()));
  }

  Future<bool> _handleBack() async {
    if (await _controller.canGoBack()) {
      _controller.goBack();
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final allowSystemPop = await _handleBack();
        if (allowSystemPop && context.mounted) Navigator.of(context).maybePop();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0B1224),
        appBar: AppBar(
          title: const Text('Brainy Bubbles'),
          backgroundColor: const Color(0xFF0B1224),
          foregroundColor: const Color(0xFFE2E8F0),
          elevation: 0,
          actions: [
            IconButton(
              tooltip: 'Reload',
              onPressed: _reload,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: Stack(
          children: [
            // WebView content
            WebViewWidget(controller: _controller),

            // Loading overlay
            if (_isLoading)
              Positioned.fill(
                child: Container(
                  color: const Color(0xFF0B1224),
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
              ),

            // Error overlay with retry
            if (_lastError != null)
              Positioned.fill(
                child: Container(
                  color: const Color(0xFF0B1224),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.wifi_off, size: 48, color: Colors.white70),
                      const SizedBox(height: 12),
                      const Text(
                        'Couldn’t load the game',
                        style: TextStyle(
                          color: Color(0xFFE2E8F0),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _lastError!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFF94A3B8)),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _reload,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Try Again'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

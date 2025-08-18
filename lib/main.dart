import 'dart:io';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // On Android, WebView needs this initialization.
  if (Platform.isAndroid) WebViewPlatform.instance = AndroidWebView();
  runApp(const BrainyBubblesApp());
}

class BrainyBubblesApp extends StatelessWidget {
  const BrainyBubblesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Brainy Bubbles',
      theme: ThemeData.dark(useMaterial3: true),
      debugShowCheckedModeBanner: false,
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
  // TODO: Put your live Vercel URL here (no trailing slash issues)
  static const String gameUrl = 'https://https://brainybubblesv4.vercel.app/';

  late final WebViewController _controller;
  bool _isLoading = true;
  String? _lastError;

  @override
  void initState() {
    super.initState();

    final params = PlatformWebViewControllerCreationParams();
    final ctrl = WebViewController.fromPlatformCreationParams(params)
      // Allow JS so your React/Canvas game runs
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      // Allow audio to start without a tap
      ..setInitialMediaPlaybackPolicy(AutoMediaPlaybackPolicy.always_allow)
      // Let the game open internal links in-place
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() {
            _isLoading = true;
            _lastError = null;
          }),
          onPageFinished: (_) => setState(() => _isLoading = false),
          onWebResourceError: (err) => setState(() {
            _lastError = err.description;
            _isLoading = false;
          }),
        ),
      )
      ..loadRequest(Uri.parse(gameUrl));

    _controller = ctrl;
  }

  Future<void> _reload() async {
    setState(() {
      _lastError = null;
      _isLoading = true;
    });
    try {
      await _controller.reload();
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  // Handle Android back button to go back inside the WebView history
  Future<bool> _onWillPop() async {
    if (await _controller.canGoBack()) {
      await _controller.goBack();
      return false;
    }
    return true; // exit the app
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              // Pull-to-refresh for convenience
              RefreshIndicator(
                onRefresh: () async => _controller.reload(),
                child: _lastError != null
                    ? _buildErrorView()
                    : WebViewWidget(controller: _controller),
              ),

              // Lightweight native splash while the game loads
              if (_isLoading) const _SplashOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return ListView( // needed for RefreshIndicator to work
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.8,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_off, size: 48),
                const SizedBox(height: 12),
                const Text(
                  'Couldn’t load Brainy Bubbles',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  _lastError ?? 'Unknown error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _reload,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SplashOverlay extends StatelessWidget {
  const _SplashOverlay();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0f172a), Color(0xFF0b1224)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text('Brainy Bubbles',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
              SizedBox(height: 10),
              Text('Loading...',
                  style: TextStyle(color: Color(0xFFcbd5e1))),
              SizedBox(height: 16),
              CircularProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}

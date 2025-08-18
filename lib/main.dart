import 'dart:math';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:audioplayers/audioplayers.dart';

void main() {
  runApp(const BrainyBubblesApp());
}

class BrainyBubblesApp extends StatelessWidget {
  const BrainyBubblesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Brainy Bubbles',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
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
  final AudioPlayer _bgPlayer = AudioPlayer();
  final AudioPlayer _sfxPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();

    // Initialize WebView controller
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        "BubbleChannel",
        onMessageReceived: (JavaScriptMessage message) {
          if (message.message == "pop") {
            _playPopSound();
          }
        },
      )
      ..loadRequest(Uri.parse("https://brainybubblesv4.vercel.app/"));

    // Start background music automatically
    _playBackgroundMusic();
  }

  Future<void> _playBackgroundMusic() async {
    await _bgPlayer.setReleaseMode(ReleaseMode.loop);
    await _bgPlayer.play(AssetSource("audio/brainy_bubbles_bg.mp3"));
  }

  Future<void> _playPopSound() async {
    // Randomize between high and low pop
    final sound = Random().nextBool() ? "pop_hi.mp3" : "pop_lo.mp3";
    await _sfxPlayer.play(AssetSource("audio/$sound"));
  }

  @override
  void dispose() {
    _bgPlayer.dispose();
    _sfxPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: WebViewWidget(controller: _controller),
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.music_note),
        onPressed: () async {
          // Toggle music on/off
          final state = await _bgPlayer.getState();
          if (state == PlayerState.playing) {
            await _bgPlayer.pause();
          } else {
            await _bgPlayer.resume();
          }
        },
      ),
    );
  }
}

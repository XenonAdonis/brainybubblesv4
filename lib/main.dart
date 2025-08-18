import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
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
      theme: ThemeData.dark(),
      home: const BubbleGame(),
    );
  }
}

class BubbleGame extends StatefulWidget {
  const BubbleGame({super.key});

  @override
  State<BubbleGame> createState() => _BubbleGameState();
}

class _BubbleGameState extends State<BubbleGame> {
  final List<Bubble> _bubbles = [];
  final Random _rand = Random();

  // Audio players
  late final AudioPlayer _bgPlayer;
  late final AudioPlayer _popPlayer;
  StreamSubscription? _bgSub;

  int _popToggle = 0; // alternate hi/lo pops
  int _score = 0;

  @override
  void initState() {
    super.initState();

    _bgPlayer = AudioPlayer();
    _popPlayer = AudioPlayer();

    _startBackgroundMusic();

    // Spawn bubbles every 2s
    Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!mounted) return;
      setState(() {
        _bubbles.add(Bubble(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          x: _rand.nextDouble() * 300,
          y: 600,
          size: 40 + _rand.nextDouble() * 40,
          speed: 20 + _rand.nextDouble() * 40,
        ));
      });
    });
  }

  Future<void> _startBackgroundMusic() async {
    try {
      if (_bgPlayer.state != PlayerState.playing) {
        await _bgPlayer.setReleaseMode(ReleaseMode.loop);
        await _bgPlayer.play(
          AssetSource('audio/brainy_bubbles_bg.mp3'),
          volume: 0.3,
        );
      }
    } catch (_) {
      // ignore autoplay restrictions (esp. on web)
    }
  }

  Future<void> _playPopSound() async {
    final sound = (_popToggle % 2 == 0)
        ? 'audio/pop_hi.mp3'
        : 'audio/pop_lo.mp3';
    _popToggle++;

    try {
      await _popPlayer.play(AssetSource(sound), volume: 1.0);
    } catch (_) {}
  }

  @override
  void dispose() {
    _bgSub?.cancel();
    _bgPlayer.dispose();
    _popPlayer.dispose();
    super.dispose();
  }

  void _popBubble(Bubble bubble) {
    setState(() {
      _bubbles.removeWhere((b) => b.id == bubble.id);
      _score++;
    });
    _playPopSound();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onTapDown: (details) {
          final tapPos = details.localPosition;
          final hit = _bubbles.firstWhere(
            (b) =>
                (tapPos.dx - b.x).abs() < b.size / 2 &&
                (tapPos.dy - b.y).abs() < b.size / 2,
            orElse: () => Bubble.empty(),
          );
          if (!hit.isEmpty) _popBubble(hit);
        },
        child: Stack(
          children: [
            // Background gradient
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blueAccent, Colors.black],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            // Moving bubbles
            ..._bubbles.map((b) => AnimatedPositioned(
                  key: ValueKey(b.id),
                  duration: Duration(seconds: (b.speed ~/ 10)),
                  curve: Curves.linear,
                  top: 0,
                  left: b.x,
                  child: Container(
                    width: b.size,
                    height: b.size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.3),
                      border: Border.all(color: Colors.white70, width: 2),
                    ),
                  ),
                )),
            // Score display
            Positioned(
              top: 40,
              left: 20,
              child: Text(
                'Score: $_score',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class Bubble {
  final String id;
  final double x;
  final double y;
  final double size;
  final double speed;

  Bubble({
    required this.id,
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
  });

  Bubble.empty()
      : id = '',
        x = 0,
        y = 0,
        size = 0,
        speed = 0;

  bool get isEmpty => id.isEmpty;
}

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
      theme: ThemeData.dark(),
      home: const GameScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final Random _random = Random();
  final List<Bubble> _bubbles = [];
  int _score = 0;
  bool _gameOver = false;
  Timer? _bubbleTimer;
  Timer? _gameTimer;
  int _timeLeft = 30;

  final AudioPlayer _musicPlayer = AudioPlayer();   // loops
  final AudioPlayer _effectPlayer = AudioPlayer();  // one-shots (pop/cheer)
  bool _musicOn = true;

  @override
  void initState() {
    super.initState();
    _startMusic();
    // Start a run immediately so the screen shows the game; you can change this
    // to show a splash if you prefer.
    unawaited(_startGame());
  }

  // Background music: start & loop
  Future<void> _startMusic() async {
    try {
      await _musicPlayer.setReleaseMode(ReleaseMode.loop);
      await _musicPlayer.play(AssetSource('audio/background_music.mp3'));
      setState(() => _musicOn = true);
    } catch (_) {
      // If asset missing or autoplay blocked, ignore (user can toggle via FAB)
    }
  }

  void _toggleMusic() async {
    if (_musicOn) {
      await _musicPlayer.pause();
    } else {
      // If first time failed due to policy, this manual interaction should succeed
      if (_musicPlayer.source == null) {
        // Ensure source set (in case autoplay failed before)
        try {
          await _musicPlayer.setReleaseMode(ReleaseMode.loop);
          await _musicPlayer.setSource(AssetSource('audio/background_music.mp3'));
        } catch (_) {}
      }
      await _musicPlayer.resume();
    }
    setState(() => _musicOn = !_musicOn);
  }

  Future<void> _playPopSound() async {
    try {
      await _effectPlayer.stop();
      await _effectPlayer.setSource(AssetSource('audio/pop.mp3'));
      await _effectPlayer.resume();
    } catch (_) {}
  }

  Future<void> _playCheerSound() async {
    try {
      await _effectPlayer.stop();
      await _effectPlayer.setSource(AssetSource('audio/cheer.mp3'));
      await _effectPlayer.resume();
    } catch (_) {}
  }

  // ---------------------- FIX: now async so 'await' is valid -----------------
  Future<void> _startGame() async {
    setState(() {
      _score = 0;
      _timeLeft = 30;
      _gameOver = false;
      _bubbles.clear();
    });

    _bubbleTimer?.cancel();
    _gameTimer?.cancel();

    // Spawn bubbles regularly
    _bubbleTimer = Timer.periodic(const Duration(milliseconds: 800), (_) {
      if (_gameOver) return;
      setState(() {
        _bubbles.add(Bubble(
          id: DateTime.now().millisecondsSinceEpoch,
          // x: 0..1 is relative; convert to pixels in Positioned
          x: _random.nextDouble(),
          // start just off-screen
          y: 1.2,
          size: 40 + _random.nextDouble() * 40,
          // give each bubble a random upward speed
          vy: 0.25 + _random.nextDouble() * 0.35,
        ));
      });
    });

    // Countdown timer
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft > 0) {
        setState(() => _timeLeft--);
      } else {
        _endGame();
      }
    });
  }

  void _endGame() {
    _gameOver = true;
    _bubbleTimer?.cancel();
    _gameTimer?.cancel();
    unawaited(_playCheerSound());
    setState(() {}); // show game over overlay
  }

  void _popBubble(int id) {
    setState(() {
      _bubbles.removeWhere((bubble) => bubble.id == id);
      _score++;
    });
    unawaited(_playPopSound());
  }

  @override
  void dispose() {
    _musicPlayer.dispose();
    _effectPlayer.dispose();
    _bubbleTimer?.cancel();
    _gameTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // Tap to pop
          GestureDetector(
            onTapDown: (details) {
              final tap = details.localPosition;
              for (final bubble in List<Bubble>.from(_bubbles)) {
                final bx = bubble.x * size.width;
                final by = bubble.y * size.height;
                final dx = bx - tap.dx;
                final dy = by - tap.dy;
                final hit = (dx * dx + dy * dy) <= (bubble.size / 2) * (bubble.size / 2);
                if (hit) {
                  _popBubble(bubble.id);
                  break;
                }
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              color: Colors.blue.shade900,
              child: Stack(
                children: [
                  // Move/render bubbles
                  ..._bubbles.map((bubble) {
                    // Update Y for a gentle float upwards (in a very simple way).
                    // For deterministic motion, this should be based on real time;
                    // keeping it simple here for clarity.
                    final newY = bubble.y - bubble.vy * 0.01; // small per-frame step
                    bubble.y = newY;

                    return Positioned(
                      left: bubble.x * size.width - bubble.size / 2,
                      top: bubble.y * size.height - bubble.size / 2,
                      child: BubbleWidget(bubble: bubble),
                    );
                  }),

                  // HUD
                  Positioned(
                    top: 40,
                    left: 20,
                    child: Text('Score: $_score', style: const TextStyle(fontSize: 24)),
                  ),
                  Positioned(
                    top: 40,
                    right: 20,
                    child: Text('Time: $_timeLeft', style: const TextStyle(fontSize: 24)),
                  ),
                ],
              ),
            ),
          ),

          // Game Over overlay
          if (_gameOver) _buildGameOver(),

          // Music toggle
          Positioned(
            bottom: 40,
            right: 20,
            child: FloatingActionButton(
              onPressed: _toggleMusic,
              child: Icon(_musicOn ? Icons.music_note : Icons.music_off),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameOver() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(.45),
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF0f172a).withOpacity(.8),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Game Over', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('Final: $_score', style: const TextStyle(color: Color(0xFFcbd5e1))),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () async {
                    await _startGame(); // ✅ now valid because _startGame() is async
                  },
                  child: const Text('Try Again'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class Bubble {
  final int id;
  final double x;
  double y;         // mutable so we can animate simple upward motion
  final double size;
  final double vy;  // upward speed in "screen fraction per tick"

  Bubble({
    required this.id,
    required this.x,
    required this.y,
    required this.size,
    required this.vy,
  });
}

class BubbleWidget extends StatelessWidget {
  final Bubble bubble;

  const BubbleWidget({super.key, required this.bubble});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: bubble.size,
      height: bubble.size,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.5),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
    );
  }
}

// Fire-and-forget helper for Futures we don't want to await.
void unawaited(Future<void> f) {}

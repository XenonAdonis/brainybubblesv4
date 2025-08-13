// Brainy Bubbles – Flutter Web (Vercel-ready)
// Splash screen, target match, timer/goal, level-ups, star particles,
// reduced-motion, music toggle. Music now starts reliably after Start
// and on subsequent resumes/level-ups. "Best" badge removed;
// only persistent High score shown on Game Over.
//
// Audio assets expected (or keep folder with .gitkeep):
//   assets/audio/brainy_bubbles_bg.mp3
//   assets/audio/pop_hi.mp3
//   assets/audio/pop_lo.mp3
//   assets/audio/cheer_triple.mp3
//
// pubspec.yaml:
// flutter:
//   uses-material-design: true
//   assets:
//     - assets/audio/

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

  final AudioPlayer _musicPlayer = AudioPlayer();
  final AudioPlayer _effectPlayer = AudioPlayer();
  bool _musicOn = true;

  @override
  void initState() {
    super.initState();
    _startMusic();
    _startGame();
  }

  void _startMusic() async {
    await _musicPlayer.setReleaseMode(ReleaseMode.loop);
    await _musicPlayer.play(AssetSource('audio/background_music.mp3'));
    setState(() {
      _musicOn = true;
    });
  }

  void _toggleMusic() {
    if (_musicOn) {
      _musicPlayer.pause();
    } else {
      _musicPlayer.resume();
    }
    setState(() {
      _musicOn = !_musicOn;
    });
  }

  void _playPopSound() {
    _effectPlayer.play(AssetSource('audio/pop.mp3'));
  }

  void _playCheerSound() {
    _effectPlayer.play(AssetSource('audio/cheer.mp3'));
  }

  void _startGame() {
    _score = 0;
    _timeLeft = 30;
    _gameOver = false;
    _bubbles.clear();

    _bubbleTimer?.cancel();
    _gameTimer?.cancel();

    _bubbleTimer = Timer.periodic(const Duration(milliseconds: 800), (_) {
      if (!_gameOver) {
        setState(() {
          _bubbles.add(Bubble(
            id: DateTime.now().millisecondsSinceEpoch,
            x: _random.nextDouble(),
            y: 1.2,
            size: 40 + _random.nextDouble() * 40,
          ));
        });
      }
    });

    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft > 0) {
        setState(() {
          _timeLeft--;
        });
      } else {
        _endGame();
      }
    });
  }

  void _endGame() {
    _gameOver = true;
    _bubbleTimer?.cancel();
    _gameTimer?.cancel();
    _playCheerSound();
  }

  void _popBubble(int id) {
    setState(() {
      _bubbles.removeWhere((bubble) => bubble.id == id);
      _score++;
    });
    _playPopSound();
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
    return Scaffold(
      body: Stack(
        children: [
          GestureDetector(
            onTapDown: (details) {
              final tapPos = details.localPosition;
              for (final bubble in List<Bubble>.from(_bubbles)) {
                if ((bubble.x * MediaQuery.of(context).size.width - tapPos.dx).abs() <
                        bubble.size / 2 &&
                    (bubble.y * MediaQuery.of(context).size.height - tapPos.dy).abs() <
                        bubble.size / 2) {
                  _popBubble(bubble.id);
                }
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              color: Colors.blue.shade900,
              child: Stack(
                children: [
                  ..._bubbles.map((bubble) {
                    return Positioned(
                      left: bubble.x * MediaQuery.of(context).size.width,
                      top: bubble.y * MediaQuery.of(context).size.height,
                      child: BubbleWidget(bubble: bubble),
                    );
                  }).toList(),
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
          if (_gameOver) _buildGameOver(),
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
                    await _startGame();
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
  final double y;
  final double size;

  Bubble({required this.id, required this.x, required this.y, required this.size});
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

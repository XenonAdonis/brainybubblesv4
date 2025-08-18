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
      theme: ThemeData.dark(useMaterial3: true),
      debugShowCheckedModeBanner: false,
      home: const GameScreen(),
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  // --------------------- Game State ---------------------
  final Random _rand = Random();
  final List<Bubble> _bubbles = [];
  int _score = 0;
  int _timeLeft = 30;
  bool _gameOver = false;

  // Timers
  Timer? _spawnTimer;
  Timer? _tickTimer;
  Timer? _countdownTimer;

  // --------------------- Audio --------------------------
  final AudioPlayer _music = AudioPlayer();   // loops background
  final AudioPlayer _sfx = AudioPlayer();     // one-shot effects
  bool _musicOn = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Start music (best effort; will succeed after first user interaction if autoplay is blocked)
    unawaited(_startMusic());

    // Start a run immediately
    unawaited(_startGame());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopAllTimers();
    _music.dispose();
    _sfx.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Pause music when app is paused; resume when foregrounded (if toggled on)
    if (state == AppLifecycleState.paused) {
      unawaited(_music.pause());
    } else if (state == AppLifecycleState.resumed && _musicOn) {
      unawaited(_music.resume());
    }
  }

  // --------------------- Audio helpers ------------------
  Future<void> _startMusic() async {
    try {
      await _music.setReleaseMode(ReleaseMode.loop);
      // IMPORTANT: AssetSource path is relative to the "assets/" root in pubspec
      await _music.play(AssetSource('audio/brainy_bubbles_bg.mp3'));
      setState(() => _musicOn = true);
    } catch (_) {
      // Autoplay may be blocked; user can toggle music to start it
    }
  }

  Future<void> _toggleMusic() async {
    if (_musicOn) {
      await _music.pause();
      setState(() => _musicOn = false);
    } else {
      try {
        // If no source yet (first manual start), set it
        if (_music.source == null) {
          await _music.setReleaseMode(ReleaseMode.loop);
          await _music.setSource(AssetSource('audio/brainy_bubbles_bg.mp3'));
        }
        await _music.resume();
        setState(() => _musicOn = true);
      } catch (_) {}
    }
  }

  Future<void> _popSfx() async {
    try {
      // Alternate between hi/lo pop for variety
      final choice = (_rand.nextBool()) ? 'audio/pop_hi.mp3' : 'audio/pop_lo.mp3';
      await _sfx.stop();
      await _sfx.setSource(AssetSource(choice));
      await _sfx.resume();
    } catch (_) {}
  }

  // --------------------- Game flow ----------------------
  Future<void> _startGame() async {
    setState(() {
      _score = 0;
      _timeLeft = 30;
      _gameOver = false;
      _bubbles.clear();
    });

    _stopAllTimers();

    // Spawn bubbles every ~800ms
    _spawnTimer = Timer.periodic(const Duration(milliseconds: 800), (_) {
      if (_gameOver) return;
      setState(() {
        _bubbles.add(Bubble(
          id: DateTime.now().microsecondsSinceEpoch,
          x: _rand.nextDouble(),     // 0..1 fractional screen X
          y: 1.15,                   // start slightly below screen
          r: 20 + _rand.nextDouble() * 30,
          vy: 0.22 + _rand.nextDouble() * 0.35, // upward speed (fraction / sec)
        ));
      });
    });

    // 60 FPS-ish tick to move bubbles
    const dt = Duration(milliseconds: 16);
    _tickTimer = Timer.periodic(dt, (_) {
      if (_gameOver) return;
      final t = dt.inMilliseconds / 1000.0;
      setState(() {
        for (final b in _bubbles) {
          b.y -= b.vy * t;
        }
        // Remove bubbles that floated off-screen
        _bubbles.removeWhere((b) => b.y < -0.2);
      });
    });

    // Countdown timer
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_timeLeft > 0) {
        setState(() => _timeLeft--);
      } else {
        _endGame();
      }
    });
  }

  void _endGame() {
    _gameOver = true;
    _stopAllTimers();
    setState(() {}); // show overlay
  }

  void _stopAllTimers() {
    _spawnTimer?.cancel();
    _tickTimer?.cancel();
    _countdownTimer?.cancel();
  }

  // --------------------- Interaction --------------------
  void _handleTap(Offset tapPos, Size size) {
    // Find the topmost bubble under the finger and pop it
    for (int i = _bubbles.length - 1; i >= 0; i--) {
      final b = _bubbles[i];
      final bx = b.x * size.width;
      final by = b.y * size.height;
      final dx = bx - tapPos.dx;
      final dy = by - tapPos.dy;
      final hit = (dx * dx + dy * dy) <= (b.r * b.r);
      if (hit) {
        setState(() {
          _score++;
          _bubbles.removeAt(i);
        });
        unawaited(_popSfx());
        break;
      }
    }
  }

  // --------------------- UI -----------------------------
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: GestureDetector(
        onTapDown: (d) => _handleTap(d.localPosition, size),
        child: Stack(
          children: [
            // Background
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0f172a), Color(0xFF0b1224)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),

            // Bubbles
            ..._bubbles.map((b) => Positioned(
                  left: b.x * size.width - b.r,
                  top: b.y * size.height - b.r,
                  child: _BubbleWidget(radius: b.r),
                )),

            // HUD
            Positioned(
              top: 40,
              left: 20,
              child: Text('Score: $_score', style: const TextStyle(fontSize: 22)),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: Text('Time: $_timeLeft', style: const TextStyle(fontSize: 22)),
            ),

            // Game over overlay
            if (_gameOver) _buildGameOverOverlay(),
          ],
        ),
      ),

      // Music toggle
      floatingActionButton: FloatingActionButton(
        onPressed: _toggleMusic,
        child: Icon(_musicOn ? Icons.music_note : Icons.music_off),
      ),
    );
  }

  Widget _buildGameOverOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.45),
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF0f172a).withOpacity(.9),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Game Over',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text('Final score: $_score',
                    style: const TextStyle(color: Color(0xFFcbd5e1))),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: () async => await _startGame(),
                  child: const Text('Play Again'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --------------------- Models & Widgets -----------------
class Bubble {
  Bubble({
    required this.id,
    required this.x,
    required this.y,
    required this.r,
    required this.vy,
  });

  final int id;
  final double x;   // 0..1 screen width
  double y;         // 0..1 screen height (mutable so we can animate)
  final double r;   // radius in pixels
  final double vy;  // upward speed (screen fraction / second)
}

class _BubbleWidget extends StatelessWidget {
  const _BubbleWidget({required this.radius});
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            Colors.white.withOpacity(0.9),
            Colors.blueAccent.withOpacity(0.25),
          ],
          center: const Alignment(-0.4, -0.5),
          radius: 1.0,
        ),
        border: Border.all(color: Colors.white.withOpacity(0.7), width: 2),
      ),
    );
  }
}

// Fire-and-forget helper (ignore returned Future).
void unawaited(Future<void> f) {}

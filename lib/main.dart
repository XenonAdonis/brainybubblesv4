import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const BrainyBubblesApp());
}

/// Brainy Bubbles – minimal playable app with:
/// - Background music toggle (safe if asset is missing)
/// - Less Bubbles toggle
/// - Faster spawn rate at start
/// - Simple tap-to-pop scoring
class BrainyBubblesApp extends StatelessWidget {
  const BrainyBubblesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Brainy Bubbles',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF3B82F6),
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0b1224),
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF0f172a)),
      ),
      home: const BrainyBubblesHome(),
    );
  }
}

class BrainyBubblesHome extends StatefulWidget {
  const BrainyBubblesHome({super.key});

  @override
  State<BrainyBubblesHome> createState() => _BrainyBubblesHomeState();
}

class _BrainyBubblesHomeState extends State<BrainyBubblesHome> {
  // ---------------- State ----------------
  final Random _rng = Random();
  final List<_Bubble> _bubbles = [];
  Timer? _spawnTimer;
  int _score = 0;

  // Settings (persisted)
  bool _lessBubbles = false;
  bool _musicOn = true;

  // Background music
  final AudioPlayer _bg = AudioPlayer();

  // ---------------- Lifecycle ----------------
  @override
  void initState() {
    super.initState();
    _loadPrefs().then((_) {
      _applyMusicState(); // start/stop music after prefs load
    });
    _startSpawning(); // start game loop
  }

  @override
  void dispose() {
    _spawnTimer?.cancel();
    _bg.dispose();
    super.dispose();
  }

  // ---------------- Prefs ----------------
  Future<void> _loadPrefs() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      _lessBubbles = p.getBool('lessBubbles') ?? false;
      _musicOn = p.getBool('musicOn') ?? true;
    });
  }

  Future<void> _savePrefs() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('lessBubbles', _lessBubbles);
    await p.setBool('musicOn', _musicOn);
  }

  // ---------------- Music ----------------
  Future<void> _applyMusicState() async {
    if (_musicOn) {
      try {
        await _bg.setReleaseMode(ReleaseMode.loop);
        // Safe: if this asset doesn't exist, we just ignore the error.
        await _bg.play(AssetSource('audio/background_music.mp3'));
      } catch (_) {
        // Asset missing or not supported on this platform — no crash.
      }
    } else {
      try {
        await _bg.stop();
      } catch (_) {}
    }
  }

  void _toggleMusic() {
    setState(() => _musicOn = !_musicOn);
    _savePrefs();
    _applyMusicState();
  }

  // ---------------- Game loop ----------------
  void _startSpawning() {
    _spawnTimer?.cancel();

    // Faster at the start; Less Bubbles slows spawns.
    // e.g., 500ms vs 1100ms
    final spawnMs = _lessBubbles ? 1100 : 500;

    _spawnTimer = Timer.periodic(Duration(milliseconds: spawnMs), (_) {
      setState(() {
        // cap total bubbles so it stays playable on low-end phones
        final cap = _lessBubbles ? 20 : 45;
        if (_bubbles.length >= cap) return;

        _bubbles.add(_Bubble(
          // use relative positions, then multiply by screen size in build
          dx: _rng.nextDouble(),
          dy: 1.05, // spawn slightly below the screen, then float up
          size: _rng.nextDouble() * 28 + 22, // 22..50 logical px
          hue: _rng.nextDouble(), // for color variation
          vy: _rng.nextDouble() * 0.012 + 0.008, // upward speed
        ));
      });
    });
  }

  void _restartGame() {
    setState(() {
      _score = 0;
      _bubbles.clear();
    });
    _startSpawning();
  }

  void _tickBubbles(Size size) {
    // Make bubbles float upward. Remove off-screen bubbles.
    _bubbles.removeWhere((b) {
      b.dy -= b.vy; // move up
      return b.dy < -0.1; // cull when off the top
    });
  }

  void _popAt(Offset tap, Size size) {
    for (int i = _bubbles.length - 1; i >= 0; i--) {
      final b = _bubbles[i];
      final pos = Offset(b.dx * size.width, b.dy * size.height);
      final r = b.size / 2;
      if ((tap - pos).distance <= r) {
        setState(() {
          _bubbles.removeAt(i);
          _score += 1;
        });
        break;
      }
    }
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Brainy Bubbles'),
        actions: [
          // Music toggle
          Row(children: [
            const SizedBox(width: 8),
            const Text('Music'),
            Switch(
              value: _musicOn,
              onChanged: (_) => _toggleMusic(),
            ),
          ]),
          // Less Bubbles toggle
          Row(children: [
            const Text('Less Bubbles'),
            Switch(
              value: _lessBubbles,
              onChanged: (v) {
                setState(() => _lessBubbles = v);
                _savePrefs();
                _startSpawning(); // restart with new spawn rate
              },
            ),
            const SizedBox(width: 8),
          ]),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);

          // Advance bubble positions once per frame using addPostFrameCallback
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _tickBubbles(size));
          });

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => _popAt(d.localPosition, size),
            child: Stack(
              children: [
                // Bubbles
                ..._bubbles.map((b) {
                  final x = b.dx * size.width;
                  final y = b.dy * size.height;
                  final color = HSVColor.fromAHSV(
                    0.9,           // alpha
                    b.hue * 360,   // hue
                    0.55,          // saturation
                    0.95,          // value
                  ).toColor();

                  return Positioned(
                    left: x - b.size / 2,
                    top: y - b.size / 2,
                    child: Container(
                      width: b.size,
                      height: b.size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withOpacity(0.85),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 6,
                            spreadRadius: 1,
                            offset: Offset(0, 2),
                          )
                        ],
                        gradient: RadialGradient(
                          colors: [
                            Colors.white.withOpacity(0.35),
                            color,
                          ],
                          center: const Alignment(-0.3, -0.4),
                          radius: 0.9,
                        ),
                      ),
                    ),
                  );
                }).toList(),

                // HUD
                Positioned(
                  left: 16,
                  bottom: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0f172a).withOpacity(0.7),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Text(
                      'Score: $_score',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

                // Restart button
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: ElevatedButton(
                    onPressed: _restartGame,
                    child: const Text('Restart'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Bubble {
  _Bubble({
    required this.dx,
    required this.dy,
    required this.size,
    required this.hue,
    required this.vy,
  });

  double dx;   // 0..1 (relative horizontal position)
  double dy;   // 0..1 (relative vertical position)
  double size; // logical pixels
  double hue;  // 0..1, used to vary color
  double vy;   // upward speed per frame
}

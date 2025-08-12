// Brainy Bubbles – Flutter Web test build (Vercel-ready)
// Mirrors the original: splash screen, target-matching bubbles, goal/timer,
// level ups with cheer messages ("YAH!"), starry pop effects, badges,
// reduced-motion + music toggle (safe if audio asset missing).
//
// You can tweak level speed/goal at the "Tuning" section.
// Inline comments explain the trickier parts so it’s easy to iterate.

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const BrainyBubblesApp());

class BrainyBubblesApp extends StatelessWidget {
  const BrainyBubblesApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Brainy Bubbles',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF6366F1),
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0b1224),
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF0f172a)),
        useMaterial3: true,
      ),
      home: const GamePage(),
    );
  }
}

// --------------------------- Models / Enums ---------------------------------

enum OverlayMode { splash, running, paused, levelup, gameover }

enum ItemKind { apple, ball, star, car, house, fish }

// One bubble in the world.
class Bubble {
  Bubble({
    required this.x,
    required this.y,
    required this.r,
    required this.vx,
    required this.vy,
    required this.hue,
    required this.item,
  });

  double x, y;      // position in logical pixels
  double r;         // radius in logical pixels
  double vx, vy;    // velocity (px/s)
  double hue;       // 0..360 for color variation
  ItemKind item;
}

// A tiny particle for pop effects (dot or star).
enum ParticleType { dot, star }

class Particle {
  Particle({
    required this.type,
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.hue,
    required this.life, // 1..0 fades out
    this.rot = 0,
    this.rotSpeed = 0,
  });
  ParticleType type;
  double x, y, vx, vy, size, hue, life, rot, rotSpeed;
}

// --------------------------- Game Widget ------------------------------------

class GamePage extends StatefulWidget {
  const GamePage({super.key});
  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> with SingleTickerProviderStateMixin {
  // Rendering ticker – drives updates @ ~60fps.
  late final Ticker _ticker;
  double _lastTs = 0;

  // World state
  final List<Bubble> _bubbles = [];
  final List<Particle> _particles = [];
  final Random _rng = Random();
  Size _canvasSize = Size.zero;

  // UI / Game flow
  OverlayMode _mode = OverlayMode.splash;
  ItemKind _target = ItemKind.values[0];
  int _level = 1;
  int _score = 0;
  int _levelScore = 0;
  int _high = 0;
  int _sessionBest = 0;

  // Timers
  double _timeLeft = 45;
  double _spawnAccumMs = 0;

  // Settings
  bool _reducedMotion = false;
  bool _musicOn = true;

  // Audio – safe: try/catch if asset missing on web
  final AudioPlayer _synth = AudioPlayer(); // for “cheer”
  final AudioPlayer _popper = AudioPlayer(); // for “pop”
  final AudioPlayer _bg = AudioPlayer(); // background loop

  // -------------------------- Lifecycle -------------------------------------

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
    _loadPrefs();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _bg.dispose();
    _synth.dispose();
    _popper.dispose();
    super.dispose();
  }

  // -------------------------- Persistence -----------------------------------

  Future<void> _loadPrefs() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      _high = p.getInt('bb_high') ?? 0;
      _reducedMotion = p.getBool('bb_rm') ?? false;
      _musicOn = p.getBool('bb_music') ?? true;
    });
    _applyMusic();
  }

  Future<void> _savePrefs() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt('bb_high', _high);
    await p.setBool('bb_rm', _reducedMotion);
    await p.setBool('bb_music', _musicOn);
  }

  // -------------------------- Tuning ----------------------------------------

  int _goalFor(int lvl) => (320 * pow(1.32, (lvl - 1))).round();
  double _timeFor(int lvl) => (_clamp(52 - (lvl - 1) * 2.5, 24, 52)).toDouble();
  double _spawnMsFor(int lvl) => _clamp(420 - (lvl - 1) * 35, 90, 420).toDouble();
  int _spawnBatchFor(int lvl) => _clamp(1 + (lvl ~/ 2), 1, 6);

  // -------------------------- Helpers ---------------------------------------

  double _clamp(double v, double lo, double hi) => v < lo ? lo : (v > hi ? hi : v);
  double _rand(double a, double b) => _rng.nextDouble() * (b - a) + a;

  // Audio safe wrappers (no crash if asset missing on web)
  Future<void> _playPop(bool target) async {
    try {
      await _popper.play(AssetSource(target ? 'audio/pop_hi.mp3' : 'audio/pop_lo.mp3'));
    } catch (_) {}
  }

  Future<void> _playCheer() async {
    try {
      await _synth.play(AssetSource('audio/cheer_triple.mp3'));
    } catch (_) {}
  }

  Future<void> _applyMusic() async {
    if (_musicOn) {
      try {
        await _bg.setReleaseMode(ReleaseMode.loop);
        await _bg.play(AssetSource('audio/background_music.mp3'));
      } catch (_) {}
    } else {
      try { await _bg.stop(); } catch (_) {}
    }
    _savePrefs();
  }

  // -------------------------- Game Flow -------------------------------------

  void _startRun() {
    setState(() {
      _score = 0;
      _level = 1;
      _timeLeft = _timeFor(1);
      _levelScore = 0;
      _mode = OverlayMode.running;
      _target = ItemKind.values[_rng.nextInt(ItemKind.values.length)];
      _bubbles.clear();
      _particles.clear();
      _spawnAccumMs = 0;
    });
  }

  void _advanceLevel() {
    setState(() {
      _level++;
      _levelScore = 0;
      _timeLeft = _timeFor(_level);
      _mode = OverlayMode.running;
      _target = ItemKind.values[_rng.nextInt(ItemKind.values.length)];
      _bubbles.clear();
      _particles.clear();
      _spawnAccumMs = 0;
    });
  }

  void _failLevel() {
    setState(() {
      _mode = OverlayMode.gameover;
      _sessionBest = max(_sessionBest, _score);
      _high = max(_high, _score);
    });
    _savePrefs();
  }

  // -------------------------- Spawn / Tap -----------------------------------

  void _spawn({ItemKind? force}) {
    if (_bubbles.length >= (_reducedMotion ? 40 : 70)) return;
    final r = _rand(22, 48);
    final x = _rand(r + 20, _canvasSize.width - r - 20);
    final y = _canvasSize.height + r + _rand(0, 80);
    final spd = _rand(40, 120);
    final ang = (-pi / 2) + _rand(-0.25, 0.25);
    final vx = cos(ang) * spd, vy = sin(ang) * spd;
    final hue = _rand(0, 360);
    final item = force ?? (_rng.nextDouble() < 0.25 ? _target : ItemKind.values[_rng.nextInt(ItemKind.values.length)]);
    _bubbles.add(Bubble(x: x, y: y, r: r, vx: vx, vy: vy, hue: hue, item: item));
  }

  void _ensureMatchingExists() {
    if (_bubbles.any((b) => b.item == _target)) return;
    _spawn(force: _target);
  }

  void _popAt(Offset p) {
    for (int i = _bubbles.length - 1; i >= 0; i--) {
      final b = _bubbles[i];
      final dx = p.dx - b.x, dy = p.dy - b.y;
      if (sqrt(dx*dx + dy*dy) <= b.r) {
        final hitTarget = b.item == _target;
        if (hitTarget) {
          final base = (_clamp(100 - b.r, 20, 95)).round();
          _score += base;
          _levelScore += base;
          _emitStarTrail(b.x, b.y, count: _reducedMotion ? 14 : 28);
        } else {
          _emitDots(b.x, b.y, hue: b.hue, count: _reducedMotion ? 8 : 16);
        }
        _playPop(hitTarget);
        _bubbles.removeAt(i);
        setState(() {}); // update HUD immediately
        break;
      }
    }
  }

  // -------------------------- Particles -------------------------------------

  void _emitDots(double x, double y, {required double hue, int count = 16}) {
    final n = _reducedMotion ? max(1, (count * .5).round()) : count;
    for (int i = 0; i < n; i++) {
      final ang = _rand(0, pi * 2);
      final sp = _rand(60, 180);
      _particles.add(Particle(
        type: ParticleType.dot,
        x: x, y: y,
        vx: cos(ang) * sp, vy: sin(ang) * sp,
        size: _rand(2, 6),
        hue: hue + _rand(-30, 30),
        life: 1,
      ));
    }
  }

  void _emitStarTrail(double x, double y, {int count = 24}) {
    final n = _reducedMotion ? max(1, (count * .5).round()) : count;
    for (int i = 0; i < n; i++) {
      final ang = _rand(0, pi * 2);
      final sp = _rand(80, 220);
      _particles.add(Particle(
        type: ParticleType.star,
        x: x, y: y,
        vx: cos(ang) * sp, vy: sin(ang) * sp,
        size: _rand(6, 12),
        hue: _rand(40, 60) + i * 3 + _rand(-10, 10),
        life: 1,
        rot: _rand(0, pi * 2),
        rotSpeed: _rand(-2, 2),
      ));
    }
  }

  // -------------------------- Tick / Render ---------------------------------

  void _onTick(Duration t) {
    final now = t.inMilliseconds / 1000.0;
    final dt = (_lastTs == 0) ? 0.0 : (now - _lastTs);
    _lastTs = now;

    if (_mode == OverlayMode.running && dt > 0) {
      _timeLeft -= dt;
      if (_timeLeft <= 0) {
        _failLevel();
      }

      _spawnAccumMs += dt * 1000.0;
      final interval = _spawnMsFor(_level);
      while (_spawnAccumMs >= interval) {
        _spawnAccumMs -= interval;
        final batch = _spawnBatchFor(_level);
        for (int i = 0; i < batch; i++) _spawn();
      }

      // Move bubbles upward
      for (final b in _bubbles) {
        b.x += b.vx * dt * 0.3;
        b.y += b.vy * dt * 0.6 - 10 * dt;
      }
      _bubbles.removeWhere((b) => b.y + b.r < -60);

      // Particles integration
      for (final p in _particles) {
        p.x += p.vx * dt;
        p.y += p.vy * dt;
        p.vx *= 0.985;
        p.vy *= 0.985;
        p.life -= dt * 1.2;
        p.rot += p.rotSpeed * dt;
      }
      _particles.removeWhere((p) => p.life <= 0);

      // Occasionally guarantee a matching bubble is present
      if ((now * 1000).toInt() % 1200 < 16) _ensureMatchingExists();

      // Level complete?
      if (_levelScore >= _goalFor(_level)) {
        _playCheer();
        setState(() => _mode = OverlayMode.levelup);
      }

      setState(() {}); // schedule paint
    }
  }

  // -------------------------- UI pieces -------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Brainy Bubbles'),
        actions: [
          // Music toggle
          Row(children: [
            const Text('Music', style: TextStyle(fontSize: 12)),
            Switch(value: _musicOn, onChanged: (_) { setState(()=>_musicOn=!_musicOn); _applyMusic(); }),
          ]),
          // Reduced motion
          Row(children: [
            const Text('Gentle', style: TextStyle(fontSize: 12)),
            Switch(value: _reducedMotion, onChanged: (v) { setState(()=>_reducedMotion=v); _savePrefs(); }),
            const SizedBox(width: 8),
          ]),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, c) {
          _canvasSize = Size(c.maxWidth, c.maxHeight);

          return Stack(
            children: [
              // Game canvas
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) {
                  if (_mode == OverlayMode.running) _popAt(d.localPosition);
                },
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _GamePainter(
                    size: _canvasSize,
                    bubbles: _bubbles,
                    particles: _particles,
                    target: _target,
                    progress: _levelScore / _goalFor(_level),
                  ),
                ),
              ),

              // HUD (badges)
              Positioned(
                left: 12, right: 12, top: 8,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Target preview
                    _TargetPreview(kind: _target),
                    Row(children: [
                      _Badge(icon: '⭐', label: 'Points', value: '$_score'),
                      const SizedBox(width: 8),
                      _Badge(icon: '🏆', label: 'Best', value: '$_sessionBest'),
                      const SizedBox(width: 8),
                      _Badge(icon: '⏱', label: 'Time', value: '${_timeLeft.ceil()}s'),
                    ]),
                  ],
                ),
              ),

              // Progress bar + hint
              Positioned(
                left: 12, right: 12, top: 78,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: (_levelScore/_goalFor(_level)).clamp(0,1).toDouble(),
                        minHeight: 8,
                        backgroundColor: const Color(0xFF1f2937),
                        color: const Color(0xFF6366F1),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text('Pop the bubble that matches the picture. Smaller bubbles = more points.',
                      style: TextStyle(fontSize: 12, color: Color(0xFFcbd5e1))),
                  ],
                ),
              ),

              // Overlays
              if (_mode == OverlayMode.splash) _buildSplash(),
              if (_mode == OverlayMode.levelup) _buildLevelUp(),
              if (_mode == OverlayMode.gameover) _buildGameOver(),

              // Pause button
              if (_mode == OverlayMode.running)
                Positioned(
                  right: 12, top: 8 + 78 + 10,
                  child: FilledButton.tonal(
                    onPressed: ()=>setState(()=>_mode=OverlayMode.paused),
                    child: const Text('Pause'),
                  ),
                ),

              if (_mode == OverlayMode.paused) _buildPaused(),
            ],
          );
        },
      ),
    );
  }

  // Splash cover
  Widget _buildSplash() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(.45),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF0f172a).withOpacity(.8),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Brainy Bubbles', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                const Text('Tap to think fast & pop the matching picture.',
                    style: TextStyle(color: Color(0xFFcbd5e1))),
                const SizedBox(height: 16),
                FilledButton(onPressed: _startRun, child: const Text('Tap to Start')),
                const SizedBox(height: 10),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Text('Gentle motion', style: TextStyle(fontSize: 12, color: Color(0xFFcbd5e1))),
                  Switch(value: _reducedMotion, onChanged: (v){ setState(()=>_reducedMotion=v); _savePrefs(); }),
                ]),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Text('Music', style: TextStyle(fontSize: 12, color: Color(0xFFcbd5e1))),
                  Switch(value: _musicOn, onChanged: (v){ setState(()=>_musicOn=v); _applyMusic(); }),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Paused overlay
  Widget _buildPaused() {
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
                const Text('Paused', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Wrap(spacing: 10, children: [
                  FilledButton(onPressed: ()=>setState(()=>_mode=OverlayMode.running), child: const Text('Resume')),
                  FilledButton.tonal(onPressed: _startRun, child: const Text('Restart')),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Level-up overlay
  Widget _buildLevelUp() {
    final cheers = ['Great!', 'Nice!', 'Awesome!', 'Woo!', 'YAH!'];
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
                Text(cheers[_rng.nextInt(cheers.length)],
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text('Level $_level cleared! Next goal → ${_goalFor(_level + 1)}',
                    style: const TextStyle(color: Color(0xFFcbd5e1))),
                const SizedBox(height: 12),
                FilledButton(onPressed: _advanceLevel, child: const Text('Next Level')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Game-over overlay
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
                Text('Session Best: $_sessionBest', style: const TextStyle(color: Color(0xFFcbd5e1))),
                Text('High (Saved): $_high', style: const TextStyle(color: Color(0xFFcbd5e1))),
                const SizedBox(height: 12),
                FilledButton(onPressed: _startRun, child: const Text('Try Again')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --------------------------- Painters ---------------------------------------

class _GamePainter extends CustomPainter {
  _GamePainter({
    required this.size,
    required this.bubbles,
    required this.particles,
    required this.target,
    required this.progress,
  });

  final Size size;
  final List<Bubble> bubbles;
  final List<Particle> particles;
  final ItemKind target;
  final double progress;

  @override
  void paint(Canvas canvas, Size _) {
    // Background gradient
    final bg = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF0f172a), Color(0xFF0b1224)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bg);

    // Bubbles
    for (final b in bubbles) {
      final center = Offset(b.x, b.y);
      // Glossy bubble gradient
      final grad = RadialGradient(
        center: const Alignment(-0.3, -0.4),
        radius: 0.9,
        colors: [
          HSLColor.fromAHSL(.85, b.hue, .8, .9).toColor(),
          HSLColor.fromAHSL(.28, b.hue, .7, .55).toColor(),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: b.r));
      final bubblePaint = Paint()..shader = grad;
      canvas.drawCircle(center, b.r, bubblePaint);

      // Highlight
      final hi = Paint()..color = Colors.white.withOpacity(.35);
      canvas.drawOval(
        Rect.fromCenter(center: center.translate(-b.r * .4, -b.r * .6),
            width: b.r * .8, height: b.r * .4),
        hi,
      );

      // Item drawing inside the bubble
      _drawItem(canvas, center, b.r * 1.4, b.item);
    }

    // Particles
    for (final p in particles) {
      final alpha = p.life.clamp(0, 1).toDouble();
      final color = HSLColor.fromAHSL(alpha, p.hue, .9, .65).toColor();
      if (p.type == ParticleType.dot) {
        final paint = Paint()..color = color;
        canvas.drawCircle(Offset(p.x, p.y), p.size, paint);
      } else {
        // star
        canvas.save();
        canvas.translate(p.x, p.y);
        canvas.rotate(p.rot);
        final path = Path();
        const spikes = 5;
        final outer = p.size, inner = p.size * .5;
        for (int i = 0; i < spikes * 2; i++) {
          final r = (i % 2 == 0) ? outer : inner;
          final a = (i * pi) / spikes - pi / 2;
          final pt = Offset(cos(a) * r, sin(a) * r);
          if (i == 0) {
            path.moveTo(pt.dx, pt.dy);
          } else {
            path.lineTo(pt.dx, pt.dy);
          }
        }
        path.close();
        final paint = Paint()..color = color;
        canvas.drawPath(path, paint);
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GamePainter old) =>
      old.bubbles != bubbles || old.particles != particles || old.progress != progress || old.target != target;

  // Cartoon item drawings (very lightweight, no image assets required)
  void _drawItem(Canvas canvas, Offset c, double s, ItemKind k) {
    final stroke = Paint()
      ..color = const Color(0xFF1f2937)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    switch (k) {
      case ItemKind.apple:
        final red = Paint()..color = const Color(0xFFef4444);
        canvas.drawOval(Rect.fromCenter(center: c, width: s * .7, height: s * .8), red);
        final leaf = Paint()..color = const Color(0xFF16a34a);
        canvas.drawOval(Rect.fromCenter(center: c.translate(s * .1, -s * .4), width: s * .36, height: s * .2), leaf);
        canvas.drawLine(c.translate(0, -s * .45), c.translate(0, -s * .6), stroke);
        canvas.drawOval(Rect.fromCenter(center: c, width: s * .7, height: s * .8), stroke);
        break;
      case ItemKind.ball:
        final white = Paint()..color = Colors.white;
        canvas.drawCircle(c, s * .38, white);
        final colors = [0xFFF59E0B, 0xFF3B82F6, 0xFF10B981, 0xFFEF4444].map((e) => Paint()..color = Color(e));
        double start = 0;
        for (final p in colors) {
          final path = Path()..moveTo(c.dx, c.dy);
          path.arcTo(Rect.fromCircle(center: c, radius: s * .38), start, pi / 2, false);
          path.close();
          canvas.drawPath(path, p);
          start += pi / 2;
        }
        canvas.drawCircle(c, s * .38, stroke);
        break;
      case ItemKind.star:
        final yellow = Paint()..color = const Color(0xFFFACC15);
        final path = Path();
        const spikes = 5;
        final r1 = s * .38, r2 = s * .18;
        for (int i = 0; i < spikes * 2; i++) {
          final r = i.isEven ? r1 : r2;
          final a = (i * pi) / spikes - pi / 2;
          final pt = Offset(c.dx + cos(a) * r, c.dy + sin(a) * r);
          if (i == 0) path.moveTo(pt.dx, pt.dy); else path.lineTo(pt.dx, pt.dy);
        }
        path.close(); canvas.drawPath(path, yellow); canvas.drawPath(path, stroke);
        break;
      case ItemKind.car:
        final body = Paint()..color = const Color(0xFF60a5fa);
        final rect = RRect.fromRectAndRadius(
            Rect.fromCenter(center: c.translate(0, s * .05), width: s * .8, height: s * .35),
            const Radius.circular(8));
        canvas.drawRRect(rect, body); canvas.drawRRect(rect, stroke);
        final wheel = Paint()..color = const Color(0xFF111827);
        canvas.drawCircle(c.translate(-s * .22, s * .22), s * .12, wheel);
        canvas.drawCircle(c.translate( s * .22, s * .22), s * .12, wheel);
        break;
      case ItemKind.house:
        final base = Paint()..color = const Color(0xFFF87171);
        final brect = RRect.fromRectAndRadius(
            Rect.fromCenter(center: c.translate(0, s * .14), width: s * .7, height: s * .45),
            const Radius.circular(6));
        canvas.drawRRect(brect, base); canvas.drawRRect(brect, stroke);
        final roof = Paint()..color = const Color(0xFF92400e);
        final path = Path()
          ..moveTo(c.dx - s * .4, c.dy - s * .1)
          ..lineTo(c.dx, c.dy - s * .45)
          ..lineTo(c.dx + s * .4, c.dy - s * .1)
          ..close();
        canvas.drawPath(path, roof); canvas.drawPath(path, stroke);
        break;
      case ItemKind.fish:
        final body = Paint()..color = const Color(0xFF34d399);
        canvas.drawOval(Rect.fromCenter(center: c, width: s * .68, height: s * .44), body);
        final tail = Path()
          ..moveTo(c.dx - s * .34, c.dy)
          ..lineTo(c.dx - s * .5, c.dy - s * .15)
          ..lineTo(c.dx - s * .5, c.dy + s * .15)
          ..close();
        canvas.drawPath(tail, body); canvas.drawOval(Rect.fromCenter(center: c, width: s * .68, height: s * .44), stroke);
        break;
    }
  }
}

class _TargetPreview extends StatelessWidget {
  const _TargetPreview({required this.kind});
  final ItemKind kind;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64, height: 64,
      decoration: BoxDecoration(
        color: const Color(0xFF0f172a),
        border: Border.all(color: const Color(0xFF334155)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: CustomPaint(
        painter: _TargetPainter(kind),
      ),
    );
  }
}

class _TargetPainter extends CustomPainter {
  _TargetPainter(this.kind);
  final ItemKind kind;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width/2, size.height/2 + 2);
    final s = size.shortestSide * .9;
    _GamePainter(size: size, bubbles: const [], particles: const [], target: kind, progress: 0)
        ._drawItem(canvas, c, s, kind);
  }

  @override
  bool shouldRepaint(covariant _TargetPainter oldDelegate) => oldDelegate.kind != kind;
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.label, required this.value});
  final String icon, label, value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0f172a).withOpacity(.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$icon $value', style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFFcbd5e1))),
        ],
      ),
    );
  }
}

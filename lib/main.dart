import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const BrainyBubblesApp());
}

class BrainyBubblesApp extends StatelessWidget {
  const BrainyBubblesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Brainy Bubbles',
      theme: ThemeData(
        primarySwatch: Colors.blue,
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
  final Random _random = Random();
  List<Offset> _bubbles = [];
  Timer? _bubbleTimer;
  int _score = 0;
  bool _lessBubbles = false;
  bool _musicOn = true;
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _startGame();
    _playMusic();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _lessBubbles = prefs.getBool('lessBubbles') ?? false;
      _musicOn = prefs.getBool('musicOn') ?? true;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool('lessBubbles', _lessBubbles);
    prefs.setBool('musicOn', _musicOn);
  }

  void _playMusic() async {
    if (_musicOn) {
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.play(AssetSource('audio/brainy_bubbles_bg.mp3'));
    } else {
      await _audioPlayer.stop();
    }
  }

  void _startGame() {
    _score = 0;
    _bubbles = [];
    _bubbleTimer?.cancel();

    // Faster spawn rate at start
    final spawnRate = _lessBubbles ? 1200 : 600;

    _bubbleTimer = Timer.periodic(Duration(milliseconds: spawnRate), (timer) {
      setState(() {
        _bubbles.add(Offset(
          _random.nextDouble(),
          _random.nextDouble(),
        ));
      });
    });
  }

  void _popBubble(int index) {
    setState(() {
      _bubbles.removeAt(index);
      _score++;
    });
  }

  @override
  void dispose() {
    _bubbleTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Brainy Bubbles'),
        actions: [
          Row(
            children: [
              const Text("Less Bubbles"),
              Switch(
                value: _lessBubbles,
                onChanged: (value) {
                  setState(() {
                    _lessBubbles = value;
                  });
                  _saveSettings();
                  _startGame();
                },
              ),
            ],
          ),
          Row(
            children: [
              const Text("Music"),
              Switch(
                value: _musicOn,
                onChanged: (value) {
                  setState(() {
                    _musicOn = value;
                  });
                  _saveSettings();
                  _playMusic();
                },
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          ..._bubbles.asMap().entries.map((entry) {
            final index = entry.key;
            final pos = entry.value;
            return Positioned(
              left: pos.dx * MediaQuery.of(context).size.width,
              top: pos.dy * MediaQuery.of(context).size.height,
              child: GestureDetector(
                onTap: () => _popBubble(index),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.blueAccent,
                  ),
                ),
              ),
            );
          }),
          Positioned(
            bottom: 20,
            left: 20,
            child: Text(
              'Score: $_score',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          )
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(BrainyBubblesApp());
}

class BrainyBubblesApp extends StatefulWidget {
  @override
  _BrainyBubblesAppState createState() => _BrainyBubblesAppState();
}

class _BrainyBubblesAppState extends State<BrainyBubblesApp> {
  late AudioPlayer _audioPlayer;
  bool _isMusicOn = true;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _isMusicOn = prefs.getBool('musicOn') ?? true;
    });
    if (_isMusicOn) {
      _playMusic();
    }
  }

  Future<void> _saveSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setBool('musicOn', _isMusicOn);
  }

  void _playMusic() {
    _audioPlayer.setReleaseMode(ReleaseMode.loop);
    _audioPlayer.play(AssetSource('audio/background_music.mp3'));
  }

  void _stopMusic() {
    _audioPlayer.stop();
  }

  void _toggleMusic() {
    setState(() {
      _isMusicOn = !_isMusicOn;
      if (_isMusicOn) {
        _playMusic();
      } else {
        _stopMusic();
      }
      _saveSettings();
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Brainy Bubbles',
      home: Scaffold(
        appBar: AppBar(
          title: Text('Brainy Bubbles'),
          actions: [
            IconButton(
              icon: Icon(_isMusicOn ? Icons.music_note : Icons.music_off),
              onPressed: _toggleMusic,
            )
          ],
        ),
        body: Center(
          child: Text(
            '🎮 Brainy Bubbles Game Here 🎮',
            style: TextStyle(fontSize: 24),
          ),
        ),
      ),
    );
  }
}

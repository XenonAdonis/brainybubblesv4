import 'package:flutter/material.dart';

void main() => runApp(const BrainyBubblesApp());

class BrainyBubblesApp extends StatelessWidget {
  const BrainyBubblesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Brainy Bubbles',
      debugShowCheckedModeBanner: false,
      home: const Scaffold(
        backgroundColor: Color(0xFF0b1224),
        body: Center(
          child: Text('Brainy Bubbles is live!',
              style: TextStyle(color: Colors.white, fontSize: 24)),
        ),
      ),
    );
  }
}

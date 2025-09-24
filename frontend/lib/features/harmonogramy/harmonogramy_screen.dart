import 'package:flutter/material.dart';

class HarmonogramyScreen extends StatelessWidget {
  const HarmonogramyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Harmonogramy'),
      ),
      body: const Center(
        child: Text(
          'Tu pojawi się lista harmonogramów',
          style: TextStyle(fontSize: 16),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}


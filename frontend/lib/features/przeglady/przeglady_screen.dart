import 'package:flutter/material.dart';

class PrzegladyScreen extends StatelessWidget {
  const PrzegladyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Przeglądy'),
      ),
      body: const Center(
        child: Text(
          'Tu pojawi się lista przeglądów',
          style: TextStyle(fontSize: 16),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}


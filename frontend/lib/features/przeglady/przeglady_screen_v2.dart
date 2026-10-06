import 'package:flutter/material.dart';

import '../harmonogramy/harmonogramy_screen.dart';

/// Tymczasowy, stabilny ekran `Przeglądy`.
///
/// Oryginalny plik był strukturalnie uszkodzony (niedomknięte nawiasy i
/// przemieszane fragmenty kodu), więc delegujemy do działającego ekranu
/// harmonogramów, który obsługuje częstotliwości cykliczne (w tym 2 i 5 lat).
class PrzegladyScreen extends StatelessWidget {
  const PrzegladyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const HarmonogramyScreen();
  }
}

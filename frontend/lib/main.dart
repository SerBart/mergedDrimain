import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';

const String apiBase =
String.fromEnvironment('API_BASE', defaultValue: ''); // same-origin by default

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(ProviderScope(child: DrimainApp(apiBase: apiBase)));
}
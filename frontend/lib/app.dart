import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'router.dart';
import 'services/auth_service.dart';

class DrimainApp extends ConsumerWidget {
  final String apiBase;
  const DrimainApp({super.key, required this.apiBase});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.read(authServiceProvider).configure(baseUrl: apiBase);
    final router = createRouter(ref);

    return MaterialApp.router(
      title: 'DriMain',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}
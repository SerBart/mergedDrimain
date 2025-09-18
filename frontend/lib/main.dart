import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'routing/app_router.dart'; // plik z providerem routera (poniżej przykład)

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: TPMApp()));
}

class TPMApp extends ConsumerWidget {
  const TPMApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider); // Provider<GoRouter>
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'TPM Suite',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      routerConfig: router,
    );
  }
}
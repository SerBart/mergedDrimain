import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'core/theme/app_theme.dart';
import 'routing/app_router.dart'; // plik z providerem routera (poniżej przykład)
import 'core/utils/notification_router.dart';
import 'core/models/notification.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: TPMApp()));
}

class TPMApp extends ConsumerStatefulWidget {
  const TPMApp({super.key});

  @override
  ConsumerState<TPMApp> createState() => _TPMAppState();
}

class _TPMAppState extends ConsumerState<TPMApp> {
  @override
  void initState() {
    super.initState();

    // Run async init after first frame so `ref` is available and context is mounted
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await Firebase.initializeApp();
      } catch (e) {
        // ignore if already initialized or fails in environments without Firebase setup
      }

      // Handle when app is opened from terminated state by a notification
      try {
        final initial = await FirebaseMessaging.instance.getInitialMessage();
        if (initial != null) {
          _handleRemoteMessage(initial);
        }
      } catch (_) {}

      // Handle when app is in background and opened via notification
      try {
        FirebaseMessaging.onMessageOpenedApp.listen((message) {
          _handleRemoteMessage(message);
        });
      } catch (_) {}
    });
  }

  void _handleRemoteMessage(RemoteMessage? message) {
    if (message == null) return;

    // Map RemoteMessage to our NotificationModel (best-effort)
    final data = message.data;
    final title = message.notification?.title ?? data['title']?.toString();
    final body = message.notification?.body ?? data['message']?.toString() ?? data['body']?.toString();
    final link = data['link']?.toString() ?? data['url']?.toString();
    final module = data['module']?.toString();
    final type = data['type']?.toString();
    int id = 0;
    try {
      final sid = data['id']?.toString();
      if (sid != null) id = int.tryParse(sid) ?? 0;
    } catch (_) {}

    final nm = NotificationModel(
      id: id,
      module: module,
      type: type,
      title: title,
      message: body,
      link: link,
      createdAt: DateTime.now(),
      read: false,
    );

    final target = routeFromNotificationModel(nm);
    if (!target.startsWith('/')) return; // keep invariant

    try {
      ref.read(appRouterProvider).go(target);
    } catch (e) {
      // ignore navigation errors
    }
  }

  @override
  Widget build(BuildContext context) {
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
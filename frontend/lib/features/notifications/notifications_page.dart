import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/notification.dart';
import '../../core/providers/app_providers.dart';
import '../../core/utils/notification_router.dart';
import '../../widgets/top_app_bar.dart';

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  bool _markingDone = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markAllReadOnce();
    });
  }

  Future<void> _markAllReadOnce() async {
    if (_markingDone) return;
    _markingDone = true;
    try {
      final repo = ref.read(notificationsApiRepositoryProvider);
      await repo.markAllRead();
    } catch (_) {
      // Keep UI usable even if mark endpoint fails.
    } finally {
      // Force refresh so badges in AppBar/Dashboard recalculate unread count.
      ref.invalidate(notificationsListProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifsAsync = ref.watch(notificationsListProvider);

    return Scaffold(
      appBar: const TopAppBar(title: 'Powiadomienia', showBack: true),
      body: notifsAsync.when(
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('Brak powiadomień'));
          }
          return ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (ctx, idx) {
              final NotificationModel n = list[idx];
              final created = n.createdAt != null ? n.createdAt!.toLocal().toString() : '';
              return ListTile(
                title: Text(n.title ?? (n.message ?? 'Bez tytułu')),
                subtitle: Text(n.message ?? ''),
                trailing: Text(created, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                onTap: () {
                  try {
                    final target = routeFromNotificationModel(n);
                    ctx.go(target);
                  } catch (_) {}
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Błąd ładowania powiadomień: ${e.toString()}')),
      ),
    );
  }
}

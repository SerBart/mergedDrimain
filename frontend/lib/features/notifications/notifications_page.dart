import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/app_providers.dart';
import '../../core/models/notification.dart';
import '../../widgets/top_app_bar.dart';
import '../../core/utils/notification_router.dart';

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

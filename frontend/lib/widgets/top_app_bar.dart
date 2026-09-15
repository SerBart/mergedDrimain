import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../core/providers/app_providers.dart';
import '../routing/app_router.dart';

class TopAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final String? title;
  final bool showBack;
  final List<Widget>? extraActions;

  const TopAppBar({super.key, this.title, this.showBack = false, this.extraActions});

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    final notifsAsync = ref.watch(notificationsListProvider);
    final versionFuture = PackageInfo.fromPlatform();
    final username = auth?.username ?? '';
    final initials = username.isNotEmpty ? username.substring(0, 1).toUpperCase() : '';
    final scheme = Theme.of(context).colorScheme;

    void goDashboard() {
      try {
        ref.read(appRouterProvider).go('/dashboard');
      } catch (_) {
        try {
          GoRouter.of(context).go('/dashboard');
        } catch (_) {}
      }
    }

    return AppBar(
      automaticallyImplyLeading: false,
      leading: null,
      elevation: 6,
      backgroundColor: scheme.primary,
      surfaceTintColor: Colors.transparent,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [scheme.primary, scheme.secondary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: scheme.primary.withOpacity(0.32),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
      ),
      title: Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: goDashboard,
            child: Container(
              width: 92,
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  colors: [Colors.white.withOpacity(0.22), Colors.white.withOpacity(0.08)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: Colors.white.withOpacity(0.22)),
              ),
              child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null)
                  Text(
                    title!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                Text('DriMain', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.95))),
              ],
            ),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (extraActions != null) ...extraActions!,
              _SessionCountdown(token: auth?.token),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    tooltip: 'Powiadomienia',
                    icon: const Icon(Icons.notifications, color: Colors.white),
                    onPressed: () {
                      try {
                        context.go('/notifications');
                      } catch (_) {
                        try {
                          ref.read(appRouterProvider).go('/notifications');
                        } catch (_) {}
                      }
                    },
                  ),
                  Positioned(
                    right: 6,
                    top: 10,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Center(
                        child: notifsAsync.when(
                          data: (list) {
                            final unread = list.where((n) => !n.read).length;
                            if (unread <= 0) return const SizedBox.shrink();
                            return Text(
                              '$unread',
                              style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                            );
                          },
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              PopupMenuButton<int>(
                color: Colors.white,
                offset: const Offset(0, 50),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.white24,
                  child: Text(initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
                onSelected: (v) async {
                  if (v == 1) {
                    try {
                      context.go('/profil');
                    } catch (_) {
                      try {
                        ref.read(appRouterProvider).go('/profil');
                      } catch (_) {}
                    }
                  } else if (v == 2) {
                    await ref.read(authStateProvider.notifier).logout();
                    if (context.mounted) context.go('/login');
                  }
                },
                itemBuilder: (ctx) => const [
                  PopupMenuItem(value: 1, child: Text('Moj profil')),
                  PopupMenuDivider(),
                  PopupMenuItem(value: 2, child: Text('Wyloguj')),
                ],
              ),
              const SizedBox(width: 8),
              PopupMenuButton<int>(
                color: Colors.white,
                icon: const Icon(Icons.more_vert, color: Colors.white),
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    value: 0,
                    child: FutureBuilder<PackageInfo>(
                      future: versionFuture,
                      builder: (ctx, snap) {
                        final ver = snap.hasData ? snap.data!.version : '...';
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Wersja'),
                            Text(ver, style: const TextStyle(fontWeight: FontWeight.w700)),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SessionCountdown extends StatelessWidget {
  const _SessionCountdown({required this.token});

  final String? token;

  @override
  Widget build(BuildContext context) {
    if (token == null || token!.isEmpty) return const SizedBox.shrink();

    final compact = MediaQuery.of(context).size.width < 420;
    return StreamBuilder<int>(
      stream: Stream<int>.periodic(const Duration(seconds: 1), (x) => x),
      initialData: 0,
      builder: (context, _) {
        final remaining = _remaining(token!);
        if (remaining == null) return const SizedBox.shrink();
        final text = compact ? _formatCompact(remaining) : 'Sesja ${_formatLong(remaining)}';

        return Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.18),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.25)),
          ),
          child: Text(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        );
      },
    );
  }

  Duration? _remaining(String jwt) {
    try {
      final parts = jwt.split('.');
      if (parts.length < 2) return null;
      final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final map = jsonDecode(payload) as Map<String, dynamic>;
      final exp = map['exp'];
      if (exp is! num) return null;
      final expiresAt = DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000, isUtc: true).toLocal();
      final d = expiresAt.difference(DateTime.now());
      return d.isNegative ? Duration.zero : d;
    } catch (_) {
      return null;
    }
  }

  String _formatCompact(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _formatLong(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

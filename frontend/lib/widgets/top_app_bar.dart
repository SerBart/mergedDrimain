import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../core/providers/app_providers.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Reusable, modern top app bar used across screens.
/// Shows logo, app name and logout button. Implements PreferredSizeWidget
class TopAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final String? title;
  const TopAppBar({Key? key, this.title}) : super(key: key);

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    final username = auth?.username ?? '';
    final initials = username.isNotEmpty ? username.substring(0, 1).toUpperCase() : '';

    // Attempt to load package info asynchronously via a FutureBuilder
    final versionFuture = PackageInfo.fromPlatform();

    // Watch notifications provider (AsyncValue)
    final notifsAsync = ref.watch(notificationsListProvider);

    return AppBar(
      automaticallyImplyLeading: false,
      elevation: 6,
      backgroundColor: Colors.transparent,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.indigo.shade800, Colors.indigo.shade400],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 10, offset: Offset(0, 4)),
          ],
        ),
      ),
      title: Row(
        children: [
          // Logo container with subtle border and rounded corners
          Container(
            width: 48,
            height: 48,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            // Prefer SVG if available, fallback to PNG
            child: Builder(builder: (ctx) {
              try {
                return SvgPicture.asset('assets/images/logo.svg', fit: BoxFit.contain);
              } catch (_) {
                return Image.asset('assets/images/logo.png', fit: BoxFit.contain);
              }
            }),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title != null)
                Text(title!, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
              Text('DriMain', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.95))),
            ],
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            children: [
              // Notifications icon with badge
              Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    tooltip: 'Powiadomienia',
                    icon: const Icon(Icons.notifications, color: Colors.white),
                    onPressed: () {
                      context.go('/notifications');
                    },
                  ),
                  Positioned(
                    right: 6,
                    top: 10,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)]),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Center(
                        child: notifsAsync.when(
                          data: (list) => Text(
                            '${list.length}',
                            style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          loading: () => const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                          error: (_, __) => const Text('0', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              // show small user avatar
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.white24,
                child: Text(initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
              // Profile menu with version and logout
              PopupMenuButton<int>(
                color: Colors.white,
                icon: const Icon(Icons.more_vert, color: Colors.white),
                onSelected: (v) async {
                  if (v == 1) {
                    // logout
                    await ref.read(authStateProvider.notifier).logout();
                    if (context.mounted) context.go('/login');
                  }
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem(value: 0, child: FutureBuilder<PackageInfo>(
                    future: versionFuture,
                    builder: (ctx, snap) {
                      final ver = snap.hasData ? snap.data!.version : '...';
                      return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Wersja'), Text(ver, style: TextStyle(fontWeight: FontWeight.w700))]);
                    },
                  )),
                  const PopupMenuDivider(),
                  const PopupMenuItem(value: 1, child: Text('Wyloguj')),
                ],
              ),
            ],
          ),
        )
      ],
    );
  }
}

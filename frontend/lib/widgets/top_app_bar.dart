import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../core/providers/app_providers.dart';
import '../routing/app_router.dart';
import '../core/utils/web_nav.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../core/models/notification.dart';

/// Reusable, modern top app bar used across screens.
/// Shows logo, app name and logout button. Implements PreferredSizeWidget
class TopAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final String? title;
  final bool showBack;
  final List<Widget>? extraActions;
  const TopAppBar({Key? key, this.title, this.showBack = false, this.extraActions}) : super(key: key);

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
      leading: showBack
          ? IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              tooltip: 'Powrót',
              onPressed: () async {
                // Close any dialogs/overlays (use root navigator)
                try {
                  Navigator.of(context, rootNavigator: true).popUntil((r) => r.isFirst);
                } catch (_) {}

                // Debug info: print and briefly show current GoRouter location if available
                try {
                  final loc = GoRouter.of(context).location;
                  debugPrint('[TopAppBar] current location: $loc');
                  if (ScaffoldMessenger.maybeOf(context) != null) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Aktualna ścieżka: $loc'), duration: Duration(seconds: 2)));
                  }
                } catch (_) {}

                // Try direct context-based navigation first (uses nearest router)
                try {
                  GoRouter.of(context).go('/dashboard');
                  return;
                } catch (e1, s1) {
                  debugPrint('[TopAppBar] context.go failed: $e1\n$s1');
                }

                // Fallback to provider router
                try {
                  ref.read(appRouterProvider).goNamed('dashboard');
                  return;
                } catch (e2, s2) {
                  debugPrint('[TopAppBar] provider.goNamed failed: $e2\n$s2');
                }

                // Final attempt: provider absolute path
                try {
                  ref.read(appRouterProvider).go('/dashboard');
                  return;
                } catch (e3, s3) {
                  debugPrint('[TopAppBar] provider.go failed: $e3\n$s3');
                  // Try forcing a full-page navigation on web as last resort
                  try {
                    navigateToDashboardWeb();
                    return;
                  } catch (_) {}
                  if (ScaffoldMessenger.maybeOf(context) != null) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Nie można przejść do panelu głównego: $e3')));
                  }
                }
              },
            )
          : null,
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
              // render any extra actions provided by screens (e.g. save button)
              if (extraActions != null) ...extraActions!,
               // Notifications icon with badge
               Stack(
                 clipBehavior: Clip.none,
                 children: [
                   // use Builder to get correct context for positioning
                   Builder(builder: (buttonContext) {
                     return IconButton(
                       tooltip: 'Powiadomienia',
                       icon: const Icon(Icons.notifications, color: Colors.white),
                       onPressed: () async {
                         try {
                           // Mark all read via repository, then refresh provider so badge updates
                           final repo = ref.read(notificationsApiRepositoryProvider);
                           // call markAllRead and get updated list
                           final updated = await repo.markAllRead();
                           // refresh provider
                           ref.refresh(notificationsListProvider);
                           // compute menu position anchored to the icon
                           final RenderBox button = buttonContext.findRenderObject() as RenderBox;
                           final overlay = Overlay.of(buttonContext)!.context.findRenderObject() as RenderBox;
                           final RelativeRect position = RelativeRect.fromRect(
                             Rect.fromPoints(
                               button.localToGlobal(Offset.zero, ancestor: overlay),
                               button.localToGlobal(button.size.bottomRight(Offset.zero), ancestor: overlay),
                             ),
                             Offset.zero & overlay.size,
                           );

                           // Build menu entries from updated list (preview up to 5)
                           final preview = updated.length > 5 ? updated.sublist(0, 5) : updated;
                           final items = preview.map((n) => PopupMenuItem<NotificationModel>(
                             value: n,
                             child: ListTile(
                               title: Text(n.title ?? (n.message ?? 'Bez tytułu')),
                               subtitle: Text(n.message ?? ''),
                               trailing: Text(n.createdAt != null ? n.createdAt!.toLocal().toString() : '', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                             ),
                           )).toList();

                           if (items.isEmpty) {
                             // show a simple menu with 'Brak powiadomień'
                             await showMenu(context: buttonContext, position: position, items: [const PopupMenuItem(child: Text('Brak powiadomień'))]);
                           } else {
                             final selected = await showMenu<NotificationModel>(context: buttonContext, position: position, items: items);
                             if (selected != null && selected.link != null && selected.link!.isNotEmpty) {
                               try { buttonContext.go(selected.link!); } catch (_) {}
                             }
                           }
                         } catch (e) {
                           // fallback: open full notifications page
                           context.go('/notifications');
                         }
                       },
                     );
                   }),
                   Positioned(
                     right: 6,
                     top: 10,
                     child: Container(
                       padding: const EdgeInsets.all(2),
                       decoration: BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)]),
                       constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                       child: Center(
                         child: notifsAsync.when(
                           data: (list) {
                             final unread = list.where((n) => !n.read).length;
                             return Text(
                               '$unread',
                               style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                             );
                           },
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

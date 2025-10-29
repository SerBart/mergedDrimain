import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/app_providers.dart';
import '../../core/constants/app_roles.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    final isAdmin = auth?.role == AppRoles.admin;
    final modules = auth?.modules ?? const {};

    bool has(String moduleKey) => modules.any((m) => m.toLowerCase() == moduleKey.toLowerCase());

    final items = [
      _DashboardItem(
        icon: FontAwesomeIcons.fileCircleCheck,
        label: 'Raporty',
        color: Colors.indigo,
        onTap: () => context.go('/raporty'),
        requiredModule: 'Raporty',
        hasAccess: has('Raporty'),
      ),
      _DashboardItem(
        icon: FontAwesomeIcons.triangleExclamation,
        label: 'Zgłoszenia',
        color: Colors.orange.shade700,
        onTap: () => context.go('/zgloszenia'),
        requiredModule: 'Zgloszenia',
        hasAccess: has('Zgloszenia'),
      ),
      _DashboardItem(
        icon: FontAwesomeIcons.calendarDays,
        label: 'Harmonogramy',
        color: Colors.green.shade700,
        onTap: () => context.go('/harmonogramy'),
        requiredModule: 'Harmonogramy',
        hasAccess: has('Harmonogramy'),
      ),
      _DashboardItem(
        icon: FontAwesomeIcons.clipboardCheck,
        label: 'Przeglądy',
        color: Colors.blueGrey,
        onTap: () => context.go('/przeglady'),
        // Brak wymogu modułu – pozostawiamy dostęp
      ),
      _DashboardItem(
        icon: Icons.menu_book_outlined,
        label: 'Instrukcje napraw',
        color: Colors.brown,
        onTap: () => context.go('/instrukcje'),
        requiredModule: 'Instrukcje',
        hasAccess: has('Instrukcje'),
      ),
      _DashboardItem(
        icon: Icons.inventory_2_outlined,
        label: 'Części',
        color: Colors.deepPurple,
        onTap: () => context.go('/czesci'),
        requiredModule: 'Czesci',
        hasAccess: has('Czesci'),
      ),
      if (isAdmin)
        _DashboardItem(
          icon: FontAwesomeIcons.userShield,
          label: 'Panel Admina',
          color: Colors.teal,
          onTap: () => context.go('/admin'),
        ),
    ];

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: SizedBox(
          height: 42,
          child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
        ),
        actions: [
          IconButton(
            tooltip: 'Wyloguj',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authStateProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
          )
        ],
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount:
              MediaQuery.of(context).size.width > 800 ? 4 : (MediaQuery.of(context).size.width > 500 ? 3 : 2),
          childAspectRatio: 1,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemBuilder: (_, i) => items[i],
      ),
    );
  }
}

class _DashboardItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final String? requiredModule;
  final bool hasAccess;
  const _DashboardItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.requiredModule,
    this.hasAccess = true,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = requiredModule != null && !hasAccess;
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: disabled
          ? () => ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Brak uprawnień do modułu: ${requiredModule ?? label}')),
              )
          : onTap,
      child: Ink(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: disabled
                ? [Colors.grey.withOpacity(.6), Colors.grey.withOpacity(.4)]
                : [color.withOpacity(.85), color.withOpacity(.55)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 42, color: Colors.white),
                  const SizedBox(height: 12),
                  Text(label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.white)),
                ],
              ),
            ),
            if (disabled)
              Positioned(
                top: 8,
                right: 8,
                child: Icon(Icons.lock, color: Colors.white.withOpacity(.9)),
              )
          ],
        ),
      ),
    );
  }
}
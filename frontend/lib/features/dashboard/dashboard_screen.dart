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
        hasAccess: isAdmin || has('Raporty'),
      ),
      _DashboardItem(
        icon: FontAwesomeIcons.triangleExclamation,
        label: 'Zgłoszenia',
        color: Colors.orange.shade700,
        onTap: () => context.go('/zgloszenia'),
        requiredModule: 'Zgloszenia',
        hasAccess: isAdmin || has('Zgloszenia'),
      ),
      _DashboardItem(
        icon: FontAwesomeIcons.calendarDays,
        label: 'Harmonogramy',
        color: Colors.green.shade700,
        onTap: () => context.go('/harmonogramy'),
        requiredModule: 'Harmonogramy',
        hasAccess: isAdmin || has('Harmonogramy'),
      ),
      _DashboardItem(
        icon: FontAwesomeIcons.clipboardCheck,
        label: 'Przeglądy',
        color: Colors.blueGrey,
        onTap: () => context.go('/przeglady'),
        // dostęp zawsze (brak wymogu modułu)
      ),
      _DashboardItem(
        icon: FontAwesomeIcons.screwdriverWrench,
        label: 'Instrukcje napraw',
        color: Colors.brown,
        onTap: () => context.go('/instrukcje'),
        requiredModule: 'Instrukcje',
        hasAccess: isAdmin || has('Instrukcje'),
      ),
      _DashboardItem(
        icon: FontAwesomeIcons.boxOpen,
        label: 'Części',
        color: Colors.deepPurple,
        onTap: () => context.go('/czesci'),
        requiredModule: 'Czesci',
        hasAccess: isAdmin || has('Czesci'),
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
              MediaQuery.of(context).size.width > 1000 ? 5 : (MediaQuery.of(context).size.width > 800 ? 4 : (MediaQuery.of(context).size.width > 500 ? 3 : 2)),
          childAspectRatio: 0.95,
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
    return LayoutBuilder(
      builder: (context, constraints) {
        // responsywny rozmiar ikony
        final tileWidth = constraints.maxWidth;
        final iconSize = tileWidth > 240
            ? 64.0
            : tileWidth > 180
                ? 56.0
                : 48.0;
        final textStyle = TextStyle(
          fontWeight: FontWeight.w700,
          color: Colors.white,
          fontSize: iconSize > 60 ? 18 : 16,
          letterSpacing: 0.3,
        );

        return InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: disabled
              ? () => ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Brak uprawnień do modułu: ${requiredModule ?? label}')),
                  )
              : onTap,
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: disabled
                    ? [Colors.grey.withOpacity(.55), Colors.grey.withOpacity(.35)]
                    : [color.withOpacity(.92), color.withOpacity(.6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.35),
                  blurRadius: 16,
                  spreadRadius: 1,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Dekoracyjny okrąg za ikoną
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10, right: 10),
                    child: Container(
                      width: iconSize + 20,
                      height: iconSize + 20,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, size: iconSize, color: Colors.white),
                      const SizedBox(height: 14),
                      Text(label, textAlign: TextAlign.center, style: textStyle),
                    ],
                  ),
                ),
                if (disabled)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Icon(Icons.lock, color: Colors.white.withOpacity(.95)),
                  )
              ],
            ),
          ),
        );
      },
    );
  }
}
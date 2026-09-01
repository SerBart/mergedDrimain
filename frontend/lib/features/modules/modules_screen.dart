import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../core/constants/app_roles.dart';
import '../../core/providers/app_providers.dart';
import '../../widgets/top_app_bar.dart';

class ModulesScreen extends ConsumerWidget {
  const ModulesScreen({super.key});

  bool _hasAccess(bool isAdmin, Set<String> modules, String? moduleKey, bool adminOnly) {
    if (adminOnly) return isAdmin;
    if (isAdmin) return true;
    if (moduleKey == null || moduleKey.isEmpty) return true;
    return modules.any((m) => m.toLowerCase() == moduleKey.toLowerCase());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    final isAdmin = auth?.role == AppRoles.admin;
    final modules = auth?.modules ?? const <String>{};
    final scheme = Theme.of(context).colorScheme;

    final allTiles = <_ModuleTile>[
      _ModuleTile(label: 'Raporty',        route: '/raporty',          icon: FontAwesomeIcons.fileCircleCheck,    gradient: [scheme.primary, scheme.primary.withOpacity(.75)], moduleKey: 'Raporty'),
      _ModuleTile(label: 'Zgłoszenia',     route: '/zgloszenia',       icon: FontAwesomeIcons.triangleExclamation, gradient: [const Color(0xFFF59E0B), const Color(0xFFF97316)], moduleKey: 'Zgloszenia'),
      _ModuleTile(label: 'Moje zgłoszenia',route: '/moje-zgloszenia',  icon: FontAwesomeIcons.checkDouble,         gradient: [const Color(0xFFFCA5A5), const Color(0xFFF87171)], moduleKey: 'Zgloszenia'),
      _ModuleTile(label: 'Harmonogramy',   route: '/harmonogramy',     icon: FontAwesomeIcons.calendarDays,        gradient: [const Color(0xFF10B981), const Color(0xFF059669)], moduleKey: 'Harmonogramy'),
      _ModuleTile(label: 'Zużycie energii', route: '/energia',         icon: Icons.bolt_outlined,                  gradient: [const Color(0xFF16A34A), const Color(0xFF15803D)], moduleKey: 'Energia'),
      _ModuleTile(label: 'Przeglądy',      route: '/przeglady',        icon: FontAwesomeIcons.clipboardCheck,      gradient: [const Color(0xFF0EA5E9), const Color(0xFF2563EB)]),
      _ModuleTile(label: 'Instrukcje',     route: '/instrukcje',       icon: FontAwesomeIcons.screwdriverWrench,   gradient: [const Color(0xFF8B5CF6), const Color(0xFF7C3AED)], moduleKey: 'Instrukcje'),
      _ModuleTile(label: 'Części',         route: '/czesci',           icon: FontAwesomeIcons.boxOpen,             gradient: [const Color(0xFFEC4899), const Color(0xFFDB2777)], moduleKey: 'Czesci'),
      _ModuleTile(label: 'Powiadomienia',  route: '/notifications',    icon: Icons.notifications_outlined,         gradient: [const Color(0xFF64748B), const Color(0xFF475569)]),
      _ModuleTile(label: 'Mój profil',     route: '/profil',           icon: Icons.person_outline,                 gradient: [const Color(0xFF6366F1), const Color(0xFF4F46E5)]),
      _ModuleTile(label: 'Panel Admina',   route: '/admin',            icon: FontAwesomeIcons.userShield,          gradient: [const Color(0xFF14B8A6), const Color(0xFF0D9488)], adminOnly: true),
    ];

    final visibleTiles = allTiles
        .where((t) => _hasAccess(isAdmin, modules, t.moduleKey, t.adminOnly))
        .toList();

    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width > 1300
        ? 5
        : width > 1024
            ? 4
            : width > 740
                ? 3
                : width > 480
                    ? 2
                    : 1;

    return Scaffold(
      appBar: const TopAppBar(title: 'Moduły', showBack: true),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: scheme.surfaceContainerHighest.withOpacity(.35),
            ),
            child: const Text('Wszystkie dostępne moduły w jednym miejscu. Wybierz kafelek, aby przejść dalej.'),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: width > 480 ? 0.98 : 3.8,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: visibleTiles.length,
            itemBuilder: (context, i) => _ModuleTileCard(tile: visibleTiles[i]),
          ),
        ],
      ),
    );
  }
}

// ---------- data ----------

class _ModuleTile {
  final String label;
  final String route;
  final IconData icon;
  final List<Color> gradient;
  final String? moduleKey;
  final bool adminOnly;

  const _ModuleTile({
    required this.label,
    required this.route,
    required this.icon,
    required this.gradient,
    this.moduleKey,
    this.adminOnly = false,
  });
}

// ---------- card widget — same look as dashboard ----------

class _ModuleTileCard extends StatefulWidget {
  final _ModuleTile tile;

  const _ModuleTileCard({required this.tile});

  @override
  State<_ModuleTileCard> createState() => _ModuleTileCardState();
}

class _ModuleTileCardState extends State<_ModuleTileCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.of(context).size.width <= 480;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? 1.015 : 1.0,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOutCubic,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          splashFactory: NoSplash.splashFactory,
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          enableFeedback: false,
          onTap: () => context.go(widget.tile.route),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                colors: widget.tile.gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.tile.gradient.first.withOpacity(0.30),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Stack(
              children: [
                // decorative circle (top-right corner)
                Positioned(
                  right: -12,
                  top: -12,
                  child: Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(.12),
                    ),
                  ),
                ),
                // content
                narrow
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Icon(widget.tile.icon, size: 26, color: Colors.white),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                widget.tile.label,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                              ),
                            ),
                            const Icon(Icons.chevron_right, color: Colors.white54, size: 20),
                          ],
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(widget.tile.icon, size: 56, color: Colors.white),
                            const SizedBox(height: 14),
                            Text(
                              widget.tile.label,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_roles.dart';
import '../core/providers/app_providers.dart';
import '../routing/app_router.dart';

final quickModuleOverlayExpandedProvider = StateProvider<bool>((ref) => false);

class _QuickModule {
  final String label;
  final String route;
  final String? requiredModule;
  final bool adminOnly;
  final IconData icon;
  final Color accent;

  const _QuickModule({
    required this.label,
    required this.route,
    required this.icon,
    required this.accent,
    this.requiredModule,
    this.adminOnly = false,
  });
}

const List<_QuickModule> _quickModules = [
  _QuickModule(
    label: 'Raporty',
    route: '/raporty',
    requiredModule: 'Raporty',
    icon: Icons.description_rounded,
    accent: Color(0xFF7C3AED),
  ),
  _QuickModule(
    label: 'Zgloszenia',
    route: '/zgloszenia',
    requiredModule: 'Zgloszenia',
    icon: Icons.campaign_rounded,
    accent: Color(0xFFF59E0B),
  ),
  _QuickModule(
    label: 'Harmonogramy',
    route: '/harmonogramy',
    requiredModule: 'Harmonogramy',
    icon: Icons.calendar_month_rounded,
    accent: Color(0xFF10B981),
  ),
  _QuickModule(
    label: 'Zużycie energii',
    route: '/energia',
    requiredModule: 'Energia',
    icon: Icons.bolt_rounded,
    accent: Color(0xFF16A34A),
  ),
  _QuickModule(
    label: 'Przeglady',
    route: '/przeglady',
    icon: Icons.fact_check_rounded,
    accent: Color(0xFF0EA5E9),
  ),
  _QuickModule(
    label: 'Instrukcje',
    route: '/instrukcje',
    requiredModule: 'Instrukcje',
    icon: Icons.menu_book_rounded,
    accent: Color(0xFF8B5CF6),
  ),
  _QuickModule(
    label: 'Czesci',
    route: '/czesci',
    requiredModule: 'Czesci',
    icon: Icons.inventory_2_rounded,
    accent: Color(0xFFEC4899),
  ),
  _QuickModule(
    label: 'Admin',
    route: '/admin',
    adminOnly: true,
    icon: Icons.admin_panel_settings_rounded,
    accent: Color(0xFF14B8A6),
  ),
];

class QuickModuleOverlay extends ConsumerStatefulWidget {
  const QuickModuleOverlay({super.key});

  @override
  ConsumerState<QuickModuleOverlay> createState() => _QuickModuleOverlayState();
}

class _QuickModuleOverlayState extends ConsumerState<QuickModuleOverlay> {
  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStateProvider);
    final modules = auth?.modules ?? const <String>{};
    final expanded = ref.watch(quickModuleOverlayExpandedProvider);

    bool hasModule(String moduleKey) =>
        modules.any((m) => m.toLowerCase() == moduleKey.toLowerCase());

    final available = _quickModules.where((m) {
      if (m.adminOnly) return auth?.role == AppRoles.admin;
      if (auth?.role == AppRoles.admin) return true;
      if (m.requiredModule == null) return true;
      return hasModule(m.requiredModule!);
    }).toList();

    if (auth == null || available.isEmpty || !expanded) {
      return const SizedBox.shrink();
    }

    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: IgnorePointer(
        ignoring: !expanded,
        child: Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.only(top: 72, left: 10),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: expanded ? 1 : 0),
              duration: const Duration(milliseconds: 190),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) {
                return Transform.translate(
                  offset: Offset(-240 * (1 - value), 0),
                  child: Opacity(
                    opacity: value,
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        width: 220,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(.98),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: scheme.outlineVariant.withOpacity(.45)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(.10),
                              blurRadius: 14,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              height: 44,
                              child: Row(
                                children: [
                                  const SizedBox(width: 12),
                                  Icon(Icons.grid_view_rounded, size: 20, color: scheme.primary),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      'Kafelki',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF111827),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Zwin',
                                    onPressed: () => ref.read(quickModuleOverlayExpandedProvider.notifier).state = false,
                                    icon: const Icon(Icons.close_rounded, size: 18),
                                  ),
                                ],
                              ),
                            ),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 320),
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
                                child: Column(
                                  children: available.map((m) {
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(12),
                                        onTap: () {
                                          ref.read(quickModuleOverlayExpandedProvider.notifier).state = false;
                                          ref.read(appRouterProvider).go(m.route);
                                        },
                                        child: Ink(
                                          decoration: BoxDecoration(
                                            color: m.accent.withOpacity(.10),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: m.accent.withOpacity(.22)),
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                                            child: Row(
                                              children: [
                                                Icon(m.icon, size: 17, color: m.accent),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    m.label,
                                                    style: const TextStyle(
                                                      color: Color(0xFF111827),
                                                      fontWeight: FontWeight.w700,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                ),
                                                Icon(Icons.chevron_right_rounded, size: 18, color: m.accent),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}


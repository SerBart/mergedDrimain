import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/app_providers.dart';
import '../../core/constants/app_roles.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../widgets/top_app_bar.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    final isAdmin = auth?.role == AppRoles.admin;
    final modules = auth?.modules ?? const {};
    final scheme = Theme.of(context).colorScheme;

    bool has(String moduleKey) => modules.any((m) => m.toLowerCase() == moduleKey.toLowerCase());

    final items = [
      _DashboardItem(
        icon: FontAwesomeIcons.fileCircleCheck,
        label: 'Raporty',
        gradient: [scheme.primary, scheme.primary.withOpacity(.75)],
        onTap: () => context.go('/raporty'),
        requiredModule: 'Raporty',
        hasAccess: isAdmin || has('Raporty'),
      ),
      _DashboardItem(
        icon: FontAwesomeIcons.triangleExclamation,
        label: 'Zgłoszenia',
        gradient: [const Color(0xFFF59E0B), const Color(0xFFF97316)],
        onTap: () => context.go('/zgloszenia'),
        requiredModule: 'Zgloszenia',
        hasAccess: isAdmin || has('Zgloszenia'),
      ),
      _DashboardItem(
        icon: FontAwesomeIcons.calendarDays,
        label: 'Harmonogramy',
        gradient: [const Color(0xFF10B981), const Color(0xFF059669)],
        onTap: () => context.go('/harmonogramy'),
        requiredModule: 'Harmonogramy',
        hasAccess: isAdmin || has('Harmonogramy'),
      ),
      _DashboardItem(
        icon: FontAwesomeIcons.clipboardCheck,
        label: 'Przeglądy',
        gradient: [const Color(0xFF0EA5E9), const Color(0xFF2563EB)],
        onTap: () => context.go('/przeglady'),
      ),
      _DashboardItem(
        icon: FontAwesomeIcons.screwdriverWrench,
        label: 'Instrukcje napraw',
        gradient: [const Color(0xFF8B5CF6), const Color(0xFF7C3AED)],
        onTap: () => context.go('/instrukcje'),
        requiredModule: 'Instrukcje',
        hasAccess: isAdmin || has('Instrukcje'),
      ),
      _DashboardItem(
        icon: FontAwesomeIcons.boxOpen,
        label: 'Części',
        gradient: [const Color(0xFFEC4899), const Color(0xFFDB2777)],
        onTap: () => context.go('/czesci'),
        requiredModule: 'Czesci',
        hasAccess: isAdmin || has('Czesci'),
      ),
      if (isAdmin)
        _DashboardItem(
          icon: FontAwesomeIcons.userShield,
          label: 'Panel Admina',
          gradient: [const Color(0xFF14B8A6), const Color(0xFF0D9488)],
          onTap: () => context.go('/admin'),
        ),
    ];

    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width > 1300
        ? 5
        : width > 1024
            ? 4
            : width > 720
                ? 3
                : 2;

    return Scaffold(
      appBar: const TopAppBar(title: 'Dashboard'),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: _WelcomePanel(isAdmin: isAdmin, modulesCount: modules.length),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                childAspectRatio: 0.98,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, i) => items[i],
                childCount: items.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomePanel extends StatelessWidget {
  final bool isAdmin;
  final int modulesCount;

  const _WelcomePanel({required this.isAdmin, required this.modulesCount});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final titleStyle = Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
        );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.86),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.primary.withOpacity(.14)),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withOpacity(.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [scheme.primary, scheme.secondary],
              ),
            ),
            child: const Icon(Icons.dashboard_rounded, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Panel glowny', style: titleStyle),
                const SizedBox(height: 4),
                Text(
                  isAdmin
                      ? 'Masz dostep administracyjny. Wszystkie moduly sa aktywne.'
                      : 'Dostepne moduly: $modulesCount. Wybierz kafelek, aby przejsc dalej.',
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final List<Color> gradient;
  final VoidCallback onTap;
  final String? requiredModule;
  final bool hasAccess;

  const _DashboardItem({
    required this.icon,
    required this.label,
    required this.gradient,
    required this.onTap,
    this.requiredModule,
    this.hasAccess = true,
    super.key,
  });

  @override
  State<_DashboardItem> createState() => _DashboardItemState();
}

class _DashboardItemState extends State<_DashboardItem> {
  bool _hovered = false;
  bool _pressed = false;

  void _setHovered(bool v) => setState(() => _hovered = v);
  void _setPressed(bool v) => setState(() => _pressed = v);

  @override
  Widget build(BuildContext context) {
    final disabled = widget.requiredModule != null && !widget.hasAccess;
    final baseScale = _hovered ? 1.02 : (_pressed ? 0.985 : 1.0);

    return MouseRegion(
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: GestureDetector(
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        child: AnimatedScale(
          scale: baseScale,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: disabled
                ? () => ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Brak uprawnien do modulu: ${widget.requiredModule ?? widget.label}')),
                    )
                : widget.onTap,
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  colors: disabled
                      ? [Colors.grey.shade500, Colors.grey.shade400]
                      : widget.gradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: disabled
                    ? []
                    : [
                        BoxShadow(
                          color: widget.gradient.first.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
              ),
              child: Stack(
                children: [
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
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(widget.icon, size: 56, color: Colors.white),
                        const SizedBox(height: 14),
                        Text(
                          widget.label,
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
                  if (disabled)
                    const Positioned(
                      top: 10,
                      right: 10,
                      child: Icon(Icons.lock, color: Colors.white),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
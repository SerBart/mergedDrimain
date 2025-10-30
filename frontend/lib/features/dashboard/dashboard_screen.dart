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
      appBar: const TopAppBar(title: 'Dashboard'),
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

class _DashboardItem extends StatefulWidget {
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
    Key? key,
  }) : super(key: key);

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
    return LayoutBuilder(
      builder: (context, constraints) {
        // responsywny rozmiar ikony - zwiększone wartości dla bardziej "wypasionej" apki
        final tileWidth = constraints.maxWidth;
        final iconSize = tileWidth > 260
            ? 84.0
            : tileWidth > 200
                ? 72.0
                : tileWidth > 140
                    ? 60.0
                    : 52.0;
        final textStyle = TextStyle(
          fontWeight: FontWeight.w800,
          color: Colors.white,
          fontSize: iconSize > 70 ? 18 : 15,
          letterSpacing: 0.2,
          shadows: [
            Shadow(color: Colors.black.withOpacity(0.35), blurRadius: 6, offset: Offset(0, 2)),
          ],
        );

        final baseScale = _hovered ? 1.03 : (_pressed ? 0.98 : 1.0);

        return MouseRegion(
          onEnter: (_) => _setHovered(true),
          onExit: (_) => _setHovered(false),
          child: GestureDetector(
            onTapDown: (_) => _setPressed(true),
            onTapUp: (_) => _setPressed(false),
            onTapCancel: () => _setPressed(false),
            child: AnimatedScale(
              scale: baseScale,
              duration: Duration(milliseconds: 160),
              curve: Curves.easeOutCubic,
              child: InkWell(
                borderRadius: BorderRadius.circular(28),
                onTap: disabled
                    ? () => ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Brak uprawnień do modułu: ${widget.requiredModule ?? widget.label}')),
                        )
                    : widget.onTap,
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: disabled
                          ? [Colors.grey.withOpacity(.55), Colors.grey.withOpacity(.35)]
                          : [widget.color.withOpacity(.95), widget.color.withOpacity(.65)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: disabled
                        ? []
                        : [
                            BoxShadow(
                              color: widget.color.withOpacity(0.28),
                              blurRadius: 22,
                              spreadRadius: 1,
                              offset: const Offset(0, 10),
                            ),
                          ],
                  ),
                  child: Stack(
                    children: [
                      // Duży, gradientowy okrąg dekoracyjny po prawej, z delikatnym blur/shadow
                      Align(
                        alignment: Alignment.topRight,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8, right: 8),
                          child: Container(
                            width: iconSize + 36,
                            height: iconSize + 36,
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                colors: disabled
                                    ? [Colors.white.withOpacity(0.04), Colors.white.withOpacity(0.01)]
                                    : [Colors.white.withOpacity(0.14), Colors.white.withOpacity(0.03)],
                                center: Alignment(-0.2, -0.2),
                                radius: 0.9,
                              ),
                              shape: BoxShape.circle,
                              boxShadow: disabled
                                  ? []
                                  : [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.12),
                                        blurRadius: 12,
                                        offset: Offset(0, 6),
                                      ),
                                    ],
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Ikona z lekkim glow
                            Container(
                              padding: EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                // delikatny gradient pod ikoną aby wyglądała bardziej premium
                                gradient: disabled
                                    ? null
                                    : LinearGradient(colors: [Colors.white.withOpacity(.12), Colors.white.withOpacity(.06)]),
                              ),
                              child: Icon(widget.icon, size: iconSize, color: Colors.white, shadows: [
                                Shadow(color: Colors.black.withOpacity(0.35), blurRadius: 8, offset: Offset(0, 3)),
                              ]),
                            ),
                            SizedBox(height: 14),
                            Text(widget.label, textAlign: TextAlign.center, style: textStyle),
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
              ),
            ),
          ),
        );
      },
    );
  }
}
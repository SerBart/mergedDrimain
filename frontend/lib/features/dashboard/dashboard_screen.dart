import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_roles.dart';
import '../../core/models/dashboard_kpi.dart';
import '../../core/models/raport.dart';
import '../../core/models/user.dart';
import '../../core/models/zgloszenie.dart';
import '../../core/providers/app_providers.dart';
import '../../core/utils/web_nav.dart';
import '../../core/utils/notification_router.dart';
import '../../widgets/app_card.dart';
import '../../widgets/top_app_bar.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _loading = true;
  String? _error;
  DashboardKpi? _kpi;
  List<Raport> _recentRaporty = const [];
  List<Zgloszenie> _recentZgloszenia = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDashboardData());
  }

  Future<void> _loadDashboardData() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raportyRepo = ref.read(raportyApiRepositoryProvider);
      final zgloszeniaRepo = ref.read(zgloszeniaApiRepositoryProvider);
      final metaRepo = ref.read(metaApiRepositoryProvider);

      final results = await Future.wait([
        raportyRepo.fetchAll(page: 0, size: 5),
        zgloszeniaRepo.fetchAll(),
        metaRepo.fetchDashboardKpi(),
      ]);

      final raporty = results[0] as List<Raport>;
      final zgloszenia = results[1] as List<Zgloszenie>;
      final kpi = results[2] as DashboardKpi;
      zgloszenia.sort((a, b) => b.dataGodzina.compareTo(a.dataGodzina));

      if (!mounted) return;
      setState(() {
        _kpi = kpi;
        _recentRaporty = raporty.take(5).toList();
        _recentZgloszenia = zgloszenia.take(5).toList();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStateProvider);
    final isAdmin = auth?.role == AppRoles.admin;
    final modules = auth?.modules ?? const <String>{};
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
         icon: FontAwesomeIcons.checkDouble,
         label: 'Moje Zgłoszenia',
         gradient: [const Color(0xFFFCA5A5), const Color(0xFFF87171)],
         onTap: () => context.go('/moje-zgloszenia'),
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
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _WelcomePanel(isAdmin: isAdmin, modulesCount: modules.length, user: auth),
            AppCard(
              title: 'Szybki dostęp do modułów',
              divided: true,
              child: _QuickModulesBar(
                isAdmin: isAdmin,
                modules: modules,
              ),
            ),
            AppCard(
              title: 'KPI i statystyki',
              divided: true,
              action: _kpi?.lastUpdated != null
                  ? Text(
                      'Aktualizacja: ${DateFormat('yyyy-MM-dd HH:mm').format(_kpi!.lastUpdated!.toLocal())}',
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    )
                  : null,
              child: _loading && _kpi == null
                  ? const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
                  : _kpi == null
                      ? _ErrorBlock(
                          message: 'Nie udało się pobrać statystyk KPI.',
                          onRetry: _loadDashboardData,
                        )
                      : _KpiOverview(kpi: _kpi!),
            ),
            AppCard(
              title: 'Mój profil',
              divided: true,
              action: TextButton.icon(
                onPressed: () => context.go('/profil'),
                icon: const Icon(Icons.manage_accounts_outlined),
                label: const Text('Otwórz profil'),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ProfileLine(label: 'Użytkownik', value: auth?.username ?? '-'),
                  _ProfileLine(label: 'E-mail', value: auth?.email ?? '-'),
                  _ProfileLine(label: 'Dział', value: auth?.dzialNazwa ?? '-'),
                  _ProfileLine(label: 'Moduły', value: modules.isEmpty ? '-' : modules.join(', ')),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.icon(
                        onPressed: () => context.go('/profil'),
                        icon: const Icon(Icons.lock_reset),
                        label: const Text('Zmień hasło'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => context.go('/notifications'),
                        icon: const Icon(Icons.notifications_outlined),
                        label: const Text('Powiadomienia'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            AppCard(
              title: 'Ostatnie raporty',
              divided: true,
              action: TextButton(
                onPressed: () => context.go('/raporty'),
                child: const Text('Wszystkie'),
              ),
              child: _loading && _recentRaporty.isEmpty
                  ? const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
                  : _error != null
                      ? _ErrorBlock(
                          message: 'Nie udało się pobrać raportów: $_error',
                          onRetry: _loadDashboardData,
                        )
                      : _RecentRaportyList(items: _recentRaporty),
            ),
            AppCard(
              title: 'Ostatnie zgłoszenia',
              divided: true,
              action: TextButton(
                onPressed: () => context.go('/zgloszenia'),
                child: const Text('Wszystkie'),
              ),
              child: _loading && _recentZgloszenia.isEmpty
                  ? const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
                  : _error != null
                      ? _ErrorBlock(
                          message: 'Nie udało się pobrać zgłoszeń: $_error',
                          onRetry: _loadDashboardData,
                        )
                       : _RecentZgloszeniaList(items: _recentZgloszenia),
            ),
            AppCard(
              title: 'Ostatnie powiadomienia',
              divided: true,
              action: TextButton(
                onPressed: () => context.go('/notifications'),
                child: const Text('Wszystkie'),
              ),
              child: _RecentNotificationsWidget(),
            ),
            AppCard(
              title: 'Moduły',
              divided: true,
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  childAspectRatio: 0.98,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: items.length,
                itemBuilder: (context, i) => items[i],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomePanel extends StatelessWidget {
  final bool isAdmin;
  final int modulesCount;
  final User? user;

  const _WelcomePanel({required this.isAdmin, required this.modulesCount, required this.user});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final titleStyle = Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
              gradient: LinearGradient(colors: [scheme.primary, scheme.secondary]),
            ),
            child: const Icon(Icons.dashboard_rounded, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Panel główny', style: titleStyle),
                const SizedBox(height: 4),
                Text(
                  isAdmin
                      ? 'Masz dostęp administracyjny. Wszystkie moduły są aktywne.'
                      : 'Dostępne moduły: $modulesCount. Wybierz kafelek, aby przejść dalej.',
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 6),
                Text(
                  user?.dzialNazwa != null ? 'Zalogowano jako ${user!.dzialNazwa}' : 'Witaj, ${user?.username ?? 'użytkowniku'}',
                  style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileLine extends StatelessWidget {
  final String label;
  final String value;

  const _ProfileLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _RecentRaportyList extends StatelessWidget {
  final List<Raport> items;

  const _RecentRaportyList({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('Brak raportów do wyświetlenia.'),
      );
    }

    return Column(
      children: items
          .map(
            (r) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.description_outlined),
              title: Text(r.typNaprawy),
              subtitle: Text('${r.maszyna?.nazwa ?? '-'} • ${r.dataNaprawy.toIso8601String().substring(0, 10)}'),
              trailing: Text(r.status),
              onTap: () => GoRouter.of(context).go('/raporty'),
            ),
          )
          .toList(),
    );
  }
}

class _RecentZgloszeniaList extends StatelessWidget {
  final List<Zgloszenie> items;

  const _RecentZgloszeniaList({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('Brak zgłoszeń do wyświetlenia.'),
      );
    }

    return Column(
      children: items
          .map(
            (z) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.report_problem_outlined),
              title: Text(z.temat.isNotEmpty ? z.temat : z.typ),
              subtitle: Text('${z.maszyna?.nazwa ?? '-'} • ${z.dataGodzina.toIso8601String().substring(0, 16).replaceFirst('T', ' ')}'),
              trailing: Text(z.status),
              onTap: () => GoRouter.of(context).go('/zgloszenia/${z.id}'),
            ),
          )
          .toList(),
    );
  }
}

class _RecentNotificationsWidget extends ConsumerWidget {
  const _RecentNotificationsWidget();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifsAsync = ref.watch(notificationsListProvider);

    return notifsAsync.when(
      data: (notifications) {
        if (notifications.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Brak powiadomień.'),
          );
        }

        final recent = notifications.take(5).toList();
        return Column(
          children: recent
              .map(
                (n) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    n.read ? Icons.notifications_none : Icons.notifications_active,
                    color: n.read ? Colors.grey : Colors.orange,
                  ),
                  title: Text(
                    n.title ?? 'Powiadomienie',
                    style: TextStyle(
                      fontWeight: n.read ? FontWeight.normal : FontWeight.w600,
                      color: n.read ? Colors.grey : Colors.black,
                    ),
                  ),
                  subtitle: Text(
                    n.message ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  trailing: Text(
                    n.createdAt != null
                        ? _formatTime(n.createdAt!)
                        : '',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  onTap: () {
                    final target = routeFromNotificationModel(n);
                    GoRouter.of(context).go(target);
                  },
                ),
              )
              .toList(),
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (_, __) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('Błąd ładowania powiadomień'),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'teraz';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';

    return DateFormat('MM-dd').format(dt);
  }
}

class _QuickModulesBar extends StatelessWidget {
  final bool isAdmin;
  final Set<String> modules;

  const _QuickModulesBar({required this.isAdmin, required this.modules});

  bool _has(String moduleKey) {
    if (isAdmin) return true;
    return modules.any((m) => m.toLowerCase() == moduleKey.toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    final actions = <_QuickModuleAction>[
      const _QuickModuleAction(label: 'Raporty', route: '/raporty', icon: Icons.description_outlined, moduleKey: 'Raporty'),
      const _QuickModuleAction(label: 'Zgłoszenia', route: '/zgloszenia', icon: Icons.report_problem_outlined, moduleKey: 'Zgloszenia'),
      const _QuickModuleAction(label: 'Moje zgłoszenia', route: '/moje-zgloszenia', icon: Icons.assignment_ind_outlined, moduleKey: 'Zgloszenia'),
      const _QuickModuleAction(label: 'Harmonogramy', route: '/harmonogramy', icon: Icons.calendar_month_outlined, moduleKey: 'Harmonogramy'),
      const _QuickModuleAction(label: 'Przeglądy', route: '/przeglady', icon: Icons.fact_check_outlined),
      const _QuickModuleAction(label: 'Instrukcje', route: '/instrukcje', icon: Icons.menu_book_outlined, moduleKey: 'Instrukcje'),
      const _QuickModuleAction(label: 'Części', route: '/czesci', icon: Icons.inventory_2_outlined, moduleKey: 'Czesci'),
      const _QuickModuleAction(label: 'Panel Admina', route: '/admin', icon: Icons.admin_panel_settings_outlined, adminOnly: true),
    ];

    final visible = actions.where((a) {
      if (a.adminOnly) return isAdmin;
      if (a.moduleKey == null) return true;
      return _has(a.moduleKey!);
    }).toList();

    if (visible.isEmpty) {
      return const Text('Brak dostępnych modułów.');
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: visible
          .map(
            (a) => FilledButton.tonalIcon(
              onPressed: () => context.go(a.route),
              icon: Icon(a.icon),
              label: Text(a.label),
            ),
          )
          .toList(),
    );
  }
}

class _QuickModuleAction {
  final String label;
  final String route;
  final IconData icon;
  final String? moduleKey;
  final bool adminOnly;

  const _QuickModuleAction({
    required this.label,
    required this.route,
    required this.icon,
    this.moduleKey,
    this.adminOnly = false,
  });
}

class _KpiOverview extends StatelessWidget {
  final DashboardKpi kpi;

  const _KpiOverview({required this.kpi});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _KpiTile(label: 'Nowe zgłoszenia (dziś)', value: '${kpi.zgloszeniaDzisNowe}', icon: Icons.fiber_new),
            _KpiTile(label: 'W toku (dziś)', value: '${kpi.zgloszeniaDzisWToku}', icon: Icons.pending_actions),
            _KpiTile(label: 'Zamknięte (dziś)', value: '${kpi.zgloszeniaDzisZamkniete}', icon: Icons.task_alt),
            _KpiTile(label: 'Raporty (dziś)', value: '${kpi.raportyDzis}', icon: Icons.description_outlined),
            _KpiTile(label: 'Raporty (7 dni)', value: '${kpi.raporty7Dni}', icon: Icons.date_range),
            _KpiTile(label: 'Śr. czas rozwiązania', value: '${kpi.sredniCzasRozwiazaniaGodziny.toStringAsFixed(1)} h', icon: Icons.schedule),
            _KpiTile(label: 'Maszyny w pracy', value: '${kpi.maszynyWPracy}/${kpi.maszynyRazem}', icon: Icons.precision_manufacturing),
            _KpiTile(label: 'Maszyny w przestoju', value: '${kpi.maszynyWPrzestoju}', icon: Icons.warning_amber_rounded),
          ],
        ),
        const SizedBox(height: 14),
        Text('Top 3 typy zgłoszeń', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        if (kpi.topTypyZgloszen.isEmpty)
          const Text('Brak danych.')
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: kpi.topTypyZgloszen.entries
                .map((e) => Chip(label: Text('${e.key}: ${e.value}')))
                .toList(),
          ),
      ],
    );
  }
}

class _KpiTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _KpiTile({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(.45),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 2),
                Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorBlock({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Spróbuj ponownie'),
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

  void _setHovered(bool v) => setState(() => _hovered = v);

  @override
  Widget build(BuildContext context) {
    final disabled = widget.requiredModule != null && !widget.hasAccess;
    final baseScale = _hovered ? 1.015 : 1.0;

    return MouseRegion(
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: GestureDetector(
        child: AnimatedScale(
          scale: baseScale,
          duration: const Duration(milliseconds: 90),
          curve: Curves.easeOutCubic,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            splashFactory: NoSplash.splashFactory,
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
            enableFeedback: false,
            onTap: disabled
                ? () => ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Brak uprawnień do modułu: ${widget.requiredModule ?? widget.label}')),
                    )
                : widget.onTap,
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  colors: disabled ? [Colors.grey.shade500, Colors.grey.shade400] : widget.gradient,
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
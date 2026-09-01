import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_roles.dart';
import '../../core/models/energia.dart';
import '../../core/models/harmonogram.dart';
import '../../core/models/raport.dart';
import '../../core/models/zgloszenie.dart';
import '../../core/providers/app_providers.dart';
import '../../widgets/top_app_bar.dart';

final _dashboardLiveSummaryProvider = FutureProvider.autoDispose<_DashboardLiveSummary>((ref) async {
  final zgloszeniaRepo = ref.watch(zgloszeniaApiRepositoryProvider);
  final harmonogramyRepo = ref.watch(harmonogramyApiRepositoryProvider);
  final raportyRepo = ref.watch(raportyApiRepositoryProvider);

  final results = await Future.wait([
    zgloszeniaRepo.fetchAll(),
    harmonogramyRepo.fetchAll(),
    raportyRepo.fetchAll(size: 200),
  ]);

  final zgloszenia = results[0] as List<Zgloszenie>;
  final harmonogramy = results[1] as List<Harmonogram>;
  final raporty = results[2] as List<Raport>;

  final openZgloszenia = zgloszenia.where((item) {
    final status = item.status.trim().toUpperCase();
    return status != 'ZAMKNIĘTE' && status != 'ZAMKNIETE';
  }).length;

  final now = DateTime.now();
  final startOfToday = DateTime(now.year, now.month, now.day);
  final startOfNextDay = startOfToday.add(const Duration(days: 1));
  final harmonogramyToday = harmonogramy.where((item) {
    final date = item.data;
    return date != null && !date.isBefore(startOfToday) && date.isBefore(startOfNextDay);
  }).length;

  final raportyToday = raporty.where((item) {
    final date = item.dataNaprawy;
    return !date.isBefore(startOfToday) && date.isBefore(startOfNextDay);
  }).length;

  return _DashboardLiveSummary(
    openZgloszenia: openZgloszenia,
    harmonogramyToday: harmonogramyToday,
    raportyToday: raportyToday,
  );
});

final _energyLiveSummaryProvider = FutureProvider.autoDispose<EnergyOverview?>((ref) async {
  final repo = ref.watch(energiaApiRepositoryProvider);
  try {
    return await repo.fetchOverview(days: 1);
  } catch (_) {
    return null;
  }
});

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    final notificationsAsync = ref.watch(notificationsListProvider);
    final liveSummaryAsync = ref.watch(_dashboardLiveSummaryProvider);
    final energySummaryAsync = ref.watch(_energyLiveSummaryProvider);
    final isAdmin = auth?.role == AppRoles.admin;
    final modules = auth?.modules ?? const <String>{};
    final scheme = Theme.of(context).colorScheme;
    final unreadNotifications = notificationsAsync.maybeWhen(
      data: (items) => items.where((n) => !n.read).length,
      orElse: () => null,
    );
    final openZgloszenia = liveSummaryAsync.maybeWhen(
      data: (summary) => summary.openZgloszenia,
      orElse: () => null,
    );
    final harmonogramyToday = liveSummaryAsync.maybeWhen(
      data: (summary) => summary.harmonogramyToday,
      orElse: () => null,
    );
    final raportyToday = liveSummaryAsync.maybeWhen(
      data: (summary) => summary.raportyToday,
      orElse: () => null,
    );
    final energySummary = energySummaryAsync.maybeWhen(
      data: (summary) => summary,
      orElse: () => null,
    );
    final aktualnosciLiveCount = (unreadNotifications ?? 0) + (raportyToday ?? 0) + (harmonogramyToday ?? 0);

    bool has(String moduleKey) =>
        modules.any((m) => m.toLowerCase() == moduleKey.toLowerCase());

    final heroItems = [
      _DashboardItem(
        icon: FontAwesomeIcons.chartLine,
        label: 'Statystyki',
        subtitle: 'KPI, trendy i alerty operacyjne',
        badge: 'KPI',
        accent: const Color(0xFF4F46E5),
        accentSoft: const Color(0xFFE0E7FF),
        onTap: () => context.go('/statystyki'),
        isHero: true,
      ),
      _DashboardItem(
        icon: FontAwesomeIcons.newspaper,
        label: 'Aktualności',
        subtitle: 'Zgłoszenia, raporty i harmonogramy w jednym miejscu',
        badge: aktualnosciLiveCount > 0 ? '$aktualnosciLiveCount live' : 'Live',
        accent: const Color(0xFF0891B2),
        accentSoft: const Color(0xFFCFFAFE),
        onTap: () => context.go('/aktualnosci'),
        isHero: true,
      ),
    ];

    final items = [
      _DashboardItem(
        icon: FontAwesomeIcons.fileCircleCheck,
        label: 'Raporty',
        subtitle: 'Historia napraw i dokumentacja działań',
        badge: raportyToday != null && raportyToday > 0 ? '$raportyToday dziś' : 'Workflow',
        accent: scheme.primary,
        accentSoft: Color.alphaBlend(scheme.primary.withOpacity(.14), Colors.white),
        onTap: () => context.go('/raporty'),
        requiredModule: 'Raporty',
        hasAccess: isAdmin || has('Raporty'),
      ),
      _DashboardItem(
        icon: FontAwesomeIcons.triangleExclamation,
        label: 'Zgłoszenia',
        subtitle: 'Nowe awarie i obsługa bieżących spraw',
        badge: openZgloszenia != null ? '$openZgloszenia otw.' : 'Priorytet',
        accent: const Color(0xFFF97316),
        accentSoft: const Color(0xFFFFEDD5),
        onTap: () => context.go('/zgloszenia'),
        requiredModule: 'Zgloszenia',
        hasAccess: isAdmin || has('Zgloszenia'),
      ),
      _DashboardItem(
        icon: FontAwesomeIcons.checkDouble,
        label: 'Moje Zgłoszenia',
        subtitle: 'Twoje zgłoszenia i ich aktualny status',
        badge: 'Moje',
        accent: const Color(0xFFF43F5E),
        accentSoft: const Color(0xFFFFE4E6),
        onTap: () => context.go('/moje-zgloszenia'),
        requiredModule: 'Zgloszenia',
        hasAccess: isAdmin || has('Zgloszenia'),
      ),
      _DashboardItem(
        icon: FontAwesomeIcons.listCheck,
        label: 'Moje Zadania',
        subtitle: 'Lista zadań przypisanych do realizacji',
        badge: 'Focus',
        accent: const Color(0xFFD97706),
        accentSoft: const Color(0xFFFEF3C7),
        onTap: () => context.go('/moje-zadania'),
        requiredModule: 'Zgloszenia',
        hasAccess: isAdmin || has('Zgloszenia'),
      ),
      _DashboardItem(
        icon: FontAwesomeIcons.calendarDays,
        label: 'Harmonogramy',
        subtitle: 'Planowane przeglądy i działania serwisowe',
        badge: harmonogramyToday != null && harmonogramyToday > 0
            ? '$harmonogramyToday dziś'
            : 'Plan',
        accent: const Color(0xFF059669),
        accentSoft: const Color(0xFFD1FAE5),
        onTap: () => context.go('/harmonogramy'),
        requiredModule: 'Harmonogramy',
        hasAccess: isAdmin || has('Harmonogramy'),
      ),
      _DashboardItem(
        icon: Icons.bolt_outlined,
        label: 'Zużycie energii',
        subtitle: 'Bieżące pomiary i historia 15-minutowa',
        badge: energySummary != null ? '${energySummary.todayEnergyKwh.toStringAsFixed(1)} kWh' : 'Energia',
        accent: const Color(0xFF16A34A),
        accentSoft: const Color(0xFFD1FAE5),
        onTap: () => context.go('/energia'),
      ),
      _DashboardItem(
        icon: FontAwesomeIcons.clipboardCheck,
        label: 'Przeglądy',
        subtitle: 'Kontrole okresowe i check-listy maszyn',
        badge: 'QA',
        accent: const Color(0xFF0284C7),
        accentSoft: const Color(0xFFE0F2FE),
        onTap: () => context.go('/przeglady'),
      ),
      _DashboardItem(
        icon: FontAwesomeIcons.screwdriverWrench,
        label: 'Instrukcje napraw',
        subtitle: 'Procedury, wiedza i instrukcje serwisowe',
        badge: 'Know-how',
        accent: const Color(0xFF7C3AED),
        accentSoft: const Color(0xFFEDE9FE),
        onTap: () => context.go('/instrukcje'),
        requiredModule: 'Instrukcje',
        hasAccess: isAdmin || has('Instrukcje'),
      ),
      _DashboardItem(
        icon: FontAwesomeIcons.boxOpen,
        label: 'Części',
        subtitle: 'Stany magazynowe i dostępność komponentów',
        badge: 'Magazyn',
        accent: const Color(0xFFDB2777),
        accentSoft: const Color(0xFFFCE7F3),
        onTap: () => context.go('/czesci'),
        requiredModule: 'Czesci',
        hasAccess: isAdmin || has('Czesci'),
      ),
      if (isAdmin)
        _DashboardItem(
          icon: FontAwesomeIcons.userShield,
          label: 'Panel Admina',
          subtitle: 'Użytkownicy, dostęp i konfiguracja aplikacji',
          badge: 'Admin',
          accent: const Color(0xFF0F766E),
          accentSoft: const Color(0xFFCCFBF1),
          onTap: () => context.go('/admin'),
        ),
    ];

    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 720;
    final heroHeight = width < 420
        ? 186.0
        : width < 720
            ? 198.0
            : width < 1024
                ? 212.0
                : 224.0;
    final sectionInset = isMobile ? 12.0 : 16.0;
    final sectionSpacing = isMobile ? 12.0 : 16.0;
    final crossAxisCount = width > 1400
        ? 4
        : width > 1024
            ? 3
            : width > 720
                ? 2
                : 1;
    final heroHorizontal = width > 960;

    return Scaffold(
      appBar: const TopAppBar(title: 'Dashboard'),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(sectionInset, sectionInset, sectionInset, isMobile ? 6 : 8),
            sliver: SliverToBoxAdapter(
              child: _HeroSection(
                items: heroItems,
                horizontal: heroHorizontal,
                unreadNotifications: unreadNotifications,
                heroHeight: heroHeight,
                spacing: sectionSpacing,
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(sectionInset, 0, sectionInset, isMobile ? 8 : 10),
            sliver: const SliverToBoxAdapter(
              child: _SectionDivider(),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(sectionInset, isMobile ? 2 : 4, sectionInset, isMobile ? 10 : 12),
            sliver: SliverToBoxAdapter(
              child: _SectionHeader(
                title: 'Moduły robocze',
                subtitle: 'Szybki dostęp do najważniejszych obszarów pracy.',
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(sectionInset, 0, sectionInset, isMobile ? 18 : 24),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                childAspectRatio: width > 1400
                    ? 1.26
                    : width > 1200
                        ? 1.18
                        : width > 900
                            ? 1.06
                            : width > 720
                                ? 0.98
                                : width > 420
                                    ? 1.40
                                    : 1.28,
                crossAxisSpacing: sectionSpacing,
                mainAxisSpacing: sectionSpacing,
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

class _HeroSection extends StatelessWidget {
  final List<_DashboardItem> items;
  final bool horizontal;
  final int? unreadNotifications;
  final double heroHeight;
  final double spacing;

  const _HeroSection({
    required this.items,
    required this.horizontal,
    required this.unreadNotifications,
    required this.heroHeight,
    required this.spacing,
  });

  @override
  Widget build(BuildContext context) {
    final children = items
        .map(
          (item) => horizontal
              ? Expanded(child: SizedBox(height: heroHeight, child: item))
              : Padding(
                  padding: EdgeInsets.only(bottom: item == items.last ? 0 : spacing),
                  child: SizedBox(height: heroHeight, child: item),
                ),
        )
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'Centrum dowodzenia',
          subtitle: unreadNotifications != null && unreadNotifications! > 0
              ? 'Masz $unreadNotifications nieprzeczytanych powiadomień i szybki dostęp do najważniejszych widoków.'
              : 'Najważniejsze informacje i szybkie wejście do kluczowych obszarów aplikacji.',
        ),
        SizedBox(height: spacing),
        if (horizontal)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              children[0],
              SizedBox(width: spacing),
              children[1],
            ],
          )
        else
          Column(children: children),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compact = MediaQuery.of(context).size.width < 480;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: (compact ? theme.textTheme.titleLarge : theme.textTheme.headlineSmall)?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
            color: const Color(0xFF111827),
            shadows: const [
              Shadow(
                color: Color(0x14000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
        SizedBox(height: compact ? 4 : 6),
        Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: const Color(0xFF4B5563),
            height: 1.4,
            fontSize: compact ? 13 : null,
          ),
        ),
      ],
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    accent.withOpacity(0),
                    accent.withOpacity(.10),
                    accent.withOpacity(.03),
                  ],
                ),
              ),
            ),
          ),
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: accent.withOpacity(.12),
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    accent.withOpacity(.03),
                    accent.withOpacity(.10),
                    accent.withOpacity(0),
                  ],
                ),
              ),
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
  final String subtitle;
  final String? badge;
  final Color accent;
  final Color accentSoft;
  final VoidCallback onTap;
  final String? requiredModule;
  final bool hasAccess;
  final bool isHero;

  const _DashboardItem({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.accent,
    required this.accentSoft,
    required this.onTap,
    this.badge,
    this.requiredModule,
    this.hasAccess = true,
    this.isHero = false,
    super.key,
  });

  @override
  State<_DashboardItem> createState() => _DashboardItemState();
}

class _DashboardItemState extends State<_DashboardItem> {
  bool _hovered = false;

  void _setHovered(bool value) => setState(() => _hovered = value);

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final compactMobile = width < 420;
    final mobile = width < 720;
    final disabled = widget.requiredModule != null && !widget.hasAccess;
    final baseScale = _hovered ? 1.018 : 1.0;
    final cardRadius = BorderRadius.circular(widget.isHero ? (compactMobile ? 24 : 30) : (compactMobile ? 22 : 26));
    final iconSize = widget.isHero ? (compactMobile ? 30.0 : 34.0) : (compactMobile ? 18.0 : 20.0);
    final titleSize = widget.isHero ? (compactMobile ? 21.0 : 24.0) : (compactMobile ? 16.0 : 18.0);
    final cardPadding = widget.isHero
        ? EdgeInsets.symmetric(horizontal: compactMobile ? 16 : 22, vertical: compactMobile ? 16 : 22)
        : EdgeInsets.symmetric(horizontal: compactMobile ? 14 : 18, vertical: mobile ? 14 : 18);
    final backgroundGradient = disabled
        ? [Colors.grey.shade200, Colors.grey.shade100]
        : widget.isHero
            ? [
                Color.alphaBlend(widget.accent.withOpacity(.18), Colors.white),
                Color.alphaBlend(widget.accentSoft.withOpacity(.92), Colors.white),
              ]
            : [
                Color.alphaBlend(widget.accent.withOpacity(.08), Colors.white),
                Color.alphaBlend(widget.accentSoft.withOpacity(.78), Colors.white),
              ];
    final titleColor = disabled ? Colors.black45 : const Color(0xFF111827);
    final subtitleColor = disabled ? Colors.black38 : const Color(0xFF4B5563);
    final actionColor = disabled ? Colors.black45 : widget.accent;
    final glowOpacity = widget.isHero ? 0.10 : 0.06;
    final heroTopInset = widget.isHero ? (compactMobile ? 2.0 : 4.0) : 0.0;
    final badgeTopInset = widget.isHero ? (compactMobile ? 2.0 : 4.0) : 0.0;

    return MouseRegion(
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: AnimatedScale(
        scale: baseScale,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            borderRadius: cardRadius,
            boxShadow: disabled
                ? []
                : [
                    BoxShadow(
                      color: widget.accent.withOpacity(_hovered ? glowOpacity + .04 : glowOpacity),
                      blurRadius: _hovered ? 20 : 14,
                      spreadRadius: 0,
                      offset: Offset(0, _hovered ? 10 : 7),
                    ),
                  ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: cardRadius,
              splashFactory: NoSplash.splashFactory,
              overlayColor: const WidgetStatePropertyAll(Colors.transparent),
              enableFeedback: false,
              onTap: disabled
                  ? () => ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Brak uprawnień do modułu: ${widget.requiredModule ?? widget.label}',
                          ),
                        ),
                      )
                  : widget.onTap,
              child: Ink(
                decoration: BoxDecoration(
                  borderRadius: cardRadius,
                  gradient: LinearGradient(
                    colors: backgroundGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: disabled
                        ? Colors.grey.shade300
                        : widget.accent.withOpacity(widget.isHero ? .20 : .14),
                  ),
                ),
                child: Stack(
                  children: [
                    Padding(
                      padding: cardPadding,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Padding(
                                padding: EdgeInsets.only(top: heroTopInset),
                                child: Container(
                                  width: widget.isHero ? (compactMobile ? 54 : 64) : (compactMobile ? 40 : 46),
                                  height: widget.isHero ? (compactMobile ? 54 : 64) : (compactMobile ? 40 : 46),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(compactMobile ? 14 : 18),
                                    gradient: LinearGradient(
                                      colors: disabled
                                          ? [Colors.grey.shade300, Colors.grey.shade200]
                                          : [widget.accent, Color.alphaBlend(widget.accent.withOpacity(.22), Colors.white)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    border: Border.all(
                                      color: disabled
                                          ? Colors.grey.shade300
                                          : widget.accent.withOpacity(.18),
                                    ),
                                  ),
                                  child: Icon(
                                    widget.icon,
                                    size: iconSize,
                                    color: disabled ? Colors.white70 : Colors.white,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              if (widget.badge != null)
                                Padding(
                                  padding: EdgeInsets.only(top: badgeTopInset),
                                  child: _TileBadge(
                                    label: widget.badge!,
                                    accent: widget.accent,
                                    isDisabled: disabled,
                                    compactHero: widget.isHero,
                                  ),
                                ),
                              if (disabled)
                                Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: Icon(Icons.lock, color: Colors.grey.shade500, size: 18),
                                ),
                            ],
                          ),
                          SizedBox(height: widget.isHero ? (compactMobile ? 14 : 22) : (compactMobile ? 12 : 18)),
                          Text(
                            widget.label,
                            maxLines: widget.isHero ? 2 : 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: titleColor,
                              fontWeight: FontWeight.w800,
                              fontSize: titleSize,
                              letterSpacing: -0.2,
                              height: 1.05,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.subtitle,
                            maxLines: widget.isHero ? 2 : 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: subtitleColor,
                              fontSize: widget.isHero ? (compactMobile ? 12.5 : 14) : (compactMobile ? 12 : 13),
                              height: 1.35,
                            ),
                          ),
                          const Spacer(),
                          SizedBox(
                            height: widget.isHero ? 22 : 20,
                            child: Align(
                              alignment: Alignment.bottomLeft,
                              child: Row(
                                children: [
                                  Text(
                                    disabled ? 'Brak dostępu' : 'Otwórz moduł',
                                    style: TextStyle(
                                      color: actionColor,
                                      fontWeight: FontWeight.w700,
                                      fontSize: widget.isHero ? (compactMobile ? 12.5 : 14) : (compactMobile ? 12 : 13),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  AnimatedSlide(
                                    offset: _hovered && !disabled ? const Offset(0.18, 0) : Offset.zero,
                                    duration: const Duration(milliseconds: 140),
                                    curve: Curves.easeOutCubic,
                                    child: Icon(
                                      Icons.arrow_forward_rounded,
                                      color: disabled ? Colors.grey.shade500 : widget.accent,
                                      size: 18,
                                    ),
                                  ),
                                ],
                              ),
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
        ),
      ),
    );
  }
}

class _TileBadge extends StatelessWidget {
  final String label;
  final Color accent;
  final bool isDisabled;
  final bool compactHero;

  const _TileBadge({
    required this.label,
    required this.accent,
    this.isDisabled = false,
    this.compactHero = false,
  });

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.of(context).size.width < 420;
    final pillPadding = compact
        ? const EdgeInsets.symmetric(horizontal: 7, vertical: 4)
        : compactHero
            ? const EdgeInsets.symmetric(horizontal: 8, vertical: 5)
            : const EdgeInsets.symmetric(horizontal: 9, vertical: 5);

    return Container(
      padding: pillPadding,
      decoration: BoxDecoration(
        color: isDisabled ? Colors.grey.shade200 : accent.withOpacity(.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isDisabled ? Colors.grey.shade300 : accent.withOpacity(.18),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? 5 : 6,
            height: compact ? 5 : 6,
            decoration: BoxDecoration(
              color: isDisabled ? Colors.grey.shade500 : accent,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: compact ? 5 : 6),
          Text(
            label,
            style: TextStyle(
              color: isDisabled ? Colors.grey.shade600 : accent,
              fontSize: compact ? 9.5 : compactHero ? 10 : 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardLiveSummary {
  final int openZgloszenia;
  final int harmonogramyToday;
  final int raportyToday;

  const _DashboardLiveSummary({
    required this.openZgloszenia,
    required this.harmonogramyToday,
    required this.raportyToday,
  });
}

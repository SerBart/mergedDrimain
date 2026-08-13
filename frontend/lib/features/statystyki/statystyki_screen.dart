import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/models/dashboard_kpi.dart';
import '../../core/providers/app_providers.dart';
import '../../core/utils/file_download.dart';
import '../../widgets/app_card.dart';
import '../../widgets/kpi_alert_banner.dart';
import '../../widgets/kpi_trend_chart.dart';
import '../../widgets/top_app_bar.dart';

enum _AlertProfile {
  sensitive,
  standard,
  strict,
}

class StatystykiScreen extends ConsumerStatefulWidget {
  const StatystykiScreen({super.key});

  @override
  ConsumerState<StatystykiScreen> createState() => _StatystykiScreenState();
}

class _StatystykiScreenState extends ConsumerState<StatystykiScreen> {
  bool _loading = true;
  bool _kpiLoading = false;
  bool _kpiExporting = false;
  bool _kpiPdfExporting = false;
  String? _kpiError;
  int _selectedKpiDays = 7;
  _AlertProfile _alertProfile = _AlertProfile.standard;
  String? _alertPrefsUserKey;
  final Set<String> _mutedAlertIds = <String>{};
  DashboardKpi? _kpi;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    await _ensureAlertPrefsLoaded();
    if (!mounted) return;
    setState(() {
      _loading = true;
      _kpiError = null;
    });
    try {
      final metaRepo = ref.read(metaApiRepositoryProvider);
      final kpi = await metaRepo.fetchDashboardKpi(days: _selectedKpiDays);
      if (!mounted) return;
      setState(() {
        _kpi = kpi;
        _selectedKpiDays = kpi.zakresDni;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _kpiError = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadKpiForRange(int days) async {
    if (!mounted) return;
    final previousDays = _selectedKpiDays;
    setState(() {
      _selectedKpiDays = days;
      _kpiLoading = true;
      _kpiError = null;
    });
    try {
      final metaRepo = ref.read(metaApiRepositoryProvider);
      final kpi = await metaRepo.fetchDashboardKpi(days: days);
      if (!mounted) return;
      setState(() {
        _kpi = kpi;
        _selectedKpiDays = kpi.zakresDni;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _kpiError = e.toString();
        _selectedKpiDays = _kpi?.zakresDni ?? previousDays;
      });
    } finally {
      if (mounted) setState(() => _kpiLoading = false);
    }
  }

  Future<void> _exportKpiCsv() async {
    if (_kpiExporting) return;
    setState(() => _kpiExporting = true);
    try {
      final metaRepo = ref.read(metaApiRepositoryProvider);
      final csv = await metaRepo.fetchDashboardKpiCsv(days: _selectedKpiDays);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Eksport KPI (CSV)'),
          content: SizedBox(
            width: 760,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Zakres: $_selectedKpiDays dni',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                const Text('Podgląd danych:'),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 300),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(ctx).dividerColor),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      csv,
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Zamknij'),
            ),
            FilledButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: csv));
                if (!ctx.mounted) return;
                Navigator.of(ctx).pop();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('CSV skopiowany do schowka.')),
                );
              },
              icon: const Icon(Icons.copy_all_outlined),
              label: const Text('Kopiuj CSV'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nie udało się wyeksportować KPI: $e')),
      );
    } finally {
      if (mounted) setState(() => _kpiExporting = false);
    }
  }

  Future<void> _exportKpiPdf() async {
    if (_kpiPdfExporting) return;
    setState(() => _kpiPdfExporting = true);
    try {
      final metaRepo = ref.read(metaApiRepositoryProvider);
      final pdf = await metaRepo.fetchDashboardKpiPdf(days: _selectedKpiDays);
      if (!mounted) return;

      final fileName = 'dashboard-kpi-${_selectedKpiDays}d.pdf';
      final downloaded = downloadBytesAsFile(
        fileName: fileName,
        mimeType: 'application/pdf',
        bytes: pdf,
      );

      if (!downloaded) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Pobieranie pliku PDF jest wspierane w wersji web aplikacji.'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nie udało się wyeksportować KPI do PDF: $e')),
      );
    } finally {
      if (mounted) setState(() => _kpiPdfExporting = false);
    }
  }

  Future<void> _ensureAlertPrefsLoaded() async {
    final username = ref.read(authStateProvider)?.username?.trim();
    if (username == null || username.isEmpty) return;

    final userKey = username.toLowerCase();
    if (_alertPrefsUserKey == userKey) return;

    final storage = ref.read(secureStorageProvider);
    final profileRaw =
        await storage.readString('dashboard:kpi:alertProfile:$userKey');
    final mutedRaw =
        await storage.readString('dashboard:kpi:muted:$userKey');

    _AlertProfile? profile;
    for (final candidate in _AlertProfile.values) {
      if (candidate.name == profileRaw) {
        profile = candidate;
        break;
      }
    }
    final muted = (mutedRaw ?? '')
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet();

    if (!mounted) return;
    setState(() {
      _alertPrefsUserKey = userKey;
      _alertProfile = profile ?? _AlertProfile.standard;
      _mutedAlertIds
        ..clear()
        ..addAll(muted);
    });
  }

  Future<void> _persistAlertPrefs() async {
    final userKey = _alertPrefsUserKey;
    if (userKey == null || userKey.isEmpty) return;

    final storage = ref.read(secureStorageProvider);
    await storage.writeString(
        'dashboard:kpi:alertProfile:$userKey', _alertProfile.name);
    if (_mutedAlertIds.isEmpty) {
      await storage.deleteByKey('dashboard:kpi:muted:$userKey');
    } else {
      await storage.writeString(
          'dashboard:kpi:muted:$userKey', _mutedAlertIds.join(','));
    }
  }

  Future<void> _muteAlert(KpiAlertItem item) async {
    if (_mutedAlertIds.contains(item.id)) return;
    setState(() => _mutedAlertIds.add(item.id));
    await _persistAlertPrefs();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Alert "${item.title}" został wyciszony.')),
    );
  }

  Future<void> _resetMutedAlerts() async {
    if (_mutedAlertIds.isEmpty) return;
    setState(() => _mutedAlertIds.clear());
    await _persistAlertPrefs();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStateProvider);
    final userKey = auth?.username?.trim().toLowerCase();
    if (userKey != null &&
        userKey.isNotEmpty &&
        _alertPrefsUserKey != userKey) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _ensureAlertPrefsLoaded());
    }

    final visibleAlerts = _buildKpiAlerts(_kpi, _alertProfile)
        .where((item) => !_mutedAlertIds.contains(item.id))
        .toList();

    return Scaffold(
      appBar: const TopAppBar(title: 'Statystyki i KPI', showBack: true),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            // ── KPI i statystyki ──────────────────────────────────────────
            AppCard(
              title: 'KPI i statystyki',
              divided: true,
              action: Wrap(
                spacing: 10,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (_kpi?.lastUpdated != null)
                    Text(
                      'Aktualizacja: ${DateFormat('yyyy-MM-dd HH:mm').format(_kpi!.lastUpdated!.toLocal())}',
                      style: const TextStyle(
                          fontSize: 12, color: Colors.black54),
                    ),
                  OutlinedButton.icon(
                    onPressed: (_kpi == null || _kpiExporting)
                        ? null
                        : _exportKpiCsv,
                    icon: _kpiExporting
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child:
                                CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download_outlined),
                    label: Text(
                        _kpiExporting ? 'Eksport...' : 'Eksport CSV'),
                  ),
                  OutlinedButton.icon(
                    onPressed: (_kpi == null || _kpiPdfExporting)
                        ? null
                        : _exportKpiPdf,
                    icon: _kpiPdfExporting
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child:
                                CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.picture_as_pdf_outlined),
                    label: Text(
                        _kpiPdfExporting ? 'Eksport...' : 'Eksport PDF'),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _KpiRangeSelector(
                    selectedDays: _selectedKpiDays,
                    isLoading: _kpiLoading,
                    onSelected: _loadKpiForRange,
                  ),
                  const SizedBox(height: 12),
                  if (_kpiError != null && _kpi != null) ...[
                    Text(
                      'Nie udało się odświeżyć KPI dla wybranego zakresu. Widoczne są ostatnio pobrane dane.',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if ((_loading || _kpiLoading) && _kpi == null)
                    const Center(
                        child: Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator()))
                  else if (_kpi == null)
                    _ErrorBlock(
                      message: _kpiError ??
                          'Nie udało się pobrać statystyk KPI.',
                      onRetry: () =>
                          _loadKpiForRange(_selectedKpiDays),
                    )
                  else
                    _KpiOverview(
                      kpi: _kpi!,
                      isRefreshing: _kpiLoading,
                    ),
                ],
              ),
            ),

            // ── Trendy operacyjne ─────────────────────────────────────────
            AppCard(
              title: 'Trendy operacyjne',
              divided: true,
              child: Column(
                children: [
                  KpiTrendChart(
                    title: 'Zgłoszenia w czasie',
                    subtitle:
                        'Liczba zgłoszeń w wybranym okresie',
                    points: _kpi?.zgloszeniaTrend ?? const [],
                    accentColor: Colors.orange.shade600,
                  ),
                  const SizedBox(height: 16),
                  KpiTrendChart(
                    title: 'Raporty w czasie',
                    subtitle:
                        'Liczba raportów w wybranym okresie',
                    points: _kpi?.raportyTrend ?? const [],
                    accentColor: Colors.blue.shade600,
                  ),
                ],
              ),
            ),

            // ── Alerty KPI ────────────────────────────────────────────────
            AppCard(
              title: 'Alerty KPI',
              divided: true,
              action: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Tryb: ',
                      style: TextStyle(
                          fontSize: 12, color: Colors.black54)),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<_AlertProfile>(
                      value: _alertProfile,
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _alertProfile = value);
                        _persistAlertPrefs();
                      },
                      items: const [
                        DropdownMenuItem(
                            value: _AlertProfile.sensitive,
                            child: Text('Czuły')),
                        DropdownMenuItem(
                            value: _AlertProfile.standard,
                            child: Text('Standard')),
                        DropdownMenuItem(
                            value: _AlertProfile.strict,
                            child: Text('Surowy')),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _mutedAlertIds.isEmpty
                        ? null
                        : _resetMutedAlerts,
                    child: Text(
                      _mutedAlertIds.isEmpty
                          ? 'Brak wyciszeń'
                          : 'Przywróć alerty (${_mutedAlertIds.length})',
                    ),
                  ),
                ],
              ),
              child: KpiAlertBanner(
                items: visibleAlerts,
                onMute: _muteAlert,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helpers (private to this file) ─────────────────────────────────────────

List<KpiAlertItem> _buildKpiAlerts(
    DashboardKpi? kpi, _AlertProfile profile) {
  if (kpi == null) return const [];

  final thresholds = _thresholdsForProfile(profile);
  final items = <KpiAlertItem>[];
  final downtimeRatio = kpi.maszynyRazem <= 0
      ? 0.0
      : (kpi.maszynyWPrzestoju * 100.0) / kpi.maszynyRazem;

  if (downtimeRatio >= thresholds.downtimeRatioPercent) {
    items.add(KpiAlertItem(
      id: 'machines-downtime',
      title: 'Maszyny w przestoju',
      message:
          'W przestoju pozostaje ${kpi.maszynyWPrzestoju} z ${kpi.maszynyRazem} maszyn (${downtimeRatio.toStringAsFixed(1)}%).',
      icon: Icons.warning_amber_rounded,
      color: Colors.red,
    ));
  }

  if (kpi.zgloszeniaZmianaProcent >= thresholds.growthPercent) {
    items.add(KpiAlertItem(
      id: 'incidents-growth',
      title: 'Wzrost liczby zgłoszeń',
      message:
          'W porównaniu do poprzedniego okresu liczba nowych zgłoszeń wzrosła o ${kpi.zgloszeniaZmianaProcent.toStringAsFixed(1)}%.',
      icon: Icons.trending_up,
      color: Colors.deepOrange,
    ));
  }

  if (kpi.raportyWOkresie == 0) {
    items.add(KpiAlertItem(
      id: 'no-reports-in-range',
      title: 'Brak raportów w okresie',
      message:
          'W wybranym okresie nie dodano jeszcze żadnego raportu.',
      icon: Icons.event_busy_outlined,
      color: Colors.blueGrey,
    ));
  }

  if (kpi.sredniCzasRozwiazaniaGodziny >= thresholds.avgSolveHours) {
    items.add(KpiAlertItem(
      id: 'slow-resolution',
      title: 'Wydłużony czas rozwiązania',
      message:
          'Średni czas rozwiązania wynosi ${kpi.sredniCzasRozwiazaniaGodziny.toStringAsFixed(1)} h.',
      icon: Icons.schedule,
      color: Colors.orange,
    ));
  }

  if (items.isEmpty) {
    items.add(KpiAlertItem(
      id: 'all-good',
      title: 'Wszystko wygląda dobrze',
      message:
          'Nie wykryto krytycznych alertów w aktualnym zakresie KPI.',
      icon: Icons.verified_outlined,
      color: Colors.green,
    ));
  }

  return items;
}

_AlertThresholds _thresholdsForProfile(_AlertProfile profile) {
  switch (profile) {
    case _AlertProfile.sensitive:
      return const _AlertThresholds(
          growthPercent: 15,
          avgSolveHours: 6,
          downtimeRatioPercent: 5);
    case _AlertProfile.strict:
      return const _AlertThresholds(
          growthPercent: 35,
          avgSolveHours: 10,
          downtimeRatioPercent: 20);
    case _AlertProfile.standard:
      return const _AlertThresholds(
          growthPercent: 25,
          avgSolveHours: 8,
          downtimeRatioPercent: 10);
  }
}

class _AlertThresholds {
  final int growthPercent;
  final int avgSolveHours;
  final int downtimeRatioPercent;

  const _AlertThresholds({
    required this.growthPercent,
    required this.avgSolveHours,
    required this.downtimeRatioPercent,
  });
}

// ── KPI range selector ──────────────────────────────────────────────────────
class _KpiRangeSelector extends StatelessWidget {
  final int selectedDays;
  final bool isLoading;
  final ValueChanged<int> onSelected;

  const _KpiRangeSelector({
    required this.selectedDays,
    required this.isLoading,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    const options = [1, 7, 30];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text('Zakres KPI:',
            style: TextStyle(fontWeight: FontWeight.w700)),
        ...options.map(
          (days) => ChoiceChip(
            label: Text(_labelForDays(days)),
            selected: selectedDays == days,
            onSelected: isLoading || selectedDays == days
                ? null
                : (_) => onSelected(days),
          ),
        ),
        if (isLoading)
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
      ],
    );
  }

  static String _labelForDays(int days) {
    if (days == 1) return 'Dzisiaj';
    return '$days dni';
  }
}

// ── KPI overview ────────────────────────────────────────────────────────────
class _KpiOverview extends StatelessWidget {
  final DashboardKpi kpi;
  final bool isRefreshing;

  const _KpiOverview({required this.kpi, this.isRefreshing = false});

  @override
  Widget build(BuildContext context) {
    final rangeLabel = _buildRangeLabel(kpi.zakresDni);
    final formattedPeriod = _formatPeriod(kpi.okresOd, kpi.okresDo);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color:
                Theme.of(context).colorScheme.primary.withOpacity(.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Theme.of(context)
                  .colorScheme
                  .primary
                  .withOpacity(.12),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.insights_outlined, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Pokazuję statystyki za: $rangeLabel${formattedPeriod == null ? '' : ' • $formattedPeriod'}',
                  style:
                      const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              if (isRefreshing)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _KpiTile(
                label: 'Nowe zgłoszenia ($rangeLabel)',
                value: '${kpi.zgloszeniaWOkresieNowe}',
                icon: Icons.fiber_new),
            _KpiTile(
                label: 'W toku ($rangeLabel)',
                value: '${kpi.zgloszeniaWOkresieWToku}',
                icon: Icons.pending_actions),
            _KpiTile(
                label: 'Zamknięte ($rangeLabel)',
                value: '${kpi.zgloszeniaWOkresieZamkniete}',
                icon: Icons.task_alt),
            _KpiTile(
                label: 'Raporty ($rangeLabel)',
                value: '${kpi.raportyWOkresie}',
                icon: Icons.description_outlined),
            _KpiTile(
                label: 'Raporty dziś',
                value: '${kpi.raportyDzis}',
                icon: Icons.today_outlined),
            _KpiTile(
                label: 'Śr. czas rozwiązania',
                value:
                    '${kpi.sredniCzasRozwiazaniaGodziny.toStringAsFixed(1)} h',
                icon: Icons.schedule),
            _KpiTile(
                label: 'Maszyny w pracy',
                value:
                    '${kpi.maszynyWPracy}/${kpi.maszynyRazem}',
                icon: Icons.precision_manufacturing),
            _KpiTile(
                label: 'Maszyny w przestoju',
                value: '${kpi.maszynyWPrzestoju}',
                icon: Icons.warning_amber_rounded),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          'Top 3 typy zgłoszeń ($rangeLabel)',
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
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

  String _buildRangeLabel(int days) {
    if (days <= 1) return 'dzisiaj';
    return 'ostatnie $days dni';
  }

  String? _formatPeriod(DateTime? from, DateTime? to) {
    if (from == null || to == null) return null;
    final fmt = DateFormat('dd.MM.yyyy');
    if (from.year == to.year &&
        from.month == to.month &&
        from.day == to.day) {
      return fmt.format(from);
    }
    return '${fmt.format(from)} – ${fmt.format(to)}';
  }
}

// ── Small KPI tile ──────────────────────────────────────────────────────────
class _KpiTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _KpiTile(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withOpacity(.45),
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
                Text(value,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 2),
                Text(label,
                    style: const TextStyle(
                        fontSize: 12, color: Colors.black54)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Error block ─────────────────────────────────────────────────────────────
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


import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'dart:async';

import '../../core/models/energia.dart';
import '../../core/providers/app_providers.dart';
import '../../widgets/app_card.dart';
import '../../widgets/energy_line_chart.dart';
import '../../widgets/top_app_bar.dart';

class EnergiaScreen extends ConsumerStatefulWidget {
  const EnergiaScreen({super.key});

  @override
  ConsumerState<EnergiaScreen> createState() => _EnergiaScreenState();
}

class _EnergiaScreenState extends ConsumerState<EnergiaScreen> {
  bool _loading = true;
  bool _historyLoading = false;
  String? _error;
  int _selectedDays = 7;
  EnergyScope _scope = EnergyScope.total;
  int? _selectedDzialId;
  int? _selectedMaszynaId;
  EnergyOverview? _catalogOverview;
  EnergyOverview? _overview;
  List<EnergyHistoryPoint> _history = const [];
  StreamSubscription<EnergyOverview>? _sseSubscription;
  Timer? _sseReconnectTimer;
  int _sseRetrySeconds = 2;
  Timer? _autoRefreshTimer;
  Timer? _historyRefreshDebounce;

  @override
  void initState() {
    super.initState();
    _startAutoRefresh();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reloadAll());
  }

  @override
  void dispose() {
    _sseSubscription?.cancel();
    _sseReconnectTimer?.cancel();
    _autoRefreshTimer?.cancel();
    _historyRefreshDebounce?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) {
        _refreshLiveDataSilently();
      },
    );
  }

  void _startSseStream() {
    _sseReconnectTimer?.cancel();
    _sseSubscription?.cancel();
    final repo = ref.read(energiaApiRepositoryProvider);
    _sseSubscription = repo
        .streamOverview(
          scope: _scope,
          dzialId: _scope == EnergyScope.dzial ? _selectedDzialId : null,
          maszynaId: _scope == EnergyScope.maszyna ? _selectedMaszynaId : null,
        )
        .listen(
          (overview) {
            if (!mounted) return;
            _sseRetrySeconds = 2;
            setState(() {
              _overview = overview;
              if (_scope == EnergyScope.total) {
                _catalogOverview = overview;
              }
            });
            _scheduleHistoryRefresh();
          },
          onError: (e) {
            if (!mounted) return;
            _scheduleSseReconnect();
          },
        );
  }

  void _scheduleSseReconnect() {
    _sseReconnectTimer?.cancel();
    _sseSubscription?.cancel();
    final delay = Duration(seconds: _sseRetrySeconds);
    _sseReconnectTimer = Timer(delay, () {
      if (!mounted) return;
      _startSseStream();
    });
    _sseRetrySeconds = ((_sseRetrySeconds * 2).clamp(2, 30) as num).toInt();
  }

  void _scheduleHistoryRefresh() {
    _historyRefreshDebounce?.cancel();
    _historyRefreshDebounce = Timer(
      const Duration(seconds: 2),
      () {
        _reloadHistorySilently();
      },
    );
  }

  Future<void> _refreshLiveDataSilently() async {
    if (!mounted || _catalogOverview == null) return;
    if ((_scope == EnergyScope.dzial && _selectedDzialId == null) ||
        (_scope == EnergyScope.maszyna && _selectedMaszynaId == null)) {
      return;
    }

    try {
      final repo = ref.read(energiaApiRepositoryProvider);
      final overview = await repo.fetchOverview(
        scope: _scope,
        days: _selectedDays,
        dzialId: _scope == EnergyScope.dzial ? _selectedDzialId : null,
        maszynaId: _scope == EnergyScope.maszyna ? _selectedMaszynaId : null,
      );
      if (!mounted) return;
      setState(() {
        _overview = overview;
        if (_scope == EnergyScope.total) {
          _catalogOverview = overview;
        }
        _error = null;
      });
      await _reloadHistorySilently();
    } catch (_) {
      // Silent refresh should not break an already visible screen.
    }
  }

  Future<void> _reloadHistorySilently() async {
    final overview = _overview;
    if (!mounted || overview == null) return;
    if (_scope == EnergyScope.dzial && _selectedDzialId == null) return;
    if (_scope == EnergyScope.maszyna && _selectedMaszynaId == null) return;

    try {
      final repo = ref.read(energiaApiRepositoryProvider);
      final points = await repo.fetchHistory(
        scope: _scope,
        days: _selectedDays,
        bucketMinutes: 15,
        dzialId: _scope == EnergyScope.dzial ? _selectedDzialId : null,
        maszynaId: _scope == EnergyScope.maszyna ? _selectedMaszynaId : null,
      );
      if (!mounted) return;
      setState(() {
        _history = points;
        _error = null;
      });
    } catch (_) {
      // Silent refresh should not replace visible data with an error.
    }
  }

  Future<void> _reloadAll() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(energiaApiRepositoryProvider);
      final catalog = await repo.fetchOverview(scope: EnergyScope.total, days: _selectedDays);
      if (!mounted) return;
      setState(() {
        _catalogOverview = catalog;
        _syncSelectionDefaults();
      });

      if ((_scope == EnergyScope.dzial && _selectedDzialId == null) ||
          (_scope == EnergyScope.maszyna && _selectedMaszynaId == null)) {
        if (!mounted) return;
        setState(() {
          _overview = EnergyOverview(
            scopeType: _scope.apiValue,
            scopeLabel: _scope.label,
            zakresDni: _selectedDays,
            bucketMinutes: 15,
            generatedAt: DateTime.now(),
            totalPowerKw: 0,
            todayEnergyKwh: 0,
            activeMachines: 0,
            totalMachines: 0,
            machines: const [],
          );
          _history = const [];
        });
        return;
      }

      final overview = _scope == EnergyScope.total
          ? catalog
          : await repo.fetchOverview(
              scope: _scope,
              days: _selectedDays,
              dzialId: _scope == EnergyScope.dzial ? _selectedDzialId : null,
              maszynaId: _scope == EnergyScope.maszyna ? _selectedMaszynaId : null,
            );

      if (!mounted) return;
      setState(() => _overview = overview);
      _startSseStream(); // Start SSE stream
      await _reloadHistory();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reloadCurrentView() async {
    if (_catalogOverview == null) {
      await _reloadAll();
      return;
    }
    if (!mounted) return;
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      if ((_scope == EnergyScope.dzial && _selectedDzialId == null) ||
          (_scope == EnergyScope.maszyna && _selectedMaszynaId == null)) {
        if (!mounted) return;
        setState(() {
          _overview = EnergyOverview(
            scopeType: _scope.apiValue,
            scopeLabel: _scope.label,
            zakresDni: _selectedDays,
            bucketMinutes: 15,
            generatedAt: DateTime.now(),
            totalPowerKw: 0,
            todayEnergyKwh: 0,
            activeMachines: 0,
            totalMachines: 0,
            machines: const [],
          );
          _history = const [];
        });
        return;
      }
      final repo = ref.read(energiaApiRepositoryProvider);
      final overview = _scope == EnergyScope.total
          ? _catalogOverview!
          : await repo.fetchOverview(
              scope: _scope,
              days: _selectedDays,
              dzialId: _scope == EnergyScope.dzial ? _selectedDzialId : null,
              maszynaId: _scope == EnergyScope.maszyna ? _selectedMaszynaId : null,
            );
      if (!mounted) return;
      setState(() => _overview = overview);
      _startSseStream(); // Start SSE stream
      await _reloadHistory();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reloadHistory() async {
    final overview = _overview;
    if (overview == null) {
      setState(() => _history = const []);
      return;
    }

    if (_scope == EnergyScope.dzial && _selectedDzialId == null) {
      setState(() => _history = const []);
      return;
    }
    if (_scope == EnergyScope.maszyna && _selectedMaszynaId == null) {
      setState(() => _history = const []);
      return;
    }

    setState(() => _historyLoading = true);
    try {
      final repo = ref.read(energiaApiRepositoryProvider);
      final points = await repo.fetchHistory(
        scope: _scope,
        days: _selectedDays,
        bucketMinutes: 15,
        dzialId: _scope == EnergyScope.dzial ? _selectedDzialId : null,
        maszynaId: _scope == EnergyScope.maszyna ? _selectedMaszynaId : null,
      );
      if (!mounted) return;
      setState(() => _history = points);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _historyLoading = false);
    }
  }

  void _syncSelectionDefaults() {
    final catalog = _catalogOverview;
    if (catalog == null) return;

    if (_scope == EnergyScope.total) {
      _selectedDzialId = null;
      _selectedMaszynaId = null;
      return;
    }

    final departments = _availableDepartments;
    final machines = _availableMachines;

    if (_scope == EnergyScope.dzial) {
      final validDepartment = departments.any((d) => d.id == _selectedDzialId)
          ? _selectedDzialId
          : (departments.isNotEmpty ? departments.first.id : null);
      _selectedDzialId = validDepartment;
      _selectedMaszynaId = null;
    } else if (_scope == EnergyScope.maszyna) {
      final validMachine = machines.any((m) => m.maszynaId == _selectedMaszynaId)
          ? _selectedMaszynaId
          : (machines.isNotEmpty ? machines.first.maszynaId : null);
      _selectedMaszynaId = validMachine;
      _selectedDzialId = null;
    }
  }

  Future<void> _changeScope(EnergyScope scope) async {
    if (_scope == scope) return;
    if (scope == EnergyScope.dzial && _availableDepartments.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Brak działów z przypisanymi maszynami.')));
      }
      return;
    }
    if (scope == EnergyScope.maszyna && _availableMachines.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Brak maszyn z odczytami do wyboru.')));
      }
      return;
    }
    setState(() {
      _scope = scope;
      _error = null;
      if (scope == EnergyScope.total) {
        _selectedDzialId = null;
        _selectedMaszynaId = null;
      } else if (_catalogOverview != null) {
        _syncSelectionDefaults();
      }
    });
    await _reloadCurrentView();
  }

  Future<void> _changeDays(int days) async {
    if (_selectedDays == days) return;
    setState(() => _selectedDays = days);
    await _reloadAll();
  }

  Future<void> _selectDepartment(int? dzialId) async {
    if (dzialId == null) return;
    setState(() {
      _scope = EnergyScope.dzial;
      _selectedDzialId = dzialId;
      _selectedMaszynaId = null;
      _error = null;
    });
    await _reloadCurrentView();
  }

  Future<void> _selectMachine(int? maszynaId) async {
    if (maszynaId == null) return;
    setState(() {
      _scope = EnergyScope.maszyna;
      _selectedMaszynaId = maszynaId;
      _selectedDzialId = null;
      _error = null;
    });
    await _reloadCurrentView();
  }

  List<_DepartmentOption> get _availableDepartments {
    final catalog = _catalogOverview;
    if (catalog == null) return const [];
    final map = <int, _DepartmentOption>{};
    for (final machine in catalog.machines) {
      final id = machine.dzialId;
      if (id == null) continue;
      map.putIfAbsent(
        id,
        () => _DepartmentOption(
          id: id,
          name: machine.dzialNazwa?.isNotEmpty == true ? machine.dzialNazwa! : 'Dział #$id',
        ),
      );
    }
    return map.values.toList();
  }

  List<EnergyMachineSummary> get _availableMachines => _catalogOverview?.machines ?? const [];

  EnergyMachineSummary? get _selectedMachine {
    final overview = _overview;
    if (overview == null || _selectedMaszynaId == null) return null;
    for (final machine in overview.machines) {
      if (machine.maszynaId == _selectedMaszynaId) return machine;
    }
    return null;
  }

  _DepartmentOption? get _selectedDepartment {
    final id = _selectedDzialId;
    if (id == null) return null;
    for (final dept in _availableDepartments) {
      if (dept.id == id) return dept;
    }
    return null;
  }

  List<_DepartmentAggregate> get _departmentAggregates {
    final catalog = _catalogOverview;
    if (catalog == null) return const [];
    final map = <int, _DepartmentAggregate>{};
    for (final machine in catalog.machines) {
      final id = machine.dzialId;
      if (id == null) continue;
      final key = id;
      map.putIfAbsent(
        key,
        () => _DepartmentAggregate(
          id: key,
          name: machine.dzialNazwa?.isNotEmpty == true ? machine.dzialNazwa! : 'Dział #$key',
        ),
      );
      map[key] = map[key]!.copyWith(
        powerKw: map[key]!.powerKw + machine.powerKw,
        todayEnergyKwh: map[key]!.todayEnergyKwh + machine.todayEnergyKwh,
        machineCount: map[key]!.machineCount + 1,
      );
    }
    final items = map.values.toList();
    items.sort((a, b) => b.powerKw.compareTo(a.powerKw));
    return items;
  }

  List<EnergyMachineSummary> get _sortedCurrentMachines {
    final overview = _overview;
    if (overview == null) return const [];
    final items = [...overview.machines];
    items.sort((a, b) => b.powerKw.compareTo(a.powerKw));
    return items;
  }

  double get _historyAveragePower {
    if (_history.isEmpty) return 0;
    final total = _history.fold<double>(0, (sum, point) => sum + point.powerKw);
    return total / _history.length;
  }

  EnergyHistoryPoint? get _peakHistoryPoint {
    if (_history.isEmpty) return null;
    return _history.reduce((a, b) => a.powerKw >= b.powerKw ? a : b);
  }

  double get _historyEnergySum {
    final sorted = [..._history]..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    final totals = sorted.map((point) => point.energyKwhTotal).whereType<double>().toList();
    if (totals.length < 2) return 0;
    final first = totals.first;
    final last = totals.last;
    return (last - first).clamp(0, double.infinity);
  }

  @override
  Widget build(BuildContext context) {
    final overview = _overview;
    final selectedMachine = _selectedMachine;
    final selectedDepartment = _selectedDepartment;
    final isEmpty = overview == null || overview.machines.isEmpty;
    final selectedScopeLabel = overview?.scopeLabel ?? _scope.label;

    return Scaffold(
      appBar: const TopAppBar(title: 'Zużycie energii', showBack: true),
      body: RefreshIndicator(
        onRefresh: _reloadAll,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _buildHeroCard(context, overview, selectedScopeLabel),
            const SizedBox(height: 12),
            if (_loading && overview == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null && overview == null)
              AppCard(
                title: 'Błąd ładowania',
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(_error!),
                ),
              )
            else ...[
              AppCard(
                title: 'Zakres danych',
                divided: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _ScopeChip(
                          label: 'Całość',
                          icon: Icons.apartment_outlined,
                          selected: _scope == EnergyScope.total,
                          onTap: () => _changeScope(EnergyScope.total),
                        ),
                        _ScopeChip(
                          label: 'Dział',
                          icon: Icons.groups_2_outlined,
                          selected: _scope == EnergyScope.dzial,
                          onTap: () => _changeScope(EnergyScope.dzial),
                        ),
                        _ScopeChip(
                          label: 'Maszyna',
                          icon: Icons.precision_manufacturing_outlined,
                          selected: _scope == EnergyScope.maszyna,
                          onTap: () => _changeScope(EnergyScope.maszyna),
                        ),
                        _ScopeChip(
                          label: '1 dzień',
                          icon: Icons.looks_one_outlined,
                          selected: _selectedDays == 1,
                          onTap: () => _changeDays(1),
                        ),
                        _ScopeChip(
                          label: '7 dni',
                          icon: Icons.date_range_outlined,
                          selected: _selectedDays == 7,
                          onTap: () => _changeDays(7),
                        ),
                        _ScopeChip(
                          label: '30 dni',
                          icon: Icons.calendar_month_outlined,
                          selected: _selectedDays == 30,
                          onTap: () => _changeDays(30),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (_scope == EnergyScope.dzial) ...[
                      DropdownButtonFormField<int>(
                        value: _selectedDzialId,
                        decoration: const InputDecoration(
                          labelText: 'Wybierz dział',
                          border: OutlineInputBorder(),
                        ),
                        isExpanded: true,
                        items: _availableDepartments
                            .map((d) => DropdownMenuItem<int>(value: d.id, child: Text(d.name)))
                            .toList(),
                        onChanged: _selectDepartment,
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (_scope == EnergyScope.maszyna) ...[
                      DropdownButtonFormField<int>(
                        value: _selectedMaszynaId,
                        decoration: const InputDecoration(
                          labelText: 'Wybierz maszynę',
                          border: OutlineInputBorder(),
                        ),
                        isExpanded: true,
                        items: _availableMachines
                            .map((m) => DropdownMenuItem<int>(value: m.maszynaId, child: Text(m.maszynaNazwa)))
                            .toList(),
                        onChanged: _selectMachine,
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (_scope == EnergyScope.total && _departmentAggregates.isNotEmpty) ...[
                      Text(
                        'Szybkie przejście do działu',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _departmentAggregates
                              .take(6)
                              .map(
                                (dept) => Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ActionChip(
                                    avatar: const Icon(Icons.groups_2_outlined, size: 18),
                                    label: Text('${dept.name} • ${dept.machineCount}'),
                                    onPressed: () => _selectDepartment(dept.id),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ],
                    if (overview?.generatedAt != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Aktualizacja: ${DateFormat('yyyy-MM-dd HH:mm').format(overview!.generatedAt!.toLocal())}',
                        style: const TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AppCard(
                title: 'Najważniejsze liczby',
                divided: true,
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _MetricTile(
                      label: 'Moc chwilowa',
                      value: '${overview?.totalPowerKw.toStringAsFixed(1) ?? '0.0'} kW',
                      icon: Icons.flash_on_outlined,
                      accent: Colors.orange,
                    ),
                    _MetricTile(
                      label: 'Zużycie dziś',
                      value: '${overview?.todayEnergyKwh.toStringAsFixed(1) ?? '0.0'} kWh',
                      icon: Icons.bolt_outlined,
                      accent: Colors.green,
                    ),
                    _MetricTile(
                      label: 'Aktywne',
                      value: '${overview?.activeMachines ?? 0}/${overview?.totalMachines ?? 0}',
                      icon: Icons.toggle_on_outlined,
                      accent: Colors.blue,
                    ),
                    _MetricTile(
                      label: 'Punktów historii',
                      value: '${_history.length}',
                      icon: Icons.show_chart_outlined,
                      accent: Colors.purple,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AppCard(
                title: 'Historia 15-minutowa',
                divided: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_historyLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_history.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          _scope == EnergyScope.maszyna
                              ? 'Brak historii dla wybranej maszyny.'
                              : 'Brak historii dla wybranego zakresu.',
                        ),
                      )
                    else ...[
                      EnergyLineChart(
                        title: selectedScopeLabel,
                        subtitle: _scope == EnergyScope.total
                            ? 'Sumaryczny pobór wszystkich maszyn'
                            : _scope == EnergyScope.dzial
                                ? 'Suma poboru w wybranym dziale'
                                : 'Pobór wybranej maszyny',
                        points: _history,
                        accentColor: Colors.green.shade600,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _MiniInsightCard(
                            label: 'Średnia moc',
                            value: '${_historyAveragePower.toStringAsFixed(1)} kW',
                            icon: Icons.auto_graph_outlined,
                          ),
                          _MiniInsightCard(
                            label: 'Szczyt',
                            value: '${_peakHistoryPoint?.powerKw.toStringAsFixed(1) ?? '0.0'} kW',
                            icon: Icons.trending_up_outlined,
                          ),
                          _MiniInsightCard(
                            label: 'Suma energii',
                            value: '${_historyEnergySum.toStringAsFixed(1)} kWh',
                            icon: Icons.battery_charging_full_outlined,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Ostatnie pomiary',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      ..._history.reversed.take(10).map(
                            (point) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              leading: const Icon(Icons.bolt_outlined, color: Colors.green),
                              title: Text(
                                '${DateFormat('yyyy-MM-dd HH:mm').format(point.recordedAt.toLocal())} • ${point.powerKw.toStringAsFixed(1)} kW',
                              ),
                              subtitle: Text(
                                [
                                  if (point.energyKwhTotal != null) 'Energia ${point.energyKwhTotal!.toStringAsFixed(1)} kWh',
                                  if (point.voltageV != null) 'U ${point.voltageV!.toStringAsFixed(0)} V',
                                  if (point.currentA != null) 'I ${point.currentA!.toStringAsFixed(1)} A',
                                ].join(' • '),
                              ),
                            ),
                          ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AppCard(
                title: _scope == EnergyScope.total
                    ? 'Top odbiorcy energii'
                    : _scope == EnergyScope.dzial
                        ? 'Maszyny w dziale'
                        : 'Szczegóły maszyny',
                divided: true,
                child: Column(
                  children: _sortedCurrentMachines.isEmpty
                      ? [
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 18),
                            child: Text('Brak maszyn do pokazania.'),
                          ),
                        ]
                      : _sortedCurrentMachines.take(_scope == EnergyScope.maszyna ? 1 : 5).map((machine) {
                          final selected = machine.maszynaId == _selectedMaszynaId;
                          final departmentLabel = machine.dzialNazwa?.isNotEmpty == true ? machine.dzialNazwa! : 'Brak działu';
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Card(
                              elevation: 0,
                              color: selected ? Colors.green.shade50 : Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(.25),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: selected ? Colors.green.shade100 : Colors.green.shade50,
                                  child: const Icon(Icons.precision_manufacturing_outlined, color: Colors.green),
                                ),
                                title: Text(machine.maszynaNazwa),
                                subtitle: Text(
                                  [
                                    departmentLabel,
                                    if (machine.lastRecordedAt != null) 'Ostatni odczyt ${DateFormat('HH:mm').format(machine.lastRecordedAt!.toLocal())}',
                                    if (machine.deviceId != null && machine.deviceId!.isNotEmpty) 'Device ${machine.deviceId}',
                                    'Dziś ${machine.todayEnergyKwh.toStringAsFixed(1)} kWh',
                                  ].join(' • '),
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('${machine.powerKw.toStringAsFixed(1)} kW', style: const TextStyle(fontWeight: FontWeight.w800)),
                                    Text('${machine.readingsCount} pomiarów', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                                  ],
                                ),
                                onTap: () => _selectMachine(machine.maszynaId),
                              ),
                            ),
                          );
                        }).toList(),
                ),
              ),
              if (_scope == EnergyScope.total && _departmentAggregates.isNotEmpty) ...[
                const SizedBox(height: 12),
                AppCard(
                  title: 'Najmocniejsze działy',
                  divided: true,
                  child: Column(
                    children: _departmentAggregates.take(4).map((dept) {
                      final maxPower = _departmentAggregates.isEmpty ? 1.0 : _departmentAggregates.first.powerKw == 0 ? 1.0 : _departmentAggregates.first.powerKw;
                      final progress = (dept.powerKw / maxPower).clamp(0.0, 1.0);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => _selectDepartment(dept.id),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50.withOpacity(.55),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.green.shade100),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        dept.name,
                                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                                      ),
                                    ),
                                    Text('${dept.powerKw.toStringAsFixed(1)} kW'),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(999),
                                  child: LinearProgressIndicator(
                                    minHeight: 8,
                                    value: progress,
                                    backgroundColor: Colors.green.shade100,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade600),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text('${dept.machineCount} maszyn • dziś ${dept.todayEnergyKwh.toStringAsFixed(1)} kWh', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
              if (overview == null || isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: AppCard(
                    title: 'Brak danych',
                    child: Text(
                      _scope == EnergyScope.total
                          ? 'Nie znaleziono jeszcze odczytów energii.'
                          : _scope == EnergyScope.dzial
                              ? 'Ten dział nie ma jeszcze zapisanych odczytów.'
                              : 'Ta maszyna nie ma jeszcze zapisanych odczytów.',
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard(BuildContext context, EnergyOverview? overview, String scopeLabel) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [scheme.primary, scheme.primaryContainer],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withOpacity(.18),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -16,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(.12)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.bolt_rounded, color: Colors.white, size: 36),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Panel zużycia energii',
                            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            scopeLabel,
                            style: TextStyle(color: Colors.white.withOpacity(.92), fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _reloadAll,
                      icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                      tooltip: 'Odśwież',
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _HeroStat(
                      label: 'Moc chwilowa',
                      value: '${overview?.totalPowerKw.toStringAsFixed(1) ?? '0.0'} kW',
                      icon: Icons.flash_on_rounded,
                    ),
                    _HeroStat(
                      label: 'Zużycie dziś',
                      value: '${overview?.todayEnergyKwh.toStringAsFixed(1) ?? '0.0'} kWh',
                      icon: Icons.bolt_rounded,
                    ),
                    _HeroStat(
                      label: 'Aktywne maszyny',
                      value: '${overview?.activeMachines ?? 0}/${overview?.totalMachines ?? 0}',
                      icon: Icons.precision_manufacturing_rounded,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _HeroStat({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(.16)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: 2),
                Text(label, style: TextStyle(color: Colors.white.withOpacity(.85), fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color accent;

  const _MetricTile({required this.label, required this.value, required this.icon, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withOpacity(.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withOpacity(.18)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: accent.withOpacity(.16), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, size: 18, color: accent),
          ),
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

class _MiniInsightCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MiniInsightCard({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(.40),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.green.shade700),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
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

class _ScopeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ScopeChip({required this.label, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      avatar: Icon(icon, size: 18, color: selected ? Colors.white : Colors.black54),
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}

class _DepartmentOption {
  final int id;
  final String name;

  const _DepartmentOption({required this.id, required this.name});
}

class _DepartmentAggregate {
  final int id;
  final String name;
  final double powerKw;
  final double todayEnergyKwh;
  final int machineCount;

  const _DepartmentAggregate({
    required this.id,
    required this.name,
    this.powerKw = 0,
    this.todayEnergyKwh = 0,
    this.machineCount = 0,
  });

  _DepartmentAggregate copyWith({double? powerKw, double? todayEnergyKwh, int? machineCount}) {
    return _DepartmentAggregate(
      id: id,
      name: name,
      powerKw: powerKw ?? this.powerKw,
      todayEnergyKwh: todayEnergyKwh ?? this.todayEnergyKwh,
      machineCount: machineCount ?? this.machineCount,
    );
  }
}



import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:convert';

import '../../core/models/energia.dart';
import '../../core/providers/app_providers.dart';
import '../../core/utils/file_download.dart';
import '../../widgets/app_card.dart';
import '../../widgets/energy_line_chart.dart';
import '../../widgets/modern_date_picker.dart';
import '../../widgets/top_app_bar.dart';

class EnergiaScreen extends ConsumerStatefulWidget {
  const EnergiaScreen({super.key});

  @override
  ConsumerState<EnergiaScreen> createState() => _EnergiaScreenState();
}

class _EnergiaScreenState extends ConsumerState<EnergiaScreen> with WidgetsBindingObserver {
  bool _loading = true;
  bool _historyLoading = false;
  bool _historyExporting = false;
  String? _error;
  int _selectedDays = 7;
  EnergyScope _scope = EnergyScope.total;
  int? _selectedDzialId;
  int? _selectedMaszynaId;
  int? _machineFilterDzialId;
  String _machineSearchQuery = '';
  EnergyOverview? _catalogOverview;
  EnergyOverview? _overview;
  List<EnergyHistoryPoint> _history = const [];
  StreamSubscription<EnergyOverview>? _sseSubscription;
  Timer? _sseReconnectTimer;
  int _sseRetrySeconds = 2;
  Timer? _autoRefreshTimer;
  Timer? _historyAutoRefreshTimer;
  final TextEditingController _machineSearchController = TextEditingController();
  EnergyAnalysisRule _analysisRule = EnergyAnalysisRule.average;
  DateTimeRange? _analysisDateRange;
  DateTimeRange? _historyDateRange;
  HistoryZoomPreset _historyZoomPreset = HistoryZoomPreset.all;
  bool _analysisLoading = false;
  List<EnergyHistoryPoint> _analysisHistory = const [];
  DateTime? _pinnedHistoryTimestamp;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startAutoRefresh();
    _startHistoryAutoRefresh();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reloadAll());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sseSubscription?.cancel();
    _sseReconnectTimer?.cancel();
    _autoRefreshTimer?.cancel();
    _historyAutoRefreshTimer?.cancel();
    _machineSearchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _reloadCurrentView();
    }
  }

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) {
        _refreshLiveDataSilently();
      },
    );
  }

  void _startHistoryAutoRefresh() {
    _historyAutoRefreshTimer?.cancel();
    _historyAutoRefreshTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) {
        _reloadHistorySilently();
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
          },
          onError: (e) {
            if (!mounted) return;
            _scheduleSseReconnect();
          },
          onDone: () {
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
        bucketMinutes: 5,
        dzialId: _scope == EnergyScope.dzial ? _selectedDzialId : null,
        maszynaId: _scope == EnergyScope.maszyna ? _selectedMaszynaId : null,
        from: _historyDateRange?.start,
        to: _historyDateRange?.end,
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

  Future<void> _reloadAnalysis({bool silent = false}) async {
    if (!mounted || _analysisDateRange == null) return;
    final overview = _overview;
    if (overview == null) return;
    if (_scope == EnergyScope.dzial && _selectedDzialId == null) return;
    if (_scope == EnergyScope.maszyna && _selectedMaszynaId == null) return;

    if (!silent) {
      setState(() => _analysisLoading = true);
    }

    try {
      final repo = ref.read(energiaApiRepositoryProvider);
      final points = await repo.fetchHistory(
        scope: _scope,
        days: _selectedDays,
        bucketMinutes: 5,
        dzialId: _scope == EnergyScope.dzial ? _selectedDzialId : null,
        maszynaId: _scope == EnergyScope.maszyna ? _selectedMaszynaId : null,
        from: _analysisDateRange!.start,
        to: _analysisDateRange!.end,
      );
      if (!mounted) return;
      setState(() {
        _analysisHistory = points;
        _error = null;
      });
    } catch (_) {
      // Leave the previous analysis on screen if refresh fails.
    } finally {
      if (mounted && !silent) setState(() => _analysisLoading = false);
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
            bucketMinutes: 5,
            generatedAt: DateTime.now(),
            totalPowerKw: 0,
            todayEnergyKwh: 0,
            peakPower1hKw: 0,
            peakPower8hKw: 0,
            peakPower24hKw: 0,
            peakPower3dKw: 0,
            peakPower7dKw: 0,
            peakPower30dKw: 0,
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
      await _reloadAnalysis(silent: true);
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
            bucketMinutes: 5,
            generatedAt: DateTime.now(),
            totalPowerKw: 0,
            todayEnergyKwh: 0,
            peakPower1hKw: 0,
            peakPower8hKw: 0,
            peakPower24hKw: 0,
            peakPower3dKw: 0,
            peakPower7dKw: 0,
            peakPower30dKw: 0,
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
      await _reloadAnalysis(silent: true);
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
        bucketMinutes: 5,
        dzialId: _scope == EnergyScope.dzial ? _selectedDzialId : null,
        maszynaId: _scope == EnergyScope.maszyna ? _selectedMaszynaId : null,
        from: _historyDateRange?.start,
        to: _historyDateRange?.end,
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

  Future<void> _pickAnalysisDateRange() async {
    final history = _history.isNotEmpty ? _history : _analysisHistory;
    final now = DateTime.now();
    final fallbackStart = now.subtract(const Duration(days: 1));
    final firstAvailable = history.isNotEmpty
        ? history.map((p) => p.recordedAt.toLocal()).reduce((a, b) => a.isBefore(b) ? a : b)
        : fallbackStart;
    final lastAvailable = history.isNotEmpty
        ? history.map((p) => p.recordedAt.toLocal()).reduce((a, b) => a.isAfter(b) ? a : b)
        : now;
    final safeInitialStart = lastAvailable.subtract(const Duration(days: 1)).isBefore(firstAvailable)
        ? firstAvailable
        : lastAvailable.subtract(const Duration(days: 1));

    final picked = await _pickDateTimeRangeDialog(
      title: 'Zakres analizy (data i godzina)',
      initial: _analysisDateRange ?? DateTimeRange(start: safeInitialStart, end: lastAvailable),
      min: firstAvailable,
      max: lastAvailable,
      applyLabel: 'Analizuj',
    );
    if (picked == null) return;

    setState(() {
      _analysisDateRange = picked;
      _analysisHistory = const [];
    });
    await _reloadAnalysis();
  }

  Future<void> _pickHistoryDateRange() async {
    final history = _history.isNotEmpty ? _history : _analysisHistory;
    final now = DateTime.now();
    final fallbackStart = now.subtract(Duration(days: _selectedDays));
    final firstAvailable = history.isNotEmpty
        ? history.map((p) => p.recordedAt.toLocal()).reduce((a, b) => a.isBefore(b) ? a : b)
        : fallbackStart;
    final lastAvailable = history.isNotEmpty
        ? history.map((p) => p.recordedAt.toLocal()).reduce((a, b) => a.isAfter(b) ? a : b)
        : now;
    final safeInitialStart = lastAvailable.subtract(const Duration(days: 1)).isBefore(firstAvailable)
        ? firstAvailable
        : lastAvailable.subtract(const Duration(days: 1));

    final picked = await _pickDateTimeRangeDialog(
      title: 'Okres wykresu (data i godzina)',
      initial: _historyDateRange ?? DateTimeRange(start: safeInitialStart, end: lastAvailable),
      min: firstAvailable,
      max: lastAvailable,
      applyLabel: 'Zastosuj',
    );
    if (picked == null) return;

    setState(() {
      _historyDateRange = picked;
      _pinnedHistoryTimestamp = null;
    });
    await _reloadHistory();
    await _reloadAnalysis(silent: true);
  }

  Future<DateTimeRange?> _pickDateTimeRangeDialog({
    required String title,
    required DateTimeRange initial,
    required DateTime min,
    required DateTime max,
    required String applyLabel,
  }) async {
    final normalizedMin = min.isBefore(max) ? min : max;
    final normalizedMax = max.isAfter(min) ? max : min;
    var start = initial.start.isBefore(normalizedMin) ? normalizedMin : initial.start;
    var end = initial.end.isAfter(normalizedMax) ? normalizedMax : initial.end;
    if (end.isBefore(start)) {
      end = start;
    }

    return showDialog<DateTimeRange>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        Future<void> pickStart(StateSetter setLocal) async {
          final picked = await showModernDatePicker(
            context: ctx,
            title: 'Poczatek',
            includeTime: true,
            initialDate: start,
            firstDate: normalizedMin,
            lastDate: end,
          );
          if (picked != null) {
            setLocal(() {
              start = picked;
              if (end.isBefore(start)) {
                end = start;
              }
            });
          }
        }

        Future<void> pickEnd(StateSetter setLocal) async {
          final picked = await showModernDatePicker(
            context: ctx,
            title: 'Koniec',
            includeTime: true,
            initialDate: end,
            firstDate: start,
            lastDate: normalizedMax,
          );
          if (picked != null) {
            setLocal(() => end = picked);
          }
        }

        return StatefulBuilder(
          builder: (ctx, setLocal) => AlertDialog(
            title: Text(title),
            content: SizedBox(
              width: 500,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.login_rounded),
                    title: const Text('Od'),
                    subtitle: Text(_formatDateTime(start)),
                    trailing: const Icon(Icons.edit_calendar_outlined),
                    onTap: () => pickStart(setLocal),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.logout_rounded),
                    title: const Text('Do'),
                    subtitle: Text(_formatDateTime(end)),
                    trailing: const Icon(Icons.edit_calendar_outlined),
                    onTap: () => pickEnd(setLocal),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ActionChip(
                        label: const Text('Ostatnie 15m'),
                        onPressed: () => setLocal(() {
                          end = normalizedMax;
                          start = end.subtract(const Duration(minutes: 15));
                          if (start.isBefore(normalizedMin)) start = normalizedMin;
                        }),
                      ),
                      ActionChip(
                        label: const Text('Ostatnia 1h'),
                        onPressed: () => setLocal(() {
                          end = normalizedMax;
                          start = end.subtract(const Duration(hours: 1));
                          if (start.isBefore(normalizedMin)) start = normalizedMin;
                        }),
                      ),
                      ActionChip(
                        label: const Text('Ostatnie 6h'),
                        onPressed: () => setLocal(() {
                          end = normalizedMax;
                          start = end.subtract(const Duration(hours: 6));
                          if (start.isBefore(normalizedMin)) start = normalizedMin;
                        }),
                      ),
                      ActionChip(
                        label: const Text('Ostatnie 24h'),
                        onPressed: () => setLocal(() {
                          end = normalizedMax;
                          start = end.subtract(const Duration(hours: 24));
                          if (start.isBefore(normalizedMin)) start = normalizedMin;
                        }),
                      ),
                      ActionChip(
                        label: const Text('Caly zakres'),
                        onPressed: () => setLocal(() {
                          start = normalizedMin;
                          end = normalizedMax;
                        }),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Anuluj')),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(DateTimeRange(start: start, end: end)),
                child: Text(applyLabel),
              ),
            ],
          ),
        );
      },
    );
  }

  EnergyHistoryPoint? _nearestHistoryPoint(DateTime timestamp, List<EnergyHistoryPoint> points) {
    if (points.isEmpty) return null;
    final target = timestamp.toLocal();
    EnergyHistoryPoint nearest = points.first;
    Duration nearestDelta = nearest.recordedAt.toLocal().difference(target).abs();
    for (final point in points.skip(1)) {
      final delta = point.recordedAt.toLocal().difference(target).abs();
      if (delta < nearestDelta) {
        nearest = point;
        nearestDelta = delta;
      }
    }
    return nearest;
  }

  Future<void> _pickHistoryPointDateTime() async {
    final source = _historyPointsForChart;
    if (source.isEmpty) return;
    final first = source.map((p) => p.recordedAt.toLocal()).reduce((a, b) => a.isBefore(b) ? a : b);
    final last = source.map((p) => p.recordedAt.toLocal()).reduce((a, b) => a.isAfter(b) ? a : b);
    final picked = await showModernDatePicker(
      context: context,
      title: 'Skocz do punktu na wykresie',
      includeTime: true,
      initialDate: _pinnedHistoryTimestamp?.toLocal() ?? last,
      firstDate: first,
      lastDate: last,
      allowQuickActions: false,
    );
    if (picked == null) return;
    final nearest = _nearestHistoryPoint(picked, source);
    if (nearest == null) return;
    setState(() => _pinnedHistoryTimestamp = nearest.recordedAt);
  }

  Future<void> _clearAnalysisDateRange() async {
    setState(() {
      _analysisDateRange = null;
      _analysisHistory = const [];
    });
  }

  Future<void> _clearHistoryDateRange() async {
    setState(() {
      _historyDateRange = null;
      _pinnedHistoryTimestamp = null;
    });
    await _reloadHistory();
    await _reloadAnalysis(silent: true);
  }

  Future<void> _exportHistoryCsv() async {
    if (_historyExporting || _historyLoading) return;
    if (_scope == EnergyScope.dzial && _selectedDzialId == null) return;
    if (_scope == EnergyScope.maszyna && _selectedMaszynaId == null) return;

    setState(() => _historyExporting = true);
    try {
      final repo = ref.read(energiaApiRepositoryProvider);
      final csv = await repo.fetchHistoryCsv(
        scope: _scope,
        days: _selectedDays,
        bucketMinutes: 5,
        dzialId: _scope == EnergyScope.dzial ? _selectedDzialId : null,
        maszynaId: _scope == EnergyScope.maszyna ? _selectedMaszynaId : null,
      );
      if (!mounted) return;

      final scopeSuffix = _scope.apiValue.toLowerCase();
      final fileName = 'energia-historia-$scopeSuffix-${_selectedDays}d.csv';
      final downloaded = downloadBytesAsFile(
        fileName: fileName,
        mimeType: 'text/csv;charset=utf-8',
        bytes: utf8.encode(csv),
      );

      if (!downloaded) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pobieranie pliku CSV jest wspierane w wersji web aplikacji.'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nie udało się wyeksportować historii: $e')),
      );
    } finally {
      if (mounted) setState(() => _historyExporting = false);
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

  void _filterMachinesByDepartment(int? dzialId) {
    setState(() {
      _machineFilterDzialId = dzialId;
      _dropSelectedMachineIfFilteredOut();
    });
  }

  void _filterMachinesByQuery(String query) {
    setState(() {
      _machineSearchQuery = query.trim();
      _dropSelectedMachineIfFilteredOut();
    });
  }

  void _setHistoryZoom(HistoryZoomPreset preset) {
    if (_historyZoomPreset == preset) return;
    setState(() {
      _historyZoomPreset = preset;
      _pinnedHistoryTimestamp = null;
    });
  }

  void _dropSelectedMachineIfFilteredOut() {
    final selectedId = _selectedMaszynaId;
    if (selectedId == null) {
      return;
    }
    final stillVisible = _availableMachines.any((machine) => machine.maszynaId == selectedId);
    if (stillVisible) {
      return;
    }

    _selectedMaszynaId = null;
    if (_scope == EnergyScope.maszyna) {
      _overview = EnergyOverview(
        scopeType: _scope.apiValue,
        scopeLabel: _scope.label,
        zakresDni: _selectedDays,
        bucketMinutes: 5,
        generatedAt: DateTime.now(),
        totalPowerKw: 0,
        todayEnergyKwh: 0,
        peakPower1hKw: 0,
        peakPower8hKw: 0,
        peakPower24hKw: 0,
        peakPower3dKw: 0,
        peakPower7dKw: 0,
        peakPower30dKw: 0,
        activeMachines: 0,
        totalMachines: 0,
        machines: const [],
      );
      _history = const [];
    }
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

  List<EnergyMachineSummary> get _availableMachines {
    final catalog = _catalogOverview;
    if (catalog == null) return const [];

    final query = _machineSearchQuery.trim().toLowerCase();
    final machines = catalog.machines.where((machine) {
      if (_machineFilterDzialId != null && machine.dzialId != _machineFilterDzialId) {
        return false;
      }
      if (query.isEmpty) {
        return true;
      }
      final name = machine.maszynaNazwa.trim().toLowerCase();
      return name.startsWith(query) || name.contains(query);
    }).toList();

    machines.sort((a, b) => a.maszynaNazwa.toLowerCase().compareTo(b.maszynaNazwa.toLowerCase()));
    return machines;
  }

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

  List<EnergyHistoryPoint> get _historyPointsForChart {
    if (_history.isEmpty) return const [];
    final sorted = [..._history]..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    final window = _historyZoomPreset.window;
    if (window == null) return sorted;
    final end = sorted.last.recordedAt;
    final start = end.subtract(window);
    return sorted.where((p) => !p.recordedAt.isBefore(start)).toList();
  }

  double _avgPower(List<EnergyHistoryPoint> points) {
    if (points.isEmpty) return 0;
    final total = points.fold<double>(0, (sum, point) => sum + point.powerKw);
    return total / points.length;
  }

  EnergyHistoryPoint? _peakPoint(List<EnergyHistoryPoint> points) {
    if (points.isEmpty) return null;
    return points.reduce((a, b) => a.powerKw >= b.powerKw ? a : b);
  }

  double _energySum(List<EnergyHistoryPoint> points) {
    final sorted = [...points]..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    final totals = sorted.map((point) => point.energyKwhTotal).whereType<double>().toList();
    if (totals.length < 2) return 0;
    return (totals.last - totals.first).clamp(0, double.infinity);
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

  List<EnergyHistoryPoint> get _analysisPoints {
    final source = _analysisDateRange == null ? _history : _analysisHistory;
    final sorted = [...source]..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    if (sorted.isEmpty) return const [];
    return sorted;
  }

  double get _analysisValue {
    final points = _analysisPoints;
    if (points.isEmpty) return 0;
    final values = points.map((p) => p.powerKw).toList();
    return switch (_analysisRule) {
      EnergyAnalysisRule.average => values.reduce((a, b) => a + b) / values.length,
      EnergyAnalysisRule.max => values.reduce((a, b) => a > b ? a : b),
      EnergyAnalysisRule.min => values.reduce((a, b) => a < b ? a : b),
      EnergyAnalysisRule.loadFactor => _loadFactor(points),
      EnergyAnalysisRule.peakSpread => _peakSpread(points),
    };
  }

  double get _analysisAverage => _analysisPoints.isEmpty
      ? 0
      : _analysisPoints.map((p) => p.powerKw).reduce((a, b) => a + b) / _analysisPoints.length;

  double get _analysisRangeDurationHours {
    final points = _analysisPoints;
    if (points.length < 2) return 0;
    return points.last.recordedAt.difference(points.first.recordedAt).inMinutes / 60.0;
  }

  List<EnergyHistoryPoint> get _analysisPreviousRangePoints {
    final points = _analysisPoints;
    if (_analysisDateRange == null || points.length < 2) return const [];
    final duration = points.last.recordedAt.difference(points.first.recordedAt);
    if (duration.inMinutes <= 0) return const [];
    final currentStart = points.first.recordedAt;
    final previousEnd = currentStart;
    final previousStart = currentStart.subtract(duration);
    return points.where((p) => !p.recordedAt.isBefore(previousStart) && p.recordedAt.isBefore(previousEnd)).toList();
  }

  String get _analysisRangeLabel {
    final range = _analysisDateRange;
    if (range == null) return 'Brak wybranego zakresu — analiza używa aktualnie załadowanej historii.';
    final start = _formatDateTime(range.start);
    final end = _formatDateTime(range.end);
    return 'Zakres analizy: $start → $end';
  }

  String get _historyRangeLabel {
    final range = _historyDateRange;
    if (range == null) return 'Okres wykresu: wg szybkiego zakresu (1/7/30 dni).';
    return 'Okres wykresu: ${_formatDateTime(range.start)} → ${_formatDateTime(range.end)}';
  }

  String get _pinnedPointLabel {
    final ts = _pinnedHistoryTimestamp;
    if (ts == null) return 'Brak przypietego punktu.';
    return 'Wybrany punkt: ${_formatDateTime(ts.toLocal())}';
  }

  double get _analysisPreviousAverage {
    final prev = _analysisPreviousRangePoints;
    if (prev.isEmpty) return 0;
    return prev.map((p) => p.powerKw).reduce((a, b) => a + b) / prev.length;
  }

  double get _analysisDeltaPercent {
    final prev = _analysisPreviousAverage;
    if (prev <= 0) return 0;
    return ((_analysisAverage - prev) / prev) * 100;
  }

  EnergyHistoryPoint? get _analysisPeakPoint {
    if (_analysisPoints.isEmpty) return null;
    return _analysisPoints.reduce((a, b) => a.powerKw >= b.powerKw ? a : b);
  }

  String get _analysisPeakLabel {
    final peak = _analysisPeakPoint;
    if (peak == null) return '-';
    return '${DateFormat('HH:mm').format(peak.recordedAt.toLocal())} • ${peak.powerKw.toStringAsFixed(1)} kW';
  }

  double get _analysisStabilityScore {
    final points = _analysisPoints;
    if (points.length < 2) return 100;
    final avg = _analysisAverage;
    if (avg <= 0) return 100;
    final variance = points
            .map((p) => p.powerKw)
            .map((value) => (value - avg) * (value - avg))
            .reduce((a, b) => a + b) /
        points.length;
    final stdDev = math.sqrt(variance);
    final score = (100 - ((stdDev / avg) * 100)).clamp(0.0, 100.0);
    return score;
  }

  double get _forecastNextHourKw {
    final points = _analysisPoints;
    if (points.isEmpty) return 0;
    if (points.length == 1) return points.last.powerKw;
    final first = points.first;
    final last = points.last;
    final hours = last.recordedAt.difference(first.recordedAt).inMinutes / 60.0;
    if (hours <= 0) return last.powerKw;
    final slopePerHour = (last.powerKw - first.powerKw) / hours;
    return (last.powerKw + slopePerHour).clamp(0.0, double.infinity);
  }

  String get _analysisVerdict {
    final score = _analysisStabilityScore;
    final value = _analysisValue;
    final avg = _analysisAverage;
    if (_analysisRule == EnergyAnalysisRule.max) return 'Szukasz pików — to najlepsza reguła do wykrywania skoków.';
    if (_analysisRule == EnergyAnalysisRule.min) return 'To pokazuje bazowe obciążenie w wybranym oknie.';
    if (_analysisRule == EnergyAnalysisRule.loadFactor) return 'Im bliżej 100%, tym bardziej równomierna praca maszyny.';
    if (_analysisRule == EnergyAnalysisRule.peakSpread) return 'Im mniejszy rozrzut, tym spokojniejsza i bardziej przewidywalna praca.';
    if (_analysisRule == EnergyAnalysisRule.average) return 'Średnia moc pomaga ocenić typowe obciążenie w badanym oknie.';
    if (score >= 85) return 'Praca wygląda stabilnie, bez dużych wahań.';
    if (value > avg * 1.15) return 'Aktualny poziom jest wyraźnie powyżej średniej — warto obserwować.';
    return 'Widać umiarkowane wahania poboru energii.';
  }

  double _loadFactor(List<EnergyHistoryPoint> points) {
    final values = points.map((p) => p.powerKw).toList();
    final avg = values.reduce((a, b) => a + b) / values.length;
    final max = values.reduce((a, b) => a > b ? a : b);
    if (max <= 0) return 0;
    return ((avg / max) * 100).clamp(0.0, 100.0);
  }

  double _peakSpread(List<EnergyHistoryPoint> points) {
    final values = points.map((p) => p.powerKw).toList();
    final max = values.reduce((a, b) => a > b ? a : b);
    final min = values.reduce((a, b) => a < b ? a : b);
    return (max - min).clamp(0.0, double.infinity);
  }

  String _formatDateTime(DateTime value) => DateFormat('yyyy-MM-dd HH:mm').format(value.toLocal());

  @override
  Widget build(BuildContext context) {
    final overview = _overview;
    final selectedMachine = _selectedMachine;
    final selectedDepartment = _selectedDepartment;
    final isEmpty = overview == null || overview.machines.isEmpty;
    final selectedScopeLabel = overview?.scopeLabel ?? _scope.label;
    final chartPoints = _historyPointsForChart;
    final chartAveragePower = _avgPower(chartPoints);
    final chartPeakPoint = _peakPoint(chartPoints);
    final chartEnergySum = _energySum(chartPoints);

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
                      DropdownButtonFormField<int?>(
                        value: _machineFilterDzialId,
                        decoration: const InputDecoration(
                          labelText: 'Filtruj po dziale',
                          border: OutlineInputBorder(),
                        ),
                        isExpanded: true,
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('Wszystkie działy'),
                          ),
                          ..._availableDepartments.map(
                            (d) => DropdownMenuItem<int?>(value: d.id, child: Text(d.name)),
                          ),
                        ],
                        onChanged: _filterMachinesByDepartment,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _machineSearchController,
                        decoration: InputDecoration(
                          labelText: 'Szukaj maszyny',
                          hintText: 'Wpisz nazwę lub pierwsze litery',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _machineSearchQuery.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Wyczyść',
                                  onPressed: () {
                                    _machineSearchController.clear();
                                    _filterMachinesByQuery('');
                                  },
                                  icon: const Icon(Icons.close),
                                ),
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: _filterMachinesByQuery,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        value: _selectedMaszynaId,
                        decoration: InputDecoration(
                          labelText: 'Wybierz maszynę',
                          helperText: _availableMachines.isEmpty
                              ? 'Brak maszyn dla wybranego działu lub frazy.'
                              : 'Znaleziono ${_availableMachines.length} maszyn.',
                          border: const OutlineInputBorder(),
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
                      const SizedBox(height: 4),
                      const Text(
                        'Moc chwilowa i lista maszyn odświeżają się live co kilka sekund. Historia zapisuje snapshoty co 5 minut.',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
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
                title: 'Skoki zużycia (max chwilowy)',
                divided: true,
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _MiniInsightCard(
                      label: '1 godzina',
                      value: '${overview?.peakPower1hKw.toStringAsFixed(1) ?? '0.0'} kW',
                      icon: Icons.speed_outlined,
                    ),
                    _MiniInsightCard(
                      label: '8 godzin',
                      value: '${overview?.peakPower8hKw.toStringAsFixed(1) ?? '0.0'} kW',
                      icon: Icons.timeline_outlined,
                    ),
                    _MiniInsightCard(
                      label: '24 godziny',
                      value: '${overview?.peakPower24hKw.toStringAsFixed(1) ?? '0.0'} kW',
                      icon: Icons.today_outlined,
                    ),
                    _MiniInsightCard(
                      label: '3 dni',
                      value: '${overview?.peakPower3dKw.toStringAsFixed(1) ?? '0.0'} kW',
                      icon: Icons.view_week_outlined,
                    ),
                    _MiniInsightCard(
                      label: '7 dni',
                      value: '${overview?.peakPower7dKw.toStringAsFixed(1) ?? '0.0'} kW',
                      icon: Icons.date_range_outlined,
                    ),
                    _MiniInsightCard(
                      label: '30 dni',
                      value: '${overview?.peakPower30dKw.toStringAsFixed(1) ?? '0.0'} kW',
                      icon: Icons.calendar_month_outlined,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AppCard(
                title: 'Analiza operatora',
                divided: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: 260,
                          child: DropdownButtonFormField<EnergyAnalysisRule>(
                            value: _analysisRule,
                            decoration: const InputDecoration(
                              labelText: 'Reguła',
                              border: OutlineInputBorder(),
                            ),
                            isExpanded: true,
                            items: EnergyAnalysisRule.values
                                .map((rule) => DropdownMenuItem(value: rule, child: Text(rule.label)))
                                .toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() => _analysisRule = value);
                            },
                          ),
                        ),
                        SizedBox(
                          width: 360,
                          child: OutlinedButton.icon(
                            onPressed: _analysisLoading ? null : _pickAnalysisDateRange,
                            icon: const Icon(Icons.schedule_outlined),
                            label: Text(_analysisDateRange == null ? 'Wybierz zakres dat i godzin od-do' : _analysisRangeLabel),
                          ),
                        ),
                        if (_analysisDateRange != null)
                          TextButton.icon(
                            onPressed: _analysisLoading ? null : _clearAnalysisDateRange,
                            icon: const Icon(Icons.close),
                            label: const Text('Wyczyść zakres'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _analysisRangeLabel,
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    const SizedBox(height: 10),
                    if (_analysisLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: LinearProgressIndicator(minHeight: 3),
                      )
                    else if (_analysisPoints.isEmpty)
                      const Text('Brak danych do analizy w wybranym oknie.')
                    else ...[
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _MiniInsightCard(
                            label: '${_analysisRule.label} • ${_analysisDateRange == null ? 'aktualna historia' : 'wybrany zakres'}',
                            value: '${_analysisValue.toStringAsFixed(1)} ${_analysisRule.unit}',
                            icon: _analysisRule.icon,
                          ),
                          _MiniInsightCard(
                            label: 'EnergoPulse',
                            value: '${_analysisStabilityScore.toStringAsFixed(0)}% stabilności',
                            icon: Icons.shield_outlined,
                          ),
                          _MiniInsightCard(
                            label: 'Prognoza 60 min',
                            value: '${_forecastNextHourKw.toStringAsFixed(1)} kW',
                            icon: Icons.auto_graph_outlined,
                          ),
                          _MiniInsightCard(
                            label: 'Najmocniejszy punkt',
                            value: _analysisPeakLabel,
                            icon: Icons.event_available_outlined,
                          ),
                          _MiniInsightCard(
                            label: 'Zmiana vs poprzedni okres',
                            value: _analysisPreviousAverage <= 0
                                ? 'Brak danych porównawczych'
                                : '${_analysisDeltaPercent >= 0 ? '+' : ''}${_analysisDeltaPercent.toStringAsFixed(1)}%',
                            icon: Icons.compare_arrows_outlined,
                          ),
                          _MiniInsightCard(
                            label: 'Werdykt',
                            value: _analysisRule == EnergyAnalysisRule.loadFactor
                                ? '${_analysisValue.toStringAsFixed(0)}%'
                                : _analysisVerdict,
                            icon: Icons.lightbulb_outline,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _analysisVerdict,
                        style: const TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AppCard(
                title: 'Historia 5-minutowa',
                divided: true,
                action: OutlinedButton.icon(
                  onPressed: _history.isEmpty || _historyExporting ? null : _exportHistoryCsv,
                  icon: _historyExporting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.table_view_outlined),
                  label: Text(_historyExporting ? 'Eksport...' : 'Eksport do Excel (CSV)'),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _historyLoading ? null : _pickHistoryDateRange,
                          icon: const Icon(Icons.date_range_outlined),
                          label: Text(_historyDateRange == null ? 'Wybierz okres wykresu (data + godzina)' : 'Edytuj okres wykresu'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _historyLoading || _history.isEmpty ? null : _pickHistoryPointDateTime,
                          icon: const Icon(Icons.pin_drop_outlined),
                          label: const Text('Wybierz konkretna date na wykresie'),
                        ),
                        if (_historyDateRange != null)
                          TextButton.icon(
                            onPressed: _historyLoading ? null : _clearHistoryDateRange,
                            icon: const Icon(Icons.close),
                            label: const Text('Wyczysc okres wykresu'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: HistoryZoomPreset.values
                            .map(
                              (preset) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(preset.label),
                                  selected: _historyZoomPreset == preset,
                                  onSelected: (_) => _setHistoryZoom(preset),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(_historyRangeLabel, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                    const SizedBox(height: 4),
                    Text(
                      '${_pinnedPointLabel}  Przeciagnij po wykresie, aby plynnie wskazywac punkty.',
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    const SizedBox(height: 12),
                    if (_historyLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (chartPoints.isEmpty)
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
                        points: chartPoints,
                        accentColor: Colors.green.shade600,
                        pinnedTimestamp: _pinnedHistoryTimestamp,
                        onPointSelected: (point) => setState(() => _pinnedHistoryTimestamp = point.recordedAt),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _MiniInsightCard(
                            label: 'Średnia moc',
                            value: '${chartAveragePower.toStringAsFixed(1)} kW',
                            icon: Icons.auto_graph_outlined,
                          ),
                          _MiniInsightCard(
                            label: 'Szczyt',
                            value: '${chartPeakPoint?.powerKw.toStringAsFixed(1) ?? '0.0'} kW',
                            icon: Icons.trending_up_outlined,
                          ),
                          _MiniInsightCard(
                            label: 'Suma energii',
                            value: '${chartEnergySum.toStringAsFixed(1)} kWh',
                            icon: Icons.battery_charging_full_outlined,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Ostatnie snapshoty 5-minutowe',
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

enum EnergyAnalysisRule {
  average,
  max,
  min,
  loadFactor,
  peakSpread;

  String get label => switch (this) {
        EnergyAnalysisRule.average => 'Średnia moc',
        EnergyAnalysisRule.max => 'Maksimum',
        EnergyAnalysisRule.min => 'Minimum',
        EnergyAnalysisRule.loadFactor => 'Współczynnik obciążenia',
        EnergyAnalysisRule.peakSpread => 'Rozrzut pików',
      };

  String get unit => switch (this) {
        EnergyAnalysisRule.loadFactor => '%',
        EnergyAnalysisRule.peakSpread => 'kW',
        _ => 'kW',
      };

  IconData get icon => switch (this) {
        EnergyAnalysisRule.average => Icons.analytics_outlined,
        EnergyAnalysisRule.max => Icons.trending_up_outlined,
        EnergyAnalysisRule.min => Icons.trending_down_outlined,
        EnergyAnalysisRule.loadFactor => Icons.balance_outlined,
        EnergyAnalysisRule.peakSpread => Icons.waterfall_chart_outlined,
      };
}

enum HistoryZoomPreset {
  m15,
  h1,
  h6,
  h24,
  all;

  String get label => switch (this) {
        HistoryZoomPreset.m15 => '15m',
        HistoryZoomPreset.h1 => '1h',
        HistoryZoomPreset.h6 => '6h',
        HistoryZoomPreset.h24 => '24h',
        HistoryZoomPreset.all => 'Calosc',
      };

  Duration? get window => switch (this) {
        HistoryZoomPreset.m15 => const Duration(minutes: 15),
        HistoryZoomPreset.h1 => const Duration(hours: 1),
        HistoryZoomPreset.h6 => const Duration(hours: 6),
        HistoryZoomPreset.h24 => const Duration(hours: 24),
        HistoryZoomPreset.all => null,
      };
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



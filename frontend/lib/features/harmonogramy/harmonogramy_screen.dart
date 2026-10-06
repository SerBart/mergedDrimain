import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/dzial.dart';
import '../../core/models/harmonogram.dart';
import '../../core/models/maszyna.dart';
import '../../core/models/osoba.dart';
import '../../core/providers/app_providers.dart';
import '../../widgets/centered_scroll_card.dart';
import '../../widgets/modern_date_picker.dart';
import '../../widgets/pagination_controls.dart';
import '../../widgets/top_app_bar.dart';

class HarmonogramyScreen extends ConsumerStatefulWidget {
  const HarmonogramyScreen({super.key, this.title = 'Harmonogramy'});

  final String title;

  @override
  ConsumerState<HarmonogramyScreen> createState() => _HarmonogramyScreenState();
}

class _HarmonogramyScreenState extends ConsumerState<HarmonogramyScreen> {
  bool _loading = true;
  List<Harmonogram> _items = [];
  List<Maszyna> _maszyny = [];
  List<Osoba> _osoby = [];
  List<Dzial> _dzialy = [];

  int? _year = DateTime.now().year;
  int? _month;
  String _statusFilter = 'WSZYSTKIE';
  String _query = '';
  final TextEditingController _searchCtrl = TextEditingController();

  int _sortCol = 0;
  bool _asc = true;

  int _page = 0;
  int _pageSize = 25;
  static const List<int> _pageSizes = [10, 25, 50, 100];

  bool _multiSelectMode = false;
  final Set<int> _selectedIds = <int>{};

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final harmonogramyApi = ref.read(harmonogramyApiRepositoryProvider);
      final metaApi = ref.read(metaApiRepositoryProvider);
      final results = await Future.wait([
        harmonogramyApi.fetchAll(year: _year, month: _month),
        metaApi.fetchMaszynySimple(),
        metaApi.fetchOsobySimple(),
        metaApi.fetchDzialySimple(),
      ]);

      _items = results[0] as List<Harmonogram>;
      _maszyny = results[1] as List<Maszyna>;
      _osoby = results[2] as List<Osoba>;
      _dzialy = results[3] as List<Dzial>;

      final existingIds = _items.map((h) => h.id).toSet();
      _selectedIds.removeWhere((id) => !existingIds.contains(id));
      if (_selectedIds.isEmpty) _multiSelectMode = false;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd ładowania: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Harmonogram> _applyFilters() {
    Iterable<Harmonogram> list = _items;
    if (_statusFilter != 'WSZYSTKIE') {
      list = list.where((h) => h.status.toUpperCase() == _statusFilter);
    }
    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((h) {
        final machineName = h.maszyna?.nazwa.toLowerCase() ?? '';
        final machineDept = h.maszyna?.dzial?.nazwa.toLowerCase() ?? '';
        final directDept = h.dzial?.nazwa.toLowerCase() ?? '';
        final section = h.maszyna?.sekcja?.nazwa.toLowerCase() ?? '';
        final person = h.osoba?.imieNazwisko.toLowerCase() ?? '';
        return h.opis.toLowerCase().contains(q) ||
            machineName.contains(q) ||
            machineDept.contains(q) ||
            directDept.contains(q) ||
            section.contains(q) ||
            person.contains(q);
      });
    }
    return list.toList();
  }

  List<Harmonogram> _sorted(List<Harmonogram> list) {
    list.sort((a, b) {
      int cmp;
      switch (_sortCol) {
        case 0:
          cmp = (a.data ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(
            b.data ?? DateTime.fromMillisecondsSinceEpoch(0),
          );
          break;
        case 1:
          cmp = (a.maszyna?.nazwa ?? '').compareTo(b.maszyna?.nazwa ?? '');
          break;
        case 2:
          cmp = (a.maszyna?.dzial?.nazwa ?? a.dzial?.nazwa ?? '').compareTo(b.maszyna?.dzial?.nazwa ?? b.dzial?.nazwa ?? '');
          break;
        case 3:
          cmp = (a.maszyna?.sekcja?.nazwa ?? '').compareTo(b.maszyna?.sekcja?.nazwa ?? '');
          break;
        case 4:
          cmp = (a.osoba?.imieNazwisko ?? '').compareTo(b.osoba?.imieNazwisko ?? '');
          break;
        case 5:
          cmp = (a.durationMinutes ?? 0).compareTo(b.durationMinutes ?? 0);
          break;
        case 6:
          cmp = a.status.compareTo(b.status);
          break;
        default:
          cmp = a.opis.compareTo(b.opis);
      }
      return _asc ? cmp : -cmp;
    });
    return list;
  }

  List<Harmonogram> _pageSlice(List<Harmonogram> all) {
    final start = _page * _pageSize;
    final end = (start + _pageSize) > all.length ? all.length : (start + _pageSize);
    if (start >= all.length) return const <Harmonogram>[];
    return all.sublist(start, end);
  }

  Future<void> _addNew() async {
    final created = await _openFormDialog();
    if (created == true) await _loadAll();
  }

  Future<void> _editItem(Harmonogram h) async {
    final saved = await _openFormDialog(
      initialDate: h.data,
      initialMaszynaId: h.maszyna?.id,
      initialOsobaId: h.osoba?.id,
      initialDuration: h.durationMinutes,
      initialOpis: h.opis.isEmpty ? null : h.opis,
      initialDzialId: h.dzial?.id ?? h.maszyna?.dzial?.id,
      onSubmit: (data, maszynaId, osobaId, duration, opis, dzialId) async {
        final api = ref.read(harmonogramyApiRepositoryProvider);
        await api.update(
          id: h.id,
          data: data,
          maszynaId: maszynaId,
          osobaId: osobaId,
          dzialId: dzialId,
          durationMinutes: duration,
          opis: (opis ?? '').trim(),
        );
      },
      title: 'Edytuj harmonogram',
    );
    if (saved == true) await _loadAll();
  }

  Future<void> _deleteItem(Harmonogram h) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Usuń harmonogram'),
        content: Text('Usunąć wpis z dnia ${_fmtDate(h.data)}?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Anuluj')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Usuń')),
        ],
      ),
    );
    if (ok == true) {
      try {
        await ref.read(harmonogramyApiRepositoryProvider).delete(h.id);
        await _loadAll();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Błąd usuwania: $e')));
      }
    }
  }

  Future<void> _quickToggleStatus(Harmonogram h) async {
    final current = h.status.toUpperCase();
    final next = switch (current) {
      'PLANOWANE' => 'W_TRAKCIE',
      'W_TRAKCIE' => 'ZAKONCZONE',
      _ => 'PLANOWANE',
    };
    try {
      await ref.read(harmonogramyApiRepositoryProvider).update(id: h.id, status: next);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Zmieniono status na ${_statusLabel(next)}')));
      }
      await _loadAll();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Błąd zmiany statusu: $e')));
    }
  }

  void _toggleMultiSelectMode() {
    setState(() {
      _multiSelectMode = !_multiSelectMode;
      if (!_multiSelectMode) _selectedIds.clear();
    });
  }

  void _toggleItemSelection(Harmonogram h, bool selected) {
    setState(() {
      if (selected) {
        _selectedIds.add(h.id);
      } else {
        _selectedIds.remove(h.id);
      }
      _multiSelectMode = _selectedIds.isNotEmpty;
    });
  }

  void _toggleSelectVisible(List<Harmonogram> visible) {
    final visibleIds = visible.map((h) => h.id).toSet();
    final allVisibleSelected = visibleIds.isNotEmpty && visibleIds.every(_selectedIds.contains);
    setState(() {
      if (allVisibleSelected) {
        _selectedIds.removeWhere(visibleIds.contains);
      } else {
        _selectedIds.addAll(visibleIds);
      }
      _multiSelectMode = _selectedIds.isNotEmpty;
    });
  }

  void _toggleSelectFiltered(List<Harmonogram> filtered) {
    final filteredIds = filtered.map((h) => h.id).toSet();
    final allFilteredSelected = filteredIds.isNotEmpty && filteredIds.every(_selectedIds.contains);
    setState(() {
      if (allFilteredSelected) {
        _selectedIds.removeWhere(filteredIds.contains);
      } else {
        _selectedIds.addAll(filteredIds);
      }
      _multiSelectMode = _selectedIds.isNotEmpty;
    });
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;
    final count = _selectedIds.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Usuń zaznaczone harmonogramy'),
        content: Text('Usunąć $count zaznaczon${count == 1 ? 'y wpis' : 'e wpisy'}?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Anuluj')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Usuń')),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _loading = true);
    int deleted = 0;
    int failed = 0;
    final api = ref.read(harmonogramyApiRepositoryProvider);
    try {
      for (final id in _selectedIds.toList()) {
        try {
          await api.delete(id);
          deleted++;
        } catch (_) {
          failed++;
        }
      }
      await _loadAll();
      if (!mounted) return;
      setState(() {
        _selectedIds.clear();
        _multiSelectMode = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failed == 0 ? 'Usunięto $deleted harmonogram${deleted == 1 ? '' : 'y'}' : 'Usunięto $deleted, błędy: $failed')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool?> _openFormDialog({
    DateTime? initialDate,
    int? initialMaszynaId,
    int? initialOsobaId,
    int? initialDuration,
    String? initialOpis,
    int? initialDzialId,
    Future<void> Function(DateTime, int, int, int?, String?, int?)? onSubmit,
    String title = 'Nowy harmonogram',
  }) async {
    if (_osoby.isEmpty) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Brak danych'),
          content: const Text('Dodaj najpierw Osobę w Panelu Admina.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Zamknij')),
            FilledButton(onPressed: () { Navigator.of(ctx).pop(); }, child: const Text('OK')),
          ],
        ),
      );
      return false;
    }

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        content: SizedBox(
          width: 640,
          child: _HarmonogramFormSheet(
            title: title,
            maszyny: _maszyny,
            osoby: _osoby,
            dzialy: _dzialy,
            initialDate: initialDate,
            initialMaszynaId: initialMaszynaId,
            initialOsobaId: initialOsobaId,
            initialDuration: initialDuration,
            initialOpis: initialOpis,
            initialDzialId: initialDzialId,
            onSubmit: (onSubmit ?? (DateTime d, int mId, int oId, int? dur, String? op, int? dzialId) async {
              final api = ref.read(harmonogramyApiRepositoryProvider);
              await api.create(
                data: d,
                maszynaId: mId,
                osobaId: oId,
                dzialId: dzialId,
                opis: op,
                durationMinutes: dur,
              );
            }),
          ),
        ),
      ),
    );
    return result;
  }

  void _handleAddTap() => _addNew();

  @override
  Widget build(BuildContext context) {
    final filtered = _sorted(_applyFilters());
    final totalPages = filtered.isEmpty ? 1 : (filtered.length / _pageSize).ceil();
    if (_page >= totalPages) {
      _page = totalPages - 1;
    }
    final visible = _pageSlice(filtered);
    final visibleIds = visible.map((h) => h.id).toSet();
    final allVisibleSelected = visibleIds.isNotEmpty && visibleIds.every(_selectedIds.contains);
    final allFilteredSelected = filtered.isNotEmpty && filtered.map((h) => h.id).every(_selectedIds.contains);

    return Scaffold(
      appBar: TopAppBar(title: widget.title, showBack: true),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _handleAddTap,
        icon: const Icon(Icons.add),
        label: const Text('Dodaj'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          SizedBox(
                            width: 140,
                            child: DropdownButtonFormField<int>(
                              value: _year,
                              decoration: const InputDecoration(labelText: 'Rok'),
                              items: List<int>.generate(5, (i) => DateTime.now().year - 2 + i)
                                  .map((y) => DropdownMenuItem(value: y, child: Text(y.toString())))
                                  .toList(),
                              onChanged: (v) async {
                                setState(() {
                                  _year = v;
                                  _page = 0;
                                });
                                await _loadAll();
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 160,
                            child: DropdownButtonFormField<int>(
                              value: _month,
                              decoration: const InputDecoration(labelText: 'Miesiąc'),
                              items: [null, ...List<int>.generate(12, (i) => i + 1)]
                                  .map((m) => DropdownMenuItem(value: m, child: Text(m == null ? 'Wszystkie' : m.toString().padLeft(2, '0'))))
                                  .toList(),
                              onChanged: (v) async {
                                setState(() {
                                  _month = v;
                                  _page = 0;
                                });
                                await _loadAll();
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _searchCtrl,
                              decoration: InputDecoration(
                                labelText: 'Szukaj (opis / maszyna / osoba)',
                                prefixIcon: const Icon(Icons.search),
                                suffixIcon: _query.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear),
                                        onPressed: () => setState(() {
                                          _searchCtrl.clear();
                                          _query = '';
                                          _page = 0;
                                        }),
                                      )
                                    : null,
                              ),
                              onChanged: (v) => setState(() {
                                _query = v;
                                _page = 0;
                              }),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _statusFilterChip('WSZYSTKIE'),
                            _statusFilterChip('PLANOWANE'),
                            _statusFilterChip('W_TRAKCIE'),
                            _statusFilterChip('ZAKONCZONE'),
                            _statusFilterChip('BRAK_CZESCI'),
                            _statusFilterChip('OCZEKIWANIE_NA_CZESC'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: filtered.isEmpty ? null : _toggleMultiSelectMode,
                            icon: Icon(_multiSelectMode ? Icons.checklist_rtl : Icons.checklist),
                            label: Text(_multiSelectMode ? 'Wyłącz zaznaczanie' : 'Zaznacz kilka'),
                          ),
                          const SizedBox(width: 8),
                          if (_multiSelectMode)
                            OutlinedButton.icon(
                              onPressed: visible.isEmpty ? null : () => _toggleSelectVisible(visible),
                              icon: Icon(allVisibleSelected ? Icons.remove_done : Icons.select_all),
                              label: Text(allVisibleSelected ? 'Odznacz stronę' : 'Zaznacz stronę'),
                            ),
                          const SizedBox(width: 8),
                          if (_multiSelectMode)
                            OutlinedButton.icon(
                              onPressed: filtered.isEmpty ? null : () => _toggleSelectFiltered(filtered),
                              icon: Icon(Icons.select_all),
                              label: Text(allFilteredSelected ? 'Odznacz wszystkie z filtrowania' : 'Zaznacz wszystkie z filtrowania'),
                            ),
                          const SizedBox(width: 8),
                          if (_multiSelectMode)
                            FilledButton.icon(
                              onPressed: _selectedIds.isEmpty ? null : _deleteSelected,
                              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
                              icon: const Icon(Icons.delete_forever),
                              label: Text('Usuń zaznaczone (${_selectedIds.length})'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadAll,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(12),
                      children: [
                        CenteredScrollableCard(
                          child: DataTable(
                            showCheckboxColumn: _multiSelectMode,
                            sortColumnIndex: _sortCol,
                            sortAscending: _asc,
                            columns: [
                              DataColumn(label: const Text('Data'), onSort: (i, asc) => setState(() { _sortCol = i; _asc = asc; })),
                              DataColumn(label: const Text('Maszyna'), onSort: (i, asc) => setState(() { _sortCol = i; _asc = asc; })),
                              DataColumn(label: const Text('Dział'), onSort: (i, asc) => setState(() { _sortCol = i; _asc = asc; })),
                              DataColumn(label: const Text('Sekcja'), onSort: (i, asc) => setState(() { _sortCol = i; _asc = asc; })),
                              DataColumn(label: const Text('Osoba'), onSort: (i, asc) => setState(() { _sortCol = i; _asc = asc; })),
                              DataColumn(numeric: true, label: const Text('Czas [min]'), onSort: (i, asc) => setState(() { _sortCol = i; _asc = asc; })),
                              DataColumn(label: const Text('Status'), onSort: (i, asc) => setState(() { _sortCol = i; _asc = asc; })),
                              const DataColumn(label: Text('Opis')),
                              const DataColumn(label: Text('Akcje')),
                            ],
                            rows: visible.map((h) {
                              return DataRow(
                                selected: _selectedIds.contains(h.id),
                                onSelectChanged: _multiSelectMode ? (v) => _toggleItemSelection(h, v ?? false) : null,
                                cells: [
                                  DataCell(Text(_fmtDate(h.data))),
                                  DataCell(Text(h.maszyna?.nazwa ?? '-')),
                                  DataCell(Text(h.maszyna?.dzial?.nazwa ?? h.dzial?.nazwa ?? '-')),
                                  DataCell(Text(h.maszyna?.sekcja?.nazwa ?? '-')),
                                  DataCell(Text(h.osoba?.imieNazwisko ?? '-')),
                                  DataCell(Text((h.durationMinutes ?? 0).toString())),
                                  DataCell(Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _statusColor(h.status).withOpacity(.12),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      _statusLabel(h.status),
                                      style: TextStyle(color: _statusColor(h.status), fontWeight: FontWeight.w600),
                                    ),
                                  )),
                                  DataCell(ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 260),
                                    child: Text(h.opis, maxLines: 2, overflow: TextOverflow.ellipsis),
                                  )),
                                  DataCell(Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        tooltip: 'Zmień status',
                                        icon: const Icon(Icons.playlist_add_check_circle_outlined),
                                        color: _statusColor(h.status),
                                        onPressed: () => _quickToggleStatus(h),
                                      ),
                                      IconButton(
                                        tooltip: 'Edytuj',
                                        icon: const Icon(Icons.edit, color: Colors.blueAccent),
                                        onPressed: () => _editItem(h),
                                      ),
                                      IconButton(
                                        tooltip: 'Usuń',
                                        icon: const Icon(Icons.delete, color: Colors.redAccent),
                                        onPressed: () => _deleteItem(h),
                                      ),
                                    ],
                                  )),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                PaginationControls(
                  totalItems: filtered.length,
                  currentPage: _page,
                  pageSize: _pageSize,
                  pageSizes: _pageSizes,
                  onPageChanged: (page) => setState(() => _page = page),
                  onPageSizeChanged: (size) => setState(() {
                    _pageSize = size;
                    _page = 0;
                  }),
                ),
              ],
            ),
    );
  }

  Widget _statusFilterChip(String status) {
    final selected = _statusFilter == status;
    final color = _statusColor(status);
    return ChoiceChip(
      label: Text(_statusLabel(status)),
      selected: selected,
      selectedColor: color.withOpacity(.15),
      onSelected: (_) => setState(() {
        _statusFilter = status;
        _page = 0;
      }),
      labelStyle: TextStyle(color: selected ? color : null),
      side: selected ? BorderSide(color: color) : null,
    );
  }

  Color _statusColor(String s) {
    switch (s.toUpperCase()) {
      case 'PLANOWANE':
        return Colors.indigo;
      case 'W_TRAKCIE':
        return Colors.orange;
      case 'ZAKONCZONE':
        return Colors.green;
      case 'BRAK_CZESCI':
        return Colors.red;
      case 'OCZEKIWANIE_NA_CZESC':
        return Colors.purple;
      default:
        return Colors.blueGrey;
    }
  }

  String _statusLabel(String s) {
    switch (s.toUpperCase()) {
      case 'PLANOWANE':
        return 'Planowane';
      case 'W_TRAKCIE':
        return 'W trakcie';
      case 'ZAKONCZONE':
        return 'Zakończone';
      case 'BRAK_CZESCI':
        return 'Brak części';
      case 'OCZEKIWANIE_NA_CZESC':
        return 'Oczekiwanie na część';
      case 'WSZYSTKIE':
        return 'Wszystkie';
      default:
        return s;
    }
  }

  String _fmtDate(DateTime? d) => d == null ? '-' : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class _HarmonogramFormSheet extends StatefulWidget {
  final String title;
  final List<Maszyna> maszyny;
  final List<Osoba> osoby;
  final List<Dzial> dzialy;
  final Future<void> Function(DateTime data, int maszynaId, int osobaId, int? duration, String? opis, int? dzialId) onSubmit;
  final DateTime? initialDate;
  final int? initialMaszynaId;
  final int? initialOsobaId;
  final int? initialDuration;
  final String? initialOpis;
  final int? initialDzialId;

  const _HarmonogramFormSheet({
    required this.title,
    required this.maszyny,
    required this.osoby,
    required this.dzialy,
    required this.onSubmit,
    this.initialDate,
    this.initialMaszynaId,
    this.initialOsobaId,
    this.initialDuration,
    this.initialOpis,
    this.initialDzialId,
  });

  @override
  State<_HarmonogramFormSheet> createState() => _HarmonogramFormSheetState();
}

class _HarmonogramFormSheetState extends State<_HarmonogramFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _data;
  late final TextEditingController _opisCtrl;
  late final TextEditingController _durationCtrl;
  Dzial? _selectedDzial;
  Maszyna? _selectedMaszyna;
  Osoba? _selectedOsoba;
  List<Maszyna> _maszynyDlaDzialu = [];

  @override
  void initState() {
    super.initState();
    _data = widget.initialDate ?? DateTime.now();
    _opisCtrl = TextEditingController(text: widget.initialOpis ?? '');
    _durationCtrl = TextEditingController(text: widget.initialDuration?.toString() ?? '');

    if (widget.initialOsobaId != null) {
      for (final o in widget.osoby) {
        if (o.id == widget.initialOsobaId) {
          _selectedOsoba = o;
          break;
        }
      }
    }
    if (widget.initialDzialId != null) {
      for (final d in widget.dzialy) {
        if (d.id == widget.initialDzialId) {
          _selectedDzial = d;
          break;
        }
      }
    }
    if (widget.initialMaszynaId != null) {
      for (final m in widget.maszyny) {
        if (m.id == widget.initialMaszynaId) {
          _selectedMaszyna = m;
          if (_selectedDzial == null) _selectedDzial = m.dzial;
          break;
        }
      }
    }
    _refreshMaszyny();
  }

  void _refreshMaszyny() {
    if (_selectedDzial == null) {
      _maszynyDlaDzialu = List<Maszyna>.from(widget.maszyny);
    } else {
      _maszynyDlaDzialu = widget.maszyny.where((m) => m.dzial?.id == _selectedDzial!.id).toList();
    }
    if (_selectedMaszyna != null && !_maszynyDlaDzialu.any((m) => m.id == _selectedMaszyna!.id)) {
      _selectedMaszyna = null;
    }
    if (_selectedMaszyna == null && _maszynyDlaDzialu.isNotEmpty) {
      _selectedMaszyna = _maszynyDlaDzialu.first;
    }
  }

  @override
  void dispose() {
    _opisCtrl.dispose();
    _durationCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            InputDecorator(
              decoration: const InputDecoration(labelText: 'Data', border: OutlineInputBorder()),
              child: InkWell(
                onTap: () async {
                  final picked = await showModernDatePicker(
                    context: context,
                    title: 'Data',
                    initialDate: _data,
                    firstDate: DateTime.now().subtract(const Duration(days: 365 * 5)),
                    lastDate: DateTime(2035, 12, 31),
                  );
                  if (picked != null) setState(() => _data = picked);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text('${_data.year}-${_data.month.toString().padLeft(2, '0')}-${_data.day.toString().padLeft(2, '0')}'),
                ),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<Dzial?>(
              value: _selectedDzial,
              decoration: const InputDecoration(labelText: 'Dział', border: OutlineInputBorder()),
              items: [
                const DropdownMenuItem<Dzial?>(value: null, child: Text('Brak')),
                ...widget.dzialy.map((d) => DropdownMenuItem<Dzial?>(value: d, child: Text(d.nazwa))),
              ],
              onChanged: (v) => setState(() {
                _selectedDzial = v;
                _refreshMaszyny();
              }),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<Maszyna?>(
              value: _selectedMaszyna,
              decoration: const InputDecoration(labelText: 'Maszyna', border: OutlineInputBorder()),
              items: [
                const DropdownMenuItem<Maszyna?>(value: null, child: Text('Brak')),
                ..._maszynyDlaDzialu.map((m) => DropdownMenuItem<Maszyna?>(value: m, child: Text(m.nazwa))),
              ],
              onChanged: (v) => setState(() => _selectedMaszyna = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<Osoba?>(
              value: _selectedOsoba,
              decoration: const InputDecoration(labelText: 'Osoba', border: OutlineInputBorder()),
              items: [
                const DropdownMenuItem<Osoba?>(value: null, child: Text('Brak')),
                ...widget.osoby.map((o) => DropdownMenuItem<Osoba?>(value: o, child: Text(o.imieNazwisko))),
              ],
              onChanged: (v) => setState(() => _selectedOsoba = v),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _durationCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Czas [min]', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _opisCtrl,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Opis', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Anuluj')),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () async {
                    if (_selectedMaszyna == null || _selectedOsoba == null) return;
                    final duration = int.tryParse(_durationCtrl.text.trim());
                    await widget.onSubmit(
                      _data,
                      _selectedMaszyna!.id,
                      _selectedOsoba!.id,
                      duration,
                      _opisCtrl.text.trim().isEmpty ? null : _opisCtrl.text.trim(),
                      _selectedDzial?.id,
                    );
                    if (mounted) Navigator.of(context).pop(true);
                  },
                  child: const Text('Zapisz'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
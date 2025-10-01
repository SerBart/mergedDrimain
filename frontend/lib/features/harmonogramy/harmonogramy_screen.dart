import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/app_providers.dart';
import '../../core/models/harmonogram.dart';
import '../../core/models/maszyna.dart';
import '../../core/models/osoba.dart';
import '../../widgets/centered_scroll_card.dart';

class HarmonogramyScreen extends ConsumerStatefulWidget {
  const HarmonogramyScreen({super.key});

  @override
  ConsumerState<HarmonogramyScreen> createState() => _HarmonogramyScreenState();
}

class _HarmonogramyScreenState extends ConsumerState<HarmonogramyScreen> {
  bool _loading = true;
  List<Harmonogram> _items = [];
  List<Maszyna> _maszyny = [];
  List<Osoba> _osoby = [];

  // Filtry / wyszukiwanie
  int? _year = DateTime.now().year;
  int? _month;
  String _statusFilter = 'WSZYSTKIE';
  String _query = '';
  final _searchCtrl = TextEditingController();

  // Sortowanie
  int _sortCol = 0;
  bool _asc = true;

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
      ]);
      _items = results[0] as List<Harmonogram>;
      _maszyny = results[1] as List<Maszyna>;
      _osoby = results[2] as List<Osoba>;
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
      list = list.where((h) => (h.status).toUpperCase() == _statusFilter);
    }
    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((h) =>
          (h.opis.toLowerCase().contains(q)) ||
          ((h.maszyna?.nazwa.toLowerCase() ?? '').contains(q)) ||
          ((h.osoba?.imieNazwisko.toLowerCase() ?? '').contains(q)));
    }
    return list.toList();
  }

  List<Harmonogram> _sorted(List<Harmonogram> list) {
    list.sort((a, b) {
      int cmp;
      switch (_sortCol) {
        case 0: // Data
          final ad = a.data ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bd = b.data ?? DateTime.fromMillisecondsSinceEpoch(0);
          cmp = ad.compareTo(bd);
          break;
        case 1: // Maszyna
          cmp = (a.maszyna?.nazwa ?? '').compareTo(b.maszyna?.nazwa ?? '');
          break;
        case 2: // Osoba
          cmp = (a.osoba?.imieNazwisko ?? '').compareTo(b.osoba?.imieNazwisko ?? '');
          break;
        case 3: // Czas trwania
          cmp = (a.durationMinutes ?? 0).compareTo(b.durationMinutes ?? 0);
          break;
        case 4: // Status
          cmp = (a.status).compareTo(b.status);
          break;
        default: // Opis
          cmp = a.opis.compareTo(b.opis);
      }
      return _asc ? cmp : -cmp;
    });
    return list;
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
      onSubmit: (data, maszynaId, osobaId, duration, opis) async {
        final api = ref.read(harmonogramyApiRepositoryProvider);
        await api.update(
          id: h.id,
          data: data,
          maszynaId: maszynaId,
          osobaId: osobaId,
          durationMinutes: duration,
          opis: (opis ?? '').trim().isEmpty ? '' : opis!.trim(),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd usuwania: $e')),
        );
      }
    }
  }

  Future<void> _quickToggleStatus(Harmonogram h) async {
    final current = (h.status).toUpperCase();
    String next;
    switch (current) {
      case 'PLANOWANE':
        next = 'W_TRAKCIE';
        break;
      case 'W_TRAKCIE':
        next = 'ZAKONCZONE';
        break;
      default:
        next = 'PLANOWANE';
    }
    try {
      await ref.read(harmonogramyApiRepositoryProvider).update(id: h.id, status: next);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Zmieniono status na ${_statusLabel(next)}')),
        );
      }
      await _loadAll();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Błąd zmiany statusu: $e')),
      );
    }
  }

  Future<bool?> _openFormDialog({
    DateTime? initialDate,
    int? initialMaszynaId,
    int? initialOsobaId,
    int? initialDuration,
    String? initialOpis,
    Future<void> Function(DateTime, int, int, int?, String?)? onSubmit,
    String title = 'Nowy harmonogram',
  }) async {
    if (_maszyny.isEmpty || _osoby.isEmpty) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Brak danych'),
          content: const Text('Dodaj najpierw Maszynę i Osobę w Panelu Admina.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Zamknij')),
            FilledButton(onPressed: () { Navigator.of(ctx).pop(); context.go('/admin'); }, child: const Text('Panel Admina')),
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
          width: 560,
          child: _HarmonogramFormSheet(
            title: title,
            maszyny: _maszyny,
            osoby: _osoby,
            initialDate: initialDate,
            initialMaszynaId: initialMaszynaId,
            initialOsobaId: initialOsobaId,
            initialDuration: initialDuration,
            initialOpis: initialOpis,
            onSubmit: (onSubmit ?? (DateTime d, int mId, int oId, int? dur, String? op) async {
              final api = ref.read(harmonogramyApiRepositoryProvider);
              await api.create(data: d, maszynaId: mId, osobaId: oId, opis: op, durationMinutes: dur);
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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Harmonogramy'),
        leading: IconButton(
          tooltip: 'Dashboard',
          icon: const Icon(Icons.home),
          onPressed: () => context.go('/dashboard'),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _handleAddTap,
        icon: const Icon(Icons.add),
        label: const Text('Dodaj'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Pasek filtrów
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          // Rok
                          SizedBox(
                            width: 140,
                            child: DropdownButtonFormField<int>(
                              value: _year,
                              decoration: const InputDecoration(labelText: 'Rok'),
                              items: List<int>.generate(5, (i) => DateTime.now().year - 2 + i)
                                  .map((y) => DropdownMenuItem(value: y, child: Text(y.toString())))
                                  .toList(),
                              onChanged: (v) async {
                                setState(() => _year = v);
                                await _loadAll();
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Miesiąc
                          SizedBox(
                            width: 160,
                            child: DropdownButtonFormField<int>(
                              value: _month,
                              decoration: const InputDecoration(labelText: 'Miesiąc'),
                              items: [null, ...List<int>.generate(12, (i) => i + 1)]
                                  .map((m) => DropdownMenuItem(
                                        value: m,
                                        child: Text(m == null ? 'Wszystkie' : m.toString().padLeft(2, '0')),
                                      ))
                                  .toList(),
                              onChanged: (v) async {
                                setState(() => _month = v);
                                await _loadAll();
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Szukaj
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
                                        }),
                                      )
                                    : null,
                              ),
                              onChanged: (v) => setState(() => _query = v),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Status chips
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
                    ],
                  ),
                ),
                const Divider(height: 1),
                // Tabela w karcie jak w Zgłoszeniach
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadAll,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: CenteredScrollableCard(
                        child: DataTable(
                          sortColumnIndex: _sortCol,
                          sortAscending: _asc,
                          columns: [
                            DataColumn(
                              label: const Text('Data'),
                              onSort: (i, asc) => setState(() { _sortCol = i; _asc = asc; }),
                            ),
                            DataColumn(
                              label: const Text('Maszyna'),
                              onSort: (i, asc) => setState(() { _sortCol = i; _asc = asc; }),
                            ),
                            DataColumn(
                              label: const Text('Osoba'),
                              onSort: (i, asc) => setState(() { _sortCol = i; _asc = asc; }),
                            ),
                            DataColumn(
                              numeric: true,
                              label: const Text('Czas [min]'),
                              onSort: (i, asc) => setState(() { _sortCol = i; _asc = asc; }),
                            ),
                            DataColumn(
                              label: const Text('Status'),
                              onSort: (i, asc) => setState(() { _sortCol = i; _asc = asc; }),
                            ),
                            const DataColumn(label: Text('Opis')),
                            const DataColumn(label: Text('Akcje')),
                          ],
                          rows: filtered.map((h) {
                            final dateStr = _fmtDate(h.data);
                            return DataRow(
                              cells: [
                                DataCell(Text(dateStr)),
                                DataCell(Text(h.maszyna?.nazwa ?? '-')),
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
                    ),
                  ),
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
      onSelected: (_) => setState(() => _statusFilter = status),
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

  String _fmtDate(DateTime? d) => d == null
      ? '-'
      : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}'
  ;
}

class _HarmonogramFormSheet extends StatefulWidget {
  final String title;
  final List<Maszyna> maszyny;
  final List<Osoba> osoby;
  final Future<void> Function(DateTime data, int maszynaId, int osobaId, int? duration, String? opis) onSubmit;

  final DateTime? initialDate;
  final int? initialMaszynaId;
  final int? initialOsobaId;
  final int? initialDuration;
  final String? initialOpis;

  const _HarmonogramFormSheet({
    required this.title,
    required this.maszyny,
    required this.osoby,
    required this.onSubmit,
    this.initialDate,
    this.initialMaszynaId,
    this.initialOsobaId,
    this.initialDuration,
    this.initialOpis,
  });

  @override
  State<_HarmonogramFormSheet> createState() => _HarmonogramFormSheetState();
}

class _HarmonogramFormSheetState extends State<_HarmonogramFormSheet> {
  final _formKey = GlobalKey<FormState>();
  DateTime? _data;
  Maszyna? _maszyna;
  Osoba? _osoba;
  late final TextEditingController _opisCtrl;
  late final TextEditingController _durationCtrl;

  @override
  void initState() {
    super.initState();
    _data = widget.initialDate ?? DateTime.now();
    if (widget.initialMaszynaId != null) {
      try { _maszyna = widget.maszyny.firstWhere((m) => m.id == widget.initialMaszynaId); } catch (_) {}
    }
    if (widget.initialOsobaId != null) {
      try { _osoba = widget.osoby.firstWhere((o) => o.id == widget.initialOsobaId); } catch (_) {}
    }
    _opisCtrl = TextEditingController(text: widget.initialOpis ?? '');
    _durationCtrl = TextEditingController(text: widget.initialDuration?.toString() ?? '');
  }

  @override
  void dispose() {
    _opisCtrl.dispose();
    _durationCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(widget.title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    tooltip: 'Zamknij',
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Data',
                              border: OutlineInputBorder(),
                            ),
                            child: InkWell(
                              onTap: () async {
                                final now = DateTime.now();
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _data ?? now,
                                  firstDate: DateTime(now.year - 5),
                                  lastDate: DateTime(now.year + 5),
                                );
                                if (picked != null) setState(() => _data = picked);
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                child: Row(
                                  children: [
                                    const Icon(Icons.calendar_month_outlined),
                                    const SizedBox(width: 8),
                                    Text(_data != null
                                        ? '${_data!.year}-${_data!.month.toString().padLeft(2, '0')}-${_data!.day.toString().padLeft(2, '0')}'
                                        : 'Wybierz datę'),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<Maszyna>(
                      value: _maszyna,
                      decoration: const InputDecoration(
                        labelText: 'Maszyna',
                        border: OutlineInputBorder(),
                      ),
                      items: widget.maszyny.map((m) => DropdownMenuItem(value: m, child: Text(m.nazwa))).toList(),
                      onChanged: (v) => setState(() => _maszyna = v),
                      validator: (v) => v == null ? 'Wybierz maszynę' : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<Osoba>(
                      value: _osoba,
                      decoration: const InputDecoration(
                        labelText: 'Osoba (wykonujący)',
                        border: OutlineInputBorder(),
                      ),
                      items: widget.osoby.map((o) => DropdownMenuItem(value: o, child: Text(o.imieNazwisko))).toList(),
                      onChanged: (v) => setState(() => _osoba = v),
                      validator: (v) => v == null ? 'Wybierz osobę' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _durationCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Czas trwania (minuty)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _opisCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Opis (co naprawiano)',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: () async {
                    if (_formKey.currentState?.validate() != true || _data == null || _maszyna == null || _osoba == null) {
                      return;
                    }
                    try {
                      final d = int.tryParse(_durationCtrl.text.trim());
                      await widget.onSubmit(_data!, _maszyna!.id, _osoba!.id, d, _opisCtrl.text);
                      if (mounted) Navigator.of(context).pop(true);
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Błąd zapisu: $e')),
                      );
                    }
                  },
                  icon: const Icon(Icons.save),
                  label: const Text('Zapisz'),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

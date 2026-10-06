class HarmonogramyScreen extends ConsumerStatefulWidget {
  const HarmonogramyScreen({super.key});

  @override
  ConsumerState<HarmonogramyScreen> createState() => _HarmonogramyScreenState();
}

class _HarmonogramyScreenState extends ConsumerState<HarmonogramyScreen> {
  bool _loading = true;
  int _currentPage = 0;
  int _pageSize = 10;
  final Set<int> _selectedIds = <int>{};
  bool _bulkDeleting = false;

  static const List<int> _pageSizes = [10, 20, 50, 100];

  bool get _isPrzegladyView => widget.title == 'Przeglądy';

  const HarmonogramyScreen({super.key, this.title = 'Harmonogramy'});

  final String title;
  List<Dzial> _dzialy = [];

  int? _year = DateTime.now().year;
  int? _month;
  String _statusFilter = 'WSZYSTKIE';
  String _query = '';

  int _sortCol = 0;
  bool _asc = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      int _currentPage = 0;
      int _pageSize = 10;

      static const List<int> _pageSizes = [10, 20, 50, 100];
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

      // Usuń zaznaczenia elementów, które już nie istnieją po odświeżeniu.
      final availableIds = _items.map((e) => e.id).toSet();
      _selectedIds.removeWhere((id) => !availableIds.contains(id));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Błąd ładowania harmonogramów: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _togglePageSelection(List<Harmonogram> pageRows, bool selected) {
    setState(() {
      if (selected) {
        _selectedIds.addAll(pageRows.map((e) => e.id));
      } else {
        _selectedIds.removeAll(pageRows.map((e) => e.id));
      }
    });
  }

  void _toggleRowSelection(int id, bool selected) {
    setState(() {
      if (selected) {
        _selectedIds.add(id);
      } else {
        _selectedIds.remove(id);
      }
    });
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;

    final selectedCount = _selectedIds.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Usuń zaznaczone przeglądy'),
        content: Text('Czy na pewno usunąć $selectedCount zaznaczonych pozycji?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Usuń'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _bulkDeleting = true);
    try {
      final repo = ref.read(harmonogramyApiRepositoryProvider);
      final ids = _selectedIds.toList();
      for (final id in ids) {
        await repo.delete(id);
      }
      if (!mounted) return;
      setState(() => _selectedIds.clear());
      await _loadAll();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Usunięto $selectedCount pozycji.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Błąd grupowego usuwania: $e')),
      );
    } finally {
      if (mounted) setState(() => _bulkDeleting = false);
    }
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
      initialFrequency: h.frequency,
      initialPlanEndDate: h.planEndDate,
      initialApplyToSeriesFuture: true,
      isEditMode: true,
      title: 'Edytuj harmonogram',
      onSubmit: (data, maszynaId, osobaId, duration, opis, dzialId, frequency, planEndDate, applyToSeriesFuture) async {
        final api = ref.read(harmonogramyApiRepositoryProvider);
        await api.update(
          id: h.id,
          data: data,
          maszynaId: maszynaId,
          osobaId: osobaId,
          dzialId: dzialId,
          durationMinutes: duration,
          opis: (opis ?? '').trim(),
          frequency: frequency,
          planEndDate: planEndDate,
          applyToSeriesFuture: applyToSeriesFuture,
        );
      },
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

    if (ok != true) return;

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

  Future<bool?> _openFormDialog({
    DateTime? initialDate,
    int? initialMaszynaId,
    int? initialOsobaId,
    int? initialDuration,
    String? initialOpis,
    int? initialDzialId,
    String? initialFrequency,
    DateTime? initialPlanEndDate,
    bool? initialApplyToSeriesFuture,
    bool isEditMode = false,
    Future<void> Function(DateTime, int, int, int?, String?, int?, String?, DateTime?, bool?)? onSubmit,
    String title = 'Nowy harmonogram',
  }) async {
    if (_osoby.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Brak danych'),
          content: const Text('Dodaj najpierw Osobę w Panelu Admina.'),
          actions: [
            FilledButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK')),
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
          width: 700,
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
            initialFrequency: initialFrequency,
            initialPlanEndDate: initialPlanEndDate,
            initialApplyToSeriesFuture: initialApplyToSeriesFuture,
            isEditMode: isEditMode,
            onSubmit: (onSubmit ??
                (DateTime d, int mId, int oId, int? dur, String? op, int? dzialId, String? frequency, DateTime? planEndDate, bool? applyToSeriesFuture) async {
                  final api = ref.read(harmonogramyApiRepositoryProvider);
                  await api.create(
                    data: d,
                    maszynaId: mId,
                    osobaId: oId,
                    dzialId: dzialId,
                    opis: op,
                    durationMinutes: dur,
                    frequency: frequency,
                    planEndDate: planEndDate,
                  );
                }),
          ),
        ),
      ),
    );

    return result;
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

  String _frequencyLabel(String? frequency) {
    switch ((frequency ?? '').toUpperCase()) {
      case 'TYGODNIOWY':
        return 'Co tydzień';
      case 'MIESIECZNY':
        return 'Co miesiąc';
      case 'KWARTALNY':
        return 'Co kwartał';
      case 'POLROCZNY':
        return 'Co pół roku';
      case 'ROCZNY':
        return 'Co rok';
      case 'DWULETNI':
        return 'Co 2 lata';
      case 'PIECIOLETNI':
        return 'Co 5 lat';
      default:
        return '-';
    }
  }

  String _fmtDate(DateTime? d) {
    if (d == null) return '-';
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final rows = _filteredAndSorted();

    return Scaffold(
      appBar: TopAppBar(title: widget.title, showBack: true),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _bulkDeleting ? null : _addNew,
        icon: const Icon(Icons.add),
        label: const Text('Dodaj'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
      appBar: TopAppBar(title: widget.title, showBack: true),
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 140,
                        child: DropdownButtonFormField<int>(
                          value: _year,
                          decoration: const InputDecoration(labelText: 'Rok'),
                          items: List<int>.generate(7, (i) => DateTime.now().year - 3 + i)
                              .map((y) => DropdownMenuItem(value: y, child: Text(y.toString())))
                              .toList(),
                          onChanged: (v) async {
                            setState(() => _year = v);
                            await _loadAll();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 160,
                        child: DropdownButtonFormField<int>(
                          value: _month,
                            setState(() {
                              _year = v;
                              _currentPage = 0;
                            });
                          items: [null, ...List<int>.generate(12, (i) => i + 1)]
                              .map((m) => DropdownMenuItem(value: m, child: Text(m == null ? 'Wszystkie' : m.toString().padLeft(2, '0'))))
                              .toList(),
                          onChanged: (v) async {
                            setState(() => _month = v);
                            await _loadAll();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          decoration: const InputDecoration(
                            labelText: 'Szukaj (opis / maszyna / osoba / okres)',
                            setState(() {
                              _month = v;
                              _currentPage = 0;
                            });
                          ),
                          onChanged: (v) => setState(() => _query = v),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: Text(_statusLabel('WSZYSTKIE')),
                        selected: _statusFilter == 'WSZYSTKIE',
                        onSelected: (_) => setState(() => _statusFilter = 'WSZYSTKIE'),
                      ),
                      ChoiceChip(
                        label: Text(_statusLabel('PLANOWANE')),
                        selected: _statusFilter == 'PLANOWANE',
                        onSelected: (_) => setState(() => _statusFilter = 'PLANOWANE'),
                      ),
                      ChoiceChip(
                        label: Text(_statusLabel('W_TRAKCIE')),
                        selected: _statusFilter == 'W_TRAKCIE',
                        onSelected: (_) => setState(() => _statusFilter = 'W_TRAKCIE'),
                      ),
                      ChoiceChip(
                        label: Text(_statusLabel('ZAKONCZONE')),
                        selected: _statusFilter == 'ZAKONCZONE',
                        onSelected: (_) => setState(() => _statusFilter = 'ZAKONCZONE'),
                      ),
                      ChoiceChip(
                        label: Text(_statusLabel('BRAK_CZESCI')),
                        selected: _statusFilter == 'BRAK_CZESCI',
                        onSelected: (_) => setState(() => _statusFilter = 'BRAK_CZESCI'),
                      ),
                      ChoiceChip(
                        label: Text(_statusLabel('OCZEKIWANIE_NA_CZESC')),
                        selected: _statusFilter == 'OCZEKIWANIE_NA_CZESC',
                        onSelected: (_) => setState(() => _statusFilter = 'OCZEKIWANIE_NA_CZESC'),
                      ),
                    ],
                  ),
                ),
                if (_isPrzegladyView)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _selectedIds.isEmpty
                                ? 'Zaznacz kilka pozycji, aby usunąć grupowo.'
                                : 'Zaznaczono: ${_selectedIds.length}',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: pageRows.isEmpty || _bulkDeleting
                              ? null
                              : () => _togglePageSelection(pageRows, !allOnPageSelected),
                          icon: Icon(allOnPageSelected ? Icons.deselect : Icons.select_all),
                          label: Text(allOnPageSelected ? 'Odznacz stronę' : 'Zaznacz stronę'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: _selectedIds.isEmpty || _bulkDeleting ? null : _deleteSelected,
                          icon: _bulkDeleting
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.delete_sweep_outlined),
                          label: const Text('Usuń zaznaczone'),
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
                        DataTable(
                          sortColumnIndex: _sortCol,
                          sortAscending: _asc,
                          columns: [
                            if (_isPrzegladyView)
                              DataColumn(
                                label: Checkbox(
                                  value: allOnPageSelected,
                                  onChanged: pageRows.isEmpty || _bulkDeleting
                                      ? null
                                      : (v) => _togglePageSelection(pageRows, v ?? false),
                                ),
                              ),
                            DataColumn(label: const Text('Data'), onSort: (i, asc) => setState(() { _sortCol = i; _asc = asc; })),
                            DataColumn(label: const Text('Maszyna'), onSort: (i, asc) => setState(() { _sortCol = i; _asc = asc; })),
                            DataColumn(label: const Text('Dział'), onSort: (i, asc) => setState(() { _sortCol = i; _asc = asc; })),
                            DataColumn(label: const Text('Osoba'), onSort: (i, asc) => setState(() { _sortCol = i; _asc = asc; })),
                            DataColumn(numeric: true, label: const Text('Czas [min]'), onSort: (i, asc) => setState(() { _sortCol = i; _asc = asc; })),
                            DataColumn(label: const Text('Okres'), onSort: (i, asc) => setState(() { _sortCol = i; _asc = asc; })),
                        if (rows.isEmpty)
                          const Card(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Text('Brak harmonogramów do wyświetlenia.'),
                            ),
                          )
                        else
                          LayoutBuilder(
                            builder: (context, constraints) {
                              return SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                                  child: Align(
                                    alignment: Alignment.topCenter,
                                    child: Card(
                                      margin: EdgeInsets.zero,
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: DataTable(
                                          sortColumnIndex: _sortCol,
                                          sortAscending: _asc,
                                          columns: [
                                            if (_isPrzegladyView)
                                              DataColumn(
                                                label: Checkbox(
                                                  value: allOnPageSelected,
                                                  onChanged: pageRows.isEmpty || _bulkDeleting
                                                      ? null
                                                      : (v) => _togglePageSelection(pageRows, v ?? false),
                                                ),
                                              ),
                                            DataColumn(label: const Text('Data'), onSort: (i, asc) => setState(() { _sortCol = i; _asc = asc; })),
                                            DataColumn(label: const Text('Maszyna'), onSort: (i, asc) => setState(() { _sortCol = i; _asc = asc; })),
                                            DataColumn(label: const Text('Dział'), onSort: (i, asc) => setState(() { _sortCol = i; _asc = asc; })),
                                            DataColumn(label: const Text('Osoba'), onSort: (i, asc) => setState(() { _sortCol = i; _asc = asc; })),
                                            DataColumn(numeric: true, label: const Text('Czas [min]'), onSort: (i, asc) => setState(() { _sortCol = i; _asc = asc; })),
                                            DataColumn(label: const Text('Okres'), onSort: (i, asc) => setState(() { _sortCol = i; _asc = asc; })),
                                            DataColumn(label: const Text('Status'), onSort: (i, asc) => setState(() { _sortCol = i; _asc = asc; })),
                                            DataColumn(label: const Text('Opis'), onSort: (i, asc) => setState(() { _sortCol = i; _asc = asc; })),
                                            const DataColumn(label: Text('Akcje')),
                                          ],
                                          rows: pageRows.map((h) {
                                            return DataRow(
                                              selected: _selectedIds.contains(h.id),
                                              onSelectChanged: _isPrzegladyView && !_bulkDeleting
                                                  ? (v) => _toggleRowSelection(h.id, v ?? false)
                                                  : null,
                                              cells: [
                                                if (_isPrzegladyView)
                                                  DataCell(
                                                    Checkbox(
                                                      value: _selectedIds.contains(h.id),
                                                      onChanged: _bulkDeleting
                                                          ? null
                                                          : (v) => _toggleRowSelection(h.id, v ?? false),
                                                    ),
                                                  ),
                                                DataCell(Text(_fmtDate(h.data))),
                                                DataCell(Text(h.maszyna?.nazwa ?? '-')),
                                                DataCell(Text(h.maszyna?.dzial?.nazwa ?? h.dzial?.nazwa ?? '-')),
                                                DataCell(Text(h.osoba?.imieNazwisko ?? '-')),
                                                DataCell(Text((h.durationMinutes ?? 0).toString())),
                                                DataCell(Text(_frequencyLabel(h.frequency))),
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
                                                DataCell(SizedBox(
                                                  width: 240,
                                                  child: Text(h.opis, maxLines: 2, overflow: TextOverflow.ellipsis),
                                                )),
                                                DataCell(Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
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
                                              ]);
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        if (rows.isNotEmpty)
                          PaginationControls(
                            totalItems: rows.length,
                            currentPage: effectivePage,
                            pageSize: _pageSize,
                            pageSizes: _pageSizes,
                            onPageChanged: (page) {
                              setState(() => _currentPage = page);
                            },
                            onPageSizeChanged: (size) {
                              setState(() {
                                _pageSize = size;
                                _currentPage = 0;
                              });
                            },
                          ),

class _HarmonogramFormSheet extends StatefulWidget {
  final String title;
  final List<Maszyna> maszyny;
  final List<Osoba> osoby;
  final List<Dzial> dzialy;
  final Future<void> Function(
    DateTime data,
    int maszynaId,
    int osobaId,
    int? duration,
    String? opis,
    int? dzialId,
    String? frequency,
    DateTime? planEndDate,
    bool? applyToSeriesFuture,
  ) onSubmit;

  final DateTime? initialDate;
  final int? initialMaszynaId;
  final int? initialOsobaId;
  final int? initialDuration;
  final String? initialOpis;
  final int? initialDzialId;
  final String? initialFrequency;
  final DateTime? initialPlanEndDate;
  final bool? initialApplyToSeriesFuture;
  final bool isEditMode;

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
    this.initialFrequency,
    this.initialPlanEndDate,
    this.initialApplyToSeriesFuture,
    this.isEditMode = false,
  });

  @override
  State<_HarmonogramFormSheet> createState() => _HarmonogramFormSheetState();
}

class _HarmonogramFormSheetState extends State<_HarmonogramFormSheet> {
  late DateTime _data;
  late final TextEditingController _opisCtrl;
  late final TextEditingController _durationCtrl;

  Dzial? _selectedDzial;
  Maszyna? _selectedMaszyna;
  Osoba? _selectedOsoba;
  String? _frequency;
  DateTime? _planEndDate;
  bool _applyToSeriesFuture = true;

  List<Maszyna> _maszynyDlaDzialu = [];

  static const List<String> _frequencyValues = [
    'TYGODNIOWY',
    'MIESIECZNY',
    'KWARTALNY',
    'POLROCZNY',
    'ROCZNY',
    'DWULETNI',
    'PIECIOLETNI',
  ];

  @override
  void initState() {
    super.initState();
    _data = widget.initialDate ?? DateTime.now();
    _opisCtrl = TextEditingController(text: widget.initialOpis ?? '');
    _durationCtrl = TextEditingController(text: widget.initialDuration?.toString() ?? '');

    _frequency = widget.initialFrequency;
    _planEndDate = widget.initialPlanEndDate;
    _applyToSeriesFuture = widget.initialApplyToSeriesFuture ?? true;

    if (_frequency != null && _planEndDate == null) {
      _planEndDate = _suggestPlanEndDate(_data, _frequency!);
    }

    if (widget.initialOsobaId != null) {
      _selectedOsoba = widget.osoby.where((o) => o.id == widget.initialOsobaId).cast<Osoba?>().firstWhere((e) => e != null, orElse: () => null);
    }

    if (widget.initialDzialId != null) {
      _selectedDzial = widget.dzialy.where((d) => d.id == widget.initialDzialId).cast<Dzial?>().firstWhere((e) => e != null, orElse: () => null);
    }

    if (widget.initialMaszynaId != null) {
      _selectedMaszyna = widget.maszyny.where((m) => m.id == widget.initialMaszynaId).cast<Maszyna?>().firstWhere((e) => e != null, orElse: () => null);
      if (_selectedDzial == null) {
        _selectedDzial = _selectedMaszyna?.dzial;
      }
    }

    _refreshMaszyny();
  }

  @override
  void dispose() {
    _opisCtrl.dispose();
    _durationCtrl.dispose();
    super.dispose();
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

  DateTime _suggestPlanEndDate(DateTime start, String frequency) {
    switch (frequency.toUpperCase()) {
      case 'PIECIOLETNI':
        return DateTime(start.year + 20, start.month, start.day);
      case 'DWULETNI':
      case 'ROCZNY':
        return DateTime(start.year + 10, start.month, start.day);
      default:
        return DateTime(start.year + 3, start.month, start.day);
    }
  }

  String _frequencyLabel(String value) {
    switch (value.toUpperCase()) {
      case 'TYGODNIOWY':
        return 'Co tydzień';
      case 'MIESIECZNY':
        return 'Co miesiąc';
      case 'KWARTALNY':
        return 'Co kwartał';
      case 'POLROCZNY':
        return 'Co pół roku';
      case 'ROCZNY':
        return 'Co rok';
      case 'DWULETNI':
        return 'Co 2 lata';
      case 'PIECIOLETNI':
        return 'Co 5 lat';
      default:
        return value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
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
                  lastDate: DateTime(2050, 12, 31),
                );
                if (picked != null) {
                  setState(() {
                    _data = picked;
                    if (_frequency != null && (_planEndDate == null || _planEndDate!.isBefore(_data))) {
                      _planEndDate = _suggestPlanEndDate(_data, _frequency!);
                    }
                  });
                }
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
          DropdownButtonFormField<String?>(
            value: _frequency,
            decoration: const InputDecoration(labelText: 'Okres przeglądu', border: OutlineInputBorder()),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('Jednorazowy')),
              ..._frequencyValues.map((f) => DropdownMenuItem<String?>(value: f, child: Text(_frequencyLabel(f)))),
            ],
            onChanged: (v) => setState(() {
              _frequency = v;
              if (_frequency == null) {
                _planEndDate = null;
              } else {
                _planEndDate ??= _suggestPlanEndDate(_data, _frequency!);
              }
            }),
          ),
          if (_frequency != null) ...[
            const SizedBox(height: 12),
            InputDecorator(
              decoration: const InputDecoration(labelText: 'Planuj do', border: OutlineInputBorder()),
              child: InkWell(
                onTap: () async {
                  final picked = await showModernDatePicker(
                    context: context,
                    title: 'Data końca planu',
                    initialDate: _planEndDate ?? _suggestPlanEndDate(_data, _frequency!),
                    firstDate: _data,
                    lastDate: DateTime(2050, 12, 31),
                  );
                  if (picked != null) {
                    setState(() => _planEndDate = picked);
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    _planEndDate == null
                        ? '-'
                        : '${_planEndDate!.year}-${_planEndDate!.month.toString().padLeft(2, '0')}-${_planEndDate!.day.toString().padLeft(2, '0')}',
                  ),
                ),
              ),
            ),
            if (widget.isEditMode) ...[
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Zastosuj zmiany do przyszłych wpisów serii'),
                value: _applyToSeriesFuture,
                onChanged: (v) => setState(() => _applyToSeriesFuture = v ?? true),
              ),
            ],
          ],
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
                    _frequency,
                    _frequency != null ? _planEndDate : null,
                    widget.isEditMode ? _applyToSeriesFuture : null,
                  );

                  if (mounted) Navigator.of(context).pop(true);
                },
                child: const Text('Zapisz'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

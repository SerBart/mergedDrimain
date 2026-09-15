import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/maszyna.dart';
import '../../core/models/part.dart';
import '../../core/providers/app_providers.dart';
import '../../core/utils/file_download.dart';
import '../../widgets/centered_scroll_card.dart';
import '../../widgets/top_app_bar.dart';

class CzesciListScreen extends ConsumerStatefulWidget {
  const CzesciListScreen({super.key});

  @override
  ConsumerState<CzesciListScreen> createState() => _CzesciListScreenState();
}

class _CzesciListScreenState extends ConsumerState<CzesciListScreen> {
  final TextEditingController _searchCtrl = TextEditingController();

  bool _loading = false;
  bool _importing = false;
  bool _exporting = false;

  String _query = '';
  int? _sortColumn;
  bool _sortAsc = true;

  int _page = 0;
  int _pageSize = 50;
  static const List<int> _pageSizes = [25, 50, 100, 200];

  List<Part> _items = [];
  List<Maszyna> _maszyny = [];
  int? _filterMaszynaId; // null = wszystkie, 0 = Inne, >0 = konkretna maszyna

  List<Part> _derivedParts = const <Part>[];
  bool _derivedDirty = true;

  static const double _wName = 220;
  static const double _wCode = 160;
  static const double _wCategory = 180;
  static const double _wMachine = 200;
  static const double _wQty = 90;
  static const double _wMin = 80;
  static const double _wUnit = 80;
  static const double _wActions = 220;

  @override
  void initState() {
    super.initState();
    _load();
    _loadMaszyny();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _markDerivedDirty() {
    _derivedDirty = true;
  }

  void _ensureDerivedParts() {
    if (!_derivedDirty) return;
    _derivedParts = _filtered(_items);
    _derivedDirty = false;
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(partsApiRepositoryProvider);
      final list = await api.listFull();
      if (mounted) {
        setState(() {
          _items = list;
          _markDerivedDirty();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd ładowania części: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadMaszyny() async {
    try {
      final list = await ref.read(adminApiRepositoryProvider).getMaszyny();
      if (mounted) {
        setState(() => _maszyny = list);
      }
    } catch (_) {}
  }

  Future<void> _importFromExcel() async {
    if (_importing) return;

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['xlsx'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return;

    final file = picked.files.first;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nie udało się odczytać pliku.')),
        );
      }
      return;
    }

    setState(() => _importing = true);
    try {
      final result = await ref.read(partsApiRepositoryProvider).importExcel(
            bytes: bytes,
            fileName: file.name,
          );

      final imported = (result['importedCount'] as num?)?.toInt() ?? 0;
      final created = (result['createdCount'] as num?)?.toInt() ?? 0;
      final updated = (result['updatedCount'] as num?)?.toInt() ?? 0;
      final skipped = (result['skippedCount'] as num?)?.toInt() ?? 0;
      final warningsRaw = result['warnings'];
      final warnings = warningsRaw is List ? warningsRaw.length : 0;

      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Import: $imported, utworzono: $created, zaktualizowano: $updated, pominięto: $skipped, ostrzeżeń: $warnings.',
            ),
          ),
        );
      }
    } on DioException catch (e) {
      final dynamic data = e.response?.data;
      final String msg = (data is Map && data['message'] != null)
          ? data['message'].toString()
          : (e.message ?? 'Błąd importu pliku Excel.');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd importu pliku Excel: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _importing = false);
      }
    }
  }

  Future<void> _exportToExcel() async {
    if (_exporting) return;

    setState(() => _exporting = true);
    try {
      final bytes = await ref.read(partsApiRepositoryProvider).exportExcel();
      if (!mounted) return;

      if (bytes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Eksport zwrócił pusty plik.')),
        );
        return;
      }

      final downloaded = downloadBytesAsFile(
        fileName: 'czesci.xlsx',
        mimeType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        bytes: bytes,
      );

      if (!downloaded) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pobieranie pliku jest wspierane w wersji web aplikacji.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd eksportu pliku Excel: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _exporting = false);
      }
    }
  }

  List<Part> _filtered(List<Part> parts) {
    final q = _query.trim().toLowerCase();
    List<Part> base = parts;

    if (_filterMaszynaId != null) {
      if (_filterMaszynaId == 0) {
        base = base.where((p) => p.maszynaId == null).toList();
      } else {
        base = base.where((p) => p.maszynaId == _filterMaszynaId).toList();
      }
    }

    if (q.isEmpty) {
      if (_sortColumn == null) return base;
      return _sorted([...base]);
    }

    final filtered = base.where((p) {
      return p.nazwa.toLowerCase().contains(q) ||
          p.kod.toLowerCase().contains(q) ||
          (p.kategoria?.toLowerCase().contains(q) ?? false) ||
          (p.maszynaNazwa?.toLowerCase().contains(q) ?? false) ||
          (p.maszynaId == null && 'inne'.contains(q));
    }).toList();

    if (_sortColumn == null) return filtered;
    return _sorted(filtered);
  }

  List<Part> _sorted(List<Part> list) {
    if (_sortColumn == null) return list;

    list.sort((a, b) {
      int cmp;
      switch (_sortColumn!) {
        case 0:
          cmp = a.nazwa.compareTo(b.nazwa);
          break;
        case 1:
          cmp = a.kod.compareTo(b.kod);
          break;
        case 2:
          cmp = (a.kategoria ?? '').compareTo(b.kategoria ?? '');
          break;
        case 3:
          cmp = (a.maszynaNazwa ?? 'Inne').compareTo(b.maszynaNazwa ?? 'Inne');
          break;
        case 4:
          cmp = a.iloscMagazyn.compareTo(b.iloscMagazyn);
          break;
        case 5:
          cmp = a.minIlosc.compareTo(b.minIlosc);
          break;
        default:
          cmp = a.id.compareTo(b.id);
      }
      return _sortAsc ? cmp : -cmp;
    });

    return list;
  }

  List<Part> _pageSlice(List<Part> all) {
    final start = _page * _pageSize;
    final end = (start + _pageSize) > all.length ? all.length : (start + _pageSize);
    if (start >= all.length) return const <Part>[];
    return all.sublist(start, end);
  }

  Future<void> _editPartDialog(Part part) async {
    final nazwa = TextEditingController(text: part.nazwa);
    final kod = TextEditingController(text: part.kod);
    final min = TextEditingController(text: part.minIlosc.toString());
    final jedn = TextEditingController(text: part.jednostka);
    final kat = TextEditingController(text: part.kategoria ?? '');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edytuj część #${part.id}'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nazwa,
                  decoration: const InputDecoration(
                    labelText: 'Nazwa',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: kod,
                  decoration: const InputDecoration(
                    labelText: 'Kod',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: kat,
                  decoration: const InputDecoration(
                    labelText: 'Kategoria / typ',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: min,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Min. ilość',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: jedn,
                        decoration: const InputDecoration(
                          labelText: 'Jednostka',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Zapisz'),
          ),
        ],
      ),
    );

    if (ok == true) {
      try {
        await ref.read(partsApiRepositoryProvider).updatePart(
              id: part.id,
              nazwa: nazwa.text.trim(),
              kod: kod.text.trim(),
              kategoria: kat.text.trim().isEmpty ? null : kat.text.trim(),
              minIlosc: int.tryParse(min.text.trim()),
              jednostka: jedn.text.trim().isEmpty ? null : jedn.text.trim(),
            );
        await _load();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Błąd zapisu: $e')),
          );
        }
      }
    }

    nazwa.dispose();
    kod.dispose();
    min.dispose();
    jedn.dispose();
    kat.dispose();
  }

  Future<void> _openAddPartDialog() async {
    final nazwa = TextEditingController();
    final kod = TextEditingController();
    final kat = TextEditingController();
    final iloscCtrl = TextEditingController();
    final minCtrl = TextEditingController();
    final jednCtrl = TextEditingController(text: 'szt');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dodaj część'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nazwa,
                  decoration: const InputDecoration(
                    labelText: 'Nazwa (wymagane)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: kod,
                  decoration: const InputDecoration(
                    labelText: 'Kod (wymagane)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: kat,
                  decoration: const InputDecoration(
                    labelText: 'Kategoria / typ (opcjonalne)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: iloscCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Ilość startowa',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: minCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Min. ilość',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: jednCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Jednostka',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Dodaj'),
          ),
        ],
      ),
    );

    if (ok == true) {
      try {
        await ref.read(partsApiRepositoryProvider).createPart(
              nazwa: nazwa.text.trim(),
              kod: kod.text.trim(),
              ilosc: int.tryParse(iloscCtrl.text.trim()) ?? 0,
              minIlosc: int.tryParse(minCtrl.text.trim()) ?? 0,
              jednostka: jednCtrl.text.trim().isEmpty ? 'szt' : jednCtrl.text.trim(),
              kategoria: kat.text.trim().isEmpty ? null : kat.text.trim(),
            );
        await _load();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Błąd dodawania: $e')),
          );
        }
      }
    }

    nazwa.dispose();
    kod.dispose();
    kat.dispose();
    iloscCtrl.dispose();
    minCtrl.dispose();
    jednCtrl.dispose();
  }

  Future<void> _assignPartDialog(Part part) async {
    List<Maszyna> maszyny = [];
    int? selectedMaszynaId;

    try {
      maszyny = await ref.read(adminApiRepositoryProvider).getMaszyny();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Nie udało się pobrać listy maszyn: $e')),
        );
      }
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Przypisz część: ${part.nazwa}'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Wybierz maszynę lub "Inne"',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int?>(
                value: selectedMaszynaId,
                isExpanded: true,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: [
                  const DropdownMenuItem<int?>(value: 0, child: Text('Inne')),
                  ...maszyny.map(
                    (m) => DropdownMenuItem<int?>(value: m.id, child: Text(m.nazwa)),
                  ),
                ],
                onChanged: (v) => selectedMaszynaId = v,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Zapisz'),
          ),
        ],
      ),
    );

    if (ok == true) {
      try {
        await ref.read(partsApiRepositoryProvider).assignToMaszyna(
              partId: part.id,
              maszynaId: selectedMaszynaId,
            );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Przypisano część.')),
          );
        }
        await _load();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Błąd przypisywania: $e')),
          );
        }
      }
    }
  }

  Future<void> _adjustQty(Part p, int delta) async {
    try {
      await ref.read(partsApiRepositoryProvider).adjustQuantity(
            partId: p.id,
            delta: delta,
          );
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd zmiany ilości: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    _ensureDerivedParts();

    final filteredParts = _derivedParts;
    final totalPages = filteredParts.isEmpty ? 1 : (filteredParts.length / _pageSize).ceil();
    if (_page >= totalPages) {
      _page = totalPages - 1;
    }
    final visibleParts = _pageSlice(filteredParts);

    return Scaffold(
      appBar: TopAppBar(
        title: 'Części zamienne',
        showBack: false,
        extraActions: [
          IconButton(
            tooltip: 'Odśwież',
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loading
                ? null
                : () async {
                    await _load();
                    await _loadMaszyny();
                  },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddPartDialog,
        icon: const Icon(Icons.add),
        label: const Text('Dodaj część'),
      ),
      body: _loading && _items.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: (_loading || _importing) ? null : _importFromExcel,
                            icon: _importing
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.upload_file),
                            label: Text(_importing ? 'Importowanie...' : 'Import Excel'),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: (_loading || _exporting) ? null : _exportToExcel,
                            icon: _exporting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.download),
                            label: Text(_exporting ? 'Eksport...' : 'Eksport Excel'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchCtrl,
                              decoration: InputDecoration(
                                labelText: 'Szukaj (nazwa / kod / kategoria / maszyna)',
                                prefixIcon: const Icon(Icons.search),
                                suffixIcon: _query.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear),
                                        onPressed: () {
                                          _searchCtrl.clear();
                                          setState(() {
                                            _query = '';
                                            _page = 0;
                                            _markDerivedDirty();
                                          });
                                        },
                                      )
                                    : null,
                              ),
                              onChanged: (v) => setState(() {
                                _query = v;
                                _page = 0;
                                _markDerivedDirty();
                              }),
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 260,
                            child: DropdownButtonFormField<int?>(
                              value: _filterMaszynaId,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Maszyna',
                                border: OutlineInputBorder(),
                              ),
                              items: [
                                const DropdownMenuItem<int?>(value: null, child: Text('Wszystkie')),
                                const DropdownMenuItem<int?>(value: 0, child: Text('Inne')),
                                ..._maszyny.map(
                                  (m) => DropdownMenuItem<int?>(value: m.id, child: Text(m.nazwa)),
                                ),
                              ],
                              onChanged: (v) => setState(() {
                                _filterMaszynaId = v;
                                _page = 0;
                                _markDerivedDirty();
                              }),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: CenteredScrollableCard(
                    child: DataTable(
                      sortColumnIndex: _sortColumn,
                      sortAscending: _sortAsc,
                      columns: [
                        DataColumn(
                          label: ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: _wName),
                            child: const Text('Nazwa'),
                          ),
                          onSort: (i, asc) => setState(() {
                            _sortColumn = i;
                            _sortAsc = asc;
                            _page = 0;
                            _markDerivedDirty();
                          }),
                        ),
                        DataColumn(
                          label: ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: _wCode),
                            child: const Text('Kod'),
                          ),
                          onSort: (i, asc) => setState(() {
                            _sortColumn = i;
                            _sortAsc = asc;
                            _page = 0;
                            _markDerivedDirty();
                          }),
                        ),
                        DataColumn(
                          label: ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: _wCategory),
                            child: const Text('Kategoria'),
                          ),
                          onSort: (i, asc) => setState(() {
                            _sortColumn = i;
                            _sortAsc = asc;
                            _page = 0;
                            _markDerivedDirty();
                          }),
                        ),
                        DataColumn(
                          label: ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: _wMachine),
                            child: const Text('Maszyna'),
                          ),
                          onSort: (i, asc) => setState(() {
                            _sortColumn = i;
                            _sortAsc = asc;
                            _page = 0;
                            _markDerivedDirty();
                          }),
                        ),
                        DataColumn(
                          numeric: true,
                          label: ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: _wQty),
                            child: const Text('Stan'),
                          ),
                          onSort: (i, asc) => setState(() {
                            _sortColumn = i;
                            _sortAsc = asc;
                            _page = 0;
                            _markDerivedDirty();
                          }),
                        ),
                        DataColumn(
                          numeric: true,
                          label: ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: _wMin),
                            child: const Text('Min'),
                          ),
                          onSort: (i, asc) => setState(() {
                            _sortColumn = i;
                            _sortAsc = asc;
                            _page = 0;
                            _markDerivedDirty();
                          }),
                        ),
                        DataColumn(
                          label: ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: _wUnit),
                            child: const Text('Jedn.'),
                          ),
                        ),
                        DataColumn(
                          label: ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: _wActions),
                            child: const Text('Akcje'),
                          ),
                        ),
                      ],
                      rows: visibleParts.map((p) {
                        return DataRow(
                          color: p.belowMin ? WidgetStatePropertyAll(Colors.red.withOpacity(.08)) : null,
                          cells: [
                            DataCell(ConstrainedBox(constraints: const BoxConstraints(minWidth: _wName), child: Text(p.nazwa))),
                            DataCell(ConstrainedBox(constraints: const BoxConstraints(minWidth: _wCode), child: Text(p.kod))),
                            DataCell(ConstrainedBox(constraints: const BoxConstraints(minWidth: _wCategory), child: Text(p.kategoria ?? '-'))),
                            DataCell(ConstrainedBox(constraints: const BoxConstraints(minWidth: _wMachine), child: Text(p.maszynaNazwa ?? 'Inne'))),
                            DataCell(ConstrainedBox(constraints: const BoxConstraints(minWidth: _wQty), child: Text(p.iloscMagazyn.toString()))),
                            DataCell(ConstrainedBox(constraints: const BoxConstraints(minWidth: _wMin), child: Text(p.minIlosc.toString()))),
                            DataCell(ConstrainedBox(constraints: const BoxConstraints(minWidth: _wUnit), child: Text(p.jednostka))),
                            DataCell(
                              ConstrainedBox(
                                constraints: const BoxConstraints(minWidth: _wActions),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: 'Zwiększ',
                                      icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                                      onPressed: () => _adjustQty(p, 1),
                                    ),
                                    IconButton(
                                      tooltip: 'Zmniejsz',
                                      icon: const Icon(Icons.remove_circle_outline, color: Colors.orange),
                                      onPressed: () => _adjustQty(p, -1),
                                    ),
                                    IconButton(
                                      tooltip: 'Edytuj',
                                      icon: const Icon(Icons.edit, color: Colors.blue),
                                      onPressed: () => _editPartDialog(p),
                                    ),
                                    IconButton(
                                      tooltip: 'Przypisz do maszyny / Inne',
                                      icon: const Icon(Icons.link, color: Colors.purple),
                                      onPressed: () => _assignPartDialog(p),
                                    ),
                                    IconButton(
                                      tooltip: 'Usuń część',
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () async {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title: const Text('Usuń część'),
                                            content: Text('Czy na pewno chcesz usunąć część "${p.nazwa}" (ID: ${p.id})?'),
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

                                        if (confirm == true) {
                                          try {
                                            await ref.read(partsApiRepositoryProvider).deletePart(p.id);
                                            if (mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('Usunięto część.')),
                                              );
                                            }
                                            await _load();
                                          } on DioException catch (e) {
                                            final code = e.response?.statusCode;
                                            final msg = code == 409
                                                ? 'Nie można usunąć części - jest używana w innych rekordach.'
                                                : 'Błąd usuwania: ${e.message}';
                                            if (mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text(msg)),
                                              );
                                            }
                                          } catch (e) {
                                            if (mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text('Błąd usuwania: $e')),
                                              );
                                            }
                                          }
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      Text('Pozycje: ${filteredParts.length} | Strona ${_page + 1} z $totalPages'),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Na stronę:'),
                          const SizedBox(width: 8),
                          DropdownButton<int>(
                            value: _pageSize,
                            items: _pageSizes
                                .map((s) => DropdownMenuItem<int>(value: s, child: Text('$s')))
                                .toList(),
                            onChanged: (v) {
                              if (v == null) return;
                              setState(() {
                                _pageSize = v;
                                _page = 0;
                              });
                            },
                          ),
                          IconButton(
                            tooltip: 'Poprzednia strona',
                            onPressed: _page > 0 ? () => setState(() => _page--) : null,
                            icon: const Icon(Icons.chevron_left),
                          ),
                          IconButton(
                            tooltip: 'Następna strona',
                            onPressed: (_page + 1) < totalPages ? () => setState(() => _page++) : null,
                            icon: const Icon(Icons.chevron_right),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
    );
  }
}

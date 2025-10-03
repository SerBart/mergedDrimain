import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../core/providers/app_providers.dart';
import '../../core/models/part.dart';
import '../../core/models/maszyna.dart';
import '../../widgets/centered_scroll_card.dart';

class CzesciListScreen extends ConsumerStatefulWidget {
  const CzesciListScreen({super.key});

  @override
  ConsumerState<CzesciListScreen> createState() => _CzesciListScreenState();
}

class _CzesciListScreenState extends ConsumerState<CzesciListScreen> {
  // Dodawanie (kontrolki formularza)
  final _nazwaCtrl = TextEditingController();
  final _kodCtrl = TextEditingController();
  final _iloscCtrl = TextEditingController();
  final _minCtrl = TextEditingController();
  final _jednCtrl = TextEditingController(text: 'szt');
  final _katCtrl = TextEditingController();

  // Wyszukiwanie
  String _query = '';
  final _searchCtrl = TextEditingController();

  // Sortowanie
  int _sortColumn = 0;
  bool _sortAsc = true;

  // Dane z backendu
  bool _loading = false;
  List<Part> _items = [];
  List<Maszyna> _maszyny = [];
  int? _filterMaszynaId; // null=wszystkie, 0=Inne, >0=konkretna

  // Minimalne szerokości kolumn, aby uniknąć przycinania i pustej przestrzeni
  static const double _wName = 260;
  static const double _wCode = 140;
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

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(partsApiRepositoryProvider);
      final list = await api.listFull();
      setState(() => _items = list);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd ładowania części: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMaszyny() async {
    try {
      final list = await ref.read(adminApiRepositoryProvider).getMaszyny();
      if (mounted) setState(() => _maszyny = list);
    } catch (_) {}
  }

  @override
  void dispose() {
    _nazwaCtrl.dispose();
    _kodCtrl.dispose();
    _iloscCtrl.dispose();
    _minCtrl.dispose();
    _jednCtrl.dispose();
    _katCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
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
    if (q.isEmpty) return _sorted([...base]);
    final f = base.where((p) {
      return p.nazwa.toLowerCase().contains(q) ||
          p.kod.toLowerCase().contains(q) ||
          (p.kategoria?.toLowerCase().contains(q) ?? false) ||
          (p.maszynaNazwa?.toLowerCase().contains(q) ?? false) ||
          (p.maszynaId == null && 'inne'.contains(q));
    }).toList();
    return _sorted(f);
  }

  List<Part> _sorted(List<Part> list) {
    list.sort((a, b) {
      int cmp;
      switch (_sortColumn) {
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

  void _editPartDialog(Part part) {
    final nazwa = TextEditingController(text: part.nazwa);
    final kod = TextEditingController(text: part.kod);
    final min = TextEditingController(text: part.minIlosc.toString());
    final jedn = TextEditingController(text: part.jednostka);
    final kat = TextEditingController(text: part.kategoria ?? '');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Edytuj część #${part.id}'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
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
                        decoration: const InputDecoration(
                          labelText: 'Min. ilość',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
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
            onPressed: () => Navigator.pop(context),
            child: const Text('Anuluj'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await ref.read(partsApiRepositoryProvider).updatePart(
                  id: part.id,
                  nazwa: nazwa.text.trim(),
                  kod: kod.text.trim(),
                  kategoria: kat.text.trim().isEmpty ? null : kat.text.trim(),
                  minIlosc: int.tryParse(min.text),
                  jednostka: jedn.text.trim().isEmpty ? null : jedn.text.trim(),
                );
                if (mounted) Navigator.pop(context);
                await _load();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Błąd zapisu: $e')),
                  );
                }
              }
            },
            child: const Text('Zapisz'),
          ),
        ],
      ),
    );
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
                        decoration: const InputDecoration(
                          labelText: 'Ilość startowa',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: minCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Min. ilość',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
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
                child: Text('Wybierz maszynę lub "Inne"', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int?>(
                value: selectedMaszynaId,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: [
                  const DropdownMenuItem<int?>(value: 0, child: Text('Inne')),
                  ...maszyny.map((m) => DropdownMenuItem<int?>(value: m.id, child: Text(m.nazwa))),
                ],
                onChanged: (v) => selectedMaszynaId = v,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Anuluj')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Zapisz')),
        ],
      ),
    );

    if (ok == true) {
      try {
        await ref.read(partsApiRepositoryProvider)
            .assignToMaszyna(partId: part.id, maszynaId: selectedMaszynaId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Przypisano część.')),
          );
        }
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
      await ref.read(partsApiRepositoryProvider).adjustQuantity(partId: p.id, delta: delta);
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
    final parts = _filtered(_items);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Części zamienne'),
        leading: IconButton(
          tooltip: 'Dashboard',
          icon: const Icon(Icons.home),
          onPressed: () => context.go('/dashboard'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : () async { await _load(); await _loadMaszyny(); },
            tooltip: 'Odśwież',
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
                  child: Row(
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
                                      setState(() => _query = '');
                                    },
                                  )
                                : null,
                          ),
                          onChanged: (v) => setState(() => _query = v),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 260,
                        child: DropdownButtonFormField<int?>(
                          value: _filterMaszynaId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Maszyna', border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem<int?>(value: null, child: Text('Wszystkie')),
                            const DropdownMenuItem<int?>(value: 0, child: Text('Inne')),
                            ..._maszyny.map((m) => DropdownMenuItem<int?>(value: m.id, child: Text(m.nazwa))),
                          ],
                          onChanged: (v) => setState(() => _filterMaszynaId = v),
                        ),
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
                          onSort: (i, asc) => setState(() { _sortColumn = i; _sortAsc = asc; }),
                        ),
                        DataColumn(
                          label: ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: _wCode),
                            child: const Text('Kod'),
                          ),
                          onSort: (i, asc) => setState(() { _sortColumn = i; _sortAsc = asc; }),
                        ),
                        DataColumn(
                          label: ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: _wCategory),
                            child: const Text('Kategoria'),
                          ),
                          onSort: (i, asc) => setState(() { _sortColumn = i; _sortAsc = asc; }),
                        ),
                        DataColumn(
                          label: ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: _wMachine),
                            child: const Text('Maszyna'),
                          ),
                          onSort: (i, asc) => setState(() { _sortColumn = i; _sortAsc = asc; }),
                        ),
                        DataColumn(
                          numeric: true,
                          label: ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: _wQty),
                            child: const Text('Stan'),
                          ),
                          onSort: (i, asc) => setState(() { _sortColumn = i; _sortAsc = asc; }),
                        ),
                        DataColumn(
                          numeric: true,
                          label: ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: _wMin),
                            child: const Text('Min'),
                          ),
                          onSort: (i, asc) => setState(() { _sortColumn = i; _sortAsc = asc; }),
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
                      rows: parts.map((p) {
                        return DataRow(
                          color: p.belowMin
                              ? WidgetStatePropertyAll(Colors.red.withOpacity(.08))
                              : null,
                          cells: [
                            DataCell(ConstrainedBox(
                              constraints: const BoxConstraints(minWidth: _wName),
                              child: Text(p.nazwa, overflow: TextOverflow.visible),
                            )),
                            DataCell(ConstrainedBox(
                              constraints: const BoxConstraints(minWidth: _wCode),
                              child: Text(p.kod, overflow: TextOverflow.visible),
                            )),
                            DataCell(ConstrainedBox(
                              constraints: const BoxConstraints(minWidth: _wCategory),
                              child: Text(p.kategoria ?? '-', overflow: TextOverflow.visible),
                            )),
                            DataCell(ConstrainedBox(
                              constraints: const BoxConstraints(minWidth: _wMachine),
                              child: Text(p.maszynaNazwa ?? 'Inne', overflow: TextOverflow.visible),
                            )),
                            DataCell(ConstrainedBox(
                              constraints: const BoxConstraints(minWidth: _wQty),
                              child: Text(p.iloscMagazyn.toString()),
                            )),
                            DataCell(ConstrainedBox(
                              constraints: const BoxConstraints(minWidth: _wMin),
                              child: Text(p.minIlosc.toString()),
                            )),
                            DataCell(ConstrainedBox(
                              constraints: const BoxConstraints(minWidth: _wUnit),
                              child: Text(p.jednostka),
                            )),
                            DataCell(ConstrainedBox(
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
                                            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Anuluj')),
                                            FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Usuń')),
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
                                              ? 'Nie można usunąć części – jest używana w innych rekordach.'
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
                            )),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/app_providers.dart';
import '../../core/models/part.dart';

class CzesciListScreen extends ConsumerStatefulWidget {
  const CzesciListScreen({super.key});

  @override
  ConsumerState<CzesciListScreen> createState() => _CzesciListScreenState();
}

class _CzesciListScreenState extends ConsumerState<CzesciListScreen> {
  // Dodawanie
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

  void _add() {
    final repo = ref.read(mockRepoProvider);
    if (_nazwaCtrl.text.isEmpty || _kodCtrl.text.isEmpty) return;
    final ilosc = int.tryParse(_iloscCtrl.text) ?? 0;
    final minI = int.tryParse(_minCtrl.text) ?? 0;
    repo.addPart(
      nazwa: _nazwaCtrl.text.trim(),
      kod: _kodCtrl.text.trim(),
      ilosc: ilosc,
      minIlosc: minI,
      jednostka: _jednCtrl.text.trim().isEmpty ? 'szt' : _jednCtrl.text.trim(),
      kategoria: _katCtrl.text.trim().isEmpty ? null : _katCtrl.text.trim(),
    );
    _nazwaCtrl.clear();
    _kodCtrl.clear();
    _iloscCtrl.clear();
    _minCtrl.clear();
    _katCtrl.clear();
    setState(() {});
  }

  List<Part> _filtered(List<Part> parts) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _sorted(parts);
    final f = parts.where((p) {
      return p.nazwa.toLowerCase().contains(q) ||
          p.kod.toLowerCase().contains(q) ||
          (p.kategoria?.toLowerCase().contains(q) ?? false);
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
          cmp = a.iloscMagazyn.compareTo(b.iloscMagazyn);
          break;
        case 4:
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
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: nazwa,
                  decoration: const InputDecoration(labelText: 'Nazwa'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: kod,
                  decoration: const InputDecoration(labelText: 'Kod'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: kat,
                  decoration: const InputDecoration(labelText: 'Kategoria / typ'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: min,
                  decoration: const InputDecoration(labelText: 'Min. ilość'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: jedn,
                  decoration: const InputDecoration(labelText: 'Jednostka'),
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
            onPressed: () {
              final repo = ref.read(mockRepoProvider);
              final newObj = part.copyWith(
                nazwa: nazwa.text.trim(),
                kod: kod.text.trim(),
                kategoria: kat.text.trim().isEmpty ? null : kat.text.trim(),
                minIlosc: int.tryParse(min.text) ?? part.minIlosc,
                jednostka: jedn.text.trim().isEmpty ? part.jednostka : jedn.text.trim(),
              );
              repo.updatePart(newObj);
              Navigator.pop(context);
              setState(() {});
            },
            child: const Text('Zapisz'),
          ),
        ],
      ),
    );
  }

  void _adjustQty(Part p, int delta) {
    final repo = ref.read(mockRepoProvider);
    try {
      repo.adjustPartQuantity(p.id, delta);
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Błąd: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(mockRepoProvider);
    final parts = _filtered(repo.getParts().toList());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Części zamienne'),
      ),
      body: Column(
        children: [
          // Pasek wyszukiwania
            Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                labelText: 'Szukaj (nazwa / kod / kategoria)',
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
          ExpansionTile(
            title: const Text('Dodaj część'),
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    TextField(
                      controller: _nazwaCtrl,
                      decoration: const InputDecoration(labelText: 'Nazwa'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _kodCtrl,
                      decoration: const InputDecoration(labelText: 'Kod'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _katCtrl,
                      decoration: const InputDecoration(labelText: 'Kategoria / typ'),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _iloscCtrl,
                            decoration: const InputDecoration(labelText: 'Ilość startowa'),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _minCtrl,
                            decoration: const InputDecoration(labelText: 'Min. ilość'),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _jednCtrl,
                            decoration: const InputDecoration(labelText: 'Jednostka'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        onPressed: _add,
                        child: const Text('Dodaj'),
                      ),
                    ),
                  ],
                ),
              )
            ],
          ),
          const Divider(height: 1),
          // Tabela
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                sortColumnIndex: _sortColumn,
                sortAscending: _sortAsc,
                columns: [
                  DataColumn(
                    label: const Text('Nazwa'),
                    onSort: (i, asc) => setState(() {
                      _sortColumn = i;
                      _sortAsc = asc;
                    }),
                  ),
                  DataColumn(
                    label: const Text('Kod'),
                    onSort: (i, asc) => setState(() {
                      _sortColumn = i;
                      _sortAsc = asc;
                    }),
                  ),
                  DataColumn(
                    label: const Text('Kategoria'),
                    onSort: (i, asc) => setState(() {
                      _sortColumn = i;
                      _sortAsc = asc;
                    }),
                  ),
                  DataColumn(
                    numeric: true,
                    label: const Text('Stan'),
                    onSort: (i, asc) => setState(() {
                      _sortColumn = i;
                      _sortAsc = asc;
                    }),
                  ),
                  DataColumn(
                    numeric: true,
                    label: const Text('Min'),
                    onSort: (i, asc) => setState(() {
                      _sortColumn = i;
                      _sortAsc = asc;
                    }),
                  ),
                  const DataColumn(label: Text('Jedn.')),
                  const DataColumn(label: Text('Akcje')),
                ],
                rows: parts.map((p) {
                  return DataRow(
                    color: p.belowMin
                        ? WidgetStatePropertyAll(Colors.red.withOpacity(.08))
                        : null,
                    cells: [
                      DataCell(Text(p.nazwa)),
                      DataCell(Text(p.kod)),
                      DataCell(Text(p.kategoria ?? '-')),
                      DataCell(Text(p.iloscMagazyn.toString())),
                      DataCell(Text(p.minIlosc.toString())),
                      DataCell(Text(p.jednostka)),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Zwiększ',
                              icon: const Icon(Icons.add_circle_outline,
                                  color: Colors.green),
                              onPressed: () => _adjustQty(p, 1),
                            ),
                            IconButton(
                              tooltip: 'Zmniejsz',
                              icon: const Icon(Icons.remove_circle_outline,
                                  color: Colors.orange),
                              onPressed: () => _adjustQty(p, -1),
                            ),
                            IconButton(
                              tooltip: 'Edytuj',
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _editPartDialog(p),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers/app_providers.dart';
import '../../core/models/zgloszenie.dart';

class ZgloszeniaScreenModern extends ConsumerStatefulWidget {
  const ZgloszeniaScreenModern({super.key});

  @override
  ConsumerState<ZgloszeniaScreenModern> createState() =>
      _ZgloszeniaScreenModernState();
}

class _ZgloszeniaScreenModernState
    extends ConsumerState<ZgloszeniaScreenModern> {
  // Formularz dodawania/edycji
  final _formKey = GlobalKey<FormState>();
  final _imieCtrl = TextEditingController();
  final _nazCtrl = TextEditingController();
  final _opisCtrl = TextEditingController();

  // Wartości domyślne
  String _status = 'NOWE';
  String _typSelected = 'Usterka';

  // Wyszukiwanie / filtrowanie / sortowanie
  final _search = TextEditingController();
  String _query = '';
  String _statusFilter = 'WSZYSTKIE';
  final _dtf = DateFormat('yyyy-MM-dd HH:mm');
  int _sortCol = 1;
  bool _asc = false;

  bool _busy = false;

  static const types = ['Usterka', 'Awaria', 'Przezbrojenie'];
  static const statusy = ['NOWE', 'W TOKU', 'WERYFIKACJA', 'ZAMKNIĘTE'];

  @override
  void initState() {
    super.initState();
    _loadFromApi();
  }

  @override
  void dispose() {
    _imieCtrl.dispose();
    _nazCtrl.dispose();
    _opisCtrl.dispose();
    _search.dispose();
    super.dispose();
  }

  // Pobranie z backendu i zasilenie lokalnego mock repo (cache dla UI)
  Future<void> _loadFromApi() async {
    setState(() => _busy = true);
    try {
      final apiRepo = ref.read(zgloszeniaApiRepositoryProvider);
      final items = await apiRepo.fetchAll();

      final mock = ref.read(mockRepoProvider);
      mock.zgloszenia
        ..clear()
        ..addAll(items);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Błąd pobierania z API: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  List<Zgloszenie> _filtered(List<Zgloszenie> all) {
    var list = List<Zgloszenie>.from(all);

    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list.where((z) {
        return z.typ.toLowerCase().contains(q) ||
            z.opis.toLowerCase().contains(q) ||
            z.imie.toLowerCase().contains(q) ||
            z.nazwisko.toLowerCase().contains(q) ||
            z.status.toLowerCase().contains(q) ||
            z.id.toString().contains(q);
      }).toList();
    }

    if (_statusFilter != 'WSZYSTKIE') {
      list = list.where((z) => z.status == _statusFilter).toList();
    }

    list.sort((a, b) {
      int cmp;
      switch (_sortCol) {
        case 0:
          cmp = a.id.compareTo(b.id);
          break;
        case 1:
          cmp = a.dataGodzina.compareTo(b.dataGodzina);
          break;
        case 2:
          cmp = a.typ.compareTo(b.typ);
          break;
        case 3:
          cmp = a.status.compareTo(b.status);
          break;
        case 4:
          cmp = a.nazwisko.compareTo(b.nazwisko);
          break;
        default:
          cmp = a.id.compareTo(b.id);
      }
      return _asc ? cmp : -cmp;
    });

    return list;
  }

  void _onSort(int i, bool asc) {
    setState(() {
      _sortCol = i;
      _asc = asc;
    });
  }

  void _resetForm() {
    _imieCtrl.clear();
    _nazCtrl.clear();
    _opisCtrl.clear();
    _status = 'NOWE';
    _typSelected = 'Usterka';
  }

  Future<void> _add() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final api = ref.read(zgloszeniaApiRepositoryProvider);
      final created = await api.create(
        imie: _imieCtrl.text.trim(),
        nazwisko: _nazCtrl.text.trim(),
        typUi: _typSelected,
        opis: _opisCtrl.text.trim(),
        statusUi: _status,
      );

      // Zaktualizuj lokalny cache
      ref.read(mockRepoProvider).addZgloszenie(created);
      _resetForm();

      if (mounted) {
        Navigator.of(context).maybePop(); // zamknij bottom sheet jeśli otwarty
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dodano zgłoszenie')),
        );
        setState(() {});
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Błąd dodawania: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _editDialog(Zgloszenie z) {
    final imie = TextEditingController(text: z.imie);
    final nazw = TextEditingController(text: z.nazwisko);
    final opis = TextEditingController(text: z.opis);
    var typ = z.typ;
    var status = z.status;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edytuj #${z.id}'),
        content: StatefulBuilder(builder: (context, setLocal) {
          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: imie,
                        decoration: const InputDecoration(labelText: 'Imię'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: nazw,
                        decoration:
                        const InputDecoration(labelText: 'Nazwisko'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: typ,
                  decoration: const InputDecoration(labelText: 'Typ'),
                  items: types
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setLocal(() => typ = v ?? typ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: opis,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Opis'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: statusy
                      .map((s) =>
                      DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => setLocal(() => status = v ?? status),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: _busy
                        ? null
                        : () async {
                      setState(() => _busy = true);
                      try {
                        final updated = z.copyWith(
                          imie: imie.text.trim(),
                          nazwisko: nazw.text.trim(),
                          typ: typ,
                          opis: opis.text.trim(),
                          status: status,
                        );
                        final api =
                        ref.read(zgloszeniaApiRepositoryProvider);
                        final saved = await api.update(updated);

                        ref
                            .read(mockRepoProvider)
                            .updateZgloszenie(saved);
                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Zapisano zmiany')),
                          );
                          setState(() {});
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('Błąd zapisu: $e')),
                          );
                        }
                      } finally {
                        if (mounted) setState(() => _busy = false);
                      }
                    },
                    child: const Text('Zapisz'),
                  ),
                ),
              ],
            ),
          );
        }),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Anuluj'),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(Zgloszenie z) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Usuń zgłoszenie #${z.id}?'),
        content: const Text('Tej operacji nie można cofnąć.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Usuń'),
          ),
        ],
      ),
    );
    if (ok == true) {
      setState(() => _busy = true);
      try {
        final api = ref.read(zgloszeniaApiRepositoryProvider);
        await api.delete(z.id);
        ref.read(mockRepoProvider).deleteZgloszenie(z.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Usunięto zgłoszenie')),
          );
          setState(() {});
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Błąd usuwania: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    }
  }

  Widget _filtersBar() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoiceChip(
          label: const Text('WSZYSTKIE'),
          selected: _statusFilter == 'WSZYSTKIE',
          onSelected: (_) => setState(() => _statusFilter = 'WSZYSTKIE'),
        ),
        ...statusy.map((s) => ChoiceChip(
          label: Text(s),
          selected: _statusFilter == s,
          onSelected: (_) => setState(() => _statusFilter = s),
        )),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(mockRepoProvider);
    final data = _filtered(repo.getZgloszenia());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Zgłoszenia'),
        actions: [
          IconButton(
            tooltip: 'Odśwież z API',
            icon: const Icon(Icons.refresh),
            onPressed: _busy ? null : _loadFromApi,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy
            ? null
            : () {
          showModalBottomSheet(
            isScrollControlled: true,
            context: context,
            builder: (_) => Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _imieCtrl,
                              decoration: const InputDecoration(
                                  labelText: 'Imię'),
                              validator: (v) => (v == null || v.isEmpty)
                                  ? 'Podaj imię'
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _nazCtrl,
                              decoration: const InputDecoration(
                                  labelText: 'Nazwisko'),
                              validator: (v) =>
                              (v == null || v.isEmpty)
                                  ? 'Podaj nazwisko'
                                  : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _typSelected,
                        decoration:
                        const InputDecoration(labelText: 'Typ'),
                        items: types
                            .map((e) => DropdownMenuItem(
                            value: e, child: Text(e)))
                            .toList(),
                        onChanged: (v) => setState(
                                () => _typSelected = v ?? _typSelected),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _opisCtrl,
                        maxLines: 3,
                        decoration:
                        const InputDecoration(labelText: 'Opis'),
                        validator: (v) =>
                        (v == null || v.trim().length < 5)
                            ? 'Opis min. 5 znaków'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _status,
                        decoration:
                        const InputDecoration(labelText: 'Status'),
                        items: statusy
                            .map((s) => DropdownMenuItem(
                            value: s, child: Text(s)))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _status = v ?? _status),
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton(
                          onPressed: _busy ? null : _add,
                          child: const Text('Dodaj'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Dodaj'),
      ),
      body: AbsorbPointer(
        absorbing: _busy,
        child: Opacity(
          opacity: _busy ? 0.6 : 1,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Wyszukiwarka
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _search,
                        decoration: InputDecoration(
                          hintText:
                          'Szukaj po opisie, typie, osobie, statusie...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _query.isNotEmpty
                              ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _search.clear();
                              setState(() => _query = '');
                            },
                          )
                              : null,
                        ),
                        onChanged: (v) => setState(() => _query = v.trim()),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: _busy ? null : _loadFromApi,
                      icon: const Icon(Icons.sync),
                      label: const Text('Synchronizuj'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Filtry statusów
                Align(
                  alignment: Alignment.centerLeft,
                  child: _filtersBar(),
                ),
                const SizedBox(height: 12),
                // Tabela wyników
                Expanded(
                  child: Card(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        sortColumnIndex: _sortCol,
                        sortAscending: _asc,
                        columns: [
                          DataColumn(
                            label: const Text('ID'),
                            numeric: true,
                            onSort: (i, asc) => _onSort(i, asc),
                          ),
                          DataColumn(
                            label: const Text('Data'),
                            onSort: (i, asc) => _onSort(i, asc),
                          ),
                          DataColumn(
                            label: const Text('Typ'),
                            onSort: (i, asc) => _onSort(i, asc),
                          ),
                          DataColumn(
                            label: const Text('Status'),
                            onSort: (i, asc) => _onSort(i, asc),
                          ),
                          const DataColumn(label: Text('Osoba')),
                          const DataColumn(label: Text('Opis')),
                          const DataColumn(label: Text('Akcje')),
                        ],
                        rows: data.map((z) {
                          return DataRow(
                            cells: [
                              DataCell(Text(z.id.toString())),
                              DataCell(Text(_dtf.format(z.dataGodzina))),
                              DataCell(Text(z.typ)),
                              DataCell(_statusChip(z.status)),
                              DataCell(Text('${z.imie} ${z.nazwisko}')),
                              DataCell(
                                ConstrainedBox(
                                  constraints:
                                  const BoxConstraints(maxWidth: 320),
                                  child: Text(
                                    z.opis,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              DataCell(Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'Edytuj',
                                    icon: const Icon(Icons.edit),
                                    onPressed: () => _editDialog(z),
                                  ),
                                  IconButton(
                                    tooltip: 'Usuń',
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red),
                                    onPressed: () => _delete(z),
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusChip(String status) {
    Color color;
    switch (status) {
      case 'NOWE':
        color = Colors.blue;
        break;
      case 'W TOKU':
        color = Colors.orange;
        break;
      case 'WERYFIKACJA':
        color = Colors.purple;
        break;
      case 'ZAMKNIĘTE':
        color = Colors.green;
        break;
      default:
        color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
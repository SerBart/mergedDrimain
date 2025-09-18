import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/providers/app_providers.dart';
import '../../core/models/zgloszenie.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_card.dart';
import '../../widgets/section_header.dart';
import '../../widgets/status_chip.dart';
import '../../widgets/table/data_table_pro.dart';

class ZgloszeniaScreenModern extends ConsumerStatefulWidget {
  const ZgloszeniaScreenModern({super.key});

  @override
  ConsumerState<ZgloszeniaScreenModern> createState() =>
      _ZgloszeniaScreenModernState();
}

class _ZgloszeniaScreenModernState
    extends ConsumerState<ZgloszeniaScreenModern> {
  final _formKey = GlobalKey<FormState>();
  final _imieCtrl = TextEditingController();
  final _nazCtrl = TextEditingController();
  final _opisCtrl = TextEditingController();
  String _status = 'NOWE';
  String _typSelected = 'Usterka';
  String _query = '';
  String _statusFilter = 'WSZYSTKIE';
  final _search = TextEditingController();
  final _dtf = DateFormat('yyyy-MM-dd HH:mm');
  int _sortCol = 1;
  bool _asc = false;

  static const types = ['Usterka', 'Awaria', 'Przezbrojenie'];

  @override
  void dispose() {
    _imieCtrl.dispose();
    _nazCtrl.dispose();
    _opisCtrl.dispose();
    _search.dispose();
    super.dispose();
  }

 List<Zgloszenie> _filtered(List<Zgloszenie> all) {
  // Kopia
  var list = List<Zgloszenie>.from(all);

  if (_query.isNotEmpty) {
    final q = _query.toLowerCase();
    list = list.where((z) {
      return z.typ.toLowerCase().contains(q) ||
          z.opis.toLowerCase().contains(q) ||
          z.imie.toLowerCase().contains(q) ||
          z.nazwisko.toLowerCase().contains(q) ||
          z.status.toLowerCase().contains(q) ||
          z.id.toString() == q;
    }).toList();
  }

  if (_statusFilter != 'WSZYSTKIE') {
    list = list
        .where((z) => z.status.toUpperCase() == _statusFilter.toUpperCase())
        .toList();
  }

  // Sort na kopii
  final sorted = List<Zgloszenie>.from(list);
  sorted.sort((a, b) {
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
        cmp = ('${a.imie} ${a.nazwisko}').compareTo('${b.imie} ${b.nazwisko}');
        break;
      case 4:
        cmp = a.status.compareTo(b.status);
        break;
      default:
        cmp = b.id.compareTo(a.id);
    }
    return _asc ? cmp : -cmp;
  });
  return sorted;
}

  void _onSort(int i, bool asc) {
    setState(() {
      _sortCol = i;
      _asc = asc;
    });
  }

  void _add() {
    if (!_formKey.currentState!.validate()) return;
    ref.read(mockRepoProvider).addZgloszenie(Zgloszenie(
          id: 0,
          imie: _imieCtrl.text.trim(),
          nazwisko: _nazCtrl.text.trim(),
          typ: _typSelected,
          dataGodzina: DateTime.now(),
          opis: _opisCtrl.text.trim(),
          status: _status,
        ));
    _imieCtrl.clear();
    _nazCtrl.clear();
    _opisCtrl.clear();
    _status = 'NOWE';
    _typSelected = 'Usterka';
    setState(() {});
  }

  void _editDialog(Zgloszenie z) {
    final imie = TextEditingController(text: z.imie);
    final nazw = TextEditingController(text: z.nazwisko);
    final opis = TextEditingController(text: z.opis);
    String typ = types.contains(z.typ) ? z.typ : types.first;
    String status = z.status;

    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: StatefulBuilder(
              builder: (ctx, setLocal) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text('Edytuj #${z.id}',
                          style: Theme.of(context).textTheme.titleLarge),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      )
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: imie,
                          decoration:
                              const InputDecoration(labelText: 'Imię'),
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
                        .map((e) =>
                            DropdownMenuItem(value: e, child: Text(e)))
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
                    items: const [
                      DropdownMenuItem(value: 'NOWE', child: Text('NOWE')),
                      DropdownMenuItem(value: 'W TOKU', child: Text('W TOKU')),
                      DropdownMenuItem(
                          value: 'WERYFIKACJA', child: Text('WERYFIKACJA')),
                      DropdownMenuItem(
                          value: 'ZAMKNIĘTE', child: Text('ZAMKNIĘTE')),
                    ],
                    onChanged: (v) => setLocal(() => status = v ?? status),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Ost. aktualizacja: ${DateFormat('yyyy-MM-dd HH:mm').format(z.lastUpdated)}',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.grey),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Anuluj'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () {
                          ref.read(mockRepoProvider).updateZgloszenie(
                                z.copyWith(
                                  imie: imie.text.trim(),
                                  nazwisko: nazw.text.trim(),
                                  typ: typ,
                                  opis: opis.text.trim(),
                                  status: status,
                                ),
                              );
                          Navigator.pop(context);
                          setState(() {});
                        },
                        child: const Text('Zapisz'),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _delete(Zgloszenie z) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Usuń zgłoszenie #${z.id}?'),
        content: const Text('Tej operacji nie można cofnąć (demo).'),
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
      ref.read(mockRepoProvider).deleteZgloszenie(z.id);
      setState(() {});
    }
  }

  Widget _statusChipFilter(String label) {
    final sel = _statusFilter == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: sel,
        onSelected: (_) => setState(() => _statusFilter = label),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(mockRepoProvider);
    final data = _filtered(repo.getZgloszenia());

    return AppScaffold(
      appBar: AppBar(
        title: const Text('Zgłoszenia'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Panel zgłoszeń',
            subtitle: 'Rejestr incydentów i prac do wykonania',
          ),
          AppCard(
            title: 'Filtrowanie',
            divided: true,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _search,
                        decoration: const InputDecoration(
                          labelText:
                              'Szukaj (id / typ / opis / imię / nazwisko / status)',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (v) => setState(() => _query = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 38,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _statusChipFilter('WSZYSTKIE'),
                      _statusChipFilter('NOWE'),
                      _statusChipFilter('W TOKU'),
                      _statusChipFilter('WERYFIKACJA'),
                      _statusChipFilter('ZAMKNIĘTE'),
                    ],
                  ),
                )
              ],
            ),
          ),
          AppCard(
            title: 'Dodaj zgłoszenie',
            divided: true,
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _imieCtrl,
                          decoration: const InputDecoration(labelText: 'Imię'),
                          validator: (v) =>
                              v == null || v.trim().isEmpty ? 'Wymagane' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _nazCtrl,
                          decoration:
                              const InputDecoration(labelText: 'Nazwisko'),
                          validator: (v) =>
                              v == null || v.trim().isEmpty ? 'Wymagane' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _typSelected,
                          decoration:
                              const InputDecoration(labelText: 'Typ'),
                          items: types
                              .map((t) =>
                                  DropdownMenuItem(value: t, child: Text(t)))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _typSelected = v ?? _typSelected),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _status,
                          decoration:
                              const InputDecoration(labelText: 'Status'),
                          items: const [
                            DropdownMenuItem(value: 'NOWE', child: Text('NOWE')),
                            DropdownMenuItem(
                                value: 'W TOKU', child: Text('W TOKU')),
                            DropdownMenuItem(
                                value: 'WERYFIKACJA', child: Text('WERYFIKACJA')),
                            DropdownMenuItem(
                                value: 'ZAMKNIĘTE', child: Text('ZAMKNIĘTE')),
                          ],
                          onChanged: (v) =>
                              setState(() => _status = v ?? 'NOWE'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _opisCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Opis'),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.add),
                      onPressed: _add,
                      label: const Text('Dodaj'),
                    ),
                  )
                ],
              ),
            ),
          ),
          AppCard(
            title: 'Lista zgłoszeń',
            action: Text('${data.length} rekordów',
                style: Theme.of(context).textTheme.bodySmall),
            child: DataTablePro(
              columns: [
                DataColumn(
                  label: const Text('ID'),
                  numeric: true,
                  onSort: (i, asc) => _onSort(i, asc),
                ),
                DataColumn(
                  label: const Text('Czas'),
                  onSort: (i, asc) => _onSort(i, asc),
                ),
                DataColumn(
                  label: const Text('Typ'),
                  onSort: (i, asc) => _onSort(i, asc),
                ),
                DataColumn(
                  label: const Text('Zgłaszający'),
                  onSort: (i, asc) => _onSort(i, asc),
                ),
                DataColumn(
                  label: const Text('Status'),
                  onSort: (i, asc) => _onSort(i, asc),
                ),
                const DataColumn(label: Text('Opis')),
                const DataColumn(label: Text('Akcje')),
              ],
              rows: data.map((z) {
                return DataRow(
                  cells: [
                    DataCell(Text(z.id.toString())),
                    DataCell(Text(_dtf.format(z.dataGodzina))),
                    DataCell(Text(z.typ)),
                    DataCell(Text('${z.imie} ${z.nazwisko}')),
                    DataCell(StatusChip(status: z.status, useGradient: true)),
                    DataCell(SizedBox(
                      width: 240,
                      child: Tooltip(
                        message: z.opis,
                        child: Text(
                          z.opis,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Edytuj',
                            icon: const Icon(Icons.edit, size: 20),
                            onPressed: () => _editDialog(z),
                          ),
                          IconButton(
                            tooltip: 'Usuń',
                            icon: const Icon(Icons.delete, size: 20),
                            onPressed: () => _delete(z),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
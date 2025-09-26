import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/app_providers.dart';
import '../../core/models/raport.dart';
import '../../widgets/status_chip.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../widgets/dialogs.dart';
import '../../core/models/maszyna.dart';
import '../../core/models/osoba.dart';

class RaportyListScreen extends ConsumerStatefulWidget {
  const RaportyListScreen({super.key});

  @override
  ConsumerState<RaportyListScreen> createState() => _RaportyListScreenState();
}

class _RaportyListScreenState extends ConsumerState<RaportyListScreen> {
  String _query = '';
  int _sortColumnIndex = 0;
  bool _sortAsc = true;

  List<Raport> _apply(List<Raport> source) {
    var list = source.where((r) {
      final q = _query.toLowerCase();
      return r.typNaprawy.toLowerCase().contains(q) ||
          (r.maszyna?.nazwa.toLowerCase().contains(q) ?? false) ||
          r.status.toLowerCase().contains(q);
    }).toList();

    list.sort((a, b) {
      int cmp;
      switch (_sortColumnIndex) {
        case 0:
          cmp = (a.maszyna?.nazwa ?? '').compareTo(b.maszyna?.nazwa ?? '');
          break;
        case 1:
          cmp = a.typNaprawy.compareTo(b.typNaprawy);
          break;
        case 2:
          cmp = a.status.compareTo(b.status);
          break;
        case 3:
          cmp = a.dataNaprawy.compareTo(b.dataNaprawy);
          break;
        default:
          cmp = a.id.compareTo(b.id);
      }
      return _sortAsc ? cmp : -cmp;
    });
    return list;
  }

  Future<void> _openAddRaportDialog() async {
    final repo = ref.read(mockRepoProvider);
    final maszyny = repo.getMaszyny();
    final osoby = repo.getOsoby();

    Maszyna? _maszyna;
    Osoba? _osoba;
    final _typCtrl = TextEditingController();
    final _opisCtrl = TextEditingController();
    String _status = 'NOWY';
    DateTime? _data;
    TimeOfDay? _od;
    TimeOfDay? _do;

    String? _validateTimes() {
      if (_od == null || _do == null || _data == null) return null;
      final start = DateTime(_data!.year, _data!.month, _data!.day, _od!.hour, _od!.minute);
      final end = DateTime(_data!.year, _data!.month, _data!.day, _do!.hour, _do!.minute);
      if (end.isBefore(start)) return 'Czas "Do" nie może być wcześniejszy niż "Od"';
      return null;
    }

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Nowy raport'),
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<Maszyna>(
                    value: _maszyna,
                    decoration: const InputDecoration(
                      labelText: 'Maszyna',
                      border: OutlineInputBorder(),
                    ),
                    items: maszyny.map((m) => DropdownMenuItem(value: m, child: Text(m.nazwa))).toList(),
                    onChanged: (v) => setLocal(() => _maszyna = v),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<Osoba>(
                    value: _osoba,
                    decoration: const InputDecoration(
                      labelText: 'Osoba (opcjonalne)',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<Osoba>(value: null, child: Text('Brak')),
                      ...osoby.map((o) => DropdownMenuItem(value: o, child: Text(o.imieNazwisko))).toList(),
                    ],
                    onChanged: (v) => setLocal(() => _osoba = v),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _typCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Typ naprawy',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _opisCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Opis',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _status,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'NOWY', child: Text('NOWY')),
                      DropdownMenuItem(value: 'W TOKU', child: Text('W TOKU')),
                      DropdownMenuItem(value: 'OCZEKUJE', child: Text('OCZEKUJE')),
                      DropdownMenuItem(value: 'ZAKOŃCZONY', child: Text('ZAKOŃCZONY')),
                    ],
                    onChanged: (v) => setLocal(() => _status = v ?? _status),
                  ),
                  const SizedBox(height: 16),
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
                                context: ctx,
                                initialDate: _data ?? now,
                                firstDate: DateTime(now.year - 1),
                                lastDate: DateTime(now.year + 1),
                              );
                              if (picked != null) setLocal(() => _data = picked);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_month_outlined),
                                  const SizedBox(width: 8),
                                  Text(_data == null
                                      ? 'Wybierz datę'
                                      : '${_data!.year}-${_data!.month.toString().padLeft(2, '0')}-${_data!.day.toString().padLeft(2, '0')}'),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Czas od',
                            border: OutlineInputBorder(),
                          ),
                          child: InkWell(
                            onTap: () async {
                              final picked = await showTimePicker(
                                context: ctx,
                                initialTime: _od ?? TimeOfDay.now(),
                              );
                              if (picked != null) setLocal(() => _od = picked);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Row(
                                children: [
                                  const Icon(Icons.schedule_outlined),
                                  const SizedBox(width: 8),
                                  Text(_od == null ? 'Wybierz' : _od!.format(ctx)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Czas do',
                            border: OutlineInputBorder(),
                          ),
                          child: InkWell(
                            onTap: () async {
                              final picked = await showTimePicker(
                                context: ctx,
                                initialTime: _do ?? TimeOfDay.now(),
                              );
                              if (picked != null) setLocal(() => _do = picked);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Row(
                                children: [
                                  const Icon(Icons.schedule),
                                  const SizedBox(width: 8),
                                  Text(_do == null ? 'Wybierz' : _do!.format(ctx)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_validateTimes() != null) ...[
                    const SizedBox(height: 8),
                    Text(_validateTimes()!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                  ],
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
              onPressed: () {
                final err = _validateTimes();
                if (err != null) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                  return;
                }
                if (_maszyna == null || _data == null || _od == null || _do == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Wybierz maszynę, datę i godziny')),
                  );
                  return;
                }
                if (_typCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Podaj typ naprawy')),
                  );
                  return;
                }
                final start = DateTime(_data!.year, _data!.month, _data!.day, _od!.hour, _od!.minute);
                final end = DateTime(_data!.year, _data!.month, _data!.day, _do!.hour, _do!.minute);
                final r = Raport(
                  id: 0,
                  maszyna: _maszyna!,
                  typNaprawy: _typCtrl.text.trim(),
                  opis: _opisCtrl.text.trim(),
                  osoba: _osoba,
                  status: _status,
                  dataNaprawy: _data!,
                  czasOd: start,
                  czasDo: end,
                  partUsages: const [],
                );
                repo.upsertRaport(r);
                Navigator.of(ctx).pop(true);
              },
              child: const Text('Dodaj'),
            ),
          ],
        ),
      ),
    );

    if (ok == true && mounted) {
      setState(() {});
      await showSuccessDialog(context, 'OK', 'Raport dodany');
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(mockRepoProvider);
    final raporty = _apply(repo.getRaporty());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Raporty'),
        leading: IconButton(
          tooltip: 'Dashboard',
          icon: const Icon(Icons.home),
          onPressed: () => context.go('/dashboard'),
        ),
        actions: [
          IconButton(
            tooltip: 'Dodaj raport',
            icon: const Icon(Icons.add),
            onPressed: _openAddRaportDialog,
          )
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Szukaj (maszyna / typ / status)',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Card(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTableTheme(
                      data: const DataTableThemeData(
                        headingRowHeight: 36,
                        dataRowMinHeight: 30,
                        dataRowMaxHeight: 34,
                        horizontalMargin: 12,
                      ),
                      child: DataTable(
                        sortColumnIndex: _sortColumnIndex,
                        sortAscending: _sortAsc,
                        columns: [
                          DataColumn(
                            label: const Text('Maszyna'),
                            onSort: (i, asc) => setState(() {
                              _sortColumnIndex = i;
                              _sortAsc = asc;
                            }),
                          ),
                          DataColumn(
                            label: const Text('Typ'),
                            onSort: (i, asc) => setState(() {
                              _sortColumnIndex = i;
                              _sortAsc = asc;
                            }),
                          ),
                          DataColumn(
                            label: const Text('Status'),
                            onSort: (i, asc) => setState(() {
                              _sortColumnIndex = i;
                              _sortAsc = asc;
                            }),
                          ),
                          DataColumn(
                            numeric: true,
                            label: const Text('Data'),
                            onSort: (i, asc) => setState(() {
                              _sortColumnIndex = i;
                              _sortAsc = asc;
                            }),
                          ),
                          const DataColumn(label: Text('Akcje')),
                        ],
                        rows: raporty.map((r) {
                          return DataRow(
                            cells: [
                              DataCell(Text(r.maszyna?.nazwa ?? '-')),
                              DataCell(Text(r.typNaprawy)),
                              DataCell(StatusChip(status: r.status)),
                              DataCell(Text(
                                  '${r.dataNaprawy.year}-${r.dataNaprawy.month.toString().padLeft(2, '0')}-${r.dataNaprawy.day.toString().padLeft(2, '0')}')),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: 'Edytuj',
                                      icon: const Icon(Icons.edit, color: Colors.blueAccent),
                                      onPressed: () => context.go('/raport/edytuj/${r.id}'),
                                    ),
                                    IconButton(
                                      tooltip: 'Usuń',
                                      icon: const Icon(Icons.delete, color: Colors.redAccent),
                                      onPressed: () async {
                                        final confirm = await showConfirmDialog(
                                          context,
                                          'Usuń raport',
                                          'Czy na pewno usunąć?'
                                        );
                                        if (confirm == true) {
                                          repo.deleteRaport(r.id);
                                          setState(() {});
                                          if (mounted) {
                                            showSuccessDialog(context, 'OK', 'Raport usunięty');
                                          }
                                        }
                                      },
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
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddRaportDialog,
        icon: const Icon(FontAwesomeIcons.plus),
        label: const Text('Nowy'),
      ),
    );
  }
}
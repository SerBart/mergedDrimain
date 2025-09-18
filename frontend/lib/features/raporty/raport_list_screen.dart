import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/app_providers.dart';
import '../../core/models/raport.dart';
import '../../widgets/status_chip.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../widgets/dialogs.dart';

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

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(mockRepoProvider);
    final raporty = _apply(repo.getRaporty());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Raporty'),
        actions: [
          IconButton(
            tooltip: 'Dodaj raport',
            icon: const Icon(Icons.add),
            onPressed: () => context.go('/raport/nowy'),
          )
        ],
      ),
      body: Column(
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
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
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
                                  'Czy na pewno usunąć?',
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
          const SizedBox(height: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/raport/nowy'),
        icon: const Icon(FontAwesomeIcons.plus),
        label: const Text('Nowy'),
      ),
    );
  }
}
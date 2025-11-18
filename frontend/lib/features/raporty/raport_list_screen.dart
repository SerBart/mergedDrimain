import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/top_app_bar.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../core/providers/app_providers.dart';
import '../../core/models/raport.dart';
import '../../widgets/status_chip.dart';
import '../../widgets/dialogs.dart';
import '../../core/models/maszyna.dart';
import '../../core/models/osoba.dart';
import '../../widgets/centered_scroll_card.dart';

class RaportyListScreen extends ConsumerStatefulWidget {
  const RaportyListScreen({super.key});

  @override
  ConsumerState<RaportyListScreen> createState() => _RaportyListScreenState();
}

class _RaportyListScreenState extends ConsumerState<RaportyListScreen> {
  String _query = '';
  int _sortColumnIndex = 0;
  bool _sortAsc = true;
  bool _busy = false;

  static const List<String> _typyNapraw = ['Awaria', 'Usterka', 'Przebudowa'];

  @override
  void initState() {
    super.initState();
    // Po starcie dociągnij metadane (maszyny i osoby), aby mock miał aktualne dane z backendu
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _syncMetaFromApi();
      await _loadFromApi();
      if (mounted) setState(() {});
    });
  }

  Future<void> _syncMetaFromApi() async {
    try {
      final meta = ref.read(metaApiRepositoryProvider);
      final fetchedMaszyny = await meta.fetchMaszynySimple();
      final fetchedOsoby = await meta.fetchOsobySimple();
      final mock = ref.read(mockRepoProvider);
      mock.maszyny
        ..clear()
        ..addAll(fetchedMaszyny);
      mock.osoby
        ..clear()
        ..addAll(fetchedOsoby);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nie udało się pobrać listy maszyn/osób: $e')),
      );
    }
  }

  Future<void> _loadFromApi() async {
    setState(() => _busy = true);
    try {
      final api = ref.read(raportyApiRepositoryProvider);
      final items = await api.fetchAll();
      final mock = ref.read(mockRepoProvider);
      mock.raporty
        ..clear()
        ..addAll(items);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd pobierania raportów: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

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
      appBar: const TopAppBar(title: 'Raporty', showBack: true),
      body: AbsorbPointer(
        absorbing: _busy,
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
              child: CenteredScrollableCard(
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
                        onSort: (i, asc) => setState(() { _sortColumnIndex = i; _sortAsc = asc; }),
                      ),
                      DataColumn(
                        label: const Text('Typ'),
                        onSort: (i, asc) => setState(() { _sortColumnIndex = i; _sortAsc = asc; }),
                      ),
                      DataColumn(
                        label: const Text('Status'),
                        onSort: (i, asc) => setState(() { _sortColumnIndex = i; _sortAsc = asc; }),
                      ),
                      DataColumn(
                        numeric: true,
                        label: const Text('Data'),
                        onSort: (i, asc) => setState(() { _sortColumnIndex = i; _sortAsc = asc; }),
                      ),
                      const DataColumn(label: Text('Akcje')),
                    ],
                    rows: raporty.map((r) {
                      return DataRow(
                        cells: [
                          DataCell(Text(r.maszyna?.nazwa ?? '-')),
                          DataCell(Text(r.typNaprawy)),
                          DataCell(StatusChip(status: r.status)),
                          DataCell(Text('${r.dataNaprawy.year}-${r.dataNaprawy.month.toString().padLeft(2, '0')}-${r.dataNaprawy.day.toString().padLeft(2, '0')}')),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Edytuj',
                                  icon: const Icon(Icons.edit, color: Colors.blueAccent),
                                  onPressed: () => context.go('/raport/edytuj/${r.id}')
                                ),
                                IconButton(
                                  tooltip: 'Usuń',
                                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                                  onPressed: _busy ? null : () async {
                                    final confirm = await showConfirmDialog(
                                      context,
                                      'Usuń raport',
                                      'Czy na pewno usunąć?'
                                    );
                                    if (confirm == true) {
                                      setState(() => _busy = true);
                                      try {
                                        await ref.read(raportyApiRepositoryProvider).delete(r.id);
                                        ref.read(mockRepoProvider).deleteRaport(r.id);
                                        setState(() {});
                                        if (mounted) {
                                          showSuccessDialog(context, 'OK', 'Raport usunięty');
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
            const SizedBox(height: 8),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : () => context.go('/raport/nowy'),
        icon: const Icon(FontAwesomeIcons.plus),
        label: const Text('Nowy'),
      ),
    );
  }
}

import 'dart:convert';
import 'package:flutter/services.dart';
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
import 'raport_form_screen.dart';
import '../../core/constants/naprawy_constants.dart';

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
  static const List<String> _typyNapraw = NaprawyConstants.typyNapraw;
  final Set<int> _expandedOpis = <int>{};
  // NOWE: paginacja
  int _page = 0;
  int _pageSize = 25;
  static const List<int> _pageSizes = [10, 25, 50, 100];

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
      if (q.isEmpty) return true;
      return r.typNaprawy.toLowerCase().contains(q) ||
          (r.maszyna?.nazwa.toLowerCase().contains(q) ?? false) ||
          r.status.toLowerCase().contains(q) ||
          (r.osoba?.imieNazwisko.toLowerCase().contains(q) ?? false) ||
          (r.maszyna?.dzial?.nazwa.toLowerCase().contains(q) ?? false) ||
          r.opis.toLowerCase().contains(q);
    }).toList();
    // Korekta strony jeśli poza zakresem po filtracji
    final totalPages = (list.length / _pageSize).ceil();
    if (_page >= totalPages && totalPages > 0) {
      _page = totalPages - 1;
    }

    list.sort((a, b) {
      int cmp;
      switch (_sortColumnIndex) {
        case 0: cmp = (a.maszyna?.nazwa ?? '').compareTo(b.maszyna?.nazwa ?? ''); break; // Maszyna
        case 1: cmp = a.typNaprawy.compareTo(b.typNaprawy); break; // Typ
        case 2: cmp = a.status.compareTo(b.status); break; // Status
        case 3: cmp = a.dataNaprawy.compareTo(b.dataNaprawy); break; // Data
        case 4: cmp = (a.osoba?.imieNazwisko ?? '').compareTo(b.osoba?.imieNazwisko ?? ''); break; // Osoba
        case 5: cmp = (a.maszyna?.dzial?.nazwa ?? '').compareTo(b.maszyna?.dzial?.nazwa ?? ''); break; // Dzial
        case 6: cmp = a.opis.compareTo(b.opis); break; // Opis
        default: cmp = a.id.compareTo(b.id);
      }
      return _sortAsc ? cmp : -cmp;
    });
    return list;
  }

  // NOWE: pobranie wycinka stronowego
  List<Raport> _pageSlice(List<Raport> all) {
    final start = _page * _pageSize;
    final end = (start + _pageSize) > all.length ? all.length : (start + _pageSize);
    if (start >= all.length) return [];
    return all.sublist(start, end);
  }

  // NOWE: eksport CSV aktualnie filtrowanych danych (pełna lista, nie tylko bieżąca strona)
  void _exportCsv(List<Raport> all) async {
    final header = ['ID','Maszyna','Dzial','Typ','Status','Data','CzasOd','CzasDo','Osoba','Opis'];
    final rows = all.map((r) => [
      r.id.toString(),
      r.maszyna?.nazwa ?? '',
      r.maszyna?.dzial?.nazwa ?? '',
      r.typNaprawy,
      r.status,
      '${r.dataNaprawy.year}-${r.dataNaprawy.month.toString().padLeft(2,'0')}-${r.dataNaprawy.day.toString().padLeft(2,'0')}',
      '${r.czasOd.hour.toString().padLeft(2,'0')}:${r.czasOd.minute.toString().padLeft(2,'0')}',
      '${r.czasDo.hour.toString().padLeft(2,'0')}:${r.czasDo.minute.toString().padLeft(2,'0')}',
      r.osoba?.imieNazwisko ?? '',
      r.opis.replaceAll('\n',' ').replaceAll('\r',' '),
    ]).toList();
    final csv = StringBuffer();
    csv.writeln(header.join(';'));
    for (final row in rows) {
      csv.writeln(row.map(_escapeCsv).join(';'));
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eksport CSV'),
        content: SingleChildScrollView(child: SelectableText(csv.toString())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Zamknij')),
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: csv.toString()));
              if (mounted) Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CSV skopiowany do schowka')));
            },
            child: const Text('Kopiuj do schowka'),
          ),
        ],
      ),
    );
  }

  String _escapeCsv(String v) {
    final needsQuotes = v.contains(';') || v.contains('"') || v.contains('\n');
    var out = v.replaceAll('"','""');
    if (needsQuotes) out = '"$out"';
    return out;
  }

  // NOWE: kolory wierszy wg statusu
  Color _rowColor(String status) {
    switch (status.toUpperCase()) {
      case 'NOWY': return Colors.yellow.shade50;
      case 'W TOKU': return Colors.lightBlue.shade50;
      case 'OCZEKUJE': return Colors.orange.shade50;
      case 'ZAKOŃCZONY': return Colors.green.shade50;
      default: return Colors.grey.shade50;
    }
  }

  void _showPhoto(Raport r) {
    if (r.photoBase64 == null || r.photoBase64!.isEmpty) return;
    try {
      final bytes = base64Decode(r.photoBase64!);
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Zdjęcie raportu #${r.id}'),
          content: InteractiveViewer(child: Image.memory(bytes, fit: BoxFit.contain)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Zamknij')),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Nie można wyświetlić zdjęcia: $e')));
    }
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 90, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _showRaportDetails(Raport r) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Raport #${r.id}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailRow('Maszyna', r.maszyna?.nazwa ?? '-'),
              _detailRow('Dział', r.maszyna?.dzial?.nazwa ?? '-'),
              _detailRow('Typ', r.typNaprawy),
              _detailRow('Status', r.status),
              _detailRow('Data', '${r.dataNaprawy.year}-${r.dataNaprawy.month.toString().padLeft(2, '0')}-${r.dataNaprawy.day.toString().padLeft(2, '0')}'),
              _detailRow('Od', '${r.czasOd.hour.toString().padLeft(2,'0')}:${r.czasOd.minute.toString().padLeft(2,'0')}'),
              _detailRow('Do', '${r.czasDo.hour.toString().padLeft(2,'0')}:${r.czasDo.minute.toString().padLeft(2,'0')}'),
              _detailRow('Osoba', r.osoba?.imieNazwisko ?? '-'),
              const SizedBox(height: 12),
              Text('Opis:', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 4),
              Text(r.opis.isEmpty ? '(brak)' : r.opis),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Zamknij')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.go('/raport/edytuj/${r.id}');
            },
            child: const Text('Edytuj'),
          ),
        ],
      ),
    );
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: const InputDecoration(
                            labelText: 'Szukaj (maszyna / typ / status / osoba / dział / opis)',
                            prefixIcon: Icon(Icons.search),
                          ),
                          onChanged: (v) => setState(() => _query = v),
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.download),
                        label: const Text('Eksport CSV'),
                        onPressed: _busy ? null : () {
                          final repoAll = _apply(ref.read(mockRepoProvider).getRaporty());
                          _exportCsv(repoAll);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('Rozmiar strony:'),
                      const SizedBox(width: 8),
                      DropdownButton<int>(
                        value: _pageSize,
                        items: _pageSizes.map((s) => DropdownMenuItem(value: s, child: Text(s.toString()))).toList(),
                        onChanged: (v) => setState(() { if (v != null) { _pageSize = v; _page = 0; } }),
                      ),
                      const SizedBox(width: 24),
                      _PageControls(
                        page: _page,
                        totalItems: _apply(ref.read(mockRepoProvider).getRaporty()).length,
                        pageSize: _pageSize,
                        onPageChanged: (p) => setState(() => _page = p),
                      ),
                    ],
                  ),
                ],
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
                      DataColumn(label: const Text('Maszyna'), onSort: (i, asc) => setState(() { _sortColumnIndex = i; _sortAsc = asc; })),
                      DataColumn(label: const Text('Typ'), onSort: (i, asc) => setState(() { _sortColumnIndex = i; _sortAsc = asc; })),
                      DataColumn(label: const Text('Status'), onSort: (i, asc) => setState(() { _sortColumnIndex = i; _sortAsc = asc; })),
                      DataColumn(numeric: true, label: const Text('Data'), onSort: (i, asc) => setState(() { _sortColumnIndex = i; _sortAsc = asc; })),
                      DataColumn(label: const Text('Osoba'), onSort: (i, asc) => setState(() { _sortColumnIndex = i; _sortAsc = asc; })),
                      DataColumn(label: const Text('Dział'), onSort: (i, asc) => setState(() { _sortColumnIndex = i; _sortAsc = asc; })),
                      DataColumn(label: const Text('Opis'), onSort: (i, asc) => setState(() { _sortColumnIndex = i; _sortAsc = asc; })),
                      const DataColumn(label: Text('Foto')),
                      const DataColumn(label: Text('Akcje')),
                    ],
                    rows: _pageSlice(raporty).map((r) {
                      final isExpanded = _expandedOpis.contains(r.id);
                      final short = r.opis.length <= 15 ? r.opis : r.opis.substring(0, 15) + '…';
                      return DataRow(
                        color: MaterialStateProperty.resolveWith((_) => _rowColor(r.status)),
                        cells: [
                          DataCell(Text(r.maszyna?.nazwa ?? '-')),
                          DataCell(Text(r.typNaprawy)),
                          DataCell(StatusChip(status: r.status)),
                          DataCell(Text('${r.dataNaprawy.year}-${r.dataNaprawy.month.toString().padLeft(2, '0')}-${r.dataNaprawy.day.toString().padLeft(2, '0')}')),
                          DataCell(Text(r.osoba?.imieNazwisko ?? '-')),
                          DataCell(Text(r.maszyna?.dzial?.nazwa ?? '-')),
                          DataCell(
                            InkWell(
                              onTap: () => setState(() {
                                if (isExpanded) {
                                  _expandedOpis.remove(r.id);
                                } else {
                                  _expandedOpis.add(r.id);
                                }
                              }),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 160),
                                child: Tooltip(
                                  message: r.opis.isEmpty ? '(brak)' : r.opis,
                                  child: Text((r.opis.isEmpty ? '(brak)' : (isExpanded ? r.opis : short)), overflow: TextOverflow.fade),
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            IconButton(
                              tooltip: r.photoBase64 != null && r.photoBase64!.isNotEmpty ? 'Podgląd zdjęcia' : 'Brak zdjęcia',
                              icon: Icon(Icons.image, color: (r.photoBase64 != null && r.photoBase64!.isNotEmpty) ? Colors.teal : Colors.grey),
                              onPressed: (r.photoBase64 != null && r.photoBase64!.isNotEmpty) ? () => _showPhoto(r) : null,
                            ),
                          ),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Podgląd',
                                  icon: const Icon(Icons.visibility, color: Colors.deepPurple),
                                  onPressed: () => _showRaportDetails(r),
                                ),
                                IconButton(
                                  tooltip: 'Edytuj',
                                  icon: const Icon(Icons.edit, color: Colors.blueAccent),
                                  onPressed: () => context.go('/raport/edytuj/${r.id}')
                                ),
                                IconButton(
                                  tooltip: 'Usuń',
                                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                                  onPressed: _busy ? null : () async {
                                    final confirm = await showConfirmDialog(context, 'Usuń raport', 'Czy na pewno usunąć?');
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
                                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Błąd usuwania: $e')));
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
        onPressed: _busy
            ? null
            : () async {
                final ok = await showDialog<bool>(
                  context: context,
                  barrierDismissible: false,
                  builder: (ctx) => Dialog(
                    insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: RaportFormScreen(
                      embedInDialog: true,
                      onSaved: (r) {
                        // Raport formularz już robi upsert do mockRepo
                      },
                    ),
                  ),
                );
                if (ok == true && mounted) {
                  await _loadFromApi();
                  await showSuccessDialog(context, 'OK', 'Raport dodany');
                  setState(() {});
                }
              },
        icon: const Icon(FontAwesomeIcons.plus),
        label: const Text('Nowy'),
      ),
    );
  }
}

// NOWE: widget kontroli stron
class _PageControls extends StatelessWidget {
  final int page;
  final int totalItems;
  final int pageSize;
  final ValueChanged<int> onPageChanged;
  const _PageControls({required this.page, required this.totalItems, required this.pageSize, required this.onPageChanged});
  @override
  Widget build(BuildContext context) {
    final totalPages = (totalItems / pageSize).ceil();
    return Row(
      children: [
        Text('Strona ${totalPages == 0 ? 0 : page + 1}/$totalPages'),
        IconButton(
          icon: const Icon(Icons.first_page),
          onPressed: page > 0 ? () => onPageChanged(0) : null,
        ),
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: page > 0 ? () => onPageChanged(page - 1) : null,
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: (page + 1) < totalPages ? () => onPageChanged(page + 1) : null,
        ),
        IconButton(
          icon: const Icon(Icons.last_page),
          onPressed: (page + 1) < totalPages ? () => onPageChanged(totalPages - 1) : null,
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/providers/app_providers.dart';
import '../../core/models/instruction.dart';
import '../../widgets/centered_scroll_card.dart';
import '../../widgets/top_app_bar.dart';

class InstrukcjeListScreen extends ConsumerStatefulWidget {
  const InstrukcjeListScreen({super.key});
  @override
  ConsumerState<InstrukcjeListScreen> createState() => _InstrukcjeListScreenState();
}

class _InstrukcjeListScreenState extends ConsumerState<InstrukcjeListScreen> {
  bool _loading = false;
  List<InstructionModel> _items = [];

  // sort state for parts table (shared across tiles)
  int _partsSortColumn = 0; // 0: nazwa, 1: ilosc
  bool _partsSortAsc = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(instructionsApiRepositoryProvider);
      final list = await repo.list();
      setState(() => _items = list);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd pobierania instrukcji: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openAdd() async {
    await context.push('/instrukcje/nowa');
    await _load();
  }

  Future<void> _openAttachment(String path) async {
    final api = ref.read(apiClientProvider);
    final url = Uri.parse('${api.dio.options.baseUrl}$path');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nie udało się otworzyć pliku.')),
        );
      }
    }
  }

  Future<void> _confirmDelete(int id, String title) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Usuń instrukcję'),
        content: Text('Czy na pewno chcesz usunąć instrukcję "$title"? Tego nie można cofnąć.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Anuluj')),
          FilledButton.tonal(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Usuń')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(instructionsApiRepositoryProvider).deleteInstruction(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Usunięto instrukcję.')),
        );
      }
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd usuwania: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(authStateProvider.select((u) => u?.role == 'ADMIN'));
    return Scaffold(
      appBar: TopAppBar(
        title: 'Instrukcje napraw',
        showBack: true,
        extraActions: [
          IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh, color: Colors.white)),
          if (isAdmin == true)
            IconButton(onPressed: _loading ? null : _openAdd, icon: const Icon(Icons.add, color: Colors.white)),
        ],
      ),
      body: _loading && _items.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: ListView.builder(
                    itemCount: _items.length,
                    itemBuilder: (_, i) {
                      final it = _items[i];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: ExpansionTile(
                          title: Text(it.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(it.maszynaNazwa ?? '-', maxLines: 1, overflow: TextOverflow.ellipsis),
                          children: [
                            if ((it.description ?? '').isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                child: Text(it.description!),
                              ),
                            const SizedBox(height: 6),
                            FutureBuilder<InstructionModel>(
                              future: ref.read(instructionsApiRepositoryProvider).getById(it.id),
                              builder: (ctx, snap) {
                                final data = snap.data;
                                if (snap.connectionState != ConnectionState.done) {
                                  return const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: LinearProgressIndicator(minHeight: 2),
                                  );
                                }
                                if (data == null) {
                                  return const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: Text('Nie udało się załadować szczegółów'),
                                  );
                                }
                                final parts = [...data.parts];
                                // apply sort for parts
                                parts.sort((a, b) {
                                  int cmp;
                                  switch (_partsSortColumn) {
                                    case 0:
                                      cmp = a.partNazwa.compareTo(b.partNazwa);
                                      break;
                                    case 1:
                                      cmp = (a.ilosc ?? 0).compareTo(b.ilosc ?? 0);
                                      break;
                                    default:
                                      cmp = a.partNazwa.compareTo(b.partNazwa);
                                  }
                                  return _partsSortAsc ? cmp : -cmp;
                                });

                                final attachments = data.attachments;
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                      child: Text('Części zamienne:', style: TextStyle(fontWeight: FontWeight.w600)),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      child: CenteredScrollableCard(
                                        child: parts.isEmpty
                                            ? const Padding(
                                                padding: EdgeInsets.all(12),
                                                child: Text('Brak części'),
                                              )
                                            : DataTableTheme(
                                                data: const DataTableThemeData(
                                                  headingRowHeight: 36,
                                                  dataRowMinHeight: 30,
                                                  dataRowMaxHeight: 34,
                                                  horizontalMargin: 12,
                                                ),
                                                child: DataTable(
                                                  sortColumnIndex: _partsSortColumn,
                                                  sortAscending: _partsSortAsc,
                                                  columns: [
                                                    DataColumn(
                                                      label: const Text('Nazwa'),
                                                      onSort: (i, asc) => setState(() {
                                                        _partsSortColumn = i;
                                                        _partsSortAsc = asc;
                                                      }),
                                                    ),
                                                    DataColumn(
                                                      numeric: true,
                                                      label: const Text('Ilość'),
                                                      onSort: (i, asc) => setState(() {
                                                        _partsSortColumn = i;
                                                        _partsSortAsc = asc;
                                                      }),
                                                    ),
                                                  ],
                                                  rows: parts.map((p) => DataRow(cells: [
                                                    DataCell(Text(p.partNazwa)),
                                                    DataCell(Text((p.ilosc ?? 0).toString())),
                                                  ])).toList(),
                                                ),
                                              ),
                                      ),
                                    ),

                                    const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                      child: Text('Pliki:', style: TextStyle(fontWeight: FontWeight.w600)),
                                    ),
                                    if (attachments.isEmpty)
                                      const Padding(
                                        padding: EdgeInsets.all(12),
                                        child: Text('Brak załączników'),
                                      )
                                    else
                                      ...attachments.map((a) => ListTile(
                                            leading: Icon(a.contentType.contains('pdf') ? Icons.picture_as_pdf : Icons.image_outlined, color: Colors.blueGrey),
                                            title: Text(a.originalFilename, maxLines: 1, overflow: TextOverflow.ellipsis),
                                            trailing: const Icon(Icons.open_in_new),
                                            onTap: () => _openAttachment('/api/instrukcje/attachments/${a.id}/download'),
                                          )),
                                  ],
                                );
                              },
                            ),
                            if (isAdmin == true) ...[
                              const SizedBox(height: 4),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton.icon(
                                      onPressed: () => _confirmDelete(it.id, it.title),
                                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                      label: const Text('Usuń', style: TextStyle(color: Colors.redAccent)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
      floatingActionButton: (isAdmin == true)
          ? FloatingActionButton.extended(
              onPressed: _openAdd,
              icon: const Icon(Icons.add),
              label: const Text('Dodaj instrukcję'),
            )
          : null,
    );
  }
}

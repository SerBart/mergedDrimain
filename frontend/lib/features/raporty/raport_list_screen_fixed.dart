import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_roles.dart';
import '../../core/models/raport.dart';
import '../../core/providers/app_providers.dart';
import '../../widgets/top_app_bar.dart';
import 'raport_form_screen.dart';

class RaportyListScreen extends ConsumerStatefulWidget {
  const RaportyListScreen({super.key, this.editRaportId});

  final int? editRaportId;

  @override
  ConsumerState<RaportyListScreen> createState() => _RaportyListScreenState();
}

class _RaportyListScreenState extends ConsumerState<RaportyListScreen> {
  bool _busy = false;
  bool _editDialogAttempted = false;
  String _query = '';
  int _sortCol = 0;
  bool _asc = false;
  String _statusFilter = 'WSZYSTKIE';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _syncMetaFromApi();
      await _loadFromApi();
      if (mounted && !_editDialogAttempted && widget.editRaportId != null) {
        _editDialogAttempted = true;
        await _openEditDialog(widget.editRaportId!);
      }
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
    } catch (_) {
      // Brak metadanych nie powinien blokować ekranu.
    }
  }

  Future<void> _loadFromApi() async {
    if (!mounted) return;
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

  List<Raport> _filtered(List<Raport> source) {
    final q = _query.trim().toLowerCase();
    final statusFilterUpper = _statusFilter.toUpperCase();

    final list = source.where((r) {
      final statusUpper = r.status.toUpperCase();
      final normalizedStatus = statusUpper
          .replaceAll('Ą', 'A')
          .replaceAll('Ć', 'C')
          .replaceAll('Ę', 'E')
          .replaceAll('Ł', 'L')
          .replaceAll('Ń', 'N')
          .replaceAll('Ó', 'O')
          .replaceAll('Ś', 'S')
          .replaceAll('Ź', 'Z')
          .replaceAll('Ż', 'Z');

      final byStatus = statusFilterUpper == 'WSZYSTKIE' ||
          statusUpper == statusFilterUpper ||
          normalizedStatus == statusFilterUpper;

      if (!byStatus) return false;
      if (q.isEmpty) return true;

      return r.typNaprawy.toLowerCase().contains(q) ||
          r.opis.toLowerCase().contains(q) ||
          r.status.toLowerCase().contains(q) ||
          (r.maszyna?.nazwa.toLowerCase().contains(q) ?? false) ||
          (r.maszyna?.dzial?.nazwa.toLowerCase().contains(q) ?? false) ||
          (r.osoba?.imieNazwisko.toLowerCase().contains(q) ?? false);
    }).toList();

    list.sort((a, b) {
      int cmp;
      switch (_sortCol) {
        case 0:
          cmp = a.dataNaprawy.compareTo(b.dataNaprawy);
          break;
        case 1:
          cmp = (a.maszyna?.nazwa ?? '').compareTo(b.maszyna?.nazwa ?? '');
          break;
        case 2:
          cmp = a.typNaprawy.compareTo(b.typNaprawy);
          break;
        case 3:
          cmp = a.status.compareTo(b.status);
          break;
        case 4:
          cmp = (a.osoba?.imieNazwisko ?? '').compareTo(b.osoba?.imieNazwisko ?? '');
          break;
        case 5:
          cmp = a.zdjecia.length.compareTo(b.zdjecia.length);
          break;
        default:
          cmp = a.opis.compareTo(b.opis);
      }
      return _asc ? cmp : -cmp;
    });
    return list;
  }

  Future<void> _openNewDialog() async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const RaportFormScreen(embedInDialog: true),
      ),
    );
    if (ok == true) {
      await _loadFromApi();
    }
  }

  Future<void> _openEditDialog(int id) async {
    final mock = ref.read(mockRepoProvider);
    var raport = mock.getRaportById(id);
    raport ??= await _fetchRaportById(id);

    if (raport == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nie znaleziono raportu ID $id')),
      );
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: RaportFormScreen(existing: raport, embedInDialog: true),
      ),
    );

    if (ok == true) {
      await _loadFromApi();
    }
  }

  Future<Raport?> _fetchRaportById(int id) async {
    try {
      final api = ref.read(raportyApiRepositoryProvider);
      final full = await api.fetchById(id);
      ref.read(mockRepoProvider).upsertRaport(full);
      return full;
    } catch (_) {
      return null;
    }
  }

  Future<void> _deleteRaport(Raport r) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Usuń raport'),
        content: Text('Czy na pewno usunąć raport #${r.id}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Anuluj')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Usuń')),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _busy = true);
    try {
      await ref.read(raportyApiRepositoryProvider).delete(r.id);
      await _loadFromApi();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Błąd usuwania raportu: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<Raport> _ensureRaportWithPhotos(Raport raport) async {
    if (raport.zdjecia.isNotEmpty) return raport;
    final full = await _fetchRaportById(raport.id);
    return full ?? raport;
  }

  bool _isPdfUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains('.pdf') || lower.contains('application/pdf');
  }

  String _attachmentName(String url) {
    final uri = Uri.tryParse(url);
    if (uri != null && uri.pathSegments.isNotEmpty) {
      return Uri.decodeComponent(uri.pathSegments.last);
    }
    return url.replaceAll('\\', '/').split('/').last;
  }

  Future<void> _openAttachmentExternal(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nieprawidłowy adres pliku.')),
      );
      return;
    }

    final ok = await launchUrl(uri, mode: LaunchMode.platformDefault);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nie udało się otworzyć pliku.')),
      );
    }
  }

  Future<void> _deleteAttachment(Raport r, String url) async {
    setState(() => _busy = true);
    try {
      await ref.read(raportyApiRepositoryProvider).deleteZdjecie(r.id, url);
      await _loadFromApi();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usunięto załącznik.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Błąd usuwania załącznika: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showSingleAttachment(Raport r, String url) async {
    if (_isPdfUrl(url)) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Plik PDF'),
          content: Text(_attachmentName(url)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Zamknij')),
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _openAttachmentExternal(url);
              },
              child: const Text('Otwórz PDF'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _deleteAttachment(r, url);
              },
              child: const Text('Usuń', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_attachmentName(url)),
        content: const Text('Podgląd obrazów jest dostępny w aplikacji zewnętrznej. Otwórz plik, aby zobaczyć obraz.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Zamknij')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _openAttachmentExternal(url);
            },
            child: const Text('Otwórz'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _deleteAttachment(r, url);
            },
            child: const Text('Usuń', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _showAttachments(Raport r) async {
    Raport raport;
    try {
      raport = await _ensureRaportWithPhotos(r);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nie udało się pobrać załączników: $e')),
      );
      return;
    }

    if (!mounted) return;
    if (raport.zdjecia.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ten raport nie ma jeszcze załączników.')),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Załączniki (${raport.zdjecia.length})'),
        content: SizedBox(
          width: 620,
          height: 420,
          child: ListView.builder(
            itemCount: raport.zdjecia.length,
            itemBuilder: (context, index) {
              final url = raport.zdjecia[index];
              final isPdf = _isPdfUrl(url);
              return ListTile(
                leading: Icon(isPdf ? Icons.picture_as_pdf : Icons.image, color: isPdf ? Colors.red : Colors.teal),
                title: Text(_attachmentName(url), maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: Wrap(
                  spacing: 4,
                  children: [
                    IconButton(
                      tooltip: isPdf ? 'Otwórz PDF' : 'Podgląd',
                      icon: Icon(isPdf ? Icons.open_in_new : Icons.visibility),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showSingleAttachment(raport, url);
                      },
                    ),
                    IconButton(
                      tooltip: 'Usuń',
                      icon: const Icon(Icons.delete, color: Colors.redAccent),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _deleteAttachment(raport, url);
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Zamknij')),
        ],
      ),
    );
  }

  Future<void> _uploadZdjecia(Raport r) async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(imageQuality: 85);
    if (picked.isEmpty) return;

    setState(() => _busy = true);
    try {
      await ref.read(raportyApiRepositoryProvider).uploadZdjecia(r.id, picked);
      await _loadFromApi();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dodano ${picked.length} zdjęć.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Błąd przesyłania zdjęć: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _uploadPdf(Raport r) async {
    final picked = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return;

    final files = picked.files.where((f) => f.bytes != null && f.bytes!.isNotEmpty).toList();
    if (files.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nie udało się odczytać wybranych PDF.')),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      await ref.read(raportyApiRepositoryProvider).uploadPdfFiles(r.id, files);
      await _loadFromApi();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dodano ${files.length} plik(i) PDF.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Błąd przesyłania PDF: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _machineLabel(Raport r) {
    final name = r.maszyna?.nazwa ?? '-';
    final dep = r.maszyna?.dzial?.nazwa;
    if (dep == null || dep.isEmpty) return name;
    return '$name ($dep)';
  }

  String _fmtDate(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'NOWY':
        return Colors.indigo;
      case 'W TOKU':
        return Colors.orange;
      case 'OCZEKUJE':
        return Colors.purple;
      case 'ZAKOŃCZONY':
      case 'ZAKONCZONY':
        return Colors.green;
      default:
        return Colors.blueGrey;
    }
  }

  void _onSort(int columnIndex, bool ascending) {
    setState(() {
      _sortCol = columnIndex;
      _asc = ascending;
    });
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(mockRepoProvider);
    final all = _filtered(repo.getRaporty());
    final isAdmin = ref.watch(authStateProvider)?.role == AppRoles.admin;

    return Scaffold(
      appBar: const TopAppBar(title: 'Raporty', showBack: true),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : _openNewDialog,
        icon: const Icon(Icons.add),
        label: const Text('Nowy raport'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                labelText: 'Szukaj (maszyna, status, osoba, opis...)',
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Wrap(
              spacing: 8,
              children: [
                for (final s in const ['WSZYSTKIE', 'NOWY', 'W TOKU', 'OCZEKUJE', 'ZAKONCZONY'])
                  ChoiceChip(
                    label: Text(s == 'WSZYSTKIE' ? 'Wszystkie' : s),
                    selected: _statusFilter == s,
                    onSelected: (_) => setState(() => _statusFilter = s),
                  ),
              ],
            ),
          ),
          if (_busy) const LinearProgressIndicator(minHeight: 3),
          const Divider(height: 1),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadFromApi,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(12),
                children: [
                  if (all.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Brak raportów do wyświetlenia.'),
                      ),
                    )
                  else
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        sortColumnIndex: _sortCol,
                        sortAscending: _asc,
                        columns: [
                          DataColumn(label: const Text('Data'), onSort: _onSort),
                          DataColumn(label: const Text('Maszyna'), onSort: _onSort),
                          DataColumn(label: const Text('Typ'), onSort: _onSort),
                          DataColumn(label: const Text('Status'), onSort: _onSort),
                          DataColumn(label: const Text('Osoba'), onSort: _onSort),
                          DataColumn(label: const Text('Załączniki'), onSort: _onSort),
                          DataColumn(label: const Text('Opis'), onSort: _onSort),
                          const DataColumn(label: Text('Akcje')),
                        ],
                        rows: all.map((r) {
                          final statusColor = _statusColor(r.status);
                          return DataRow(
                            cells: [
                              DataCell(Text(_fmtDate(r.dataNaprawy))),
                              DataCell(Text(_machineLabel(r))),
                              DataCell(Text(r.typNaprawy)),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    r.status,
                                    style: TextStyle(color: statusColor, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ),
                              DataCell(Text(r.osoba?.imieNazwisko ?? '-')),
                              DataCell(Text('${r.zdjecia.length}')),
                              DataCell(
                                SizedBox(
                                  width: 280,
                                  child: Text(
                                    r.opis.isEmpty ? '(brak opisu)' : r.opis,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: 'Załączniki (${r.zdjecia.length})',
                                      icon: Icon(
                                        Icons.attach_file,
                                        color: r.zdjecia.isNotEmpty ? Colors.teal : Colors.orange,
                                      ),
                                      onPressed: () => _showAttachments(r),
                                    ),
                                    IconButton(
                                      tooltip: 'Dodaj zdjęcia',
                                      icon: const Icon(Icons.add_a_photo, color: Colors.teal),
                                      onPressed: () => _uploadZdjecia(r),
                                    ),
                                    IconButton(
                                      tooltip: 'Dodaj PDF',
                                      icon: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
                                      onPressed: () => _uploadPdf(r),
                                    ),
                                    IconButton(
                                      tooltip: 'Edytuj',
                                      icon: const Icon(Icons.edit_outlined),
                                      onPressed: () => _openEditDialog(r.id),
                                    ),
                                    if (isAdmin)
                                      IconButton(
                                        tooltip: 'Usuń raport',
                                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                        onPressed: () => _deleteRaport(r),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  const SizedBox(height: 70),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/providers/app_providers.dart';
import '../../core/models/zgloszenie.dart';
import '../../widgets/top_app_bar.dart';

class MojeZgloszeniaScreen extends ConsumerStatefulWidget {
  final bool showTasksInitially;

  const MojeZgloszeniaScreen({
    super.key,
    this.showTasksInitially = false,
  });

  @override
  ConsumerState<MojeZgloszeniaScreen> createState() =>
      _MojeZgloszeniaScreenState();
}

class _MojeZgloszeniaScreenState extends ConsumerState<MojeZgloszeniaScreen> {
  bool _showTasks = false;
  // Filtrowanie
  final _search = TextEditingController();
  String _query = '';
  String _statusFilter = 'WSZYSTKIE';

  // Sortowanie
  int _sortCol = 0; // 0: Data, 1: Typ, 2: Status, 3: Maszyna
  bool _sortAsc = false;

  // Stan ładowania
  bool _loading = false;
  String? _error;
  List<Zgloszenie> _zgloszenia = [];

  static const statusy = ['WSZYSTKIE', 'NOWE', 'W TOKU', 'WERYFIKACJA', 'ZAMKNIĘTE'];
  static const types = ['WSZYSTKIE', 'Usterka', 'Awaria', 'Przezbrojenie', 'Modernizacja'];
  final _dtf = DateFormat('yyyy-MM-dd HH:mm');

  @override
  void initState() {
    super.initState();
    _showTasks = widget.showTasksInitially;
    _loadData();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final repo = ref.read(zgloszeniaApiRepositoryProvider);
      final data = _showTasks
          ? await repo.fetchMojeZadania(
              status: _statusFilter != 'WSZYSTKIE' ? _statusFilter : null,
              query: _query.isNotEmpty ? _query : null,
            )
          : await repo.fetchMoje(
              status: _statusFilter != 'WSZYSTKIE' ? _statusFilter : null,
              query: _query.isNotEmpty ? _query : null,
            );

      if (!mounted) return;
      setState(() {
        _zgloszenia = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _applyFilters() {
    _loadData();
  }

  void _sort(int col) {
    setState(() {
      if (_sortCol == col) {
        _sortAsc = !_sortAsc;
      } else {
        _sortCol = col;
        _sortAsc = true;
      }
    });
  }

  List<Zgloszenie> _getSortedData() {
    List<Zgloszenie> sorted = [..._zgloszenia];

    switch (_sortCol) {
      case 0: // Data
        sorted.sort((a, b) =>
            a.dataGodzina.compareTo(b.dataGodzina));
        break;
      case 1: // Typ
        sorted.sort((a, b) => a.typ.compareTo(b.typ));
        break;
      case 2: // Status
        sorted.sort((a, b) => a.status.compareTo(b.status));
        break;
      case 3: // Maszyna
        sorted.sort((a, b) =>
            (a.maszyna?.nazwa ?? '').compareTo(b.maszyna?.nazwa ?? ''));
        break;
    }

    if (!_sortAsc) sorted = sorted.reversed.toList();
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sorted = _getSortedData();
    final width = MediaQuery.of(context).size.width;
    final compact = width < 720;

    return Scaffold(
      appBar: TopAppBar(
        title: _showTasks ? 'Moje Zadania' : 'Moje Zgłoszenia',
        showBack: true,
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: Column(
          children: [
            // Filtry
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1120),
                  child: Container(
                    padding: EdgeInsets.all(compact ? 12 : 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.78),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: scheme.primary.withOpacity(.08)),
                      boxShadow: [
                        BoxShadow(
                          color: scheme.primary.withOpacity(.06),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Align(
                          alignment: compact ? Alignment.centerLeft : Alignment.center,
                          child: SegmentedButton<bool>(
                            showSelectedIcon: false,
                            segments: const [
                              ButtonSegment<bool>(
                                value: false,
                                icon: Icon(Icons.person_outline),
                                label: Text('Moje zgłoszenia'),
                              ),
                              ButtonSegment<bool>(
                                value: true,
                                icon: Icon(Icons.assignment_turned_in_outlined),
                                label: Text('Moje zadania'),
                              ),
                            ],
                            selected: {_showTasks},
                            onSelectionChanged: (value) {
                              final selectedTasks = value.first;
                              if (selectedTasks == _showTasks) return;
                              setState(() => _showTasks = selectedTasks);
                              _loadData();
                            },
                          ),
                        ),
                        SizedBox(height: compact ? 12 : 14),
                        if (compact) ...[
                          TextField(
                            controller: _search,
                            onChanged: (v) {
                              setState(() => _query = v);
                              _applyFilters();
                            },
                            decoration: InputDecoration(
                              hintText: 'Szukaj po temacie, opisie, typie...',
                              prefixIcon: const Icon(Icons.search),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            value: _statusFilter,
                            decoration: InputDecoration(
                              labelText: 'Status',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            items: statusy
                                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                                .toList(),
                            onChanged: (v) {
                              setState(() => _statusFilter = v ?? 'WSZYSTKIE');
                              _applyFilters();
                            },
                          ),
                        ] else
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _search,
                                  onChanged: (v) {
                                    setState(() => _query = v);
                                    _applyFilters();
                                  },
                                  decoration: InputDecoration(
                                    hintText: 'Szukaj po temacie, opisie, typie...',
                                    prefixIcon: const Icon(Icons.search),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 240,
                                child: DropdownButtonFormField<String>(
                                  value: _statusFilter,
                                  decoration: InputDecoration(
                                    labelText: 'Status',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  ),
                                  items: statusy
                                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                                      .toList(),
                                  onChanged: (v) {
                                    setState(() => _statusFilter = v ?? 'WSZYSTKIE');
                                    _applyFilters();
                                  },
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Dane
            Expanded(
              child: _loading && _zgloszenia.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Błąd: $_error',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.red)),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _loadData,
                                child: const Text('Spróbuj ponownie'),
                              ),
                            ],
                          ),
                        )
                      : sorted.isEmpty
                          ? Center(
                              child: Text(
                                _showTasks ? 'Brak zadań do obsługi' : 'Brak zgłoszeń',
                              ),
                            )
                          : _buildTable(sorted, scheme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTable(List<Zgloszenie> data, ColorScheme scheme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final minWidth = constraints.maxWidth < 1320 ? 1320.0 : constraints.maxWidth;

        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1400),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.76),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: scheme.primary.withOpacity(.08)),
                  boxShadow: [
                    BoxShadow(
                      color: scheme.primary.withOpacity(.05),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                        decoration: BoxDecoration(
                          color: scheme.primary.withOpacity(.05),
                          border: Border(
                            bottom: BorderSide(color: scheme.primary.withOpacity(.08)),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _showTasks ? 'Lista moich zadań' : 'Lista moich zgłoszeń',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFF111827),
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Kliknij wiersz, aby zobaczyć szczegóły. Łącznie: ${data.length} wpisów.',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: const Color(0xFF6B7280),
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: scheme.primary.withOpacity(.10),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '${data.length}',
                                style: TextStyle(
                                  color: scheme.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Scrollbar(
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(12),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(minWidth: minWidth),
                              child: DataTable(
                                sortColumnIndex: _sortCol,
                                sortAscending: _sortAsc,
                                columnSpacing: 24,
                                headingRowColor: WidgetStatePropertyAll(
                                  scheme.primary.withOpacity(.04),
                                ),
                                dataRowMinHeight: 56,
                                dataRowMaxHeight: 76,
                                columns: [
                                  const DataColumn(
                                    label: Text('Nr'),
                                  ),
                                  DataColumn(
                                    label: const Text('Data'),
                                    onSort: (i, asc) => _sort(0),
                                  ),
                                  DataColumn(
                                    label: const Text('Typ'),
                                    onSort: (i, asc) => _sort(1),
                                  ),
                                  DataColumn(
                                    label: const Text('Status'),
                                    onSort: (i, asc) => _sort(2),
                                  ),
                                  DataColumn(
                                    label: const Text('Maszyna'),
                                    onSort: (i, asc) => _sort(3),
                                  ),
                                  const DataColumn(
                                    label: Text('Nazwa zgłoszenia'),
                                  ),
                                  const DataColumn(
                                    label: Text('Zgłaszający'),
                                  ),
                                  const DataColumn(
                                    label: Text('Opis skrócony'),
                                  ),
                                ],
                                rows: data
                                    .map((z) => DataRow(
                                          onSelectChanged: (_) => _showDetails(z),
                                          cells: [
                                            DataCell(Text('#${z.id}')),
                                            DataCell(Text(_dtf.format(z.dataGodzina))),
                                            DataCell(Text(z.typ)),
                                            DataCell(_statusChip(z.status, scheme)),
                                            DataCell(
                                              SizedBox(
                                                width: 150,
                                                child: Text(
                                                  z.maszyna?.nazwa ?? '-',
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              SizedBox(
                                                width: 280,
                                                child: Text(
                                                  z.temat.isEmpty ? '-' : z.temat,
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              SizedBox(
                                                width: 150,
                                                child: Text(
                                                  '${z.imie} ${z.nazwisko}'.trim().isEmpty
                                                      ? '-'
                                                      : '${z.imie} ${z.nazwisko}',
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              SizedBox(
                                                width: 320,
                                                child: Text(
                                                  z.opis.isEmpty ? '-' : z.opis,
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(color: Color(0xFF4B5563)),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ))
                                    .toList(),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _statusChip(String status, ColorScheme scheme) {
    final color = _getStatusColor(status);
    return Chip(
      label: Text(status, style: const TextStyle(fontSize: 12, color: Colors.white)),
      backgroundColor: color,
      padding: EdgeInsets.zero,
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'NOWE':
        return Colors.blue;
      case 'W TOKU':
        return Colors.orange;
      case 'WERYFIKACJA':
        return Colors.purple;
      case 'ZAMKNIĘTE':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  void _showDetails(Zgloszenie z) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Zgłoszenie #${z.id}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _detail('Typ', z.typ),
              _detail('Temat', z.temat),
              _detail('Status', z.status),
              _detail('Data', _dtf.format(z.dataGodzina)),
              _detail('Maszyna', z.maszyna?.nazwa ?? '-'),
              _detail('Autor', '${z.imie} ${z.nazwisko}'),
              const SizedBox(height: 12),
              const Text('Opis:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(z.opis),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => ctx.pop(),
            child: const Text('Zamknij'),
          ),
        ],
      ),
    );
  }

  Widget _detail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 80, child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.bold))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}


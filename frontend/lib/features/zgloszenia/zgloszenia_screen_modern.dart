import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/providers/app_providers.dart';
import '../../core/models/zgloszenie.dart';
import '../../core/models/maszyna.dart';
import '../../core/models/dzial.dart';
import '../../widgets/photo_picker_field.dart';
import '../../widgets/centered_scroll_card.dart';

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
  String? _photoBase64;

  // Wartości domyślne
  String _status = 'NOWE';
  String _typSelected = 'Usterka';
  Maszyna? _selectedMaszyna;
  Dzial? _selectedDzial; // New: selected department

  // Wyszukiwanie / filtrowanie / sortowanie
  final _search = TextEditingController();
  String _query = '';
  String _statusFilter = 'WSZYSTKIE';
  final _dtf = DateFormat('yyyy-MM-dd HH:mm');
  int _sortCol = 0; // 0: Data, 1: Start, 2: Koniec, 3: Typ, 4: Status, 5: Osoba
  bool _asc = false;

  bool _busy = false;

  static const types = ['Usterka', 'Awaria', 'Przezbrojenie', 'Modernizacja'];
  static const statusy = ['NOWE', 'W TOKU', 'WERYFIKACJA', 'ZAMKNIĘTE'];
  static const double _dialogWidth = 480; // jednolita szerokość dialogów

  @override
  void initState() {
    super.initState();
    _loadFromApi();
    // Po zbudowaniu kontekstu dociągnij metadane (maszyny/działy) z backendu,
    // żeby dropdown nie korzystał z hardcodów w MockRepository
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _syncMetaFromApi();
    });
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
      // Zachowaj lokalne rozszerzone pola zanim nadpiszemy
      final local = {for (final z in ref.read(mockRepoProvider).getZgloszenia()) z.id: z};
      final items = await apiRepo.fetchAll();

      final mock = ref.read(mockRepoProvider);
      mock.zgloszenia
        ..clear()
        ..addAll(items.map((z) {
          final prev = local[z.id];
          if (prev != null) {
            return z.copyWith(
              photoBase64: prev.photoBase64,
              acceptedAt: prev.acceptedAt,
              completedAt: prev.completedAt,
            );
          }
          return z;
        }));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Błąd pobierania z API: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // NOWE: Synchronizacja list maszyn i działów z backendu (meta API)
  Future<void> _syncMetaFromApi() async {
    try {
      final meta = ref.read(metaApiRepositoryProvider);
      final fetchedMaszyny = await meta.fetchMaszynySimple();
      final fetchedDzialy = await meta.fetchDzialySimple();
      final mock = ref.read(mockRepoProvider);
      mock.maszyny
        ..clear()
        ..addAll(fetchedMaszyny);
      mock.dzialy
        ..clear()
        ..addAll(fetchedDzialy);
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nie udało się pobrać listy maszyn/działów: $e')),
      );
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
        case 0: // Data zgłoszenia
          cmp = a.dataGodzina.compareTo(b.dataGodzina);
          break;
        case 1: // Typ zgłoszenia
          cmp = a.typ.compareTo(b.typ);
          break;
        case 2: // Status
          cmp = a.status.compareTo(b.status);
          break;
        case 3: // Start
          cmp = (a.acceptedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
              .compareTo(b.acceptedAt ?? DateTime.fromMillisecondsSinceEpoch(0));
          break;
        case 4: // Koniec
          cmp = (a.completedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
              .compareTo(b.completedAt ?? DateTime.fromMillisecondsSinceEpoch(0));
          break;
        case 5: // Osoba (nazwisko potem imię)
          cmp = (a.nazwisko + a.imie).compareTo(b.nazwisko + b.imie);
          break;
        default:
          cmp = a.dataGodzina.compareTo(b.dataGodzina);
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
    _photoBase64 = null;
    _selectedMaszyna = null;
    _selectedDzial = null;
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
        dataGodzina: DateTime.now(),
        dzialId: _selectedDzial?.id,
        maszynaId: _selectedMaszyna?.id,
      );

      // Zachowaj zdjęcie lokalnie w mock repo; backend nie obsługuje jeszcze zdjęć w DTO
      ref.read(mockRepoProvider).updateZgloszenie(
            created.copyWith(photoBase64: _photoBase64, maszyna: _selectedMaszyna),
          );

      _resetForm();

      if (mounted) {
        _selectedMaszyna = null;
        Navigator.of(context).maybePop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dodano zgłoszenie')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      String msg = 'Błąd dodawania: $e';
      try {
        final dioResp = (e as dynamic).response;
        final data = dioResp?.data;
        if (data is Map && data['message'] is String) {
          msg = 'Błąd dodawania: ${data['message']}';
        } else if (data is String && data.isNotEmpty) {
          msg = 'Błąd dodawania: $data';
        }
      } catch (_) {}
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _editDialog(Zgloszenie z) {
    if (z.id <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('To zgłoszenie nie jest zapisane na serwerze (brak ID).')),
      );
      return;
    }

    final imie = TextEditingController(text: z.imie);
    final nazw = TextEditingController(text: z.nazwisko);
    final opis = TextEditingController(text: z.opis);
    var typ = z.typ;
    var status = z.status;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        title: Text('Edytuj zgłoszenie #${z.id}'),
        content: StatefulBuilder(
          builder: (context, setLocal) {
            return SizedBox(
              width: _dialogWidth,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: imie,
                            decoration: const InputDecoration(
                              labelText: 'Imię',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: nazw,
                            decoration: const InputDecoration(
                              labelText: 'Nazwisko',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: typ,
                      decoration: const InputDecoration(
                        labelText: 'Typ',
                        border: OutlineInputBorder(),
                      ),
                      items: types
                          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (v) => setLocal(() => typ = v ?? typ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: opis,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Opis',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: status,
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        border: OutlineInputBorder(),
                      ),
                      items: statusy
                          .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                      onChanged: (v) => setLocal(() => status = v ?? status),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Anuluj'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
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
                                    final api = ref.read(zgloszeniaApiRepositoryProvider);
                                    final saved = await api.update(updated);
                                    ref.read(mockRepoProvider).updateZgloszenie(saved);
                                    if (mounted) {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Zapisano zmiany')),
                                      );
                                      await _loadFromApi();
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      String msg = 'Błąd zapisu: $e';
                                      try {
                                        final dioResp = (e as dynamic).response;
                                        final data = dioResp?.data;
                                        if (data is Map && data['message'] is String) {
                                          msg = 'Błąd zapisu: ${data['message']}';
                                        } else if (data is String && data.isNotEmpty) {
                                          msg = 'Błąd zapisu: $data';
                                        }
                                      } catch (_) {}
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(msg)),
                                      );
                                    }
                                  } finally {
                                    if (mounted) setState(() => _busy = false);
                                  }
                                },
                          child: const Text('Zapisz'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _delete(Zgloszenie z) async {
    if (z.id <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('To zgłoszenie nie jest zapisane na serwerze (brak ID).')),
      );
      return;
    }

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
          // Po usunięciu – odśwież z API
          await _loadFromApi();
        }
      } catch (e) {
        if (mounted) {
          String msg = 'Błąd usuwania: $e';
          try {
            final dioResp = (e as dynamic).response;
            final data = dioResp?.data;
            if (data is Map && data['message'] is String) {
              msg = 'Błąd usuwania: ${data['message']}';
            } else if (data is String && data.isNotEmpty) {
              msg = 'Błąd usuwania: $data';
            }
          } catch (_) {}
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg)),
          );
        }
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    }
  }

  Future<void> _startWork(Zgloszenie z) async {
    if (_busy || z.id <= 0) return;
    setState(() => _busy = true);
    try {
      // Tylko jeśli nie jest już zamknięte
      if (z.status == 'ZAMKNIĘTE') return;
      final updated = z.copyWith(status: 'W TOKU');
      final api = ref.read(zgloszeniaApiRepositoryProvider);
      final saved = await api.update(updated);
      // Zachowaj acceptedAt jeśli już było, jeśli nie ustaw teraz
      ref.read(mockRepoProvider).updateZgloszenie(
        saved.copyWith(
          acceptedAt: z.acceptedAt ?? DateTime.now(),
          completedAt: z.completedAt, // bez zmian
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Zgłoszenie rozpoczęte')),);
      }
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd rozpoczęcia: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Color _typeColor(String typ) {
    final v = typ.trim().toUpperCase();
    if (v == 'AWARIA') return Colors.red;
    if (v == 'MODERNIZACJA') return Colors.blue;
    if (v == 'USTERKA') return Colors.purple;
    if (v == 'PRZEZBROJENIE' || v == 'PRZEZBROJENIA') return Colors.orange;
    return Colors.grey;
  }

  Future<void> _setOnHold(Zgloszenie z) async {
    final noteCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Przerwać zgłoszenie?'),
        content: SizedBox(
          width: 460,
          child: TextField(
            controller: noteCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Notatka (opcjonalnie)',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Anuluj')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Przerwij')),
        ],
      ),
    );
    if (ok == true) {
      setState(() => _busy = true);
      try {
        final extra = noteCtrl.text.trim();
        final appended = extra.isEmpty
            ? z.opis
            : (z.opis + '\n\n[Przerwane]\n' + extra);
        final api = ref.read(zgloszeniaApiRepositoryProvider);
        final saved = await api.update(
          z.copyWith(status: 'PRZERWANE', opis: appended),
        );
        ref.read(mockRepoProvider).updateZgloszenie(saved);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Status zmieniony na PRZERWANE')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Błąd zmiany statusu: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    }
  }

  Future<void> _finishWork(Zgloszenie z) async {
    if (_busy || z.id <= 0) return;
    final uszkCtrl = TextEditingController();
    final zrobCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Zakończ naprawę'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: uszkCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Co było uszkodzone?',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: zrobCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Co zostało zrobione?',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Anuluj')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Zakończ')),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busy = true);
    try {
      final now = DateTime.now();
      final extraBlock = [
        if (uszkCtrl.text.trim().isNotEmpty) 'Uszkodzone: ${uszkCtrl.text.trim()}',
        if (zrobCtrl.text.trim().isNotEmpty) 'Wykonano: ${zrobCtrl.text.trim()}',
      ].join('\n');
      final newOpis = extraBlock.isEmpty
          ? z.opis
          : (z.opis + '\n\n[Zakończenie]\n' + extraBlock);

      final api = ref.read(zgloszeniaApiRepositoryProvider);
      final saved = await api.update(
        z.copyWith(
          status: 'ZAMKNIĘTE',
          opis: newOpis,
        ),
      );
      ref.read(mockRepoProvider).updateZgloszenie(
        saved.copyWith(
          acceptedAt: z.acceptedAt ?? now,
          completedAt: now,
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Naprawa zakończona')),
        );
      }
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd zakończenia: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
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

  void _showDetails(Zgloszenie z) {
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final canStart = !_busy && z.status != 'ZAMKNIĘTE' && (z.acceptedAt == null || z.status == 'NOWE');
          final canFinish = !_busy && z.status != 'ZAMKNIĘTE';
          return AlertDialog(
            title: Text('Zgłoszenie #${z.id > 0 ? z.id : '-'}'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _detailRow('Data', _dtf.format(z.dataGodzina)),
                  _detailRow('Start', z.acceptedAt != null ? _dtf.format(z.acceptedAt!) : '-'),
                  _detailRow('Koniec', z.completedAt != null ? _dtf.format(z.completedAt!) : '-'),
                  _detailRow('Typ', z.typ),
                  _detailRow('Status', z.status),
                  if (z.maszyna != null) _detailRow('Maszyna', z.maszyna!.nazwa),
                  if (z.maszyna?.dzial != null) _detailRow('Dział', z.maszyna!.dzial!.nazwa),
                  _detailRow('Osoba', '${z.imie} ${z.nazwisko}'),
                  const SizedBox(height: 12),
                  const Text('Opis:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(z.opis),
                  if (z.photoBase64 != null) ...[
                    const SizedBox(height: 12),
                    const Text('Zdjęcie:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    // Minimalny podgląd (można rozbudować w przyszłości)
                    Text('(Załączone zdjęcie - podgląd w przyszłej wersji)')
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Zamknij'),
              ),
              if (canStart)
                FilledButton(
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    await _startWork(z);
                  },
                  child: const Text('Rozpoczęcie naprawy'),
                ),
              if (canFinish)
                FilledButton.tonal(
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    await _setOnHold(z);
                  },
                  style: FilledButton.styleFrom(foregroundColor: Colors.orange),
                  child: const Text('Przerwane'),
                ),
              if (canFinish)
                FilledButton(
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    await _finishWork(z);
                  },
                  style: FilledButton.styleFrom(backgroundColor: Colors.green),
                  child: const Text('Naprawa zakończona'),
                ),
              FilledButton.tonal(
                onPressed: z.id <= 0 ? null : () {
                  Navigator.of(ctx).pop();
                  _editDialog(z);
                },
                child: const Text('Edytuj'),
              ),
              FilledButton.tonal(
                onPressed: z.id <= 0 ? null : () async {
                  Navigator.of(ctx).pop();
                  await _delete(z);
                },
                style: FilledButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Usuń'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  // Nowy helper: otwiera dialog dodawania zgłoszenia (wydzielone by uniknąć zamieszania w nawiasach)
  void _openAddDialog() {
    final maszyny = ref.read(mockRepoProvider).getMaszyny();
    final dzialy = ref.read(mockRepoProvider).getDzialy();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          title: const Text('Nowe zgłoszenie'),
          content: SizedBox(
            width: _dialogWidth,
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (maszyny.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('Brak maszyn – kliknij Odśwież lub dodaj w Panelu Admina.'),
                      ),
                    DropdownButtonFormField<Maszyna>(
                      value: _selectedMaszyna,
                      decoration: const InputDecoration(
                        labelText: 'Maszyna',
                        border: OutlineInputBorder(),
                      ),
                      items: maszyny
                          .map((m) => DropdownMenuItem(
                                value: m,
                                child: Text('${m.nazwa}${m.dzial != null ? ' (${m.dzial!.nazwa})' : ''}'),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() {
                        _selectedMaszyna = v;
                        // Auto-select department based on machine
                        _selectedDzial = v?.dzial ?? _selectedDzial;
                      }),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<Dzial>(
                      value: _selectedDzial,
                      decoration: const InputDecoration(
                        labelText: 'Dział',
                        border: OutlineInputBorder(),
                      ),
                      items: dzialy
                          .map((d) => DropdownMenuItem(
                                value: d,
                                child: Text(d.nazwa),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedDzial = v),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _imieCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Imię',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) => (v == null || v.isEmpty) ? 'Podaj imię' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _nazCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Nazwisko',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) => (v == null || v.isEmpty) ? 'Podaj nazwisko' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _typSelected,
                      decoration: const InputDecoration(
                        labelText: 'Typ',
                        border: OutlineInputBorder(),
                      ),
                      items: types
                          .map((e) => DropdownMenuItem(
                                value: e,
                                child: Text(e),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _typSelected = v ?? _typSelected),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _opisCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Opis',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        final txt = v?.trim() ?? '';
                        if (txt.isEmpty) return 'Opis jest wymagany';
                        if (txt.length < 10) return 'Opis musi mieć co najmniej 10 znaków';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _status,
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        border: OutlineInputBorder(),
                      ),
                      items: statusy
                          .map((s) => DropdownMenuItem(
                                value: s,
                                child: Text(s),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _status = v ?? _status),
                    ),
                    const SizedBox(height: 12),
                    PhotoPickerField(
                      label: 'Zdjęcie (opcjonalne)',
                      initialBase64: _photoBase64,
                      onChanged: (b64) => _photoBase64 = b64,
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            onPressed: () { Navigator.of(context).pop(); },
                            child: const Text('Anuluj'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: _busy ? null : _add,
                            child: const Text('Dodaj'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ), // <-- poprawne zamknięcie SizedBox zamiast ;
        ); // <-- zamknięcie AlertDialog
      },
    ); // <-- zamknięcie showDialog
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(mockRepoProvider);
    final data = _filtered(repo.getZgloszenia());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Zgłoszenia'),
        leading: IconButton(
          tooltip: 'Dashboard',
          icon: const Icon(Icons.home),
          onPressed: () => context.go('/dashboard'),
        ),
        actions: [
          IconButton(
            tooltip: 'Odśwież z API',
            icon: const Icon(Icons.refresh),
            onPressed: _busy ? null : () async {
              await _syncMetaFromApi();
              await _loadFromApi();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : _openAddDialog,
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
                  child: LayoutBuilder(
                    builder: (ctx, constraints) {
                      final rowCount = data.length;
                      const headerHeight = 56.0; // DataTable heading approx
                      const dataRowHeight = 56.0; // default row height
                      final desiredHeight = headerHeight + (rowCount * dataRowHeight) + 32; // + padding
                      final maxHeight = constraints.maxHeight;
                      final double targetHeight = desiredHeight.clamp(220.0, maxHeight); // ensure double
                      final needsVerticalScroll = desiredHeight > maxHeight;

                      Widget table = DataTable(
                        sortColumnIndex: _sortCol,
                        sortAscending: _asc,
                        columns: [
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
                          DataColumn(
                            label: const Text('Start'),
                            onSort: (i, asc) => _onSort(i, asc),
                          ),
                          DataColumn(
                            label: const Text('Koniec'),
                            onSort: (i, asc) => _onSort(i, asc),
                          ),
                          DataColumn(
                            label: const Text('Osoba'),
                            onSort: (i, asc) => _onSort(i, asc),
                          ),
                        ],
                        rows: data.map((z) {
                          String fmt(DateTime? d) => d == null ? '-' : _dtf.format(d);
                          final typeColor = _typeColor(z.typ);
                          return DataRow(
                            onSelectChanged: (_) => _showDetails(z),
                            cells: [
                              DataCell(Text(_dtf.format(z.dataGodzina))), // Data
                              DataCell(
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: typeColor.withOpacity(.12),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: typeColor.withOpacity(.5)),
                                    ),
                                    child: Text(
                                      z.typ,
                                      style: TextStyle(color: typeColor, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ),
                              ), // Typ (colored)
                              DataCell(_statusChip(z.status)),             // Status
                              DataCell(Text(fmt(z.acceptedAt))),           // Start
                              DataCell(Text(fmt(z.completedAt))),          // Koniec
                              DataCell(Text('${z.imie} ${z.nazwisko}')),   // Osoba
                            ],
                          );
                        }).toList(),
                      );

                      return Align(
                        alignment: Alignment.topCenter,
                        child: SizedBox(
                          height: targetHeight,
                          child: Center(
                            child: CenteredScrollableCard(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              child: needsVerticalScroll ? SingleChildScrollView(child: table) : table,
                            ),
                          ),
                        ),
                      );
                    },
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

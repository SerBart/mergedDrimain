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
import '../../widgets/top_app_bar.dart';

class ZgloszeniaScreenModern extends ConsumerStatefulWidget {
  final int? selectedZgloszenieId; // Nowy parametr dla powiadomień

  const ZgloszeniaScreenModern({
    super.key,
    this.selectedZgloszenieId,
  });

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
  final _tematCtrl = TextEditingController();
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
  int _sortCol = 0; // 0: Data, 1: Typ, 2: Status, 3: Maszyna, 4: Dział, 5: Temat, 6: Osoba
  bool _asc = false;

  bool _busy = false;

  static const types = ['Usterka', 'Awaria', 'Przezbrojenie', 'Modernizacja'];
  static const statusy = ['NOWE', 'W TOKU', 'WERYFIKACJA', 'ZAMKNIĘTE'];
  static const double _dialogWidth = 480; // jednolita szerokość dialogów

  // Nowe: zmienne do obsługi dynamicznego ładowania maszyn dla działu
  bool _loadingDzialy = false;
  bool _loadingMaszyny = false;
  String? _metaError;
  String? _maszynyError;
  List<Dzial> _dzialyLoaded = [];
  String _maszynaSearchText = '';

  @override
  void initState() {

      // NOWE: Jeśli mamy selectedZgloszenieId z powiadomienia, pokaż szczegóły
      if (widget.selectedZgloszenieId != null && widget.selectedZgloszenieId! > 0) {
        Future.delayed(const Duration(milliseconds: 500), () {
          final zgloszenie = ref.read(mockRepoProvider).getZgloszenia()
              .firstWhere(
                (z) => z.id == widget.selectedZgloszenieId,
                orElse: () => null as dynamic,
              );
          if (zgloszenie != null && mounted) {
            _showDetails(zgloszenie);
          }
        });
      }
    super.initState();
    _loadFromApi();
    // Po zbudowaniu kontekstu dociągnij metadane (maszyny/działy) z backendu
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _syncMetaFromApi();
    });
  }

  @override
  void dispose() {
    _imieCtrl.dispose();
    _nazCtrl.dispose();
    _tematCtrl.dispose();
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
        case 3: // Maszyna (nazwa)
          cmp = (a.maszyna?.nazwa ?? '').compareTo(b.maszyna?.nazwa ?? '');
          break;
        case 4: // Dział (nazwa działu powiązanego z maszyną)
          cmp = (a.maszyna?.dzial?.nazwa ?? '').compareTo(b.maszyna?.dzial?.nazwa ?? '');
          break;
        case 5: // Temat
          cmp = a.temat.compareTo(b.temat);
          break;
        case 6: // Osoba (nazwisko potem imię)
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
        temat: _tematCtrl.text.trim(),
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
    final temat = TextEditingController(text: z.temat);
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
                      controller: temat,
                      decoration: const InputDecoration(
                        labelText: 'Temat',
                        border: OutlineInputBorder(),
                      ),
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
                                      temat: temat.text.trim(),
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
    final dzialy = ref.read(mockRepoProvider).getDzialy();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            // Pobierz aktualne maszyny
            final maszyny = ref.read(mockRepoProvider).getMaszyny();
            // Filtruj maszyny dla wybranego działu
            final maszynyDlaDzialu = _selectedDzial != null
                ? maszyny.where((m) => m.dzial?.id == _selectedDzial!.id).toList()
                : <Maszyna>[];

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
                          onChanged: (v) async {
                            setLocalState(() {
                              _selectedDzial = v;
                              _selectedMaszyna = null;
                              _maszynaSearchText = '';
                              _loadingMaszyny = true;
                            });
                            if (v != null) {
                              await _fetchMaszynyForDzial();
                              setLocalState(() {
                                _loadingMaszyny = false;
                              });
                            }
                          },
                        ),
                        // ROZSZERZONA DIAGNOSTYKA + SPINNER
                        Padding(
                          padding: const EdgeInsets.only(top: 6.0, bottom: 12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AnimatedOpacity(
                                opacity: _selectedDzial != null ? 1 : 0.5,
                                duration: const Duration(milliseconds: 200),
                                child: Row(
                                  children: [
                                    if (_loadingMaszyny)
                                      const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                    Expanded(
                                      child: Text(
                                        _maszynyError != null
                                            ? _maszynyError!
                                            : _selectedDzial == null
                                                ? 'Wybierz dział aby pobrać maszyny.'
                                                : 'Maszyny dostępne.',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: _maszynyError != null
                                              ? Colors.redAccent
                                              : Colors.grey.shade600,
                                        ),
                                      ),
                                    ),
                                    if (_selectedDzial != null)
                                      IconButton(
                                        tooltip: 'Odśwież maszyny dla działu',
                                        icon: const Icon(Icons.settings_backup_restore, size: 18),
                                        onPressed: _loadingMaszyny
                                            ? null
                                            : () async {
                                                await _fetchMaszynyForDzial();
                                                setLocalState(() {});
                                              },
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Autocomplete dla maszyn (dynamiczne ładowanie)
                        FormField<void>(
                          validator: (_) => _selectedMaszyna == null ? 'Wybierz maszynę' : null,
                          builder: (state) => Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Maszyna',
                                style: Theme.of(context).inputDecorationTheme.labelStyle ??
                                    const TextStyle(fontSize: 12, color: Colors.black54),
                              ),
                              const SizedBox(height: 8),
                              Autocomplete<Maszyna>(
                                key: ValueKey(_selectedDzial?.id),
                                displayStringForOption: (o) => o.nazwa,
                                initialValue: TextEditingValue(text: _maszynaSearchText),
                                optionsBuilder: (TextEditingValue tev) {
                                  if (_selectedDzial == null || _loadingMaszyny) {
                                    return const Iterable<Maszyna>.empty();
                                  }
                                  final q = tev.text.trim().toLowerCase();
                                  final all = ref.read(mockRepoProvider).getMaszyny();
                                  if (q.isEmpty) return all;
                                  return all.where((m) => m.nazwa.toLowerCase().contains(q));
                                },
                                onSelected: (Maszyna sel) {
                                  setState(() {
                                    _selectedMaszyna = sel;
                                    _maszynaSearchText = sel.nazwa;
                                  });
                                },
                                fieldViewBuilder: (ctx, textCtrl, focusNode, onFieldSubmitted) {
                                  return TextField(
                                    controller: textCtrl,
                                    focusNode: focusNode,
                                    enabled: _selectedDzial != null && !_loadingMaszyny,
                                    decoration: InputDecoration(
                                      hintText: _selectedDzial == null
                                          ? 'Najpierw wybierz dział'
                                          : 'Wpisz literę lub rozwiń listę',
                                      prefixIcon: const Icon(Icons.search),
                                      suffixIcon: IconButton(
                                        tooltip: 'Pokaż pełną listę',
                                        icon: const Icon(Icons.arrow_drop_down),
                                        onPressed: _selectedDzial != null && !_loadingMaszyny
                                            ? () {
                                                focusNode.requestFocus();
                                                textCtrl.text = textCtrl.text + ' ';
                                                textCtrl.text = textCtrl.text.trimRight();
                                              }
                                            : null,
                                      ),
                                    ),
                                    onChanged: (v) => setState(() {
                                      _maszynaSearchText = v;
                                      if (_selectedMaszyna != null && _selectedMaszyna!.nazwa != v) {
                                        _selectedMaszyna = null;
                                      }
                                    }),
                                    onSubmitted: (_) => onFieldSubmitted(),
                                  );
                                },
                                optionsViewBuilder: (ctx, onSelected, options) {
                                  return Align(
                                    alignment: Alignment.topLeft,
                                    child: Material(
                                      elevation: 4,
                                      borderRadius: BorderRadius.circular(8),
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(maxHeight: 300),
                                        child: ListView.builder(
                                          padding: EdgeInsets.zero,
                                          shrinkWrap: true,
                                          itemCount: options.length,
                                          itemBuilder: (ctx, i) {
                                            final m = options.elementAt(i);
                                            return ListTile(
                                              dense: true,
                                              title: Text(m.nazwa),
                                              onTap: () => onSelected(m),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              if (state.hasError)
                                const SizedBox(height: 6),
                              if (state.hasError)
                                Text(state.errorText!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                            ],
                          ),
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
                          onChanged: (v) => setLocalState(() => _typSelected = v ?? _typSelected),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _tematCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Temat',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => (v == null || v.isEmpty) ? 'Podaj temat' : null,
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
                          onChanged: (v) => setLocalState(() => _status = v ?? _status),
                        ),
                        const SizedBox(height: 12),
                        PhotoPickerField(
                          label: 'Zdjęcie (opcjonalne)',
                          initialBase64: _photoBase64,
                          onChanged: (b64) => setLocalState(() => _photoBase64 = b64),
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
              ),
              actions: [
                TextButton(
                  onPressed: () { Navigator.of(context).pop(); },
                  child: const Text('Anuluj'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _fetchMaszynyForDzial() async {
    if (_selectedDzial == null) return;
    setState(() {
      _loadingMaszyny = true;
      _maszynyError = null;
    });
    try {
      final meta = ref.read(metaApiRepositoryProvider);
      final fetchedMaszyny = await meta.fetchMaszynySimple(dzialId: _selectedDzial!.id);
      final mock = ref.read(mockRepoProvider);
      mock.maszyny
        ..clear()
        ..addAll(fetchedMaszyny);
      // Jeżeli obecnie wybrana maszyna nie należy do nowego zestawu – wyczyść
      if (_selectedMaszyna != null && !fetchedMaszyny.any((m) => m.id == _selectedMaszyna!.id)) {
        _selectedMaszyna = null;
        _maszynaSearchText = '';
      }
      setState(() {
        _loadingMaszyny = false;
      });
    } catch (e) {
      _maszynyError = 'Błąd maszyn dla działu: $e';
      if (mounted) {
        setState(() {
          _loadingMaszyny = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Nie udało się pobrać maszyn dla działu: $e')),
        );
      }
    }
  }

  List<Maszyna> _filteredMaszyny(List<Maszyna> all) {
    final q = _maszynaSearchText.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all.where((m) => m.nazwa.toLowerCase().contains(q)).toList();
  }

  void _onSelectDzial(Dzial? dz) async {
    setState(() {
      _selectedDzial = dz;
      _selectedMaszyna = null; // reset maszyny przy zmianie działu
      _maszynaSearchText = '';
    });
    if (dz != null) {
      await _fetchMaszynyForDzial();
    } else {
      // brak działu => wyczyść listę maszyn lokalnie
      final mock = ref.read(mockRepoProvider);
      mock.maszyny.clear();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(mockRepoProvider);
    final data = _filtered(repo.getZgloszenia());

    return Scaffold(
      appBar: const TopAppBar(title: 'Zgłoszenia', showBack: true),
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

                      final isMobile = MediaQuery.of(context).size.width < 720;

                      Widget table;
                      if (isMobile) {
                        // Mobile: pokaż listę kart (bardziej czytelne na małych ekranach)
                        table = ListView.separated(
                          shrinkWrap: true,
                          physics: needsVerticalScroll ? const AlwaysScrollableScrollPhysics() : const NeverScrollableScrollPhysics(),
                          itemCount: data.length,
                          itemBuilder: (ctx, idx) {
                            final z = data[idx];
                            final typeColor = _typeColor(z.typ);
                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              child: InkWell(
                                onTap: () => _showDetails(z),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(child: Text(_dtf.format(z.dataGodzina), style: const TextStyle(fontWeight: FontWeight.w600))),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: typeColor.withOpacity(.12),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(color: typeColor.withOpacity(.5)),
                                            ),
                                            child: Text(z.typ, style: TextStyle(color: typeColor, fontWeight: FontWeight.w600)),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      _statusChip(z.status),
                                      const SizedBox(height: 8),
                                      Text('Maszyna: ${z.maszyna?.nazwa ?? '-'}'),
                                      Text('Dział: ${z.maszyna?.dzial?.nazwa ?? '-'}'),
                                      const SizedBox(height: 6),
                                      Text('Osoba: ${z.imie} ${z.nazwisko}'),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                          separatorBuilder: (_, __) => const SizedBox(height: 4),
                        );
                      } else {
                        // Desktop/tablet: zachowaj DataTable
                        table = DataTable(
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
                              label: const Text('Maszyna'),
                              onSort: (i, asc) => _onSort(i, asc),
                            ),
                            DataColumn(
                              label: const Text('Dział'),
                              onSort: (i, asc) => _onSort(i, asc),
                            ),
                            DataColumn(
                              label: const Text('Temat'),
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
                                DataCell(Text(z.maszyna?.nazwa ?? '-')),     // Maszyna
                                DataCell(Text(z.maszyna?.dzial?.nazwa ?? '-')), // Dział
                                DataCell(Text(z.temat)),                     // Temat
                                DataCell(Text('${z.imie} ${z.nazwisko}')),   // Osoba
                              ],
                            );
                          }).toList(),
                        );
                      }

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

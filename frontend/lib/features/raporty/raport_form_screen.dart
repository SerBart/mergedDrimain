import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/top_app_bar.dart';

import '../../core/models/maszyna.dart';
import '../../core/models/osoba.dart';
import '../../core/models/raport.dart';
import '../../core/models/dzial.dart'; // nowy import
import '../../core/providers/app_providers.dart';
import '../../core/repositories/meta_api_repository.dart';
import '../../widgets/photo_picker_field.dart';

/// Formularz tworzenia / edycji raportu.
/// Możesz wejść tu:
/// 1) z istniejącym obiektem Raport (param existing)
/// 2) tylko z raportId (załaduje z repo)
/// 3) pusty – tworzenie nowego
class RaportFormScreen extends ConsumerStatefulWidget {
  final Raport? existing;
  final int? raportId;

  const RaportFormScreen({
    super.key,
    this.existing,
    this.raportId,
  });

  @override
  ConsumerState<RaportFormScreen> createState() => _RaportFormScreenState();
}

class _RaportFormScreenState extends ConsumerState<RaportFormScreen> {
  final _formKey = GlobalKey<FormState>();

  // Pola formularza
  Maszyna? _maszyna;
  Osoba? _osoba;
  Dzial? _dzial; // wybrany dział
  final _typNaprawyCtrl = TextEditingController();
  final _opisCtrl = TextEditingController();
  String _status = 'NOWY';
  DateTime? _dataNaprawy;
  TimeOfDay? _czasOd;
  TimeOfDay? _czasDo;
  String? _photoBase64;

  // Załadowany (jeśli edycja przez ID)
  Raport? _loaded;

  final TextEditingController _maszynaSearchCtrl = TextEditingController();
  String _maszynaQuery = '';
  List<Dzial> _dzialyLocal = []; // załadowane działy

  bool get _isEdit => _loaded != null || widget.existing != null;

  @override
  void initState() {
    super.initState();
    _hydrate();
    // Po zbudowaniu kontekstu pobierz meta dane (maszyny, osoby) z API i zsynchronizuj mock repo
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncMetaFromApi();
    });
  }

  Future<void> _syncMetaFromApi() async {
    try {
      final meta = ref.read(metaApiRepositoryProvider);
      final fetchedDzialy = await meta.fetchDzialySimple();
      final mock = ref.read(mockRepoProvider);
      mock.dzialy
        ..clear()
        ..addAll(fetchedDzialy);
      _dzialyLocal = fetchedDzialy;

      // osoby tylko z UR (jak wcześniej) – pozostawiono logikę
      const urName = 'Utrzymanie Ruchu';
      var fetchedOsoby = await meta.fetchOsobySimple(dzialNazwa: urName);
      if (fetchedOsoby.isEmpty) {
        fetchedOsoby = await meta.fetchOsobySimple();
      }
      mock.osoby..clear()..addAll(fetchedOsoby);

      // Jeśli edycja i mamy maszynę z działem, ustaw dział i pobierz maszyny dla niego
      if (_maszyna?.dzial != null && _dzial == null) {
        _dzial = _maszyna!.dzial;
        await _fetchMaszynyForDzial();
      }
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nie udało się pobrać meta danych: $e')),
      );
    }
  }

  Future<void> _fetchMaszynyForDzial() async {
    if (_dzial == null) return;
    try {
      final meta = ref.read(metaApiRepositoryProvider);
      final fetchedMaszyny = await meta.fetchMaszynySimple(dzialId: _dzial!.id);
      final mock = ref.read(mockRepoProvider);
      mock.maszyny
        ..clear()
        ..addAll(fetchedMaszyny);
      // Jeżeli obecnie wybrana maszyna nie należy do nowego zestawu – wyczyść
      if (_maszyna != null && !fetchedMaszyny.any((m) => m.id == _maszyna!.id)) {
        _maszyna = null;
      }
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nie udało się pobrać maszyn dla działu: $e')),
      );
    }
  }

  void _hydrate() {
    // 1. Priorytet existing
    Raport? base = widget.existing;

    // 2. Jeśli nie ma, a mamy ID => spróbuj załadować
    if (base == null && widget.raportId != null) {
      final repo = ref.read(mockRepoProvider);
      base = repo.getRaportById(widget.raportId!);
      _loaded = base;
    }

    if (base != null) {
      _maszyna = base.maszyna;
      _osoba = base.osoba;
      _dzial = base.maszyna?.dzial; // null-safe
      _typNaprawyCtrl.text = base.typNaprawy;
      _opisCtrl.text = base.opis;
      _status = base.status;
      _dataNaprawy = base.dataNaprawy;
      _czasOd = TimeOfDay(hour: base.czasOd.hour, minute: base.czasOd.minute);
      _czasDo = TimeOfDay(hour: base.czasDo.hour, minute: base.czasDo.minute);
      _photoBase64 = base.photoBase64;
    } else {
      // Wartości domyślne nowego
      _status = 'NOWY';
    }
  }

  @override
  void dispose() {
    _typNaprawyCtrl.dispose();
    _opisCtrl.dispose();
    _maszynaSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dataNaprawy ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
    );
    if (picked != null) {
      setState(() => _dataNaprawy = picked);
    }
  }

  Future<void> _pickTime(bool from) async {
    final initial = from ? _czasOd : _czasDo;
    final picked = await showTimePicker(
      context: context,
      initialTime: initial ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        if (from) {
          _czasOd = picked;
        } else {
          _czasDo = picked;
        }
      });
    }
  }

  String? _validateTimes() {
    if (_czasOd == null || _czasDo == null) return null;
    final date = _dataNaprawy ?? DateTime.now();
    final start = DateTime(
        date.year, date.month, date.day, _czasOd!.hour, _czasOd!.minute);
    final end = DateTime(
        date.year, date.month, date.day, _czasDo!.hour, _czasDo!.minute);
    if (end.isBefore(start)) {
      return 'Czas "Do" nie może być wcześniejszy niż "Od"';
    }
    return null;
  }

  void _save() {
    final timesError = _validateTimes();
    if (timesError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(timesError)),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    if (_maszyna == null ||
        _dataNaprawy == null ||
        _czasOd == null ||
        _czasDo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Uzupełnij maszynę, datę oraz godziny')),
      );
      return;
    }

    final repo = ref.read(mockRepoProvider);

    final dtOd = DateTime(
      _dataNaprawy!.year,
      _dataNaprawy!.month,
      _dataNaprawy!.day,
      _czasOd!.hour,
      _czasOd!.minute,
    );
    final dtDo = DateTime(
      _dataNaprawy!.year,
      _dataNaprawy!.month,
      _dataNaprawy!.day,
      _czasDo!.hour,
      _czasDo!.minute,
    );

    final int id =
        _loaded?.id ?? widget.existing?.id ?? 0; // 0 => repo nada nowe ID
    final partUsages = _loaded?.partUsages ??
        widget.existing?.partUsages ??
        []; // zachowaj jeśli edycja

    final raport = Raport(
      id: id,
      maszyna: _maszyna!,
      typNaprawy: _typNaprawyCtrl.text.trim(),
      opis: _opisCtrl.text.trim(),
      osoba: _osoba,
      status: _status,
      dataNaprawy: _dataNaprawy!,
      czasOd: dtOd,
      czasDo: dtDo,
      partUsages: partUsages,
      photoBase64: _photoBase64,
    );

    repo.upsertRaport(raport);
    Navigator.pop(context);
  }

  void _onSelectDzial(Dzial? dz) async {
    setState(() {
      _dzial = dz;
      _maszyna = null; // reset maszyny przy zmianie działu
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

  List<Maszyna> _filteredMaszyny(List<Maszyna> all) {
    final q = _maszynaQuery.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all.where((m) => m.nazwa.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(mockRepoProvider);
    final wszystkieMaszyny = repo.getMaszyny();
    final maszyny = _filteredMaszyny(wszystkieMaszyny);
    final osoby = repo.getOsoby();
    final dzialy = _dzialyLocal; // zaciągnięte meta

    return Scaffold(
      appBar: TopAppBar(
        title: _isEdit ? 'Edytuj raport' : 'Nowy raport',
        showBack: true,
        extraActions: [
          IconButton(
            tooltip: 'Zapisz',
            icon: const Icon(Icons.save, color: Colors.white),
            onPressed: _save,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // DZIAŁ – wymagany przed wyborem maszyny
            DropdownButtonFormField<Dzial>(
              value: _dzial,
              decoration: const InputDecoration(labelText: 'Dział'),
              items: dzialy
                  .map((d) => DropdownMenuItem(value: d, child: Text(d.nazwa)))
                  .toList(),
              onChanged: (v) => _onSelectDzial(v),
              validator: (v) => v == null ? 'Wybierz dział' : null,
            ),
            // DEBUG / DIAGNOSTYKA DZIAŁÓW
            Padding(
              padding: const EdgeInsets.only(top: 6.0, bottom: 12.0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      dzialy.isEmpty
                          ? 'Brak działów – sprawdź /api/meta/dzialy-simple lub czy jesteś zalogowany.'
                          : 'Załadowano działów: ${dzialy.length}',
                      style: TextStyle(
                        fontSize: 11,
                        color: dzialy.isEmpty ? Colors.redAccent : Colors.grey.shade600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Odśwież listę działów',
                    icon: const Icon(Icons.refresh, size: 18),
                    onPressed: () async {
                      await _syncMetaFromApi();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Odświeżono meta dane')),);
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // WYSZUKIWARKA MASZYN (aktywowana gdy wybrano dział)
            TextField(
              controller: _maszynaSearchCtrl,
              enabled: _dzial != null,
              decoration: InputDecoration(
                labelText: 'Szukaj maszyny (minimum 1 litera)',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _maszynaQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() {
                          _maszynaSearchCtrl.clear();
                          _maszynaQuery = '';
                        }),
                      )
                    : null,
              ),
              onChanged: (v) => setState(() => _maszynaQuery = v),
            ),
            const SizedBox(height: 16),
            // MASZYNA – zależna od działu
            DropdownButtonFormField<Maszyna>(
              value: _maszyna,
              decoration: InputDecoration(
                labelText: _dzial == null
                    ? 'Maszyna (najpierw wybierz dział)'
                    : 'Maszyna',
              ),
              items: maszyny
                  .map((m) => DropdownMenuItem(value: m, child: Text(m.nazwa)))
                  .toList(),
              onChanged: _dzial == null ? null : (v) => setState(() => _maszyna = v),
              validator: (v) => v == null ? 'Wybierz maszynę' : null,
            ),
            const SizedBox(height: 16),
            // OSOBA (opcjonalne)
            DropdownButtonFormField<Osoba>(
              value: _osoba,
              decoration: const InputDecoration(
                  labelText: 'Osoba (wykonujący) – opcjonalne'),
              items: [
                const DropdownMenuItem<Osoba>(value: null, child: Text('Brak')),
                ...osoby.map(
                  (o) => DropdownMenuItem(value: o, child: Text(o.imieNazwisko)),
                ),
              ],
              onChanged: (v) => setState(() => _osoba = v),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _typNaprawyCtrl,
              decoration: const InputDecoration(labelText: 'Typ naprawy'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Wymagane' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _opisCtrl,
              decoration: const InputDecoration(labelText: 'Opis'),
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            // STATUS
            DropdownButtonFormField<String>(
              value: _status,
              decoration: const InputDecoration(labelText: 'Status'),
              items: const [
                DropdownMenuItem(value: 'NOWY', child: Text('NOWY')),
                DropdownMenuItem(value: 'W TOKU', child: Text('W TOKU')),
                DropdownMenuItem(value: 'OCZEKUJE', child: Text('OCZEKUJE')),
                DropdownMenuItem(
                    value: 'ZAKOŃCZONY', child: Text('ZAKOŃCZONY')),
              ],
              onChanged: (v) => setState(() => _status = v ?? _status),
            ),
            const SizedBox(height: 24),

            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _PickerButton(
                  label: _dataNaprawy == null
                      ? 'Data'
                      : 'Data: ${_dataNaprawy!.toIso8601String().substring(0, 10)}',
                  icon: Icons.calendar_month_outlined,
                  onTap: _pickDate,
                ),
                _PickerButton(
                  label: _czasOd == null
                      ? 'Czas od'
                      : 'Od: ${_czasOd!.format(context)}',
                  icon: Icons.schedule_outlined,
                  onTap: () => _pickTime(true),
                ),
                _PickerButton(
                  label: _czasDo == null
                      ? 'Czas do'
                      : 'Do: ${_czasDo!.format(context)}',
                  icon: Icons.schedule,
                  onTap: () => _pickTime(false),
                ),
              ],
            ),
            if (_validateTimes() != null) ...[
              const SizedBox(height: 8),
              Text(
                _validateTimes()!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ],
            const SizedBox(height: 28),

            // ZDJĘCIE (opcjonalne)
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                      color: Theme.of(context).dividerColor.withOpacity(.4))),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                child: PhotoPickerField(
                  initialBase64: _photoBase64,
                  label: 'Zdjęcie (opcjonalne)',
                  onChanged: (b64) => _photoBase64 = b64,
                ),
              ),
            ),
            const SizedBox(height: 32),

            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.save),
                onPressed: _save,
                label: Text(_isEdit ? 'Zapisz zmiany' : 'Dodaj raport'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickerButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _PickerButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 0,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.black87),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

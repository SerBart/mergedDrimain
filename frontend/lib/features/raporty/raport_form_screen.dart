import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/maszyna.dart';
import '../../core/models/osoba.dart';
import '../../core/models/raport.dart';
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
  final _typNaprawyCtrl = TextEditingController();
  final _opisCtrl = TextEditingController();
  String _status = 'NOWY';
  DateTime? _dataNaprawy;
  TimeOfDay? _czasOd;
  TimeOfDay? _czasDo;
  String? _photoBase64;

  // Załadowany (jeśli edycja przez ID)
  Raport? _loaded;

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
      final fetchedMaszyny = await meta.fetchMaszynySimple();
      final fetchedOsoby = await meta.fetchOsobySimple();
      final mock = ref.read(mockRepoProvider);
      // Podmień zawartość list w mock repo na dane z backendu
      mock.maszyny
        ..clear()
        ..addAll(fetchedMaszyny);
      mock.osoby
        ..clear()
        ..addAll(fetchedOsoby);
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nie udało się pobrać listy maszyn/osób: $e')),
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

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(mockRepoProvider);
    final maszyny = repo.getMaszyny();
    final osoby = repo.getOsoby();

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edytuj raport' : 'Nowy raport'),
        leading: IconButton(
          tooltip: 'Dashboard',
          icon: const Icon(Icons.home),
          onPressed: () => context.go('/dashboard'),
        ),
        actions: [
          IconButton(
            tooltip: 'Zapisz',
            icon: const Icon(Icons.save),
            onPressed: _save,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // MASZYNA
            DropdownButtonFormField<Maszyna>(
              value: _maszyna,
              decoration: const InputDecoration(labelText: 'Maszyna'),
              items: maszyny
                  .map(
                    (m) => DropdownMenuItem(value: m, child: Text(m.nazwa)),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _maszyna = v),
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
                  (o) =>
                      DropdownMenuItem(value: o, child: Text(o.imieNazwisko)),
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

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
import '../../core/constants/naprawy_constants.dart';

/// Formularz tworzenia / edycji raportu.
/// Możesz wejść tu:
/// 1) z istniejącym obiektem Raport (param existing)
/// 2) tylko z raportId (załaduje z repo)
/// 3) pusty – tworzenie nowego
class RaportFormScreen extends ConsumerStatefulWidget {
  final Raport? existing;
  final int? raportId;
  // NOWE: tryb osadzenia w dialogu oraz callback po zapisie
  final bool embedInDialog;
  final void Function(Raport)? onSaved;

  const RaportFormScreen({
    super.key,
    this.existing,
    this.raportId,
    this.embedInDialog = false,
    this.onSaved,
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

  // Lista typów jak w nowych zgłoszeniach
  static const List<String> _typyNapraw = NaprawyConstants.typyNapraw;
  bool _saving = false;

  // Załadowany (jeśli edycja przez ID)
  Raport? _loaded;

  final TextEditingController _maszynaSearchCtrl = TextEditingController();
  String _maszynaQuery = '';
  List<Dzial> _dzialyLocal = []; // załadowane działy
  // NOWE: aktualny tekst wyszukiwania dla Autocomplete
  String _maszynaSearchText = '';

  // NOWE: stany ładowania / błędów
  bool _loadingMeta = false;
  bool _loadingMaszyny = false;
  String? _metaError;
  String? _maszynyError;

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
    setState(() {
      _loadingMeta = true;
      _metaError = null;
    });
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
    } catch (e) {
      _metaError = 'Meta dane (działy) błąd: $e';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Nie udało się pobrać meta danych: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingMeta = false);
    }
  }

  Future<void> _fetchMaszynyForDzial() async {
    if (_dzial == null) return;
    setState(() {
      _loadingMaszyny = true;
      _maszynyError = null;
    });
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
    } catch (e) {
      _maszynyError = 'Błąd maszyn dla działu: $e';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Nie udało się pobrać maszyn dla działu: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingMaszyny = false);
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
      // Domyślny typ naprawy jak w zgłoszeniach
      _typNaprawyCtrl.text = _typyNapraw.first;
    }
    // Ustaw widoczny tekst wyszukiwania maszyny dla Autocomplete
    _maszynaSearchText = _maszyna?.nazwa ?? '';
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

  // NOWE: listener dla pola Autocomplete (maszyna)
  void _maszynaSearchListener(TextEditingController c) {
    final text = c.text;
    if (text != _maszynaSearchText) {
      setState(() {
        _maszynaSearchText = text;
        if (_maszyna != null && _maszyna!.nazwa != text) {
          _maszyna = null;
        }
      });
    }
  }

  void _save() async {
    if (_saving) return;
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

    setState(() => _saving = true);
    try {
      final api = ref.read(raportyApiRepositoryProvider);
      final mock = ref.read(mockRepoProvider);
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
      final partUsages = _loaded?.partUsages ?? widget.existing?.partUsages ?? [];
      Raport saved;
      if (_isEdit) {
        final id = _loaded?.id ?? widget.existing!.id;
        saved = await api.update(
          id: id,
          maszynaId: _maszyna!.id,
          typNaprawy: _typNaprawyCtrl.text.trim(),
          opis: _opisCtrl.text.trim(),
          osobaId: _osoba?.id,
          status: _status,
          data: _dataNaprawy!,
          czasOd: dtOd,
          czasDo: dtDo,
          partUsages: partUsages,
        );
      } else {
        saved = await api.create(
          maszynaId: _maszyna!.id,
          typNaprawy: _typNaprawyCtrl.text.trim(),
          opis: _opisCtrl.text.trim(),
          osobaId: _osoba?.id,
          status: _status,
          data: _dataNaprawy!,
          czasOd: dtOd,
          czasDo: dtDo,
          partUsages: partUsages,
        );
      }
      // Zachowaj lokalnie photoBase64 (backend jeszcze może nie zwracać)
      if (_photoBase64 != null) {
        saved = saved.copyWith(photoBase64: _photoBase64);
      }
      mock.upsertRaport(saved);
      widget.onSaved?.call(saved);
      if (widget.embedInDialog) {
        Navigator.pop(context, true);
      } else {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd zapisu raportu: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _onSelectDzial(Dzial? dz) async {
    setState(() {
      _dzial = dz;
      _maszyna = null; // reset maszyny przy zmianie działu
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

  List<Maszyna> _filteredMaszyny(List<Maszyna> all) {
    final q = _maszynaSearchText.trim().toLowerCase();
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

    if (widget.embedInDialog) {
      return _buildDialogUI(context, wszystkieMaszyny, maszyny, osoby, dzialy);
    }
    return _buildPageUI(context, wszystkieMaszyny, maszyny, osoby, dzialy);
  }

  // Zbiór pól formularza wykorzystywany w obu wariantach (dialog i pełna strona)
  List<Widget> _buildFormFields(
    BuildContext context,
    List<Maszyna> wszystkieMaszyny,
    List<Maszyna> maszyny,
    List<Osoba> osoby,
    List<Dzial> dzialy,
  ) {
    return [
      // DZIAŁ – wymagany przed wyborem maszyny
      DropdownButtonFormField<Dzial>(
        value: _dzial,
        decoration: const InputDecoration(labelText: 'Dział'),
        items: dzialy
            .map((d) => DropdownMenuItem(value: d, child: Text(d.nazwa)))
            .toList(),
        onChanged: _loadingMeta ? null : (v) => _onSelectDzial(v),
        validator: (v) => v == null ? 'Wybierz dział' : null,
      ),
      // ROZSZERZONA DIAGNOSTYKA + SPINNER
      Padding(
        padding: const EdgeInsets.only(top: 6.0, bottom: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (_loadingMeta)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                Expanded(
                  child: Text(
                    _metaError != null
                        ? _metaError!
                        : dzialy.isEmpty
                            ? 'Brak działów – odśwież lub sprawdź autoryzację.'
                            : 'Działy: ${dzialy.length} (wybrany: ${_dzial?.nazwa ?? '-'}).',
                    style: TextStyle(
                      fontSize: 11,
                      color: _metaError != null
                          ? Colors.redAccent
                          : (dzialy.isEmpty
                              ? Colors.redAccent
                              : Colors.grey.shade600),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Odśwież meta (działy)',
                  icon: const Icon(Icons.refresh, size: 18),
                  onPressed: _loadingMeta
                      ? null
                      : () async {
                          await _syncMetaFromApi();
                          if (mounted && _metaError == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Odświeżono działy')),
                            );
                          }
                        },
                ),
              ],
            ),
            AnimatedOpacity(
              opacity: _dzial != null ? 1 : 0.5,
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
                          : _dzial == null
                              ? 'Wybierz dział aby pobrać maszyny.'
                              : 'Maszyny: ${wszystkieMaszyny.length} (filtrowane: ${maszyny.length}).',
                      style: TextStyle(
                        fontSize: 11,
                        color: _maszynyError != null
                            ? Colors.redAccent
                            : Colors.grey.shade600,
                      ),
                    ),
                  ),
                  if (_dzial != null)
                    IconButton(
                      tooltip: 'Odśwież maszyny dla działu',
                      icon: const Icon(Icons.settings_backup_restore, size: 18),
                      onPressed:
                          _loadingMaszyny ? null : () async => _fetchMaszynyForDzial(),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      // MASZYNA – Autocomplete (rozwiń listę lub wpisz min. 1 literę)
      FormField<void>(
        validator: (_) => _maszyna == null ? 'Wybierz maszynę' : null,
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
              displayStringForOption: (o) => o.nazwa,
              initialValue: TextEditingValue(text: _maszynaSearchText),
              optionsBuilder: (TextEditingValue tev) {
                if (_dzial == null || _loadingMaszyny) {
                  return const Iterable<Maszyna>.empty();
                }
                final q = tev.text.trim().toLowerCase();
                final all = ref.read(mockRepoProvider).getMaszyny();
                if (q.isEmpty) return all; // pełna lista bez wpisywania
                return all.where((m) => m.nazwa.toLowerCase().contains(q));
              },
              onSelected: (Maszyna sel) {
                setState(() {
                  _maszyna = sel;
                  _maszynaSearchText = sel.nazwa;
                });
              },
              fieldViewBuilder: (ctx, textCtrl, focusNode, onFieldSubmitted) {
                return TextField(
                  controller: textCtrl,
                  focusNode: focusNode,
                  enabled: _dzial != null && !_loadingMaszyny,
                  decoration: InputDecoration(
                    hintText: 'Wpisz literę lub rozwiń listę',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      tooltip: 'Pokaż pełną listę',
                      icon: const Icon(Icons.arrow_drop_down),
                      onPressed: _dzial != null && !_loadingMaszyny
                          ? () {
                              // Wymuś otwarcie listy bez wpisywania
                              focusNode.requestFocus();
                              textCtrl.text = textCtrl.text + ' ';
                              textCtrl.text = textCtrl.text.trimRight();
                            }
                          : null,
                    ),
                  ),
                  onChanged: (v) => setState(() {
                    _maszynaSearchText = v;
                    if (_maszyna != null && _maszyna!.nazwa != v) {
                      _maszyna = null;
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
      const SizedBox(height: 16),
      // OSOBA (opcjonalne)
      DropdownButtonFormField<Osoba>(
        value: _osoba,
        decoration: const InputDecoration(labelText: 'Osoba (wykonujący) – opcjonalne'),
        items: [
          const DropdownMenuItem<Osoba>(value: null, child: Text('Brak')),
          ...osoby.map((o) => DropdownMenuItem(value: o, child: Text(o.imieNazwisko))),
        ],
        onChanged: (v) => setState(() => _osoba = v),
      ),
      const SizedBox(height: 16),
      // Zmiana: Typ naprawy z listy rozwijalnej (jak w nowych zgłoszeniach)
      DropdownButtonFormField<String>(
        value: _typyNapraw.contains(_typNaprawyCtrl.text) && _typNaprawyCtrl.text.isNotEmpty
            ? _typNaprawyCtrl.text
            : _typyNapraw.first,
        decoration: const InputDecoration(labelText: 'Typ naprawy'),
        items: _typyNapraw
            .map((t) => DropdownMenuItem<String>(value: t, child: Text(t)))
            .toList(),
        onChanged: (v) => setState(() {
          if (v != null) _typNaprawyCtrl.text = v;
        }),
        validator: (v) => v == null || v.trim().isEmpty ? 'Wymagane' : null,
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _opisCtrl,
        decoration: const InputDecoration(labelText: 'Opis'),
        maxLines: 3,
      ),
      const SizedBox(height: 16),
      DropdownButtonFormField<String>(
        value: _status,
        decoration: const InputDecoration(labelText: 'Status'),
        items: const [
          DropdownMenuItem(value: 'NOWY', child: Text('NOWY')),
          DropdownMenuItem(value: 'W TOKU', child: Text('W TOKU')),
          DropdownMenuItem(value: 'OCZEKUJE', child: Text('OCZEKUJE')),
          DropdownMenuItem(value: 'ZAKOŃCZONY', child: Text('ZAKOŃCZONY')),
        ],
        onChanged: (v) => setState(() => _status = v ?? _status),
      ),
      const SizedBox(height: 20),
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
            label: _czasOd == null ? 'Czas od' : 'Od: ${_czasOd!.format(context)}',
            icon: Icons.schedule_outlined,
            onTap: () => _pickTime(true),
          ),
          _PickerButton(
            label: _czasDo == null ? 'Czas do' : 'Do: ${_czasDo!.format(context)}',
            icon: Icons.schedule,
            onTap: () => _pickTime(false),
          ),
        ],
      ),
      if (_validateTimes() != null) ...[
        const SizedBox(height: 8),
        Text(_validateTimes()!, style: const TextStyle(color: Colors.red, fontSize: 12)),
      ],
      const SizedBox(height: 20),
      Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: Theme.of(context).dividerColor.withOpacity(.4)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: PhotoPickerField(
            initialBase64: _photoBase64,
            label: 'Zdjęcie (opcjonalne)',
            onChanged: (b64) => _photoBase64 = b64,
          ),
        ),
      ),
    ];
  }

  Widget _buildDialogUI(
    BuildContext context,
    List<Maszyna> wszystkieMaszyny,
    List<Maszyna> maszyny,
    List<Osoba> osoby,
    List<Dzial> dzialy,
  ) {
    return SizedBox(
      width: 640,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _isEdit ? 'Edytuj raport' : 'Nowy raport',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Zamknij',
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _buildFormFields(context, wszystkieMaszyny, maszyny, osoby, dzialy),
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Anuluj'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.save),
                    onPressed: _save,
                    label: Text(_isEdit ? 'Zapisz zmiany' : 'Dodaj'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageUI(
    BuildContext context,
    List<Maszyna> wszystkieMaszyny,
    List<Maszyna> maszyny,
    List<Osoba> osoby,
    List<Dzial> dzialy,
  ) {
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
            ..._buildFormFields(context, wszystkieMaszyny, maszyny, osoby, dzialy),
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

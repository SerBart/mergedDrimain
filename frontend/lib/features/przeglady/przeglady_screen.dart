import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/app_providers.dart';
import '../../core/models/harmonogram.dart';
import '../../core/models/maszyna.dart';
import '../../core/models/dzial.dart';
import '../../core/models/osoba.dart';
import '../raporty/raport_form_screen.dart';
import '../../widgets/top_app_bar.dart';

// Dodane: enum musi być na poziomie top-level w Dart
enum DayColorMode { none, dominantFrequency, gradientFrequencies, status }

class PrzegladyScreen extends ConsumerStatefulWidget {
  const PrzegladyScreen({super.key});
  @override
  ConsumerState<PrzegladyScreen> createState() => _PrzegladyScreenState();
}

class _PrzegladyScreenState extends ConsumerState<PrzegladyScreen> {
  DateTime _currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
  bool _loading = false;
  List<Harmonogram> _items = [];
  List<Maszyna> _maszyny = [];
  List<Dzial> _dzialy = [];
  List<Osoba> _osoby = []; // lista osób (UR)
  bool _loadingMeta = false;

  // Tryby kolorowania dnia
  DayColorMode _colorMode = DayColorMode.dominantFrequency;
  bool _strongFill = false; // intensywniejsze wypełnienie

  static const _freqValues = [
    'TYGODNIOWY', 'MIESIECZNY', 'KWARTALNY', 'POLROCZNY', 'ROCZNY'
  ];

  static const Map<String, Color> _freqColors = {
    'TYGODNIOWY': Colors.blue,
    'MIESIECZNY': Colors.green,
    'KWARTALNY': Colors.orange,
    'POLROCZNY': Colors.purple,
    'ROCZNY': Colors.red,
  };

  static const Map<String, Color> _statusColors = {
    'PLANOWANE': Colors.amber,
    'W_TRAKCIE': Colors.indigo,
    'ZAKONCZONE': Colors.teal,
    'ANULOWANE': Colors.grey,
  };

  // Priorytet kolorów – jeśli kilka eventów w dniu, wybieramy "najkrótszy" okres
  static const List<String> _freqPriority = [
    'TYGODNIOWY', 'MIESIECZNY', 'KWARTALNY', 'POLROCZNY', 'ROCZNY'
  ];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    await Future.wait([
      _loadMonth(),
      _loadMeta(),
    ]);
  }

   Future<void> _loadMonth() async {
     setState(() => _loading = true);
     try {
       final repo = ref.read(harmonogramyApiRepositoryProvider);
       final list = await repo.fetchAll(year: _currentMonth.year, month: _currentMonth.month);
       setState(() => _items = list);
     } catch (e) {
       if (mounted) {
         String errorMsg = 'Błąd pobierania harmonogramów';
         if (e.toString().contains('401') || e.toString().contains('Sesja wygasła')) {
           errorMsg = 'Sesja wygasła - zaloguj się ponownie';
         }
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(
             content: Text('⚠️ $errorMsg'),
             duration: const Duration(seconds: 5),
             action: SnackBarAction(
               label: 'Ponów',
               onPressed: _loadMonth,
             ),
           ),
         );
       }
     } finally {
       if (mounted) setState(() => _loading = false);
     }
   }

   Future<void> _loadMeta() async {
     setState(() => _loadingMeta = true);
     try {
       final adminRepo = ref.read(adminApiRepositoryProvider);
       final metaRepo = ref.read(metaApiRepositoryProvider);
       final maszyny = await adminRepo.getMaszyny();
       final dzialy = await adminRepo.getDzialy();
       // pobierz osoby tylko z UR; fallback do wszystkich jeśli brak
       const urName = 'Utrzymanie Ruchu';
       var osoby = await metaRepo.fetchOsobySimple(dzialNazwa: urName);
       if (osoby.isEmpty) {
         osoby = await metaRepo.fetchOsobySimple();
       }
       setState(() { _maszyny = maszyny; _dzialy = dzialy; _osoby = osoby; });
     } catch (e) {
       // Cicha obsługa - meta nie blokuje krytycznie, ale loguj błąd
       if (e.toString().contains('401')) {
         if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('⚠️ Nie udało się pobrać opcji - sesja wygasła'))
           );
         }
       }
     } finally {
       if (mounted) setState(() => _loadingMeta = false);
     }
   }

  void _prevMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    });
    _loadMonth();
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    });
    _loadMonth();
  }

  String _monthTitle(DateTime d) {
    const names = [
      'Styczeń','Luty','Marzec','Kwiecień','Maj','Czerwiec',
      'Lipiec','Sierpień','Wrzesień','Październik','Listopad','Grudzień'
    ];
    return '${names[d.month - 1]} ${d.year}';
  }

  List<DateTime> _calendarDays(DateTime month) {
    final first = DateTime(month.year, month.month, 1);
    final firstWeekday = first.weekday; // Mon=1 .. Sun=7
    final daysBefore = firstWeekday - 1; // how many days from prev month
    final firstToShow = first.subtract(Duration(days: daysBefore));
    return List.generate(42, (i) => DateTime(firstToShow.year, firstToShow.month, firstToShow.day + i));
  }

  List<Harmonogram> _eventsOn(DateTime day) {
    return _items.where((h) => h.data != null && h.data!.year == day.year && h.data!.month == day.month && h.data!.day == day.day).toList();
  }

  Color _colorFor(String? freq) => _freqColors[freq] ?? Colors.grey;

  Color? _dominantColorForEvents(List<Harmonogram> events) {
    if (events.isEmpty) return null;
    final Map<String, int> counts = {};
    for (final e in events) {
      final f = e.frequency;
      if (f == null) continue;
      counts[f] = (counts[f] ?? 0) + 1;
    }
    if (counts.isEmpty) return null;
    for (final p in _freqPriority) {
      if (counts.containsKey(p)) {
        return _colorFor(p);
      }
    }
    return _colorFor(counts.keys.first);
  }

  String _fullDesc(Harmonogram h) {
    return h.opis.isNotEmpty ? h.opis : (h.maszyna?.nazwa ?? h.dzial?.nazwa ?? 'Przegląd');
  }

  String _shortDesc(Harmonogram h) {
    final base = _fullDesc(h);
    if (base.length <= 40) return base;
    return base.substring(0, 37) + '...';
  }

  static const Map<int, String> _weekdayLabels = {
    DateTime.monday: 'Poniedziałek',
    DateTime.tuesday: 'Wtorek',
    DateTime.wednesday: 'Środa',
    DateTime.thursday: 'Czwartek',
    DateTime.friday: 'Piątek',
    DateTime.saturday: 'Sobota',
    DateTime.sunday: 'Niedziela',
  };

  DateTime _nextOrSameWeekday(DateTime from, int weekday) {
    final delta = (weekday - from.weekday + 7) % 7;
    return DateTime(from.year, from.month, from.day + delta);
  }

   Future<void> _openAddDialog() async {
     DateTime selectedDate = DateTime.now();
     String? frequency = 'MIESIECZNY';
     int weeklyWeekday = DateTime.friday;
     DateTime planEndDate = DateTime(DateTime.now().year, 12, 31);
     String opis = '';
     int? maszynaId;
     int? dzialId;
     int? osobaId; // wykonujący przegląd
     bool useMaszyna = true; // toggle między maszyna / dzial

     await showDialog(
       context: context,
       barrierDismissible: false,
       builder: (ctx) => StatefulBuilder(
         builder: (ctx, setLocal) => AlertDialog(
           title: const Text('Nowy przegląd'),
           content: SizedBox(
             width: 480,
             child: SingleChildScrollView(
               child: Column(
                 mainAxisSize: MainAxisSize.min,
                 children: [
                   // UPROSZCZONE: Data
                   InputDecorator(
                     decoration: const InputDecoration(
                       labelText: 'Data pierwszego przeglądu',
                       border: OutlineInputBorder(),
                       helperText: 'Wybierz datę rozpoczęcia'
                     ),
                     child: InkWell(
                       onTap: () async {
                         final now = DateTime.now();
                         final picked = await showDatePicker(
                           context: ctx,
                           initialDate: selectedDate,
                           firstDate: DateTime(now.year, now.month, now.day),
                           lastDate: DateTime(now.year + 2),
                         );
                         if (picked != null) {
                           setLocal(() {
                             selectedDate = picked;
                             if (planEndDate.isBefore(selectedDate)) {
                               planEndDate = DateTime(selectedDate.year, 12, 31);
                             }
                           });
                         }
                       },
                       child: Padding(
                         padding: const EdgeInsets.symmetric(vertical: 12),
                         child: Row(
                           children: [
                             const Icon(Icons.calendar_today, size: 20, color: Colors.indigo),
                             const SizedBox(width: 12),
                             Text(
                               '${selectedDate.year}-${selectedDate.month.toString().padLeft(2,'0')}-${selectedDate.day.toString().padLeft(2,'0')}',
                               style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                             ),
                           ],
                         ),
                       ),
                     ),
                   ),
                   const SizedBox(height: 16),
                   // UPROSZCZONE: Częstotliwość
                   DropdownButtonFormField<String>(
                     value: frequency,
                     decoration: const InputDecoration(
                       labelText: 'Jak często?',
                       border: OutlineInputBorder(),
                       helperText: 'Wybierz częstotliwość powtarzania'
                     ),
                     isExpanded: true,
                     items: _freqValues.map((f) {
                       final labels = {
                         'TYGODNIOWY': 'Co tydzień',
                         'MIESIECZNY': 'Co miesiąc',
                         'KWARTALNY': 'Co kwartał',
                         'POLROCZNY': 'Co pół roku',
                         'ROCZNY': 'Co rok',
                       };
                       return DropdownMenuItem(value: f, child: Text(labels[f] ?? f));
                     }).toList(),
                     onChanged: (v) => setLocal(() {
                       frequency = v;
                       if (v == 'TYGODNIOWY') {
                         weeklyWeekday = selectedDate.weekday;
                       }
                     }),
                   ),
                   const SizedBox(height: 16),
                   // Jeśli tygodniowy, pozwól wybrać dzień
                   if (frequency == 'TYGODNIOWY') ...[
                     DropdownButtonFormField<int>(
                       value: weeklyWeekday,
                       decoration: const InputDecoration(
                         labelText: 'Który dzień tygodnia?',
                         border: OutlineInputBorder(),
                       ),
                       isExpanded: true,
                       items: _weekdayLabels.entries
                           .map((e) => DropdownMenuItem<int>(value: e.key, child: Text(e.value)))
                           .toList(),
                       onChanged: (v) => setLocal(() => weeklyWeekday = v ?? DateTime.friday),
                     ),
                     const SizedBox(height: 16),
                   ],
                   // UPROSZCZONE: Plan do
                   InputDecorator(
                     decoration: const InputDecoration(
                       labelText: 'Plan do (kiedy skończyć powtarzanie)',
                       border: OutlineInputBorder(),
                       helperText: 'Domyślnie koniec roku'
                     ),
                     child: InkWell(
                       onTap: () async {
                         final picked = await showDatePicker(
                           context: ctx,
                           initialDate: planEndDate,
                           firstDate: selectedDate,
                           lastDate: DateTime(2035, 12, 31),
                         );
                         if (picked != null) setLocal(() => planEndDate = picked);
                       },
                       child: Padding(
                         padding: const EdgeInsets.symmetric(vertical: 12),
                         child: Row(
                           children: [
                             const Icon(Icons.event_repeat, size: 20, color: Colors.indigo),
                             const SizedBox(width: 12),
                             Text(
                               '${planEndDate.year}-${planEndDate.month.toString().padLeft(2,'0')}-${planEndDate.day.toString().padLeft(2,'0')}',
                               style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                             ),
                           ],
                         ),
                       ),
                     ),
                   ),
                   const SizedBox(height: 16),
                   // UPROSZCZONE: Opis (główne pole)
                   TextField(
                     decoration: const InputDecoration(
                       labelText: 'Czego dotyczy przegląd?',
                       hintText: 'np. Smarowanie łożysk',
                       border: OutlineInputBorder(),
                       prefixIcon: Icon(Icons.description_outlined),
                     ),
                     maxLines: 2,
                     onChanged: (v) => opis = v,
                   ),
                   const SizedBox(height: 16),
                   // OPCJONALNIE: Maszyna/Dział
                   const Divider(height: 2),
                   const SizedBox(height: 12),
                   const Text('Dodatkowe (opcjonalnie):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
                   const SizedBox(height: 12),
                   Row(
                     children: [
                       Expanded(
                         child: SegmentedButton<bool>(
                           segments: const [
                             ButtonSegment(value: true, label: Text('Maszyna'), icon: Icon(Icons.precision_manufacturing_outlined)),
                             ButtonSegment(value: false, label: Text('Dział'), icon: Icon(Icons.apartment_outlined)),
                           ],
                           selected: {useMaszyna},
                           onSelectionChanged: (s) => setLocal(() { useMaszyna = s.first; maszynaId = null; dzialId = null; }),
                         ),
                       ),
                     ],
                   ),
                   const SizedBox(height: 12),
                   if (useMaszyna && _maszyny.isNotEmpty)
                     DropdownButtonFormField<int>(
                       value: maszynaId,
                       decoration: const InputDecoration(labelText: 'Maszyna', border: OutlineInputBorder()),
                       isExpanded: true,
                       items: [
                         const DropdownMenuItem<int>(value: null, child: Text('Brak')),
                         ..._maszyny.map((m) => DropdownMenuItem(value: m.id, child: Text(m.nazwa)))
                       ],
                       onChanged: (v) => setLocal(() => maszynaId = v),
                     )
                   else if (!useMaszyna && _dzialy.isNotEmpty)
                     DropdownButtonFormField<int>(
                       value: dzialId,
                       decoration: const InputDecoration(labelText: 'Dział', border: OutlineInputBorder()),
                       isExpanded: true,
                       items: [
                         const DropdownMenuItem<int>(value: null, child: Text('Brak')),
                         ..._dzialy.map((d) => DropdownMenuItem(value: d.id, child: Text(d.nazwa)))
                       ],
                       onChanged: (v) => setLocal(() => dzialId = v),
                     ),
                   if (_osoby.isNotEmpty) ...[
                     const SizedBox(height: 12),
                     DropdownButtonFormField<int>(
                       value: osobaId,
                       decoration: const InputDecoration(labelText: 'Osoba', border: OutlineInputBorder()),
                       isExpanded: true,
                       items: [
                         const DropdownMenuItem<int>(value: null, child: Text('Brak')),
                         ..._osoby.map((o) => DropdownMenuItem(value: o.id, child: Text(o.imieNazwisko)))
                       ],
                       onChanged: (v) => setLocal(() => osobaId = v),
                     ),
                   ],
                 ],
               ),
             ),
           ),
           actions: [
             TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Anuluj')),
             FilledButton(
               onPressed: () async {
                 if (frequency == null) {
                   ScaffoldMessenger.of(context).showSnackBar(
                     const SnackBar(content: Text('⚠️ Wybierz częstotliwość powtarzania'))
                   );
                   return;
                 }
                 if (opis.trim().isEmpty) {
                   ScaffoldMessenger.of(context).showSnackBar(
                     const SnackBar(content: Text('⚠️ Opisz co to za przegląd'))
                   );
                   return;
                 }
                 try {
                   final repo = ref.read(harmonogramyApiRepositoryProvider);
                   await repo.create(
                     data: frequency == 'TYGODNIOWY'
                         ? _nextOrSameWeekday(selectedDate, weeklyWeekday)
                         : selectedDate,
                     maszynaId: useMaszyna ? maszynaId : null,
                     dzialId: useMaszyna ? null : dzialId,
                     osobaId: osobaId,
                     frequency: frequency,
                     planEndDate: planEndDate,
                     opis: opis.trim(),
                   );
                   if (!mounted) return;
                   Navigator.of(ctx).pop();
                   await _loadMonth();
                   ScaffoldMessenger.of(context).showSnackBar(
                     SnackBar(
                       content: Text('✓ Dodano przegląd: "${opis.trim()}"'),
                       duration: const Duration(seconds: 3),
                     )
                   );
                 } catch (e) {
                   if (!mounted) return;
                   ScaffoldMessenger.of(context).showSnackBar(
                     SnackBar(content: Text('❌ Błąd: $e'))
                   );
                 }
               },
               child: const Text('Dodaj przegląd'),
             ),
           ],
         ),
       ),
     );
   }

  Future<void> _openEditDialog(Harmonogram item) async {
    DateTime selectedDate = item.data ?? DateTime.now();
    String? frequency = item.frequency ?? 'MIESIECZNY';
    int weeklyWeekday = selectedDate.weekday;
    DateTime planEndDate = item.planEndDate ?? DateTime(selectedDate.year, 12, 31);
    String opis = item.opis;
    final opisCtrl = TextEditingController(text: opis);
    int? maszynaId = item.maszyna?.id;
    int? dzialId = item.dzial?.id;
    int? osobaId = item.osoba?.id;
    bool applyToFuture = true;
    bool useMaszyna = item.maszyna != null;

    try {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setLocal) => AlertDialog(
            title: const Text('Edytuj przegląd'),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                  InputDecorator(
                    decoration: const InputDecoration(labelText: 'Data', border: OutlineInputBorder()),
                    child: InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: selectedDate,
                          firstDate: DateTime.now().subtract(const Duration(days: 365)),
                          lastDate: DateTime(2035, 12, 31),
                        );
                        if (picked != null) setLocal(() => selectedDate = picked);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text('${selectedDate.year}-${selectedDate.month.toString().padLeft(2,'0')}-${selectedDate.day.toString().padLeft(2,'0')}'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: frequency,
                    decoration: const InputDecoration(labelText: 'Częstotliwość', border: OutlineInputBorder()),
                    items: _freqValues.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                    onChanged: (v) => setLocal(() {
                      frequency = v;
                      if (v == 'TYGODNIOWY') {
                        weeklyWeekday = selectedDate.weekday;
                      }
                    }),
                  ),
                  const SizedBox(height: 12),
                  if (frequency == 'TYGODNIOWY') ...[
                    DropdownButtonFormField<int>(
                      value: weeklyWeekday,
                      decoration: const InputDecoration(labelText: 'Dzień tygodnia', border: OutlineInputBorder()),
                      items: _weekdayLabels.entries
                          .map((e) => DropdownMenuItem<int>(value: e.key, child: Text(e.value)))
                          .toList(),
                      onChanged: (v) => setLocal(() => weeklyWeekday = v ?? DateTime.friday),
                    ),
                    const SizedBox(height: 12),
                  ],
                  InputDecorator(
                    decoration: const InputDecoration(labelText: 'Plan do', border: OutlineInputBorder()),
                    child: InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: planEndDate,
                          firstDate: selectedDate,
                          lastDate: DateTime(2035, 12, 31),
                        );
                        if (picked != null) setLocal(() => planEndDate = picked);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text('${planEndDate.year}-${planEndDate.month.toString().padLeft(2,'0')}-${planEndDate.day.toString().padLeft(2,'0')}'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment(value: true, label: Text('Maszyna'), icon: Icon(Icons.precision_manufacturing_outlined)),
                            ButtonSegment(value: false, label: Text('Dział'), icon: Icon(Icons.apartment_outlined)),
                          ],
                          selected: {useMaszyna},
                          onSelectionChanged: (s) => setLocal(() {
                            useMaszyna = s.first;
                            if (useMaszyna) {
                              dzialId = null;
                            } else {
                              maszynaId = null;
                            }
                          }),
                        ),
                      ),
                    ],
                  ),
                   const SizedBox(height: 12),
                   if (useMaszyna && _maszyny.isNotEmpty)
                     DropdownButtonFormField<int>(
                       value: maszynaId,
                       decoration: const InputDecoration(labelText: 'Maszyna', border: OutlineInputBorder()),
                       isExpanded: true,
                       items: [
                         const DropdownMenuItem<int>(value: null, child: Text('Brak')),
                         ..._maszyny.map((m) => DropdownMenuItem(value: m.id, child: Text(m.nazwa)))
                       ],
                       onChanged: (v) => setLocal(() => maszynaId = v),
                     )
                   else if (!useMaszyna && _dzialy.isNotEmpty)
                     DropdownButtonFormField<int>(
                       value: dzialId,
                       decoration: const InputDecoration(labelText: 'Dział', border: OutlineInputBorder()),
                       isExpanded: true,
                       items: [
                         const DropdownMenuItem<int>(value: null, child: Text('Brak')),
                         ..._dzialy.map((d) => DropdownMenuItem(value: d.id, child: Text(d.nazwa)))
                       ],
                       onChanged: (v) => setLocal(() => dzialId = v),
                     ),
                   if (_osoby.isNotEmpty) ...[
                     const SizedBox(height: 12),
                     DropdownButtonFormField<int>(
                       value: osobaId,
                       decoration: const InputDecoration(labelText: 'Osoba', border: OutlineInputBorder()),
                       isExpanded: true,
                       items: [
                         const DropdownMenuItem<int>(value: null, child: Text('Brak')),
                         ..._osoby.map((o) => DropdownMenuItem(value: o.id, child: Text(o.imieNazwisko)))
                       ],
                       onChanged: (v) => setLocal(() => osobaId = v),
                     ),
                   ],
                   const SizedBox(height: 12),
                   TextField(
                     controller: opisCtrl,
                     maxLines: 2,
                     decoration: const InputDecoration(
                       labelText: 'Opis przeglądu',
                       border: OutlineInputBorder(),
                       prefixIcon: Icon(Icons.description_outlined),
                     ),
                     onChanged: (v) => opis = v,
                   ),
                   const SizedBox(height: 16),
                   CheckboxListTile(
                     value: applyToFuture,
                     onChanged: (v) => setLocal(() => applyToFuture = v ?? true),
                     title: const Text('Zastosuj do przyszłych przeglądów z tej serii'),
                     controlAffinity: ListTileControlAffinity.leading,
                     contentPadding: EdgeInsets.zero,
                     subtitle: const Text('Jeśli nie zaznaczysz, zmieni się tylko ten przegląd', style: TextStyle(fontSize: 11)),
                   ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Anuluj')),
            FilledButton(
              onPressed: () async {
                try {
                  await ref.read(harmonogramyApiRepositoryProvider).update(
                    id: item.id,
                    data: frequency == 'TYGODNIOWY'
                        ? _nextOrSameWeekday(selectedDate, weeklyWeekday)
                        : selectedDate,
                    maszynaId: useMaszyna ? maszynaId : null,
                    dzialId: useMaszyna ? null : dzialId,
                    osobaId: osobaId,
                    frequency: frequency,
                    planEndDate: planEndDate,
                    opis: opis,
                    applyToSeriesFuture: applyToFuture,
                  );
                  if (!mounted) return;
                  Navigator.of(ctx).pop();
                  await _loadMonth();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Zapisano zmiany przeglądu')));
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Błąd edycji: $e')));
                }
              },
              child: const Text('Zapisz'),
            ),
          ],
          ),
        ),
      );
    } finally {
      opisCtrl.dispose();
    }
  }

   Future<void> _openRaportFromPrzeglad(Harmonogram item) async {
     try {
       final ok = await showDialog<bool>(
         context: context,
         barrierDismissible: false,
         builder: (ctx) => Dialog(
           insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
           child: RaportFormScreen(
             embedInDialog: true,
             prefillMaszyna: item.maszyna,
             prefillDzial: item.dzial ?? item.maszyna?.dzial,
             prefillOsoba: item.osoba,
             prefillDataNaprawy: item.data,
             prefillTypNaprawy: item.frequency != null ? 'Przegląd okresowy' : null,
             prefillOpis: item.opis,
           ),
         ),
       );

       if (ok == true) {
         try {
           final result = await ref.read(harmonogramyApiRepositoryProvider).complete(item.id);
           if (!mounted) return;
           await _loadMonth();
           final planFinished = result['planFinished'] == true;
           final message = planFinished
               ? (result['message']?.toString() ?? 'Plan przeglądów zakończony')
               : 'Przegląd oznaczono jako wykonany i utworzono raport';
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
         } catch (e) {
           if (!mounted) return;
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(
             content: Text('Raport dodany, ale błąd przy oznaczyniu przeglądu: $e')
           ));
         }
       }
     } catch (e) {
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Błąd: $e')));
       }
     }
   }

  void _openDayDetails(DateTime day) {
    final events = _eventsOn(day);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: events.isEmpty ? const Text('Brak przeglądów w tym dniu') : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Przeglądy ${day.year}-${day.month.toString().padLeft(2,'0')}-${day.day.toString().padLeft(2,'0')}', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ...events.map((e) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(radius: 10, backgroundColor: _colorFor(e.frequency)),
                title: Text(
                  e.opis.isNotEmpty ? e.opis : (e.maszyna?.nazwa ?? e.dzial?.nazwa ?? 'Przegląd'),
                  style: TextStyle(
                    color: e.status.toUpperCase() == 'ZAKONCZONE' ? Colors.black87 : Colors.red.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  '${e.frequency ?? '-'} • ${e.status.toUpperCase() == 'ZAKONCZONE' ? 'wykonane' : 'zaplanowane'}'
                  '${e.osoba != null ? ' • ${e.osoba!.imieNazwisko}' : ''}',
                ),
                trailing: Wrap(
                  spacing: 4,
                  children: [
                    IconButton(
                      tooltip: 'Nowy raport',
                      icon: const Icon(Icons.note_add_outlined, color: Colors.indigo),
                      onPressed: () async {
                        Navigator.of(ctx).pop();
                        await _openRaportFromPrzeglad(e);
                      },
                    ),
                    IconButton(
                      tooltip: 'Edytuj',
                      icon: const Icon(Icons.edit_outlined, color: Colors.blueAccent),
                      onPressed: () async {
                        Navigator.of(ctx).pop();
                        await _openEditDialog(e);
                      },
                    ),
                    IconButton(
                      tooltip: 'Usuń',
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      onPressed: () async {
                        final repo = ref.read(harmonogramyApiRepositoryProvider);
                        try {
                          await repo.delete(e.id);
                          if (mounted) {
                            Navigator.of(ctx).pop();
                            await _loadMonth();
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Usunięto')));
                          }
                        } catch (err) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Błąd usuwania: $err')));
                          }
                        }
                      },
                    ),
                  ],
                ),
              )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCalendar() {
    final days = _calendarDays(_currentMonth);
    final month = _currentMonth.month;
    return Column(
      children: [
        Row(
          children: [
            IconButton(onPressed: _loading ? null : _prevMonth, icon: const Icon(Icons.chevron_left)),
            Expanded(
              child: Center(
                child: Text(_monthTitle(_currentMonth), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              ),
            ),
            IconButton(onPressed: _loading ? null : _nextMonth, icon: const Icon(Icons.chevron_right)),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: const [
            Expanded(child: Center(child: Text('Pn', style: TextStyle(fontWeight: FontWeight.bold)))),
            Expanded(child: Center(child: Text('Wt', style: TextStyle(fontWeight: FontWeight.bold)))),
            Expanded(child: Center(child: Text('Śr', style: TextStyle(fontWeight: FontWeight.bold)))),
            Expanded(child: Center(child: Text('Cz', style: TextStyle(fontWeight: FontWeight.bold)))),
            Expanded(child: Center(child: Text('Pt', style: TextStyle(fontWeight: FontWeight.bold)))),
            Expanded(child: Center(child: Text('So', style: TextStyle(fontWeight: FontWeight.bold)))),
            Expanded(child: Center(child: Text('Nd', style: TextStyle(fontWeight: FontWeight.bold)))),
          ],
        ),
        const SizedBox(height: 4),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: days.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisExtent: 82,
          ),
          itemBuilder: (ctx, i) {
            final d = days[i];
            final isCurrent = d.month == month;
            final dayEvents = _eventsOn(d);
            final decoration = _dayDecoration(dayEvents, isCurrent);
            final firstEvent = dayEvents.isNotEmpty ? dayEvents.first : null;
            final shortLabel = firstEvent == null ? null : _shortDesc(firstEvent);
            final bool firstDone = firstEvent?.status.toUpperCase() == 'ZAKONCZONE';
            return InkWell(
              onTap: () => _openDayDetails(d),
              child: Container(
                margin: const EdgeInsets.all(2),
                decoration: decoration,
                padding: const EdgeInsets.all(4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('${d.day}', style: TextStyle(fontWeight: FontWeight.w600, color: isCurrent ? Colors.black87 : Colors.grey)),
                        const SizedBox(width: 4),
                        if (DateTime.now().year == d.year && DateTime.now().month == d.month && DateTime.now().day == d.day)
                          const Icon(Icons.circle, size: 6, color: Colors.redAccent),
                        if (dayEvents.length > 3)
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Text('+${dayEvents.length - 2}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500)),
                          )
                      ],
                    ),
                    if (shortLabel != null) ...[
                      const SizedBox(height: 2),
                      Tooltip(
                        message: _fullDesc(firstEvent!),
                        child: Text(
                          shortLabel,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.1,
                            color: firstDone
                                ? (isCurrent ? Colors.black87 : Colors.grey)
                                : Colors.red.shade700,
                          ),
                        ),
                      ),
                    ] else const SizedBox(height: 4),
                    Expanded(
                      child: dayEvents.isEmpty ? const SizedBox.shrink() : Align(
                        alignment: Alignment.bottomLeft,
                        child: Wrap(
                          spacing: 2,
                          runSpacing: 2,
                          children: _buildEventDots(dayEvents),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        _buildLegend(),
      ],
    );
  }

  List<Widget> _buildEventDots(List<Harmonogram> events) {
    // pokaż do 4 kropek, jeśli więcej – ostatnia z liczbą
    const maxDots = 4;
    if (events.length <= maxDots) {
      return events.map((e) => _eventDot(_colorFor(e.frequency), e)).toList();
    }
    final first = events.take(maxDots - 1).map((e) => _eventDot(_colorFor(e.frequency), e));
    return [
      ...first,
      Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text('+${events.length - (maxDots - 1)}', style: const TextStyle(fontSize: 9, color: Colors.white)),
      )
    ];
  }

  Widget _eventDot(Color c, Harmonogram h) => Tooltip(
    message: '${h.frequency ?? '-'} | ${h.maszyna?.nazwa ?? h.dzial?.nazwa ?? ''}',
    child: Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: c.withOpacity(.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c, width: 2),
      ),
    ),
  );

  Widget _buildLegend() {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: _freqValues.map((f) {
        final c = _colorFor(f);
        return Row(
          mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 14, height: 14, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(7))),
              const SizedBox(width: 6),
              Text(f, style: const TextStyle(fontSize: 12)),
            ],
        );
      }).toList(),
    );
  }

  Color _statusColor(String? status) => _statusColors[status] ?? Colors.blueGrey;

  List<Color> _frequencyColors(List<Harmonogram> events) {
    final set = <String>{};
    final colors = <Color>[];
    for (final e in events) {
      final f = e.frequency;
      if (f == null) continue;
      if (set.add(f)) {
        colors.add(_colorFor(f).withOpacity(_strongFill ? .65 : .35));
        if (colors.length == 4) break; // ogranicz gradient do 4 kolorów
      }
    }
    return colors;
  }

  Color? _statusDominant(List<Harmonogram> events) {
    if (events.isEmpty) return null;
    // prosty priorytet: W_TRAKCIE > PLANOWANE > ZAKONCZONE > ANULOWANE
    const order = ['W_TRAKCIE','PLANOWANE','ZAKONCZONE','ANULOWANE'];
    final statuses = events.map((e)=>e.status).toSet();
    for (final o in order) {
      if (statuses.contains(o)) return _statusColor(o);
    }
    return _statusColor(events.first.status);
  }

  BoxDecoration _dayDecoration(List<Harmonogram> dayEvents, bool isCurrent) {
    final baseBorder = BorderRadius.circular(6);
    if (_colorMode == DayColorMode.none || dayEvents.isEmpty) {
      return BoxDecoration(
        color: isCurrent ? Colors.white : Colors.grey.shade100,
        borderRadius: baseBorder,
        border: Border.all(color: isCurrent ? Colors.grey.shade300 : Colors.grey.shade200, width: 1),
      );
    }
    switch (_colorMode) {
      case DayColorMode.dominantFrequency:
        final c = _dominantColorForEvents(dayEvents) ?? Colors.grey;
        final fill = c.withOpacity(_strongFill ? .38 : .18);
        return BoxDecoration(
          color: fill,
          borderRadius: baseBorder,
          border: Border.all(color: c.withOpacity(.55), width: 1),
        );
      case DayColorMode.gradientFrequencies:
        final cols = _frequencyColors(dayEvents);
        if (cols.length <= 1) {
          final single = (cols.isEmpty ? (_dominantColorForEvents(dayEvents) ?? Colors.grey) : cols.first.withOpacity(1));
          return BoxDecoration(
            color: single.withOpacity(_strongFill ? .38 : .18),
            borderRadius: baseBorder,
            border: Border.all(color: single.withOpacity(.6), width: 1),
          );
        }
        return BoxDecoration(
          gradient: LinearGradient(
            colors: cols,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: baseBorder,
          border: Border.all(color: cols.first.withOpacity(.7), width: 1),
        );
      case DayColorMode.status:
        final c = _statusDominant(dayEvents) ?? Colors.grey;
        return BoxDecoration(
          color: c.withOpacity(_strongFill ? .42 : .20),
            borderRadius: baseBorder,
            border: Border.all(color: c.withOpacity(.55), width: 1),
        );
      case DayColorMode.none:
        return BoxDecoration(
          color: isCurrent ? Colors.white : Colors.grey.shade100,
          borderRadius: baseBorder,
          border: Border.all(color: isCurrent ? Colors.grey.shade300 : Colors.grey.shade200, width: 1),
        );
    }
  }

  void _cycleColorMode() {
    setState(() {
      switch (_colorMode) {
        case DayColorMode.none: _colorMode = DayColorMode.dominantFrequency; break;
        case DayColorMode.dominantFrequency: _colorMode = DayColorMode.gradientFrequencies; break;
        case DayColorMode.gradientFrequencies: _colorMode = DayColorMode.status; break;
        case DayColorMode.status: _colorMode = DayColorMode.none; break;
      }
    });
  }

  String _colorModeLabel() {
    switch (_colorMode) {
      case DayColorMode.none: return 'Kolory: brak';
      case DayColorMode.dominantFrequency: return 'Kolor: dom. częst.';
      case DayColorMode.gradientFrequencies: return 'Kolor: gradient';
      case DayColorMode.status: return 'Kolor: status';
    }
  }

  IconData _colorModeIcon() {
    switch (_colorMode) {
      case DayColorMode.none: return Icons.crop_square;
      case DayColorMode.dominantFrequency: return Icons.color_lens_outlined;
      case DayColorMode.gradientFrequencies: return Icons.gradient;
      case DayColorMode.status: return Icons.flag_circle_outlined;
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TopAppBar(
        title: 'Przeglądy',
        showBack: true,
        extraActions: [
          Tooltip(
            message: _colorModeLabel(),
            child: IconButton(
              icon: Icon(_colorModeIcon()),
              onPressed: _loading ? null : _cycleColorMode,
            ),
          ),
          Tooltip(
            message: _strongFill ? 'Wypełnienie: mocne' : 'Wypełnienie: delikatne',
            child: IconButton(
              icon: Icon(_strongFill ? Icons.opacity : Icons.opacity_outlined),
              onPressed: () => setState(() => _strongFill = !_strongFill),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : _openAddDialog,
        icon: const Icon(Icons.add),
        label: const Text('Dodaj'),
      ),
      body: _loading && _items.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadMonth,
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  if (_loadingMeta) const LinearProgressIndicator(minHeight: 3),
                  Card(
                    elevation: 1,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: _buildCalendar(),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

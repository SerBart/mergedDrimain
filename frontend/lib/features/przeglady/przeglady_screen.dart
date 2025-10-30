import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/app_providers.dart';
import '../../core/models/harmonogram.dart';
import '../../core/models/maszyna.dart';
import '../../core/models/dzial.dart';
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd pobierania harmonogramów: $e')),
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
      final maszyny = await adminRepo.getMaszyny();
      final dzialy = await adminRepo.getDzialy();
      setState(() { _maszyny = maszyny; _dzialy = dzialy; });
    } catch (_) {
      // ciche – meta nie blokuje krytycznie
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

  Future<void> _openAddDialog() async {
    DateTime selectedDate = DateTime.now();
    String? frequency = 'MIESIECZNY';
    String opis = '';
    int? maszynaId;
    int? dzialId;
    bool useMaszyna = true; // toggle between maszyna / dzial

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
                  // Data
                  InputDecorator(
                    decoration: const InputDecoration(labelText: 'Data', border: OutlineInputBorder()),
                    child: InkWell(
                      onTap: () async {
                        final now = DateTime.now();
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: selectedDate,
                          firstDate: DateTime(now.year - 1),
                          lastDate: DateTime(now.year + 2),
                        );
                        if (picked != null) setLocal(() => selectedDate = picked);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 18),
                            const SizedBox(width: 8),
                            Text('${selectedDate.year}-${selectedDate.month.toString().padLeft(2,'0')}-${selectedDate.day.toString().padLeft(2,'0')}'),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Częstotliwość
                  DropdownButtonFormField<String>(
                    value: frequency,
                    decoration: const InputDecoration(labelText: 'Częstotliwość', border: OutlineInputBorder()),
                    items: _freqValues.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                    onChanged: (v) => setLocal(() => frequency = v),
                  ),
                  const SizedBox(height: 12),
                  // Typ powiązania
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
                  if (useMaszyna)
                    DropdownButtonFormField<int>(
                      value: maszynaId,
                      decoration: const InputDecoration(labelText: 'Maszyna (opcjonalnie)', border: OutlineInputBorder()),
                      items: _maszyny.map((m) => DropdownMenuItem(value: m.id, child: Text(m.nazwa))).toList(),
                      onChanged: (v) => setLocal(() => maszynaId = v),
                    )
                  else
                    DropdownButtonFormField<int>(
                      value: dzialId,
                      decoration: const InputDecoration(labelText: 'Dział (opcjonalnie)', border: OutlineInputBorder()),
                      items: _dzialy.map((d) => DropdownMenuItem(value: d.id, child: Text(d.nazwa))).toList(),
                      onChanged: (v) => setLocal(() => dzialId = v),
                    ),
                  const SizedBox(height: 12),
                  TextFormField(
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Opis (opcjonalnie)', border: OutlineInputBorder()),
                    onChanged: (v) => opis = v,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Anuluj')),
            FilledButton(
              onPressed: () async {
                if (frequency == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Wybierz częstotliwość')));
                  return;
                }
                try {
                  final repo = ref.read(harmonogramyApiRepositoryProvider);
                  await repo.create(
                    data: selectedDate,
                    maszynaId: useMaszyna ? maszynaId : null,
                    dzialId: useMaszyna ? null : dzialId,
                    frequency: frequency,
                    opis: opis.isNotEmpty ? opis : null,
                  );
                  if (mounted) {
                    Navigator.of(ctx).pop();
                    await _loadMonth();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dodano przegląd')));
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Błąd dodawania: $e')));
                  }
                }
              },
              child: const Text('Zapisz'),
            ),
          ],
        ),
      ),
    );
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
                title: Text(e.opis.isNotEmpty ? e.opis : (e.maszyna?.nazwa ?? e.dzial?.nazwa ?? 'Przegląd')),
                subtitle: Text('${e.frequency ?? '-'} • ${e.status}'),
                trailing: IconButton(
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
                          style: TextStyle(fontSize: 11, height: 1.1, color: isCurrent ? Colors.black87 : Colors.grey),
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

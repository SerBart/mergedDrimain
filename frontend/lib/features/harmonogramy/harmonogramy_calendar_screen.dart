import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/harmonogram.dart';
import '../../core/providers/app_providers.dart';
import '../../widgets/top_app_bar.dart';

class HarmonogramyCalendarScreen extends ConsumerStatefulWidget {
  const HarmonogramyCalendarScreen({super.key});

  @override
  ConsumerState<HarmonogramyCalendarScreen> createState() => _HarmonogramyCalendarScreenState();
}

class _HarmonogramyCalendarScreenState extends ConsumerState<HarmonogramyCalendarScreen> {
  bool _loading = true;
  DateTime _currentMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  List<Harmonogram> _items = const [];

  static const Map<String, Color> _freqColors = {
    'TYGODNIOWY': Colors.blue,
    'MIESIECZNY': Colors.green,
    'KWARTALNY': Colors.orange,
    'POLROCZNY': Colors.purple,
    'ROCZNY': Colors.red,
    'DWULETNI': Colors.teal,
    'PIECIOLETNI': Colors.brown,
  };

  @override
  void initState() {
    super.initState();
    _loadMonth();
  }

  Future<void> _loadMonth() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(harmonogramyApiRepositoryProvider);
      final list = await repo.fetchAll(
        year: _currentMonth.year,
        month: _currentMonth.month,
      );
      if (!mounted) return;
      setState(() => _items = list);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Błąd ładowania harmonogramów: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _prevMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
    });
    _loadMonth();
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
    });
    _loadMonth();
  }

  String _monthTitle(DateTime d) {
    const names = [
      'Styczen',
      'Luty',
      'Marzec',
      'Kwiecien',
      'Maj',
      'Czerwiec',
      'Lipiec',
      'Sierpien',
      'Wrzesien',
      'Pazdziernik',
      'Listopad',
      'Grudzien',
    ];
    return '${names[d.month - 1]} ${d.year}';
  }

  List<DateTime> _calendarDays(DateTime month) {
    final first = DateTime(month.year, month.month, 1);
    final firstWeekday = first.weekday;
    final daysBefore = firstWeekday - 1;
    final firstToShow = first.subtract(Duration(days: daysBefore));
    return List.generate(
      42,
      (i) => DateTime(firstToShow.year, firstToShow.month, firstToShow.day + i),
    );
  }

  List<Harmonogram> _eventsOn(DateTime day) {
    return _items
        .where((h) {
          final d = h.data;
          return d != null && d.year == day.year && d.month == day.month && d.day == day.day;
        })
        .toList();
  }

  Color _colorForFreq(String? frequency) {
    if (frequency == null) return Colors.blueGrey;
    return _freqColors[frequency.toUpperCase()] ?? Colors.blueGrey;
  }

  BoxDecoration _dayDecoration(List<Harmonogram> events, bool isCurrentMonth) {
    final baseBorder = Border.all(color: Colors.black12);
    if (!isCurrentMonth) {
      return BoxDecoration(
        color: Colors.black.withOpacity(.02),
        borderRadius: BorderRadius.circular(8),
        border: baseBorder,
      );
    }
    if (events.isEmpty) {
      return BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: baseBorder,
      );
    }

    final c = _colorForFreq(events.first.frequency);
    return BoxDecoration(
      color: c.withOpacity(.08),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: c.withOpacity(.4)),
    );
  }

  String _fmtDate(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }

  String _eventTitle(Harmonogram h) {
    if (h.opis.trim().isNotEmpty) return h.opis.trim();
    if (h.maszyna?.nazwa != null && h.maszyna!.nazwa.isNotEmpty) return h.maszyna!.nazwa;
    return 'Harmonogram #${h.id}';
  }

  String? _departmentName(Harmonogram h) {
    final machineDepartment = h.maszyna?.dzial?.nazwa?.trim();
    if (machineDepartment != null && machineDepartment.isNotEmpty) {
      return machineDepartment;
    }
    final directDepartment = h.dzial?.nazwa?.trim();
    if (directDepartment != null && directDepartment.isNotEmpty) {
      return directDepartment;
    }
    return null;
  }

  String _shortDesc(Harmonogram h) {
    final parts = <String>[];
    final department = _departmentName(h);
    if (department != null) parts.add('Dział: $department');
    final machine = h.maszyna?.nazwa?.trim();
    if (machine != null && machine.isNotEmpty) parts.add('Maszyna: $machine');
    final person = h.osoba?.imieNazwisko.trim();
    if (person != null && person.isNotEmpty) parts.add('Osoba: $person');

    if (parts.isEmpty) {
      return 'Brak szczegółów';
    }
    return parts.join(' • ');
  }

  String _eventTooltip(Harmonogram h) {
    final lines = <String>[_eventTitle(h)];
    final department = _departmentName(h);
    if (department != null) lines.add('Dział: $department');
    if (h.maszyna != null) lines.add('Maszyna: ${h.maszyna!.nazwa}');
    if (h.osoba != null) lines.add('Osoba: ${h.osoba!.imieNazwisko}');
    if (h.frequency != null && h.frequency!.isNotEmpty) lines.add('Częstotliwość: ${h.frequency}');
    return lines.join('\n');
  }

  Future<void> _deleteItem(Harmonogram h) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Usun wpis'),
        content: Text('Usunac wpis z dnia ${_fmtDate(h.data ?? DateTime.now())}?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Anuluj')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Usun')),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await ref.read(harmonogramyApiRepositoryProvider).delete(h.id);
      await _loadMonth();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Blad usuwania: $e')),
      );
    }
  }

  void _openDayDetails(DateTime day) {
    final events = _eventsOn(day);
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Harmonogramy ${_fmtDate(day)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (events.isEmpty)
                const Text('Brak wpisow w tym dniu')
              else
                ...events.map((e) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    isThreeLine: true,
                    leading: CircleAvatar(radius: 10, backgroundColor: _colorForFreq(e.frequency)),
                    title: Text(
                      _eventTitle(e),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(_shortDesc(e)),
                    trailing: IconButton(
                      tooltip: 'Usun',
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      onPressed: () async {
                        Navigator.of(ctx).pop();
                        await _deleteItem(e);
                      },
                    ),
                  );
                }),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    context.go('/przeglady');
                  },
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Zarzadzaj w Przegladach'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegend() {
    final entries = <MapEntry<String, Color>>[
      ..._freqColors.entries,
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: entries.map((e) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: e.value,
                borderRadius: BorderRadius.circular(7),
              ),
            ),
            const SizedBox(width: 6),
            Text(e.key, style: const TextStyle(fontSize: 12)),
          ],
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final days = _calendarDays(_currentMonth);

    return Scaffold(
      appBar: const TopAppBar(title: 'Harmonogramy', showBack: true),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/przeglady'),
        icon: const Icon(Icons.edit_calendar_outlined),
        label: const Text('Dodaj / Edytuj'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadMonth,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(12),
                children: [
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              IconButton(onPressed: _prevMonth, icon: const Icon(Icons.chevron_left)),
                              Expanded(
                                child: Center(
                                  child: Text(
                                    _monthTitle(_currentMonth),
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ),
                              IconButton(onPressed: _nextMonth, icon: const Icon(Icons.chevron_right)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Row(
                            children: [
                              Expanded(child: Center(child: Text('Pn', style: TextStyle(fontWeight: FontWeight.bold)))),
                              Expanded(child: Center(child: Text('Wt', style: TextStyle(fontWeight: FontWeight.bold)))),
                              Expanded(child: Center(child: Text('Sr', style: TextStyle(fontWeight: FontWeight.bold)))),
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
                              mainAxisExtent: 86,
                            ),
                            itemBuilder: (ctx, i) {
                              final d = days[i];
                              final isCurrent = d.month == _currentMonth.month;
                              final events = _eventsOn(d);
                              return InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () => _openDayDetails(d),
                                child: Container(
                                  margin: const EdgeInsets.all(2),
                                  decoration: _dayDecoration(events, isCurrent),
                                  padding: const EdgeInsets.all(4),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${d.day}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: isCurrent ? Colors.black87 : Colors.grey,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      if (events.isNotEmpty)
                                        Expanded(
                                          child: Align(
                                            alignment: Alignment.bottomLeft,
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: events.take(2).map((e) {
                                                final c = _colorForFreq(e.frequency);
                                                return Padding(
                                                  padding: const EdgeInsets.only(top: 2),
                                                  child: Tooltip(
                                                    message: _eventTooltip(e),
                                                    child: Row(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Container(
                                                          width: 10,
                                                          height: 10,
                                                          margin: const EdgeInsets.only(top: 3),
                                                          decoration: BoxDecoration(
                                                            color: c.withOpacity(.22),
                                                            borderRadius: BorderRadius.circular(5),
                                                            border: Border.all(color: c, width: 1.2),
                                                          ),
                                                        ),
                                                        const SizedBox(width: 4),
                                                        Expanded(
                                                          child: Text(
                                                            _shortDesc(e),
                                                            maxLines: 2,
                                                            overflow: TextOverflow.ellipsis,
                                                            style: const TextStyle(fontSize: 9.5, height: 1.05),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                );
                                              }).toList(),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          _buildLegend(),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 70),
                ],
              ),
            ),
    );
  }
}


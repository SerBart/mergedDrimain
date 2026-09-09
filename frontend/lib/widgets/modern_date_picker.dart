import 'package:flutter/material.dart';

/// Compact, dialog-based date picker with quick actions.
Future<DateTime?> showModernDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  String title = 'Wybierz date',
  bool allowQuickActions = true,
  bool includeTime = false,
  SelectableDayPredicate? selectableDayPredicate,
}) {
  final normalizedInitial = DateUtils.dateOnly(initialDate);
  final normalizedFirst = DateUtils.dateOnly(firstDate);
  final normalizedLast = DateUtils.dateOnly(lastDate);

  return showDialog<DateTime>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => _ModernDatePickerDialog(
      title: title,
      initialDate: normalizedInitial,
      firstDate: normalizedFirst,
      lastDate: normalizedLast,
      initialDateTime: initialDate,
      firstDateTime: firstDate,
      lastDateTime: lastDate,
      allowQuickActions: allowQuickActions,
      includeTime: includeTime,
      selectableDayPredicate: selectableDayPredicate,
    ),
  );
}

class _ModernDatePickerDialog extends StatefulWidget {
  final String title;
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final DateTime initialDateTime;
  final DateTime firstDateTime;
  final DateTime lastDateTime;
  final bool allowQuickActions;
  final bool includeTime;
  final SelectableDayPredicate? selectableDayPredicate;

  const _ModernDatePickerDialog({
    required this.title,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.initialDateTime,
    required this.firstDateTime,
    required this.lastDateTime,
    required this.allowQuickActions,
    required this.includeTime,
    this.selectableDayPredicate,
  });

  @override
  State<_ModernDatePickerDialog> createState() => _ModernDatePickerDialogState();
}

class _ModernDatePickerDialogState extends State<_ModernDatePickerDialog> {
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;

  @override
  void initState() {
    super.initState();
    final initialDateTime = _clampDateTime(widget.initialDateTime);
    _selectedDate = DateUtils.dateOnly(initialDateTime);
    _selectedTime = TimeOfDay.fromDateTime(initialDateTime);
  }

  DateTime _selectedDateTime() => DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

  DateTime _clampDateTime(DateTime value) {
    if (value.isBefore(widget.firstDateTime)) return widget.firstDateTime;
    if (value.isAfter(widget.lastDateTime)) return widget.lastDateTime;
    return value;
  }

  void _clampSelectionToBounds() {
    final clamped = _clampDateTime(_selectedDateTime());
    _selectedDate = DateUtils.dateOnly(clamped);
    _selectedTime = TimeOfDay.fromDateTime(clamped);
  }

  DateTime _clamp(DateTime date) {
    if (date.isBefore(widget.firstDate)) return widget.firstDate;
    if (date.isAfter(widget.lastDate)) return widget.lastDate;
    return date;
  }

  bool _isSelectable(DateTime date) {
    final normalized = DateUtils.dateOnly(date);
    if (normalized.isBefore(widget.firstDate) || normalized.isAfter(widget.lastDate)) {
      return false;
    }
    final predicate = widget.selectableDayPredicate;
    return predicate == null ? true : predicate(normalized);
  }

  DateTime _findSelectable(DateTime preferred) {
    var candidate = _clamp(preferred);
    if (_isSelectable(candidate)) return candidate;

    for (var i = 1; i <= 3660; i++) {
      final plus = candidate.add(Duration(days: i));
      if (!plus.isAfter(widget.lastDate) && _isSelectable(plus)) return plus;
      final minus = candidate.subtract(Duration(days: i));
      if (!minus.isBefore(widget.firstDate) && _isSelectable(minus)) return minus;
      if (plus.isAfter(widget.lastDate) && minus.isBefore(widget.firstDate)) break;
    }
    return candidate;
  }

  void _applyQuickDate(DateTime date) {
    setState(() {
      _selectedDate = _findSelectable(date);
      _clampSelectionToBounds();
    });
  }

  Widget _quickChip(String label, DateTime value) {
    return ActionChip(
      avatar: const Icon(Icons.auto_awesome, size: 16),
      label: Text(label),
      onPressed: () => _applyQuickDate(value),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  String _pad2(int value) => value.toString().padLeft(2, '0');

  void _updateHour(int? hour) {
    if (hour == null) return;
    setState(() {
      _selectedTime = TimeOfDay(hour: hour, minute: _selectedTime.minute);
      _clampSelectionToBounds();
    });
  }

  void _updateMinute(int? minute) {
    if (minute == null) return;
    setState(() {
      _selectedTime = TimeOfDay(hour: _selectedTime.hour, minute: minute);
      _clampSelectionToBounds();
    });
  }

  Widget _minuteChip(int minute) {
    final selected = _selectedTime.minute == minute;
    return ChoiceChip(
      label: Text(_pad2(minute)),
      selected: selected,
      onSelected: (_) => _updateMinute(minute),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateUtils.dateOnly(DateTime.now());
    final monthEnd = DateTime(_selectedDate.year, _selectedDate.month + 1, 0);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.surface,
                theme.colorScheme.primary.withOpacity(0.05),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.calendar_month_rounded, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Zamknij',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (widget.allowQuickActions) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _quickChip('Dzisiaj', now),
                      _quickChip('Jutro', now.add(const Duration(days: 1))),
                      _quickChip('+7 dni', now.add(const Duration(days: 7))),
                      _quickChip('Koniec miesiaca', monthEnd),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
                Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: CalendarDatePicker(
                    initialDate: _selectedDate,
                    firstDate: widget.firstDate,
                    lastDate: widget.lastDate,
                    selectableDayPredicate: widget.selectableDayPredicate,
                    onDateChanged: (date) => setState(() {
                      _selectedDate = date;
                      _clampSelectionToBounds();
                    }),
                  ),
                ),
                if (widget.includeTime) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: theme.colorScheme.outlineVariant),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.schedule_rounded, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Godzina: ${_pad2(_selectedTime.hour)}:${_pad2(_selectedTime.minute)}',
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                value: _selectedTime.hour,
                                decoration: const InputDecoration(
                                  labelText: 'Godzina',
                                  border: OutlineInputBorder(),
                                ),
                                items: List.generate(
                                  24,
                                  (hour) => DropdownMenuItem<int>(
                                    value: hour,
                                    child: Text(_pad2(hour)),
                                  ),
                                ),
                                onChanged: _updateHour,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                value: _selectedTime.minute,
                                decoration: const InputDecoration(
                                  labelText: 'Minuta',
                                  border: OutlineInputBorder(),
                                ),
                                items: List.generate(
                                  60,
                                  (minute) => DropdownMenuItem<int>(
                                    value: minute,
                                    child: Text(_pad2(minute)),
                                  ),
                                ),
                                onChanged: _updateMinute,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _minuteChip(0),
                            _minuteChip(15),
                            _minuteChip(30),
                            _minuteChip(45),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Anuluj'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      icon: const Icon(Icons.check_rounded),
                      onPressed: _isSelectable(_selectedDate)
                          ? () => Navigator.of(context).pop(
                                widget.includeTime
                                    ? _clampDateTime(_selectedDateTime())
                                    : DateUtils.dateOnly(_selectedDate),
                              )
                          : null,
                      label: const Text('Wybierz'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


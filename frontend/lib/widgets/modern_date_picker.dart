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
  final bool allowQuickActions;
  final bool includeTime;
  final SelectableDayPredicate? selectableDayPredicate;

  const _ModernDatePickerDialog({
    required this.title,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
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
    _selectedDate = _clamp(widget.initialDate);
    _selectedTime = TimeOfDay.fromDateTime(widget.initialDate);
  }

  DateTime _selectedDateTime() => DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

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
    setState(() => _selectedDate = _findSelectable(date));
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      helpText: 'Wybierz godzine',
      cancelText: 'Anuluj',
      confirmText: 'OK',
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Widget _quickChip(String label, DateTime value) {
    return ActionChip(
      avatar: const Icon(Icons.auto_awesome, size: 16),
      label: Text(label),
      onPressed: () => _applyQuickDate(value),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                    onDateChanged: (date) => setState(() => _selectedDate = date),
                  ),
                ),
                if (widget.includeTime) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.schedule_rounded, size: 18),
                      const SizedBox(width: 8),
                      Text('Godzina: ${_selectedTime.format(context)}'),
                      const Spacer(),
                      OutlinedButton.icon(
                        onPressed: _pickTime,
                        icon: const Icon(Icons.edit_calendar_outlined),
                        label: const Text('Zmien'),
                      ),
                    ],
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
                                    ? _selectedDateTime()
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


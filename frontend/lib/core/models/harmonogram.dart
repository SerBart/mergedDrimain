import 'dzial.dart';
import 'maszyna.dart';
import 'osoba.dart';

class Harmonogram {
  final int id;
  final DateTime? data;
  final Maszyna? maszyna;
  final Osoba? osoba;
  final Dzial? dzial;
  final int? durationMinutes;
  final String opis;
  final String status;
  final String? frequency; // TYGODNIOWY / MIESIECZNY / KWARTALNY / POLROCZNY / ROCZNY / DWULETNI / PIECIOLETNI
  final DateTime? planEndDate;
  final String? seriesId;

  const Harmonogram({
    required this.id,
    this.data,
    this.maszyna,
    this.osoba,
    this.dzial,
    this.durationMinutes,
    this.opis = '',
    this.status = 'PLANOWANE',
    this.frequency,
    this.planEndDate,
    this.seriesId,
  });

  factory Harmonogram.fromJson(Map<String, dynamic> json) {
    return Harmonogram(
      id: _toInt(json['id']) ?? 0,
      data: _toDate(json['data']),
      maszyna: _toMap(json['maszyna']) != null
          ? Maszyna.fromJson(_toMap(json['maszyna'])!)
          : null,
      osoba: _toMap(json['osoba']) != null
          ? Osoba.fromJson(_toMap(json['osoba'])!)
          : null,
      dzial: _toMap(json['dzial']) != null
          ? Dzial.fromJson(_toMap(json['dzial'])!)
          : null,
      durationMinutes: _toInt(json['durationMinutes']),
      opis: (json['opis'] ?? '').toString(),
      status: (json['status'] ?? 'PLANOWANE').toString(),
      frequency: json['frequency']?.toString(),
      planEndDate: _toDate(json['planEndDate']),
      seriesId: json['seriesId']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (data != null) 'data': _formatDateOnly(data!),
      if (maszyna != null) 'maszyna': maszyna!.toJson(),
      if (osoba != null) 'osoba': osoba!.toJson(),
      if (dzial != null) 'dzial': dzial!.toJson(),
      if (durationMinutes != null) 'durationMinutes': durationMinutes,
      'opis': opis,
      'status': status,
      if (frequency != null) 'frequency': frequency,
      if (planEndDate != null) 'planEndDate': _formatDateOnly(planEndDate!),
      if (seriesId != null) 'seriesId': seriesId,
    };
  }

  static Map<String, dynamic>? _toMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.cast<String, dynamic>();
    return null;
  }

  static int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static DateTime? _toDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;

    final raw = value.toString().trim();
    if (raw.isEmpty) return null;

    final parsed = DateTime.tryParse(raw);
    if (parsed != null) return parsed;

    final normalized = raw.replaceAll('/', '-');
    final parts = normalized.split('-');
    if (parts.length == 3) {
      final y = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      final d = int.tryParse(parts[2]);
      if (y != null && m != null && d != null) {
        return DateTime(y, m, d);
      }
    }
    return null;
  }

  static String _formatDateOnly(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }
}

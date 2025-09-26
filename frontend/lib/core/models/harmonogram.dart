import 'maszyna.dart';
import 'osoba.dart';
import 'dzial.dart';

class Harmonogram {
  final int id;
  final DateTime? data; // tylko data (bez czasu)
  final String opis;
  final Maszyna? maszyna;
  final Osoba? osoba;
  final String status; // PLANOWANE / W TRAKCIE / ZAKONCZONE (z backendu enum)
  final int? durationMinutes;
  final String? frequency; // TYGODNIOWY / MIESIECZNY / KWARTALNY / POLROCZNY / ROCZNY
  final Dzial? dzial;

  Harmonogram({
    required this.id,
    required this.data,
    required this.opis,
    required this.maszyna,
    required this.osoba,
    required this.status,
    required this.durationMinutes,
    required this.frequency,
    required this.dzial,
  });

  factory Harmonogram.fromJson(Map<String, dynamic> j) {
    final String? dataStr = j['data'] as String?;
    DateTime? d;
    if (dataStr != null && dataStr.isNotEmpty) {
      // LocalDate -> "YYYY-MM-DD"
      d = DateTime.tryParse(dataStr);
    }
    return Harmonogram(
      id: (j['id'] as num?)?.toInt() ?? 0,
      data: d,
      opis: (j['opis'] ?? '').toString(),
      maszyna: j['maszyna'] != null ? Maszyna.fromJson(j['maszyna']) : null,
      osoba: j['osoba'] != null ? Osoba.fromJson(j['osoba']) : null,
      status: (j['status'] ?? '').toString(),
      durationMinutes: (j['durationMinutes'] as num?)?.toInt(),
      frequency: (j['frequency'] ?? j['freq'])?.toString(),
      dzial: j['dzial'] != null ? Dzial.fromJson(j['dzial']) : null,
    );
  }
}

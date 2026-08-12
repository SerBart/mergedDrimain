class DashboardKpi {
  final int zgloszeniaDzisNowe;
  final int zgloszeniaDzisWToku;
  final int zgloszeniaDzisZamkniete;
  final int raportyDzis;
  final int raporty7Dni;
  final double sredniCzasRozwiazaniaGodziny;
  final int maszynyWPrzestoju;
  final int maszynyWPracy;
  final int maszynyRazem;
  final Map<String, int> topTypyZgloszen;
  final Map<String, int> zgloszeniaByStatus;
  final Map<String, int> raportyByStatus;
  final DateTime? lastUpdated;

  DashboardKpi({
    required this.zgloszeniaDzisNowe,
    required this.zgloszeniaDzisWToku,
    required this.zgloszeniaDzisZamkniete,
    required this.raportyDzis,
    required this.raporty7Dni,
    required this.sredniCzasRozwiazaniaGodziny,
    required this.maszynyWPrzestoju,
    required this.maszynyWPracy,
    required this.maszynyRazem,
    required this.topTypyZgloszen,
    required this.zgloszeniaByStatus,
    required this.raportyByStatus,
    this.lastUpdated,
  });

  factory DashboardKpi.fromJson(Map<String, dynamic> json) {
    Map<String, int> mapToIntMap(dynamic value) {
      if (value is! Map) return const {};
      return value.map((k, v) => MapEntry(k.toString(), (v as num?)?.toInt() ?? 0));
    }

    DateTime? parseDate(dynamic raw) {
      if (raw is! String || raw.isEmpty) return null;
      try {
        return DateTime.parse(raw);
      } catch (_) {
        return null;
      }
    }

    return DashboardKpi(
      zgloszeniaDzisNowe: (json['zgloszeniaDzisNowe'] as num?)?.toInt() ?? 0,
      zgloszeniaDzisWToku: (json['zgloszeniaDzisWToku'] as num?)?.toInt() ?? 0,
      zgloszeniaDzisZamkniete: (json['zgloszeniaDzisZamkniete'] as num?)?.toInt() ?? 0,
      raportyDzis: (json['raportyDzis'] as num?)?.toInt() ?? 0,
      raporty7Dni: (json['raporty7Dni'] as num?)?.toInt() ?? 0,
      sredniCzasRozwiazaniaGodziny: (json['sredniCzasRozwiazaniaGodziny'] as num?)?.toDouble() ?? 0.0,
      maszynyWPrzestoju: (json['maszynyWPrzestoju'] as num?)?.toInt() ?? 0,
      maszynyWPracy: (json['maszynyWPracy'] as num?)?.toInt() ?? 0,
      maszynyRazem: (json['maszynyRazem'] as num?)?.toInt() ?? 0,
      topTypyZgloszen: mapToIntMap(json['topTypyZgloszen']),
      zgloszeniaByStatus: mapToIntMap(json['zgloszeniaByStatus']),
      raportyByStatus: mapToIntMap(json['raportyByStatus']),
      lastUpdated: parseDate(json['lastUpdated']),
    );
  }
}


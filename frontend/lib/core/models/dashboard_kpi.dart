class DashboardKpi {
  final int zakresDni;
  final DateTime? okresOd;
  final DateTime? okresDo;
  final int zgloszeniaWOkresieNowe;
  final int zgloszeniaWOkresieWToku;
  final int zgloszeniaWOkresieZamkniete;
  final int raportyWOkresie;
  final int zgloszeniaWPoprzednimOkresie;
  final int raportyWPoprzednimOkresie;
  final double zgloszeniaZmianaProcent;
  final double raportyZmianaProcent;
  final List<DashboardTrendPoint> zgloszeniaTrend;
  final List<DashboardTrendPoint> raportyTrend;
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
    required this.zakresDni,
    this.okresOd,
    this.okresDo,
    required this.zgloszeniaWOkresieNowe,
    required this.zgloszeniaWOkresieWToku,
    required this.zgloszeniaWOkresieZamkniete,
    required this.raportyWOkresie,
    required this.zgloszeniaWPoprzednimOkresie,
    required this.raportyWPoprzednimOkresie,
    required this.zgloszeniaZmianaProcent,
    required this.raportyZmianaProcent,
    required this.zgloszeniaTrend,
    required this.raportyTrend,
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

    List<DashboardTrendPoint> mapTrendList(dynamic value) {
      if (value is! List) return const [];
      return value
          .whereType<Map>()
          .map((item) => DashboardTrendPoint.fromJson(item.cast<String, dynamic>()))
          .toList();
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
      zakresDni: (json['zakresDni'] as num?)?.toInt() ?? 7,
      okresOd: parseDate(json['okresOd']),
      okresDo: parseDate(json['okresDo']),
      zgloszeniaWOkresieNowe: (json['zgloszeniaWOkresieNowe'] as num?)?.toInt() ?? (json['zgloszeniaDzisNowe'] as num?)?.toInt() ?? 0,
      zgloszeniaWOkresieWToku: (json['zgloszeniaWOkresieWToku'] as num?)?.toInt() ?? (json['zgloszeniaDzisWToku'] as num?)?.toInt() ?? 0,
      zgloszeniaWOkresieZamkniete: (json['zgloszeniaWOkresieZamkniete'] as num?)?.toInt() ?? (json['zgloszeniaDzisZamkniete'] as num?)?.toInt() ?? 0,
      raportyWOkresie: (json['raportyWOkresie'] as num?)?.toInt() ?? (json['raporty7Dni'] as num?)?.toInt() ?? (json['raportyDzis'] as num?)?.toInt() ?? 0,
      zgloszeniaWPoprzednimOkresie: (json['zgloszeniaWPoprzednimOkresie'] as num?)?.toInt() ?? 0,
      raportyWPoprzednimOkresie: (json['raportyWPoprzednimOkresie'] as num?)?.toInt() ?? 0,
      zgloszeniaZmianaProcent: (json['zgloszeniaZmianaProcent'] as num?)?.toDouble() ?? 0.0,
      raportyZmianaProcent: (json['raportyZmianaProcent'] as num?)?.toDouble() ?? 0.0,
      zgloszeniaTrend: mapTrendList(json['zgloszeniaTrend']),
      raportyTrend: mapTrendList(json['raportyTrend']),
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

class DashboardTrendPoint {
  final DateTime date;
  final int count;

  const DashboardTrendPoint({required this.date, required this.count});

  factory DashboardTrendPoint.fromJson(Map<String, dynamic> json) {
    final rawDate = json['date'];
    final parsed = rawDate is String ? DateTime.tryParse(rawDate) : null;
    final date = parsed ?? DateTime.now();
    return DashboardTrendPoint(
      date: DateTime(date.year, date.month, date.day),
      count: (json['count'] as num?)?.toInt() ?? 0,
    );
  }
}


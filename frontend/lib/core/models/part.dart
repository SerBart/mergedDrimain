class Part {
  final int id;
  final String nazwa;
  final String kod;
  int iloscMagazyn;
  final int minIlosc;
  final String jednostka;
  final String? kategoria; // nowość (typ / grupa)
  final int? maszynaId; // assigned machine id (null => Inne)
  final String? maszynaNazwa; // assigned machine name
  final DateTime? dataZakupu;
  final DateTime? dataRealizacji;
  final double? cena;

  Part({
    required this.id,
    required this.nazwa,
    required this.kod,
    required this.iloscMagazyn,
    required this.minIlosc,
    required this.jednostka,
    this.kategoria,
    this.maszynaId,
    this.maszynaNazwa,
    this.dataZakupu,
    this.dataRealizacji,
    this.cena,
  });

  factory Part.fromJson(Map<String, dynamic> json) => Part(
        id: (json['id'] as num?)?.toInt() ?? 0,
        nazwa: json['nazwa']?.toString() ?? '',
        kod: json['kod']?.toString() ?? '',
        iloscMagazyn: (json['ilosc'] as num?)?.toInt() ?? 0,
        minIlosc: (json['minIlosc'] as num?)?.toInt() ?? 0,
        jednostka: json['jednostka']?.toString() ?? 'szt',
        kategoria: json['kategoria']?.toString(),
        maszynaId: (json['maszynaId'] as num?)?.toInt(),
        maszynaNazwa: json['maszynaNazwa']?.toString(),
        dataZakupu: _tryParseDate(json['dataZakupu']),
        dataRealizacji: _tryParseDate(json['dataRealizacji']),
        cena: (json['cena'] as num?)?.toDouble(),
      );

  bool get belowMin => iloscMagazyn <= minIlosc;

  Part copyWith({
    int? id,
    String? nazwa,
    String? kod,
    int? iloscMagazyn,
    int? minIlosc,
    String? jednostka,
    String? kategoria,
    int? maszynaId,
    String? maszynaNazwa,
    DateTime? dataZakupu,
    DateTime? dataRealizacji,
    double? cena,
  }) {
    return Part(
      id: id ?? this.id,
      nazwa: nazwa ?? this.nazwa,
      kod: kod ?? this.kod,
      iloscMagazyn: iloscMagazyn ?? this.iloscMagazyn,
      minIlosc: minIlosc ?? this.minIlosc,
      jednostka: jednostka ?? this.jednostka,
      kategoria: kategoria ?? this.kategoria,
      maszynaId: maszynaId ?? this.maszynaId,
      maszynaNazwa: maszynaNazwa ?? this.maszynaNazwa,
      dataZakupu: dataZakupu ?? this.dataZakupu,
      dataRealizacji: dataRealizacji ?? this.dataRealizacji,
      cena: cena ?? this.cena,
    );
  }

  static DateTime? _tryParseDate(dynamic raw) {
    if (raw == null) return null;
    final text = raw.toString().trim();
    if (text.isEmpty) return null;
    return DateTime.tryParse(text);
  }

  static String? isoDate(DateTime? date) {
    if (date == null) return null;
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '${date.year}-$m-$d';
  }
}
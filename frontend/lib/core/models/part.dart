class Part {
  final int id;
  final String nazwa;
  final String kod;
  int iloscMagazyn;
  final int minIlosc;
  final String jednostka;
  final String? kategoria; // nowość (typ / grupa)

  Part({
    required this.id,
    required this.nazwa,
    required this.kod,
    required this.iloscMagazyn,
    required this.minIlosc,
    required this.jednostka,
    this.kategoria,
  });

  bool get belowMin => iloscMagazyn <= minIlosc;

  Part copyWith({
    int? id,
    String? nazwa,
    String? kod,
    int? iloscMagazyn,
    int? minIlosc,
    String? jednostka,
    String? kategoria,
  }) {
    return Part(
      id: id ?? this.id,
      nazwa: nazwa ?? this.nazwa,
      kod: kod ?? this.kod,
      iloscMagazyn: iloscMagazyn ?? this.iloscMagazyn,
      minIlosc: minIlosc ?? this.minIlosc,
      jednostka: jednostka ?? this.jednostka,
      kategoria: kategoria ?? this.kategoria,
    );
  }
}
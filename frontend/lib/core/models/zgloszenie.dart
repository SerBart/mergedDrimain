class Zgloszenie {
  final int id;
  final String imie;
  final String nazwisko;
  final String typ;         // AWARIA / SERWIS / INNE
  final DateTime dataGodzina;
  final String opis;
  final String status;      // NOWE / W TOKU / WERYFIKACJA / ZAMKNIĘTE
  final String? photoBase64;
  final DateTime lastUpdated;

  Zgloszenie({
    required this.id,
    required this.imie,
    required this.nazwisko,
    required this.typ,
    required this.dataGodzina,
    required this.opis,
    this.status = 'NOWE',
    this.photoBase64,
    DateTime? lastUpdated,
  }) : lastUpdated = lastUpdated ?? DateTime.now();

  Zgloszenie copyWith({
    int? id,
    String? imie,
    String? nazwisko,
    String? typ,
    DateTime? dataGodzina,
    String? opis,
    String? status,
    String? photoBase64,
    DateTime? lastUpdated,
  }) {
    return Zgloszenie(
      id: id ?? this.id,
      imie: imie ?? this.imie,
      nazwisko: nazwisko ?? this.nazwisko,
      typ: typ ?? this.typ,
      dataGodzina: dataGodzina ?? this.dataGodzina,
      opis: opis ?? this.opis,
      status: status ?? this.status,
      photoBase64: photoBase64 ?? this.photoBase64,
      lastUpdated: lastUpdated ?? DateTime.now(),
    );
  }
}
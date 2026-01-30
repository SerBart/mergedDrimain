import 'maszyna.dart';

class Zgloszenie {
  final int id;
  final String imie;
  final String nazwisko;
  final String typ;         // AWARIA / SERWIS / INNE
  final String temat;       // nowe pole - temat zgłoszenia
  final DateTime dataGodzina;
  final String opis;
  final String status;      // NOWE / W TOKU / WERYFIKACJA / ZAMKNIĘTE
  final String? photoBase64;
  final DateTime lastUpdated;
  final DateTime? acceptedAt; // moment podjęcia naprawy
  final DateTime? completedAt; // moment zakończenia naprawy
  final Maszyna? maszyna; // wybrana maszyna (z działem)

  Zgloszenie({
    required this.id,
    required this.imie,
    required this.nazwisko,
    required this.typ,
    required this.temat,
    required this.dataGodzina,
    required this.opis,
    this.status = 'NOWE',
    this.photoBase64,
    DateTime? lastUpdated,
    this.acceptedAt,
    this.completedAt,
    this.maszyna,
  }) : lastUpdated = lastUpdated ?? DateTime.now();

  Zgloszenie copyWith({
    int? id,
    String? imie,
    String? nazwisko,
    String? typ,
    String? temat,
    DateTime? dataGodzina,
    String? opis,
    String? status,
    String? photoBase64,
    DateTime? lastUpdated,
    DateTime? acceptedAt,
    DateTime? completedAt,
    Maszyna? maszyna,
    bool setNullPhoto = false,
    bool setNullAccepted = false,
    bool setNullCompleted = false,
    bool setNullMaszyna = false,
  }) {
    return Zgloszenie(
      id: id ?? this.id,
      imie: imie ?? this.imie,
      nazwisko: nazwisko ?? this.nazwisko,
      typ: typ ?? this.typ,
      temat: temat ?? this.temat,
      dataGodzina: dataGodzina ?? this.dataGodzina,
      opis: opis ?? this.opis,
      status: status ?? this.status,
      photoBase64: setNullPhoto ? null : (photoBase64 ?? this.photoBase64),
      lastUpdated: lastUpdated ?? DateTime.now(),
      acceptedAt: setNullAccepted ? null : (acceptedAt ?? this.acceptedAt),
      completedAt: setNullCompleted ? null : (completedAt ?? this.completedAt),
      maszyna: setNullMaszyna ? null : (maszyna ?? this.maszyna),
    );
  }
}
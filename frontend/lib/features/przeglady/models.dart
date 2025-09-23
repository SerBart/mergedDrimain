class Przeglad {
  final String id;
  final String? data;
  final String? typ;
  final String? opis;
  final String? status;
  final String? maszyna;
  final String? osoba;

  Przeglad({
    required this.id,
    this.data,
    this.typ,
    this.opis,
    this.status,
    this.maszyna,
    this.osoba,
  });

  static Przeglad fromJson(Map<String, dynamic> j) => Przeglad(
    id: j['id'].toString(),
    data: j['data']?.toString(),
    typ: j['typ']?.toString(),
    opis: j['opis']?.toString(),
    status: j['status']?.toString(),
    maszyna: j['maszyna']?['nazwa']?.toString(),
    osoba: j['osoba']?['imieNazwisko']?.toString(),
  );
}
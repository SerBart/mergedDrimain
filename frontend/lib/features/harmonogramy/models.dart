class Harmonogram {
  final String id;
  final String? data;
  final String? opis;
  final String? status;
  final String? maszyna;
  final String? osoba;
  Harmonogram({
    required this.id,
    this.data,
    this.opis,
    this.status,
    this.maszyna,
    this.osoba,
  });

  static Harmonogram fromJson(Map<String, dynamic> j) => Harmonogram(
    id: j['id'].toString(),
    data: j['data']?.toString(),
    opis: j['opis']?.toString(),
    status: j['status']?.toString(),
    maszyna: j['maszyna']?['nazwa']?.toString(),
    osoba: j['osoba']?['imieNazwisko']?.toString(),
  );
}
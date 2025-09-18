class Osoba {
  final int id;
  final String imieNazwisko;

  Osoba({required this.id, required this.imieNazwisko});

  factory Osoba.fromJson(Map<String, dynamic> j) =>
      Osoba(id: j['id'] ?? 0, imieNazwisko: j['imieNazwisko'] ?? '');

  Map<String, dynamic> toJson() => {'id': id, 'imieNazwisko': imieNazwisko};
}
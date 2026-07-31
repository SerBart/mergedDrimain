class Osoba {
  final int id;
  final String imieNazwisko;
  final String? login;
  final String? rola;
  final int? dzialId;
  final String? dzialNazwa;

  Osoba({
    required this.id,
    required this.imieNazwisko,
    this.login,
    this.rola,
    this.dzialId,
    this.dzialNazwa,
  });

  factory Osoba.fromJson(Map<String, dynamic> j) => Osoba(
        id: (j['id'] as num?)?.toInt() ?? 0,
        imieNazwisko: (j['imieNazwisko'] ?? '').toString(),
        login: j['login']?.toString(),
        rola: j['rola']?.toString(),
        dzialId: (j['dzialId'] as num?)?.toInt(),
        dzialNazwa: j['dzialNazwa']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'imieNazwisko': imieNazwisko,
        if (login != null) 'login': login,
        if (rola != null) 'rola': rola,
        if (dzialId != null) 'dzialId': dzialId,
        if (dzialNazwa != null) 'dzialNazwa': dzialNazwa,
      };
}
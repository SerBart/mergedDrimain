class Raport {
  final String id;
  final String? opis;
  final String? status;
  final String? dataNaprawy;
  final String? maszyna;
  Raport({required this.id, this.opis, this.status, this.dataNaprawy, this.maszyna});

  static Raport fromJson(Map<String, dynamic> j) => Raport(
    id: j['id'].toString(),
    opis: j['opis']?.toString(),
    status: j['status']?.toString(),
    dataNaprawy: j['dataNaprawy']?.toString(),
    maszyna: j['maszyna']?['nazwa']?.toString(),
  );
}
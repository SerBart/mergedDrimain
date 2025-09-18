import 'maszyna.dart';
import 'osoba.dart';
import 'part_usage.dart';

class Raport {
  final int id;
  final Maszyna? maszyna;
  final String typNaprawy;
  final String opis;
  final Osoba? osoba;
  final String status;
  final DateTime dataNaprawy;
  final DateTime czasOd;
  final DateTime czasDo;
  final List<PartUsage> partUsages;
  final String? photoBase64; // opcjonalne zdjęcie (demo)

  Raport({
    required this.id,
    required this.maszyna,
    required this.typNaprawy,
    required this.opis,
    required this.osoba,
    required this.status,
    required this.dataNaprawy,
    required this.czasOd,
    required this.czasDo,
    this.partUsages = const [],
    this.photoBase64,
  });

  Raport copyWith({
    int? id,
    Maszyna? maszyna,
    String? typNaprawy,
    String? opis,
    Osoba? osoba,
    String? status,
    DateTime? dataNaprawy,
    DateTime? czasOd,
    DateTime? czasDo,
    List<PartUsage>? partUsages,
    String? photoBase64,
  }) {
    return Raport(
      id: id ?? this.id,
      maszyna: maszyna ?? this.maszyna,
      typNaprawy: typNaprawy ?? this.typNaprawy,
      opis: opis ?? this.opis,
      osoba: osoba ?? this.osoba,
      status: status ?? this.status,
      dataNaprawy: dataNaprawy ?? this.dataNaprawy,
      czasOd: czasOd ?? this.czasOd,
      czasDo: czasDo ?? this.czasDo,
      partUsages: partUsages ?? this.partUsages,
      photoBase64: photoBase64 ?? this.photoBase64,
    );
  }
}
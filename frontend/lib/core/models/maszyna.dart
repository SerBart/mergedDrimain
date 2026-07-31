import 'dzial.dart';
import 'sekcja.dart';

class Maszyna {
  final int id;
  final String nazwa;
  final Dzial? dzial;
  final Sekcja? sekcja;

  Maszyna({required this.id, required this.nazwa, this.dzial, this.sekcja});

  factory Maszyna.fromJson(Map<String, dynamic> j) => Maszyna(
        id: j['id'] ?? 0,
        nazwa: j['nazwa'] ?? '',
        dzial: j['dzial'] != null ? Dzial.fromJson(j['dzial']) : null,
        sekcja: j['sekcja'] != null ? Sekcja.fromJson(j['sekcja']) : null,
      );

  Map<String, dynamic> toJson() =>
      {
        'id': id,
        'nazwa': nazwa,
        'dzial': dzial?.toJson(),
        'sekcja': sekcja?.toJson(),
      };
}
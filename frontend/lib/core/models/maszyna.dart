import 'dzial.dart';
import 'sekcja.dart';

class Maszyna {
  final int id;
  final String nazwa;
  final Dzial? dzial;
  final List<Sekcja> sekcje;

  // Kompatybilność ze starszym kodem: zwracamy sekcję główną jako pierwszą.
  Sekcja? get sekcja => sekcje.isEmpty ? null : sekcje.first;

  Maszyna({required this.id, required this.nazwa, this.dzial, this.sekcje = const []});

  factory Maszyna.fromJson(Map<String, dynamic> j) => Maszyna(
        id: j['id'] ?? 0,
        nazwa: j['nazwa'] ?? '',
        dzial: j['dzial'] != null ? Dzial.fromJson(j['dzial']) : null,
        sekcje: (() {
          if (j['sekcje'] is List) {
            return (j['sekcje'] as List)
                .whereType<Map>()
                .map((s) => Sekcja.fromJson(s.cast<String, dynamic>()))
                .toList();
          }
          if (j['sekcja'] != null && j['sekcja'] is Map) {
            return [Sekcja.fromJson((j['sekcja'] as Map).cast<String, dynamic>())];
          }
          return <Sekcja>[];
        })(),
      );

  Map<String, dynamic> toJson() =>
      {
        'id': id,
        'nazwa': nazwa,
        'dzial': dzial?.toJson(),
        'sekcja': sekcja?.toJson(),
        'sekcje': sekcje.map((s) => s.toJson()).toList(),
      };
}
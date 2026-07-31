import 'dzial.dart';

class Sekcja {
  final int id;
  final String nazwa;
  final Dzial? dzial;

  Sekcja({required this.id, required this.nazwa, this.dzial});

  factory Sekcja.fromJson(Map<String, dynamic> j) => Sekcja(
        id: (j['id'] as num?)?.toInt() ?? 0,
        nazwa: (j['nazwa'] ?? '').toString(),
        dzial: j['dzial'] is Map<String, dynamic>
            ? Dzial.fromJson((j['dzial'] as Map).cast<String, dynamic>())
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'nazwa': nazwa,
        if (dzial != null) 'dzial': dzial!.toJson(),
      };
}


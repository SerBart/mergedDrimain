import 'dzial.dart';

class Sekcja {
  final int id;
  final String nazwa;
  final Dzial? dzial;
  final int? maszynaId;
  final String? maszynaNazwa;

  Sekcja({required this.id, required this.nazwa, this.dzial, this.maszynaId, this.maszynaNazwa});

  factory Sekcja.fromJson(Map<String, dynamic> j) => Sekcja(
        id: (j['id'] as num?)?.toInt() ?? 0,
        nazwa: (j['nazwa'] ?? '').toString(),
        dzial: j['dzial'] is Map<String, dynamic>
            ? Dzial.fromJson((j['dzial'] as Map).cast<String, dynamic>())
            : null,
        maszynaId: (j['maszynaId'] as num?)?.toInt(),
        maszynaNazwa: j['maszynaNazwa']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'nazwa': nazwa,
        if (dzial != null) 'dzial': dzial!.toJson(),
        if (maszynaId != null) 'maszynaId': maszynaId,
        if (maszynaNazwa != null) 'maszynaNazwa': maszynaNazwa,
      };
}


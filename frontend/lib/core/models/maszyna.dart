import 'dzial.dart';

class Maszyna {
  final int id;
  final String nazwa;
  final Dzial? dzial;

  Maszyna({required this.id, required this.nazwa, this.dzial});

  factory Maszyna.fromJson(Map<String, dynamic> j) => Maszyna(
        id: j['id'] ?? 0,
        nazwa: j['nazwa'] ?? '',
        dzial: j['dzial'] != null ? Dzial.fromJson(j['dzial']) : null,
      );

  Map<String, dynamic> toJson() =>
      {'id': id, 'nazwa': nazwa, 'dzial': dzial?.toJson()};
}
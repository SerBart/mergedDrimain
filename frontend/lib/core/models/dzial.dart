class Dzial {
  final int id;
  final String nazwa;

  Dzial({required this.id, required this.nazwa});

  factory Dzial.fromJson(Map<String, dynamic> j) =>
      Dzial(id: j['id'] ?? 0, nazwa: j['nazwa'] ?? '');

  Map<String, dynamic> toJson() => {'id': id, 'nazwa': nazwa};

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Dzial &&
        other.id == id &&
        other.nazwa == nazwa;
  }

  @override
  int get hashCode => id.hashCode ^ nazwa.hashCode;
}
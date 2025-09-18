import 'maszyna.dart';

class MaintenancePlan {
  final int id;
  final String nazwa;
  final Maszyna? maszyna;
  final int interwalDni;
  final DateTime dataOstatniegoWykonania;
  final DateTime dataNastepna;
  final String status; // AKTYWNY / WSTRZYMANY

  MaintenancePlan({
    required this.id,
    required this.nazwa,
    required this.maszyna,
    required this.interwalDni,
    required this.dataOstatniegoWykonania,
    required this.dataNastepna,
    required this.status,
  });

  bool get overdue => DateTime.now().isAfter(dataNastepna);

  MaintenancePlan copyWith({
    int? id,
    String? nazwa,
    int? interwalDni,
    DateTime? dataOstatniegoWykonania,
    DateTime? dataNastepna,
    String? status,
    maszyna,
  }) {
    return MaintenancePlan(
      id: id ?? this.id,
      nazwa: nazwa ?? this.nazwa,
      maszyna: maszyna ?? this.maszyna,
      interwalDni: interwalDni ?? this.interwalDni,
      dataOstatniegoWykonania:
          dataOstatniegoWykonania ?? this.dataOstatniegoWykonania,
      dataNastepna: dataNastepna ?? this.dataNastepna,
      status: status ?? this.status,
    );
  }
}
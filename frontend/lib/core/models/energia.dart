enum EnergyScope { total, dzial, maszyna }

extension EnergyScopeJson on EnergyScope {
  String get apiValue => switch (this) {
        EnergyScope.total => 'TOTAL',
        EnergyScope.dzial => 'DZIAL',
        EnergyScope.maszyna => 'MASZYNA',
      };

  String get label => switch (this) {
        EnergyScope.total => 'Całość',
        EnergyScope.dzial => 'Dział',
        EnergyScope.maszyna => 'Maszyna',
      };

  static EnergyScope fromApi(String? value) {
    switch ((value ?? '').toUpperCase()) {
      case 'DZIAL':
        return EnergyScope.dzial;
      case 'MASZYNA':
        return EnergyScope.maszyna;
      default:
        return EnergyScope.total;
    }
  }
}

class EnergyHistoryPoint {
  final DateTime recordedAt;
  final String deviceId;
  final double powerKw;
  final double? energyKwhTotal;
  final double? voltageV;
  final double? currentA;

  const EnergyHistoryPoint({
    required this.recordedAt,
    required this.deviceId,
    required this.powerKw,
    required this.energyKwhTotal,
    required this.voltageV,
    required this.currentA,
  });

  factory EnergyHistoryPoint.fromJson(Map<String, dynamic> json) {
    final rawDate = json['recordedAt']?.toString();
    return EnergyHistoryPoint(
      recordedAt: rawDate != null ? DateTime.tryParse(rawDate) ?? DateTime.now() : DateTime.now(),
      deviceId: (json['deviceId'] ?? '').toString(),
      powerKw: (json['powerKw'] as num?)?.toDouble() ?? 0.0,
      energyKwhTotal: (json['energyKwhTotal'] as num?)?.toDouble(),
      voltageV: (json['voltageV'] as num?)?.toDouble(),
      currentA: (json['currentA'] as num?)?.toDouble(),
    );
  }
}

class EnergyMachineSummary {
  final int maszynaId;
  final String maszynaNazwa;
  final int? dzialId;
  final String? dzialNazwa;
  final String? deviceId;
  final DateTime? lastRecordedAt;
  final double powerKw;
  final double? energyKwhTotal;
  final double todayEnergyKwh;
  final int readingsCount;

  const EnergyMachineSummary({
    required this.maszynaId,
    required this.maszynaNazwa,
    required this.dzialId,
    required this.dzialNazwa,
    required this.deviceId,
    required this.lastRecordedAt,
    required this.powerKw,
    required this.energyKwhTotal,
    required this.todayEnergyKwh,
    required this.readingsCount,
  });

  factory EnergyMachineSummary.fromJson(Map<String, dynamic> json) {
    final rawDate = json['lastRecordedAt']?.toString();
    return EnergyMachineSummary(
      maszynaId: (json['maszynaId'] as num?)?.toInt() ?? 0,
      maszynaNazwa: (json['maszynaNazwa'] ?? '').toString(),
      dzialId: (json['dzialId'] as num?)?.toInt(),
      dzialNazwa: json['dzialNazwa']?.toString(),
      deviceId: json['deviceId']?.toString(),
      lastRecordedAt: rawDate != null ? DateTime.tryParse(rawDate) : null,
      powerKw: (json['powerKw'] as num?)?.toDouble() ?? 0.0,
      energyKwhTotal: (json['energyKwhTotal'] as num?)?.toDouble(),
      todayEnergyKwh: (json['todayEnergyKwh'] as num?)?.toDouble() ?? 0.0,
      readingsCount: (json['readingsCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class EnergyOverview {
  final String scopeType;
  final String scopeLabel;
  final int zakresDni;
  final int bucketMinutes;
  final DateTime? generatedAt;
  final double totalPowerKw;
  final double todayEnergyKwh;
  final double peakPower1hKw;
  final double peakPower8hKw;
  final double peakPower24hKw;
  final double peakPower3dKw;
  final double peakPower7dKw;
  final double peakPower30dKw;
  final int activeMachines;
  final int totalMachines;
  final List<EnergyMachineSummary> machines;

  const EnergyOverview({
    required this.scopeType,
    required this.scopeLabel,
    required this.zakresDni,
    required this.bucketMinutes,
    required this.generatedAt,
    required this.totalPowerKw,
    required this.todayEnergyKwh,
    required this.peakPower1hKw,
    required this.peakPower8hKw,
    required this.peakPower24hKw,
    required this.peakPower3dKw,
    required this.peakPower7dKw,
    required this.peakPower30dKw,
    required this.activeMachines,
    required this.totalMachines,
    required this.machines,
  });

  factory EnergyOverview.fromJson(Map<String, dynamic> json) {
    final rawDate = json['generatedAt']?.toString();
    final machines = (json['machines'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((m) => EnergyMachineSummary.fromJson(m.cast<String, dynamic>()))
        .toList();

    return EnergyOverview(
      scopeType: (json['scopeType'] ?? 'TOTAL').toString(),
      scopeLabel: (json['scopeLabel'] ?? 'Całość zakładu').toString(),
      zakresDni: (json['zakresDni'] as num?)?.toInt() ?? 1,
      bucketMinutes: (json['bucketMinutes'] as num?)?.toInt() ?? 5,
      generatedAt: rawDate != null ? DateTime.tryParse(rawDate) : null,
      totalPowerKw: (json['totalPowerKw'] as num?)?.toDouble() ?? 0.0,
      todayEnergyKwh: (json['todayEnergyKwh'] as num?)?.toDouble() ?? 0.0,
      peakPower1hKw: (json['peakPower1hKw'] as num?)?.toDouble() ?? 0.0,
      peakPower8hKw: (json['peakPower8hKw'] as num?)?.toDouble() ?? 0.0,
      peakPower24hKw: (json['peakPower24hKw'] as num?)?.toDouble() ?? 0.0,
      peakPower3dKw: (json['peakPower3dKw'] as num?)?.toDouble() ?? 0.0,
      peakPower7dKw: (json['peakPower7dKw'] as num?)?.toDouble() ?? 0.0,
      peakPower30dKw: (json['peakPower30dKw'] as num?)?.toDouble() ?? 0.0,
      activeMachines: (json['activeMachines'] as num?)?.toInt() ?? 0,
      totalMachines: (json['totalMachines'] as num?)?.toInt() ?? 0,
      machines: machines,
    );
  }
}


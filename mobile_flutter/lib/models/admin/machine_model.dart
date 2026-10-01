class MachineModel {
  final String id;
  final String name;
  final String status;
  final double uptimeHours;
  final double maintenanceIntervalHours;
  final String location;
  final bool isMaintenanceDue;
  final double remainingHours;
  final DateTime createdAt;
  final DateTime updatedAt;

  MachineModel({
    required this.id,
    required this.name,
    required this.status,
    required this.uptimeHours,
    required this.maintenanceIntervalHours,
    required this.location,
    required this.isMaintenanceDue,
    required this.remainingHours,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MachineModel.fromJson(Map<String, dynamic> json) {
    String parsedStatus = 'Operational';
    if (json['status'] is int) {
      switch (json['status'] as int) {
        case 0:
          parsedStatus = 'Operational';
          break;
        case 1:
          parsedStatus = 'MaintenanceRequired';
          break;
        case 2:
          parsedStatus = 'Offline';
          break;
        default:
          parsedStatus = 'Operational';
      }
    } else if (json['status'] != null) {
      parsedStatus = json['status'].toString();
    }

    return MachineModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unnamed Machine',
      status: parsedStatus,
      uptimeHours: (json['uptimeHours'] as num?)?.toDouble() ?? 0.0,
      maintenanceIntervalHours:
          (json['maintenanceIntervalHours'] as num?)?.toDouble() ?? 100.0,
      location: json['location']?.toString() ?? 'Floor',
      isMaintenanceDue: json['isMaintenanceDue'] as bool? ?? false,
      remainingHours: (json['remainingHours'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'status': status,
        'uptimeHours': uptimeHours,
        'maintenanceIntervalHours': maintenanceIntervalHours,
        'location': location,
        'isMaintenanceDue': isMaintenanceDue,
        'remainingHours': remainingHours,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };
}

class MaintenanceLogModel {
  final String id;
  final String machineId;
  final String? performedBy;
  final String description;
  final DateTime performedAt;
  final String status;
  final double cost;

  MaintenanceLogModel({
    required this.id,
    required this.machineId,
    this.performedBy,
    required this.description,
    required this.performedAt,
    required this.status,
    required this.cost,
  });

  factory MaintenanceLogModel.fromJson(Map<String, dynamic> json) {
    return MaintenanceLogModel(
      id: json['id']?.toString() ?? '',
      machineId: json['machineId']?.toString() ?? '',
      performedBy: json['performedBy']?.toString(),
      description: json['description']?.toString() ?? '',
      performedAt: json['performedAt'] != null
          ? DateTime.tryParse(json['performedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      status: json['status']?.toString() ?? 'Completed',
      cost: (json['cost'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

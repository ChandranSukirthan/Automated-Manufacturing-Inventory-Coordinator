class SystemHealthModel {
  final String overallStatus;
  final List<ServiceHealthItem> services;
  final DateTime timestamp;

  SystemHealthModel({
    required this.overallStatus,
    required this.services,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory SystemHealthModel.fromJson(Map<String, dynamic> json) {
    List<ServiceHealthItem> serviceList = [];
    if (json['services'] is List) {
      serviceList = (json['services'] as List)
          .map((item) => ServiceHealthItem.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    return SystemHealthModel(
      overallStatus: json['overallStatus']?.toString() ?? 'ONLINE',
      services: serviceList,
      timestamp: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'overallStatus': overallStatus,
        'services': services.map((s) => s.toJson()).toList(),
        'timestamp': timestamp.toIso8601String(),
      };
}

class ServiceHealthItem {
  final String name;
  final String status;
  final String message;
  final int? latencyMs;

  ServiceHealthItem({
    required this.name,
    required this.status,
    required this.message,
    this.latencyMs,
  });

  factory ServiceHealthItem.fromJson(Map<String, dynamic> json) {
    return ServiceHealthItem(
      name: json['name']?.toString() ?? 'Service',
      status: json['status']?.toString() ?? 'ONLINE',
      message: json['message']?.toString() ?? 'Operational',
      latencyMs: (json['latencyMs'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'status': status,
        'message': message,
        'latencyMs': latencyMs,
      };
}

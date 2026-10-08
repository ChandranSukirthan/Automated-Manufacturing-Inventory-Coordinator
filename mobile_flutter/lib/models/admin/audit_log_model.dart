class AuditLogModel {
  final String id;
  final String userId;
  final String userName;
  final String action;
  final String entity;
  final String entityId;
  final DateTime timestamp;
  final bool success;
  final String? ipAddress;

  AuditLogModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.action,
    required this.entity,
    required this.entityId,
    required this.timestamp,
    required this.success,
    this.ipAddress,
  });

  factory AuditLogModel.fromJson(Map<String, dynamic> json) {
    return AuditLogModel(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      userName: json['userName']?.toString() ?? 'System',
      action: json['action']?.toString() ?? '',
      entity: json['entity']?.toString() ?? '',
      entityId: json['entityId']?.toString() ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      success: json['success'] != false,
      ipAddress: json['ipAddress']?.toString(),
    );
  }
}


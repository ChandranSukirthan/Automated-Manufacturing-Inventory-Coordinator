class ShiftModel {
  final String id;
  final String name;
  final DateTime startTime;
  final DateTime endTime;
  final double targetOutput;
  final double adjustedOutput;
  final String status;
  final String? notes;

  ShiftModel({
    required this.id,
    required this.name,
    required this.startTime,
    required this.endTime,
    required this.targetOutput,
    required this.adjustedOutput,
    required this.status,
    this.notes,
  });

  factory ShiftModel.fromJson(Map<String, dynamic> json) {
    String parsedStatus = 'Scheduled';
    if (json['status'] is int) {
      switch (json['status'] as int) {
        case 0:
          parsedStatus = 'Scheduled';
          break;
        case 1:
          parsedStatus = 'Active';
          break;
        case 2:
          parsedStatus = 'Completed';
          break;
        case 3:
          parsedStatus = 'Cancelled';
          break;
        default:
          parsedStatus = 'Scheduled';
      }
    } else if (json['status'] != null) {
      parsedStatus = json['status'].toString();
    }

    return ShiftModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unnamed Shift',
      startTime: json['startTime'] != null
          ? DateTime.tryParse(json['startTime'].toString()) ?? DateTime.now()
          : DateTime.now(),
      endTime: json['endTime'] != null
          ? DateTime.tryParse(json['endTime'].toString()) ?? DateTime.now()
          : DateTime.now().add(const Duration(hours: 8)),
      targetOutput: (json['targetOutput'] as num?)?.toDouble() ?? 0.0,
      adjustedOutput: (json['adjustedOutput'] as num?)?.toDouble() ?? 0.0,
      status: parsedStatus,
      notes: json['notes']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
        'targetOutput': targetOutput,
        'adjustedOutput': adjustedOutput,
        'status': status,
        'notes': notes,
      };
}

class QualitySummary {
  const QualitySummary({
    required this.totalDefects,
    required this.highSeverityDefects,
    required this.activeQuarantines,
    required this.releasedQuarantines,
  });

  final int totalDefects;
  final int highSeverityDefects;
  final int activeQuarantines;
  final int releasedQuarantines;

  factory QualitySummary.fromJson(Map<String, dynamic> json) => QualitySummary(
    totalDefects: json['totalDefects'] as int? ?? 0,
    highSeverityDefects: json['highSeverityDefects'] as int? ?? 0,
    activeQuarantines: json['activeQuarantines'] as int? ?? 0,
    releasedQuarantines: json['releasedQuarantines'] as int? ?? 0,
  );
}

class DefectReport {
  const DefectReport({
    required this.id,
    required this.batchId,
    required this.productType,
    required this.severity,
    required this.description,
    required this.createdAt,
    required this.status,
  });

  final String id;
  final String batchId;
  final String productType;
  final String severity;
  final String description;
  final DateTime createdAt;
  final String status;

  factory DefectReport.fromJson(Map<String, dynamic> json) => DefectReport(
    id: json['id']?.toString() ?? '',
    batchId: json['batchId'] as String? ?? '',
    productType: json['productType'] as String? ?? '',
    severity: json['severity'] as String? ?? '',
    description: json['description'] as String? ?? '',
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    status: json['status'] as String? ?? '',
  );
}

extension DefectReportCopy on DefectReport {
  DefectReport copyWith({
    String? batchId,
    String? productType,
    String? severity,
    String? description,
    String? status,
  }) => DefectReport(
    id: id,
    batchId: batchId ?? this.batchId,
    productType: productType ?? this.productType,
    severity: severity ?? this.severity,
    description: description ?? this.description,
    createdAt: createdAt,
    status: status ?? this.status,
  );
}

class QuarantineRecord {
  const QuarantineRecord({
    required this.id,
    required this.defectReportId,
    required this.inventoryRollId,
    required this.batchId,
    required this.reason,
    required this.status,
    required this.createdAt,
    this.releasedAt,
  });

  final String id;
  final String defectReportId;
  final String inventoryRollId;
  final String batchId;
  final String reason;
  final String status;
  final DateTime createdAt;
  final DateTime? releasedAt;

  factory QuarantineRecord.fromJson(Map<String, dynamic> json) =>
      QuarantineRecord(
        id: json['id']?.toString() ?? '',
        defectReportId: json['defectReportId']?.toString() ?? '',
        inventoryRollId: json['inventoryRollId'] as String? ?? '',
        batchId: json['batchId'] as String? ?? '',
        reason: json['reason'] as String? ?? '',
        status: json['status'] as String? ?? '',
        createdAt:
            DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
        releasedAt: DateTime.tryParse(json['releasedAt'] as String? ?? ''),
      );
}

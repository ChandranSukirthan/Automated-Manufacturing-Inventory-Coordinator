class QualitySummary {
  const QualitySummary({
    required this.totalDefects,
    required this.highSeverityDefects,
    required this.activeQuarantines,
    required this.releasedQuarantines,
    required this.openDefects,
    required this.quarantinedBatches,
    required this.affectedInventory,
    required this.releasedInventory,
  });

  final int totalDefects;
  final int highSeverityDefects;
  final int activeQuarantines;
  final int releasedQuarantines;
  final int openDefects;
  final int quarantinedBatches;
  final int affectedInventory;
  final int releasedInventory;

  factory QualitySummary.fromJson(Map<String, dynamic> json) => QualitySummary(
    totalDefects: json['totalDefects'] as int? ?? 0,
    highSeverityDefects: json['highSeverityDefects'] as int? ?? 0,
    activeQuarantines: json['activeQuarantines'] as int? ?? 0,
    releasedQuarantines: json['releasedQuarantines'] as int? ?? 0,
    openDefects: json['openDefects'] as int? ?? 0,
    quarantinedBatches: json['quarantinedBatches'] as int? ?? 0,
    affectedInventory: json['affectedInventory'] as int? ?? 0,
    releasedInventory: json['releasedInventory'] as int? ?? 0,
  );

  QualitySummary copyWith({
    int? totalDefects,
    int? highSeverityDefects,
    int? activeQuarantines,
    int? releasedQuarantines,
    int? openDefects,
    int? quarantinedBatches,
    int? affectedInventory,
    int? releasedInventory,
  }) => QualitySummary(
    totalDefects: totalDefects ?? this.totalDefects,
    highSeverityDefects: highSeverityDefects ?? this.highSeverityDefects,
    activeQuarantines: activeQuarantines ?? this.activeQuarantines,
    releasedQuarantines: releasedQuarantines ?? this.releasedQuarantines,
    openDefects: openDefects ?? this.openDefects,
    quarantinedBatches: quarantinedBatches ?? this.quarantinedBatches,
    affectedInventory: affectedInventory ?? this.affectedInventory,
    releasedInventory: releasedInventory ?? this.releasedInventory,
  );
}

class BatchDetails {
  const BatchDetails({
    required this.id,
    required this.productType,
    required this.inventoryRolls,
  });

  final String id;
  final String productType;
  final List<InventoryRoll> inventoryRolls;

  factory BatchDetails.fromJson(Map<String, dynamic> json) => BatchDetails(
    id: json['id']?.toString() ?? '',
    productType: json['productType'] as String? ?? '',
    inventoryRolls: (json['inventoryRolls'] as List<dynamic>? ?? [])
        .map((item) => InventoryRoll.fromJson(item as Map<String, dynamic>))
        .toList(),
  );
}

class InventoryRoll {
  const InventoryRoll({
    required this.id,
    required this.batchId,
    required this.status,
  });

  final String id;
  final String batchId;
  final String status;

  factory InventoryRoll.fromJson(Map<String, dynamic> json) => InventoryRoll(
    id: json['id']?.toString() ?? '',
    batchId: json['batchId'] as String? ?? '',
    status: json['status'] as String? ?? '',
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
    this.reportedByUserId,
  });

  final String id;
  final String batchId;
  final String productType;
  final String severity;
  final String description;
  final DateTime createdAt;
  final String status;
  final String? reportedByUserId;

  factory DefectReport.fromJson(Map<String, dynamic> json) => DefectReport(
    id: json['id']?.toString() ?? '',
    batchId: json['batchId'] as String? ?? '',
    productType: json['productType'] as String? ?? '',
    severity: json['severity'] as String? ?? '',
    description: json['description'] as String? ?? '',
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    status: json['status'] as String? ?? '',
    reportedByUserId: json['reportedByUserId']?.toString(),
  );
}

extension DefectReportCopy on DefectReport {
  DefectReport copyWith({
    String? batchId,
    String? productType,
    String? severity,
    String? description,
    String? status,
    String? reportedByUserId,
  }) => DefectReport(
    id: id,
    batchId: batchId ?? this.batchId,
    productType: productType ?? this.productType,
    severity: severity ?? this.severity,
    description: description ?? this.description,
    createdAt: createdAt,
    status: status ?? this.status,
    reportedByUserId: reportedByUserId ?? this.reportedByUserId,
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

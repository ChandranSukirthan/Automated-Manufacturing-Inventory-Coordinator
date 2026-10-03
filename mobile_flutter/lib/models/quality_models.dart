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

class QualityRecommendation {
  const QualityRecommendation({
    required this.batchId,
    required this.quarantineRequired,
    required this.affectedInventory,
    required this.riskLevel,
    this.reason,
    this.inventoryContext = const [],
  });

  final String batchId;
  final bool quarantineRequired;
  final List<String> affectedInventory;
  final String riskLevel;
  final String? reason;
  final List<Map<String, dynamic>> inventoryContext;

  factory QualityRecommendation.fromJson(Map<String, dynamic> json) =>
      QualityRecommendation(
        batchId: json['batchId']?.toString() ?? '',
        quarantineRequired: json['quarantineRequired'] as bool? ?? false,
        affectedInventory: (json['affectedInventory'] as List<dynamic>? ?? [])
            .map((item) => item.toString())
            .toList(),
        riskLevel: json['riskLevel']?.toString() ?? 'LOW',
        reason: json['reason']?.toString(),
        inventoryContext: (json['inventoryContext'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .toList(),
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
    this.rollIdentifier,
    this.currentQuantity,
    this.initialQuantity,
    this.rawMaterialId,
  });

  final String id;
  final String batchId;
  final String status;
  final String? rollIdentifier;
  final num? currentQuantity;
  final num? initialQuantity;
  final int? rawMaterialId;

  factory InventoryRoll.fromJson(Map<String, dynamic> json) => InventoryRoll(
    id: json['id']?.toString() ?? '',
    batchId: json['batchId'] as String? ?? '',
    status: json['status'] as String? ?? '',
    rollIdentifier: json['rollIdentifier']?.toString(),
    currentQuantity: json['currentQuantity'] as num?,
    initialQuantity: json['initialQuantity'] as num?,
    rawMaterialId: json['rawMaterialId'] as int?,
  );
}

class DefectReport {
  const DefectReport({
    required this.id,
    this.skuCode = '',
    required this.batchId,
    required this.productType,
    required this.severity,
    required this.description,
    required this.createdAt,
    required this.status,
    this.skuCode,
    this.reportedByUserId,
    this.affectedInventory = const [],
  });

  final String id;
  final String skuCode;
  final String batchId;
  final String productType;
  final String severity;
  final String description;
  final DateTime createdAt;
  final String status;
  final String? skuCode;
  final String? reportedByUserId;
  final List<String> affectedInventory;

  factory DefectReport.fromJson(Map<String, dynamic> json) => DefectReport(
    id: json['id']?.toString() ?? '',
    skuCode: json['skuCode'] as String? ?? '',
    batchId: json['batchId'] as String? ?? '',
    productType: json['productType'] as String? ?? '',
    severity: json['severity'] as String? ?? '',
    description: json['description'] as String? ?? '',
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    status: json['status'] as String? ?? '',
    skuCode: json['skuCode'] as String?,
    reportedByUserId: json['reportedByUserId']?.toString(),
    affectedInventory: (json['affectedInventory'] as List<dynamic>? ?? [])
        .map((item) => item.toString())
        .toList(),
  );
}

extension DefectReportCopy on DefectReport {
  DefectReport copyWith({
    String? skuCode,
    String? batchId,
    String? productType,
    String? severity,
    String? description,
    String? status,
    String? skuCode,
    String? reportedByUserId,
    List<String>? affectedInventory,
  }) => DefectReport(
    id: id,
    skuCode: skuCode ?? this.skuCode,
    batchId: batchId ?? this.batchId,
    productType: productType ?? this.productType,
    severity: severity ?? this.severity,
    description: description ?? this.description,
    createdAt: createdAt,
    status: status ?? this.status,
    skuCode: skuCode ?? this.skuCode,
    reportedByUserId: reportedByUserId ?? this.reportedByUserId,
    affectedInventory: affectedInventory ?? this.affectedInventory,
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

/// Model representing the AI Validation & Safety Gate Assessment
class AiValidationData {
  const AiValidationData({
    required this.workflowId,
    required this.status,
    this.isValid,
    this.qualitySafetyStatus,
    this.supplierValidation,
    this.budgetCheck,
    this.poMathematicalCheck,
    this.materialValidation,
    this.quarantinedRollsCount,
    this.isHighImpact,
    this.impactReason,
    this.rejectionReason,
    this.manualResolutionStatus,
    this.manualResolutionNote,
    this.resolvedBy,
    this.resolvedAt,
    this.purchaseOrderNumber,
    this.poNumber,
  });

  final String workflowId;
  final String status;
  final bool? isValid;
  final String? qualitySafetyStatus;
  final String? supplierValidation;
  final String? budgetCheck;
  final String? poMathematicalCheck;
  final String? materialValidation;
  final int? quarantinedRollsCount;
  final bool? isHighImpact;
  final String? impactReason;
  final String? rejectionReason;
  final String? manualResolutionStatus;
  final String? manualResolutionNote;
  final String? resolvedBy;
  final String? resolvedAt;
  final String? purchaseOrderNumber;
  final String? poNumber;

  factory AiValidationData.fromJson(Map<String, dynamic> json) => AiValidationData(
    workflowId: json['workflowId']?.toString() ?? '',
    status: json['status']?.toString() ?? 'COMPLETED',
    isValid: json['isValid'] as bool?,
    qualitySafetyStatus: json['qualitySafetyStatus']?.toString(),
    supplierValidation: json['supplierValidation']?.toString() ?? json['supplierCheck']?.toString(),
    budgetCheck: json['budgetCheck']?.toString(),
    poMathematicalCheck: json['poMathematicalCheck']?.toString() ?? json['poMathCheck']?.toString(),
    materialValidation: json['materialValidation']?.toString() ?? json['materialCheck']?.toString(),
    quarantinedRollsCount: json['quarantinedRollsCount'] as int?,
    isHighImpact: json['isHighImpact'] as bool?,
    impactReason: json['impactReason']?.toString(),
    rejectionReason: json['rejectionReason']?.toString(),
    manualResolutionStatus: json['manualResolutionStatus']?.toString(),
    manualResolutionNote: json['manualResolutionNote']?.toString(),
    resolvedBy: json['resolvedBy']?.toString(),
    resolvedAt: json['resolvedAt']?.toString(),
    purchaseOrderNumber: json['purchaseOrderNumber']?.toString(),
    poNumber: json['poNumber']?.toString(),
  );

  /// Helper to extract PO Number cleanly
  String get poReference {
    if (purchaseOrderNumber != null && purchaseOrderNumber!.isNotEmpty) return purchaseOrderNumber!;
    if (poNumber != null && poNumber!.isNotEmpty) return poNumber!;
    final match = RegExp(r'PO-\d{4}-\d{4}', caseSensitive: false).firstMatch(workflowId);
    if (match != null) return match.group(0)!;
    return 'Not available';
  }

  /// 1. Original AI Assessment (Strictly Preserved)
  String get origAiOutcome {
    if (isValid != null) return isValid! ? 'VALID' : 'INVALID';
    if (qualitySafetyStatus != null) {
      final s = qualitySafetyStatus!.toUpperCase().trim();
      return (s == 'CLEAR' || s == 'PASSED') ? 'VALID' : 'INVALID';
    }
    return 'Not available';
  }

  String get origSafetyStatus {
    if (qualitySafetyStatus != null && qualitySafetyStatus!.isNotEmpty) {
      return qualitySafetyStatus!.toUpperCase().trim();
    }
    if (quarantinedRollsCount != null) {
      return quarantinedRollsCount! > 0 ? 'QUARANTINE_ACTIVE' : 'CLEAR';
    }
    return 'Not available';
  }

  String get quarantinedRollsDisplay {
    if (quarantinedRollsCount != null) return '$quarantinedRollsCount roll(s)';
    return 'Not available';
  }

  String get highImpactDisplay {
    if (isHighImpact != null) return isHighImpact! ? 'YES' : 'NO';
    return 'Not available';
  }

  /// 2. Current QA & Quarantine State
  bool get isResolved => manualResolutionStatus?.toUpperCase().trim() == 'RESOLVED';

  bool get hasQuarantineTrigger {
    final safety = qualitySafetyStatus?.toUpperCase().trim();
    return safety?.contains('QUARANTINE') == true ||
        safety == 'BLOCKED' ||
        (quarantinedRollsCount != null && quarantinedRollsCount! > 0) ||
        isValid == false;
  }

  String get currentManualResolution {
    if (isResolved) return 'RESOLVED';
    final manual = manualResolutionStatus?.toUpperCase().trim();
    final safety = qualitySafetyStatus?.toUpperCase().trim();
    if (manual == 'NOT_REQUIRED' || (safety == 'CLEAR' && (quarantinedRollsCount == 0 || quarantinedRollsCount == null) && isValid != false)) {
      return 'NOT REQUIRED';
    }
    if (hasQuarantineTrigger) return 'PENDING REVIEW';
    if (safety != null) return 'NOT REQUIRED';
    return 'Not available';
  }

  String get currentQuarantineDisposition {
    if (isResolved) return 'RELEASED';
    final manual = manualResolutionStatus?.toUpperCase().trim();
    final safety = qualitySafetyStatus?.toUpperCase().trim();
    if (manual == 'NOT_REQUIRED' || (safety == 'CLEAR' && (quarantinedRollsCount == 0 || quarantinedRollsCount == null) && isValid != false)) {
      return 'NONE';
    }
    if (hasQuarantineTrigger) return 'ACTIVE';
    if (safety != null) return 'NONE';
    return 'Not available';
  }

  /// 3. Safety Gate Status
  String get safetyGateState {
    if (isResolved) return 'RESOLVED';
    if (hasQuarantineTrigger) return 'BLOCKED';
    if (qualitySafetyStatus != null || isValid != null || quarantinedRollsCount != null) {
      return 'CLEAR';
    }
    return 'Not available';
  }

  bool get isSafetyBlocked => safetyGateState == 'BLOCKED';
  bool get needsReview => isSafetyBlocked && !isResolved;

  /// Automated checks summary
  List<ValidationCheckItem> get automatedCheckItems => [
    ValidationCheckItem(name: 'Supplier Check', key: 'supplier', value: supplierValidation),
    ValidationCheckItem(name: 'Budget Check', key: 'budget', value: budgetCheck),
    ValidationCheckItem(name: 'PO Math Check', key: 'poMath', value: poMathematicalCheck),
    ValidationCheckItem(name: 'Material Check', key: 'material', value: materialValidation),
  ];

  List<ValidationCheckItem> get presentChecks =>
      automatedCheckItems.where((c) => c.value != null && c.value!.trim().isNotEmpty).toList();

  List<ValidationCheckItem> get passedChecks => presentChecks.where((c) => c.isPassed).toList();

  String get automatedSummary {
    if (presentChecks.isEmpty) return 'Not available';
    if (presentChecks.length == 4 && passedChecks.length == 4) return '4 / 4 PASSED';
    if (presentChecks.length == 4) return '${passedChecks.length} / 4 PASSED';
    return '${passedChecks.length} / ${presentChecks.length} PASSED';
  }

  bool get allAutomatedPassed => presentChecks.length == 4 && passedChecks.length == 4;
}

class ValidationCheckItem {
  const ValidationCheckItem({
    required this.name,
    required this.key,
    required this.value,
  });

  final String name;
  final String key;
  final String? value;

  bool get isAvailable => value != null && value!.trim().isNotEmpty;

  bool get isPassed {
    if (!isAvailable) return false;
    final s = value!.toUpperCase().trim();
    return s == 'PASSED' || s == 'CLEAR' || s == 'VALID' || s == 'TRUE';
  }

  bool get isFailed {
    if (!isAvailable) return false;
    final s = value!.toUpperCase().trim();
    return s == 'FAILED' || s == 'INVALID' || s == 'BLOCKED' || s == 'FALSE';
  }

  bool get isExceedsBudget {
    if (!isAvailable) return false;
    return value!.toUpperCase().trim() == 'EXCEEDS_BUDGET_THRESHOLD';
  }

  String get displayLabel {
    if (!isAvailable) return 'Not available';
    if (isPassed) return 'PASSED';
    if (isFailed) return 'FAILED';
    if (isExceedsBudget) return 'EXCEEDS THRESHOLD';
    return value!.toUpperCase().trim();
  }
}

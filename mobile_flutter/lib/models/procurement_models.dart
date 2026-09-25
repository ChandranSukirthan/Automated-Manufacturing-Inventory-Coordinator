import 'package:flutter/material.dart';

/// 11-stage procurement pipeline requested for mobile tracking:
/// LOW STOCK → PROCUREMENT REQUESTED → AI RESEARCHING → RECOMMENDATION READY →
/// WAITING FOR MANAGER APPROVAL → APPROVED → PAYMENT PROCESSING → PAID →
/// SUPPLIER NOTIFIED → INCOMING SUPPLY → COMPLETED
enum ProcurementPipelineStep {
  lowStock('LOW STOCK', 'Warehouse inventory breached safety threshold'),
  procurementRequested('PROCUREMENT REQUESTED', 'Procurement requirement logged and persisted in ERP'),
  aiResearching('AI RESEARCHING', 'Goal-based agent researching market via search grounding'),
  recommendationReady('RECOMMENDATION READY', 'Top candidate selected with deterministic quantity & cost'),
  waitingForApproval('WAITING FOR MANAGER APPROVAL', 'Draft PO formulated; awaiting Supply Chain Manager authorization'),
  approved('APPROVED', 'Purchase order authorized by Supply Chain Manager'),
  paymentProcessing('PAYMENT PROCESSING', 'Stripe payment transaction initiated'),
  paid('PAID', 'Stripe payment confirmed and reconciled'),
  supplierNotified('SUPPLIER NOTIFIED', 'Signed PO invoice PDF dispatched to supplier via SendGrid'),
  incomingSupply('INCOMING SUPPLY', 'Order acknowledged by supplier and shipment en route'),
  completed('COMPLETED', 'Raw material supplies received and verified in inventory');

  const ProcurementPipelineStep(this.title, this.description);
  final String title;
  final String description;
}

/// Incoming supply delivery status for Floor Workers
enum SupplyDeliveryStatus {
  expected('EXPECTED', Color(0xFF5CC8F8)),
  inTransit('IN_TRANSIT', Color(0xFFF59E0B)),
  received('RECEIVED', Color(0xFF10B981)),
  partiallyReceived('PARTIALLY_RECEIVED', Color(0xFF8B5CF6)),
  delayed('DELAYED', Color(0xFFEF4444)),
  completed('COMPLETED', Color(0xFF10B981));

  const SupplyDeliveryStatus(this.label, this.color);
  final String label;
  final Color color;

  static SupplyDeliveryStatus fromString(String? value) {
    if (value == null) return SupplyDeliveryStatus.expected;
    final normalized = value.trim().toUpperCase().replaceAll(' ', '_');
    for (final status in SupplyDeliveryStatus.values) {
      if (status.label == normalized) return status;
    }
    return switch (normalized) {
      'SENT' || 'SHIPPED' => SupplyDeliveryStatus.inTransit,
      'ARRIVED' => SupplyDeliveryStatus.received,
      _ => SupplyDeliveryStatus.expected,
    };
  }
}

/// Evaluated supplier candidate from AI research
class SupplierCandidateItem {
  const SupplierCandidateItem({
    required this.id,
    this.supplierId,
    required this.supplierName,
    required this.materialName,
    required this.unitPrice,
    required this.currency,
    required this.minimumOrderQuantity,
    required this.packSize,
    required this.leadTimeDays,
    required this.qualityEvidence,
    required this.supplierStatus,
    required this.confidenceScore,
    this.sourceUrl,
    required this.isValidated,
    this.validationRemarks,
    required this.recommendedOrderQuantity,
    required this.totalCost,
    required this.createdAt,
    this.availability = 'In Stock',
  });

  final int id;
  final int? supplierId;
  final String supplierName;
  final String materialName;
  final double unitPrice;
  final String currency;
  final double minimumOrderQuantity;
  final double packSize;
  final int leadTimeDays;
  final String qualityEvidence;
  final String supplierStatus; // APPROVED, UNVERIFIED, BLOCKED
  final double confidenceScore;
  final String? sourceUrl;
  final bool isValidated;
  final String? validationRemarks;
  final double recommendedOrderQuantity;
  final double totalCost;
  final DateTime createdAt;
  final String availability;

  factory SupplierCandidateItem.fromJson(Map<String, dynamic> json) {
    return SupplierCandidateItem(
      id: json['id'] as int? ?? 0,
      supplierId: json['supplierId'] as int?,
      supplierName: json['supplierName'] as String? ?? 'Unknown Vendor',
      materialName: json['materialName'] as String? ?? 'Raw Material',
      unitPrice: (json['unitPrice'] as num? ?? 0).toDouble(),
      currency: json['currency'] as String? ?? 'USD',
      minimumOrderQuantity: (json['minimumOrderQuantity'] as num? ?? 0).toDouble(),
      packSize: (json['packSize'] as num? ?? 1).toDouble(),
      leadTimeDays: json['leadTimeDays'] as int? ?? 0,
      qualityEvidence: json['qualityEvidence'] as String? ?? '',
      supplierStatus: (json['supplierStatus'] as String? ?? 'UNVERIFIED').toUpperCase(),
      confidenceScore: (json['confidenceScore'] as num? ?? 0).toDouble(),
      sourceUrl: json['sourceUrl'] as String?,
      isValidated: json['isValidated'] as bool? ?? false,
      validationRemarks: json['validationRemarks'] as String?,
      recommendedOrderQuantity: (json['recommendedOrderQuantity'] as num? ?? 0).toDouble(),
      totalCost: (json['totalCost'] as num? ?? 0).toDouble(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      availability: json['availability'] as String? ?? 'In Stock',
    );
  }

  /// Quality status: VERIFIED, UNKNOWN, NOT VERIFIED
  String get qualityStatus {
    final lower = qualityEvidence.toLowerCase();
    if (lower.contains('iso') || lower.contains('certified') || lower.contains('astm') || lower.contains('approved') || lower.contains('passed')) {
      return 'VERIFIED';
    }
    if (qualityEvidence.trim().isEmpty || lower.contains('unknown')) {
      return 'UNKNOWN';
    }
    return 'NOT VERIFIED';
  }

  String get qualityEvidenceDisplay {
    if (qualityEvidence.trim().isEmpty) {
      return 'Quality evidence unavailable';
    }
    return qualityEvidence;
  }

  bool get isApproved => supplierStatus == 'APPROVED';
  bool get isUnverified => supplierStatus == 'UNVERIFIED';
  bool get isBlocked => supplierStatus == 'BLOCKED';

  Color get statusBadgeColor {
    switch (supplierStatus) {
      case 'APPROVED':
        return const Color(0xFF10B981);
      case 'BLOCKED':
        return const Color(0xFFEF4444);
      case 'UNVERIFIED':
      default:
        return const Color(0xFFF59E0B);
    }
  }

  Color get qualityBadgeColor {
    switch (qualityStatus) {
      case 'VERIFIED':
        return const Color(0xFF10B981);
      case 'NOT VERIFIED':
        return const Color(0xFFEF4444);
      case 'UNKNOWN':
      default:
        return const Color(0xFF94A3B8);
    }
  }
}

/// Real-time status tracking payload from ASP.NET Core: GET /api/procurement/{id}/status
class ProcurementStatusTracking {
  const ProcurementStatusTracking({
    required this.procurementId,
    required this.materialName,
    required this.requiredSpecification,
    required this.netDeficit,
    required this.procurementStatus,
    this.workflowId,
    this.purchaseOrderId,
    this.purchaseOrderNumber,
    this.purchaseOrderStatus,
    this.paymentStatus,
    this.supplierNotificationStatus,
    this.supplierName,
    this.supplierStatus,
    this.recommendedQuantity,
    this.unitPrice,
    this.totalCost,
    this.qualityEvidence,
    this.leadTimeDays,
    this.availability,
    required this.requiresSupplierVerification,
    required this.requiresHumanApproval,
    this.lastUpdated,
  });

  final int procurementId;
  final String materialName;
  final String requiredSpecification;
  final double netDeficit;
  final String procurementStatus;
  final String? workflowId;
  final int? purchaseOrderId;
  final String? purchaseOrderNumber;
  final String? purchaseOrderStatus;
  final String? paymentStatus;
  final String? supplierNotificationStatus;
  final String? supplierName;
  final String? supplierStatus;
  final double? recommendedQuantity;
  final double? unitPrice;
  final double? totalCost;
  final String? qualityEvidence;
  final int? leadTimeDays;
  final String? availability;
  final bool requiresSupplierVerification;
  final bool requiresHumanApproval;
  final DateTime? lastUpdated;

  factory ProcurementStatusTracking.fromJson(Map<String, dynamic> json) {
    return ProcurementStatusTracking(
      procurementId: json['procurementId'] as int? ?? json['id'] as int? ?? 0,
      materialName: json['materialName'] as String? ?? json['rawMaterialName'] as String? ?? 'Raw Material',
      requiredSpecification: json['requiredSpecification'] as String? ?? '',
      netDeficit: (json['netDeficit'] as num? ?? json['calculatedNetQuantity'] as num? ?? 0).toDouble(),
      procurementStatus: json['procurementStatus'] as String? ?? json['status'] as String? ?? 'Requested',
      workflowId: json['workflowId'] as String?,
      purchaseOrderId: json['purchaseOrderId'] as int? ?? json['generatedPurchaseOrderId'] as int?,
      purchaseOrderNumber: json['purchaseOrderNumber'] as String? ?? json['generatedPoNumber'] as String?,
      purchaseOrderStatus: json['purchaseOrderStatus'] as String?,
      paymentStatus: json['paymentStatus'] as String?,
      supplierNotificationStatus: json['supplierNotificationStatus'] as String?,
      supplierName: json['supplierName'] as String? ?? json['recommendedSupplierName'] as String?,
      supplierStatus: json['supplierStatus'] as String?,
      recommendedQuantity: (json['recommendedQuantity'] as num?)?.toDouble(),
      unitPrice: (json['unitPrice'] as num?)?.toDouble(),
      totalCost: (json['totalCost'] as num?)?.toDouble(),
      qualityEvidence: json['qualityEvidence'] as String?,
      leadTimeDays: json['leadTimeDays'] as int?,
      availability: json['availability'] as String?,
      requiresSupplierVerification: json['requiresSupplierVerification'] as bool? ?? false,
      requiresHumanApproval: json['requiresHumanApproval'] as bool? ?? false,
      lastUpdated: DateTime.tryParse(json['lastUpdated']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  /// Maps backend state to the 11-step pipeline
  ProcurementPipelineStep get pipelineStep {
    final poStatus = (purchaseOrderStatus ?? '').toLowerCase();
    final payStatus = (paymentStatus ?? '').toLowerCase();
    final notifStatus = (supplierNotificationStatus ?? '').toLowerCase();
    final procStatus = procurementStatus.toLowerCase();

    if (poStatus == 'completed' || poStatus == 'received') {
      return ProcurementPipelineStep.completed;
    }
    if (poStatus == 'sent') {
      return ProcurementPipelineStep.incomingSupply;
    }
    if (notifStatus == 'sent' || notifStatus == 'delivered') {
      return ProcurementPipelineStep.supplierNotified;
    }
    if (payStatus == 'paid' || payStatus == 'succeeded') {
      return ProcurementPipelineStep.paid;
    }
    if (payStatus == 'processing' || poStatus == 'payment') {
      return ProcurementPipelineStep.paymentProcessing;
    }
    if (poStatus == 'approved') {
      return ProcurementPipelineStep.approved;
    }
    if (requiresHumanApproval || poStatus == 'pendingapproval' || poStatus == 'draft' || procStatus == 'draftpocreated') {
      return ProcurementPipelineStep.waitingForApproval;
    }
    if (procStatus == 'recommendationready' || (supplierName != null && supplierName!.isNotEmpty)) {
      return ProcurementPipelineStep.recommendationReady;
    }
    if (procStatus == 'researching') {
      return ProcurementPipelineStep.aiResearching;
    }
    if (procStatus == 'requested' || procStatus == 'initiated') {
      return ProcurementPipelineStep.procurementRequested;
    }
    return ProcurementPipelineStep.lowStock;
  }

  int get pipelineIndex => pipelineStep.index;

  bool get isApprovalPending =>
      requiresHumanApproval ||
      (purchaseOrderStatus != null && purchaseOrderStatus!.toLowerCase() == 'pendingapproval') ||
      pipelineStep == ProcurementPipelineStep.waitingForApproval;

  String get qualityStatus {
    final q = (qualityEvidence ?? '').toLowerCase();
    if (q.contains('iso') || q.contains('astm') || q.contains('certified') || q.contains('approved')) {
      return 'VERIFIED';
    }
    if (q.isEmpty || q.contains('unknown')) {
      return 'UNKNOWN';
    }
    return 'NOT VERIFIED';
  }
}

/// Incoming supply record for delivery tracking
class IncomingSupplyItem {
  const IncomingSupplyItem({
    required this.purchaseOrderId,
    required this.poNumber,
    required this.supplierName,
    required this.materialName,
    required this.quantity,
    required this.expectedDelivery,
    required this.deliveryStatus,
    this.trackingNumber,
    this.actualDeliveryDate,
    required this.statusRemarks,
  });

  final int purchaseOrderId;
  final String poNumber;
  final String supplierName;
  final String materialName;
  final double quantity;
  final DateTime expectedDelivery;
  final SupplyDeliveryStatus deliveryStatus;
  final String? trackingNumber;
  final DateTime? actualDeliveryDate;
  final String statusRemarks;

  factory IncomingSupplyItem.fromJson(Map<String, dynamic> json) {
    return IncomingSupplyItem(
      purchaseOrderId: json['purchaseOrderId'] as int? ?? json['id'] as int? ?? 0,
      poNumber: json['poNumber'] as String? ?? 'PO-${json['purchaseOrderId'] ?? json['id']}',
      supplierName: json['supplierName'] as String? ?? 'Supplier',
      materialName: json['materialName'] as String? ?? 'Raw Materials',
      quantity: (json['quantity'] as num? ?? 0).toDouble(),
      expectedDelivery: DateTime.tryParse(json['expectedDelivery']?.toString() ?? '') ?? DateTime.now().add(const Duration(days: 7)),
      deliveryStatus: SupplyDeliveryStatus.fromString(json['deliveryStatus'] as String?),
      trackingNumber: json['trackingNumber'] as String?,
      actualDeliveryDate: json['actualDeliveryDate'] != null ? DateTime.tryParse(json['actualDeliveryDate'].toString()) : null,
      statusRemarks: json['statusRemarks'] as String? ?? '',
    );
  }
}

/// Full Procurement Request entity matching backend ProcurementResponseDto
class ProcurementItem {
  const ProcurementItem({
    required this.id,
    required this.rawMaterialId,
    required this.rawMaterialName,
    required this.rawMaterialSku,
    required this.requiredSpecification,
    required this.productionRequirement,
    required this.currentStock,
    required this.safetyStock,
    required this.existingOpenPoQuantity,
    required this.calculatedNetQuantity,
    required this.maximumBudget,
    required this.requiredByDate,
    required this.qualityRequirement,
    this.preferredRegion,
    required this.status,
    this.workflowId,
    this.recommendedSupplierId,
    this.recommendedSupplierName,
    this.generatedPurchaseOrderId,
    this.generatedPoNumber,
    this.failureReason,
    required this.createdAt,
    required this.updatedAt,
    required this.candidates,
  });

  final int id;
  final int rawMaterialId;
  final String rawMaterialName;
  final String rawMaterialSku;
  final String requiredSpecification;
  final double productionRequirement;
  final double currentStock;
  final double safetyStock;
  final double existingOpenPoQuantity;
  final double calculatedNetQuantity;
  final double maximumBudget;
  final DateTime requiredByDate;
  final String qualityRequirement;
  final String? preferredRegion;
  final String status;
  final String? workflowId;
  final int? recommendedSupplierId;
  final String? recommendedSupplierName;
  final int? generatedPurchaseOrderId;
  final String? generatedPoNumber;
  final String? failureReason;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<SupplierCandidateItem> candidates;

  factory ProcurementItem.fromJson(Map<String, dynamic> json) {
    final rawCandidates = json['candidates'];
    final candidatesList = <SupplierCandidateItem>[];
    if (rawCandidates is List) {
      for (final item in rawCandidates) {
        if (item is Map<String, dynamic>) {
          candidatesList.add(SupplierCandidateItem.fromJson(item));
        }
      }
    }

    return ProcurementItem(
      id: json['id'] as int? ?? 0,
      rawMaterialId: json['rawMaterialId'] as int? ?? 0,
      rawMaterialName: json['rawMaterialName'] as String? ?? 'Raw Material',
      rawMaterialSku: json['rawMaterialSku'] as String? ?? 'RM-SKU',
      requiredSpecification: json['requiredSpecification'] as String? ?? '',
      productionRequirement: (json['productionRequirement'] as num? ?? 0).toDouble(),
      currentStock: (json['currentStock'] as num? ?? 0).toDouble(),
      safetyStock: (json['safetyStock'] as num? ?? 0).toDouble(),
      existingOpenPoQuantity: (json['existingOpenPoQuantity'] as num? ?? 0).toDouble(),
      calculatedNetQuantity: (json['calculatedNetQuantity'] as num? ?? 0).toDouble(),
      maximumBudget: (json['maximumBudget'] as num? ?? 0).toDouble(),
      requiredByDate: DateTime.tryParse(json['requiredByDate']?.toString() ?? '') ?? DateTime.now(),
      qualityRequirement: json['qualityRequirement'] as String? ?? '',
      preferredRegion: json['preferredRegion'] as String?,
      status: json['status'] as String? ?? 'Requested',
      workflowId: json['workflowId'] as String?,
      recommendedSupplierId: json['recommendedSupplierId'] as int?,
      recommendedSupplierName: json['recommendedSupplierName'] as String?,
      generatedPurchaseOrderId: json['generatedPurchaseOrderId'] as int?,
      generatedPoNumber: json['generatedPoNumber'] as String?,
      failureReason: json['failureReason'] as String?,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ?? DateTime.now(),
      candidates: candidatesList,
    );
  }

  double get requiredStock => productionRequirement + safetyStock;

  double get shortage {
    final diff = (productionRequirement + safetyStock) - (currentStock + existingOpenPoQuantity);
    return diff > 0 ? diff : 0.0;
  }

  double get recommendedPurchaseQuantity => calculatedNetQuantity > 0 ? calculatedNetQuantity : shortage;

  SupplierCandidateItem? get recommendedCandidate {
    if (recommendedSupplierName != null && recommendedSupplierName!.isNotEmpty) {
      try {
        return candidates.firstWhere(
          (c) => c.supplierName.toLowerCase() == recommendedSupplierName!.toLowerCase(),
        );
      } catch (_) {}
    }
    if (candidates.isNotEmpty) {
      return candidates.first;
    }
    return null;
  }

  ProcurementPipelineStep get pipelineStep {
    switch (status.toLowerCase()) {
      case 'failed':
      case 'rejected':
      case 'requested':
      case 'initiated':
        return ProcurementPipelineStep.procurementRequested;
      case 'researching':
        return ProcurementPipelineStep.aiResearching;
      case 'recommendationready':
        if (generatedPurchaseOrderId != null && generatedPurchaseOrderId! > 0) {
          return ProcurementPipelineStep.waitingForApproval;
        }
        return ProcurementPipelineStep.recommendationReady;
      case 'draftpocreated':
        return ProcurementPipelineStep.waitingForApproval;
      case 'completed':
        return ProcurementPipelineStep.completed;
      default:
        return ProcurementPipelineStep.procurementRequested;
    }
  }

  int get pipelineIndex => pipelineStep.index;
}

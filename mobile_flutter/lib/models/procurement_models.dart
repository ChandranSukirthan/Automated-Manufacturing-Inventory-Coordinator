import 'package:flutter/material.dart';

/// 12-stage procurement pipeline requested for mobile tracking
enum ProcurementPipelineStep {
  lowStock('LOW STOCK', 'Inventory breached threshold; replenishment required'),
  procurementRequested('PROCUREMENT REQUESTED', 'Procurement requirement logged and initialized'),
  aiResearching('AI RESEARCHING', 'Goal-based agent researching market via Gemini search grounding'),
  suppliersFound('SUPPLIERS FOUND', 'Market candidates discovered with quotes & specifications'),
  candidatesValidated('CANDIDATES VALIDATED', 'Candidates evaluated against quality, MOQ, lead time & budget'),
  recommendationReady('RECOMMENDATION READY', 'Top supplier selected with deterministic pricing'),
  waitingForApproval('WAITING FOR APPROVAL', 'Draft PO formulated; awaiting Supply Chain Manager authorization'),
  approved('APPROVED', 'Purchase order authorized by Supply Chain Manager'),
  paymentProcessing('PAYMENT PROCESSING', 'Settlement transaction initiated via payment gateway'),
  paid('PAID', 'Payment confirmed and reconciled'),
  sentToSupplier('SENT TO SUPPLIER', 'PO documentation dispatched to supplier contact'),
  completed('COMPLETED', 'Procurement lifecycle completed');

  const ProcurementPipelineStep(this.title, this.description);
  final String title;
  final String description;
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
    );
  }

  /// Quality status: VERIFIED, UNKNOWN, NOT VERIFIED
  String get qualityStatus {
    final lower = qualityEvidence.toLowerCase();
    if (lower.contains('iso') || lower.contains('certified') || lower.contains('astm') || lower.contains('approved') || lower.contains('passed')) {
      return 'VERIFIED';
    }
    if (qualityEvidence.trim().isEmpty) {
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

/// Procurement Request entity matching backend ProcurementResponseDto
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

  /// Required stock = Production Requirement + Safety Stock
  double get requiredStock => productionRequirement + safetyStock;

  /// Shortage = Required Stock - Current Stock - Existing Open POs
  double get shortage {
    final diff = (productionRequirement + safetyStock) - (currentStock + existingOpenPoQuantity);
    return diff > 0 ? diff : 0.0;
  }

  /// Recommended Purchase Quantity matches calculatedNetQuantity from backend
  double get recommendedPurchaseQuantity => calculatedNetQuantity > 0 ? calculatedNetQuantity : shortage;

  /// Get the recommended candidate from candidates list
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

  /// Map backend status to 12-stage pipeline step
  ProcurementPipelineStep get pipelineStep {
    switch (status.toLowerCase()) {
      case 'failed':
      case 'rejected':
        return ProcurementPipelineStep.procurementRequested;
      case 'requested':
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
        if (candidates.isNotEmpty) {
          return ProcurementPipelineStep.candidatesValidated;
        }
        return ProcurementPipelineStep.procurementRequested;
    }
  }

  /// Index (0 to 11) for linear progress indicator
  int get pipelineIndex => pipelineStep.index;
}

/// Represents a low-stock alert event linked to procurement
class LowStockEventItem {
  const LowStockEventItem({
    required this.material,
    required this.sku,
    required this.currentStock,
    required this.requiredStock,
    required this.shortage,
    required this.recommendedPurchaseQuantity,
    this.procurementRequestId,
  });

  final String material;
  final String sku;
  final double currentStock;
  final double requiredStock;
  final double shortage;
  final double recommendedPurchaseQuantity;
  final int? procurementRequestId;

  factory LowStockEventItem.fromProcurement(ProcurementItem item) {
    return LowStockEventItem(
      material: item.rawMaterialName,
      sku: item.rawMaterialSku,
      currentStock: item.currentStock,
      requiredStock: item.requiredStock,
      shortage: item.shortage,
      recommendedPurchaseQuantity: item.recommendedPurchaseQuantity,
      procurementRequestId: item.id,
    );
  }
}

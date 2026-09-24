import 'package:flutter/material.dart';

/// Represents a 10-step lifecycle state of a Purchase Order
enum POLifecycleStep {
  lowStockSubmitted('Low Stock Submitted', 'Warehouse stock breached safety threshold'),
  aiProcessing('AI Processing', 'Agentic system evaluating consumption & lead time'),
  poDraftCreated('PO Draft Created', 'Initial procurement draft generated with items'),
  validation('Validation', 'Automated SLA, budget, and supplier validation'),
  waitingForManager('Waiting for Manager', 'Pending executive approval on Manager Console'),
  approved('Approved', 'Purchase Order approved by Supply Chain Manager'),
  paymentProcessing('Payment Processing', 'Settling invoice transaction via payment gateway'),
  paymentSuccessful('Payment Successful', 'Payment captured and reconciled successfully'),
  supplierNotified('Supplier Notified', 'Official PO document emailed to supplier contact'),
  orderSent('Order Sent', 'Procurement order transmitted and active in supplier system');

  const POLifecycleStep(this.title, this.description);
  final String title;
  final String description;
}

/// Summary item used in lists and dashboards
class PurchaseOrderSummary {
  const PurchaseOrderSummary({
    required this.id,
    required this.poNumber,
    required this.supplierName,
    required this.status,
    required this.currency,
    required this.totalCost,
    required this.requiresApproval,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String poNumber;
  final String supplierName;
  final String status;
  final String currency;
  final double totalCost;
  final bool requiresApproval;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory PurchaseOrderSummary.fromJson(Map<String, dynamic> json) {
    return PurchaseOrderSummary(
      id: json['id'] as int? ?? 0,
      poNumber: json['poNumber'] as String? ?? 'PO-${json['id']}',
      supplierName: json['supplierName'] as String? ?? 'Unknown Supplier',
      status: json['status'] as String? ?? 'Draft',
      currency: json['currency'] as String? ?? 'USD',
      totalCost: (json['totalCost'] as num? ?? json['totalAmount'] as num? ?? 0).toDouble(),
      requiresApproval: json['requiresApproval'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  POLifecycleStep get currentLifecycleStep {
    switch (status.toLowerCase()) {
      case 'draft':
        return POLifecycleStep.poDraftCreated;
      case 'pendingapproval':
        return POLifecycleStep.waitingForManager;
      case 'approved':
        return POLifecycleStep.approved;
      case 'payment':
        return POLifecycleStep.paymentProcessing;
      case 'sent':
        return POLifecycleStep.orderSent;
      case 'rejected':
      case 'revisionrequested':
        return POLifecycleStep.waitingForManager;
      default:
        return POLifecycleStep.poDraftCreated;
    }
  }

  Color get statusColor {
    switch (status.toLowerCase()) {
      case 'approved':
        return const Color(0xFF10B981);
      case 'sent':
        return const Color(0xFF06B6D4);
      case 'pendingapproval':
        return const Color(0xFFF59E0B);
      case 'payment':
        return const Color(0xFF8B5CF6);
      case 'rejected':
        return const Color(0xFFEF4444);
      case 'draft':
      default:
        return const Color(0xFF64748B);
    }
  }
}

/// Order line detail in a Purchase Order
class OrderLine {
  const OrderLine({
    required this.id,
    required this.rawMaterialId,
    required this.rawMaterialName,
    required this.rawMaterialSku,
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
  });

  final int id;
  final int rawMaterialId;
  final String rawMaterialName;
  final String rawMaterialSku;
  final String description;
  final double quantity;
  final double unitPrice;
  final double totalPrice;

  factory OrderLine.fromJson(Map<String, dynamic> json) {
    final qty = (json['quantity'] as num? ?? 0).toDouble();
    final price = (json['unitPrice'] as num? ?? 0).toDouble();
    final total = (json['totalPrice'] as num? ?? json['subtotal'] as num? ?? (qty * price)).toDouble();

    return OrderLine(
      id: json['id'] as int? ?? 0,
      rawMaterialId: json['rawMaterialId'] as int? ?? json['materialId'] as int? ?? 0,
      rawMaterialName: json['rawMaterialName'] as String? ?? 'Raw Material',
      rawMaterialSku: json['rawMaterialSku'] as String? ?? 'RM-SKU',
      description: json['description'] as String? ?? '',
      quantity: qty,
      unitPrice: price,
      totalPrice: total,
    );
  }
}

/// Approval audit record
class PurchaseOrderApproval {
  const PurchaseOrderApproval({
    required this.id,
    required this.action,
    this.userId,
    this.userName,
    this.notes,
    required this.timestamp,
  });

  final int id;
  final String action;
  final String? userId;
  final String? userName;
  final String? notes;
  final DateTime timestamp;

  factory PurchaseOrderApproval.fromJson(Map<String, dynamic> json) {
    return PurchaseOrderApproval(
      id: json['id'] as int? ?? 0,
      action: json['action'] as String? ?? 'Updated',
      userId: json['userId']?.toString(),
      userName: json['userName'] as String?,
      notes: json['notes'] as String?,
      timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

/// Payment transaction record
class PaymentTransaction {
  const PaymentTransaction({
    required this.id,
    this.transactionId,
    required this.amount,
    required this.currency,
    required this.paymentStatus,
    this.failureReason,
    required this.timestamp,
  });

  final int id;
  final String? transactionId;
  final double amount;
  final String currency;
  final String paymentStatus;
  final String? failureReason;
  final DateTime timestamp;

  factory PaymentTransaction.fromJson(Map<String, dynamic> json) {
    return PaymentTransaction(
      id: json['id'] as int? ?? 0,
      transactionId: json['transactionId'] as String?,
      amount: (json['amount'] as num? ?? 0).toDouble(),
      currency: json['currency'] as String? ?? 'usd',
      paymentStatus: json['paymentStatus'] as String? ?? 'Completed',
      failureReason: json['failureReason'] as String?,
      timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

/// Full details of a Purchase Order
class PurchaseOrderDetail {
  const PurchaseOrderDetail({
    required this.id,
    required this.poNumber,
    required this.supplierId,
    required this.supplierName,
    required this.status,
    required this.currency,
    required this.totalCost,
    required this.budgetLimit,
    required this.approvalThreshold,
    required this.requiresApproval,
    this.notes,
    this.rejectionReason,
    this.createdByName,
    this.approvedByName,
    this.approvedAt,
    this.stripePaymentIntentId,
    this.stripePaymentStatus,
    this.emailStatus,
    this.emailSentAt,
    required this.orderLines,
    required this.approvals,
    required this.transactions,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String poNumber;
  final int supplierId;
  final String supplierName;
  final String status;
  final String currency;
  final double totalCost;
  final double budgetLimit;
  final double approvalThreshold;
  final bool requiresApproval;
  final String? notes;
  final String? rejectionReason;
  final String? createdByName;
  final String? approvedByName;
  final DateTime? approvedAt;
  final String? stripePaymentIntentId;
  final String? stripePaymentStatus;
  final String? emailStatus;
  final DateTime? emailSentAt;
  final List<OrderLine> orderLines;
  final List<PurchaseOrderApproval> approvals;
  final List<PaymentTransaction> transactions;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory PurchaseOrderDetail.fromJson(Map<String, dynamic> json) {
    final rawLines = json['orderLines'] as List<dynamic>? ?? [];
    final rawApprovals = json['approvals'] as List<dynamic>? ?? [];
    final rawTransactions = json['transactions'] as List<dynamic>? ?? [];

    return PurchaseOrderDetail(
      id: json['id'] as int? ?? 0,
      poNumber: json['poNumber'] as String? ?? 'PO-${json['id']}',
      supplierId: json['supplierId'] as int? ?? 0,
      supplierName: json['supplierName'] as String? ?? 'Unknown Supplier',
      status: json['status'] as String? ?? 'Draft',
      currency: json['currency'] as String? ?? 'USD',
      totalCost: (json['totalCost'] as num? ?? json['totalAmount'] as num? ?? 0).toDouble(),
      budgetLimit: (json['budgetLimit'] as num? ?? 0).toDouble(),
      approvalThreshold: (json['approvalThreshold'] as num? ?? 0).toDouble(),
      requiresApproval: json['requiresApproval'] as bool? ?? false,
      notes: json['notes'] as String?,
      rejectionReason: json['rejectionReason'] as String?,
      createdByName: json['createdByName'] as String?,
      approvedByName: json['approvedByName'] as String?,
      approvedAt: json['approvedAt'] != null ? DateTime.tryParse(json['approvedAt'].toString()) : null,
      stripePaymentIntentId: json['stripePaymentIntentId'] as String?,
      stripePaymentStatus: json['stripePaymentStatus'] as String?,
      emailStatus: json['emailStatus'] as String?,
      emailSentAt: json['emailSentAt'] != null ? DateTime.tryParse(json['emailSentAt'].toString()) : null,
      orderLines: rawLines.map((l) => OrderLine.fromJson(l as Map<String, dynamic>)).toList(),
      approvals: rawApprovals.map((a) => PurchaseOrderApproval.fromJson(a as Map<String, dynamic>)).toList(),
      transactions: rawTransactions.map((t) => PaymentTransaction.fromJson(t as Map<String, dynamic>)).toList(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  POLifecycleStep get currentLifecycleStep {
    switch (status.toLowerCase()) {
      case 'draft':
        return POLifecycleStep.poDraftCreated;
      case 'pendingapproval':
        return POLifecycleStep.waitingForManager;
      case 'approved':
        return POLifecycleStep.approved;
      case 'payment':
        return (stripePaymentStatus?.toLowerCase() == 'succeeded')
            ? POLifecycleStep.paymentSuccessful
            : POLifecycleStep.paymentProcessing;
      case 'sent':
        return POLifecycleStep.orderSent;
      case 'rejected':
      case 'revisionrequested':
        return POLifecycleStep.waitingForManager;
      default:
        return POLifecycleStep.poDraftCreated;
    }
  }

  String get approvalStatusDisplay {
    if (approvedByName != null && approvedByName!.isNotEmpty) {
      return 'Approved by $approvedByName';
    }
    if (status.toLowerCase() == 'approved' || status.toLowerCase() == 'sent' || status.toLowerCase() == 'payment') {
      return 'Approved';
    }
    if (status.toLowerCase() == 'pendingapproval') {
      return 'Pending Executive Approval';
    }
    if (status.toLowerCase() == 'rejected') {
      return 'Rejected${rejectionReason != null ? ': $rejectionReason' : ''}';
    }
    if (status.toLowerCase() == 'revisionrequested') {
      return 'Revision Requested';
    }
    return requiresApproval ? 'Approval Required' : 'Pre-Approved (Under Threshold)';
  }

  String get paymentStatusDisplay {
    if (stripePaymentStatus != null && stripePaymentStatus!.isNotEmpty) {
      return stripePaymentStatus!;
    }
    if (status.toLowerCase() == 'sent') {
      return 'Settled';
    }
    if (status.toLowerCase() == 'payment') {
      return 'Processing';
    }
    return 'Pending Approval';
  }

  String get supplierNotificationDisplay {
    if (emailStatus != null && emailStatus!.isNotEmpty) {
      return emailStatus!;
    }
    if (status.toLowerCase() == 'sent') {
      return 'Dispatched & Emailed';
    }
    return 'Awaiting Order Approval';
  }
}

/// Agentic Workflow Item for tracking multi-agent execution
class AgentWorkflowItem {
  const AgentWorkflowItem({
    required this.workflowId,
    required this.objective,
    required this.currentAgent,
    required this.currentStep,
    required this.status,
    required this.startedAt,
    this.completedAt,
    required this.approvalStatus,
    required this.finalOutcome,
    required this.steps,
    required this.currentStepIndex,
    required this.purchaseOrderId,
    required this.poNumber,
    required this.supplierName,
    required this.totalCost,
  });

  final String workflowId;
  final String objective;
  final String currentAgent;
  final String currentStep;
  final String status;
  final DateTime startedAt;
  final DateTime? completedAt;
  final String approvalStatus;
  final String finalOutcome;
  final List<String> steps;
  final int currentStepIndex;
  final int purchaseOrderId;
  final String poNumber;
  final String supplierName;
  final double totalCost;

  factory AgentWorkflowItem.fromJson(Map<String, dynamic> json) {
    final rawSteps = json['steps'] as List<dynamic>? ?? [];
    return AgentWorkflowItem(
      workflowId: json['workflowId'] as String? ?? 'WF-${json['purchaseOrderId']}',
      objective: json['objective'] as String? ?? 'Inventory replenishment',
      currentAgent: json['currentAgent'] as String? ?? 'Agent',
      currentStep: json['currentStep'] as String? ?? 'Processing',
      status: json['status'] as String? ?? 'Active',
      startedAt: DateTime.tryParse(json['startedAt']?.toString() ?? '') ?? DateTime.now(),
      completedAt: json['completedAt'] != null ? DateTime.tryParse(json['completedAt'].toString()) : null,
      approvalStatus: json['approvalStatus'] as String? ?? 'Draft',
      finalOutcome: json['finalOutcome'] as String? ?? '',
      steps: rawSteps.map((s) => s.toString()).toList(),
      currentStepIndex: json['currentStepIndex'] as int? ?? 0,
      purchaseOrderId: json['purchaseOrderId'] as int? ?? 0,
      poNumber: json['poNumber'] as String? ?? 'PO-${json['purchaseOrderId']}',
      supplierName: json['supplierName'] as String? ?? 'Supplier',
      totalCost: (json['totalCost'] as num? ?? 0).toDouble(),
    );
  }
}

/// Supplier Summary model
class SupplierSummary {
  const SupplierSummary({
    required this.id,
    required this.name,
    required this.contactPerson,
    required this.email,
    required this.phone,
    required this.rating,
    required this.paymentTerms,
    required this.isActive,
  });

  final int id;
  final String name;
  final String contactPerson;
  final String email;
  final String phone;
  final double rating;
  final String paymentTerms;
  final bool isActive;

  factory SupplierSummary.fromJson(Map<String, dynamic> json) {
    return SupplierSummary(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? 'Unknown',
      contactPerson: json['contactPerson'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      rating: (json['rating'] as num? ?? 4.5).toDouble(),
      paymentTerms: json['paymentTerms'] as String? ?? 'Net30',
      isActive: json['isActive'] as bool? ?? true,
    );
  }
}

/// Supplier Analytics summary
class SupplierAnalytics {
  const SupplierAnalytics({
    required this.totalSuppliers,
    required this.activeSuppliers,
    required this.averageRating,
    required this.totalSpend,
  });

  final int totalSuppliers;
  final int activeSuppliers;
  final double averageRating;
  final double totalSpend;

  factory SupplierAnalytics.fromJson(Map<String, dynamic> json) {
    return SupplierAnalytics(
      totalSuppliers: json['totalSuppliers'] as int? ?? 0,
      activeSuppliers: json['activeSuppliers'] as int? ?? 0,
      averageRating: (json['averageRating'] as num? ?? 4.8).toDouble(),
      totalSpend: (json['totalSpend'] as num? ?? 0).toDouble(),
    );
  }
}


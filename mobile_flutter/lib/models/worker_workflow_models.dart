class WorkerWorkflowResult {
  const WorkerWorkflowResult({
    this.workflowId,
    this.status,
    this.currentAgent,
    this.requiresApproval = false,
    this.approvalStatus,
    this.purchaseOrderId,
    this.poNumber,
    this.supplierName,
    this.materialName,
    this.materialSku,
    this.quantity,
    this.unitPrice,
    this.totalAmount,
    this.agentResult,
    this.objective,
  });

  final String? workflowId;
  final String? status;
  final String? currentAgent;
  final bool requiresApproval;
  final String? approvalStatus;
  final int? purchaseOrderId;
  final String? poNumber;
  final String? supplierName;
  final String? materialName;
  final String? materialSku;
  final num? quantity;
  final num? unitPrice;
  final num? totalAmount;
  final dynamic agentResult;
  final String? objective;

  factory WorkerWorkflowResult.fromJson(Map<String, dynamic> json) =>
      WorkerWorkflowResult(
        workflowId: json['workflow_id']?.toString(),
        status: json['status']?.toString(),
        currentAgent: json['current_agent']?.toString(),
        requiresApproval: json['requires_approval'] == true,
        approvalStatus: json['approval_status']?.toString(),
        purchaseOrderId: _toInt(json['purchase_order_id']),
        poNumber: json['po_number']?.toString(),
        supplierName: json['supplier_name']?.toString(),
        materialName: json['material_name']?.toString(),
        materialSku: json['material_sku']?.toString(),
        quantity: _toNum(json['quantity']),
        unitPrice: _toNum(json['unit_price']),
        totalAmount: _toNum(json['total_amount']),
        agentResult: json['agent_result'],
        objective: json['objective']?.toString(),
      );

  static int? _toInt(dynamic value) =>
      value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');

  static num? _toNum(dynamic value) =>
      value is num ? value : num.tryParse(value?.toString() ?? '');
}

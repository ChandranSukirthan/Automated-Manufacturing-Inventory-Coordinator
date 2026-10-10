class WorkflowModel {
  final String id;
  final String workflowId;
  final String objective;
  final String workflowType;
  final String? machineId;
  final int? purchaseOrderId;
  bool get canAuthorize =>
      status == 'WaitingForApproval' && approvalStatus == 'Pending';
  bool get canAuthorizeMaintenance =>
      workflowType == 'Maintenance' && canAuthorize;
  final String currentAgent;
  final String status;
  final String approvalStatus;
  final String? finalOutcome;
  final int currentStep;
  final int totalSteps;
  final List<WorkflowStepModel> steps;
  final bool isWaitingForApproval;
  final DateTime createdAt;
  final DateTime updatedAt;

  String? get result => finalOutcome;

  WorkflowModel({
    required this.id,
    required this.workflowId,
    required this.objective,
    this.workflowType = "Procurement",
    this.machineId,
    this.purchaseOrderId,
    required this.currentAgent,
    required this.status,
    required this.approvalStatus,
    this.finalOutcome,
    required this.currentStep,
    required this.totalSteps,
    required this.steps,
    required this.isWaitingForApproval,
    required this.createdAt,
    required this.updatedAt,
  });

  static String _enumLabel(
    dynamic value,
    List<String> labels,
    String fallback,
  ) {
    final index = int.tryParse(value?.toString() ?? '');
    if (index != null && index >= 0 && index < labels.length) {
      return labels[index];
    }
    return value?.toString() ?? fallback;
  }

  factory WorkflowModel.fromJson(Map<String, dynamic> json) {
    List<WorkflowStepModel> stepList = [];
    if (json['steps'] is List) {
      stepList = (json['steps'] as List)
          .map((s) => WorkflowStepModel.fromJson(s as Map<String, dynamic>))
          .toList();
    }

    final details = json['details'];
    if (stepList.isEmpty &&
        details is Map &&
        details['completed_steps'] is List) {
      final completed = details['completed_steps'] as List;
      stepList = List.generate(
        completed.length,
        (i) => WorkflowStepModel(
          stepNumber: i + 1,
          agentName: 'Recorded stage',
          status: 'Completed',
          output: completed[i].toString(),
        ),
      );
    }
    final idStr = json['id']?.toString() ?? '';
    final wfId = json['workflowId']?.toString() ?? idStr;
    final statusStr = _enumLabel(json['status'], [
      'Running',
      'Completed',
      'Failed',
      'WaitingForApproval',
    ], 'Pending');
    final approvalStr = _enumLabel(json['approvalStatus'], [
      'Pending',
      'Approved',
      'Rejected',
      'RevisionRequested',
    ], 'Pending');
    final waiting =
        json['isWaitingForApproval'] as bool? ??
        (approvalStr.toLowerCase().contains('waiting') ||
            statusStr.toLowerCase().contains('waiting'));

    return WorkflowModel(
      id: idStr,
      workflowId: wfId,
      workflowType: json['workflowType']?.toString() ?? 'Procurement',
      machineId: json['machineId']?.toString(),
      purchaseOrderId: (json['purchaseOrderId'] as num?)?.toInt(),
      objective: json['objective']?.toString() ?? 'Agent Workflow Task',
      currentAgent: json['currentAgent']?.toString() ?? 'Planner',
      status: statusStr,
      approvalStatus: approvalStr,
      finalOutcome:
          json['finalOutcome']?.toString() ?? json['result']?.toString(),
      currentStep: (json['currentStep'] as num?)?.toInt() ?? 0,
      totalSteps: (json['totalSteps'] as num?)?.toInt() ?? stepList.length,
      steps: stepList,
      isWaitingForApproval: waiting,
      createdAt: json['startedAt'] != null
          ? DateTime.tryParse(json['startedAt'].toString()) ?? DateTime.now()
          : (json['createdAt'] != null
                ? DateTime.tryParse(json['createdAt'].toString()) ??
                      DateTime.now()
                : DateTime.now()),
      updatedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'].toString()) ?? DateTime.now()
          : (json['updatedAt'] != null
                ? DateTime.tryParse(json['updatedAt'].toString()) ??
                      DateTime.now()
                : DateTime.now()),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'workflowType': workflowType,
    'machineId': machineId,
    'purchaseOrderId': purchaseOrderId,
    'workflowId': workflowId,
    'objective': objective,
    'currentAgent': currentAgent,
    'status': status,
    'approvalStatus': approvalStatus,
    'finalOutcome': finalOutcome,
    'currentStep': currentStep,
    'totalSteps': totalSteps,
    'steps': steps.map((s) => s.toJson()).toList(),
    'isWaitingForApproval': isWaitingForApproval,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
}

class WorkflowStepModel {
  final int stepNumber;
  final String agentName;
  final String status;
  final String? output;
  final DateTime? executedAt;

  WorkflowStepModel({
    required this.stepNumber,
    required this.agentName,
    required this.status,
    this.output,
    this.executedAt,
  });

  factory WorkflowStepModel.fromJson(Map<String, dynamic> json) {
    return WorkflowStepModel(
      stepNumber: (json['stepNumber'] as num?)?.toInt() ?? 1,
      agentName: json['agentName']?.toString() ?? 'Agent',
      status: json['status']?.toString() ?? 'Pending',
      output: json['output']?.toString(),
      executedAt: json['executedAt'] != null
          ? DateTime.tryParse(json['executedAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'stepNumber': stepNumber,
    'agentName': agentName,
    'status': status,
    'output': output,
    'executedAt': executedAt?.toIso8601String(),
  };
}

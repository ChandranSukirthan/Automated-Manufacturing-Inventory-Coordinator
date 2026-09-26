class WorkflowModel {
  final String id;
  final String workflowId;
  final String objective;
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

  WorkflowModel({
    required this.id,
    required this.workflowId,
    required this.objective,
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

  factory WorkflowModel.fromJson(Map<String, dynamic> json) {
    List<WorkflowStepModel> stepList = [];
    if (json['steps'] is List) {
      stepList = (json['steps'] as List)
          .map((s) => WorkflowStepModel.fromJson(s as Map<String, dynamic>))
          .toList();
    }

    final idStr = json['id']?.toString() ?? '';
    final wfId = json['workflowId']?.toString() ?? (idStr.length > 8 ? 'WF-${idStr.substring(0, 6).toUpperCase()}' : 'WF-1001');
    final statusStr = json['status']?.toString() ?? 'Pending';
    final approvalStr = json['approvalStatus']?.toString() ?? 
        (json['isWaitingForApproval'] == true ? 'Waiting For Approval' : 'Pending');
    final waiting = json['isWaitingForApproval'] as bool? ??
        (approvalStr.toLowerCase().contains('waiting') || statusStr.toLowerCase().contains('waiting'));

    return WorkflowModel(
      id: idStr,
      workflowId: wfId,
      objective: json['objective']?.toString() ?? 'Agent Workflow Task',
      currentAgent: json['currentAgent']?.toString() ?? 'Planner',
      status: statusStr,
      approvalStatus: approvalStr,
      finalOutcome: json['finalOutcome']?.toString() ?? json['result']?.toString(),
      currentStep: (json['currentStep'] as num?)?.toInt() ?? 0,
      totalSteps: (json['totalSteps'] as num?)?.toInt() ?? (stepList.isNotEmpty ? stepList.length : 5),
      steps: stepList,
      isWaitingForApproval: waiting,
      createdAt: json['startedAt'] != null
          ? DateTime.tryParse(json['startedAt'].toString()) ?? DateTime.now()
          : (json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now() : DateTime.now()),
      updatedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'].toString()) ?? DateTime.now()
          : (json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'].toString()) ?? DateTime.now() : DateTime.now()),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
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

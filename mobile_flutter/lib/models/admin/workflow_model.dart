class WorkflowModel {
  final String id;
  final String objective;
  final String status;
  final int currentStep;
  final int totalSteps;
  final List<WorkflowStepModel> steps;
  final String? result;
  final bool isWaitingForApproval;
  final DateTime createdAt;
  final DateTime updatedAt;

  WorkflowModel({
    required this.id,
    required this.objective,
    required this.status,
    required this.currentStep,
    required this.totalSteps,
    required this.steps,
    this.result,
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

    return WorkflowModel(
      id: json['id']?.toString() ?? '',
      objective: json['objective']?.toString() ?? 'Agent Workflow Task',
      status: json['status']?.toString() ?? 'Pending',
      currentStep: (json['currentStep'] as num?)?.toInt() ?? 0,
      totalSteps: (json['totalSteps'] as num?)?.toInt() ?? (stepList.isNotEmpty ? stepList.length : 5),
      steps: stepList,
      result: json['result']?.toString(),
      isWaitingForApproval: json['isWaitingForApproval'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'objective': objective,
        'status': status,
        'currentStep': currentStep,
        'totalSteps': totalSteps,
        'steps': steps.map((s) => s.toJson()).toList(),
        'result': result,
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

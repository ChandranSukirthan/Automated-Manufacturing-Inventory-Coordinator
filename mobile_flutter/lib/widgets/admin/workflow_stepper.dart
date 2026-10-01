import 'package:flutter/material.dart';
import '../../models/admin/workflow_model.dart';
import 'status_chip.dart';

class WorkflowStepper extends StatelessWidget {
  final List<WorkflowStepModel> steps;
  final int currentStep;

  const WorkflowStepper({
    required this.steps,
    required this.currentStep,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'No steps recorded for this workflow.',
          style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
        ),
      );
    }

    return Column(
      children: List.generate(steps.length, (index) {
        final step = steps[index];
        final isLast = index == steps.length - 1;
        final isPassed = index + 1 < currentStep || step.status == 'Completed';
        final isCurrent = index + 1 == currentStep && step.status != 'Completed';

        Color nodeColor = const Color(0xFF64748B);
        if (isPassed) {
          nodeColor = const Color(0xFF10B981);
        } else if (isCurrent) {
          nodeColor = const Color(0xFF06B6D4);
        }

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Circle node and vertical track
              Column(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: nodeColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: nodeColor, width: 2),
                    ),
                    alignment: Alignment.center,
                    child: isPassed
                        ? const Icon(Icons.check, size: 14, color: Color(0xFF10B981))
                        : Text(
                            '${step.stepNumber}',
                            style: TextStyle(
                              color: nodeColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        color: isPassed
                            ? const Color(0xFF10B981).withValues(alpha: 0.5)
                            : const Color(0xFF334155),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),
              // Content
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            step.agentName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          StatusChip(status: step.status, showDot: false),
                        ],
                      ),
                      if (step.output != null && step.output!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF334155)),
                          ),
                          child: Text(
                            step.output!,
                            style: const TextStyle(
                              color: Color(0xFFCBD5E1),
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

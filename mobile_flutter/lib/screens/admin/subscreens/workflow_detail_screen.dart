import 'package:flutter/material.dart';
import '../../../models/admin/workflow_model.dart';
import '../../../services/admin/admin_api_service.dart';
import '../../../widgets/admin/admin_card.dart';
import '../../../widgets/admin/status_chip.dart';
import '../../../widgets/admin/workflow_stepper.dart';

class WorkflowDetailScreen extends StatefulWidget {
  final WorkflowModel workflow;
  final AdminApiService service;

  const WorkflowDetailScreen({
    required this.workflow,
    required this.service,
    super.key,
  });

  @override
  State<WorkflowDetailScreen> createState() => _WorkflowDetailScreenState();
}

class _WorkflowDetailScreenState extends State<WorkflowDetailScreen> {
  late WorkflowModel _currentWorkflow;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _currentWorkflow = widget.workflow;
  }

  Future<void> _handleDecision(bool approve) async {
    setState(() => _submitting = true);
    try {
      if (approve) {
        await widget.service.approveWorkflow(_currentWorkflow.workflowId);
      } else {
        await widget.service.rejectWorkflow(_currentWorkflow.workflowId);
      }

      if (mounted) {
        final updated = await widget.service.getWorkflowById(_currentWorkflow.id);
        if (!mounted) return;
        setState(() {
          _currentWorkflow = updated;
          _submitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(approve ? 'Workflow plan approved!' : 'Workflow plan rejected.'),
            backgroundColor: approve ? const Color(0xFF10B981) : const Color(0xFFEF4444),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Action failed: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        title: const Text('Workflow Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AdminCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF06B6D4).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF06B6D4)),
                      ),
                      child: Text(
                        _currentWorkflow.workflowId,
                        style: const TextStyle(
                          color: Color(0xFF06B6D4),
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        StatusChip(status: _currentWorkflow.status),
                        const SizedBox(width: 6),
                        StatusChip(status: _currentWorkflow.approvalStatus, showDot: false),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _currentWorkflow.objective,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Current Agent: ${_currentWorkflow.currentAgent}',
                      style: const TextStyle(color: Color(0xFF06B6D4), fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'Started: ${_currentWorkflow.createdAt.toLocal().toString().split('.')[0]}',
                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (_currentWorkflow.isWaitingForApproval) ...[
            AdminCard(
              backgroundColor: const Color(0xFF78350F).withValues(alpha: 0.25),
              borderColor: const Color(0xFFF59E0B),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.gavel_rounded, color: Color(0xFFF59E0B), size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Human-in-the-Loop Approval Required',
                        style: TextStyle(
                          color: Color(0xFFFDE68A),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'The AI Planner agent has generated an optimization proposal that requires IT Admin confirmation before executing plant changes.',
                    style: TextStyle(color: Color(0xFFE2E8F0), fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _submitting ? null : () => _handleDecision(true),
                          icon: const Icon(Icons.check_circle_outline, size: 18),
                          label: const Text('Approve Plan'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _submitting ? null : () => _handleDecision(false),
                          icon: const Icon(Icons.cancel_outlined, size: 18, color: Color(0xFFEF4444)),
                          label: const Text('Reject', style: TextStyle(color: Color(0xFFEF4444))),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFEF4444)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Multi-agent execution graph
          AdminCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Multi-Agent Graph Pipeline',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 16),
                WorkflowStepper(
                  steps: _currentWorkflow.steps,
                  currentStep: _currentWorkflow.currentStep,
                ),
              ],
            ),
          ),

          if (_currentWorkflow.finalOutcome != null && _currentWorkflow.finalOutcome!.isNotEmpty) ...[
            const SizedBox(height: 16),
            AdminCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Final Outcome / Result',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Text(
                      _currentWorkflow.finalOutcome!,
                      style: const TextStyle(
                        color: Color(0xFFCBD5E1),
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

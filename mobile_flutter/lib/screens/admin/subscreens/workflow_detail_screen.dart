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
      final targetId = _currentWorkflow.workflowId.isNotEmpty
          ? _currentWorkflow.workflowId
          : _currentWorkflow.id;
      final res = approve
          ? await widget.service.approveWorkflow(targetId)
          : await widget.service.rejectWorkflow(targetId);

      if (mounted) {
        WorkflowModel updated;
        if (res is Map<String, dynamic>) {
          updated = WorkflowModel.fromJson(res);
        } else {
          updated = await widget.service.getWorkflowById(targetId);
        }
        if (!mounted) return;
        setState(() {
          _currentWorkflow = updated;
          _submitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              approve ? 'Workflow plan approved!' : 'Workflow plan rejected.',
            ),
            backgroundColor: approve
                ? const Color(0xFF10B981)
                : const Color(0xFFEF4444),
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

  Widget _detail(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
        ),
        const SizedBox(height: 4),
        SelectableText(
          value,
          style: const TextStyle(color: Colors.white, height: 1.4),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        title: const Text(
          'Workflow Details',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AdminCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Text(
                      '${_currentWorkflow.workflowType} Workflow',
                      style: TextStyle(
                        color: Color(0xFF06B6D4),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    StatusChip(status: _currentWorkflow.status),
                    StatusChip(status: _currentWorkflow.approvalStatus),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _currentWorkflow.objective,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Created: ${_currentWorkflow.createdAt.toUtc().add(const Duration(hours: 5, minutes: 30)).toString().split('.')[0]}',
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          AdminCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Request details',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                _detail('Workflow ID', _currentWorkflow.workflowId),
                _detail('Current agent', _currentWorkflow.currentAgent),
                if (_currentWorkflow.machineId != null)
                  _detail('Machine ID', _currentWorkflow.machineId!),
                if (_currentWorkflow.purchaseOrderId != null)
                  _detail(
                    'Purchase order',
                    '#${_currentWorkflow.purchaseOrderId}',
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_currentWorkflow.canAuthorize) ...[
            AdminCard(
              backgroundColor: const Color(0xFF78350F).withValues(alpha: 0.25),
              borderColor: const Color(0xFFF59E0B),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.gavel_rounded,
                        color: Color(0xFFF59E0B),
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Admin approval required',
                          style: TextStyle(
                            color: Color(0xFFFDE68A),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _currentWorkflow.workflowType == 'Maintenance'
                        ? 'Approval places this machine under maintenance. Reject to decline the request.'
                        : 'Approve or reject this workflow proposal. Purchase order payment remains the Supply Chain Manager responsibility.',
                    style: TextStyle(color: Color(0xFFE2E8F0), fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _submitting
                              ? null
                              : () => _handleDecision(true),
                          icon: const Icon(
                            Icons.check_circle_outline,
                            size: 18,
                          ),
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
                          onPressed: _submitting
                              ? null
                              : () => _handleDecision(false),
                          icon: const Icon(
                            Icons.cancel_outlined,
                            size: 18,
                            color: Color(0xFFEF4444),
                          ),
                          label: const Text(
                            'Reject',
                            style: TextStyle(color: Color(0xFFEF4444)),
                          ),
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
                  'Recorded agent activity',
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

          if (_currentWorkflow.finalOutcome != null &&
              _currentWorkflow.finalOutcome!.isNotEmpty) ...[
            const SizedBox(height: 16),
            AdminCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Workflow outcome',
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

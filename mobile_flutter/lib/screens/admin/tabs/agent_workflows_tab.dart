import 'package:flutter/material.dart';
import '../../../models/admin/workflow_model.dart';
import '../../../services/admin/admin_api_service.dart';
import '../../../widgets/admin/admin_card.dart';
import '../../../widgets/admin/status_chip.dart';
import '../subscreens/workflow_detail_screen.dart';

class AgentWorkflowsTab extends StatefulWidget {
  final List<WorkflowModel> workflows;
  final AdminApiService service;
  final bool loading;
  final Future<void> Function() onRefresh;

  const AgentWorkflowsTab({
    required this.workflows,
    required this.service,
    required this.loading,
    required this.onRefresh,
    super.key,
  });

  @override
  State<AgentWorkflowsTab> createState() => _AgentWorkflowsTabState();
}

class _AgentWorkflowsTabState extends State<AgentWorkflowsTab> {
  final _objectiveController = TextEditingController();
  bool _triggering = false;

  @override
  void dispose() {
    _objectiveController.dispose();
    super.dispose();
  }

  Future<void> _showTriggerDialog() async {
    _objectiveController.text = 'Rebalance production output between Line 1 and CNC machines';
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Row(
          children: [
            Icon(Icons.psychology_rounded, color: Color(0xFF06B6D4)),
            SizedBox(width: 8),
            Text('Trigger Agent Workflow', style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the objective for the multi-agent Planner pipeline:',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _objectiveController,
              maxLines: 3,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF0F172A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF334155)),
                ),
                hintText: 'e.g. Schedule preventive maintenance for Hydraulic Press',
                hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            onPressed: _triggering
                ? null
                : () async {
                    final obj = _objectiveController.text.trim();
                    if (obj.isEmpty) return;
                    Navigator.pop(ctx);
                    setState(() => _triggering = true);
                    try {
                      await widget.service.triggerWorkflow(obj);
                      await widget.onRefresh();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Agent workflow triggered successfully!'),
                            backgroundColor: Color(0xFF10B981),
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to trigger workflow: $e'),
                            backgroundColor: const Color(0xFFEF4444),
                          ),
                        );
                      }
                    } finally {
                      if (mounted) setState(() => _triggering = false);
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF06B6D4),
              foregroundColor: const Color(0xFF0B0F19),
            ),
            child: const Text('Dispatch Pipeline'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _triggering ? null : _showTriggerDialog,
        backgroundColor: const Color(0xFF06B6D4),
        foregroundColor: const Color(0xFF0B0F19),
        icon: _triggering
            ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0B0F19)))
            : const Icon(Icons.add_task_rounded),
        label: const Text('New Workflow', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: RefreshIndicator(
        onRefresh: widget.onRefresh,
        color: const Color(0xFF06B6D4),
        backgroundColor: const Color(0xFF0F172A),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Multi-Agent Workflows',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                Text(
                  '${widget.workflows.length} total',
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (widget.workflows.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Column(
                    children: [
                      Icon(Icons.psychology_outlined, color: Color(0xFF64748B), size: 48),
                      SizedBox(height: 12),
                      Text(
                        'No agent workflows recorded yet.\nTap "+ New Workflow" to initiate one.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...widget.workflows.map((wf) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AdminCard(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => WorkflowDetailScreen(
                            workflow: wf,
                            service: widget.service,
                          ),
                        ),
                      );
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            StatusChip(status: wf.status),
                            if (wf.isWaitingForApproval)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF78350F).withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFF59E0B)),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.touch_app, size: 12, color: Color(0xFFF59E0B)),
                                    SizedBox(width: 4),
                                    Text(
                                      'AWAITING APPROVAL',
                                      style: TextStyle(
                                        color: Color(0xFFFDE68A),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          wf.objective,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Step ${wf.currentStep} of ${wf.totalSteps}',
                              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                            ),
                            Text(
                              wf.createdAt.toLocal().toString().split('.')[0],
                              style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

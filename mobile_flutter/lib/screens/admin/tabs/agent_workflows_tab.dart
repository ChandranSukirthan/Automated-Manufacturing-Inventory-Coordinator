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
  final _search = TextEditingController();
  String _type = 'All', _status = 'All', _approval = 'All';
  bool _needsApproval = false;

  @override
  void dispose() {
    _objectiveController.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _showTriggerDialog() async {
    _objectiveController.text = 'Schedule preventive maintenance';
    final machines = await widget.service.getMachines();
    if (!mounted) return;
    String? machineId;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, updateDialog) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Row(
            children: [
              Icon(Icons.psychology_rounded, color: Color(0xFF06B6D4)),
              SizedBox(width: 8),
              Text(
                'Trigger Agent Workflow',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select the exact machine for IT Admin maintenance authorization:',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Machine'),
                items: machines
                    .map(
                      (m) => DropdownMenuItem(value: m.id, child: Text(m.name)),
                    )
                    .toList(),
                onChanged: (value) => updateDialog(() => machineId = value),
              ),
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
                  hintText:
                      'e.g. Schedule preventive maintenance for Hydraulic Press',
                  hintStyle: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Color(0xFF94A3B8)),
              ),
            ),
            ElevatedButton(
              onPressed: _triggering
                  ? null
                  : () async {
                      final obj = _objectiveController.text.trim();
                      if (obj.isEmpty || machineId == null) return;
                      Navigator.pop(ctx);
                      setState(() => _triggering = true);
                      try {
                        await widget.service.triggerWorkflow(
                          "$obj [MachineID: $machineId]",
                        );
                        await widget.onRefresh();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Agent workflow triggered successfully!',
                              ),
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
      ),
    );
  }

  Widget _filter(
    String label,
    String value,
    List<String> values,
    ValueChanged<String?> change,
  ) => SizedBox(
    width: 220,
    child: DropdownButtonFormField<String>(
      initialValue: value,
      key: ValueKey('$label$value'),
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: values
          .map((v) => DropdownMenuItem(value: v, child: Text(v)))
          .toList(),
      onChanged: change,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final types = {
      'All',
      ...widget.workflows.map((w) => w.workflowType),
    }.toList();
    final filtered =
        widget.workflows
            .where(
              (w) =>
                  (_type == 'All' || w.workflowType == _type) &&
                  (_status == 'All' || w.status == _status) &&
                  (_approval == 'All' || w.approvalStatus == _approval) &&
                  (!_needsApproval || w.canAuthorize) &&
                  '${w.workflowId} ${w.objective} ${w.currentAgent} ${w.machineId ?? ''} ${w.purchaseOrderId ?? ''}'
                      .toLowerCase()
                      .contains(query),
            )
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _triggering ? null : _showTriggerDialog,
        icon: const Icon(Icons.add_task),
        label: const Text('New Workflow'),
      ),
      body: RefreshIndicator(
        onRefresh: widget.onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            const Text(
              'AI Workflows & Approvals',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            AdminCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Search workflows',
                      hintText: 'Objective, workflow ID or agent',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _search.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear search',
                              icon: const Icon(Icons.close),
                              onPressed: () => setState(_search.clear),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _filter(
                        'Workflow type',
                        types.contains(_type) ? _type : 'All',
                        types,
                        (v) => setState(() => _type = v!),
                      ),
                      _filter('Workflow status', _status, [
                        'All',
                        'Running',
                        'WaitingForApproval',
                        'Completed',
                        'Failed',
                      ], (v) => setState(() => _status = v!)),
                      _filter('Approval status', _approval, [
                        'All',
                        'Pending',
                        'Approved',
                        'Rejected',
                        'RevisionRequested',
                      ], (v) => setState(() => _approval = v!)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      FilterChip(
                        label: Text(
                          'Needs approval (${widget.workflows.where((w) => w.canAuthorize).length})',
                        ),
                        selected: _needsApproval,
                        onSelected: (v) => setState(() => _needsApproval = v),
                      ),
                      TextButton(
                        onPressed: () => setState(() {
                          _search.clear();
                          _type = _status = _approval = 'All';
                          _needsApproval = false;
                        }),
                        child: const Text('Clear filters'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${filtered.length} of ${widget.workflows.length} workflows - Newest first',
              style: const TextStyle(color: Color(0xFF94A3B8)),
            ),
            if (widget.loading) const LinearProgressIndicator(),
            const SizedBox(height: 12),
            if (filtered.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No workflows match these filters.',
                  style: TextStyle(color: Color(0xFF94A3B8)),
                ),
              ),
            ...filtered.map(
              (wf) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AdminCard(
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => WorkflowDetailScreen(
                          workflow: wf,
                          service: widget.service,
                        ),
                      ),
                    );
                    if (mounted) await widget.onRefresh();
                  },
                  borderColor: wf.canAuthorize ? const Color(0xFFF59E0B) : null,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          StatusChip(status: wf.status),
                          StatusChip(status: wf.approvalStatus),
                          Text(
                            wf.workflowType,
                            style: const TextStyle(
                              color: Color(0xFF06B6D4),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        wf.objective,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        wf.workflowId,
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Current agent: ${wf.currentAgent}',
                        style: const TextStyle(color: Color(0xFFCBD5E1)),
                      ),
                      Text(
                        'Started: ${wf.createdAt.toUtc().add(const Duration(hours: 5, minutes: 30)).toString().split('.')[0]}',
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 12,
                        ),
                      ),
                      if (wf.canAuthorize)
                        const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: Text(
                            'Review and approve',
                            style: TextStyle(
                              color: Color(0xFFFBBF24),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      if (wf.finalOutcome?.isNotEmpty == true)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            wf.finalOutcome!,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Color(0xFFCBD5E1)),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

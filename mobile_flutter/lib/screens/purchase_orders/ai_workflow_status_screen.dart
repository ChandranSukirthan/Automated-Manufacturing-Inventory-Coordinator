import '../../utils/locale.dart';
import 'package:flutter/material.dart';
import '../../models/purchase_order_models.dart';
import '../../services/purchase_order_service.dart';
import '../../widgets/app_widgets.dart';
import 'po_details_screen.dart';

class AIWorkflowStatusScreen extends StatefulWidget {
  const AIWorkflowStatusScreen({
    required this.service,
    this.showAppBar = true,
    super.key,
  });

  final PurchaseOrderService service;
  final bool showAppBar;

  @override
  State<AIWorkflowStatusScreen> createState() => _AIWorkflowStatusScreenState();
}

class _AIWorkflowStatusScreenState extends State<AIWorkflowStatusScreen> {
  bool _loading = true;
  String? _error;
  List<AgentWorkflowItem> _workflows = [];
  String? _retrying;

  Future<void> _retryWorkflow(AgentWorkflowItem workflow) async {
    setState(() { _retrying = workflow.workflowId; _error = null; });
    try {
      await widget.service.retryWorkflow(workflow.workflowId);
      await _fetchWorkflows();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _retrying = null);
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchWorkflows();
  }

  Future<void> _fetchWorkflows() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await widget.service.getAgentWorkflows();
      if (mounted) {
        setState(() {
          _workflows = data.where((w) {
            final type = w.workflowType.toLowerCase();
            final id = w.workflowId.toLowerCase();
            return type != 'maintenance' && !id.startsWith('wf-maint');
          }).toList();
          _loading = false;
        });
      }
    } catch (err) {
      if (mounted) {
        setState(() {
          _error = err.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const navyBg = Color(0xFF070E17);
    const cardBg = Color(0xFF0F1B2B);
    const cyanAccent = Color(0xFF5CC8F8);

    return Scaffold(
      backgroundColor: navyBg,
      appBar: widget.showAppBar
          ? AppBar(
              backgroundColor: navyBg,
              elevation: 0,
              title: const Text(
                'AI Workflow Status',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
                  onPressed: _fetchWorkflows,
                  tooltip: 'Refresh',
                ),
              ],
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? StateMessage(
                  message: _error!,
                  icon: Icons.cloud_off,
                  action: _fetchWorkflows,
                )
              : _workflows.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.psychology_outlined, size: 54, color: Colors.white.withValues(alpha: 0.2)),
                          const SizedBox(height: 16),
                          const Text(
                            'No active multi-agent workflows found.',
                            style: TextStyle(color: Colors.white54, fontSize: 14),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchWorkflows,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16.0),
                        itemCount: _workflows.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 16),
                        itemBuilder: (context, idx) {
                          final wf = _workflows[idx];
                          final isComplete = wf.status.toLowerCase() == 'completed';
                          final isWaiting = wf.status.toLowerCase().contains('waiting') ||
                              wf.approvalStatus.toLowerCase().contains('pending');

                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isWaiting
                                    ? const Color(0xFFF59E0B).withValues(alpha: 0.3)
                                    : Colors.white.withValues(alpha: 0.08),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        wf.workflowId,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: isComplete
                                            ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                            : isWaiting
                                                ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                                                : const Color(0xFF5CC8F8).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isComplete
                                              ? const Color(0xFF10B981).withValues(alpha: 0.3)
                                              : isWaiting
                                                  ? const Color(0xFFF59E0B).withValues(alpha: 0.4)
                                                  : const Color(0xFF5CC8F8).withValues(alpha: 0.3),
                                        ),
                                      ),
                                      child: Text(
                                        wf.status,
                                        style: TextStyle(
                                          color: isComplete
                                              ? const Color(0xFF10B981)
                                              : isWaiting
                                                  ? const Color(0xFFF59E0B)
                                                  : const Color(0xFF5CC8F8),
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  wf.objective,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Divider(color: Colors.white10, height: 1),
                                const SizedBox(height: 12),

                                // Agent and step details
                                Row(
                                  children: [
                                    const Icon(Icons.smart_toy_outlined, size: 16, color: cyanAccent),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Agent: ${wf.currentAgent}',
                                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(Icons.trending_flat_rounded, size: 16, color: Colors.white38),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Step: ${wf.currentStep}',
                                        style: const TextStyle(color: Colors.white60, fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 12),

                                ...wf.errors.map((error) => Text(error, style: const TextStyle(color: Colors.redAccent))),
                                if (wf.finalOutcome.isNotEmpty) Text(wf.finalOutcome, style: const TextStyle(color: Colors.white70)),
                                if (wf.canRetry) ElevatedButton(
                                  onPressed: _retrying == wf.workflowId ? null : () => _retryWorkflow(wf),
                                  child: Text(_retrying == wf.workflowId ? 'Queuing…' : 'Retry analysis')),
                                // Steps chip timeline
                                if (wf.steps.isNotEmpty)
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: wf.steps.asMap().entries.map((entry) {
                                        final sIdx = entry.key;
                                        final sName = entry.value;
                                        final isPassed = sIdx <= wf.currentStepIndex;

                                        return Container(
                                          margin: const EdgeInsets.only(right: 6),
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: isPassed
                                                ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                                : Colors.white.withValues(alpha: 0.04),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: isPassed
                                                  ? const Color(0xFF10B981).withValues(alpha: 0.3)
                                                  : Colors.white10,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (isPassed) ...[
                                                const Icon(Icons.check, size: 12, color: Color(0xFF10B981)),
                                                const SizedBox(width: 4),
                                              ],
                                              Text(
                                                sName,
                                                style: TextStyle(
                                                  color: isPassed ? Colors.white : Colors.white38,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),

                                const SizedBox(height: 12),
                                Text(
                                  'Linked: ${wf.poNumber} • ${formatMoney(wf.totalCost, currency: wf.currency)}',
                                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                                ),
                                if (wf.purchaseOrderId > 0) ...[
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => PODetailsScreen(
                                            service: widget.service,
                                            poId: wf.purchaseOrderId,
                                          ),
                                        ),
                                      ).then((_) => _fetchWorkflows()),
                                      icon: const Icon(Icons.rate_review_rounded, size: 16),
                                      label: const Text(
                                        'Review Purchase Order',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF10B981),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

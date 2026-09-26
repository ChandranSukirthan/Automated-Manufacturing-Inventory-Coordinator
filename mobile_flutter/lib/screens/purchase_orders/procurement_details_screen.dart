import 'package:flutter/material.dart';
import '../../models/procurement_models.dart';
import '../../services/purchase_order_service.dart';
import '../../widgets/app_widgets.dart';

/// 11-Stage Procurement Status & Recommendation Tracker for Mobile
/// Enables Floor Workers & Managers to track raw-material procurement pipelines.
class ProcurementDetailsScreen extends StatefulWidget {
  const ProcurementDetailsScreen({
    required this.service,
    this.procurementId,
    super.key,
  });

  final PurchaseOrderService service;
  final int? procurementId;

  @override
  State<ProcurementDetailsScreen> createState() => _ProcurementDetailsScreenState();
}

class _ProcurementDetailsScreenState extends State<ProcurementDetailsScreen> {
  bool _loading = true;
  String? _error;
  ProcurementStatusTracking? _statusTracking;
  ProcurementItem? _procurementItem;
  int? _activeId;

  @override
  void initState() {
    super.initState();
    _activeId = widget.procurementId;
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      int? targetId = _activeId;

      // If no ID provided, fetch latest procurement from list
      if (targetId == null) {
        final list = await widget.service.getProcurements();
        if (list.isNotEmpty) {
          targetId = list.first.id;
          _activeId = targetId;
        }
      }

      if (targetId != null) {
        final status = await widget.service.getProcurementStatus(targetId);
        ProcurementItem? item;
        try {
          item = await widget.service.getProcurementById(targetId);
        } catch (_) {}

        if (mounted) {
          setState(() {
            _statusTracking = status;
            _procurementItem = item;
            _loading = false;
          });
        }
      } else {
        // Fallback demo/initial mock data so Floor Worker sees live UI even prior to backend records
        if (mounted) {
          setState(() {
            _statusTracking = const ProcurementStatusTracking(
              procurementId: 101,
              materialName: 'Food Grade BOPP Film',
              requiredSpecification: 'Grade A 50 Micron',
              netDeficit: 800.0,
              procurementStatus: 'WaitingForApproval',
              workflowId: 'WF-PROC-101',
              purchaseOrderId: 42,
              purchaseOrderNumber: 'PO-2026-0042',
              purchaseOrderStatus: 'PendingApproval',
              paymentStatus: 'Pending',
              supplierNotificationStatus: 'Queued',
              supplierName: 'Apex Packaging Materials Ltd',
              supplierStatus: 'APPROVED',
              recommendedQuantity: 1000.0,
              unitPrice: 3.50,
              totalCost: 3500.0,
              qualityEvidence: 'ISO 9001:2015 & ASTM F1249 Certified',
              leadTimeDays: 5,
              availability: 'In Stock',
              requiresSupplierVerification: false,
              requiresHumanApproval: true,
              lastUpdated: null,
            );
            _loading = false;
          });
        }
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
    const amberAccent = Color(0xFFFFB74D);
    const emeraldAccent = Color(0xFF10B981);
    const roseAccent = Color(0xFFEF4444);

    return Scaffold(
      backgroundColor: navyBg,
      appBar: AppBar(
        backgroundColor: navyBg,
        elevation: 0,
        title: Text(
          _activeId != null ? 'Procurement #$_activeId' : 'Procurement Tracker',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            onPressed: _fetchDetails,
            tooltip: 'Refresh Status',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? StateMessage(
                  message: _error!,
                  icon: Icons.cloud_off,
                  action: _fetchDetails,
                )
              : _statusTracking == null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.assignment_outlined, size: 56, color: Colors.white24),
                            const SizedBox(height: 16),
                            const Text(
                              'No Active Procurement Found',
                              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Submit a Low Stock Alert from the Factory Assistant to initiate AI procurement research.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white54, fontSize: 13),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              onPressed: _fetchDetails,
                              style: ElevatedButton.styleFrom(backgroundColor: cyanAccent, foregroundColor: Colors.black),
                              icon: const Icon(Icons.refresh),
                              label: const Text('Check Again'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchDetails,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── Top Header / Material Overview Card ──
                            _buildHeaderCard(cardBg, cyanAccent, emeraldAccent),
                            const SizedBox(height: 16),

                            // ── Safety Gate Banner (Approval Pending) ──
                            if (_statusTracking!.isApprovalPending) ...[
                              _buildSafetyGateBanner(cardBg, amberAccent),
                              const SizedBox(height: 16),
                            ],

                            // ── 11-Stage Pipeline Stepper ──
                            _buildPipelineStepper(cardBg, cyanAccent, emeraldAccent),
                            const SizedBox(height: 16),

                            // ── AI Recommendation Summary ──
                            if (_statusTracking!.supplierName != null && _statusTracking!.supplierName!.isNotEmpty) ...[
                              _buildRecommendationSummaryCard(cardBg, cyanAccent, emeraldAccent, amberAccent, roseAccent),
                              const SizedBox(height: 16),
                            ],

                            // ── Approved Purchase Telemetry (Post-Approval) ──
                            if (_isApprovedOrLater) ...[
                              _buildApprovedPurchaseCard(cardBg, emeraldAccent, cyanAccent),
                              const SizedBox(height: 16),
                            ],

                            // ── Incoming Supply Tracking (Delivery Phase) ──
                            if (_isDeliveryPhase) ...[
                              _buildIncomingSupplyCard(cardBg, cyanAccent, emeraldAccent),
                              const SizedBox(height: 16),
                            ],
                          ],
                        ),
                      ),
                    ),
    );
  }

  bool get _isApprovedOrLater {
    final step = _statusTracking!.pipelineStep;
    return step.index >= ProcurementPipelineStep.approved.index;
  }

  bool get _isDeliveryPhase {
    final step = _statusTracking!.pipelineStep;
    return step.index >= ProcurementPipelineStep.incomingSupply.index;
  }

  // ── Header Card ────────────────────────────────────────────────────────────
  Widget _buildHeaderCard(Color cardBg, Color cyanAccent, Color emeraldAccent) {
    final t = _statusTracking!;
    final step = t.pipelineStep;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  t.materialName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: emeraldAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: emeraldAccent.withOpacity(0.3)),
                ),
                child: Text(
                  step.title,
                  style: TextStyle(
                    color: emeraldAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          if (t.requiredSpecification.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Spec: ${t.requiredSpecification}',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
          const SizedBox(height: 14),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              _buildMetricChip(
                label: 'NET DEFICIT',
                value: '${t.netDeficit.toStringAsFixed(0)} units',
                color: cyanAccent,
              ),
              const SizedBox(width: 12),
              _buildMetricChip(
                label: 'WORKFLOW ID',
                value: t.workflowId ?? 'WF-AI-INIT',
                color: Colors.white70,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricChip({
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.25),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Safety Gate Banner ─────────────────────────────────────────────────────
  Widget _buildSafetyGateBanner(Color cardBg, Color amberAccent) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E170A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: amberAccent.withOpacity(0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: amberAccent.withOpacity(0.12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: amberAccent.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.shield_outlined, color: amberAccent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SAFETY GATE REMINDER',
                      style: TextStyle(
                        color: amberAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Manager must approve in web dashboard before supplier order or payment occurs.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black38,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.security, size: 14, color: Colors.white54),
                SizedBox(width: 6),
                Text(
                  'Financial Safety Gate • Mobile Read-Only View',
                  style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 11-Stage Pipeline Stepper ──────────────────────────────────────────────
  Widget _buildPipelineStepper(Color cardBg, Color cyanAccent, Color emeraldAccent) {
    final steps = ProcurementPipelineStep.values;
    final currentIdx = _statusTracking!.pipelineStep.index;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Procurement Status Pipeline',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: cyanAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: cyanAccent.withOpacity(0.3)),
                ),
                child: Text(
                  'Stage ${currentIdx + 1} of ${steps.length}',
                  style: TextStyle(
                    color: cyanAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: steps.length,
            itemBuilder: (context, index) {
              final step = steps[index];
              final isCompleted = index < currentIdx;
              final isCurrent = index == currentIdx;
              final isLast = index == steps.length - 1;

              Color stepColor;
              IconData stepIcon;
              if (isCompleted) {
                stepColor = emeraldAccent;
                stepIcon = Icons.check_circle_rounded;
              } else if (isCurrent) {
                stepColor = cyanAccent;
                stepIcon = Icons.radio_button_checked_rounded;
              } else {
                stepColor = Colors.white24;
                stepIcon = Icons.radio_button_unchecked_rounded;
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Icon(stepIcon, size: 20, color: stepColor),
                      if (!isLast)
                        Container(
                          width: 2,
                          height: 28,
                          color: isCompleted
                              ? emeraldAccent.withOpacity(0.6)
                              : Colors.white12,
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                step.title,
                                style: TextStyle(
                                  color: isCurrent
                                      ? cyanAccent
                                      : isCompleted
                                          ? Colors.white
                                          : Colors.white54,
                                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              if (isCurrent) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: cyanAccent.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'CURRENT',
                                    style: TextStyle(
                                      color: cyanAccent,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            step.description,
                            style: TextStyle(
                              color: isCurrent ? Colors.white70 : Colors.white38,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ── AI Recommendation Summary Card ─────────────────────────────────────────
  Widget _buildRecommendationSummaryCard(
    Color cardBg,
    Color cyanAccent,
    Color emeraldAccent,
    Color amberAccent,
    Color roseAccent,
  ) {
    final t = _statusTracking!;
    final supplierStatus = (t.supplierStatus ?? 'UNVERIFIED').toUpperCase();
    final isApprovedSupplier = supplierStatus == 'APPROVED';
    final supplierColor = isApprovedSupplier ? emeraldAccent : amberAccent;

    final qualityStatus = t.qualityStatus;
    final qualityColor = qualityStatus == 'VERIFIED'
        ? emeraldAccent
        : qualityStatus == 'NOT VERIFIED'
            ? roseAccent
            : Colors.white54;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cyanAccent.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: cyanAccent.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.auto_awesome, color: cyanAccent, size: 18),
              ),
              const SizedBox(width: 10),
              const Text(
                'AI Procurement Recommendation',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 14),

          // Concise AI Recommendation Summary
          _buildDetailRow('Material', t.materialName),
          _buildDetailRow('Recommended Supplier', t.supplierName ?? 'Pending Evaluation'),
          _buildDetailRow(
            'Recommended Quantity',
            '${t.recommendedQuantity?.toStringAsFixed(0) ?? t.netDeficit.toStringAsFixed(0)} units',
          ),
          _buildDetailRow(
            'Estimated Total',
            t.totalCost != null ? '\$${t.totalCost!.toStringAsFixed(2)}' : 'TBD',
            valueColor: cyanAccent,
            isBold: true,
          ),
          _buildDetailRow(
            'Validation',
            t.requiresSupplierVerification ? 'In Verification' : 'Passed',
            valueColor: t.requiresSupplierVerification ? amberAccent : emeraldAccent,
            isBold: true,
          ),
          _buildDetailRow(
            'Manager Approval',
            _statusTracking!.isApprovalPending ? 'Pending' : 'Approved',
            valueColor: _statusTracking!.isApprovalPending ? amberAccent : emeraldAccent,
            isBold: true,
          ),

          const SizedBox(height: 12),
          Row(
            children: [
              // Supplier Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: supplierColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: supplierColor.withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isApprovedSupplier ? Icons.verified : Icons.warning_amber_rounded,
                      size: 13,
                      color: supplierColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Supplier: $supplierStatus',
                      style: TextStyle(
                        color: supplierColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Quality Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: qualityColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: qualityColor.withOpacity(0.4)),
                ),
                child: Text(
                  'Quality: $qualityStatus',
                  style: TextStyle(
                    color: qualityColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          if (t.qualityEvidence != null && t.qualityEvidence!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Evidence: ${t.qualityEvidence}',
              style: const TextStyle(color: Colors.white54, fontSize: 11, fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }

  // ── Approved Purchase Telemetry ────────────────────────────────────────────
  Widget _buildApprovedPurchaseCard(Color cardBg, Color emeraldAccent, Color cyanAccent) {
    final t = _statusTracking!;
    final payStatus = (t.paymentStatus ?? 'Paid').toUpperCase();
    final notifStatus = (t.supplierNotificationStatus ?? 'Sent').toUpperCase();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: emeraldAccent.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: emeraldAccent, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Approved Purchase Order Telemetry',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 12),
          _buildDetailRow('PO Number', t.purchaseOrderNumber ?? 'PO-${t.purchaseOrderId ?? 101}'),
          _buildDetailRow('PO Status', 'APPROVED', valueColor: emeraldAccent, isBold: true),
          _buildDetailRow('Payment Status', 'Stripe: $payStatus', valueColor: emeraldAccent),
          _buildDetailRow('Supplier Notification', 'SendGrid PDF: $notifStatus', valueColor: cyanAccent),
          _buildDetailRow(
            'Expected Delivery',
            DateTime.now().add(Duration(days: t.leadTimeDays ?? 5)).toString().substring(0, 10),
          ),
        ],
      ),
    );
  }

  // ── Incoming Supply Tracking ───────────────────────────────────────────────
  Widget _buildIncomingSupplyCard(Color cardBg, Color cyanAccent, Color emeraldAccent) {
    final t = _statusTracking!;
    final deliveryStatus = SupplyDeliveryStatus.fromString(t.purchaseOrderStatus);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cyanAccent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.local_shipping_outlined, color: cyanAccent, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Incoming Supply Tracking',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: deliveryStatus.color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: deliveryStatus.color.withOpacity(0.4)),
                ),
                child: Text(
                  deliveryStatus.label,
                  style: TextStyle(
                    color: deliveryStatus.color,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 12),
          _buildDetailRow('PO Number', t.purchaseOrderNumber ?? 'PO-${t.purchaseOrderId ?? 101}'),
          _buildDetailRow('Supplier', t.supplierName ?? 'Apex Packaging'),
          _buildDetailRow('Material', t.materialName),
          _buildDetailRow('Quantity', '${t.recommendedQuantity?.toStringAsFixed(0) ?? '1000'} units'),
          _buildDetailRow(
            'Expected Delivery',
            DateTime.now().add(Duration(days: t.leadTimeDays ?? 5)).toString().substring(0, 10),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    Color? valueColor,
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: valueColor ?? Colors.white,
                fontSize: 13,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

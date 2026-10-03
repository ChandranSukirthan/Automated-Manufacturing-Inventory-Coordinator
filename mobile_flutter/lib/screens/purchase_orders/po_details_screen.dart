import 'package:flutter/material.dart';
import '../../models/purchase_order_models.dart';
import 'receive_goods_screen.dart';
import '../../services/purchase_order_service.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/po_status_stepper.dart';

class PODetailsScreen extends StatefulWidget {
  const PODetailsScreen({
    required this.service,
    required this.poId,
    super.key,
  });

  final PurchaseOrderService service;
  final int poId;

  @override
  State<PODetailsScreen> createState() => _PODetailsScreenState();
}

class _PODetailsScreenState extends State<PODetailsScreen> {
  bool _loading = true;
  String? _error;
  PurchaseOrderDetail? _po;

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await widget.service.getPurchaseOrderById(widget.poId);
      if (mounted) {
        setState(() {
          _po = data;
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
      appBar: AppBar(
        backgroundColor: navyBg,
        elevation: 0,
        title: Text(
          _po?.poNumber ?? 'PO Details',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.inventory_2), tooltip: 'Delivery receipts', onPressed: () async {
            await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => ReceiveGoodsScreen(purchaseOrderId: widget.poId)));
            if (mounted) await _fetchDetails();
          }),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            onPressed: _fetchDetails,
            tooltip: 'Refresh',
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
              : _po == null
                  ? const Center(child: Text('Order not found', style: TextStyle(color: Colors.white54)))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_po!.bankSlipStatus == 'SUBMITTED') ElevatedButton(onPressed: () async {
                            try { await widget.service.verifyBankSlip(widget.poId); await _fetchDetails(); }
                            catch (error) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString()))); }
                          }, child: const Text('Confirm bank payment against bank records')),
                          // Manager Interactive Action Panel or Telemetry Notice
                          _buildManagerActionBar(context, _po!),

                          const SizedBox(height: 16),

                          // Header Card: PO Number, Status, Supplier, Total
                          Container(
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
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _po!.poNumber,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 20,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Created ${_po!.createdAt.year}-${_po!.createdAt.month.toString().padLeft(2, '0')}-${_po!.createdAt.day.toString().padLeft(2, '0')}',
                                          style: const TextStyle(color: Colors.white38, fontSize: 11),
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(_po!.status).withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: _getStatusColor(_po!.status).withOpacity(0.3)),
                                      ),
                                      child: Text(
                                        _po!.status,
                                        style: TextStyle(
                                          color: _getStatusColor(_po!.status),
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                const Divider(color: Colors.white10, height: 1),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    _buildMetaColumn('Supplier', _po!.supplierName, Icons.business_outlined),
                                    _buildMetaColumn('Total Cost', '\$${_po!.totalCost.toStringAsFixed(2)}', Icons.payments_outlined),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // 10-Step Order Lifecycle Stepper
                          POStatusStepper(currentStep: _po!.currentLifecycleStep),

                          const SizedBox(height: 16),

                          // Status Breakdown Cards: Approval, Payment, Notification
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withOpacity(0.08)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Status Telemetry',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _buildStatusRow(
                                  title: 'Approval Status',
                                  value: _po!.approvalStatusDisplay,
                                  icon: Icons.check_circle_outline_rounded,
                                  iconColor: const Color(0xFF10B981),
                                ),
                                const Divider(color: Colors.white10, height: 16),
                                _buildStatusRow(
                                  title: 'Payment Status',
                                  value: _po!.paymentStatusDisplay,
                                  icon: Icons.credit_card_outlined,
                                  iconColor: const Color(0xFF8B5CF6),
                                ),
                                const Divider(color: Colors.white10, height: 16),
                                _buildStatusRow(
                                  title: 'Supplier Notification',
                                  value: _po!.supplierNotificationDisplay,
                                  icon: Icons.send_outlined,
                                  iconColor: cyanAccent,
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Payment & Settlement Receipt Card (when paid/sent or when bank slip/Stripe info exists)
                          if (_po!.bankSlipUrl != null ||
                              _po!.bankReferenceNumber != null ||
                              _po!.stripePaymentIntentId != null ||
                              _po!.status.toLowerCase() == 'sent' ||
                              _po!.status.toLowerCase() == 'payment') ...[
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFF10B981).withOpacity(0.35)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Row(
                                        children: [
                                          Icon(Icons.verified_outlined, color: Color(0xFF10B981), size: 18),
                                          SizedBox(width: 8),
                                          Text(
                                            'Payment & Settlement Receipt',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF10B981).withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          _po!.bankSlipStatus ?? 'Settled & Verified',
                                          style: const TextStyle(
                                            color: Color(0xFF10B981),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  _buildReceiptRow(
                                    label: 'Payment Gateway',
                                    value: _po!.bankReferenceNumber != null
                                        ? 'Bank Transfer (Slip Verified)'
                                        : 'Stripe Online Checkout',
                                    icon: _po!.bankReferenceNumber != null
                                        ? Icons.account_balance
                                        : Icons.credit_card,
                                  ),
                                  const Divider(color: Colors.white10, height: 16),
                                  _buildReceiptRow(
                                    label: 'Transaction Reference',
                                    value: _po!.bankReferenceNumber ?? _po!.stripePaymentIntentId ?? 'SETTLED-${_po!.id}',
                                    icon: Icons.tag,
                                  ),
                                  if (_po!.bankSlipUrl != null) ...[
                                    const Divider(color: Colors.white10, height: 16),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'Verified Bank Voucher',
                                          style: TextStyle(color: Colors.white54, fontSize: 11),
                                        ),
                                        InkWell(
                                          onTap: () => _showVoucherDialog(_po!),
                                          child: const Row(
                                            children: [
                                              Icon(Icons.receipt_long, color: cyanAccent, size: 15),
                                              SizedBox(width: 4),
                                              Text(
                                                'View Slip Voucher',
                                                style: TextStyle(
                                                  color: cyanAccent,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Order Lines (Material, Quantity, Unit Price, Total)
                          Container(
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
                                      'Order Lines',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    Text(
                                      '${_po!.orderLines.length} items',
                                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                if (_po!.orderLines.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8.0),
                                    child: Text(
                                      'No item lines attached.',
                                      style: TextStyle(color: Colors.white38),
                                    ),
                                  )
                                else
                                  ListView.separated(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: _po!.orderLines.length,
                                    separatorBuilder: (_, _) => const Divider(color: Colors.white10, height: 16),
                                    itemBuilder: (context, idx) {
                                      final line = _po!.orderLines[idx];
                                      return Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            width: 36,
                                            height: 36,
                                            decoration: BoxDecoration(
                                              color: cyanAccent.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Icon(Icons.inventory_2_outlined, color: cyanAccent, size: 18),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  line.rawMaterialName,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  'SKU: ${line.rawMaterialSku}',
                                                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  '${line.quantity} units @ \$${line.unitPrice.toStringAsFixed(2)} / unit',
                                                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Text(
                                            '\$${line.totalPrice.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildManagerActionBar(BuildContext context, PurchaseOrderDetail po) {
    final status = po.status.toLowerCase();

    if (status == 'pendingapproval') {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.gavel_rounded, color: Color(0xFFF59E0B), size: 20),
                SizedBox(width: 8),
                Text(
                  'Supply Chain Manager Approval Action',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Review order specifications and authorize release, request revision, or reject.',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _handleApprove(po.id),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.check_circle_outline, size: 16),
                    label: const Text('Approve', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showRevisionDialog(po.id),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF59E0B),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.edit_note_rounded, size: 16),
                    label: const Text('Revise', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showRejectDialog(po.id),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.cancel_outlined, size: 16),
                    label: const Text('Reject', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    } else if (status == 'approved' || status == 'payment') {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E38),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF8B5CF6), size: 20),
                SizedBox(width: 8),
                Text(
                  'Payment Gateway & Financial Settlement',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Order is approved! Choose Stripe Credit Card or Bank Transfer Slip to settle invoice and notify supplier.',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _handleStripeCheckout(po.id),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.credit_card, size: 16),
                    label: const Text('Stripe Card', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showBankSlipDialog(po),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.receipt_long_rounded, size: 16),
                    label: const Text('Bank Slip', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    } else if (status == 'draft') {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Draft Purchase Order', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                Text('Submit for manager approval', style: TextStyle(color: Colors.white54, fontSize: 11)),
              ],
            ),
            ElevatedButton.icon(
              onPressed: () => _handleSubmit(po.id),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5CC8F8),
                foregroundColor: Colors.black,
              ),
              icon: const Icon(Icons.send, size: 16),
              label: const Text('Submit', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Future<void> _handleApprove(int poId) async {
    try {
      await widget.service.approvePurchaseOrder(poId, notes: 'Approved by Supply Chain Manager via Mobile');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Purchase Order Approved successfully!'), backgroundColor: Color(0xFF10B981)),
        );
        _fetchDetails();
      }
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Approval failed: $err'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleSubmit(int poId) async {
    try {
      await widget.service.submitPurchaseOrder(poId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Purchase Order Submitted for approval!'), backgroundColor: Color(0xFF5CC8F8)),
        );
        _fetchDetails();
      }
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Submit failed: $err'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showRejectDialog(int poId) async {
    final controller = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F1B2B),
        title: const Text('Reject Purchase Order', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Enter reason for rejection...',
            hintStyle: TextStyle(color: Colors.white38),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text('Reject Order'),
          ),
        ],
      ),
    );

    if (result == true && controller.text.trim().isNotEmpty) {
      try {
        await widget.service.rejectPurchaseOrder(poId, notes: controller.text.trim());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Order Rejected.'), backgroundColor: Color(0xFFEF4444)),
          );
          _fetchDetails();
        }
      } catch (err) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Rejection failed: $err'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _showRevisionDialog(int poId) async {
    final controller = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F1B2B),
        title: const Text('Request Revision', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Enter required revisions...',
            hintStyle: TextStyle(color: Colors.white38),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF59E0B), foregroundColor: Colors.black),
            child: const Text('Send Revision'),
          ),
        ],
      ),
    );

    if (result == true && controller.text.trim().isNotEmpty) {
      try {
        await widget.service.revisePurchaseOrder(poId, notes: controller.text.trim());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Revision requested.'), backgroundColor: Color(0xFFF59E0B)),
          );
          _fetchDetails();
        }
      } catch (err) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Revision request failed: $err'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _handleStripeCheckout(int poId) async {
    try {
      final checkoutUrl = await widget.service.createCheckoutSession(poId);
      if (!mounted) return;

      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF0F1B2B),
          title: const Row(
            children: [
              Icon(Icons.payment, color: Color(0xFF8B5CF6)),
              SizedBox(width: 8),
              Text('Stripe Payment Checkout', style: TextStyle(color: Colors.white, fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Stripe Checkout Session Created.', style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 10),
              if (checkoutUrl != null)
                SelectableText(
                  checkoutUrl,
                  style: const TextStyle(color: Color(0xFF5CC8F8), fontSize: 12),
                ),
              const SizedBox(height: 14),
              const Text('Complete secure payment via Stripe hosted checkout.', style: TextStyle(color: Colors.white54, fontSize: 11)),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1)),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Stripe Checkout error: $err'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleDirectPayment(int poId) async {
    try {
      await widget.service.processPayment(poId, forceDispatch: false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment request processed. Check payment and dispatch status.'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        _fetchDetails();
      }
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment processing failed: $err'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showBankSlipDialog(PurchaseOrderDetail po) async {
    final bankNameController = TextEditingController(text: 'Commercial Bank of Ceylon');
    final refController = TextEditingController(text: 'TXN-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}');
    final notesController = TextEditingController(text: 'Bank Wire Transfer completed via corporate online portal.');
    bool submitting = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF0F1B2B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.account_balance, color: Color(0xFF10B981), size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Bank Transfer Slip Gateway',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Supplier:', style: TextStyle(color: Colors.white54, fontSize: 11)),
                              Text(po.supplierName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Payable Total:', style: TextStyle(color: Colors.white54, fontSize: 11)),
                              Text('${po.currency} \$${po.totalCost.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text('Bank / Institution Name', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: bankNameController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        hintText: 'e.g. Chase Bank, HSBC, Commercial Bank',
                        hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('Transaction Reference Number *', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: refController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        hintText: 'e.g. TXN-9988231',
                        hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('Verification / Slip Notes', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: notesController,
                      maxLines: 2,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        hintText: 'Notes regarding wire transfer or branch deposit...',
                        hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: submitting ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton.icon(
                  onPressed: submitting
                      ? null
                      : () async {
                          final ref = refController.text.trim();
                          if (ref.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter a Transaction Reference Number.'), backgroundColor: Colors.orange),
                            );
                            return;
                          }
                          setDialogState(() => submitting = true);
                          try {
                            await widget.service.uploadBankSlip(
                              po.id,
                              referenceNumber: ref,
                              bankName: bankNameController.text.trim(),
                              notes: notesController.text.trim(),
                            );
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                            }
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Bank Slip verified & Order Dispatched to Supplier!'),
                                  backgroundColor: Color(0xFF10B981),
                                ),
                              );
                              _fetchDetails();
                            }
                          } catch (err) {
                            if (ctx.mounted) {
                              setDialogState(() => submitting = false);
                            }
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Bank slip submission failed: $err'), backgroundColor: Colors.red),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                  ),
                  icon: submitting
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_circle_outline, size: 16),
                  label: Text(submitting ? 'Verifying...' : 'Verify & Settle'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildReceiptRow({required String label, required String value, required IconData icon}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: Colors.white38),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
          ],
        ),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
        ),
      ],
    );
  }

  void _showVoucherDialog(PurchaseOrderDetail po) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F1B2B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.receipt_long, color: Color(0xFF10B981)),
            SizedBox(width: 8),
            Text('Bank Slip Voucher', style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('PO Number: ${po.poNumber}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 4),
            Text('Reference: ${po.bankReferenceNumber ?? 'N/A'}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 4),
            Text('Total Amount: ${po.currency} \$${po.totalCost.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 12),
            const Text('Slip Voucher URL on server:', style: TextStyle(color: Colors.white38, fontSize: 11)),
            const SizedBox(height: 4),
            SelectableText(
              'http://localhost:5070${po.bankSlipUrl}',
              style: const TextStyle(color: Color(0xFF5CC8F8), fontSize: 11),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaColumn(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: Colors.white38),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusRow({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return const Color(0xFF10B981);
      case 'sent':
        return const Color(0xFF06B6D4);
      case 'pendingapproval':
        return const Color(0xFFF59E0B);
      case 'payment':
        return const Color(0xFF8B5CF6);
      case 'rejected':
        return const Color(0xFFEF4444);
      case 'draft':
      default:
        return const Color(0xFF64748B);
    }
  }
}


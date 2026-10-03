import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/floor_worker_operations_service.dart';
import 'purchase_orders/receive_goods_screen.dart';
import 'production_status_screen.dart' show OperationsEmptyState;

class SupplyDeliveryTrackingScreen extends StatefulWidget {
  const SupplyDeliveryTrackingScreen({this.service, super.key});

  final FloorWorkerOperationsService? service;

  @override
  State<SupplyDeliveryTrackingScreen> createState() =>
      _SupplyDeliveryTrackingScreenState();
}

class _SupplyDeliveryTrackingScreenState
    extends State<SupplyDeliveryTrackingScreen> {
  late final FloorWorkerOperationsService _service;
  bool _loading = true;
  String? _error;
  List<IncomingDelivery> _deliveries = const [];

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? FloorWorkerOperationsService();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final deliveries = await _service.fetchIncomingDeliveries();
      if (mounted) {
        setState(() {
          _deliveries = deliveries;
          _loading = false;
        });
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Incoming deliveries could not be loaded.';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Supply Deliveries'),
      actions: [
        IconButton(
          onPressed: _load,
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
        ),
      ],
    ),
    body: RefreshIndicator(
      onRefresh: _load,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _errorState()
          : _deliveries.isEmpty
          ? const OperationsEmptyState(
              message: 'No deliveries are currently in transit.',
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: _deliveries.length,
              itemBuilder: (_, index) => _deliveryCard(_deliveries[index]),
            ),
    ),
  );

  Widget _errorState() => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.all(24),
    children: [
      const Icon(Icons.cloud_off_outlined, size: 42, color: Colors.redAccent),
      const SizedBox(height: 12),
      Text(_error!, textAlign: TextAlign.center),
      const SizedBox(height: 12),
      Center(
        child: FilledButton(onPressed: _load, child: const Text('Retry')),
      ),
    ],
  );

  Widget _deliveryCard(IncomingDelivery delivery) => Card(
    child: ListTile(
      onTap: () async { await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => ReceiveGoodsScreen(purchaseOrderId: delivery.id))); if (mounted) await _load(); },
      leading: const Icon(
        Icons.local_shipping_outlined,
        color: Color(0xFFFFD700),
      ),
      title: Text(delivery.poNumber),
      subtitle: Text(
        '${delivery.supplierName}\nDispatched: ${_formatDeliveryTime(delivery.updatedAt)}',
      ),
      isThreeLine: true,
      trailing: Chip(label: Text(delivery.status)),
    ),
  );
}

String _formatDeliveryTime(DateTime? value) => value == null
    ? 'Not available'
    : value.toLocal().toString().split('.').first;

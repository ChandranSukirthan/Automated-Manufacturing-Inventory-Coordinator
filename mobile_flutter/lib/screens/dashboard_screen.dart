import 'package:flutter/material.dart';

import '../models/quality_models.dart';
import '../services/api_client.dart';
import '../services/quality_service.dart';
import '../widgets/app_widgets.dart';
import 'batch_scan_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({required this.service, super.key});

  final QualityService service;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  QualitySummary? _summary;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final summary = await widget.service.getSummary();
      final defects = await widget.service.getDefects();
      final quarantines = await widget.service.getQuarantines();
      final active = quarantines.where((record) => record.status == 'Active');
      final released = quarantines.where((record) => record.status == 'Released');
      final liveSummary = summary.copyWith(
        totalDefects: defects.length,
        highSeverityDefects: defects
            .where((defect) => defect.severity == 'HIGH' || defect.severity == 'CRITICAL')
            .length,
        openDefects: defects.where((defect) => defect.status == 'Open').length,
        quarantinedBatches: active.map((record) => record.batchId).toSet().length,
        affectedInventory: active.map((record) => record.inventoryRollId).toSet().length,
        releasedInventory: released.map((record) => record.inventoryRollId).toSet().length,
      );
      if (mounted) {
        setState(() => _summary = liveSummary);
      }
    } on ApiException catch (exception) {
      if (mounted) {
        setState(() => _error = exception.message);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null && _summary == null) {
      return StateMessage(
        message: _error!,
        icon: Icons.cloud_off,
        action: _load,
      );
    }
    if (_summary == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final summary = _summary!;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Quality overview',
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'A live view of the inspection floor.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => Navigator.push<void>(
              context,
              MaterialPageRoute(
                builder: (_) => BatchScanScreen(service: widget.service),
              ),
            ),
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scan batch QR'),
          ),
          const SizedBox(height: 20),
          GridView.count(
            crossAxisCount: MediaQuery.sizeOf(context).width > 600 ? 4 : 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.1,
            children: [
              MetricCard(
                label: 'Total defects',
                value: summary.totalDefects,
                color: Colors.indigo,
              ),
              MetricCard(
                label: 'High severity',
                value: summary.highSeverityDefects,
                color: Colors.deepOrange,
              ),
              MetricCard(
                label: 'Open defects',
                value: summary.openDefects,
                color: Colors.amber.shade800,
              ),
              MetricCard(
                label: 'Quarantined batches',
                value: summary.quarantinedBatches,
                color: Colors.red,
              ),
              MetricCard(
                label: 'Affected inventory',
                value: summary.affectedInventory,
                color: Colors.orange,
              ),
              MetricCard(
                label: 'Released inventory',
                value: summary.releasedInventory,
                color: Colors.teal,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

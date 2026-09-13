import 'package:flutter/material.dart';

import '../models/quality_models.dart';
import '../services/api_client.dart';
import '../services/quality_service.dart';
import '../widgets/app_widgets.dart';
import 'batch_scan_screen.dart';
import 'defect_form_screen.dart';
import 'defects_screen.dart';
import 'quarantine_history_screen.dart';
import 'quarantine_screen.dart';

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
          const SizedBox(height: 14),
          const Align(
            alignment: Alignment.centerLeft,
            child: Chip(
              avatar: Icon(Icons.circle, size: 10, color: Colors.green),
              label: Text('System online'),
            ),
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
          const SizedBox(height: 24),
          _OperationalPanel(
            title: 'Defect Risk',
            icon: Icons.warning_amber_rounded,
            value: summary.highSeverityDefects > 0
                ? 'Attention required'
                : 'Stable',
            detail: '${summary.highSeverityDefects} high priority',
            color: summary.highSeverityDefects > 0
                ? Colors.deepOrange
                : Colors.teal,
          ),
          const SizedBox(height: 12),
          _OperationalPanel(
            title: 'Quality Flow',
            icon: Icons.sync_alt,
            value: summary.quarantinedBatches == 0
                ? 'No active holds'
                : '${summary.quarantinedBatches} batches on hold',
            detail: '${summary.affectedInventory} inventory affected',
            color: summary.quarantinedBatches == 0
                ? Colors.teal
                : Colors.amber.shade800,
          ),
          const SizedBox(height: 24),
          Text(
            'Quick actions',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          _QuickAction(
            icon: Icons.fact_check_outlined,
            label: 'Review defect reports',
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute(
                builder: (_) => DefectsScreen(service: widget.service),
              ),
            ),
          ),
          _QuickAction(
            icon: Icons.inventory_2_outlined,
            label: 'Open quarantine queue',
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute(
                builder: (_) => QuarantineScreen(service: widget.service),
              ),
            ),
          ),
          _QuickAction(
            icon: Icons.add_task,
            label: 'Log a new defect',
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute(
                builder: (_) => DefectFormScreen(service: widget.service),
              ),
            ),
          ),
          _QuickAction(
            icon: Icons.history,
            label: 'View quarantine history',
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute(
                builder: (_) => QuarantineHistoryScreen(service: widget.service),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OperationalPanel extends StatelessWidget {
  const _OperationalPanel({
    required this.title,
    required this.icon,
    required this.value,
    required this.detail,
    required this.color,
  });

  final String title;
  final IconData icon;
  final String value;
  final String detail;
  final Color color;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(detail, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      leading: Icon(icon),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    ),
  );
}

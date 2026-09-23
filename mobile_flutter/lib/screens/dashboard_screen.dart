import 'package:flutter/material.dart';

import '../app_state.dart';
import '../app_colors.dart';
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
  const DashboardScreen({
    required this.service,
    required this.appState,
    super.key,
  });

  final QualityService service;
  final AppState appState;

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
      final released = quarantines.where(
        (record) => record.status == 'Released',
      );
      final liveSummary = summary.copyWith(
        totalDefects: defects.length,
        highSeverityDefects: defects
            .where(
              (defect) =>
                  defect.severity == 'HIGH' || defect.severity == 'Critical',
            )
            .length,
        openDefects: defects.where((defect) => defect.status == 'Open').length,
        quarantinedBatches: active
            .map((record) => record.batchId)
            .toSet()
            .length,
        affectedInventory: active
            .map((record) => record.inventoryRollId)
            .toSet()
            .length,
        releasedInventory: released
            .map((record) => record.inventoryRollId)
            .toSet()
            .length,
      );
      if (mounted) {
        setState(() => _summary = liveSummary);
      }
    } on ApiException catch (exception) {
      if (mounted) {
        setState(() => _error = exception.message);
      }
    } catch (exception) {
      if (mounted) {
        setState(
          () => _error = 'Unable to load the quality dashboard: $exception',
        );
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
                builder: (_) => BatchScanScreen(
                  service: widget.service,
                  appState: widget.appState,
                ),
              ),
            ),
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scan batch QR'),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DefectsScreen(service: widget.service),
                  ),
                ),
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('View Defects'),
              ),
              OutlinedButton.icon(
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => QuarantineScreen(service: widget.service),
                  ),
                ),
                icon: const Icon(Icons.shield_outlined),
                label: const Text('Manage Quarantine'),
              ),
              OutlinedButton.icon(
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DefectFormScreen(service: widget.service),
                  ),
                ),
                icon: const Icon(Icons.add_alert_outlined),
                label: const Text('New Defect'),
              ),
              OutlinedButton.icon(
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        QuarantineHistoryScreen(service: widget.service),
                  ),
                ),
                icon: const Icon(Icons.history),
                label: const Text('History'),
              ),
            ],
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
                color: AppColors.primary,
              ),
              MetricCard(
                label: 'High severity',
                value: summary.highSeverityDefects,
                color: AppColors.danger,
              ),
              MetricCard(
                label: 'Open defects',
                value: summary.openDefects,
                color: AppColors.violet,
              ),
              MetricCard(
                label: 'Quarantined batches',
                value: summary.quarantinedBatches,
                color: AppColors.warning,
              ),
              MetricCard(
                label: 'Affected inventory',
                value: summary.affectedInventory,
                color: AppColors.orange,
              ),
              MetricCard(
                label: 'Released inventory',
                value: summary.releasedInventory,
                color: AppColors.info,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

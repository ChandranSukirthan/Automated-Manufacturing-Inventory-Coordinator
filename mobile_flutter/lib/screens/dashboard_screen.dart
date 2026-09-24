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
    final user = widget.appState.session?.user;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'QUALITY CONTROL',
                      style: TextStyle(
                        color: AppColors.primaryLight,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Quality overview',
                      style: TextStyle(
                        color: AppColors.strongText,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'A live view of the inspection floor.',
                      style: TextStyle(color: AppColors.mutedText, fontSize: 14),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              CircleAvatar(
                radius: 23,
                backgroundColor: AppColors.primary.withValues(alpha: 0.18),
                child: Icon(
                  Icons.person_outline_rounded,
                  color: AppColors.primaryLight,
                  size: 24,
                  semanticLabel: user?.fullName ?? 'Profile',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 54,
            child: FilledButton.icon(
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => BatchScanScreen(
                    service: widget.service,
                    appState: widget.appState,
                  ),
                ),
              ),
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: const Text(
                'Scan batch QR',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.strongText,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'Quick actions',
            style: TextStyle(
              color: AppColors.strongText,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 2.35,
            children: [
              _QuickAction(
                icon: Icons.fact_check_outlined,
                label: 'View Defects',
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DefectsScreen(service: widget.service),
                  ),
                ),
              ),
              _QuickAction(
                icon: Icons.shield_outlined,
                label: 'Manage Quarantine',
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => QuarantineScreen(service: widget.service),
                  ),
                ),
              ),
              _QuickAction(
                icon: Icons.add_alert_outlined,
                label: 'New Defect',
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DefectFormScreen(service: widget.service),
                  ),
                ),
              ),
              _QuickAction(
                icon: Icons.history_rounded,
                label: 'History',
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        QuarantineHistoryScreen(service: widget.service),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Inspection metrics',
            style: TextStyle(
              color: AppColors.strongText,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.92,
            children: [
              DashboardMetricCard(
                label: 'Total defects',
                value: summary.totalDefects,
                icon: Icons.analytics_outlined,
                accentColor: AppColors.primary,
                gradientColors: const [Color(0xFF161B2E), Color(0xFF0F1523)],
              ),
              DashboardMetricCard(
                label: 'High severity',
                value: summary.highSeverityDefects,
                icon: Icons.error_outline_rounded,
                accentColor: AppColors.error,
                gradientColors: const [Color(0xFF221115), Color(0xFF130A0D)],
              ),
              DashboardMetricCard(
                label: 'Open defects',
                value: summary.openDefects,
                icon: Icons.pending_actions_rounded,
                accentColor: const Color(0xFF3B82F6),
                gradientColors: const [Color(0xFF151D2A), Color(0xFF0D121B)],
              ),
              DashboardMetricCard(
                label: 'Quarantined batches',
                value: summary.quarantinedBatches,
                icon: Icons.warning_amber_rounded,
                accentColor: AppColors.warning,
                gradientColors: const [Color(0xFF221A11), Color(0xFF130F0A)],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onPressed,
    icon: Icon(icon, size: 19),
    label: Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
    ),
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.secondaryText,
      side: BorderSide(color: AppColors.border.withValues(alpha: 0.8)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(horizontal: 8),
    ),
  );
}

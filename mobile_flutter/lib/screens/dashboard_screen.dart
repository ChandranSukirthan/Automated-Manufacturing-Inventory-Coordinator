import 'package:flutter/material.dart';

import '../app_state.dart';
import '../app_colors.dart';
import '../models/quality_models.dart';
import '../services/quality_service.dart';
import '../widgets/app_widgets.dart';
import 'ai_validation_screen.dart';
import 'batch_scan_screen.dart';
import 'defect_detail_screen.dart';
import 'defect_form_screen.dart';
import 'defects_screen.dart';
import 'quarantine_detail_screen.dart';
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
  List<DefectReport> _defects = [];
  List<QuarantineRecord> _quarantines = [];
  AiValidationData? _aiValidation;
  String? _error;
  bool _loading = true;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _refreshing = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        widget.service.getSummary().catchError(
              (_) => const QualitySummary(
                totalDefects: 0,
                highSeverityDefects: 0,
                activeQuarantines: 0,
                releasedQuarantines: 0,
                openDefects: 0,
                quarantinedBatches: 0,
                affectedInventory: 0,
                releasedInventory: 0,
              ),
            ),
        widget.service.getDefects().catchError((_) => <DefectReport>[]),
        widget.service.getQuarantines().catchError(
              (_) => <QuarantineRecord>[],
            ),
        widget.service.getAiValidation().catchError((_) => null),
      ]);

      if (mounted) {
        setState(() {
          _summary = results[0] as QualitySummary;
          _defects = results[1] as List<DefectReport>;
          _quarantines = results[2] as List<QuarantineRecord>;
          _aiValidation = results[3] as AiValidationData?;
          _loading = false;
          _refreshing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Unable to aggregate quality telemetry.';
          _loading = false;
          _refreshing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _summary == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _summary == null) {
      return StateMessage(
        message: _error!,
        icon: Icons.cloud_off,
        action: _load,
      );
    }

    final defects = _defects;
    final quarantines = _quarantines;
    final summary = _summary!;

    final openDefectsList = defects
        .where(
          (d) => ['open', 'inreview'].contains(d.status.toLowerCase()),
        )
        .toList();
    final criticalDefects = defects
        .where((d) => d.severity.toLowerCase() == 'critical')
        .toList();
    final highDefects = defects
        .where((d) => d.severity.toLowerCase() == 'high')
        .toList();
    final mediumDefects = defects
        .where((d) => d.severity.toLowerCase() == 'medium')
        .toList();
    final lowDefects = defects
        .where((d) => d.severity.toLowerCase() == 'low')
        .toList();

    final activeQuarantines = quarantines
        .where((q) => q.status.toLowerCase() == 'active')
        .toList();
    final releasedQuarantines = quarantines
        .where((q) => q.status.toLowerCase() == 'released')
        .toList();

    final attentionItems = _computeAttentionItems(
      activeQuarantines,
      openDefectsList,
      _aiValidation,
    );
    final recentActivities = _computeRecentActivities(defects, quarantines);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 36),
        children: [
          // 1. Header Banner
          _buildHeaderBanner(),
          const SizedBox(height: 16),

          if (_error != null) ...[
            _buildErrorBanner(_error!),
            const SizedBox(height: 16),
          ],

          // 2. Top Level 4 KPI Cards
          _buildTopKpiCards(
            openCount: openDefectsList.length,
            totalCount: defects.length,
            criticalCount: criticalDefects.length,
            activeQuarantinesCount: activeQuarantines.length,
            releasedQuarantinesCount: releasedQuarantines.length,
            batchesHeldCount: summary.quarantinedBatches,
            restrictedRollsCount: summary.affectedInventory > 0
                ? summary.affectedInventory
                : activeQuarantines.length,
            clearedRollsCount: summary.releasedInventory,
            aiValidation: _aiValidation,
          ),
          const SizedBox(height: 20),

          // Quick Scan QR Button
          SizedBox(
            height: 50,
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
                'Scan Batch QR Code',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 3. Monitoring & Real Data Visuals Grid
          _buildSeverityBreakdownCard(
            total: defects.length,
            critical: criticalDefects.length,
            high: highDefects.length,
            medium: mediumDefects.length,
            low: lowDefects.length,
          ),
          const SizedBox(height: 16),

          _buildQuarantineContainmentCard(
            total: quarantines.length,
            active: activeQuarantines.length,
            released: releasedQuarantines.length,
          ),
          const SizedBox(height: 16),

          _buildDefectPipelineCard(
            total: defects.length,
            open: defects
                .where((d) => d.status.toLowerCase() == 'open')
                .length,
            inReview: defects
                .where((d) => d.status.toLowerCase() == 'inreview')
                .length,
            resolved: defects
                .where((d) => d.status.toLowerCase() == 'resolved')
                .length,
            closed: defects
                .where((d) => d.status.toLowerCase() == 'closed')
                .length,
          ),
          const SizedBox(height: 20),

          // 4. Requires Attention Panel
          _buildRequiresAttentionPanel(attentionItems),
          const SizedBox(height: 20),

          // 5. Recent QA Activity Stream
          _buildRecentActivityStream(recentActivities),
          const SizedBox(height: 20),

          // 6. Navigation Shortcuts
          _buildNavigationShortcuts(),
        ],
      ),
    );
  }

  Widget _buildHeaderBanner() => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF1E1B4B), Color(0xFF0F172A)],
      ),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: AppColors.primary.withValues(alpha: 0.35),
        width: 1.2,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.3),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.4),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.shield_outlined,
                    color: AppColors.primaryLight,
                    size: 13,
                  ),
                  SizedBox(width: 5),
                  Text(
                    'Quality Assurance · Student 3',
                    style: TextStyle(
                      color: AppColors.primaryLight,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                const Text(
                  'Operational',
                  style: TextStyle(
                    color: Color(0xFF34D399),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'Quality Control',
          style: TextStyle(
            color: AppColors.strongText,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Manufacturing quality, safety, defect and quarantine monitoring console. Real-time factory floor telemetry, AI compliance checks, and containment management.',
          style: TextStyle(
            color: AppColors.mutedText,
            fontSize: 12,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DefectFormScreen(service: widget.service),
                  ),
                ).then((_) => _load()),
                icon: const Icon(Icons.add_circle_outline, size: 17),
                label: const Text(
                  'Log Defect',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton.icon(
              onPressed: _refreshing ? null : _load,
              icon: _refreshing
                  ? const SizedBox.square(
                      dimension: 14,
                      child: CircularProgressIndicator(strokeWidth: 1.8),
                    )
                  : const Icon(Icons.refresh_rounded, size: 17),
              label: const Text('Refresh'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.secondaryText,
                side: const BorderSide(color: Color(0xFF2A3958)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _buildErrorBanner(String message) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.error.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.error.withValues(alpha: 0.35)),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.error_outline_rounded,
          color: AppColors.errorText,
          size: 18,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(color: AppColors.errorText, fontSize: 12),
          ),
        ),
      ],
    ),
  );

  Widget _buildTopKpiCards({
    required int openCount,
    required int totalCount,
    required int criticalCount,
    required int activeQuarantinesCount,
    required int releasedQuarantinesCount,
    required int batchesHeldCount,
    required int restrictedRollsCount,
    required int clearedRollsCount,
    required AiValidationData? aiValidation,
  }) {
    final aiStatus = aiValidation?.qualitySafetyStatus ?? 'ACTIVE';
    final isAiClear = aiStatus == 'CLEAR';

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.15,
      children: [
        // 1. Open Defects
        _buildKpiCard(
          title: 'OPEN DEFECTS',
          value: '$openCount',
          valueColor: AppColors.strongText,
          icon: Icons.fact_check_outlined,
          iconColor: AppColors.primaryLight,
          footerLeft: '$totalCount total',
          footerRight: criticalCount > 0 ? '$criticalCount Crit' : null,
          footerRightColor: AppColors.error,
          onTap: () => Navigator.push<void>(
            context,
            MaterialPageRoute(
              builder: (_) => DefectsScreen(service: widget.service),
            ),
          ).then((_) => _load()),
        ),

        // 2. Active Quarantines
        _buildKpiCard(
          title: 'ACTIVE QUARANTINES',
          value: '$activeQuarantinesCount',
          valueColor: AppColors.error,
          icon: Icons.shield_outlined,
          iconColor: AppColors.error,
          footerLeft: '$batchesHeldCount held',
          footerRight: '$releasedQuarantinesCount rel',
          footerRightColor: const Color(0xFF34D399),
          onTap: () => Navigator.push<void>(
            context,
            MaterialPageRoute(
              builder: (_) => QuarantineScreen(service: widget.service),
            ),
          ).then((_) => _load()),
        ),

        // 3. Restricted Rolls
        _buildKpiCard(
          title: 'RESTRICTED ROLLS',
          value: '$restrictedRollsCount',
          valueColor: const Color(0xFFFBBF24),
          icon: Icons.inventory_2_outlined,
          iconColor: const Color(0xFFFBBF24),
          footerLeft: 'Fabric rolls on hold',
          footerRight: '$clearedRollsCount clear',
          footerRightColor: const Color(0xFF38BDF8),
          onTap: () => Navigator.push<void>(
            context,
            MaterialPageRoute(
              builder: (_) => QuarantineScreen(service: widget.service),
            ),
          ).then((_) => _load()),
        ),

        // 4. AI Safety Status
        _buildKpiCard(
          title: 'AI SAFETY STATUS',
          value: aiStatus,
          valueColor: isAiClear ? const Color(0xFF34D399) : AppColors.error,
          icon: Icons.auto_awesome_outlined,
          iconColor: isAiClear ? const Color(0xFF34D399) : AppColors.primaryLight,
          footerLeft: aiValidation?.workflowId ?? 'Agent safety',
          footerRight: 'Inspect →',
          footerRightColor: AppColors.primaryLight,
          onTap: () => Navigator.push<void>(
            context,
            MaterialPageRoute(
              builder: (_) => AiValidationScreen(
                service: widget.service,
                initialWorkflowId: aiValidation?.workflowId,
              ),
            ),
          ).then((_) => _load()),
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required Color valueColor,
    required IconData icon,
    required Color iconColor,
    required String footerLeft,
    String? footerRight,
    Color? footerRightColor,
    VoidCallback? onTap,
  }) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.mutedText,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
              Icon(icon, color: iconColor, size: 18),
            ],
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              fontFamily: 'monospace',
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Container(
            padding: const EdgeInsets.only(top: 6),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFF1E293B))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    footerLeft,
                    style: const TextStyle(
                      color: AppColors.mutedText,
                      fontSize: 10,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (footerRight != null)
                  Text(
                    footerRight,
                    style: TextStyle(
                      color: footerRightColor ?? AppColors.secondaryText,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildSeverityBreakdownCard({
    required int total,
    required int critical,
    required int high,
    required int medium,
    required int low,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.primaryLight,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Defect Severity Breakdown',
                    style: TextStyle(
                      color: AppColors.strongText,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              Text(
                '$total Total',
                style: const TextStyle(
                  color: AppColors.mutedText,
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _severityBar('Critical', critical, total, AppColors.error),
          const SizedBox(height: 8),
          _severityBar('High', high, total, const Color(0xFFFB923C)),
          const SizedBox(height: 8),
          _severityBar('Medium', medium, total, const Color(0xFFFBBF24)),
          const SizedBox(height: 8),
          _severityBar('Low', low, total, const Color(0xFF94A3B8)),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFF1E293B)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Critical & High: ${critical + high}',
                style: const TextStyle(
                  color: AppColors.mutedText,
                  fontSize: 11,
                ),
              ),
              TextButton(
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DefectsScreen(service: widget.service),
                  ),
                ),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: AppColors.primaryLight,
                  padding: EdgeInsets.zero,
                ),
                child: const Text(
                  'View Defect Matrix →',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _severityBar(String label, int count, int total, Color barColor) {
    final pct = total > 0 ? ((count / total) * 100).round() : 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$label Severity',
              style: const TextStyle(
                color: AppColors.secondaryText,
                fontSize: 11,
              ),
            ),
            Text(
              '$count ($pct%)',
              style: TextStyle(
                color: barColor,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: total > 0 ? count / total : 0,
            backgroundColor: const Color(0xFF0B0F19),
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildQuarantineContainmentCard({
    required int total,
    required int active,
    required int released,
  }) {
    final rate = total > 0 ? ((released / total) * 100).round() : 100;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.shield_outlined,
                    color: AppColors.error,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Quarantine Containment',
                    style: TextStyle(
                      color: AppColors.strongText,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              Text(
                '$total Events',
                style: const TextStyle(
                  color: AppColors.mutedText,
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'ACTIVE RESTRICTION',
                        style: TextStyle(
                          color: AppColors.error,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$active',
                        style: const TextStyle(
                          color: Color(0xFFFECDD3),
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const Text(
                        'Held from floor',
                        style: TextStyle(
                          color: AppColors.mutedText,
                          fontSize: 8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF10B981).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'RELEASED / CLEARED',
                        style: TextStyle(
                          color: Color(0xFF34D399),
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$released',
                        style: const TextStyle(
                          color: Color(0xFFD1FAE5),
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const Text(
                        'Returned to stock',
                        style: TextStyle(
                          color: AppColors.mutedText,
                          fontSize: 8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Containment Clearance Rate',
                style: TextStyle(color: AppColors.mutedText, fontSize: 11),
              ),
              Text(
                '$rate%',
                style: const TextStyle(
                  color: Color(0xFF34D399),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: rate / 100,
              backgroundColor: AppColors.error.withValues(alpha: 0.4),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF10B981),
              ),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Active Holds: $active',
                style: const TextStyle(
                  color: AppColors.mutedText,
                  fontSize: 11,
                ),
              ),
              TextButton(
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => QuarantineScreen(service: widget.service),
                  ),
                ),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: AppColors.primaryLight,
                  padding: EdgeInsets.zero,
                ),
                child: const Text(
                  'Manage Holds →',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDefectPipelineCard({
    required int total,
    required int open,
    required int inReview,
    required int resolved,
    required int closed,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.timeline_rounded,
                    color: Color(0xFF38BDF8),
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Defect Resolution Pipeline',
                    style: TextStyle(
                      color: AppColors.strongText,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              Text(
                '$total Total',
                style: const TextStyle(
                  color: AppColors.mutedText,
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _pipelineRow('Open', open, total, const Color(0xFF3B82F6)),
          const SizedBox(height: 6),
          _pipelineRow('In Review', inReview, total, const Color(0xFFF59E0B)),
          const SizedBox(height: 6),
          _pipelineRow('Resolved', resolved, total, const Color(0xFF10B981)),
          const SizedBox(height: 6),
          _pipelineRow('Closed', closed, total, const Color(0xFF64748B)),
        ],
      ),
    );
  }

  Widget _pipelineRow(String label, int count, int total, Color indicatorColor) {
    final pct = total > 0 ? ((count / total) * 100).round() : 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0B0F19),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: indicatorColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Text(
                '$pct%',
                style: const TextStyle(
                  color: AppColors.mutedText,
                  fontSize: 10,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF111827),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: indicatorColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRequiresAttentionPanel(List<_AttentionItem> items) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Requires Attention',
                    style: TextStyle(
                      color: AppColors.strongText,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  '${items.length} Urgent',
                  style: const TextStyle(
                    color: Color(0xFFFECDD3),
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF0B0F19),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    color: Color(0xFF10B981),
                    size: 28,
                  ),
                  SizedBox(height: 6),
                  Text(
                    'All Systems Nominal',
                    style: TextStyle(
                      color: AppColors.strongText,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'No active quarantine holds or critical defects require review.',
                    style: TextStyle(color: AppColors.mutedText, fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = items[index];
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B0F19),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF1E293B)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.error.withValues(
                                      alpha: 0.15,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: AppColors.error.withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    item.type,
                                    style: const TextStyle(
                                      color: Color(0xFFFECDD3),
                                      fontSize: 8,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    item.title,
                                    style: const TextStyle(
                                      color: AppColors.strongText,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              item.subtitle,
                              style: const TextStyle(
                                color: AppColors.mutedText,
                                fontSize: 10,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton(
                        onPressed: item.onInspect,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primaryLight,
                          side: const BorderSide(color: Color(0xFF2A3958)),
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          textStyle: const TextStyle(fontSize: 11),
                        ),
                        child: const Text('Inspect'),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildRecentActivityStream(List<_RecentActivity> activities) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.history_rounded,
                    color: AppColors.primaryLight,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Recent QA Activity',
                    style: TextStyle(
                      color: AppColors.strongText,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              Text(
                'Live Stream',
                style: TextStyle(color: AppColors.mutedText, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (activities.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'No recent QA events logged.',
                  style: TextStyle(color: AppColors.mutedText, fontSize: 12),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: activities.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final act = activities[index];
                return InkWell(
                  onTap: act.onTap,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B0F19),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF1E293B)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    act.type,
                                    style: const TextStyle(
                                      color: AppColors.primaryLight,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    act.ref,
                                    style: const TextStyle(
                                      color: AppColors.mutedText,
                                      fontSize: 10,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                act.detail,
                                style: const TextStyle(
                                  color: AppColors.secondaryText,
                                  fontSize: 11,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF111827),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            act.status,
                            style: const TextStyle(
                              color: AppColors.primaryLight,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildNavigationShortcuts() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Quick Navigation',
        style: TextStyle(
          color: AppColors.strongText,
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 10),
      _shortcutTile(
        title: 'AI Validation & Safety',
        subtitle: 'Authoritative rules & safety gates',
        icon: Icons.auto_awesome_outlined,
        onTap: () => Navigator.push<void>(
          context,
          MaterialPageRoute(
            builder: (_) => AiValidationScreen(
              service: widget.service,
              initialWorkflowId: _aiValidation?.workflowId,
            ),
          ),
        ).then((_) => _load()),
      ),
      const SizedBox(height: 8),
      _shortcutTile(
        title: 'Defect Reports',
        subtitle: 'Inspection, logging & defect matrix',
        icon: Icons.fact_check_outlined,
        onTap: () => Navigator.push<void>(
          context,
          MaterialPageRoute(
            builder: (_) => DefectsScreen(service: widget.service),
          ),
        ).then((_) => _load()),
      ),
      const SizedBox(height: 8),
      _shortcutTile(
        title: 'Quarantine Control',
        subtitle: 'Active holds & release management',
        icon: Icons.shield_outlined,
        onTap: () => Navigator.push<void>(
          context,
          MaterialPageRoute(
            builder: (_) => QuarantineScreen(service: widget.service),
          ),
        ).then((_) => _load()),
      ),
      const SizedBox(height: 8),
      _shortcutTile(
        title: 'Quarantine History',
        subtitle: 'Audit ledger & released dispositions',
        icon: Icons.history_rounded,
        onTap: () => Navigator.push<void>(
          context,
          MaterialPageRoute(
            builder: (_) => QuarantineHistoryScreen(service: widget.service),
          ),
        ).then((_) => _load()),
      ),
    ],
  );

  Widget _shortcutTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primaryLight, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.strongText,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.mutedText,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.mutedText,
            size: 18,
          ),
        ],
      ),
    ),
  );

  List<_AttentionItem> _computeAttentionItems(
    List<QuarantineRecord> activeQuarantines,
    List<DefectReport> openDefects,
    AiValidationData? aiValidation,
  ) {
    final list = <_AttentionItem>[];

    for (final q in activeQuarantines.take(3)) {
      list.add(
        _AttentionItem(
          type: 'QUARANTINE HOLD',
          title:
              'Roll ${q.inventoryRollId.length > 8 ? q.inventoryRollId.substring(0, 8) : q.inventoryRollId}',
          subtitle: 'Batch: ${q.batchId} • ${q.reason}',
          onInspect: () => Navigator.push<void>(
            context,
            MaterialPageRoute(
              builder: (_) => QuarantineDetailScreen(
                service: widget.service,
                quarantineId: q.id,
              ),
            ),
          ).then((_) => _load()),
        ),
      );
    }

    for (final d in openDefects
        .where(
          (d) => ['critical', 'high'].contains(d.severity.toLowerCase()),
        )
        .take(2)) {
      list.add(
        _AttentionItem(
          type: 'DEFECT ALERT',
          title: 'Defect #${d.id.substring(0, 6)} (${d.severity})',
          subtitle: 'SKU: ${d.skuCode ?? 'N/A'} • ${d.description}',
          onInspect: () => Navigator.push<void>(
            context,
            MaterialPageRoute(
              builder: (_) => DefectDetailScreen(
                service: widget.service,
                defectId: d.id,
              ),
            ),
          ).then((_) => _load()),
        ),
      );
    }

    if (aiValidation != null && aiValidation.needsReview) {
      list.add(
        _AttentionItem(
          type: 'AI SAFETY BLOCK',
          title: 'Hold: ${aiValidation.workflowId}',
          subtitle:
              'PO: ${aiValidation.poReference} • ${aiValidation.quarantinedRollsDisplay}',
          onInspect: () => Navigator.push<void>(
            context,
            MaterialPageRoute(
              builder: (_) => AiValidationScreen(
                service: widget.service,
                initialWorkflowId: aiValidation.workflowId,
              ),
            ),
          ).then((_) => _load()),
        ),
      );
    }

    return list;
  }

  List<_RecentActivity> _computeRecentActivities(
    List<DefectReport> defects,
    List<QuarantineRecord> quarantines,
  ) {
    final list = <_RecentActivity>[];

    for (final d in defects.take(3)) {
      list.add(
        _RecentActivity(
          type: 'Defect Logged',
          ref: 'DEF-${d.id.substring(0, 6)}',
          detail: d.description.isNotEmpty
              ? d.description
              : 'Defect on SKU ${d.skuCode}',
          status: d.status,
          onTap: () => Navigator.push<void>(
            context,
            MaterialPageRoute(
              builder: (_) => DefectDetailScreen(
                service: widget.service,
                defectId: d.id,
              ),
            ),
          ).then((_) => _load()),
        ),
      );
    }

    for (final q in quarantines.take(3)) {
      list.add(
        _RecentActivity(
          type: q.status == 'Released'
              ? 'Quarantine Released'
              : 'Quarantine Placed',
          ref: 'QR-${q.id.substring(0, 6)}',
          detail: 'Roll ${q.inventoryRollId} (${q.batchId})',
          status: q.status,
          onTap: () => Navigator.push<void>(
            context,
            MaterialPageRoute(
              builder: (_) => QuarantineDetailScreen(
                service: widget.service,
                quarantineId: q.id,
              ),
            ),
          ).then((_) => _load()),
        ),
      );
    }

    return list;
  }

  BoxDecoration _cardDecoration() => BoxDecoration(
    gradient: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF161B2E), Color(0xFF0F1523)],
    ),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: const Color(0xFF2A3958), width: 1.2),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.25),
        blurRadius: 10,
        offset: const Offset(0, 4),
      ),
    ],
  );
}

class _AttentionItem {
  const _AttentionItem({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.onInspect,
  });

  final String type;
  final String title;
  final String subtitle;
  final VoidCallback onInspect;
}

class _RecentActivity {
  const _RecentActivity({
    required this.type,
    required this.ref,
    required this.detail,
    required this.status,
    required this.onTap,
  });

  final String type;
  final String ref;
  final String detail;
  final String status;
  final VoidCallback onTap;
}

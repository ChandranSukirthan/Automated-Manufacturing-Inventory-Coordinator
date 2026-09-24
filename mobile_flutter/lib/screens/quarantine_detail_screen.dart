import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../models/quality_models.dart';
import '../services/api_client.dart';
import '../services/quality_service.dart';
import '../widgets/app_widgets.dart';

class QuarantineDetailScreen extends StatefulWidget {
  const QuarantineDetailScreen({
    required this.service,
    required this.quarantineId,
    super.key,
  });

  final QualityService service;
  final String quarantineId;

  @override
  State<QuarantineDetailScreen> createState() => _QuarantineDetailScreenState();
}

class _QuarantineDetailScreenState extends State<QuarantineDetailScreen> {
  QuarantineRecord? _record;
  String? _error;
  bool _loading = true;
  bool _releasing = false;
  BatchDetails? _batch;
  DefectReport? _defect;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final record = await widget.service.getQuarantine(widget.quarantineId);
      final results = await Future.wait([
        widget.service.getBatch(record.batchId),
        widget.service.getDefect(record.defectReportId),
      ]);
      if (mounted) {
        setState(() {
          _record = record;
          _batch = results[0] as BatchDetails;
          _defect = results[1] as DefectReport;
        });
      }
    } on ApiException catch (exception) {
      if (mounted) setState(() => _error = exception.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _release() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Release quarantine?'),
        content: const Text(
          'Release this quarantine and return the inventory to normal business handling?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Release'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _releasing = true;
      _error = null;
    });
    try {
      final record = await widget.service.releaseQuarantine(
        widget.quarantineId,
      );
      final results = await Future.wait([
        widget.service.getBatch(record.batchId),
        widget.service.getDefect(record.defectReportId),
      ]);
      if (mounted) {
        setState(() {
          _record = record;
          _batch = results[0] as BatchDetails;
          _defect = results[1] as DefectReport;
        });
      }
    } on ApiException catch (exception) {
      if (mounted) setState(() => _error = exception.message);
    } finally {
      if (mounted) setState(() => _releasing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _record == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null && _record == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Quarantine details')),
        body: StateMessage(
          message: _error!,
          icon: Icons.cloud_off,
          action: _load,
        ),
      );
    }
    final record = _record;
    if (record == null) {
      return const Scaffold(
        body: StateMessage(
          message: 'Quarantine not found.',
          icon: Icons.search_off,
        ),
      );
    }
    final active = record.status == 'Active';
    final inventoryStatus = _batch?.inventoryRolls
        .firstWhere(
          (roll) => roll.id == record.inventoryRollId,
          orElse: () => const InventoryRoll(
            id: '',
            batchId: '',
            status: 'Unknown',
          ),
        )
        .status;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quarantine details'),
        leading: BackButton(onPressed: () => Navigator.pop(context)),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 17, 16, 16),
              decoration: _quarantineDetailDecoration,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'QUARANTINE RECORD',
                    style: TextStyle(
                      color: AppColors.primaryLight,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Defect',
                    style: TextStyle(
                      color: AppColors.mutedText,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    record.defectReportId,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.strongText,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _BadgeField(
                          label: 'Severity',
                          child: _QuarantineDetailBadge(
                            label: _defect?.severity ?? 'Unknown',
                            color: AppColors.error,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _BadgeField(
                          label: 'Status',
                          child: _QuarantineDetailBadge(
                            label: record.status,
                            color: AppColors.primaryLight,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _Info(label: 'Batch code', value: record.batchId),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _Info(
                          label: 'Inventory roll',
                          value: record.inventoryRollId,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _BadgeField(
                          label: 'Inventory status',
                          child: _QuarantineDetailBadge(
                            label: inventoryStatus ?? 'Unknown',
                            color: AppColors.primaryLight,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _Info(
                          label: 'Created',
                          value: _formatDate(record.createdAt),
                        ),
                      ),
                    ],
                  ),
                  _Info(
                    label: 'Released',
                    value: record.releasedAt == null
                        ? 'Not released'
                        : _formatDate(record.releasedAt!),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'Reason',
                    style: TextStyle(
                      color: AppColors.mutedText,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: AppColors.background.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: const Color(0xFF2A3958)),
                    ),
                    child: Text(
                      record.reason,
                      style: const TextStyle(
                        color: AppColors.primaryText,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppColors.errorText)),
            ],
            if (active) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _releasing ? null : _release,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.background,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
                icon: _releasing
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: Text(
                  _releasing ? 'Releasing...' : 'Release quarantine',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.mutedText,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.strongText,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class _BadgeField extends StatelessWidget {
  const _BadgeField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.mutedText,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    ),
  );
}

class _QuarantineDetailBadge extends StatelessWidget {
  const _QuarantineDetailBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(7),
      border: Border.all(color: color.withValues(alpha: 0.32)),
    ),
    child: Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: color,
        fontSize: 11,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

final _quarantineDetailDecoration = BoxDecoration(
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

String _formatDate(DateTime value) {
  final local = value.toLocal();
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${local.year}-${twoDigits(local.month)}-${twoDigits(local.day)} '
      '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
}

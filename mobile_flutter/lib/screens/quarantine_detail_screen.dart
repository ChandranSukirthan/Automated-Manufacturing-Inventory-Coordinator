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
        widget.service.getBatch(record.batchId).catchError(
              (_) => const BatchDetails(id: '', productType: '', inventoryRolls: []),
            ),
        widget.service.getDefect(record.defectReportId).catchError(
              (_) => DefectReport(
                id: record.defectReportId,
                batchId: record.batchId,
                productType: '',
                severity: 'Unknown',
                description: '',
                createdAt: DateTime.now(),
                status: 'Open',
              ),
            ),
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
    } catch (_) {
      if (mounted) setState(() => _error = 'Unable to load quarantine details.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _release() async {
    final noteController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFF1E293B)),
        ),
        title: const Text(
          'Release Quarantine',
          style: TextStyle(color: AppColors.strongText, fontSize: 16, fontWeight: FontWeight.w800),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Release this quarantine hold and return the inventory roll to active stock?',
              style: TextStyle(color: AppColors.secondaryText, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              maxLines: 3,
              style: const TextStyle(color: AppColors.strongText, fontSize: 13),
              decoration: const InputDecoration(
                labelText: 'Disposition note (optional)',
                hintText: 'Reason or laboratory clearance note...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
            ),
            child: const Text('Authorize Release'),
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
        resolutionNote: noteController.text.trim(),
      );
      if (mounted) {
        setState(() {
          _record = record;
        });
      }
      _load();
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
        appBar: AppBar(title: const Text('Quarantine Details')),
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
    final active = record.status.toLowerCase() == 'active';
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
        title: const Text('Quarantine Details'),
        leading: BackButton(onPressed: () => Navigator.pop(context)),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 36),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: _detailBoxDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'QUARANTINE RECORD',
                        style: TextStyle(
                          color: AppColors.primaryLight,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: active
                              ? AppColors.error.withValues(alpha: 0.15)
                              : const Color(0xFF10B981).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: active
                                ? AppColors.error.withValues(alpha: 0.35)
                                : const Color(0xFF10B981).withValues(alpha: 0.35),
                          ),
                        ),
                        child: Text(
                          record.status,
                          style: TextStyle(
                            color: active ? AppColors.error : const Color(0xFF34D399),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Roll: ${record.inventoryRollId}',
                    style: const TextStyle(
                      color: Color(0xFF67E8F9),
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: _metaField('Severity', _defect?.severity ?? 'Unknown', isBadge: true),
                      ),
                      Expanded(
                        child: _metaField(
                          'Quarantine ID',
                          '#${record.id.length > 8 ? record.id.substring(0, 8) : record.id}',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: _metaField('Inventory Status', inventoryStatus ?? 'Unknown'),
                      ),
                      Expanded(
                        child: _metaField('Defect Report', '#${record.defectReportId.length > 8 ? record.defectReportId.substring(0, 8) : record.defectReportId}'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: _metaField('Created Date', _formatDate(record.createdAt)),
                      ),
                      Expanded(
                        child: _metaField(
                          'Released Date',
                          record.releasedAt == null ? 'Not released' : _formatDate(record.releasedAt!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  const Text(
                    'REASON FOR QUARANTINE',
                    style: TextStyle(
                      color: AppColors.mutedText,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B0F19),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF1E293B)),
                    ),
                    child: Text(
                      record.reason,
                      style: const TextStyle(
                        color: AppColors.primaryText,
                        fontSize: 13,
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
              SizedBox(
                height: 50,
                child: FilledButton.icon(
                  onPressed: _releasing ? null : _release,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                  icon: _releasing
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.verified_user_outlined),
                  label: Text(
                    _releasing ? 'Releasing...' : 'Authorize Quarantine Release',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _metaField(String label, String value, {bool isBadge = false}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: AppColors.mutedText,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 3),
      if (isBadge)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            value.toUpperCase(),
            style: TextStyle(
              color: value.toLowerCase() == 'critical' || value.toLowerCase() == 'high'
                  ? AppColors.error
                  : const Color(0xFFFBBF24),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              fontFamily: 'monospace',
            ),
          ),
        )
      else
        Text(
          value,
          style: const TextStyle(
            color: AppColors.strongText,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            fontFamily: 'monospace',
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
    ],
  );

  BoxDecoration _detailBoxDecoration() => BoxDecoration(
    color: const Color(0xFF0F172A),
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: const Color(0xFF1E293B), width: 1.2),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.3),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ],
  );

  String _formatDate(DateTime value) {
    final local = value.toUtc().add(const Duration(hours: 5, minutes: 30));
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} ${two(local.hour)}:${two(local.minute)}';
  }
}

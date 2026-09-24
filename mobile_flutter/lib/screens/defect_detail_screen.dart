import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../models/quality_models.dart';
import '../services/api_client.dart';
import '../services/inventory_api_service.dart';
import '../services/quality_service.dart';
import '../widgets/app_widgets.dart';
import 'defect_form_screen.dart';
import 'quarantine_detail_screen.dart';

class DefectDetailScreen extends StatefulWidget {
  const DefectDetailScreen({
    required this.service,
    required this.defectId,
    super.key,
  });

  final QualityService service;
  final String defectId;

  @override
  State<DefectDetailScreen> createState() => _DefectDetailScreenState();
}

class _DefectDetailScreenState extends State<DefectDetailScreen> {
  DefectReport? _defect;
  String? _error;
  bool _loading = true;
  bool _quarantining = false;
  List<QuarantineRecord> _affectedInventory = [];
  String? _skuCode;
  final _reason = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        widget.service.getDefect(widget.defectId),
        widget.service.getQuarantines(),
        InventoryApiService().fetchOwnedRolls(),
        InventoryApiService().fetchRawMaterials(),
      ]);
      final defect = results[0] as DefectReport;
      final quarantines = results[1] as List<QuarantineRecord>;
      final rolls = results[2] as List<InventoryRollModel>;
      final materials = results[3] as List<RawMaterialModel>;
      final affectedRoll = rolls
          .where((roll) => defect.affectedInventory.contains(roll.id))
          .firstOrNull;
      final material = materials
          .where((item) => item.id == affectedRoll?.rawMaterialId)
          .firstOrNull;
      if (mounted) {
        setState(() {
          _defect = defect;
          _skuCode = material?.skuCode;
          _affectedInventory = quarantines
              .where((record) => record.defectReportId == widget.defectId)
              .toList();
        });
      }
    } on ApiException catch (exception) {
      if (mounted) setState(() => _error = exception.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit() async {
    final defect = _defect;
    if (defect == null) return;
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            DefectFormScreen(service: widget.service, defect: defect),
      ),
    );
    if (updated == true) _load();
  }

  Future<void> _quarantine() async {
    if (_defect == null || _reason.text.trim().isEmpty) {
      setState(() => _error = 'A quarantine reason is required.');
      return;
    }
    setState(() {
      _quarantining = true;
      _error = null;
    });
    try {
      final records = await widget.service.quarantineDefect(
        widget.defectId,
        _reason.text.trim(),
      );
      final record = records.isNotEmpty ? records.first : null;
      if (record == null) {
        if (mounted) {
          setState(
            () => _error = 'The backend did not create a quarantine record.',
          );
        }
        return;
      }
      if (mounted) {
        await Navigator.push<void>(
          context,
          MaterialPageRoute(
            builder: (_) => QuarantineDetailScreen(
              service: widget.service,
              quarantineId: record.id,
            ),
          ),
        );
      }
    } on ApiException catch (exception) {
      if (mounted) setState(() => _error = exception.message);
    } finally {
      if (mounted) setState(() => _quarantining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _defect == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null && _defect == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Defect detail')),
        body: StateMessage(
          message: _error!,
          icon: Icons.cloud_off,
          action: _load,
        ),
      );
    }
    final defect = _defect;
    if (defect == null) {
      return const Scaffold(
        body: StateMessage(
          message: 'Defect not found.',
          icon: Icons.search_off,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Defect detail'),
        actions: [
          IconButton(
            onPressed: _edit,
            icon: const Icon(Icons.edit_outlined),
            color: AppColors.primaryLight,
            tooltip: 'Edit defect',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 17, 16, 16),
              decoration: _detailDecoration,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'DEFECT REPORT',
                    style: TextStyle(
                      color: AppColors.primaryLight,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _skuCode ?? 'Unavailable',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.strongText,
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _DetailBadgeField(
                          label: 'Severity',
                          child: _DefectBadge(
                            label: defect.severity,
                            color: AppColors.error,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _DetailBadgeField(
                          label: 'Status',
                          child: _DefectBadge(
                            label: defect.status,
                            color: AppColors.primaryLight,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _DetailMeta(
                          label: 'Created',
                          value: _formatDate(defect.createdAt),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _DetailMeta(
                          label: 'Reported by',
                          value: defect.reportedByUserId ?? 'Unavailable',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Description',
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
                      defect.description,
                      style: const TextStyle(
                        color: AppColors.primaryText,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _DetailMeta(
                    label: 'Affected inventory',
                    value:
                        (defect.affectedInventory.isNotEmpty
                                ? defect.affectedInventory
                                : _affectedInventory
                                      .map((record) => record.inventoryRollId)
                                      .toList())
                            .join(', '),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 17, 16, 16),
              decoration: _detailDecoration,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Quarantine inventory',
                    style: TextStyle(
                      color: AppColors.strongText,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Affected inventory rolls are selected automatically from this defect.',
                    style: TextStyle(color: AppColors.mutedText, fontSize: 13),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _reason,
                    maxLines: 3,
                    style: const TextStyle(
                      color: AppColors.strongText,
                      fontSize: 14,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Reason for quarantine',
                      hintText: 'Reason for quarantine',
                      hintStyle: TextStyle(color: AppColors.mutedText),
                      alignLabelWithHint: true,
                      enabledBorder: _detailFieldBorder,
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                        borderSide: BorderSide(
                          color: AppColors.primary,
                          width: 1.4,
                        ),
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: const TextStyle(color: AppColors.errorText),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: _quarantining ? null : _quarantine,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.warning,
                        foregroundColor: AppColors.background,
                        disabledBackgroundColor: AppColors.warning.withValues(
                          alpha: 0.35,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                      icon: _quarantining
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.pause_circle_outline_rounded),
                      label: const Text(
                        'Quarantine Inventory',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailMeta extends StatelessWidget {
  const _DetailMeta({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
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
  );
}

class _DetailBadgeField extends StatelessWidget {
  const _DetailBadgeField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
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
  );
}

class _DefectBadge extends StatelessWidget {
  const _DefectBadge({required this.label, required this.color});

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

const _detailFieldBorder = OutlineInputBorder(
  borderRadius: BorderRadius.all(Radius.circular(12)),
  borderSide: BorderSide(color: Color(0xFF2A3958), width: 1.2),
);

final _detailDecoration = BoxDecoration(
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

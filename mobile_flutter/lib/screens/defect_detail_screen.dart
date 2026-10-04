import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../models/quality_models.dart';
import '../services/api_client.dart';
import '../services/inventory_api_service.dart';
import '../services/quality_service.dart';
import '../widgets/app_widgets.dart';
import 'defect_form_screen.dart';

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
  String? _successMessage;
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
        widget.service.getQuarantines().catchError((_) => <QuarantineRecord>[]),
        InventoryApiService().fetchOwnedRolls().catchError((_) => <InventoryRollModel>[]),
        InventoryApiService().fetchRawMaterials().catchError((_) => <RawMaterialModel>[]),
      ]);
      final defect = results[0] as DefectReport;
      final quarantines = results[1] as List<QuarantineRecord>;
      final rolls = results[2] as List<InventoryRollModel>;
      final materials = results[3] as List<RawMaterialModel>;
      final affectedRoll = rolls
          .where((roll) => defect.affectedInventory.contains(roll.rollIdentifier))
          .firstOrNull;
      final material = materials
          .where((item) => item.id == affectedRoll?.rawMaterialId)
          .firstOrNull;
      if (mounted) {
        setState(() {
          _defect = defect;
          _skuCode = material?.skuCode ?? defect.skuCode;
          _affectedInventory = quarantines
              .where((record) => record.defectReportId == widget.defectId)
              .toList();
        });
      }
    } on ApiException catch (exception) {
      if (mounted) setState(() => _error = exception.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Unable to load defect details.');
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
        setState(() {
          _reason.clear();
          _successMessage = 'Inventory successfully placed into quarantine.';
        });
        Future.delayed(const Duration(seconds: 4), () {
          if (mounted) setState(() => _successMessage = null);
        });
        _load();
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
        appBar: AppBar(title: const Text('Defect Detail')),
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

    final isCritical = defect.severity.toLowerCase() == 'critical' || defect.severity.toLowerCase() == 'high';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Defect Detail'),
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
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 36),
          children: [
            if (_successMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                ),
                child: Text(
                  _successMessage!,
                  style: const TextStyle(color: Color(0xFFD1FAE5), fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 14),
            ],

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
                        'DEFECT REPORT',
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
                          color: isCritical ? AppColors.error.withValues(alpha: 0.15) : const Color(0xFFFBBF24).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isCritical ? AppColors.error.withValues(alpha: 0.35) : const Color(0xFFFBBF24).withValues(alpha: 0.35),
                          ),
                        ),
                        child: Text(
                          defect.severity.toUpperCase(),
                          style: TextStyle(
                            color: isCritical ? AppColors.error : const Color(0xFFFBBF24),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _skuCode ?? 'Unavailable',
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
                      Expanded(child: _metaField('Status', defect.status)),
                      Expanded(child: _metaField('Created', _formatDate(defect.createdAt))),
                    ],
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(child: _metaField('Reported By', defect.reportedByUserId ?? 'System')),
                      Expanded(
                        child: _metaField(
                          'Affected Rolls',
                          (defect.affectedInventory.isNotEmpty
                                  ? defect.affectedInventory
                                  : _affectedInventory.map((r) => r.inventoryRollId).toList())
                              .join(', '),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  const Text(
                    'DESCRIPTION',
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
                      defect.description.isNotEmpty ? defect.description : 'No description provided.',
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
            const SizedBox(height: 16),

            // Quarantine Action Panel
            Container(
              padding: const EdgeInsets.all(18),
              decoration: _detailBoxDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Quarantine Inventory',
                    style: TextStyle(
                      color: AppColors.strongText,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Place affected inventory rolls into quarantine restriction.',
                    style: TextStyle(color: AppColors.mutedText, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _reason,
                    maxLines: 3,
                    style: const TextStyle(color: AppColors.strongText, fontSize: 13),
                    decoration: const InputDecoration(
                      labelText: 'Quarantine Reason',
                      hintText: 'Enter specific reason for quarantine containment...',
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(_error!, style: const TextStyle(color: AppColors.errorText, fontSize: 12)),
                  ],
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: _quarantining ? null : _quarantine,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFD97706),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: _quarantining
                          ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.shield_outlined, size: 18),
                      label: const Text('Place In Quarantine', style: TextStyle(fontWeight: FontWeight.w800)),
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

  Widget _metaField(String label, String value) => Column(
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
      const SizedBox(height: 2),
      Text(
        value.isNotEmpty ? value : '—',
        style: const TextStyle(
          color: AppColors.strongText,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          fontFamily: 'monospace',
        ),
        maxLines: 2,
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
    final local = value.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.month}/${two(local.day)}/${local.year}';
  }
}

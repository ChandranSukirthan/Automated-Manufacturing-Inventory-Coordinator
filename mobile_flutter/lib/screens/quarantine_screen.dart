import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../models/quality_models.dart';
import '../services/api_client.dart';
import '../services/quality_service.dart';
import '../widgets/app_widgets.dart';
import 'quarantine_detail_screen.dart';
import 'quarantine_history_screen.dart';

class QuarantineScreen extends StatefulWidget {
  const QuarantineScreen({required this.service, super.key});

  final QualityService service;

  @override
  State<QuarantineScreen> createState() => _QuarantineScreenState();
}

enum _QuarantineSort { newest, oldest, batch, severity, status }

class _QuarantineScreenState extends State<QuarantineScreen> {
  static const _pageSize = 8;
  static const _severities = ['LOW', 'MEDIUM', 'HIGH', 'Critical'];
  static const _statuses = ['Active', 'Released'];

  List<QuarantineRecord>? _records;
  List<DefectReport> _defects = [];
  String? _error;
  String? _successMessage;
  String _query = '';
  String? _severity;
  String? _status;
  _QuarantineSort _sort = _QuarantineSort.newest;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final results = await Future.wait([
        widget.service.getQuarantines(),
        widget.service.getDefects().catchError((_) => <DefectReport>[]),
      ]);
      if (mounted) {
        setState(() {
          _records = results[0] as List<QuarantineRecord>;
          _defects = results[1] as List<DefectReport>;
        });
      }
    } on ApiException catch (exception) {
      if (mounted) setState(() => _error = exception.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Unable to load quarantine records.');
      }
    }
  }

  String _severityFor(QuarantineRecord record) {
    for (final defect in _defects) {
      if (defect.id == record.defectReportId) return defect.severity;
    }
    return 'Unknown';
  }

  List<QuarantineRecord> get _visibleRecords {
    final query = _query.trim().toLowerCase();
    final records = (_records ?? []).where((record) {
      final severity = _severityFor(record);
      final searchable = [
        record.batchId,
        record.inventoryRollId,
        record.reason,
        record.status,
        severity,
      ].join(' ').toLowerCase();
      return (query.isEmpty || searchable.contains(query)) &&
          (_severity == null ||
              severity.toLowerCase() == _severity!.toLowerCase()) &&
          (_status == null ||
              record.status.toLowerCase() == _status!.toLowerCase());
    }).toList();

    records.sort(
      (left, right) => switch (_sort) {
        _QuarantineSort.newest => right.createdAt.compareTo(left.createdAt),
        _QuarantineSort.oldest => left.createdAt.compareTo(right.createdAt),
        _QuarantineSort.batch => left.batchId.compareTo(right.batchId),
        _QuarantineSort.status => left.status.compareTo(right.status),
        _QuarantineSort.severity => _severityFor(
          left,
        ).compareTo(_severityFor(right)),
      },
    );
    return records;
  }

  void _openResolveDialog(QuarantineRecord record) {
    showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (_) => _ReleaseQuarantineModal(
        record: record,
        severity: _severityFor(record),
        onRelease: (note) async {
          await widget.service.releaseQuarantine(
            record.id,
            resolutionNote: note,
          );
          if (mounted) {
            setState(() {
              _successMessage =
                  'Quarantine for Roll ${record.inventoryRollId} successfully released.';
            });
            Future.delayed(const Duration(seconds: 4), () {
              if (mounted) setState(() => _successMessage = null);
            });
            _load();
          }
        },
      ),
    );
  }

  Future<void> _open(QuarantineRecord record) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => QuarantineDetailScreen(
          service: widget.service,
          quarantineId: record.id,
        ),
      ),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final allRecords = _records ?? [];
    final activeRecords = allRecords
        .where((r) => r.status.toLowerCase() == 'active')
        .toList();
    final criticalCases = allRecords
        .where((r) => _severityFor(r).toLowerCase() == 'critical')
        .length;
    final releasedRecords = allRecords
        .where((r) => r.status.toLowerCase() == 'released')
        .toList();

    final records = _visibleRecords;
    final totalPages = (records.length / _pageSize).ceil().clamp(1, 999999);
    final visibleRecords = records
        .skip((_page - 1).clamp(0, totalPages - 1) * _pageSize)
        .take(_pageSize)
        .toList();

    return Scaffold(
      body: _error != null && _records == null
          ? StateMessage(message: _error!, icon: Icons.cloud_off, action: _load)
          : _records == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
                children: [
                  _buildHeader(),
                  const SizedBox(height: 16),

                  // Success message
                  if (_successMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF10B981).withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            color: Color(0xFF10B981),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _successMessage!,
                              style: const TextStyle(
                                color: Color(0xFFD1FAE5),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Top 4 Metric Cards
                  _buildTopMetricCards(
                    activeCount: activeRecords.length,
                    criticalCount: criticalCases,
                    affectedRollsCount: allRecords.length,
                    releasedCount: releasedRecords.length,
                  ),
                  const SizedBox(height: 16),

                  _filterToolbar(),
                  const SizedBox(height: 16),

                  if (_error != null) _errorBanner(),

                  if (records.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 60),
                      child: StateMessage(
                        message: 'No quarantine records match these filters.',
                        icon: Icons.inventory_2_outlined,
                      ),
                    )
                  else
                    _quarantineList(visibleRecords),

                  if (totalPages > 1) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: _page <= 1
                              ? null
                              : () => setState(() => _page--),
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Text(
                          'Page ${_page.clamp(1, totalPages)} of $totalPages',
                          style: const TextStyle(
                            color: AppColors.mutedText,
                            fontSize: 12,
                          ),
                        ),
                        IconButton(
                          onPressed: _page >= totalPages
                              ? null
                              : () => setState(() => _page++),
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildHeader() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'QUALITY ASSURANCE',
        style: TextStyle(
          color: AppColors.primaryLight,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
        ),
      ),
      const SizedBox(height: 6),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quarantine Management',
                  style: TextStyle(
                    color: AppColors.strongText,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Monitor and control inventory under quality restriction',
                  style: TextStyle(color: AppColors.mutedText, fontSize: 13),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: () => Navigator.push<void>(
              context,
              MaterialPageRoute(
                builder: (_) => QuarantineHistoryScreen(
                  service: widget.service,
                  showPageChrome: true,
                ),
              ),
            ).then((_) => _load()),
            icon: const Icon(Icons.history_rounded, size: 16),
            label: const Text('History'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaryLight,
              side: const BorderSide(color: Color(0xFF2A3958)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              textStyle: const TextStyle(fontSize: 11),
            ),
          ),
        ],
      ),
    ],
  );

  Widget _buildTopMetricCards({
    required int activeCount,
    required int criticalCount,
    required int affectedRollsCount,
    required int releasedCount,
  }) => GridView.count(
    crossAxisCount: 2,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    crossAxisSpacing: 10,
    mainAxisSpacing: 10,
    childAspectRatio: 1.6,
    children: [
      _metricCard(
        'ACTIVE QUARANTINES',
        '$activeCount',
        AppColors.error,
        Icons.shield_outlined,
        'Active containment holds',
      ),
      _metricCard(
        'CRITICAL CASES',
        '$criticalCount',
        const Color(0xFFFB923C),
        Icons.warning_amber_rounded,
        'High severity defects',
      ),
      _metricCard(
        'AFFECTED ROLLS',
        '$affectedRollsCount',
        const Color(0xFFFBBF24),
        Icons.inventory_2_outlined,
        'Total tracked rolls',
      ),
      _metricCard(
        'RELEASED',
        '$releasedCount',
        const Color(0xFF34D399),
        Icons.check_circle_outline,
        'Returned to floor',
      ),
    ],
  );

  Widget _metricCard(
    String label,
    String value,
    Color valueColor,
    IconData icon,
    String subtitle,
  ) => Container(
    padding: const EdgeInsets.all(12),
    decoration: _cardBoxDecoration(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppColors.mutedText,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
            Icon(icon, color: valueColor, size: 16),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(height: 1),
        Text(
          subtitle,
          style: const TextStyle(color: AppColors.mutedText, fontSize: 8),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    ),
  );

  Widget _filterToolbar() {
    final hasFilters =
        _query.isNotEmpty || _severity != null || _status != null;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardBoxDecoration(),
      child: Column(
        children: [
          TextField(
            onChanged: (value) => setState(() {
              _query = value;
              _page = 1;
            }),
            style: const TextStyle(color: AppColors.strongText, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search batch, inventory roll, reason...',
              hintStyle: const TextStyle(
                color: AppColors.mutedText,
                fontSize: 12,
              ),
              prefixIcon: const Icon(Icons.search, size: 18),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () => setState(() {
                        _query = '';
                        _page = 1;
                      }),
                      icon: const Icon(Icons.clear, size: 16),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _dropdown(
                  'All Severities',
                  _severity,
                  _severities,
                  (v) => setState(() {
                    _severity = v;
                    _page = 1;
                  }),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _dropdown(
                  'All Statuses',
                  _status,
                  _statuses,
                  (v) => setState(() {
                    _status = v;
                    _page = 1;
                  }),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_visibleRecords.length} records found',
                style: const TextStyle(
                  color: AppColors.mutedText,
                  fontSize: 11,
                ),
              ),
              Row(
                children: [
                  PopupMenuButton<_QuarantineSort>(
                    tooltip: 'Sort by',
                    icon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.sort_rounded,
                          size: 14,
                          color: AppColors.mutedText,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _sort.name.toUpperCase(),
                          style: const TextStyle(
                            color: AppColors.mutedText,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    color: const Color(0xFF0F172A),
                    onSelected: (sort) {
                      setState(() {
                        _sort = sort;
                      });
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: _QuarantineSort.newest,
                        child: Text('Newest First', style: TextStyle(fontSize: 12)),
                      ),
                      PopupMenuItem(
                        value: _QuarantineSort.oldest,
                        child: Text('Oldest First', style: TextStyle(fontSize: 12)),
                      ),
                      PopupMenuItem(
                        value: _QuarantineSort.batch,
                        child: Text('Batch ID', style: TextStyle(fontSize: 12)),
                      ),
                      PopupMenuItem(
                        value: _QuarantineSort.severity,
                        child: Text('Severity', style: TextStyle(fontSize: 12)),
                      ),
                      PopupMenuItem(
                        value: _QuarantineSort.status,
                        child: Text('Status', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                  if (hasFilters)
                    TextButton.icon(
                      onPressed: () => setState(() {
                        _query = '';
                        _severity = null;
                        _status = null;
                        _sort = _QuarantineSort.newest;
                        _page = 1;
                      }),
                      icon: const Icon(Icons.refresh_rounded, size: 14),
                      label: const Text('Reset'),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: AppColors.primaryLight,
                        padding: EdgeInsets.zero,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dropdown(
    String label,
    String? value,
    List<String> values,
    ValueChanged<String?> onChanged,
  ) => DropdownButtonFormField<String?>(
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.mutedText, fontSize: 11),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    ),
    style: const TextStyle(color: AppColors.strongText, fontSize: 12),
    dropdownColor: const Color(0xFF0F172A),
    items: [
      DropdownMenuItem<String?>(
        value: null,
        child: Text(label, style: const TextStyle(fontSize: 12)),
      ),
      ...values.map(
        (item) => DropdownMenuItem<String?>(
          value: item,
          child: Text(item, style: const TextStyle(fontSize: 12)),
        ),
      ),
    ],
    onChanged: onChanged,
  );

  Widget _errorBanner() => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.error.withValues(alpha: 0.12),
      border: Border.all(color: AppColors.error.withValues(alpha: 0.35)),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            _error!,
            style: const TextStyle(color: AppColors.errorText, fontSize: 12),
          ),
        ),
        TextButton(onPressed: _load, child: const Text('Retry')),
      ],
    ),
  );

  Widget _quarantineList(List<QuarantineRecord> records) => ListView.separated(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    itemCount: records.length,
    separatorBuilder: (_, _) => const SizedBox(height: 10),
    itemBuilder: (context, index) {
      final r = records[index];
      final severity = _severityFor(r);
      final isActive = r.status.toLowerCase() == 'active';

      return Container(
        padding: const EdgeInsets.all(14),
        decoration: _cardBoxDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.inventory_2_outlined,
                      color: Color(0xFF67E8F9),
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      r.inventoryRollId,
                      style: const TextStyle(
                        color: Color(0xFF67E8F9),
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
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
                    color: isActive
                        ? AppColors.error.withValues(alpha: 0.15)
                        : const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isActive
                          ? AppColors.error.withValues(alpha: 0.35)
                          : const Color(0xFF10B981).withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    r.status,
                    style: TextStyle(
                      color: isActive
                          ? AppColors.error
                          : const Color(0xFF34D399),
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Batch: ${r.batchId}',
                    style: const TextStyle(
                      color: AppColors.mutedText,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
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
                    severity.toUpperCase(),
                    style: TextStyle(
                      color: severity.toLowerCase() == 'critical' ||
                              severity.toLowerCase() == 'high'
                          ? AppColors.error
                          : const Color(0xFFFBBF24),
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              r.reason,
              style: const TextStyle(
                color: AppColors.secondaryText,
                fontSize: 12,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDate(r.createdAt),
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 10,
                    fontFamily: 'monospace',
                  ),
                ),
                Row(
                  children: [
                    if (isActive) ...[
                      FilledButton(
                        onPressed: () => _openResolveDialog(r),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          foregroundColor: Colors.white,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          textStyle: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        child: const Text('Review & Release'),
                      ),
                      const SizedBox(width: 6),
                    ],
                    OutlinedButton(
                      onPressed: () => _open(r),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryLight,
                        side: const BorderSide(color: Color(0xFF2A3958)),
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        textStyle: const TextStyle(fontSize: 11),
                      ),
                      child: const Text('Details'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      );
    },
  );

  BoxDecoration _cardBoxDecoration() => BoxDecoration(
    color: const Color(0xFF0F172A),
    borderRadius: BorderRadius.circular(16),
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

/// Release Quarantine Modal Dialog with Inspector Disposition Note
class _ReleaseQuarantineModal extends StatefulWidget {
  const _ReleaseQuarantineModal({
    required this.record,
    required this.severity,
    required this.onRelease,
  });

  final QuarantineRecord record;
  final String severity;
  final Future<void> Function(String? note) onRelease;

  @override
  State<_ReleaseQuarantineModal> createState() =>
      _ReleaseQuarantineModalState();
}

class _ReleaseQuarantineModalState extends State<_ReleaseQuarantineModal> {
  final _noteController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.onRelease(_noteController.text.trim());
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = 'Failed to release quarantine: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
    backgroundColor: Colors.transparent,
    child: Container(
      constraints: const BoxConstraints(maxWidth: 420),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1E293B), width: 1.4),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.verified_user_outlined,
                    color: Color(0xFF34D399),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Review & Release Quarantine',
                        style: TextStyle(
                          color: AppColors.strongText,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Roll ${widget.record.inventoryRollId}',
                        style: const TextStyle(
                          color: AppColors.primaryLight,
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Summary box
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF0B0F19),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF1E293B)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Batch: ${widget.record.batchId} • Severity: ${widget.severity}',
                    style: const TextStyle(
                      color: AppColors.mutedText,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Reason: ${widget.record.reason}',
                    style: const TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            if (_error != null) ...[
              Text(
                _error!,
                style: const TextStyle(
                  color: AppColors.errorText,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 10),
            ],

            const Text(
              'INSPECTOR DISPOSITION NOTE',
              style: TextStyle(
                color: AppColors.mutedText,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _noteController,
              maxLines: 3,
              style: const TextStyle(color: AppColors.strongText, fontSize: 13),
              decoration: const InputDecoration(
                hintText:
                    'State lab clearance, rework completion, or inspector authorization releasing this roll...',
                hintStyle: TextStyle(color: AppColors.mutedText, fontSize: 12),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _submitting ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox.square(
                          dimension: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check, size: 16),
                  label: const Text('Authorize Release'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../models/quality_models.dart';
import '../services/api_client.dart';
import '../services/quality_service.dart';
import '../widgets/app_widgets.dart';
import 'quarantine_detail_screen.dart';

class QuarantineScreen extends StatefulWidget {
  const QuarantineScreen({required this.service, super.key});

  final QualityService service;

  @override
  State<QuarantineScreen> createState() => _QuarantineScreenState();
}

class _QuarantineScreenState extends State<QuarantineScreen> {
  static const _pageSize = 8;
  List<QuarantineRecord>? _records;
  List<DefectReport> _defects = [];
  String? _error;
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
        widget.service.getDefects(),
      ]);
      if (mounted) {
        setState(() {
          _records = results[0] as List<QuarantineRecord>;
          _defects = results[1] as List<DefectReport>;
        });
      }
    } on ApiException catch (exception) {
      if (mounted) setState(() => _error = exception.message);
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
          (_severity == null || severity == _severity) &&
          (_status == null || record.status == _status);
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

  Future<void> _showSort() async {
    final result = await showModalBottomSheet<_QuarantineSort>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Sort quarantine records')),
            ..._QuarantineSort.values.map(
              (sort) => ListTile(
                leading: Icon(
                  sort == _sort
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                ),
                title: Text(sort.label),
                onTap: () => Navigator.pop(context, sort),
              ),
            ),
          ],
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _sort = result;
        _page = 1;
      });
    }
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
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  _filterToolbar(),
                  const SizedBox(height: 16),
                  if (_error != null) _errorBanner(),
                  if (records.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 80),
                      child: StateMessage(
                        message: 'No quarantine records match these filters.',
                        icon: Icons.inventory_2_outlined,
                      ),
                    )
                  else
                    _quarantineTable(visibleRecords),
                  if (totalPages > 1) ...[
                    const SizedBox(height: 8),
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

  Widget _filterToolbar() {
    final hasFilters =
        _query.isNotEmpty || _severity != null || _status != null;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _quarantineDecoration,
      child: Column(
        children: [
            TextField(
              onChanged: (value) => setState(() {
                _query = value;
                _page = 1;
              }),
              style: const TextStyle(color: AppColors.strongText),
              decoration: InputDecoration(
                hintText: 'Search batch, inventory, reason...',
                hintStyle: const TextStyle(color: AppColors.mutedText),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () => setState(() {
                          _query = '';
                          _page = 1;
                        }),
                        icon: const Icon(Icons.clear),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _dropdown(
                    'All Severities',
                    _severity,
                    const ['LOW', 'MEDIUM', 'HIGH', 'Critical'],
                    (value) => setState(() {
                      _severity = value;
                      _page = 1;
                    }),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _dropdown(
                    'All Statuses',
                    _status,
                    const ['Active', 'Released'],
                    (value) => setState(() {
                      _status = value;
                      _page = 1;
                    }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Divider(height: 1, color: AppColors.border.withValues(alpha: 0.7)),
            const SizedBox(height: 10),
            Row(
              children: [
                const Text(
                  'Sort By: ',
                  style: TextStyle(color: AppColors.mutedText, fontSize: 12),
                ),
                Text(
                  _sort.label,
                  style: const TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                IconButton(
                  onPressed: _showSort,
                  icon: const Icon(Icons.swap_vert_rounded, size: 18),
                  tooltip: 'Change sort',
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.only(left: 8),
                  constraints: const BoxConstraints(),
                ),
                if (hasFilters)
                  IconButton(
                    onPressed: () => setState(() {
                      _query = '';
                      _severity = null;
                      _status = null;
                      _page = 1;
                    }),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    tooltip: 'Reset filters',
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.only(left: 8),
                    constraints: const BoxConstraints(),
                  ),
                const Spacer(),
                Flexible(
                  child: Text(
                    '${_visibleRecords.length} quarantine record${_visibleRecords.length == 1 ? '' : 's'} found',
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.mutedText,
                      fontSize: 12,
                    ),
                  ),
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
      labelStyle: const TextStyle(color: AppColors.mutedText, fontSize: 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      enabledBorder: _quarantineFieldBorder,
      focusedBorder: _quarantineFieldBorder.copyWith(
        borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
      ),
    ),
    style: const TextStyle(color: AppColors.strongText, fontSize: 13),
    dropdownColor: AppColors.surface,
    items: [
      DropdownMenuItem<String?>(value: null, child: Text(label)),
      ...values.map(
        (item) => DropdownMenuItem<String?>(value: item, child: Text(item)),
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
            style: const TextStyle(color: AppColors.errorText),
          ),
        ),
        TextButton(onPressed: _load, child: const Text('Retry')),
      ],
    ),
  );

  Widget _quarantineTable(List<QuarantineRecord> records) => LayoutBuilder(
    builder: (context, constraints) => constraints.maxWidth < 700
        ? _quarantineCards(records)
        : Container(
          clipBehavior: Clip.antiAlias,
          decoration: _quarantineDecoration,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Inventory Rolls')),
                  DataColumn(label: Text('Severity')),
                  DataColumn(label: Text('Reason')),
                  DataColumn(label: Text('Created')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Released')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: records
                    .map(
                      (record) => DataRow(
                        cells: [
                          DataCell(Text(record.inventoryRollId)),
                          DataCell(
                            _QuarantineBadge(
                              label: _severityFor(record),
                              type: _QuarantineBadgeType.severity,
                            ),
                          ),
                          DataCell(
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 220),
                              child: Text(
                                record.reason,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          DataCell(Text(_formatDate(record.createdAt))),
                          DataCell(
                            _QuarantineBadge(
                              label: record.status,
                              type: _QuarantineBadgeType.status,
                            ),
                          ),
                          DataCell(
                            Text(
                              record.releasedAt == null
                                  ? 'Not released'
                                  : _formatDate(record.releasedAt!),
                            ),
                          ),
                          DataCell(
                            IconButton(
                              onPressed: () => _open(record),
                              icon: const Icon(Icons.visibility_outlined),
                              tooltip: 'View',
                            ),
                          ),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
  );

  Widget _quarantineCards(List<QuarantineRecord> records) => Column(
    children: [
      for (final record in records) ...[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 15, 12, 8),
          decoration: _quarantineDecoration,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.inventory_2_outlined,
                    color: AppColors.primaryLight,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      record.inventoryRollId,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.strongText,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              Divider(height: 1, color: AppColors.border.withValues(alpha: 0.7)),
              const SizedBox(height: 5),
              _quarantineField(
                'Severity',
                _QuarantineBadge(
                  label: _severityFor(record),
                  type: _QuarantineBadgeType.severity,
                ),
              ),
              _quarantineField(
                'Reason',
                Text(
                  record.reason,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _quarantineField('Created', Text(_formatDate(record.createdAt))),
              _quarantineField(
                'Status',
                _QuarantineBadge(
                  label: record.status,
                  type: _QuarantineBadgeType.status,
                ),
              ),
              _quarantineField(
                'Released',
                Text(
                  record.releasedAt == null
                      ? 'Not released'
                      : _formatDate(record.releasedAt!),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _open(record),
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  label: const Text('View'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primaryLight,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
    ],
  );

  Widget _quarantineField(String label, Widget value) => Padding(
    padding: const EdgeInsets.only(top: 5, bottom: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 88,
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.mutedText,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: DefaultTextStyle(
            style: const TextStyle(
              color: AppColors.strongText,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            child: value,
          ),
        ),
      ],
    ),
  );
}

enum _QuarantineBadgeType { severity, status }

class _QuarantineBadge extends StatelessWidget {
  const _QuarantineBadge({required this.label, required this.type});

  final String label;
  final _QuarantineBadgeType type;

  @override
  Widget build(BuildContext context) {
    final lower = label.toLowerCase();
    final color = type == _QuarantineBadgeType.status
        ? AppColors.primaryLight
        : lower == 'high' || lower == 'critical'
        ? AppColors.error
        : lower == 'low'
        ? const Color(0xFF67E8F9)
        : AppColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.25,
        ),
      ),
    );
  }
}

final _quarantineFieldBorder = OutlineInputBorder(
  borderRadius: BorderRadius.circular(12),
  borderSide: const BorderSide(color: Color(0xFF2A3958), width: 1.2),
);

final _quarantineDecoration = BoxDecoration(
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

enum _QuarantineSort { newest, oldest, batch, severity, status }

extension on _QuarantineSort {
  String get label => switch (this) {
    _QuarantineSort.newest => 'Newest first',
    _QuarantineSort.oldest => 'Oldest first',
    _QuarantineSort.batch => 'Batch A-Z',
    _QuarantineSort.severity => 'Severity A-Z',
    _QuarantineSort.status => 'Status A-Z',
  };
}

class _QuarantineFilters {
  const _QuarantineFilters({this.severity, this.status});

  final String? severity;
  final String? status;
}

class _QuarantineFilterSheet extends StatefulWidget {
  const _QuarantineFilterSheet({required this.initial});

  final _QuarantineFilters initial;

  @override
  State<_QuarantineFilterSheet> createState() => _QuarantineFilterSheetState();
}

class _QuarantineFilterSheetState extends State<_QuarantineFilterSheet> {
  late String? _severity = widget.initial.severity;
  late String? _status = widget.initial.status;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Filter quarantine',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          _dropdown('Severity', _severity, const [
            'LOW',
            'MEDIUM',
            'HIGH',
            'Critical',
          ], (value) => setState(() => _severity = value)),
          _dropdown('Status', _status, const [
            'Active',
            'Released',
          ], (value) => setState(() => _status = value)),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              _QuarantineFilters(severity: _severity, status: _status),
            ),
            child: const Text('Apply filters'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, const _QuarantineFilters()),
            child: const Text('Clear filters'),
          ),
        ],
      ),
    ),
  );

  Widget _dropdown(
    String label,
    String? value,
    List<String> values,
    ValueChanged<String?> onChanged,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: DropdownButtonFormField<String?>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: [
        const DropdownMenuItem<String?>(value: null, child: Text('All')),
        ...values.map(
          (item) => DropdownMenuItem<String?>(value: item, child: Text(item)),
        ),
      ],
      onChanged: onChanged,
    ),
  );
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${local.year}-${twoDigits(local.month)}-${twoDigits(local.day)} ${twoDigits(local.hour)}:${twoDigits(local.minute)}';
}

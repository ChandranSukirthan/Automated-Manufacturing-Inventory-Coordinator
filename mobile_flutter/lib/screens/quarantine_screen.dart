import 'package:flutter/material.dart';

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
  List<QuarantineRecord>? _records;
  List<DefectReport> _defects = [];
  String? _error;
  String _query = '';
  String? _severity;
  String? _status;
  _QuarantineSort _sort = _QuarantineSort.newest;

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
    records.sort((left, right) => switch (_sort) {
      _QuarantineSort.newest => right.createdAt.compareTo(left.createdAt),
      _QuarantineSort.oldest => left.createdAt.compareTo(right.createdAt),
      _QuarantineSort.batch => left.batchId.compareTo(right.batchId),
      _QuarantineSort.status => left.status.compareTo(right.status),
      _QuarantineSort.severity => _severityFor(left).compareTo(_severityFor(right)),
    });
    return records;
  }

  Future<void> _showFilters() async {
    final result = await showModalBottomSheet<_QuarantineFilters>(
      context: context,
      builder: (_) => _QuarantineFilterSheet(
        initial: _QuarantineFilters(severity: _severity, status: _status),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _severity = result.severity;
      _status = result.status;
    });
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
    if (result != null && mounted) setState(() => _sort = result);
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quarantine'),
        actions: [
          IconButton(onPressed: _showSort, icon: const Icon(Icons.sort)),
          IconButton(
            onPressed: _showFilters,
            icon: Badge(
              isLabelVisible: _severity != null || _status != null,
              child: const Icon(Icons.tune),
            ),
          ),
        ],
      ),
      body: _error != null && _records == null
          ? StateMessage(message: _error!, icon: Icons.cloud_off, action: _load)
          : _records == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  TextField(
                    onChanged: (value) => setState(() => _query = value),
                    decoration: InputDecoration(
                      hintText: 'Search batch, inventory, reason...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () => setState(() => _query = ''),
                              icon: const Icon(Icons.clear),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('${records.length} result${records.length == 1 ? '' : 's'} · ${_sort.label}'),
                  const SizedBox(height: 8),
                  if (records.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 120),
                      child: StateMessage(
                        message: 'No quarantine records match these filters.',
                        icon: Icons.inventory_2_outlined,
                      ),
                    )
                  else
                    ...records.map(
                      (record) => Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          onTap: () => _open(record),
                          title: Text(
                            record.batchId,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              '${record.inventoryRollId}\n${_severityFor(record)} · ${record.reason}\nCreated: ${_formatDate(record.createdAt)}${record.releasedAt == null ? '' : '\nReleased: ${_formatDate(record.releasedAt!)}'}',
                            ),
                          ),
                          isThreeLine: true,
                          trailing: StatusPill(record.status),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

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
          Text('Filter quarantine', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          _dropdown('Severity', _severity, const ['LOW', 'MEDIUM', 'HIGH', 'CRITICAL'], (value) => setState(() => _severity = value)),
          _dropdown('Status', _status, const ['Active', 'Released'], (value) => setState(() => _status = value)),
          FilledButton(
            onPressed: () => Navigator.pop(context, _QuarantineFilters(severity: _severity, status: _status)),
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
        ...values.map((item) => DropdownMenuItem<String?>(value: item, child: Text(item))),
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
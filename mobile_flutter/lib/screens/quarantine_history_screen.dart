import 'package:flutter/material.dart';

import '../models/quality_models.dart';
import '../services/api_client.dart';
import '../services/quality_service.dart';
import '../widgets/app_widgets.dart';
import 'quarantine_detail_screen.dart';

class QuarantineHistoryScreen extends StatefulWidget {
  const QuarantineHistoryScreen({required this.service, super.key});

  final QualityService service;

  @override
  State<QuarantineHistoryScreen> createState() => _QuarantineHistoryScreenState();
}

class _QuarantineHistoryScreenState extends State<QuarantineHistoryScreen> {
  List<QuarantineRecord>? _records;
  String? _error;
  String _query = '';
  _HistorySort _sort = _HistorySort.newest;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final records = await widget.service.getQuarantines();
      if (mounted) {
        setState(() {
          _records = records.where((record) => record.status == 'Released').toList();
        });
      }
    } on ApiException catch (exception) {
      if (mounted) setState(() => _error = exception.message);
    }
  }

  List<QuarantineRecord> get _visibleRecords {
    final query = _query.trim().toLowerCase();
    final records = (_records ?? []).where((record) {
      final text = [
        record.inventoryRollId,
        record.batchId,
        record.status,
        record.reason,
      ].join(' ').toLowerCase();
      return query.isEmpty || text.contains(query);
    }).toList();
    records.sort((left, right) => switch (_sort) {
      _HistorySort.newest => (right.releasedAt ?? right.createdAt)
          .compareTo(left.releasedAt ?? left.createdAt),
      _HistorySort.oldest => (left.releasedAt ?? left.createdAt)
          .compareTo(right.releasedAt ?? right.createdAt),
      _HistorySort.batch => left.batchId.compareTo(right.batchId),
      _HistorySort.inventory => left.inventoryRollId.compareTo(right.inventoryRollId),
    });
    return records;
  }

  Future<void> _showSort() async {
    final result = await showModalBottomSheet<_HistorySort>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Sort quarantine history')),
            ..._HistorySort.values.map(
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
    if (_error != null && _records == null) {
      return StateMessage(message: _error!, icon: Icons.cloud_off, action: _load);
    }
    if (_records == null) return const Center(child: CircularProgressIndicator());
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quarantine history'),
        actions: [IconButton(onPressed: _showSort, icon: const Icon(Icons.sort))],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            TextField(
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: 'Search inventory, batch, reason...',
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
                  message: 'No released quarantine history found.',
                  icon: Icons.history,
                ),
              )
            else
              ...records.map(
                (record) => Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    onTap: () => _open(record),
                    title: Text(record.inventoryRollId, style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text(
                      'Batch: ${record.batchId}\nStatus: ${record.status}\nReleased: ${_formatDate(record.releasedAt ?? record.createdAt)}\nReason: ${record.reason}',
                    ),
                    isThreeLine: true,
                    trailing: const StatusPill('Released'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

enum _HistorySort { newest, oldest, batch, inventory }

extension on _HistorySort {
  String get label => switch (this) {
    _HistorySort.newest => 'Newest first',
    _HistorySort.oldest => 'Oldest first',
    _HistorySort.batch => 'Batch A-Z',
    _HistorySort.inventory => 'Inventory A-Z',
  };
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${local.year}-${twoDigits(local.month)}-${twoDigits(local.day)} ${twoDigits(local.hour)}:${twoDigits(local.minute)}';
}
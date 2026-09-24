import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../models/quality_models.dart';
import '../services/api_client.dart';
import '../services/quality_service.dart';
import '../widgets/app_widgets.dart';
import 'quarantine_detail_screen.dart';

class QuarantineHistoryScreen extends StatefulWidget {
  const QuarantineHistoryScreen({
    required this.service,
    this.showPageChrome = true,
    super.key,
  });

  final QualityService service;
  final bool showPageChrome;

  @override
  State<QuarantineHistoryScreen> createState() =>
      _QuarantineHistoryScreenState();
}

class _QuarantineHistoryScreenState extends State<QuarantineHistoryScreen> {
  static const _pageSize = 8;
  List<QuarantineRecord>? _records;
  String? _error;
  String _query = '';
  _HistorySort _sort = _HistorySort.newest;
  int _page = 1;

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
          _records = records
              .where((record) => record.status == 'Released')
              .toList();
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
    records.sort(
      (left, right) => switch (_sort) {
        _HistorySort.newest => (right.releasedAt ?? right.createdAt).compareTo(
          left.releasedAt ?? left.createdAt,
        ),
        _HistorySort.oldest => (left.releasedAt ?? left.createdAt).compareTo(
          right.releasedAt ?? right.createdAt,
        ),
        _HistorySort.batch => left.batchId.compareTo(right.batchId),
        _HistorySort.inventory => left.inventoryRollId.compareTo(
          right.inventoryRollId,
        ),
      },
    );
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
    if (_error != null && _records == null) {
      return StateMessage(
        message: _error!,
        icon: Icons.cloud_off,
        action: _load,
      );
    }
    if (_records == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Scaffold(
      appBar: widget.showPageChrome
          ? AppBar(
              title: const Text('Quarantine History'),
              actions: [
                IconButton(onPressed: _showSort, icon: const Icon(Icons.sort)),
              ],
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            if (widget.showPageChrome) ...[
              _pageHeader(),
              const SizedBox(height: 20),
            ],
            _searchToolbar(records.length),
            const SizedBox(height: 16),
            if (_error != null) _errorBanner(),
            if (records.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: StateMessage(
                  message: 'No released quarantine history found.',
                  icon: Icons.history,
                ),
              )
            else
              _historyTable(visibleRecords),
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
                  Text('Page ${_page.clamp(1, totalPages)} of $totalPages'),
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

  Widget _pageHeader() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Quality Assurance  •  Control Center',
        style: TextStyle(
          color: AppColors.primaryLight,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
      const SizedBox(height: 6),
      Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quarantine History',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 4),
                Text('Review previously released quality holds.'),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, size: 17),
            label: const Text('Back to Quarantine'),
          ),
        ],
      ),
    ],
  );

  Widget _searchToolbar(int count) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              onChanged: (value) => setState(() {
                _query = value;
                _page = 1;
              }),
              decoration: InputDecoration(
                hintText: 'Filter released inventory or reason...',
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
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              'Showing $count released audit record${count == 1 ? '' : 's'}',
            ),
          ),
        ],
      ),
    ),
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

  Widget _historyTable(List<QuarantineRecord> records) => LayoutBuilder(
    builder: (context, constraints) => constraints.maxWidth < 700
        ? _historyCards(records)
        : Card(
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Inventory')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Released At')),
                  DataColumn(label: Text('Disposition Reason')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: records
                    .map(
                      (record) => DataRow(
                        cells: [
                          DataCell(Text(record.inventoryRollId)),
                          DataCell(const StatusPill('Released')),
                          DataCell(
                            Text(
                              _formatDate(
                                record.releasedAt ?? record.createdAt,
                              ),
                            ),
                          ),
                          DataCell(
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 260),
                              child: Text(
                                record.reason,
                                overflow: TextOverflow.ellipsis,
                              ),
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

  Widget _historyCards(List<QuarantineRecord> records) => Column(
    children: [
      for (final record in records) ...[
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _historyField('Inventory', Text(record.inventoryRollId)),
                _historyField('Status', const StatusPill('Released')),
                _historyField(
                  'Released At',
                  Text(_formatDate(record.releasedAt ?? record.createdAt)),
                ),
                _historyField('Disposition', Text(record.reason)),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => _open(record),
                    icon: const Icon(Icons.visibility_outlined),
                    label: const Text('View'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    ],
  );

  Widget _historyField(String label, Widget value) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 92,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: value),
      ],
    ),
  );
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

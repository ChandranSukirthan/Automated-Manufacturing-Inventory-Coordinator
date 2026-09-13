import 'package:flutter/material.dart';

import '../models/quality_models.dart';
import '../services/api_client.dart';
import '../services/quality_service.dart';
import '../widgets/app_widgets.dart';
import 'defect_detail_screen.dart';
import 'defect_form_screen.dart';

class DefectsScreen extends StatefulWidget {
  const DefectsScreen({required this.service, super.key});

  final QualityService service;

  @override
  State<DefectsScreen> createState() => _DefectsScreenState();
}

class _DefectsScreenState extends State<DefectsScreen> {
  static const _pageSize = 8;
  static const _productTypes = [
    'BoxPouch',
    'BiscuitPackaging',
    'TeaBag',
    'Bag',
    'Can',
    'Bottle',
  ];
  static const _severities = ['LOW', 'MEDIUM', 'HIGH', 'CRITICAL'];
  static const _statuses = ['Open', 'InReview', 'Resolved', 'Closed'];

  List<DefectReport>? _defects;
  List<QuarantineRecord> _quarantines = [];
  String? _error;
  String _query = '';
  String? _productFilter;
  String? _severityFilter;
  String? _statusFilter;
  _DefectSort _sort = _DefectSort.createdNewest;
  int _visibleCount = _pageSize;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final results = await Future.wait([
        widget.service.getDefects(),
        widget.service.getQuarantines(),
      ]);
      if (mounted) {
        setState(() {
          _defects = results[0] as List<DefectReport>;
          _quarantines = results[1] as List<QuarantineRecord>;
          _visibleCount = _pageSize;
        });
      }
    } on ApiException catch (exception) {
      if (mounted) setState(() => _error = exception.message);
    }
  }

  Future<void> _create() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => DefectFormScreen(service: widget.service),
      ),
    );
    if (created == true) {
      _load();
    }
  }

  Future<void> _open(DefectReport defect) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            DefectDetailScreen(service: widget.service, defectId: defect.id),
      ),
    );
    if (mounted) _load();
  }

  List<DefectReport> get _filteredDefects {
    final query = _query.trim().toLowerCase();
    final filtered = (_defects ?? []).where((defect) {
      final affectedInventory = _inventoryFor(defect.id).join(' ');
      final searchable = [
        defect.batchId,
        defect.productType,
        defect.severity,
        defect.status,
        defect.reportedByUserId ?? '',
        defect.description,
        affectedInventory,
      ].join(' ').toLowerCase();
      return (query.isEmpty || searchable.contains(query)) &&
          (_productFilter == null || defect.productType == _productFilter) &&
          (_severityFilter == null || defect.severity == _severityFilter) &&
          (_statusFilter == null || defect.status == _statusFilter);
    }).toList();

    filtered.sort((left, right) {
      final result = switch (_sort) {
        _DefectSort.createdNewest => right.createdAt.compareTo(left.createdAt),
        _DefectSort.createdOldest => left.createdAt.compareTo(right.createdAt),
        _DefectSort.batchAscending => left.batchId.compareTo(right.batchId),
        _DefectSort.severityDescending => _severityRank(right.severity)
            .compareTo(_severityRank(left.severity)),
        _DefectSort.statusAscending => left.status.compareTo(right.status),
      };
      return result;
    });
    return filtered;
  }

  List<String> _inventoryFor(String defectId) => _quarantines
      .where((record) => record.defectReportId == defectId)
      .map((record) => record.inventoryRollId)
      .toList();

  int _severityRank(String severity) => switch (severity) {
    'CRITICAL' => 4,
    'HIGH' => 3,
    'MEDIUM' => 2,
    _ => 1,
  };

  Future<void> _showFilters() async {
    final result = await showModalBottomSheet<_DefectFilters>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _DefectFilterSheet(
        productTypes: _productTypes,
        severities: _severities,
        statuses: _statuses,
        initial: _DefectFilters(
          product: _productFilter,
          severity: _severityFilter,
          status: _statusFilter,
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _productFilter = result.product;
      _severityFilter = result.severity;
      _statusFilter = result.status;
      _visibleCount = _pageSize;
    });
  }

  Future<void> _showSortMenu() async {
    final selected = await showModalBottomSheet<_DefectSort>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text('Sort defects'),
              subtitle: Text('Choose how defect reports are ordered'),
            ),
            ..._DefectSort.values.map(
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
    if (selected == null || !mounted) return;
    setState(() {
      _sort = selected;
      _visibleCount = _pageSize;
    });
  }

  void _clearFilters() => setState(() {
    _query = '';
    _productFilter = null;
    _severityFilter = null;
    _statusFilter = null;
    _visibleCount = _pageSize;
  });

  Future<void> _delete(DefectReport defect) async {
    try {
      await widget.service.deleteDefect(defect.id);
      if (mounted) _load();
    } on ApiException catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(exception.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredDefects;
    final visible = filtered.take(_visibleCount).toList();
    final hasFilters = _query.trim().isNotEmpty ||
        _productFilter != null ||
        _severityFilter != null ||
        _statusFilter != null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Defect reports'),
        actions: [
          IconButton(
            onPressed: _showSortMenu,
            tooltip: 'Sort defects',
            icon: const Icon(Icons.sort),
          ),
          IconButton(
            onPressed: _showFilters,
            tooltip: 'Filter defects',
            icon: Badge(
              isLabelVisible: _productFilter != null ||
                  _severityFilter != null ||
                  _statusFilter != null,
              child: const Icon(Icons.tune),
            ),
          ),
        ],
      ),
      body: _error != null && _defects == null
          ? StateMessage(message: _error!, icon: Icons.cloud_off, action: _load)
          : _defects == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                children: [
                  TextField(
                    onChanged: (value) => setState(() {
                      _query = value;
                      _visibleCount = _pageSize;
                    }),
                    decoration: InputDecoration(
                      hintText: 'Search batch, description, inventory...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () => setState(() {
                                _query = '';
                                _visibleCount = _pageSize;
                              }),
                              icon: const Icon(Icons.clear),
                            ),
                    ),
                  ),
                  if (hasFilters) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (_productFilter != null)
                          _FilterChip(label: _productFilter!),
                        if (_severityFilter != null)
                          _FilterChip(label: _severityFilter!),
                        if (_statusFilter != null)
                          _FilterChip(label: _statusFilter!),
                        TextButton(
                          onPressed: _clearFilters,
                          child: const Text('Clear all'),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 14),
                  Text(
                    '${filtered.length} result${filtered.length == 1 ? '' : 's'} · ${_sort.label}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  if (visible.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 120),
                      child: StateMessage(
                        message: 'No defect reports match these filters.',
                        icon: Icons.fact_check_outlined,
                      ),
                    )
                  else
                    ...visible.map((defect) => _DefectCard(
                          defect: defect,
                          affectedInventory: _inventoryFor(defect.id),
                          onTap: () => _open(defect),
                          onDelete: () => _confirmDelete(defect),
                        )),
                  if (visible.length < filtered.length)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: OutlinedButton.icon(
                        onPressed: () => setState(
                          () => _visibleCount += _pageSize,
                        ),
                        icon: const Icon(Icons.expand_more),
                        label: Text(
                          'Load more (${filtered.length - visible.length} remaining)',
                        ),
                      ),
                    ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: const Text('Report defect'),
      ),
    );
  }

  Future<void> _confirmDelete(DefectReport defect) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete report?'),
        content: const Text(
          'This permanently removes the selected defect report.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await _delete(defect);
  }
}

enum _DefectSort {
  createdNewest,
  createdOldest,
  batchAscending,
  severityDescending,
  statusAscending,
}

extension on _DefectSort {
  String get label => switch (this) {
    _DefectSort.createdNewest => 'Newest first',
    _DefectSort.createdOldest => 'Oldest first',
    _DefectSort.batchAscending => 'Batch A-Z',
    _DefectSort.severityDescending => 'Severity high-low',
    _DefectSort.statusAscending => 'Status A-Z',
  };
}

class _DefectFilters {
  const _DefectFilters({this.product, this.severity, this.status});

  final String? product;
  final String? severity;
  final String? status;
}

class _DefectFilterSheet extends StatefulWidget {
  const _DefectFilterSheet({
    required this.productTypes,
    required this.severities,
    required this.statuses,
    required this.initial,
  });

  final List<String> productTypes;
  final List<String> severities;
  final List<String> statuses;
  final _DefectFilters initial;

  @override
  State<_DefectFilterSheet> createState() => _DefectFilterSheetState();
}

class _DefectFilterSheetState extends State<_DefectFilterSheet> {
  late String? _product = widget.initial.product;
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
          Text('Filter defects', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 14),
          _dropdown('Product type', _product, widget.productTypes, (value) {
            setState(() => _product = value);
          }),
          _dropdown('Severity', _severity, widget.severities, (value) {
            setState(() => _severity = value);
          }),
          _dropdown('Status', _status, widget.statuses, (value) {
            setState(() => _status = value);
          }),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              _DefectFilters(
                product: _product,
                severity: _severity,
                status: _status,
              ),
            ),
            child: const Text('Apply filters'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, const _DefectFilters()),
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

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Chip(
    avatar: const Icon(Icons.filter_alt_outlined, size: 16),
    label: Text(label),
  );
}

class _DefectCard extends StatelessWidget {
  const _DefectCard({
    required this.defect,
    required this.affectedInventory,
    required this.onTap,
    required this.onDelete,
  });

  final DefectReport defect;
  final List<String> affectedInventory;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    defect.batchId,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                  ),
                ),
                StatusPill(defect.severity),
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  onSelected: (value) {
                    if (value == 'view') onTap();
                    if (value == 'delete') onDelete();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'view', child: Text('View details')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(defect.productType, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 4),
            Text(
              defect.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _MetaPill(icon: Icons.flag_outlined, text: defect.status),
                _MetaPill(
                  icon: Icons.person_outline,
                  text: defect.reportedByUserId ?? 'Unavailable',
                ),
                _MetaPill(
                  icon: Icons.inventory_2_outlined,
                  text: affectedInventory.isEmpty
                      ? 'No affected inventory'
                      : affectedInventory.join(', '),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              _formatDate(defect.createdAt),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    ),
  );
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Chip(
    avatar: Icon(icon, size: 15),
    label: Text(text),
    visualDensity: VisualDensity.compact,
  );
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${local.year}-${twoDigits(local.month)}-${twoDigits(local.day)} '
      '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
}

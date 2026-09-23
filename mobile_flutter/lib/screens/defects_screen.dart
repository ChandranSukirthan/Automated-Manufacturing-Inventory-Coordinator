import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../models/quality_models.dart';
import '../services/api_client.dart';
import '../services/inventory_api_service.dart';
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

enum _DefectSort { date, inventory, severity, status }

class _DefectsScreenState extends State<DefectsScreen> {
  static const _pageSize = 8;
  static const _products = [
    'BoxPouch',
    'BiscuitPackaging',
    'TeaBag',
    'Bag',
    'Can',
    'Bottle',
  ];
  static const _severities = ['LOW', 'MEDIUM', 'HIGH', 'Critical'];
  static const _statuses = ['Open', 'InReview', 'Resolved', 'Closed'];

  List<DefectReport>? _defects;
  List<QuarantineRecord> _quarantines = [];
  List<InventoryRollModel> _rolls = [];
  String? _error;
  String _query = '';
  String? _product;
  String? _severity;
  String? _status;
  _DefectSort _sort = _DefectSort.date;
  bool _ascending = false;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _load();
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
                  'Defect Reports',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 4),
                Text('Monitor and review reported quality issues.'),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: _create,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Create Defect'),
          ),
        ],
      ),
    ],
  );

  Widget _filterToolbar() {
    final hasFilters =
        _product != null ||
        _severity != null ||
        _status != null ||
        _query.isNotEmpty;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            TextField(
              onChanged: (value) => setState(() {
                _query = value;
                _page = 1;
              }),
              decoration: InputDecoration(
                hintText: 'Search inventory roll, description...',
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
            _inlineDropdown(
              'All Product Types',
              _product,
              _products,
              (value) => setState(() {
                _product = value;
                _page = 1;
              }),
            ),
            const SizedBox(height: 8),
            _inlineDropdown(
              'All Severities',
              _severity,
              _severities,
              (value) => setState(() {
                _severity = value;
                _page = 1;
              }),
            ),
            const SizedBox(height: 8),
            _inlineDropdown(
              'All Statuses',
              _status,
              _statuses,
              (value) => setState(() {
                _status = value;
                _page = 1;
              }),
            ),
            const Divider(height: 24),
            Row(
              children: [
                const Text(
                  'Sort By:',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(_sort.label)),
                IconButton(
                  onPressed: _showSortMenu,
                  icon: const Icon(Icons.swap_vert),
                  tooltip: 'Change sort',
                ),
                if (hasFilters)
                  IconButton(
                    onPressed: () => setState(() {
                      _query = '';
                      _product = null;
                      _severity = null;
                      _status = null;
                      _page = 1;
                    }),
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Reset filters',
                  ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${_filtered.length} defect report${_filtered.length == 1 ? '' : 's'} found',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _inlineDropdown(
    String label,
    String? value,
    List<String> values,
    ValueChanged<String?> onChanged,
  ) => DropdownButtonFormField<String?>(
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(labelText: label),
    items: [
      DropdownMenuItem<String?>(value: null, child: Text(label)),
      ...values.map(
        (item) => DropdownMenuItem<String?>(value: item, child: Text(item)),
      ),
    ],
    onChanged: onChanged,
  );

  Future<void> _showSortMenu() async {
    final value = await showModalBottomSheet<_DefectSort>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: _DefectSort.values
              .map(
                (item) => ListTile(
                  title: Text(item.label),
                  trailing: item == _sort ? const Icon(Icons.check) : null,
                  onTap: () => Navigator.pop(context, item),
                ),
              )
              .toList(),
        ),
      ),
    );
    if (value != null && mounted) {
      setState(() {
        _ascending = _sort == value ? !_ascending : true;
        _sort = value;
        _page = 1;
      });
    }
  }

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

  Widget _defectTable(List<DefectReport> defects) => Card(
    clipBehavior: Clip.antiAlias,
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Inventory Roll')),
          DataColumn(label: Text('Product')),
          DataColumn(label: Text('Severity')),
          DataColumn(label: Text('Status')),
          DataColumn(label: Text('Reported By')),
          DataColumn(label: Text('Affected Inventory')),
          DataColumn(label: Text('Created')),
          DataColumn(label: Text('Actions')),
        ],
        rows: defects.map((defect) {
          final affected = _inventoryFor(defect);
          return DataRow(
            cells: [
              DataCell(Text(_inventoryLabel(defect))),
              DataCell(Text(defect.productType)),
              DataCell(StatusPill(defect.severity)),
              DataCell(StatusPill(defect.status)),
              DataCell(Text(defect.reportedByUserId ?? 'System')),
              DataCell(Text(affected.isEmpty ? '—' : affected.join(', '))),
              DataCell(Text(_formatDate(defect.createdAt))),
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () => _open(defect),
                      icon: const Icon(Icons.visibility_outlined),
                      tooltip: 'View',
                    ),
                    IconButton(
                      onPressed: () => _edit(defect),
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: 'Edit',
                    ),
                    IconButton(
                      onPressed: () => _delete(defect),
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Delete',
                    ),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    ),
  );

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final results = await Future.wait([
        widget.service.getDefects(),
        widget.service.getQuarantines(),
        InventoryApiService().fetchOwnedRolls(),
      ]);
      if (!mounted) return;
      setState(() {
        _defects = results[0] as List<DefectReport>;
        _quarantines = results[1] as List<QuarantineRecord>;
        _rolls = results[2] as List<InventoryRollModel>;
      });
    } on ApiException catch (exception) {
      if (mounted) setState(() => _error = exception.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Unable to load defect reports.');
    }
  }

  String _inventoryLabel(DefectReport defect) {
    final ids = _inventoryFor(defect);
    final roll = _rolls.where((item) => ids.contains(item.id)).firstOrNull;
    return roll?.rollIdentifier.isNotEmpty == true
        ? roll!.rollIdentifier
        : ids.firstOrNull ?? 'Unavailable';
  }

  List<String> _inventoryFor(DefectReport defect) =>
      defect.affectedInventory.isNotEmpty
      ? defect.affectedInventory
      : _quarantines
            .where((record) => record.defectReportId == defect.id)
            .map((record) => record.inventoryRollId)
            .toList();

  List<DefectReport> get _filtered {
    final query = _query.trim().toLowerCase();
    final values = (_defects ?? []).where((defect) {
      final text = [
        defect.batchId,
        _inventoryLabel(defect),
        defect.productType,
        defect.severity,
        defect.status,
        defect.description,
        ..._inventoryFor(defect),
      ].join(' ').toLowerCase();
      return (query.isEmpty || text.contains(query)) &&
          (_product == null || defect.productType == _product) &&
          (_severity == null || defect.severity == _severity) &&
          (_status == null || defect.status == _status);
    }).toList();
    values.sort((left, right) {
      final comparison = switch (_sort) {
        _DefectSort.date => left.createdAt.compareTo(right.createdAt),
        _DefectSort.inventory => _inventoryLabel(
          left,
        ).compareTo(_inventoryLabel(right)),
        _DefectSort.severity => left.severity.compareTo(right.severity),
        _DefectSort.status => left.status.compareTo(right.status),
      };
      return _ascending ? comparison : -comparison;
    });
    return values;
  }

  int get _pageCount => (_filtered.length / _pageSize).ceil().clamp(1, 999999);

  List<DefectReport> get _visible {
    final page = _page.clamp(1, _pageCount);
    final start = (page - 1) * _pageSize;
    return _filtered.skip(start).take(_pageSize).toList();
  }

  Future<void> _create() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => DefectFormScreen(service: widget.service),
      ),
    );
    if (created == true && mounted) _load();
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

  Future<void> _edit(DefectReport defect) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            DefectFormScreen(service: widget.service, defect: defect),
      ),
    );
    if (updated == true && mounted) _load();
  }

  Future<void> _delete(DefectReport defect) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete defect report?'),
        content: const Text(
          'This permanently removes the selected defect report.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
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

  Future<void> _filters() async {
    final result = await showModalBottomSheet<List<String?>>(
      context: context,
      builder: (context) => _DefectFilterSheet(
        product: _product,
        severity: _severity,
        status: _status,
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _product = result[0];
      _severity = result[1];
      _status = result[2];
      _page = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final defects = _visible;
    if (_error != null && _defects == null) {
      return Scaffold(
        body: StateMessage(
          message: _error!,
          icon: Icons.cloud_off,
          action: _load,
        ),
      );
    }
    if (_defects == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Defect Reports'),
        actions: [
          IconButton(
            onPressed: _create,
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Create defect',
          ),
          IconButton(
            onPressed: _filters,
            icon: Badge(
              isLabelVisible:
                  _product != null || _severity != null || _status != null,
              child: const Icon(Icons.tune),
            ),
            tooltip: 'Filters',
          ),
          PopupMenuButton<_DefectSort>(
            icon: const Icon(Icons.sort),
            onSelected: (value) => setState(() {
              if (_sort == value) {
                _ascending = !_ascending;
              } else {
                _sort = value;
                _ascending = true;
              }
              _page = 1;
            }),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: _DefectSort.date,
                child: Text('Sort by date'),
              ),
              PopupMenuItem(
                value: _DefectSort.inventory,
                child: Text('Sort by inventory roll'),
              ),
              PopupMenuItem(
                value: _DefectSort.severity,
                child: Text('Sort by severity'),
              ),
              PopupMenuItem(
                value: _DefectSort.status,
                child: Text('Sort by status'),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          children: [
            _pageHeader(),
            const SizedBox(height: 20),
            _filterToolbar(),
            const SizedBox(height: 16),
            if (_error != null) _errorBanner(),
            if (defects.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: StateMessage(
                  message: 'No defect reports match these filters.',
                  icon: Icons.fact_check_outlined,
                ),
              )
            else
              _defectTable(defects),
            if (_pageCount > 1) ...[
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
                  Text('Page ${_page.clamp(1, _pageCount)} of $_pageCount'),
                  IconButton(
                    onPressed: _page >= _pageCount
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
}

class _DefectFilterSheet extends StatefulWidget {
  const _DefectFilterSheet({this.product, this.severity, this.status});
  final String? product;
  final String? severity;
  final String? status;
  @override
  State<_DefectFilterSheet> createState() => _DefectFilterSheetState();
}

class _DefectFilterSheetState extends State<_DefectFilterSheet> {
  late String? product = widget.product;
  late String? severity = widget.severity;
  late String? status = widget.status;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String?>(
            initialValue: product,
            decoration: const InputDecoration(labelText: 'Product type'),
            items: [
              const DropdownMenuItem(value: null, child: Text('All')),
              ..._DefectsScreenState._products.map(
                (value) => DropdownMenuItem(value: value, child: Text(value)),
              ),
            ],
            onChanged: (value) => setState(() => product = value),
          ),
          DropdownButtonFormField<String?>(
            initialValue: severity,
            decoration: const InputDecoration(labelText: 'Severity'),
            items: [
              const DropdownMenuItem(value: null, child: Text('All')),
              ..._DefectsScreenState._severities.map(
                (value) => DropdownMenuItem(value: value, child: Text(value)),
              ),
            ],
            onChanged: (value) => setState(() => severity = value),
          ),
          DropdownButtonFormField<String?>(
            initialValue: status,
            decoration: const InputDecoration(labelText: 'Status'),
            items: [
              const DropdownMenuItem(value: null, child: Text('All')),
              ..._DefectsScreenState._statuses.map(
                (value) => DropdownMenuItem(value: value, child: Text(value)),
              ),
            ],
            onChanged: (value) => setState(() => status = value),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, [product, severity, status]),
            child: const Text('Apply filters'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, [null, null, null]),
            child: const Text('Reset filters'),
          ),
        ],
      ),
    ),
  );
}

extension on _DefectSort {
  String get label => switch (this) {
    _DefectSort.date => 'Date',
    _DefectSort.inventory => 'Inventory Roll',
    _DefectSort.severity => 'Severity',
    _DefectSort.status => 'Status',
  };
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  return '${months[local.month - 1]} ${local.day}, $hour:$minute ${local.hour >= 12 ? 'PM' : 'AM'}';
}

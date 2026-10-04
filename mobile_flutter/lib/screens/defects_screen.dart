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
  const DefectsScreen({
    required this.service,
    this.showAppBar = true,
    super.key,
  });

  final QualityService service;
  final bool showAppBar;

  @override
  State<DefectsScreen> createState() => _DefectsScreenState();
}

enum _DefectSort { date, inventory, severity, status }

class _DefectsScreenState extends State<DefectsScreen> {
  static const _pageSize = 8;
  static const _severities = ['LOW', 'MEDIUM', 'HIGH', 'Critical'];
  static const _statuses = ['Open', 'InReview', 'Resolved', 'Closed'];

  List<DefectReport>? _defects;
  List<QuarantineRecord> _quarantines = [];
  List<InventoryRollModel> _rolls = [];
  String? _error;
  String _query = '';
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

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final results = await Future.wait([
        widget.service.getDefects(),
        widget.service.getQuarantines().catchError((_) => <QuarantineRecord>[]),
        InventoryApiService().fetchOwnedRolls().catchError((_) => <InventoryRollModel>[]),
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
    final roll = _rolls.where((item) => ids.contains(item.rollIdentifier)).firstOrNull;
    return roll?.rollIdentifier.isNotEmpty == true
        ? roll!.rollIdentifier
        : ids.firstOrNull ?? (defect.skuCode.isEmpty ? 'Unavailable' : defect.skuCode);
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
        _inventoryLabel(defect),
        defect.skuCode,
        defect.severity,
        defect.status,
        defect.description,
        ..._inventoryFor(defect),
      ].join(' ').toLowerCase();
      return (query.isEmpty || text.contains(query)) &&
          (_severity == null ||
              defect.severity.toLowerCase() == _severity!.toLowerCase()) &&
          (_status == null ||
              defect.status.toLowerCase() == _status!.toLowerCase());
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
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFF1E293B)),
        ),
        title: const Text(
          'Delete Defect Report?',
          style: TextStyle(color: AppColors.strongText, fontSize: 16, fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'This action permanently deletes this defect record. Cannot be undone.',
          style: TextStyle(color: AppColors.secondaryText, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
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

  @override
  Widget build(BuildContext context) {
    final allDefects = _defects ?? [];
    final openDefects = allDefects
        .where((d) => ['open', 'inreview'].contains(d.status.toLowerCase()))
        .toList();
    final criticalHighCount = allDefects
        .where((d) => ['critical', 'high'].contains(d.severity.toLowerCase()))
        .length;
    final mediumCount = allDefects
        .where((d) => d.severity.toLowerCase() == 'medium')
        .length;
    final resolvedCount = allDefects
        .where((d) => ['resolved', 'closed'].contains(d.status.toLowerCase()))
        .length;

    final filtered = _filtered;
    final totalPages = (filtered.length / _pageSize).ceil().clamp(1, 999999);
    final visibleDefects = filtered
        .skip((_page - 1).clamp(0, totalPages - 1) * _pageSize)
        .take(_pageSize)
        .toList();

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
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text('Defect Reports'),
              actions: [
                IconButton(
                  onPressed: _create,
                  icon: const Icon(Icons.add_circle_outline),
                  tooltip: 'Create defect',
                ),
              ],
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
          children: [
            _pageHeader(),
            const SizedBox(height: 16),

            // Top 4 Metric Summary Cards
            _buildTopMetrics(
              openCount: openDefects.length,
              criticalHighCount: criticalHighCount,
              mediumCount: mediumCount,
              resolvedCount: resolvedCount,
            ),
            const SizedBox(height: 16),

            _filterToolbar(),
            const SizedBox(height: 16),

            if (_error != null) _errorBanner(),

            if (filtered.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 60),
                child: StateMessage(
                  message: 'No defect reports match these filters.',
                  icon: Icons.fact_check_outlined,
                ),
              )
            else
              _defectList(visibleDefects),

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
                  'Defect Reports',
                  style: TextStyle(
                    color: AppColors.strongText,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Track, investigate and manage manufacturing quality defects',
                  style: TextStyle(color: AppColors.mutedText, fontSize: 13),
                ),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: _create,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Log Defect'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    ],
  );

  Widget _buildTopMetrics({
    required int openCount,
    required int criticalHighCount,
    required int mediumCount,
    required int resolvedCount,
  }) => GridView.count(
    crossAxisCount: 2,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    crossAxisSpacing: 10,
    mainAxisSpacing: 10,
    childAspectRatio: 1.6,
    children: [
      _metricCard('TOTAL OPEN', '$openCount', AppColors.strongText, Icons.fact_check_outlined, 'Active investigation'),
      _metricCard('CRITICAL / HIGH', '$criticalHighCount', AppColors.error, Icons.warning_amber_rounded, 'Priority containment'),
      _metricCard('MEDIUM', '$mediumCount', const Color(0xFFFBBF24), Icons.layers_outlined, 'Standard inspection'),
      _metricCard('RESOLVED', '$resolvedCount', const Color(0xFF34D399), Icons.check_circle_outline, 'Cleared or closed'),
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
              hintText: 'Search SKU, roll, defect description...',
              hintStyle: const TextStyle(color: AppColors.mutedText, fontSize: 12),
              prefixIcon: const Icon(Icons.search, size: 18),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
              Expanded(
                child: Text(
                  '${_filtered.length} defect reports found',
                  style: const TextStyle(color: AppColors.mutedText, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PopupMenuButton<_DefectSort>(
                    tooltip: 'Sort by',
                    icon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _ascending ? Icons.arrow_upward : Icons.arrow_downward,
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
                        if (_sort == sort) {
                          _ascending = !_ascending;
                        } else {
                          _sort = sort;
                          _ascending = false;
                        }
                      });
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: _DefectSort.date,
                        child: Text('Date', style: TextStyle(fontSize: 12)),
                      ),
                      PopupMenuItem(
                        value: _DefectSort.severity,
                        child: Text('Severity', style: TextStyle(fontSize: 12)),
                      ),
                      PopupMenuItem(
                        value: _DefectSort.status,
                        child: Text('Status', style: TextStyle(fontSize: 12)),
                      ),
                      PopupMenuItem(
                        value: _DefectSort.inventory,
                        child: Text('Inventory', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                  if (hasFilters)
                    TextButton.icon(
                      onPressed: () => setState(() {
                        _query = '';
                        _severity = null;
                        _status = null;
                        _sort = _DefectSort.date;
                        _ascending = false;
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

  Widget _defectList(List<DefectReport> defects) => ListView.separated(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    itemCount: defects.length,
    separatorBuilder: (_, _) => const SizedBox(height: 10),
    itemBuilder: (context, index) {
      final d = defects[index];
      final shortId = d.id.length > 8 ? d.id.substring(0, 8) : d.id;
      final isCritical = d.severity.toLowerCase() == 'critical' || d.severity.toLowerCase() == 'high';

      return Container(
        padding: const EdgeInsets.all(14),
        decoration: _cardBoxDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '#$shortId',
                  style: const TextStyle(
                    color: AppColors.primaryLight,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111827),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF1F2937)),
                  ),
                  child: Text(
                    d.status,
                    style: const TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _inventoryLabel(d),
                    style: const TextStyle(
                      color: Color(0xFF67E8F9),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isCritical ? AppColors.error.withValues(alpha: 0.15) : const Color(0xFFFBBF24).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isCritical ? AppColors.error.withValues(alpha: 0.35) : const Color(0xFFFBBF24).withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    d.severity.toUpperCase(),
                    style: TextStyle(
                      color: isCritical ? AppColors.error : const Color(0xFFFBBF24),
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
              d.description.isNotEmpty ? d.description : '—',
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
                  _formatDate(d.createdAt),
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 10,
                    fontFamily: 'monospace',
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: () => _open(d),
                      icon: const Icon(Icons.visibility_outlined, size: 18),
                      color: const Color(0xFF67E8F9),
                      visualDensity: VisualDensity.compact,
                      tooltip: 'View Detail',
                    ),
                    IconButton(
                      onPressed: () => _edit(d),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      color: AppColors.primaryLight,
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Edit',
                    ),
                    IconButton(
                      onPressed: () => _delete(d),
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      color: AppColors.error,
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Delete',
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

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

enum _HistorySort { newest, oldest, batch, inventory }

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
              .where((record) => record.status.toLowerCase() == 'released')
              .toList();
        });
      }
    } on ApiException catch (exception) {
      if (mounted) setState(() => _error = exception.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Unable to load quarantine history.');
      }
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
              leading: BackButton(onPressed: () => Navigator.pop(context)),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
          children: [
            _pageHeader(),
            const SizedBox(height: 16),
            _searchToolbar(records.length),
            const SizedBox(height: 16),
            if (_error != null) _errorBanner(),
            if (records.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 60),
                child: StateMessage(
                  message: 'No released quarantine history records found.',
                  icon: Icons.history,
                ),
              )
            else
              _historyList(visibleRecords),
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
      const Text(
        'Quarantine History',
        style: TextStyle(
          color: AppColors.strongText,
          fontSize: 24,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
        ),
      ),
      const SizedBox(height: 4),
      const Text(
        'Authoritative audit ledger of previously released quality holds and dispositions',
        style: TextStyle(color: AppColors.mutedText, fontSize: 13),
      ),
    ],
  );

  Widget _searchToolbar(int count) => Container(
    padding: const EdgeInsets.all(14),
    decoration: _historyBoxDecoration(),
    child: Column(
      children: [
        TextField(
          onChanged: (value) => setState(() {
            _query = value;
            _page = 1;
          }),
          style: const TextStyle(color: AppColors.strongText, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Search roll, batch, disposition reason...',
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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Showing $count released records',
                style: const TextStyle(color: AppColors.mutedText, fontSize: 11),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<_HistorySort>(
              icon: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.sort, size: 16, color: AppColors.primaryLight),
                  SizedBox(width: 4),
                  Text(
                    'Sort',
                    style: TextStyle(color: AppColors.primaryLight, fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              onSelected: (val) => setState(() {
                _sort = val;
                _page = 1;
              }),
              itemBuilder: (_) => const [
                PopupMenuItem(value: _HistorySort.newest, child: Text('Newest first')),
                PopupMenuItem(value: _HistorySort.oldest, child: Text('Oldest first')),
                PopupMenuItem(value: _HistorySort.batch, child: Text('Batch A-Z')),
                PopupMenuItem(value: _HistorySort.inventory, child: Text('Roll A-Z')),
              ],
            ),
          ],
        ),
      ],
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
            style: const TextStyle(color: AppColors.errorText, fontSize: 12),
          ),
        ),
        TextButton(onPressed: _load, child: const Text('Retry')),
      ],
    ),
  );

  Widget _historyList(List<QuarantineRecord> records) => ListView.separated(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    itemCount: records.length,
    separatorBuilder: (_, _) => const SizedBox(height: 10),
    itemBuilder: (context, index) {
      final r = records[index];
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: _historyBoxDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.history_rounded, color: Color(0xFF67E8F9), size: 16),
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
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.35)),
                  ),
                  child: const Text(
                    'RELEASED',
                    style: TextStyle(
                      color: Color(0xFF34D399),
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
              'Released: ${_formatDate(r.releasedAt ?? r.createdAt)}',
              style: const TextStyle(color: AppColors.mutedText, fontSize: 11, fontFamily: 'monospace'),
            ),
            const SizedBox(height: 4),
            Text(
              r.reason,
              style: const TextStyle(color: AppColors.secondaryText, fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton(
                onPressed: () => _open(r),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryLight,
                  side: const BorderSide(color: Color(0xFF1E293B)),
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  textStyle: const TextStyle(fontSize: 11),
                ),
                child: const Text('View Details'),
              ),
            ),
          ],
        ),
      );
    },
  );

  BoxDecoration _historyBoxDecoration() => BoxDecoration(
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

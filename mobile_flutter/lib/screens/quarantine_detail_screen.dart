import 'package:flutter/material.dart';

import '../models/quality_models.dart';
import '../services/api_client.dart';
import '../services/quality_service.dart';
import '../widgets/app_widgets.dart';

class QuarantineDetailScreen extends StatefulWidget {
  const QuarantineDetailScreen({
    required this.service,
    required this.quarantineId,
    super.key,
  });

  final QualityService service;
  final String quarantineId;

  @override
  State<QuarantineDetailScreen> createState() => _QuarantineDetailScreenState();
}

class _QuarantineDetailScreenState extends State<QuarantineDetailScreen> {
  QuarantineRecord? _record;
  String? _error;
  bool _loading = true;
  bool _releasing = false;
  BatchDetails? _batch;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final record = await widget.service.getQuarantine(widget.quarantineId);
      final batch = await widget.service.getBatch(record.batchId);
      if (mounted) {
        setState(() {
          _record = record;
          _batch = batch;
        });
      }
    } on ApiException catch (exception) {
      if (mounted) setState(() => _error = exception.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _release() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Release quarantine?'),
        content: const Text(
          'Release this quarantine and return the inventory to normal business handling?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Release'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _releasing = true;
      _error = null;
    });
    try {
      final record = await widget.service.releaseQuarantine(
        widget.quarantineId,
      );
      final batch = await widget.service.getBatch(record.batchId);
      if (mounted) {
        setState(() {
          _record = record;
          _batch = batch;
        });
      }
    } on ApiException catch (exception) {
      if (mounted) setState(() => _error = exception.message);
    } finally {
      if (mounted) setState(() => _releasing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _record == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null && _record == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Quarantine details')),
        body: StateMessage(
          message: _error!,
          icon: Icons.cloud_off,
          action: _load,
        ),
      );
    }
    final record = _record;
    if (record == null) {
      return const Scaffold(
        body: StateMessage(
          message: 'Quarantine not found.',
          icon: Icons.search_off,
        ),
      );
    }
    final active = record.status == 'Active';

    return Scaffold(
      appBar: AppBar(title: const Text('Quarantine details')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            _Info(label: 'Defect', value: record.defectReportId),
            _Info(label: 'Batch', value: record.batchId),
            _Info(label: 'Inventory', value: record.inventoryRollId),
            _Info(
              label: 'Inventory status',
              value: _batch?.inventoryRolls
                      .firstWhere(
                        (roll) => roll.id == record.inventoryRollId,
                        orElse: () => const InventoryRoll(
                          id: '',
                          batchId: '',
                          status: 'Unknown',
                        ),
                      )
                      .status ??
                  'Unknown',
            ),
            Row(
              children: [
                Expanded(
                  child: _Info(label: 'Status', value: record.status),
                ),
                Expanded(
                  child: _Info(
                    label: 'Created',
                    value: record.createdAt.toLocal().toString(),
                  ),
                ),
              ],
            ),
            _Info(
              label: 'Released',
              value: record.releasedAt?.toLocal().toString() ?? 'Not released',
            ),
            Text('Reason', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(record.reason),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (active) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _releasing ? null : _release,
                icon: _releasing
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: Text(_releasing ? 'Releasing...' : 'Release quarantine'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

import 'package:flutter/material.dart';

import '../models/quality_models.dart';
import '../services/api_client.dart';
import '../services/quality_service.dart';
import '../widgets/app_widgets.dart';
import 'defect_form_screen.dart';
import 'quarantine_detail_screen.dart';

class DefectDetailScreen extends StatefulWidget {
  const DefectDetailScreen({
    required this.service,
    required this.defectId,
    super.key,
  });

  final QualityService service;
  final String defectId;

  @override
  State<DefectDetailScreen> createState() => _DefectDetailScreenState();
}

class _DefectDetailScreenState extends State<DefectDetailScreen> {
  DefectReport? _defect;
  String? _error;
  bool _loading = true;
  bool _quarantining = false;
  final _inventoryRollId = TextEditingController();
  final _reason = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _inventoryRollId.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final defect = await widget.service.getDefect(widget.defectId);
      if (mounted) setState(() => _defect = defect);
    } on ApiException catch (exception) {
      if (mounted) setState(() => _error = exception.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit() async {
    final defect = _defect;
    if (defect == null) return;
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            DefectFormScreen(service: widget.service, defect: defect),
      ),
    );
    if (updated == true) _load();
  }

  Future<void> _quarantine() async {
    if (_defect == null || _reason.text.trim().isEmpty) {
      setState(() => _error = 'A quarantine reason is required.');
      return;
    }
    setState(() {
      _quarantining = true;
      _error = null;
    });
    try {
      final record = await widget.service.quarantineDefect(
        widget.defectId,
        _reason.text.trim(),
        _inventoryRollId.text.trim(),
      );
      if (mounted) {
        await Navigator.push<void>(
          context,
          MaterialPageRoute(
            builder: (_) => QuarantineDetailScreen(
              service: widget.service,
              quarantineId: record.id,
            ),
          ),
        );
      }
    } on ApiException catch (exception) {
      if (mounted) setState(() => _error = exception.message);
    } finally {
      if (mounted) setState(() => _quarantining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _defect == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null && _defect == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Defect detail')),
        body: StateMessage(
          message: _error!,
          icon: Icons.cloud_off,
          action: _load,
        ),
      );
    }
    final defect = _defect;
    if (defect == null) {
      return const Scaffold(
        body: StateMessage(
          message: 'Defect not found.',
          icon: Icons.search_off,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Defect detail'),
        actions: [
          IconButton(onPressed: _edit, icon: const Icon(Icons.edit_outlined)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            _DetailRow(label: 'Batch ID', value: defect.batchId),
            _DetailRow(label: 'Product type', value: defect.productType),
            Row(
              children: [
                Expanded(
                  child: _DetailRow(label: 'Severity', value: defect.severity),
                ),
                Expanded(
                  child: _DetailRow(label: 'Status', value: defect.status),
                ),
              ],
            ),
            _DetailRow(
              label: 'Created',
              value: defect.createdAt.toLocal().toString(),
            ),
            const SizedBox(height: 12),
            Text('Description', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(defect.description),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Quarantine inventory',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Leave the inventory ID blank to use this defect\'s batch ID.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _inventoryRollId,
              decoration: const InputDecoration(
                labelText: 'Inventory roll ID (optional)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reason,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Reason for quarantine',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _quarantining ? null : _quarantine,
              icon: _quarantining
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.pause_circle_outline),
              label: const Text('Quarantine inventory'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

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

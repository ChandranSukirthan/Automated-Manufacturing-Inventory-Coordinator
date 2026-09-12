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
  State<QuarantineHistoryScreen> createState() =>
      _QuarantineHistoryScreenState();
}

class _QuarantineHistoryScreenState extends State<QuarantineHistoryScreen> {
  List<QuarantineRecord>? _records;
  String? _error;

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
        setState(
          () => _records = records
              .where((record) => record.status == 'Released')
              .toList(),
        );
      }
    } on ApiException catch (exception) {
      if (mounted) setState(() => _error = exception.message);
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
    return RefreshIndicator(
      onRefresh: _load,
      child: _records!.isEmpty
          ? ListView(
              children: const [
                SizedBox(height: 180),
                StateMessage(
                  message: 'No released quarantine history found.',
                  icon: Icons.history,
                ),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: _records!.length,
              itemBuilder: (context, index) {
                final record = _records![index];
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    title: Text(
                      record.batchId,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${record.inventoryRollId}\n${record.reason}',
                    ),
                    isThreeLine: true,
                    trailing: const StatusPill('Released'),
                    onTap: () => _open(record),
                  ),
                );
              },
            ),
    );
  }
}

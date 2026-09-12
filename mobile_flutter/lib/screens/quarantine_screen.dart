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
      if (mounted) setState(() => _records = records);
    } on ApiException catch (exception) {
      if (mounted) setState(() => _error = exception.message);
    }
  }

  Future<void> _release(QuarantineRecord record) async {
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
  Widget build(BuildContext context) => Scaffold(
    body: _error != null && _records == null
        ? StateMessage(message: _error!, icon: Icons.cloud_off, action: _load)
        : _records == null
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _load,
            child: _records!.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 180),
                      StateMessage(
                        message: 'No quarantine records yet.',
                        icon: Icons.inventory_2_outlined,
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: _records!.length,
                    itemBuilder: (context, index) {
                      final record = _records![index];
                      final active = record.status.toLowerCase() == 'active';
                      return Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          title: Text(
                            record.batchId,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(record.reason),
                          ),
                          trailing: active
                              ? FilledButton.tonal(
                                  onPressed: () => _release(record),
                                  child: const Text('View'),
                                )
                              : const StatusPill('Released'),
                          onTap: () => _release(record),
                        ),
                      );
                    },
                  ),
          ),
  );
}

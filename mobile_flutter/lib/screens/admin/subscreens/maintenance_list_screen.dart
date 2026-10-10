import '../../../utils/locale.dart';
import 'package:flutter/material.dart';
import '../../../models/admin/machine_model.dart';
import '../../../services/admin/admin_api_service.dart';
import '../../../widgets/admin/admin_card.dart';
import '../../../widgets/admin/status_chip.dart';

class MaintenanceListScreen extends StatefulWidget {
  final MachineModel machine;
  final AdminApiService service;

  const MaintenanceListScreen({
    required this.machine,
    required this.service,
    super.key,
  });

  @override
  State<MaintenanceListScreen> createState() => _MaintenanceListScreenState();
}

class _MaintenanceListScreenState extends State<MaintenanceListScreen> {
  List<MaintenanceLogModel> _logs = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }

  Future<void> _fetchLogs() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final logs = await widget.service.getMaintenanceLogs(widget.machine.id);
      if (mounted) {
        setState(() {
          _logs = logs;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load maintenance records: $e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _createLog() async {
    final description = TextEditingController();
    final technician = TextEditingController();
    final form = GlobalKey<FormState>();
    int type = 0;
    bool saving = false;
    String? error;
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: const Text('Record maintenance'),
          content: SingleChildScrollView(
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.machine.name),
                  TextFormField(
                    controller: description,
                    maxLength: 1000,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Description'),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  TextFormField(
                    controller: technician,
                    maxLength: 150,
                    decoration: const InputDecoration(
                      labelText: 'Performed by',
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  DropdownButtonFormField<int>(
                    initialValue: type,
                    decoration: const InputDecoration(
                      labelText: 'Maintenance type',
                    ),
                    items: const [
                      DropdownMenuItem(value: 0, child: Text('Scheduled')),
                      DropdownMenuItem(value: 1, child: Text('Emergency')),
                      DropdownMenuItem(value: 2, child: Text('Preventive')),
                    ],
                    onChanged: saving ? null : (v) => update(() => type = v!),
                  ),
                  if (error != null)
                    Text(
                      error!,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!form.currentState!.validate()) return;
                      update(() {
                        saving = true;
                        error = null;
                      });
                      try {
                        await widget.service.createMaintenanceLog(
                          widget.machine.id,
                          description.text.trim(),
                          technician.text.trim(),
                          type,
                        );
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      } catch (e) {
                        if (ctx.mounted)
                          update(() {
                            saving = false;
                            error = e.toString();
                          });
                      }
                    },
              child: Text(saving ? 'Saving...' : 'Save'),
            ),
          ],
        ),
      ),
    );
    // Dialog teardown finishes before its field controllers are released.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    description.dispose();
    technician.dispose();
    if (saved == true && mounted) await _fetchLogs();
  }

  Future<void> _deleteLog(MaintenanceLogModel log) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete maintenance record?'),
        content: Text(log.description),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.service.deleteMaintenanceLog(log.id);
      if (mounted) await _fetchLogs();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not delete record: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        title: Text(
          '${widget.machine.name} Logs',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createLog,
        icon: const Icon(Icons.add),
        label: const Text('Record maintenance'),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF06B6D4)),
            )
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Color(0xFFEF4444),
                      size: 40,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: const TextStyle(color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _fetchLogs,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF06B6D4),
                      ),
                      child: const Text(
                        'Retry',
                        style: TextStyle(color: Color(0xFF0B0F19)),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : _logs.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.assignment_turned_in_outlined,
                    color: Colors.white.withValues(alpha: 0.3),
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No service history recorded for this unit.',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _fetchLogs,
              color: const Color(0xFF06B6D4),
              backgroundColor: const Color(0xFF0F172A),
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _logs.length,
                itemBuilder: (context, index) {
                  final log = _logs[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: AdminCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  log.description,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              StatusChip(status: log.status),
                              IconButton(
                                tooltip: 'Delete record',
                                onPressed: () => _deleteLog(log),
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'By: ${log.performedBy ?? "Technician"}',
                                style: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                log.performedAt
                                    .toUtc()
                                    .add(const Duration(hours: 5, minutes: 30))
                                    .toString()
                                    .split(' ')[0],
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          if (log.cost > 0) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Cost: ${formatMoney(log.cost)}',
                              style: const TextStyle(
                                color: Color(0xFF10B981),
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

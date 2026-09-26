import 'package:flutter/material.dart';
import '../../../models/admin/machine_model.dart';
import '../../../services/admin/admin_api_service.dart';
import '../../../widgets/admin/admin_card.dart';
import '../../../widgets/admin/status_chip.dart';
import '../../../widgets/admin/metric_gauge.dart';
import '../../../widgets/admin/machine_form_dialog.dart';
import 'maintenance_list_screen.dart';

class MachineDetailScreen extends StatefulWidget {
  final MachineModel machine;
  final AdminApiService service;

  const MachineDetailScreen({
    required this.machine,
    required this.service,
    super.key,
  });

  @override
  State<MachineDetailScreen> createState() => _MachineDetailScreenState();
}

class _MachineDetailScreenState extends State<MachineDetailScreen> {
  late MachineModel _currentMachine;
  bool _calculating = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _currentMachine = widget.machine;
  }

  Future<void> _runCalculateMaintenance() async {
    setState(() => _calculating = true);
    try {
      final res = await widget.service.calculateMaintenance(_currentMachine.id);
      if (mounted) {
        // Refresh machine details
        final updated = await widget.service.getMachineById(_currentMachine.id);
        if (!mounted) return;
        setState(() {
          _currentMachine = updated;
          _calculating = false;
          _message = res['message']?.toString() ?? 'Maintenance calculation updated successfully!';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_message!),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _calculating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to calculate maintenance: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  Future<void> _editMachine() async {
    final updated = await showDialog<MachineModel>(
      context: context,
      builder: (_) => MachineFormDialog(
        machine: _currentMachine,
        service: widget.service,
      ),
    );

    if (updated != null && mounted) {
      setState(() {
        _currentMachine = updated;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${updated.name} updated successfully!'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    }
  }

  Future<void> _deleteMachine() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Delete Equipment', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to delete "${_currentMachine.name}"? This action cannot be undone.',
          style: const TextStyle(color: Color(0xFFCBD5E1)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await widget.service.deleteMachine(_currentMachine.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${_currentMachine.name} deleted successfully!'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
          Navigator.of(context).pop(true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete machine: $e'),
              backgroundColor: const Color(0xFFEF4444),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        title: Text(
          _currentMachine.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded, color: Color(0xFF06B6D4)),
            tooltip: 'Maintenance History',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MaintenanceListScreen(
                    machine: _currentMachine,
                    service: widget.service,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Colors.white70),
            tooltip: 'Edit Equipment',
            onPressed: _editMachine,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
            tooltip: 'Delete Equipment',
            onPressed: _deleteMachine,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AdminCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _currentMachine.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    StatusChip(status: _currentMachine.status),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Location: ${_currentMachine.location}',
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                ),
                const SizedBox(height: 16),
                MetricGauge(
                  label: 'Uptime vs Service Interval',
                  value: _currentMachine.uptimeHours,
                  maxValue: _currentMachine.maintenanceIntervalHours > 0
                      ? _currentMachine.maintenanceIntervalHours
                      : 100,
                  unit: 'h / ${_currentMachine.maintenanceIntervalHours.toInt()}h',
                ),
                const SizedBox(height: 12),
                if (_currentMachine.isMaintenanceDue)
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF78350F).withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFF59E0B)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Maintenance overdue or required based on runtime limits.',
                            style: TextStyle(color: Color(0xFFFDE68A), fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Telemetry Specs Card
          AdminCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Machine Telemetry',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 12),
                _specRow('Machine ID', _currentMachine.id),
                _specRow('Uptime Total', '${_currentMachine.uptimeHours.toStringAsFixed(1)} hours'),
                _specRow('Remaining to Service', '${_currentMachine.remainingHours.toStringAsFixed(1)} hours'),
                _specRow('Service Cycle Interval', '${_currentMachine.maintenanceIntervalHours.toInt()} hours'),
                _specRow('Last Synced', _currentMachine.updatedAt.toLocal().toString().split('.')[0]),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Action Buttons
          ElevatedButton.icon(
            onPressed: _calculating ? null : _runCalculateMaintenance,
            icon: _calculating
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0B0F19)),
                  )
                : const Icon(Icons.calculate_rounded),
            label: Text(_calculating ? 'Analyzing Cycles...' : 'Recalculate Maintenance'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF06B6D4),
              foregroundColor: const Color(0xFF0B0F19),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MaintenanceListScreen(
                    machine: _currentMachine,
                    service: widget.service,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.build_circle_outlined, color: Color(0xFF06B6D4)),
            label: const Text('View Maintenance Logs', style: TextStyle(color: Color(0xFF06B6D4))),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF06B6D4)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _specRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

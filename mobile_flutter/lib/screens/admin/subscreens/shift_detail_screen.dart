import 'package:flutter/material.dart';
import '../../../models/admin/shift_model.dart';
import '../../../services/admin/admin_api_service.dart';
import '../../../widgets/admin/admin_card.dart';
import '../../../widgets/admin/status_chip.dart';
import '../../../widgets/admin/metric_gauge.dart';
import '../../../widgets/admin/shift_form_dialog.dart';

class ShiftDetailScreen extends StatefulWidget {
  final ShiftModel shift;
  final AdminApiService service;

  const ShiftDetailScreen({
    required this.shift,
    required this.service,
    super.key,
  });

  @override
  State<ShiftDetailScreen> createState() => _ShiftDetailScreenState();
}

class _ShiftDetailScreenState extends State<ShiftDetailScreen> {
  late ShiftModel _currentShift;
  bool _adjusting = false;
  bool _hasChanged = false;

  @override
  void initState() {
    super.initState();
    _currentShift = widget.shift;
  }

  Future<void> _editShift() async {
    final updated = await showDialog<ShiftModel>(
      context: context,
      builder: (_) =>
          ShiftFormDialog(shift: _currentShift, service: widget.service),
    );
    if (updated != null && mounted) {
      setState(() {
        _currentShift = updated;
        _hasChanged = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Shift details updated!'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    }
  }

  Future<void> _adjustOutput() async {
    setState(() => _adjusting = true);
    try {
      final res = await widget.service.adjustShiftOutput(_currentShift.id);
      if (mounted) {
        final shifts = await widget.service.getShifts();
        if (!mounted) return;
        final updated = shifts.firstWhere(
          (s) => s.id == _currentShift.id,
          orElse: () => _currentShift,
        );
        setState(() {
          _currentShift = updated;
          _adjusting = false;
          _hasChanged = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              res['message']?.toString() ??
                  'Output quota adjusted successfully!',
            ),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _adjusting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to adjust output: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  Future<void> _deleteShift() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete shift?'),
        content: Text(_currentShift.name),
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
      await widget.service.deleteShift(_currentShift.id);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not delete shift: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {},
      child: Scaffold(
        backgroundColor: const Color(0xFF0B0F19),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0F172A),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context, _hasChanged),
          ),
          title: Text(
            _currentShift.name,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          actions: [
            IconButton(
              tooltip: 'Delete shift',
              onPressed: _deleteShift,
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: Color(0xFF06B6D4)),
              tooltip: 'Edit Shift',
              onPressed: _editShift,
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
                        _currentShift.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      StatusChip(status: _currentShift.status),
                    ],
                  ),
                  const SizedBox(height: 16),
                  MetricGauge(
                    label: 'Shift Target Quota',
                    value: _currentShift.adjustedOutput,
                    maxValue: _currentShift.targetOutput > 0
                        ? _currentShift.targetOutput
                        : 100,
                    unit: ' units',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AdminCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Shift Operational Details',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _specRow('Shift ID', _currentShift.id),
                  _specRow(
                    'Scheduled Start',
                    _currentShift.startTime
                        .toUtc()
                        .add(const Duration(hours: 5, minutes: 30))
                        .toString()
                        .split('.')[0],
                  ),
                  _specRow(
                    'Scheduled End',
                    _currentShift.endTime
                        .toUtc()
                        .add(const Duration(hours: 5, minutes: 30))
                        .toString()
                        .split('.')[0],
                  ),
                  _specRow(
                    'Base Quota',
                    '${_currentShift.targetOutput.toInt()} units',
                  ),
                  _specRow(
                    'Adjusted Quota',
                    '${_currentShift.adjustedOutput.toInt()} units',
                  ),
                  if (_currentShift.notes != null &&
                      _currentShift.notes!.isNotEmpty)
                    _specRow('Operational Notes', _currentShift.notes!),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _adjusting ? null : _adjustOutput,
              icon: _adjusting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF0B0F19),
                      ),
                    )
                  : const Icon(Icons.tune_rounded),
              label: Text(
                _adjusting ? 'Adjusting Quota...' : 'Optimize Shift Output',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF06B6D4),
                foregroundColor: const Color(0xFF0B0F19),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _editShift,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Edit Shift Details'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF06B6D4),
                side: const BorderSide(color: Color(0xFF06B6D4)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _specRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

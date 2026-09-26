import 'package:flutter/material.dart';
import '../../../models/admin/shift_model.dart';
import '../../../services/admin/admin_api_service.dart';
import '../../../widgets/admin/admin_card.dart';
import '../../../widgets/admin/status_chip.dart';
import '../../../widgets/admin/metric_gauge.dart';

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

  @override
  void initState() {
    super.initState();
    _currentShift = widget.shift;
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
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message']?.toString() ?? 'Output quota adjusted successfully!'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        title: Text(
          _currentShift.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
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
                  value: _currentShift.adjustedOutput > 0
                      ? _currentShift.adjustedOutput
                      : _currentShift.targetOutput,
                  maxValue: _currentShift.targetOutput > 0 ? _currentShift.targetOutput : 100,
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
                _specRow('Scheduled Start', _currentShift.startTime.toLocal().toString().split('.')[0]),
                _specRow('Scheduled End', _currentShift.endTime.toLocal().toString().split('.')[0]),
                _specRow('Base Quota', '${_currentShift.targetOutput.toInt()} units'),
                _specRow('Adjusted Quota', '${_currentShift.adjustedOutput.toInt()} units'),
                if (_currentShift.notes != null && _currentShift.notes!.isNotEmpty)
                  _specRow('Operational Notes', _currentShift.notes!),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _adjusting ? null : _adjustOutput,
            icon: _adjusting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0B0F19)),
                  )
                : const Icon(Icons.tune_rounded),
            label: Text(_adjusting ? 'Adjusting Quota...' : 'Optimize Shift Output'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF06B6D4),
              foregroundColor: const Color(0xFF0B0F19),
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

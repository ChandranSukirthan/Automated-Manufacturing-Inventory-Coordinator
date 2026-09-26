import 'package:flutter/material.dart';
import '../../../models/admin/machine_model.dart';
import '../../../models/admin/shift_model.dart';
import '../../../services/admin/admin_api_service.dart';
import '../../../widgets/admin/admin_card.dart';
import '../../../widgets/admin/status_chip.dart';
import '../../../widgets/admin/metric_gauge.dart';
import '../subscreens/machine_detail_screen.dart';
import '../subscreens/shift_detail_screen.dart';

class ProductionEquipmentTab extends StatefulWidget {
  final List<MachineModel> machines;
  final List<ShiftModel> shifts;
  final AdminApiService service;
  final bool loading;
  final Future<void> Function() onRefresh;

  const ProductionEquipmentTab({
    required this.machines,
    required this.shifts,
    required this.service,
    required this.loading,
    required this.onRefresh,
    super.key,
  });

  @override
  State<ProductionEquipmentTab> createState() => _ProductionEquipmentTabState();
}

class _ProductionEquipmentTabState extends State<ProductionEquipmentTab> {
  int _selectedSection = 0; // 0: Machines, 1: Shifts

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      color: const Color(0xFF06B6D4),
      backgroundColor: const Color(0xFF0F172A),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          // Section Toggle
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _selectedSection = 0),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _selectedSection == 0 ? const Color(0xFF06B6D4) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Equipment (${widget.machines.length})',
                        style: TextStyle(
                          color: _selectedSection == 0 ? const Color(0xFF0B0F19) : Colors.white70,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _selectedSection = 1),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _selectedSection == 1 ? const Color(0xFF06B6D4) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Shifts (${widget.shifts.length})',
                        style: TextStyle(
                          color: _selectedSection == 1 ? const Color(0xFF0B0F19) : Colors.white70,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (_selectedSection == 0) ..._buildMachinesList() else ..._buildShiftsList(),
        ],
      ),
    );
  }

  List<Widget> _buildMachinesList() {
    if (widget.machines.isEmpty) {
      return [
        const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              'No plant machinery found.',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          ),
        ),
      ];
    }

    return widget.machines.map((machine) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: AdminCard(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MachineDetailScreen(
                  machine: machine,
                  service: widget.service,
                ),
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      machine.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  StatusChip(status: machine.status),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, color: Color(0xFF64748B), size: 14),
                  const SizedBox(width: 4),
                  Text(
                    machine.location,
                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                  ),
                  const Spacer(),
                  if (machine.isMaintenanceDue)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF78350F).withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'SERVICE DUE',
                        style: TextStyle(
                          color: Color(0xFFF59E0B),
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              MetricGauge(
                label: 'Operational Uptime',
                value: machine.uptimeHours,
                maxValue: machine.maintenanceIntervalHours > 0 ? machine.maintenanceIntervalHours : 100,
                unit: 'h / ${machine.maintenanceIntervalHours.toInt()}h',
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  List<Widget> _buildShiftsList() {
    if (widget.shifts.isEmpty) {
      return [
        const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              'No manufacturing shifts found.',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          ),
        ),
      ];
    }

    return widget.shifts.map((shift) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: AdminCard(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ShiftDetailScreen(
                  shift: shift,
                  service: widget.service,
                ),
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      shift.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  StatusChip(status: shift.status),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.access_time_rounded, color: Color(0xFF64748B), size: 14),
                  const SizedBox(width: 4),
                  Text(
                    '${shift.startTime.toLocal().toString().substring(11, 16)} - ${shift.endTime.toLocal().toString().substring(11, 16)}',
                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                  ),
                  const Spacer(),
                  Text(
                    'Target: ${shift.targetOutput.toInt()} units',
                    style: const TextStyle(
                      color: Color(0xFF06B6D4),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }).toList();
  }
}

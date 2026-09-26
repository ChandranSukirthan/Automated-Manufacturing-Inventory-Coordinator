import 'package:flutter/material.dart';
import '../../../models/admin/machine_model.dart';
import '../../../models/admin/shift_model.dart';
import '../../../services/admin/admin_api_service.dart';
import '../../../widgets/admin/admin_card.dart';
import '../../../widgets/admin/status_chip.dart';
import '../../../widgets/admin/metric_gauge.dart';
import '../subscreens/machine_detail_screen.dart';
import '../subscreens/shift_detail_screen.dart';
import '../../../widgets/admin/machine_form_dialog.dart';

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
                        'Production & Shifts (${widget.shifts.length})',
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

  Future<void> _openAddMachineDialog() async {
    final created = await showDialog<MachineModel>(
      context: context,
      builder: (_) => MachineFormDialog(service: widget.service),
    );
    if (created != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${created.name} registered to fleet!'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
      await widget.onRefresh();
    }
  }

  List<Widget> _buildMachinesList() {
    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Equipment Registry',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  '${widget.machines.length} active machines registered',
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                ),
              ],
            ),
            ElevatedButton.icon(
              onPressed: _openAddMachineDialog,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text(
                'Add Machine',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF06B6D4),
                foregroundColor: const Color(0xFF0B0F19),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
      if (widget.machines.isEmpty)
        const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              'No plant machinery found. Tap "Add Machine" above to register equipment.',
              style: TextStyle(color: Color(0xFF64748B)),
              textAlign: TextAlign.center,
            ),
          ),
        )
      else
        ...widget.machines.map((machine) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AdminCard(
              onTap: () async {
                final changed = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MachineDetailScreen(
                      machine: machine,
                      service: widget.service,
                    ),
                  ),
                );
                if (changed == true && mounted) {
                  widget.onRefresh();
                }
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
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF064E3B).withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'OK',
                        style: TextStyle(
                          color: Color(0xFF10B981),
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
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Uptime: ${machine.uptimeHours.toStringAsFixed(1)}h',
                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                  ),
                  Text(
                    'Remaining: ${machine.remainingHours.toStringAsFixed(1)}h',
                    style: TextStyle(
                      color: machine.remainingHours < 20 ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }),
  ];
}

  List<Widget> _buildShiftsList() {
    final activeShift = widget.shifts.firstWhere(
      (s) => s.status == 'Active',
      orElse: () => widget.shifts.isNotEmpty
          ? widget.shifts.first
          : ShiftModel(
              id: '',
              name: 'Morning Production Shift A',
              startTime: DateTime.now(),
              endTime: DateTime.now().add(const Duration(hours: 8)),
              targetOutput: 450,
              adjustedOutput: 420,
              status: 'Active',
            ),
    );

    return [
      // Production Dashboard Master Summary Card
      AdminCard(
        backgroundColor: const Color(0xFF0F172A),
        borderColor: const Color(0xFF06B6D4).withValues(alpha: 0.4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.factory_rounded, color: Color(0xFF06B6D4), size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Production Dashboard',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                StatusChip(status: activeShift.status),
              ],
            ),
            const SizedBox(height: 14),

            // Production Status Specs
            _specRow('Current Shift', activeShift.name),
            _specRow('Production Status', activeShift.status),
            _specRow('Production Target', '${activeShift.targetOutput.toInt()} units'),
            _specRow('Adjusted Output', '${(activeShift.adjustedOutput > 0 ? activeShift.adjustedOutput : activeShift.targetOutput).toInt()} units'),

            const SizedBox(height: 12),
            const Divider(color: Color(0xFF334155), height: 1),
            const SizedBox(height: 12),

            // Available Material Section
            const Row(
              children: [
                Icon(Icons.inventory_2_outlined, color: Color(0xFF10B981), size: 16),
                SizedBox(width: 6),
                Text(
                  'Available Material',
                  style: TextStyle(
                    color: Color(0xFF10B981),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _materialRow('Cold Rolled Steel Sheet', '2,900 KG'),
            _materialRow('High-Tensile Aluminum Rod', '900 METRES'),
            _materialRow('Industrial Polypropylene Pellets', '2,900 KG'),
          ],
        ),
      ),
      const SizedBox(height: 16),

      const Text(
        'Manufacturing Shifts',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 15,
        ),
      ),
      const SizedBox(height: 10),

      ...widget.shifts.map((shift) {
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
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Production Status: ${shift.status}',
                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                    ),
                    Text(
                      'Adjusted Output: ${shift.adjustedOutput > 0 ? shift.adjustedOutput.toInt() : shift.targetOutput.toInt()}u',
                      style: const TextStyle(
                        color: Color(0xFF10B981),
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }),
    ];
  }

  Widget _specRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _materialRow(String material, String quantity) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(material, style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF064E3B).withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
            ),
            child: Text(
              quantity,
              style: const TextStyle(
                color: Color(0xFF10B981),
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

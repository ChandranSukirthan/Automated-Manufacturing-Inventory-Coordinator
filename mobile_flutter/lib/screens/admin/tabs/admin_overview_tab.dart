import 'package:flutter/material.dart';
import '../../../models/admin/machine_model.dart';
import '../../../models/admin/shift_model.dart';
import '../../../models/admin/workflow_model.dart';
import '../../../models/admin/system_health_model.dart';
import '../../../widgets/admin/admin_card.dart';
import '../../../widgets/admin/status_chip.dart';
import '../../../widgets/admin/metric_gauge.dart';

class AdminOverviewTab extends StatelessWidget {
  final List<MachineModel> machines;
  final List<ShiftModel> shifts;
  final List<WorkflowModel> workflows;
  final SystemHealthModel? health;
  final bool loading;
  final Future<void> Function() onRefresh;
  final void Function(int index) onNavigateTab;

  const AdminOverviewTab({
    required this.machines,
    required this.shifts,
    required this.workflows,
    required this.health,
    required this.loading,
    required this.onRefresh,
    required this.onNavigateTab,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (loading && machines.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF06B6D4)),
      );
    }

    final operationalCount = machines.where((m) => m.status == 'Operational').length;
    final maintenanceCount = machines.where((m) => m.isMaintenanceDue).length;
    final activeShift = shifts.firstWhere(
      (s) => s.status == 'Active',
      orElse: () => shifts.isNotEmpty ? shifts.first : ShiftModel(
        id: '',
        name: 'No Active Shift',
        startTime: DateTime.now(),
        endTime: DateTime.now().add(const Duration(hours: 8)),
        targetOutput: 0,
        adjustedOutput: 0,
        status: 'None',
      ),
    );
    final pendingApprovals = workflows.where((w) => w.isWaitingForApproval).length;

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: const Color(0xFF06B6D4),
      backgroundColor: const Color(0xFF0F172A),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          // Header banner
          AdminCard(
            backgroundColor: const Color(0xFF0F172A),
            borderColor: const Color(0xFF06B6D4).withValues(alpha: 0.3),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF06B6D4).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.hub_rounded, color: Color(0xFF06B6D4), size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Operations Command Center',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Live telemetry • Plant Floor & Cloud Infrastructure',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                StatusChip(status: health?.overallStatus ?? 'ONLINE'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2x2 Grid KPIs
          Row(
            children: [
              Expanded(
                child: AdminCard(
                  onTap: () => onNavigateTab(1),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Icon(Icons.precision_manufacturing, color: Color(0xFF06B6D4), size: 22),
                          Text(
                            '$operationalCount / ${machines.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Equipment Active',
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        maintenanceCount > 0 ? '$maintenanceCount due for check' : 'All running optimal',
                        style: TextStyle(
                          color: maintenanceCount > 0 ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AdminCard(
                  onTap: () => onNavigateTab(1),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Icon(Icons.schedule_rounded, color: Color(0xFF8B5CF6), size: 22),
                          Text(
                            '${activeShift.targetOutput.toInt()}u',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Current Shift Goal',
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        activeShift.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFCBD5E1),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AdminCard(
                  onTap: () => onNavigateTab(2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Icon(Icons.psychology_rounded, color: Color(0xFFF59E0B), size: 22),
                          Text(
                            '$pendingApprovals',
                            style: TextStyle(
                              color: pendingApprovals > 0 ? const Color(0xFFF59E0B) : Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Pending Approvals',
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        pendingApprovals > 0 ? 'Requires Admin Decision' : 'Zero blockers',
                        style: TextStyle(
                          color: pendingApprovals > 0 ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AdminCard(
                  onTap: () => onNavigateTab(3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Icon(Icons.dns_rounded, color: Color(0xFF10B981), size: 22),
                          Text(
                            '${health?.services.length ?? 6}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Services Monitored',
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        health?.overallStatus == 'ONLINE' ? '100% Operational' : 'Action Required',
                        style: TextStyle(
                          color: health?.overallStatus == 'ONLINE'
                              ? const Color(0xFF10B981)
                              : const Color(0xFFEF4444),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Active Shift Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Active Production Shift',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              TextButton(
                onPressed: () => onNavigateTab(1),
                child: const Text(
                  'Manage Shifts',
                  style: TextStyle(color: Color(0xFF06B6D4), fontSize: 12),
                ),
              ),
            ],
          ),
          AdminCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      activeShift.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    StatusChip(status: activeShift.status),
                  ],
                ),
                const SizedBox(height: 12),
                MetricGauge(
                  label: 'Target vs Adjusted Output',
                  value: activeShift.adjustedOutput > 0 ? activeShift.adjustedOutput : activeShift.targetOutput,
                  maxValue: activeShift.targetOutput > 0 ? activeShift.targetOutput : 100,
                  unit: ' units',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Live Machines Snapshot
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Machine Telemetry',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              TextButton(
                onPressed: () => onNavigateTab(1),
                child: const Text(
                  'View All Machines',
                  style: TextStyle(color: Color(0xFF06B6D4), fontSize: 12),
                ),
              ),
            ],
          ),
          ...machines.take(3).map(
                (m) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AdminCard(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F172A),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.settings_suggest_rounded,
                                color: Color(0xFF06B6D4),
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  m.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  '${m.uptimeHours.toInt()}h uptime • ${m.location}',
                                  style: const TextStyle(
                                    color: Color(0xFF64748B),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        StatusChip(status: m.status),
                      ],
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

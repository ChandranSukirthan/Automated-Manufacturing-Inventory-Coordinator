import 'package:flutter/material.dart';
import '../../../models/admin/system_health_model.dart';
import '../../../widgets/admin/admin_card.dart';
import '../../../widgets/admin/status_chip.dart';

class SystemHealthTab extends StatelessWidget {
  final SystemHealthModel? health;
  final bool loading;
  final Future<void> Function() onRefresh;

  const SystemHealthTab({
    required this.health,
    required this.loading,
    required this.onRefresh,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final overall = health?.overallStatus ?? 'ONLINE';
    final services = health?.services ?? [];

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: const Color(0xFF06B6D4),
      backgroundColor: const Color(0xFF0F172A),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          // Header Status Banner
          AdminCard(
            backgroundColor: overall == 'ONLINE'
                ? const Color(0xFF064E3B).withValues(alpha: 0.25)
                : const Color(0xFF7F1D1D).withValues(alpha: 0.25),
            borderColor: overall == 'ONLINE' ? const Color(0xFF10B981) : const Color(0xFFEF4444),
            child: Row(
              children: [
                Icon(
                  overall == 'ONLINE' ? Icons.check_circle_rounded : Icons.warning_rounded,
                  color: overall == 'ONLINE' ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  size: 32,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Overall Status: $overall',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        overall == 'ONLINE'
                            ? 'All distributed components operating within normal SLA'
                            : 'One or more subsystem dependencies are unreachable',
                        style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Subsystem Services',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              Text(
                'Synced: ${health?.timestamp.toLocal().toString().substring(11, 19) ?? "Now"}',
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (services.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('No service telemetry reported.', style: TextStyle(color: Color(0xFF64748B))),
              ),
            )
          else
            ...services.map((svc) {
              IconData icon;
              if (svc.name.toLowerCase().contains('api') || svc.name.toLowerCase().contains('asp')) {
                icon = Icons.dns_rounded;
              } else if (svc.name.toLowerCase().contains('sql') || svc.name.toLowerCase().contains('data')) {
                icon = Icons.storage_rounded;
              } else if (svc.name.toLowerCase().contains('fastapi') || svc.name.toLowerCase().contains('ai')) {
                icon = Icons.psychology_rounded;
              } else {
                icon = Icons.cloud_done_rounded;
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AdminCard(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, color: const Color(0xFF06B6D4), size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              svc.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              svc.message,
                              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      StatusChip(status: svc.status),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

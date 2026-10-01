import 'package:flutter/material.dart';

class StatusChip extends StatelessWidget {
  final String status;
  final bool showDot;

  const StatusChip({
    required this.status,
    this.showDot = true,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final lower = status.toLowerCase();
    Color color;
    Color bg;

    if (lower.contains('operational') ||
        lower.contains('online') ||
        lower.contains('completed') ||
        lower.contains('active') ||
        lower.contains('success')) {
      color = const Color(0xFF10B981);
      bg = const Color(0xFF064E3B).withValues(alpha: 0.35);
    } else if (lower.contains('maintenance') ||
        lower.contains('degraded') ||
        lower.contains('in_progress') ||
        lower.contains('inprogress') ||
        lower.contains('waiting') ||
        lower.contains('warning')) {
      color = const Color(0xFFF59E0B);
      bg = const Color(0xFF78350F).withValues(alpha: 0.35);
    } else if (lower.contains('offline') ||
        lower.contains('cancelled') ||
        lower.contains('failed') ||
        lower.contains('error')) {
      color = const Color(0xFFEF4444);
      bg = const Color(0xFF7F1D1D).withValues(alpha: 0.35);
    } else {
      color = const Color(0xFF06B6D4);
      bg = const Color(0xFF083344).withValues(alpha: 0.35);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
          ],
          Text(
            status,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

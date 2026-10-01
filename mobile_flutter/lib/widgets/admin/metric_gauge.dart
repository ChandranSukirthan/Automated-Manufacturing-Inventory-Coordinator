import 'package:flutter/material.dart';

class MetricGauge extends StatelessWidget {
  final String label;
  final double value;
  final double maxValue;
  final String unit;
  final Color? color;

  const MetricGauge({
    required this.label,
    required this.value,
    this.maxValue = 100.0,
    this.unit = '%',
    this.color,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (maxValue > 0 ? (value / maxValue) : 0.0).clamp(0.0, 1.0);
    final displayColor = color ??
        (progress > 0.8
            ? const Color(0xFF10B981)
            : progress > 0.5
                ? const Color(0xFF06B6D4)
                : const Color(0xFFF59E0B));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${value.toStringAsFixed(1)}$unit',
              style: TextStyle(
                color: displayColor,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: const Color(0xFF0F172A),
            valueColor: AlwaysStoppedAnimation<Color>(displayColor),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}

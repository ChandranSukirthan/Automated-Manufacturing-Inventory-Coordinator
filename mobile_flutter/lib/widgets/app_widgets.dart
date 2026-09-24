import 'package:flutter/material.dart';

import '../app_colors.dart';

class MetricCard extends StatelessWidget {
  const MetricCard({
    required this.label,
    required this.value,
    required this.color,
    super.key,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: color.withValues(alpha: 0.25)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.analytics_outlined, color: color),
        const SizedBox(height: 16),
        Text(
          '$value',
          style: Theme.of(context).textTheme.headlineMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
      ],
    ),
  );
}

class DashboardMetricCard extends StatelessWidget {
  const DashboardMetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.accentColor,
    required this.gradientColors,
    super.key,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color accentColor;
  final List<Color> gradientColors;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: gradientColors,
      ),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: accentColor.withValues(alpha: 0.42), width: 1.2),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.25),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: accentColor, size: 22),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$value',
              style: const TextStyle(
                color: AppColors.strongText,
                fontSize: 32,
                fontWeight: FontWeight.w700,
                height: 1,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label.toUpperCase(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.mutedText,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class StateMessage extends StatelessWidget {
  const StateMessage({
    required this.message,
    required this.icon,
    this.action,
    super.key,
  });

  final String message;
  final IconData icon;
  final VoidCallback? action;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 44, color: AppColors.primary),
          const SizedBox(height: 14),
          Text(message, textAlign: TextAlign.center),
          if (action != null) ...[
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: action,
              child: const Text('Try again'),
            ),
          ],
        ],
      ),
    ),
  );
}

class StatusPill extends StatelessWidget {
  const StatusPill(this.value, {super.key});

  final String value;

  @override
  Widget build(BuildContext context) {
    final lower = value.toLowerCase();
    final color =
        lower.contains('high') || lower.contains('active')
        ? AppColors.warningText
        : lower.contains('open')
        ? AppColors.violet
        : lower.contains('released') ||
              lower.contains('resolved') ||
              lower.contains('closed')
        ? AppColors.primaryTextLight
        : AppColors.info;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        value,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

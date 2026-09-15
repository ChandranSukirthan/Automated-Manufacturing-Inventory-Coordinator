import 'package:flutter/material.dart';

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
          Icon(icon, size: 44, color: Theme.of(context).colorScheme.primary),
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
        lower.contains('high') ||
            lower.contains('active') ||
            lower.contains('open')
        ? Colors.deepOrange
        : lower.contains('released') ||
              lower.contains('resolved') ||
              lower.contains('closed')
        ? Colors.teal
        : Colors.indigo;
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

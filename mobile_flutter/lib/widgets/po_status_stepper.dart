import 'package:flutter/material.dart';
import '../models/purchase_order_models.dart';

class POStatusStepper extends StatelessWidget {
  const POStatusStepper({
    required this.currentStep,
    super.key,
  });

  final POLifecycleStep currentStep;

  @override
  Widget build(BuildContext context) {
    final steps = POLifecycleStep.values;
    final currentIdx = steps.indexOf(currentStep);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1B2B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Order Lifecycle Pipeline',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF5CC8F8).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF5CC8F8).withOpacity(0.3)),
                ),
                child: Text(
                  'Step ${currentIdx + 1} of ${steps.length}',
                  style: const TextStyle(
                    color: Color(0xFF5CC8F8),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: steps.length,
            itemBuilder: (context, index) {
              final step = steps[index];
              final isCompleted = index < currentIdx;
              final isCurrent = index == currentIdx;
              final isLast = index == steps.length - 1;

              Color stepColor;
              IconData stepIcon;
              if (isCompleted) {
                stepColor = const Color(0xFF10B981);
                stepIcon = Icons.check_circle_rounded;
              } else if (isCurrent) {
                stepColor = const Color(0xFF5CC8F8);
                stepIcon = Icons.radio_button_checked_rounded;
              } else {
                stepColor = Colors.white24;
                stepIcon = Icons.radio_button_unchecked_rounded;
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Step Indicator column with connector line
                  Column(
                    children: [
                      Icon(
                        stepIcon,
                        size: 20,
                        color: stepColor,
                      ),
                      if (!isLast)
                        Container(
                          width: 2,
                          height: 28,
                          color: isCompleted
                              ? const Color(0xFF10B981).withOpacity(0.6)
                              : Colors.white12,
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  // Step text information
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                step.title,
                                style: TextStyle(
                                  color: isCurrent
                                      ? const Color(0xFF5CC8F8)
                                      : isCompleted
                                          ? Colors.white
                                          : Colors.white54,
                                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              if (isCurrent) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF5CC8F8).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'ACTIVE',
                                    style: TextStyle(
                                      color: Color(0xFF5CC8F8),
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            step.description,
                            style: TextStyle(
                              color: isCurrent ? Colors.white70 : Colors.white38,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

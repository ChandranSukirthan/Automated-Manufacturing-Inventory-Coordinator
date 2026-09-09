import 'package:flutter/material.dart';

class AgenticExecutionLogView extends StatelessWidget {
  final VoidCallback onClose;

  const AgenticExecutionLogView({
    super.key,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    const navyBg = Color(0xFF070E17);
    const cardBg = Color(0xFF0F1B2B);
    const cyanAccent = Color(0xFF5CC8F8);
    const greenDot = Color(0xFF00E676);
    const amberDot = Color(0xFFFFB74D);
    const coralAccent = Color(0xFFFF7043);

    return Scaffold(
      backgroundColor: navyBg,
      appBar: AppBar(
        backgroundColor: navyBg,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Execution Log',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                const Text(
                  'Agentic AI Execution ',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E3A5F),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '#WF-8902',
                    style: TextStyle(color: cyanAccent, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70),
            onPressed: onClose,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Reasoning Tree Sequence',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Agent Step 1: Planner Agent
                  _buildAgentStep(
                    icon: Icons.tour_outlined,
                    dotColor: greenDot,
                    agentName: 'Planner Agent',
                    timestamp: '00:00:01',
                    description: 'Replenishment plan generated. Targeted inventory restock to 150% of safety stock.',
                    cardBg: cardBg,
                    showLine: true,
                  ),

                  // Agent Step 2: Data Extraction Agent
                  _buildAgentStep(
                    icon: Icons.storage_outlined,
                    dotColor: greenDot,
                    agentName: 'Data Extraction Agent',
                    timestamp: '00:00:03',
                    description: 'Burn rate analyzed: 120 kg/day. Current stock depletion estimated in 4.5 days.',
                    cardBg: cardBg,
                    showLine: true,
                  ),

                  // Agent Step 3: Purchasing Agent
                  _buildAgentStep(
                    icon: Icons.shopping_cart_outlined,
                    dotColor: greenDot,
                    agentName: 'Purchasing Agent',
                    timestamp: '00:00:12',
                    description: 'Optimum rate found at Apex Polymers (\$53.75/kg). Compared against 4 suppliers.',
                    cardBg: cardBg,
                    showLine: true,
                  ),

                  // Agent Step 4: Validation Agent
                  _buildAgentStep(
                    icon: Icons.verified_user_outlined,
                    dotColor: amberDot,
                    agentName: 'Validation Agent',
                    timestamp: '00:00:15',
                    description: 'Schema valid. Budget threshold flagged: Total \$6,450.00 exceeds \$5,000.00 manager limit. Approval required.',
                    cardBg: cardBg,
                    showLine: false,
                    isBorderedCard: true,
                    borderColor: cyanAccent,
                    customChild: Container(
                      margin: const EdgeInsets.only(top: 14),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF070E17),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Text('Total Cost:', style: TextStyle(color: Colors.white70, fontSize: 13)),
                          Text('\$6,450.00', style: TextStyle(color: coralAccent, fontSize: 14, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Fixed Action Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: cardBg,
              border: Border(top: BorderSide(color: Colors.white12)),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 1,
                  child: SizedBox(
                    height: 50,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.close, color: Colors.white, size: 18),
                      label: const Text('Reject', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white30),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: onClose,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check_circle_outline, color: Colors.black, size: 20),
                      label: const Text('Approve & Execute', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cyanAccent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Execution Plan #WF-8902 Approved!')),
                        );
                        onClose();
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgentStep({
    required IconData icon,
    required Color dotColor,
    required String agentName,
    required String timestamp,
    required String description,
    required Color cardBg,
    required bool showLine,
    bool isBorderedCard = false,
    Color borderColor = Colors.transparent,
    Widget? customChild,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon Stack Column
          Column(
            children: [
              Stack(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Icon(icon, color: Colors.white70, size: 22),
                  ),
                  Positioned(
                    right: 2,
                    bottom: 2,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: dotColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF070E17), width: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
              if (showLine)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    color: Colors.white12,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          // Details Card Column
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
                border: isBorderedCard
                    ? Border.all(color: borderColor, width: 1.5)
                    : Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        agentName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        timestamp,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                  if (customChild != null) ...[customChild],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

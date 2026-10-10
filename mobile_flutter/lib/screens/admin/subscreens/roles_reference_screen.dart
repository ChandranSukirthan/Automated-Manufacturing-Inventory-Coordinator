import 'package:flutter/material.dart';

class RolesReferenceScreen extends StatelessWidget {
  const RolesReferenceScreen({super.key});
  @override
  Widget build(BuildContext context) {
    const roles = [
      {
        "name": "FloorWorker",
        "title": "Floor Worker",
        "badge": "bg-slate-800 text-slate-300 border-white/10",
        "description":
            "Frontline shop-floor operators executing production tasks, reporting machinery incidents, and logging work shift actuals.",
        "permissions": [
          {"label": "View Assigned Machine Telemetry", "granted": true},
          {"label": "Submit Incident & Maintenance Requests", "granted": true},
          {"label": "View Current Work Shifts", "granted": true},
          {"label": "Manage Inventory Procurement", "granted": false},
          {"label": "Approve Quality Inspection Batches", "granted": false},
          {
            "label": "Access System Administration (/admin/*)",
            "granted": false,
          },
          {"label": "Decommission or Alter Fleet Machinery", "granted": false},
          {"label": "Monitor Autonomous AI Agent Workflows", "granted": false},
        ],
      },
      {
        "name": "SupplyChainManager",
        "title": "Supply Chain Manager",
        "badge": "bg-blue-500/10 text-blue-400 border-blue-500/20",
        "description":
            "Logistics and procurement leaders managing vendor purchase orders, inventory stocks, and material replenishment schedules.",
        "permissions": [
          {"label": "View Assigned Machine Telemetry", "granted": true},
          {"label": "Submit Incident & Maintenance Requests", "granted": true},
          {"label": "View Current Work Shifts", "granted": true},
          {"label": "Manage Inventory Procurement", "granted": true},
          {"label": "Approve Quality Inspection Batches", "granted": false},
          {
            "label": "Access System Administration (/admin/*)",
            "granted": false,
          },
          {"label": "Decommission or Alter Fleet Machinery", "granted": false},
          {"label": "Monitor Autonomous AI Agent Workflows", "granted": false},
        ],
      },
      {
        "name": "QualityInspector",
        "title": "Quality Inspector",
        "badge": "bg-purple-500/10 text-purple-400 border-purple-500/20",
        "description":
            "Compliance and quality assurance specialists logging inspection audits, batch defect tracking, and regulatory sign-offs.",
        "permissions": [
          {"label": "View Assigned Machine Telemetry", "granted": true},
          {"label": "Submit Incident & Maintenance Requests", "granted": true},
          {"label": "View Current Work Shifts", "granted": true},
          {"label": "Manage Inventory Procurement", "granted": false},
          {"label": "Approve Quality Inspection Batches", "granted": true},
          {
            "label": "Access System Administration (/admin/*)",
            "granted": false,
          },
          {"label": "Decommission or Alter Fleet Machinery", "granted": false},
          {"label": "Monitor Autonomous AI Agent Workflows", "granted": false},
        ],
      },
      {
        "name": "ITAdmin",
        "title": "IT Administrator",
        "badge": "bg-brand-500/20 text-brand-300 border-brand-500/30",
        "description":
            "System master role with full security administration, user provisioning, role assignments, audit inspection, and machine CRUD ownership.",
        "permissions": [
          {"label": "View Assigned Machine Telemetry", "granted": true},
          {"label": "Submit Incident & Maintenance Requests", "granted": true},
          {"label": "View Current Work Shifts", "granted": true},
          {"label": "Manage Inventory Procurement", "granted": true},
          {"label": "Approve Quality Inspection Batches", "granted": true},
          {"label": "Access System Administration (/admin/*)", "granted": true},
          {"label": "Decommission or Alter Fleet Machinery", "granted": true},
          {"label": "Monitor Autonomous AI Agent Workflows", "granted": true},
        ],
      },
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Roles & Permissions')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Role reference matching the web admin page. Assign user roles through User Directory.',
          ),
          ...roles.map(
            (r) => Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r['title'] as String,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(r['description'] as String),
                    const SizedBox(height: 12),
                    ...(r['permissions'] as List).map(
                      (p) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Icon(
                              p['granted'] == true
                                  ? Icons.check_circle_outline
                                  : Icons.block,
                              color: p['granted'] == true
                                  ? Colors.green
                                  : Colors.grey,
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(p['label'] as String)),
                          ],
                        ),
                      ),
                    ),
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

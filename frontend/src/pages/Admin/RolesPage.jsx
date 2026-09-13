import React from 'react';
import { 
  ShieldCheck, 
  Users, 
  Package, 
  CheckSquare, 
  Cpu, 
  Lock, 
  FileText, 
  Bot, 
  Activity,
  Check,
  X
} from 'lucide-react';
import AdminLayout from '../../components/Layout/AdminLayout';

export default function RolesPage() {
  const roles = [
    {
      name: 'FloorWorker',
      title: 'Floor Worker',
      badge: 'bg-slate-800 text-slate-300 border-white/10',
      description: 'Frontline shop-floor operators executing production tasks, reporting machinery incidents, and logging work shift actuals.',
      permissions: [
        { label: 'View Assigned Machine Telemetry', granted: true },
        { label: 'Submit Incident & Maintenance Requests', granted: true },
        { label: 'View Current Work Shifts', granted: true },
        { label: 'Manage Inventory Procurement', granted: false },
        { label: 'Approve Quality Inspection Batches', granted: false },
        { label: 'Access System Administration (/admin/*)', granted: false },
        { label: 'Decommission or Alter Fleet Machinery', granted: false },
        { label: 'Monitor Autonomous AI Agent Workflows', granted: false },
      ]
    },
    {
      name: 'SupplyChainManager',
      title: 'Supply Chain Manager',
      badge: 'bg-blue-500/10 text-blue-400 border-blue-500/20',
      description: 'Logistics and procurement leaders managing vendor purchase orders, inventory stocks, and material replenishment schedules.',
      permissions: [
        { label: 'View Assigned Machine Telemetry', granted: true },
        { label: 'Submit Incident & Maintenance Requests', granted: true },
        { label: 'View Current Work Shifts', granted: true },
        { label: 'Manage Inventory Procurement', granted: true },
        { label: 'Approve Quality Inspection Batches', granted: false },
        { label: 'Access System Administration (/admin/*)', granted: false },
        { label: 'Decommission or Alter Fleet Machinery', granted: false },
        { label: 'Monitor Autonomous AI Agent Workflows', granted: false },
      ]
    },
    {
      name: 'QualityInspector',
      title: 'Quality Inspector',
      badge: 'bg-purple-500/10 text-purple-400 border-purple-500/20',
      description: 'Compliance and quality assurance specialists logging inspection audits, batch defect tracking, and regulatory sign-offs.',
      permissions: [
        { label: 'View Assigned Machine Telemetry', granted: true },
        { label: 'Submit Incident & Maintenance Requests', granted: true },
        { label: 'View Current Work Shifts', granted: true },
        { label: 'Manage Inventory Procurement', granted: false },
        { label: 'Approve Quality Inspection Batches', granted: true },
        { label: 'Access System Administration (/admin/*)', granted: false },
        { label: 'Decommission or Alter Fleet Machinery', granted: false },
        { label: 'Monitor Autonomous AI Agent Workflows', granted: false },
      ]
    },
    {
      name: 'ITAdmin',
      title: 'IT Administrator (Student 4)',
      badge: 'bg-brand-500/20 text-brand-300 border-brand-500/30',
      description: 'System master role with full security administration, user provisioning, role assignments, audit inspection, and machine CRUD ownership.',
      permissions: [
        { label: 'View Assigned Machine Telemetry', granted: true },
        { label: 'Submit Incident & Maintenance Requests', granted: true },
        { label: 'View Current Work Shifts', granted: true },
        { label: 'Manage Inventory Procurement', granted: true },
        { label: 'Approve Quality Inspection Batches', granted: true },
        { label: 'Access System Administration (/admin/*)', granted: true },
        { label: 'Decommission or Alter Fleet Machinery', granted: true },
        { label: 'Monitor Autonomous AI Agent Workflows', granted: true },
      ]
    }
  ];

  return (
    <AdminLayout 
      title="Role-Based Access Control (RBAC)" 
      subtitle="Security matrix defining entitlements across floor workers, managers, inspectors, and administrators"
    >
      <div className="space-y-6">
        <div className="p-5 rounded-2xl bg-white/5 border border-white/10 backdrop-blur-xl flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="p-2.5 rounded-xl bg-brand-500/10 text-brand-400 border border-brand-500/20">
              <ShieldCheck className="w-6 h-6" />
            </div>
            <div>
              <h3 className="text-base font-bold text-white">RBAC Security Policy</h3>
              <p className="text-xs text-slate-400">All administrative API endpoints strictly enforce the <code className="text-brand-300 bg-black/40 px-1.5 py-0.5 rounded font-mono">ITAdmin</code> role claim via JWT.</p>
            </div>
          </div>
          <span className="px-3 py-1 rounded-full text-xs font-semibold bg-emerald-500/10 text-emerald-400 border border-emerald-500/20">
            4 Defined Roles
          </span>
        </div>

        {/* Roles Grid */}
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          {roles.map((role) => (
            <div 
              key={role.name}
              className="bg-slate-900/60 border border-white/10 rounded-3xl p-6 backdrop-blur-xl flex flex-col justify-between space-y-6"
            >
              <div>
                <div className="flex items-center justify-between mb-3">
                  <span className={`px-3 py-1 rounded-full text-xs font-bold border ${role.badge}`}>
                    {role.name}
                  </span>
                  <span className="text-xs font-mono text-slate-500 uppercase">System Scope</span>
                </div>

                <h3 className="text-xl font-extrabold text-white">{role.title}</h3>
                <p className="text-xs text-slate-400 mt-1 leading-relaxed">{role.description}</p>

                <div className="mt-5 space-y-2.5 pt-4 border-t border-white/10">
                  <h4 className="text-xs font-bold uppercase tracking-wider text-slate-400 mb-2">Entitlements</h4>
                  {role.permissions.map((p, idx) => (
                    <div key={idx} className="flex items-center justify-between text-xs py-1">
                      <span className={p.granted ? 'text-slate-200' : 'text-slate-500 line-through'}>
                        {p.label}
                      </span>
                      {p.granted ? (
                        <div className="w-5 h-5 rounded-full bg-emerald-500/10 text-emerald-400 flex items-center justify-center">
                          <Check className="w-3.5 h-3.5" />
                        </div>
                      ) : (
                        <div className="w-5 h-5 rounded-full bg-white/5 text-slate-600 flex items-center justify-center">
                          <X className="w-3.5 h-3.5" />
                        </div>
                      )}
                    </div>
                  ))}
                </div>
              </div>

              <div className="pt-4 border-t border-white/5 text-xs text-slate-400 flex items-center justify-between">
                <span>Role enum identifier:</span>
                <span className="font-mono text-slate-200 bg-black/40 px-2 py-0.5 rounded border border-white/5">
                  {role.name === 'FloorWorker' ? 0 : role.name === 'SupplyChainManager' ? 1 : role.name === 'QualityInspector' ? 2 : 3}
                </span>
              </div>
            </div>
          ))}
        </div>
      </div>
    </AdminLayout>
  );
}


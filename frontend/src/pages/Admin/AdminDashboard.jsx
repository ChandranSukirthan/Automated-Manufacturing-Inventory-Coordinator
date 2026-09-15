import { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { 
  Users, 
  Cpu, 
  Bot, 
  Activity, 
  ShieldCheck, 
  FileText, 
  Loader2,
  AlertTriangle,
  Layers,
  ChevronRight
} from 'lucide-react';
import AdminLayout from '../../components/Layout/AdminLayout';
import adminService from '../../services/adminService';
import machineService from '../../services/machineService';

export default function AdminDashboard() {
  const [stats, setStats] = useState({
    usersCount: 0,
    machinesCount: 0,
    workflowsCount: 0,
    systemHealth: null
  });
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    const fetchDashboardStats = async () => {
      setLoading(true);
      try {
        const [users, machines, workflows, health] = await Promise.all([
          adminService.getAllUsers(),
          machineService.getAll(),
          adminService.getAgentWorkflows(),
          adminService.getSystemHealth()
        ]);

        setStats({
          usersCount: users.length,
          machinesCount: machines.length,
          workflowsCount: workflows.length,
          systemHealth: health
        });
      } catch (err) {
        console.error(err);
        setError('Failed to aggregate administrative telemetry.');
      } finally {
        setLoading(false);
      }
    };

    fetchDashboardStats();
  }, []);

  const adminShortcuts = [
    { title: 'User Management', desc: 'Manage system access, assign roles, activate or deactivate accounts.', path: '/admin/users', icon: Users, color: 'text-blue-400', bg: 'bg-blue-500/10' },
    { title: 'Role Permissions Matrix', desc: 'Inspect capabilities across FloorWorker, Manager, Inspector & ITAdmin.', path: '/admin/roles', icon: ShieldCheck, color: 'text-indigo-400', bg: 'bg-indigo-500/10' },
    { title: 'Audit Trail Ledger', desc: 'Review security actions, access attempts, and resource mutations.', path: '/admin/audit-logs', icon: FileText, color: 'text-purple-400', bg: 'bg-purple-500/10' },
    { title: 'AI Workflow Monitoring', desc: 'Track multi-agent coordination, approvals, safety checks, and outcomes.', path: '/admin/agent-workflows', icon: Bot, color: 'text-cyan-400', bg: 'bg-cyan-500/10' },
    { title: 'System Diagnostics', desc: 'Live operational health across ASP.NET, PostgreSQL, FastAPI, and AI.', path: '/admin/system-health', icon: Activity, color: 'text-emerald-400', bg: 'bg-emerald-500/10' },
    { title: 'Equipment Telemetry', desc: 'Fleet uptime tracking, scheduled maintenance, and sensor limits.', path: '/machines', icon: Cpu, color: 'text-amber-400', bg: 'bg-amber-500/10' },
  ];

  return (
    <AdminLayout 
      title="IT Administration Hub" 
      subtitle="Centralized management of user access, security auditing, and system operations"
    >
      {/* Welcome Banner */}
      <div className="relative overflow-hidden rounded-3xl bg-gradient-to-r from-brand-600/30 via-cyan-600/20 to-slate-900/40 border border-white/10 p-8 backdrop-blur-xl">
        <div className="relative z-10 max-w-2xl space-y-2">
          <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-brand-500/20 border border-brand-500/30 text-brand-300 text-xs font-semibold">
            <span>Student 4 — IT Admin Role</span>
          </div>
          <h2 className="text-2xl sm:text-3xl font-extrabold text-white tracking-tight">
            Production Equipment & System Administration
          </h2>
          <p className="text-sm text-slate-300 leading-relaxed">
            Welcome to the control center. Monitor equipment uptime, enforce production limits, manage user authorization roles, and supervise autonomous AI agent workflows in one unified cockpit.
          </p>
        </div>
      </div>

      {error && (
        <div className="p-4 rounded-xl bg-red-500/10 border border-red-500/20 text-red-400 text-sm flex items-center gap-3">
          <AlertTriangle className="w-5 h-5 shrink-0" />
          <span>{error}</span>
        </div>
      )}

      {/* Top Level Telemetry Stats */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-5">
        <div className="bg-slate-900/60 border border-white/10 rounded-2xl p-5 backdrop-blur-xl">
          <div className="flex items-center justify-between mb-2">
            <span className="text-xs uppercase font-semibold text-slate-400">Total Registered Users</span>
            <Users className="w-4 h-4 text-blue-400" />
          </div>
          <div className="text-3xl font-extrabold text-white font-mono">
            {loading ? <Loader2 className="w-6 h-6 animate-spin" /> : stats.usersCount}
          </div>
          <p className="text-xs text-slate-400 mt-2">Active credentials across all 4 roles</p>
        </div>

        <div className="bg-slate-900/60 border border-white/10 rounded-2xl p-5 backdrop-blur-xl">
          <div className="flex items-center justify-between mb-2">
            <span className="text-xs uppercase font-semibold text-slate-400">Equipment Fleet</span>
            <Cpu className="w-4 h-4 text-amber-400" />
          </div>
          <div className="text-3xl font-extrabold text-white font-mono">
            {loading ? <Loader2 className="w-6 h-6 animate-spin" /> : stats.machinesCount}
          </div>
          <p className="text-xs text-slate-400 mt-2">Operational & under-maintenance units</p>
        </div>

        <div className="bg-slate-900/60 border border-white/10 rounded-2xl p-5 backdrop-blur-xl">
          <div className="flex items-center justify-between mb-2">
            <span className="text-xs uppercase font-semibold text-slate-400">Agent Workflows</span>
            <Bot className="w-4 h-4 text-cyan-400" />
          </div>
          <div className="text-3xl font-extrabold text-white font-mono">
            {loading ? <Loader2 className="w-6 h-6 animate-spin" /> : stats.workflowsCount}
          </div>
          <p className="text-xs text-slate-400 mt-2">Autonomous pipelines logged</p>
        </div>

        <div className="bg-slate-900/60 border border-white/10 rounded-2xl p-5 backdrop-blur-xl">
          <div className="flex items-center justify-between mb-2">
            <span className="text-xs uppercase font-semibold text-slate-400">Cluster Status</span>
            <Activity className="w-4 h-4 text-emerald-400" />
          </div>
          <div className="text-2xl font-extrabold tracking-tight">
            {loading ? (
              <Loader2 className="w-6 h-6 animate-spin" />
            ) : (
              <span className={stats.systemHealth?.overallStatus === 'ONLINE' ? 'text-emerald-400' : 'text-amber-400'}>
                {stats.systemHealth?.overallStatus || 'HEALTHY'}
              </span>
            )}
          </div>
          <p className="text-xs text-slate-400 mt-2">PostgreSQL & ASP.NET operational</p>
        </div>
      </div>

      {/* Admin Modules Grid */}
      <div>
        <h3 className="text-lg font-bold text-white mb-4 flex items-center gap-2">
          <Layers className="w-5 h-5 text-brand-400" />
          Administrative Control Subsystems
        </h3>

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-5">
          {adminShortcuts.map((item, idx) => {
            const Icon = item.icon;
            return (
              <Link
                key={idx}
                to={item.path}
                className="bg-slate-900/60 border border-white/10 hover:border-brand-500/40 rounded-2xl p-6 backdrop-blur-xl group transition-all hover:-translate-y-1 hover:shadow-xl hover:shadow-black/40 flex flex-col justify-between"
              >
                <div className="space-y-3">
                  <div className={`w-10 h-10 rounded-xl ${item.bg} ${item.color} flex items-center justify-center border border-white/10 group-hover:scale-105 transition-transform`}>
                    <Icon className="w-5 h-5" />
                  </div>
                  <div>
                    <h4 className="text-base font-bold text-white group-hover:text-brand-300 transition-colors">
                      {item.title}
                    </h4>
                    <p className="text-xs text-slate-400 mt-1 leading-relaxed">
                      {item.desc}
                    </p>
                  </div>
                </div>

                <div className="mt-4 pt-4 border-t border-white/5 flex items-center justify-between text-xs font-semibold text-slate-400 group-hover:text-white transition-colors">
                  <span>Open Subsystem</span>
                  <ChevronRight className="w-4 h-4 text-slate-500 group-hover:text-brand-400 group-hover:translate-x-0.5 transition-all" />
                </div>
              </Link>
            );
          })}
        </div>
      </div>
    </AdminLayout>
  );
}


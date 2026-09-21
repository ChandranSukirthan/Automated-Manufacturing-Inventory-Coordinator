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
  ChevronRight,
  Zap,
  CheckCircle2,
  Boxes,
  Clock,
  Send
} from 'lucide-react';
import AdminLayout from '../../components/Layout/AdminLayout';
import adminService from '../../services/adminService';
import machineService from '../../services/machineService';
import inventoryService from '../../services/inventoryService';

export default function AdminDashboard() {
  const [stats, setStats] = useState({
    usersCount: 0,
    machinesCount: 0,
    workflowsCount: 0,
    systemHealth: null
  });
  const [floorAlerts, setFloorAlerts] = useState([]);
  const [recentWorkflows, setRecentWorkflows] = useState([]);
  const [deployingAlertId, setDeployingAlertId] = useState(null);
  const [actionFeedback, setActionFeedback] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    const fetchDashboardStats = async () => {
      setLoading(true);
      try {
        const [users, machines, workflows, health, alerts] = await Promise.all([
          adminService.getAllUsers(),
          machineService.getAll(),
          adminService.getAgentWorkflows(),
          adminService.getSystemHealth(),
          inventoryService.getAlerts().catch(() => [])
        ]);

        setStats({
          usersCount: users.length,
          machinesCount: machines.length,
          workflowsCount: workflows.length,
          systemHealth: health
        });
        setFloorAlerts(Array.isArray(alerts) ? alerts : []);
        setRecentWorkflows(Array.isArray(workflows) ? workflows.slice(0, 5) : []);
      } catch (err) {
        console.error(err);
        setError('Failed to aggregate administrative telemetry.');
      } finally {
        setLoading(false);
      }
    };

    fetchDashboardStats();
  }, []);

  const handleDeployReplenishment = async (alert) => {
    try {
      setDeployingAlertId(alert.id);
      setActionFeedback({ type: 'info', message: `Deploying Multi-Agent AI pipeline for SKU ${alert.sku}...` });

      const res = await inventoryService.triggerWorkflow(
        `Supervisor Approved Replenishment for ${alert.sku} (${alert.quantityRequested || 1000} units requested by Floor Worker)`,
        alert.sku,
        alert.quantityRequested || 1000
      );

      try {
        await inventoryService.updateAlertStatus(alert.id, 'Processing');
      } catch (err) {
        console.warn('Could not update alert status', err);
      }

      setActionFeedback({
        type: 'success',
        message: `Multi-Agent Pipeline launched! ${res.workflowId ? `Workflow ID: ${res.workflowId}. ` : ''}Draft Purchase Order generated and routed to Supply Chain Manager for approval.`
      });

      const [updatedAlerts, updatedWorkflows] = await Promise.all([
        inventoryService.getAlerts().catch(() => []),
        adminService.getAgentWorkflows().catch(() => [])
      ]);
      setFloorAlerts(Array.isArray(updatedAlerts) ? updatedAlerts : []);
      setRecentWorkflows(Array.isArray(updatedWorkflows) ? updatedWorkflows.slice(0, 5) : []);
    } catch (err) {
      console.error(err);
      setActionFeedback({
        type: 'error',
        message: err.response?.data?.message || err.message || 'Failed to dispatch AI replenishment pipeline.'
      });
    } finally {
      setDeployingAlertId(null);
    }
  };

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

      {/* Action Feedback Notification */}
      {actionFeedback && (
        <div className={`p-4 rounded-2xl border flex items-center justify-between gap-3 text-sm animate-fade-in ${
          actionFeedback.type === 'success' 
            ? 'bg-emerald-500/10 border-emerald-500/30 text-emerald-300' 
            : actionFeedback.type === 'error'
            ? 'bg-red-500/10 border-red-500/30 text-red-300'
            : 'bg-cyan-500/10 border-cyan-500/30 text-cyan-300'
        }`}>
          <div className="flex items-center gap-3">
            {actionFeedback.type === 'success' && <CheckCircle2 className="w-5 h-5 shrink-0 text-emerald-400" />}
            {actionFeedback.type === 'error' && <AlertTriangle className="w-5 h-5 shrink-0 text-red-400" />}
            {actionFeedback.type === 'info' && <Loader2 className="w-5 h-5 shrink-0 animate-spin text-cyan-400" />}
            <span>{actionFeedback.message}</span>
          </div>
          <button 
            onClick={() => setActionFeedback(null)}
            className="text-xs text-slate-400 hover:text-white px-2.5 py-1 rounded-lg bg-white/5 hover:bg-white/10 transition-colors"
          >
            Dismiss
          </button>
        </div>
      )}

      {/* Supervisor Live Floor Requests & Multi-Agent Action Center */}
      <div className="bg-slate-900/70 border border-brand-500/30 rounded-3xl p-6 sm:p-8 backdrop-blur-xl relative overflow-hidden shadow-2xl space-y-6">
        <div className="flex flex-col lg:flex-row lg:items-center justify-between gap-4 pb-6 border-b border-white/10">
          <div>
            <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-cyan-500/10 border border-cyan-500/30 text-cyan-300 text-xs font-semibold mb-2">
              <Zap className="w-3.5 h-3.5 text-cyan-400" />
              <span>Multi-Agent Dispatch & Supervision (Student 1 → Student 4 → Student 2)</span>
            </div>
            <h3 className="text-xl font-extrabold text-white tracking-tight flex items-center gap-2">
              Live Floor Stock Requests & Autonomous Action Center
            </h3>
            <p className="text-xs text-slate-400 mt-1">
              Floor Worker (Student 1) alerts and deficit signals requiring supervisor validation or multi-agent procurement dispatch.
            </p>
          </div>

          <div className="flex items-center gap-2">
            <Link
              to="/admin/agent-workflows"
              className="px-4 py-2 rounded-xl bg-white/5 hover:bg-white/10 border border-white/10 text-xs font-semibold text-slate-200 transition-all flex items-center gap-2"
            >
              <Bot className="w-4 h-4 text-brand-400" />
              <span>Inspect All Workflows ({stats.workflowsCount})</span>
            </Link>
          </div>
        </div>

        {/* Floor Alerts List */}
        {floorAlerts.length === 0 ? (
          <div className="p-8 rounded-2xl bg-slate-950/40 border border-emerald-500/20 text-center space-y-2">
            <CheckCircle2 className="w-8 h-8 text-emerald-400 mx-auto" />
            <h4 className="text-sm font-semibold text-emerald-300">Floor Operations Synchronized</h4>
            <p className="text-xs text-slate-400 max-w-md mx-auto">
              No pending low-stock alerts or unhandled material shortages from the factory floor.
            </p>
          </div>
        ) : (
          <div className="space-y-3">
            <div className="text-xs font-bold uppercase tracking-wider text-slate-400 flex items-center gap-2">
              <Boxes className="w-4 h-4 text-amber-400" />
              <span>Active Material Requisitions & Low Stock Signals ({floorAlerts.length})</span>
            </div>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              {floorAlerts.slice(0, 4).map((alert) => (
                <div
                  key={alert.id}
                  className="p-5 rounded-2xl bg-slate-950/60 border border-white/10 hover:border-brand-500/30 transition-all flex flex-col justify-between space-y-4"
                >
                  <div className="space-y-2">
                    <div className="flex items-center justify-between">
                      <span className="font-mono text-xs font-bold px-2 py-1 rounded bg-brand-500/20 text-brand-300 border border-brand-500/30">
                        {alert.sku}
                      </span>
                      <span className={`text-[11px] font-semibold px-2 py-0.5 rounded-full uppercase tracking-wider ${
                        alert.status?.toLowerCase() === 'pending'
                          ? 'bg-amber-500/20 text-amber-300 border border-amber-500/30'
                          : alert.status?.toLowerCase() === 'processing'
                          ? 'bg-blue-500/20 text-blue-300 border border-blue-500/30'
                          : 'bg-emerald-500/20 text-emerald-300 border border-emerald-500/30'
                      }`}>
                        {alert.status || 'Pending'}
                      </span>
                    </div>

                    <div className="text-xs text-slate-300 space-y-1">
                      <div className="flex justify-between">
                        <span className="text-slate-400">Packaging Type:</span>
                        <span className="font-medium text-slate-200">{alert.packagingType || 'Roll / Standard'}</span>
                      </div>
                      <div className="flex justify-between">
                        <span className="text-slate-400">Requested Quantity:</span>
                        <span className="font-bold text-amber-400">{(alert.quantityRequested || 1000).toLocaleString()} units</span>
                      </div>
                      <div className="flex justify-between text-slate-400 text-[11px]">
                        <span>Reported by:</span>
                        <span className="font-mono">{alert.workerId || 'Floor Worker'}</span>
                      </div>
                    </div>
                  </div>

                  <div className="pt-3 border-t border-white/5 flex items-center justify-between gap-3">
                    <div className="flex items-center gap-1.5 text-[11px] text-slate-500">
                      <Clock className="w-3.5 h-3.5" />
                      <span>{alert.timestamp ? new Date(alert.timestamp).toLocaleTimeString() : 'Recent'}</span>
                    </div>

                    <button
                      onClick={() => handleDeployReplenishment(alert)}
                      disabled={deployingAlertId === alert.id || alert.status?.toLowerCase() === 'processing'}
                      className="px-3.5 py-1.5 rounded-xl bg-gradient-to-r from-brand-600 to-cyan-600 hover:from-brand-500 hover:to-cyan-500 disabled:opacity-50 text-white text-xs font-semibold shadow-lg shadow-brand-600/20 flex items-center gap-1.5 transition-all hover:scale-[1.02] active:scale-[0.98]"
                    >
                      {deployingAlertId === alert.id ? (
                        <>
                          <Loader2 className="w-3.5 h-3.5 animate-spin" />
                          <span>Deploying AI...</span>
                        </>
                      ) : alert.status?.toLowerCase() === 'processing' ? (
                        <>
                          <CheckCircle2 className="w-3.5 h-3.5 text-blue-300" />
                          <span>In Agent Pipeline</span>
                        </>
                      ) : (
                        <>
                          <Send className="w-3.5 h-3.5" />
                          <span>Deploy Multi-Agent AI</span>
                        </>
                      )}
                    </button>
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}
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


import React, { useState, useEffect } from 'react';
import { 
  Bot, 
  Search, 
  CheckCircle2, 
  Clock, 
  AlertCircle, 
  Hourglass, 
  ShieldCheck, 
  ArrowRight, 
  Loader2, 
  RefreshCw,
  AlertTriangle,
  Play,
  Check,
  X,
  PlusCircle,
  Sparkles
} from 'lucide-react';
import AdminLayout from '../../components/Layout/AdminLayout';
import adminService from '../../services/adminService';

export default function AgentWorkflowsPage() {
  const [workflows, setWorkflows] = useState([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [error, setError] = useState('');
  const [successMsg, setSuccessMsg] = useState('');

  // Action states
  const [actionLoading, setActionLoading] = useState({}); // { [wfId]: 'approve' | 'reject' }

  // Trigger Modal
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [objective, setObjective] = useState('Replenish BoxPouch film because inventory is low.');
  const [customWfId, setCustomWfId] = useState('');
  const [triggerLoading, setTriggerLoading] = useState(false);

  const fetchWorkflows = async () => {
    setLoading(true);
    setError('');
    try {
      const data = await adminService.getAgentWorkflows();
      setWorkflows(data);
    } catch (err) {
      console.error(err);
      setError('Failed to fetch autonomous agent workflow pipelines.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchWorkflows();
  }, []);

  const handleApprove = async (workflowId) => {
    setActionLoading(prev => ({ ...prev, [workflowId]: 'approve' }));
    setError('');
    setSuccessMsg('');
    try {
      await adminService.approveWorkflow(workflowId);
      setSuccessMsg(`Workflow ${workflowId} approved successfully. Resumed execution.`);
      await fetchWorkflows();
    } catch (err) {
      console.error(err);
      setError(err.response?.data?.message || `Failed to approve workflow ${workflowId}.`);
    } finally {
      setActionLoading(prev => ({ ...prev, [workflowId]: null }));
    }
  };

  const handleReject = async (workflowId) => {
    setActionLoading(prev => ({ ...prev, [workflowId]: 'reject' }));
    setError('');
    setSuccessMsg('');
    try {
      await adminService.rejectWorkflow(workflowId);
      setSuccessMsg(`Workflow ${workflowId} has been rejected.`);
      await fetchWorkflows();
    } catch (err) {
      console.error(err);
      setError(err.response?.data?.message || `Failed to reject workflow ${workflowId}.`);
    } finally {
      setActionLoading(prev => ({ ...prev, [workflowId]: null }));
    }
  };

  const handleTriggerWorkflow = async (e) => {
    e.preventDefault();
    if (!objective.trim()) return;

    setTriggerLoading(true);
    setError('');
    setSuccessMsg('');
    try {
      const payload = {
        objective: objective.trim(),
        workflowId: customWfId.trim() || undefined
      };
      await adminService.triggerWorkflow(payload);
      setSuccessMsg('Planner/Coordinator Agent triggered successfully! Execution started.');
      setIsModalOpen(false);
      setObjective('Replenish BoxPouch film because inventory is low.');
      setCustomWfId('');
      await fetchWorkflows();
    } catch (err) {
      console.error(err);
      setError(err.response?.data?.message || 'Failed to dispatch workflow to Planner Agent.');
    } finally {
      setTriggerLoading(false);
    }
  };

  const getWorkflowStatusBadge = (status) => {
    switch (status) {
      case 0:
        return <span className="px-2.5 py-1 rounded-full text-xs font-semibold bg-blue-500/10 text-blue-400 border border-blue-500/20">RUNNING</span>;
      case 1:
        return <span className="px-2.5 py-1 rounded-full text-xs font-semibold bg-emerald-500/10 text-emerald-400 border border-emerald-500/20">COMPLETED</span>;
      case 2:
        return <span className="px-2.5 py-1 rounded-full text-xs font-semibold bg-red-500/10 text-red-400 border border-red-500/20">FAILED</span>;
      case 3:
        return <span className="px-2.5 py-1 rounded-full text-xs font-bold bg-amber-500/20 text-amber-300 border border-amber-500/30 animate-pulse">WAITING_FOR_APPROVAL</span>;
      default:
        return <span className="px-2.5 py-1 rounded-full text-xs font-semibold bg-slate-800 text-slate-300">UNKNOWN</span>;
    }
  };

  const getApprovalBadge = (approval) => {
    switch (approval) {
      case 0:
        return <span className="text-amber-400 font-semibold text-xs flex items-center gap-1"><Hourglass className="w-3.5 h-3.5" /> Pending</span>;
      case 1:
        return <span className="text-emerald-400 font-semibold text-xs flex items-center gap-1"><CheckCircle2 className="w-3.5 h-3.5" /> Approved</span>;
      case 2:
        return <span className="text-red-400 font-semibold text-xs flex items-center gap-1"><AlertCircle className="w-3.5 h-3.5" /> Rejected</span>;
      default:
        return <span className="text-slate-400 text-xs">None</span>;
    }
  };

  const filteredWorkflows = workflows.filter(w =>
    w.workflowId.toLowerCase().includes(search.toLowerCase()) ||
    w.objective.toLowerCase().includes(search.toLowerCase()) ||
    w.currentAgent?.toLowerCase().includes(search.toLowerCase())
  );

  return (
    <AdminLayout 
      title="Agent Workflow Monitor" 
      subtitle="Supervise multi-agent coordination, validation checkpoints, and autonomous decisions"
    >
      {/* Header Actions */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div className="relative flex-1 max-w-md">
          <Search className="w-4 h-4 text-slate-400 absolute left-3 top-1/2 -translate-y-1/2" />
          <input
            type="text"
            placeholder="Search by Workflow ID (e.g. WF-1001) or objective..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="w-full pl-9 pr-4 py-2.5 bg-slate-900/60 border border-white/10 rounded-xl text-sm text-white placeholder-slate-500 focus:ring-2 focus:ring-brand-500 focus:outline-none"
          />
        </div>

        <div className="flex items-center gap-3">
          <button
            onClick={() => setIsModalOpen(true)}
            className="flex items-center gap-2 px-4 py-2.5 bg-gradient-to-r from-brand-600 to-indigo-600 hover:from-brand-500 hover:to-indigo-500 text-white rounded-xl text-sm font-semibold transition-all shadow-lg shadow-brand-500/20"
          >
            <Sparkles className="w-4 h-4" />
            <span>Trigger AI Workflow</span>
          </button>

          <button
            onClick={fetchWorkflows}
            disabled={loading}
            className="flex items-center gap-2 px-4 py-2.5 bg-slate-800 hover:bg-slate-700 text-slate-200 rounded-xl border border-white/10 text-sm font-semibold transition-all shadow-sm shrink-0"
          >
            <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin text-brand-400' : ''}`} />
            <span>Refresh</span>
          </button>
        </div>
      </div>

      {/* Notifications */}
      {successMsg && (
        <div className="p-4 rounded-xl bg-emerald-500/10 border border-emerald-500/20 text-emerald-400 text-sm flex items-center justify-between gap-3">
          <div className="flex items-center gap-2">
            <CheckCircle2 className="w-5 h-5 shrink-0" />
            <span>{successMsg}</span>
          </div>
          <button onClick={() => setSuccessMsg('')} className="text-emerald-500 hover:text-white"><X className="w-4 h-4" /></button>
        </div>
      )}

      {error && (
        <div className="p-4 rounded-xl bg-red-500/10 border border-red-500/20 text-red-400 text-sm flex items-center justify-between gap-3">
          <div className="flex items-center gap-2">
            <AlertTriangle className="w-5 h-5 shrink-0" />
            <span>{error}</span>
          </div>
          <button onClick={() => setError('')} className="text-red-500 hover:text-white"><X className="w-4 h-4" /></button>
        </div>
      )}

      {/* Workflows Grid / Cards */}
      <div className="space-y-4">
        {loading ? (
          <div className="py-16 text-center text-slate-400 bg-slate-900/40 rounded-3xl border border-white/10">
            <Loader2 className="w-8 h-8 animate-spin mx-auto text-brand-400 mb-3" />
            <p className="text-sm">Polling active agent workflow traces...</p>
          </div>
        ) : filteredWorkflows.length === 0 ? (
          <div className="py-16 text-center text-slate-400 bg-slate-900/40 rounded-3xl border border-white/10">
            <Bot className="w-10 h-10 mx-auto mb-3 text-slate-600" />
            <p className="text-base font-semibold text-white">No agent workflows found</p>
            <p className="text-xs text-slate-400 mt-1">Click "Trigger AI Workflow" above to launch a new autonomous coordination pipeline.</p>
          </div>
        ) : (
          filteredWorkflows.map((wf) => {
            const isWaitingApproval = (wf.status === 3 || wf.approvalStatus === 0) && wf.status !== 1 && wf.status !== 2;
            const isApproveLoading = actionLoading[wf.workflowId] === 'approve';
            const isRejectLoading = actionLoading[wf.workflowId] === 'reject';

            return (
              <div 
                key={wf.id}
                className={`bg-slate-900/60 border rounded-3xl p-6 backdrop-blur-xl shadow-xl transition-all space-y-4 ${
                  isWaitingApproval 
                    ? 'border-amber-500/40 ring-1 ring-amber-500/20 shadow-amber-500/5' 
                    : 'border-white/10 hover:border-brand-500/30'
                }`}
              >
                {/* Top Row: Workflow ID, Agent, Status */}
                <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 pb-3 border-b border-white/10">
                  <div className="flex items-center gap-3">
                    <span className="font-mono text-base font-extrabold text-brand-400 bg-brand-500/10 px-3 py-1 rounded-xl border border-brand-500/20">
                      {wf.workflowId}
                    </span>
                    <div className="flex items-center gap-2 text-xs text-slate-300">
                      <span className="text-slate-500">Current Agent:</span>
                      <span className="font-semibold text-white bg-white/5 px-2.5 py-1 rounded-lg border border-white/5">
                        {wf.currentAgent || 'Orchestrator'}
                      </span>
                    </div>
                  </div>

                  <div className="flex items-center gap-3">
                    {getWorkflowStatusBadge(wf.status)}
                    <div className="hidden sm:block pl-3 border-l border-white/10">
                      {getApprovalBadge(wf.approvalStatus)}
                    </div>
                  </div>
                </div>

                {/* Objective */}
                <div>
                  <span className="text-xs uppercase tracking-wider font-semibold text-slate-500 block mb-1">Objective</span>
                  <p className="text-sm font-medium text-slate-100">{wf.objective}</p>
                </div>

                {/* Human Approval Action Box (Prominent for IT Admin) */}
                {isWaitingApproval && (
                  <div className="p-4 rounded-2xl bg-amber-500/10 border border-amber-500/30 flex flex-col sm:flex-row sm:items-center justify-between gap-4">
                    <div className="flex items-center gap-3">
                      <ShieldCheck className="w-5 h-5 text-amber-400 shrink-0" />
                      <div>
                        <span className="text-xs font-bold text-amber-300 uppercase tracking-wider block">IT Admin Approval Required</span>
                        <p className="text-xs text-slate-300 mt-0.5">High-impact procurement or schedule adjustment awaits human authorization before execution.</p>
                      </div>
                    </div>

                    <div className="flex items-center gap-2 shrink-0">
                      <button
                        onClick={() => handleApprove(wf.workflowId)}
                        disabled={isApproveLoading || isRejectLoading}
                        className="flex items-center gap-1.5 px-4 py-2 bg-emerald-600 hover:bg-emerald-500 text-white rounded-xl text-xs font-bold transition-all shadow-md shadow-emerald-600/20 disabled:opacity-50"
                      >
                        {isApproveLoading ? <Loader2 className="w-3.5 h-3.5 animate-spin" /> : <Check className="w-3.5 h-3.5" />}
                        <span>Approve & Execute</span>
                      </button>

                      <button
                        onClick={() => handleReject(wf.workflowId)}
                        disabled={isApproveLoading || isRejectLoading}
                        className="flex items-center gap-1.5 px-3 py-2 bg-red-600/20 hover:bg-red-600/30 text-red-300 rounded-xl border border-red-500/30 text-xs font-semibold transition-all disabled:opacity-50"
                      >
                        {isRejectLoading ? <Loader2 className="w-3.5 h-3.5 animate-spin" /> : <X className="w-3.5 h-3.5" />}
                        <span>Reject</span>
                      </button>
                    </div>
                  </div>
                )}

                {/* Outcome or details */}
                {wf.finalOutcome && (
                  <div className="p-3.5 rounded-xl bg-emerald-500/5 border border-emerald-500/20 text-xs text-slate-200">
                    <span className="font-semibold text-emerald-400 block mb-1">Final Outcome & Resolution:</span>
                    {wf.finalOutcome}
                  </div>
                )}

                {/* Bottom Row: Timestamps */}
                <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2 text-xs text-slate-400 pt-2 font-mono border-t border-white/5">
                  <span className="flex items-center gap-1.5">
                    <Clock className="w-3.5 h-3.5 text-slate-500" />
                    Started: {new Date(wf.startedAt).toLocaleString()}
                  </span>

                  {wf.completedAt ? (
                    <span className="flex items-center gap-1.5 text-emerald-400">
                      <CheckCircle2 className="w-3.5 h-3.5" />
                      Completed: {new Date(wf.completedAt).toLocaleString()}
                    </span>
                  ) : (
                    <span className="text-amber-400/80 font-sans">Awaiting final execution</span>
                  )}
                </div>
              </div>
            );
          })
        )}
      </div>

      {/* Trigger Workflow Modal */}
      {isModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/70 backdrop-blur-sm">
          <div className="bg-slate-900 border border-white/10 rounded-3xl w-full max-w-lg p-6 shadow-2xl space-y-5">
            <div className="flex items-center justify-between border-b border-white/10 pb-4">
              <div className="flex items-center gap-2.5">
                <div className="p-2 bg-brand-500/10 rounded-xl border border-brand-500/20 text-brand-400">
                  <Sparkles className="w-5 h-5" />
                </div>
                <div>
                  <h3 className="text-lg font-bold text-white">Trigger Planner Agent</h3>
                  <p className="text-xs text-slate-400">Dispatch an autonomous multi-agent operational objective</p>
                </div>
              </div>
              <button 
                onClick={() => setIsModalOpen(false)}
                className="text-slate-400 hover:text-white p-1 rounded-lg hover:bg-white/5 transition"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <form onSubmit={handleTriggerWorkflow} className="space-y-4">
              <div>
                <label className="text-xs font-semibold text-slate-300 block mb-1">Custom Workflow ID (Optional)</label>
                <input
                  type="text"
                  placeholder="e.g. WF-LIVE-2001 (auto-generated if empty)"
                  value={customWfId}
                  onChange={(e) => setCustomWfId(e.target.value)}
                  className="w-full px-4 py-2.5 bg-slate-950/60 border border-white/10 rounded-xl text-sm text-white placeholder-slate-500 focus:ring-2 focus:ring-brand-500 focus:outline-none"
                />
              </div>

              <div>
                <label className="text-xs font-semibold text-slate-300 block mb-1">Business Objective</label>
                <textarea
                  rows={3}
                  required
                  placeholder="Enter objective for the Planner Agent..."
                  value={objective}
                  onChange={(e) => setObjective(e.target.value)}
                  className="w-full px-4 py-2.5 bg-slate-950/60 border border-white/10 rounded-xl text-sm text-white placeholder-slate-500 focus:ring-2 focus:ring-brand-500 focus:outline-none"
                />
              </div>

              {/* Quick Presets */}
              <div>
                <span className="text-xs text-slate-400 block mb-1.5">Quick Presets:</span>
                <div className="flex flex-wrap gap-2">
                  <button
                    type="button"
                    onClick={() => setObjective("Replenish BoxPouch film because inventory is low.")}
                    className="text-xs px-2.5 py-1 bg-white/5 hover:bg-white/10 border border-white/10 rounded-lg text-slate-300 transition"
                  >
                    📦 Replenish BoxPouch
                  </button>
                  <button
                    type="button"
                    onClick={() => setObjective("Schedule urgent preventive overhaul for CNC Milling Machine 01.")}
                    className="text-xs px-2.5 py-1 bg-white/5 hover:bg-white/10 border border-white/10 rounded-lg text-slate-300 transition"
                  >
                    ⚙️ Machine Maintenance
                  </button>
                  <button
                    type="button"
                    onClick={() => setObjective("Reconcile shift output targets after raw material delivery bottleneck.")}
                    className="text-xs px-2.5 py-1 bg-white/5 hover:bg-white/10 border border-white/10 rounded-lg text-slate-300 transition"
                  >
                    📊 Reconcile Shift Target
                  </button>
                </div>
              </div>

              <div className="flex items-center justify-end gap-3 pt-4 border-t border-white/10">
                <button
                  type="button"
                  onClick={() => setIsModalOpen(false)}
                  className="px-4 py-2 text-sm font-semibold text-slate-300 hover:text-white rounded-xl transition"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={triggerLoading || !objective.trim()}
                  className="flex items-center gap-2 px-5 py-2.5 bg-gradient-to-r from-brand-600 to-indigo-600 hover:from-brand-500 hover:to-indigo-500 text-white rounded-xl text-sm font-bold transition shadow-lg shadow-brand-500/20 disabled:opacity-50"
                >
                  {triggerLoading ? <Loader2 className="w-4 h-4 animate-spin" /> : <Play className="w-4 h-4 fill-current" />}
                  <span>Dispatch Workflow</span>
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </AdminLayout>
  );
}

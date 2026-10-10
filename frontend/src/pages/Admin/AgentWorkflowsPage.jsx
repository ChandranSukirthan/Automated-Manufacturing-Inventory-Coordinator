import { formatColomboDate } from '../../utils/locale.js';
import ModalOverlay from '../../components/Common/ModalOverlay';
import { useState, useEffect } from 'react';
import { 
  Bot, 
  Search, 
  CheckCircle2, 
  Clock, 
  AlertCircle, 
  Hourglass, 
  ShieldCheck, 
  Loader2, 
  RefreshCw,
  AlertTriangle,
  Play,
  Check,
  X,
  Sparkles,
  Filter,
  SlidersHorizontal,
  ArrowUpDown
} from 'lucide-react';
import AdminLayout from '../../components/Layout/AdminLayout';
import machineService from '../../services/machineService';
import adminService from '../../services/adminService';

export default function AgentWorkflowsPage() {
  const [workflows, setWorkflows] = useState([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [error, setError] = useState('');
  const [successMsg, setSuccessMsg] = useState('');

  // Filter states
  const [statusFilter, setStatusFilter] = useState('ALL');
  const [typeFilter, setTypeFilter] = useState('ALL');
  const [approvalFilter, setApprovalFilter] = useState('ALL');
  const [sortOrder, setSortOrder] = useState('desc');

  // Action states
  const [actionLoading, setActionLoading] = useState({}); // { [wfId]: 'approve' | 'reject' }

  // Trigger Modal
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [objective, setObjective] = useState('Schedule preventive maintenance.');
  const [machines, setMachines] = useState([]);
  const [machineId, setMachineId] = useState('');
  useEffect(() => { machineService.getAll().then(setMachines).catch(() => setError('Could not load machines.')); }, []);
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
    const timer = setTimeout(() => {
      void fetchWorkflows();
    }, 0);
    return () => clearTimeout(timer);
  }, []);

  const handleApprove = async (workflowId) => {
    setActionLoading(prev => ({ ...prev, [workflowId]: 'approve' }));
    setError('');
    setSuccessMsg('');
    try {
      await adminService.approveWorkflow(workflowId);
      setSuccessMsg(`Workflow ${workflowId} approved successfully.`);
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
    if (!objective.trim() || !machineId) return;

    setTriggerLoading(true);
    setError('');
    setSuccessMsg('');
    try {
      const payload = {
        objective: `${objective.trim()} [MachineID: ${machineId}]`,
        workflowId: customWfId.trim() || undefined
      };
      await adminService.triggerWorkflow(payload);
      setSuccessMsg('Maintenance request created for IT Admin review.');
      setIsModalOpen(false);
      setObjective('Schedule preventive maintenance.');
      setCustomWfId('');
      await fetchWorkflows();
    } catch (err) {
      console.error(err);
      setError(err.response?.data?.message || 'Failed to dispatch workflow to Planner Agent.');
    } finally {
      setTriggerLoading(false);
    }
  };

  const getWorkflowStatusBadge = (status, approvalStatus, currentAgent) => {
    const isApproved = approvalStatus === 1 || approvalStatus === 'Approved';
    const isPendingApproval = status === 3 || status === 'WaitingForApproval';

    // If approval has already been granted, it is actively running in Payment / Dispatch
    if (isApproved && isPendingApproval) {
      return (
        <span className="px-2.5 py-1 rounded-full text-xs font-semibold bg-cyan-500/10 text-cyan-300 border border-cyan-500/20">
          IN DISPATCH (PAYMENT)
        </span>
      );
    }

    switch (status) {
      case 0:
      case 'Running':
        return <span className="px-2.5 py-1 rounded-full text-xs font-semibold bg-blue-500/10 text-blue-400 border border-blue-500/20">RUNNING</span>;
      case 1:
      case 'Completed':
        return <span className="px-2.5 py-1 rounded-full text-xs font-semibold bg-emerald-500/10 text-emerald-400 border border-emerald-500/20">COMPLETED</span>;
      case 2:
      case 'Failed':
        return <span className="px-2.5 py-1 rounded-full text-xs font-semibold bg-red-500/10 text-red-400 border border-red-500/20">FAILED</span>;
      case 3:
      case 'WaitingForApproval':
        return <span className="px-2.5 py-1 rounded-full text-xs font-bold bg-amber-500/20 text-amber-300 border border-amber-500/30 animate-pulse">WAITING_FOR_APPROVAL</span>;
      default:
        return <span className="px-2.5 py-1 rounded-full text-xs font-semibold bg-slate-800 text-slate-300">{status || 'UNKNOWN'}</span>;
    }
  };

  const getApprovalBadge = (approval) => {
    switch (approval) {
      case 0:
      case 'Pending':
        return <span className="text-amber-400 font-semibold text-xs flex items-center gap-1"><Hourglass className="w-3.5 h-3.5" /> Pending</span>;
      case 1:
      case 'Approved':
        return <span className="text-emerald-400 font-semibold text-xs flex items-center gap-1"><CheckCircle2 className="w-3.5 h-3.5" /> Approved</span>;
      case 2:
      case 'Rejected':
        return <span className="text-red-400 font-semibold text-xs flex items-center gap-1"><AlertCircle className="w-3.5 h-3.5" /> Rejected</span>;
      default:
        return <span className="text-slate-400 text-xs">{approval || 'None'}</span>;
    }
  };

  const normalizeStatus = (status, approvalStatus) => {
    const isApproved = approvalStatus === 1 || approvalStatus === 'Approved';
    if (isApproved && (status === 3 || status === 'WaitingForApproval')) {
      return 'RUNNING';
    }
    if (status === 0 || status === 'Running') return 'RUNNING';
    if (status === 1 || status === 'Completed') return 'COMPLETED';
    if (status === 2 || status === 'Failed') return 'FAILED';
    if (status === 3 || status === 'WaitingForApproval') return 'WAITING_FOR_APPROVAL';
    return String(status || '').toUpperCase();
  };

  const normalizeApproval = (approval) => {
    if (approval === 0 || approval === 'Pending') return 'Pending';
    if (approval === 1 || approval === 'Approved') return 'Approved';
    if (approval === 2 || approval === 'Rejected') return 'Rejected';
    return approval ? String(approval) : 'None';
  };

  const totalCount = workflows.length;
  const waitingCount = workflows.filter(w => normalizeStatus(w.status, w.approvalStatus) === 'WAITING_FOR_APPROVAL').length;
  const runningCount = workflows.filter(w => normalizeStatus(w.status, w.approvalStatus) === 'RUNNING').length;
  const completedCount = workflows.filter(w => normalizeStatus(w.status, w.approvalStatus) === 'COMPLETED').length;
  const failedCount = workflows.filter(w => normalizeStatus(w.status, w.approvalStatus) === 'FAILED').length;

  const availableTypes = Array.from(
    new Set(
      ['Procurement', 'Maintenance', 'Quality', ...workflows.map(w => w.workflowType).filter(Boolean)]
    )
  );

  const filteredWorkflows = workflows.filter(w => {
    const q = search.trim().toLowerCase();
    const matchesSearch = !q ||
      w.workflowId.toLowerCase().includes(q) ||
      (w.objective && w.objective.toLowerCase().includes(q)) ||
      (w.currentAgent && w.currentAgent.toLowerCase().includes(q)) ||
      (w.workflowType && w.workflowType.toLowerCase().includes(q));

    const matchesStatus = statusFilter === 'ALL' || normalizeStatus(w.status, w.approvalStatus) === statusFilter;
    const matchesType = typeFilter === 'ALL' || (w.workflowType || '').toLowerCase() === typeFilter.toLowerCase();
    const matchesApproval = approvalFilter === 'ALL' || normalizeApproval(w.approvalStatus).toLowerCase() === approvalFilter.toLowerCase();

    return matchesSearch && matchesStatus && matchesType && matchesApproval;
  }).sort((a, b) => {
    const timeA = new Date(a.startedAt || 0).getTime();
    const timeB = new Date(b.startedAt || 0).getTime();
    return sortOrder === 'asc' ? timeA - timeB : timeB - timeA;
  });

  const hasActiveFilters = search.trim() !== '' || statusFilter !== 'ALL' || typeFilter !== 'ALL' || approvalFilter !== 'ALL';

  const clearAllFilters = () => {
    setSearch('');
    setStatusFilter('ALL');
    setTypeFilter('ALL');
    setApprovalFilter('ALL');
    setSortOrder('desc');
  };

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
            <span>Request maintenance</span>
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

      {/* Interactive Quick-Action Status Chips */}
      <div className="flex items-center gap-2 overflow-x-auto pb-1 scrollbar-none">
        <button
          type="button"
          onClick={() => setStatusFilter('ALL')}
          className={`flex items-center gap-2 px-3.5 py-2 rounded-xl text-xs font-semibold transition-all shrink-0 cursor-pointer ${
            statusFilter === 'ALL'
              ? 'bg-brand-600 text-white shadow-md shadow-brand-600/20'
              : 'bg-slate-900/60 hover:bg-slate-800 text-slate-300 border border-white/10'
          }`}
        >
          <span>All Workflows</span>
          <span className={`px-2 py-0.5 rounded-full text-[10px] font-bold ${
            statusFilter === 'ALL' ? 'bg-white/20 text-white' : 'bg-slate-800 text-slate-400'
          }`}>
            {totalCount}
          </span>
        </button>

        <button
          type="button"
          onClick={() => setStatusFilter('WAITING_FOR_APPROVAL')}
          className={`flex items-center gap-2 px-3.5 py-2 rounded-xl text-xs font-semibold transition-all shrink-0 cursor-pointer ${
            statusFilter === 'WAITING_FOR_APPROVAL'
              ? 'bg-amber-500 text-slate-950 shadow-md shadow-amber-500/20 font-bold'
              : 'bg-slate-900/60 hover:bg-slate-800 text-amber-300 border border-amber-500/30'
          }`}
        >
          <Hourglass className="w-3.5 h-3.5" />
          <span>Needs Approval</span>
          <span className={`px-2 py-0.5 rounded-full text-[10px] font-bold ${
            statusFilter === 'WAITING_FOR_APPROVAL' ? 'bg-black/20 text-slate-950' : 'bg-amber-500/20 text-amber-300'
          }`}>
            {waitingCount}
          </span>
        </button>

        <button
          type="button"
          onClick={() => setStatusFilter('RUNNING')}
          className={`flex items-center gap-2 px-3.5 py-2 rounded-xl text-xs font-semibold transition-all shrink-0 cursor-pointer ${
            statusFilter === 'RUNNING'
              ? 'bg-blue-600 text-white shadow-md shadow-blue-600/20'
              : 'bg-slate-900/60 hover:bg-slate-800 text-blue-300 border border-blue-500/30'
          }`}
        >
          <Loader2 className={`w-3.5 h-3.5 ${runningCount > 0 ? 'animate-spin' : ''}`} />
          <span>Running</span>
          <span className={`px-2 py-0.5 rounded-full text-[10px] font-bold ${
            statusFilter === 'RUNNING' ? 'bg-white/20 text-white' : 'bg-blue-500/20 text-blue-300'
          }`}>
            {runningCount}
          </span>
        </button>

        <button
          type="button"
          onClick={() => setStatusFilter('COMPLETED')}
          className={`flex items-center gap-2 px-3.5 py-2 rounded-xl text-xs font-semibold transition-all shrink-0 cursor-pointer ${
            statusFilter === 'COMPLETED'
              ? 'bg-emerald-600 text-white shadow-md shadow-emerald-600/20'
              : 'bg-slate-900/60 hover:bg-slate-800 text-emerald-300 border border-emerald-500/30'
          }`}
        >
          <CheckCircle2 className="w-3.5 h-3.5" />
          <span>Completed</span>
          <span className={`px-2 py-0.5 rounded-full text-[10px] font-bold ${
            statusFilter === 'COMPLETED' ? 'bg-white/20 text-white' : 'bg-emerald-500/20 text-emerald-300'
          }`}>
            {completedCount}
          </span>
        </button>

        <button
          type="button"
          onClick={() => setStatusFilter('FAILED')}
          className={`flex items-center gap-2 px-3.5 py-2 rounded-xl text-xs font-semibold transition-all shrink-0 cursor-pointer ${
            statusFilter === 'FAILED'
              ? 'bg-red-600 text-white shadow-md shadow-red-600/20'
              : 'bg-slate-900/60 hover:bg-slate-800 text-red-300 border border-red-500/30'
          }`}
        >
          <AlertCircle className="w-3.5 h-3.5" />
          <span>Failed</span>
          <span className={`px-2 py-0.5 rounded-full text-[10px] font-bold ${
            statusFilter === 'FAILED' ? 'bg-white/20 text-white' : 'bg-red-500/20 text-red-300'
          }`}>
            {failedCount}
          </span>
        </button>
      </div>

      {/* Secondary Controls: Type, Approval, Sort, Summary */}
      <div className="flex flex-wrap items-center justify-between gap-3 p-3 bg-slate-900/40 rounded-2xl border border-white/5">
        <div className="flex flex-wrap items-center gap-2.5">
          {/* Workflow Type Selector */}
          <div className="flex items-center gap-1.5 text-xs text-slate-300">
            <Filter className="w-3.5 h-3.5 text-slate-400" />
            <span className="text-slate-400">Type:</span>
            <select
              value={typeFilter}
              onChange={(e) => setTypeFilter(e.target.value)}
              className="bg-slate-800 text-white text-xs rounded-xl px-2.5 py-1.5 border border-white/10 focus:ring-2 focus:ring-brand-500 focus:outline-none cursor-pointer"
            >
              <option value="ALL">All Types</option>
              {availableTypes.map((t) => (
                <option key={t} value={t}>{t}</option>
              ))}
            </select>
          </div>

          {/* Approval Status Selector */}
          <div className="flex items-center gap-1.5 text-xs text-slate-300">
            <span className="text-slate-400">Approval:</span>
            <select
              value={approvalFilter}
              onChange={(e) => setApprovalFilter(e.target.value)}
              className="bg-slate-800 text-white text-xs rounded-xl px-2.5 py-1.5 border border-white/10 focus:ring-2 focus:ring-brand-500 focus:outline-none cursor-pointer"
            >
              <option value="ALL">All Approvals</option>
              <option value="Pending">Pending</option>
              <option value="Approved">Approved</option>
              <option value="Rejected">Rejected</option>
            </select>
          </div>

          {/* Sort Order */}
          <div className="flex items-center gap-1.5 text-xs text-slate-300">
            <ArrowUpDown className="w-3.5 h-3.5 text-slate-400" />
            <select
              value={sortOrder}
              onChange={(e) => setSortOrder(e.target.value)}
              className="bg-slate-800 text-white text-xs rounded-xl px-2.5 py-1.5 border border-white/10 focus:ring-2 focus:ring-brand-500 focus:outline-none cursor-pointer"
            >
              <option value="desc">Newest First</option>
              <option value="asc">Oldest First</option>
            </select>
          </div>

          {/* Reset Filters button */}
          {hasActiveFilters && (
            <button
              type="button"
              onClick={clearAllFilters}
              className="flex items-center gap-1 px-2.5 py-1.5 rounded-xl text-xs font-semibold bg-slate-800 hover:bg-slate-700 text-slate-300 border border-white/10 transition-colors cursor-pointer"
            >
              <X className="w-3 h-3 text-slate-400" />
              <span>Reset</span>
            </button>
          )}
        </div>

        {/* Counter Summary */}
        <div className="text-xs text-slate-400 font-mono">
          Showing <span className="font-bold text-white">{filteredWorkflows.length}</span> of {totalCount} pipelines
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
            <p className="text-xs text-slate-400 mt-1">
              {hasActiveFilters 
                ? 'No pipelines match your active search or filter selection.'
                : 'Click "Request maintenance" above to launch a new autonomous coordination pipeline.'}
            </p>
            {hasActiveFilters && (
              <button
                type="button"
                onClick={clearAllFilters}
                className="mt-4 inline-flex items-center gap-1.5 px-3.5 py-2 rounded-xl text-xs font-semibold bg-slate-800 hover:bg-slate-700 text-brand-300 border border-white/10 transition-colors cursor-pointer"
              >
                <X className="w-3.5 h-3.5" />
                <span>Reset all filters</span>
              </button>
            )}
          </div>
        ) : (
          filteredWorkflows.map((wf) => {
            const isWaitingApproval =
              (wf.status === 3 || wf.status === 'WaitingForApproval') && 
              (wf.approvalStatus === 0 || wf.approvalStatus === 'Pending') &&
              wf.status !== 1 && wf.status !== 'Completed' &&
              wf.status !== 2 && wf.status !== 'Failed';
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
                {/* Top Row: Workflow ID, Type, Agent, Status */}
                <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 pb-3 border-b border-white/10">
                  <div className="flex flex-wrap items-center gap-2.5">
                    <span className="font-mono text-base font-extrabold text-brand-400 bg-brand-500/10 px-3 py-1 rounded-xl border border-brand-500/20">
                      {wf.workflowId}
                    </span>
                    {wf.workflowType && (
                      <span className="text-xs font-semibold text-indigo-300 bg-indigo-500/10 px-2.5 py-1 rounded-lg border border-indigo-500/20">
                        {wf.workflowType}
                      </span>
                    )}
                    <div className="flex items-center gap-2 text-xs text-slate-300">
                      <span className="text-slate-500">Current Agent:</span>
                      <span className="font-semibold text-white bg-white/5 px-2.5 py-1 rounded-lg border border-white/5">
                        {wf.currentAgent || 'Orchestrator'}
                      </span>
                    </div>
                  </div>

                  <div className="flex items-center gap-3">
                    {getWorkflowStatusBadge(wf.status, wf.approvalStatus, wf.currentAgent)}
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
                        <span className="text-xs font-bold text-amber-300 uppercase tracking-wider block">
                          {wf.workflowType === 'Maintenance'
                            ? 'IT Admin Approval Required'
                            : `${wf.workflowType || 'Agent'} Workflow Approval Required`}
                        </span>
                        <p className="text-xs text-slate-300 mt-0.5">
                          {wf.workflowType === 'Maintenance'
                            ? 'This machine maintenance request awaits IT Admin authorization.'
                            : 'This agentic workflow awaits IT Admin authorization. Approving authorizes the workflow proposal (payment settlement remains exclusively with Supply Chain Manager / Finance).'}
                        </p>
                      </div>
                    </div>

                    <div className="flex items-center gap-2 shrink-0">
                      <button
                        onClick={() => handleApprove(wf.workflowId)}
                        disabled={isApproveLoading || isRejectLoading}
                        className="flex items-center gap-1.5 px-4 py-2 bg-emerald-600 hover:bg-emerald-500 text-white rounded-xl text-xs font-bold transition-all shadow-md shadow-emerald-600/20 disabled:opacity-50 cursor-pointer"
                      >
                        {isApproveLoading ? <Loader2 className="w-3.5 h-3.5 animate-spin" /> : <Check className="w-3.5 h-3.5" />}
                        <span>{wf.workflowType === 'Maintenance' ? 'Authorize maintenance' : 'Authorize workflow'}</span>
                      </button>

                      <button
                        onClick={() => handleReject(wf.workflowId)}
                        disabled={isApproveLoading || isRejectLoading}
                        className="flex items-center gap-1.5 px-3 py-2 bg-red-600/20 hover:bg-red-600/30 text-red-300 rounded-xl border border-red-500/30 text-xs font-semibold transition-all disabled:opacity-50 cursor-pointer"
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
                    Started: {formatColomboDate(wf.startedAt, 'toLocaleString')}
                  </span>

                  {wf.completedAt ? (
                    <span className="flex items-center gap-1.5 text-emerald-400">
                      <CheckCircle2 className="w-3.5 h-3.5" />
                      Completed: {formatColomboDate(wf.completedAt, 'toLocaleString')}
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
        <ModalOverlay className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/70 backdrop-blur-sm">
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
              <label className="text-sm text-slate-300">Machine
                <select required value={machineId} onChange={e => setMachineId(e.target.value)} className="block w-full bg-slate-800 p-2 rounded">
                  <option value="">Choose machine</option>{machines.map(m => <option key={m.id} value={m.id}>{m.name} ({m.machineTag || m.id})</option>)}
                </select>
              </label>
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
                    onClick={() => setObjective("Schedule preventive maintenance.")}
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
                  disabled={triggerLoading || !objective.trim() || !machineId}
                  className="flex items-center gap-2 px-5 py-2.5 bg-gradient-to-r from-brand-600 to-indigo-600 hover:from-brand-500 hover:to-indigo-500 text-white rounded-xl text-sm font-bold transition shadow-lg shadow-brand-500/20 disabled:opacity-50"
                >
                  {triggerLoading ? <Loader2 className="w-4 h-4 animate-spin" /> : <Play className="w-4 h-4 fill-current" />}
                  <span>Dispatch Workflow</span>
                </button>
              </div>
            </form>
          </div>
        </ModalOverlay>
      )}
    </AdminLayout>
  );
}

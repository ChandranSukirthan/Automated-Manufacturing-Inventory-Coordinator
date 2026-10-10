import React, { useEffect, useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import AppLayout from '../../components/Layout/AppLayout';
import agentWorkflowService from '../../services/agentWorkflowService';
import { useAuth } from '../../context/useAuth';
import { parseErrorMessage } from '../../utils/errorHandler';
import { 
  Activity, 
  ArrowUpRight, 
  Bot, 
  CheckCircle2, 
  ChevronDown, 
  CircleAlert, 
  Clock3, 
  FileText, 
  Layers3, 
  RotateCcw, 
  Search, 
  ShieldCheck, 
  Sparkles, 
  X 
} from 'lucide-react';
import './workflow-monitor.css';

const statusLabels = { 
  WaitingForApproval: 'Awaiting approval', 
  Running: 'Running', 
  Failed: 'Failed', 
  Completed: 'Completed' 
};

export default function AgentWorkflowMonitor() {
  const { user } = useAuth();
  const isITAdmin = user && (user.role === 3 || user.role === '3' || user.role === 'ITAdmin');
  const isWorker = user && (user.role === 0 || user.role === '0' || user.role === 'FloorWorker');
  const isQA = user && (user.role === 2 || user.role === '2' || user.role === 'QualityInspector');
  const isManager = user && (user.role === 1 || user.role === '1' || user.role === 'SupplyChainManager');

  const [workflows, setWorkflows] = useState([]);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(true);
  const [retrying, setRetrying] = useState(null);

  // Filter States
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState('ALL'); // 'ALL' | 'WaitingForApproval' | 'Running' | 'Completed' | 'Failed'
  const [typeFilter, setTypeFilter] = useState('ALL'); // 'ALL' | 'Procurement' | 'Maintenance' | 'Quality'
  const [approvalFilter, setApprovalFilter] = useState('ALL'); // 'ALL' | 'Pending' | 'Approved' | 'Rejected'
  const [sortOrder, setSortOrder] = useState('desc'); // 'desc' | 'asc'

  useEffect(() => {
    let cancelled = false;
    async function load() {
      try { 
        const data = await agentWorkflowService.getWorkflows(); 
        if (!cancelled) { 
          setWorkflows(Array.isArray(data) ? data : []); 
          setError(''); 
        } 
      }
      catch (err) { 
        if (!cancelled) setError(parseErrorMessage(err, 'Could not load workflow status.')); 
      }
      finally { 
        if (!cancelled) setLoading(false); 
      }
    }
    void load(); 
    const interval = setInterval(load, 10000);
    return () => { 
      cancelled = true; 
      clearInterval(interval); 
    };
  }, []);

  async function retry(id) {
    setRetrying(id);
    try { 
      await agentWorkflowService.retry(id); 
      setWorkflows(await agentWorkflowService.getWorkflows()); 
    }
    catch (err) { 
      setError(parseErrorMessage(err, 'Could not retry workflow.')); 
    }
    finally { 
      setRetrying(null); 
    }
  }

  // Summary counts
  const counts = useMemo(() => {
    let running = 0;
    let waitingApproval = 0;
    let completed = 0;
    let failed = 0;

    workflows.forEach((w) => {
      const st = String(w.status || '');
      const appSt = String(w.approvalStatus || '');
      const isApproved = appSt === 'Approved' || appSt === '1';

      if (st === 'Running' || st === '0') {
        running += 1;
      } else if (st === 'WaitingForApproval' || st === '3') {
        if (!isApproved) {
          waitingApproval += 1;
        } else {
          running += 1;
        }
      } else if (st === 'Completed' || st === '1') {
        completed += 1;
      } else if (st === 'Failed' || st === '2') {
        failed += 1;
      }
    });

    return { 
      running, 
      waitingApproval, 
      completed, 
      failed, 
      total: workflows.length 
    };
  }, [workflows]);

  // Filtered & Sorted Workflows
  const filteredWorkflows = useMemo(() => {
    let result = [...workflows];

    // Search query
    if (search.trim()) {
      const q = search.trim().toLowerCase();
      result = result.filter((w) => {
        const id = (w.workflowId || '').toLowerCase();
        const obj = (w.objective || '').toLowerCase();
        const agent = (w.currentAgent || '').toLowerCase();
        const outcome = (w.finalOutcome || '').toLowerCase();
        const type = (w.workflowType || '').toLowerCase();
        const steps = (w.details?.completed_steps || []).join(' ').toLowerCase();
        return id.includes(q) || obj.includes(q) || agent.includes(q) || outcome.includes(q) || type.includes(q) || steps.includes(q);
      });
    }

    // Status filter
    if (statusFilter !== 'ALL') {
      result = result.filter((w) => {
        const st = String(w.status || '');
        const appSt = String(w.approvalStatus || '');
        const isApproved = appSt === 'Approved' || appSt === '1';

        if (statusFilter === 'WaitingForApproval') {
          return (st === 'WaitingForApproval' || st === '3') && !isApproved;
        }
        if (statusFilter === 'Running') {
          return st === 'Running' || st === '0' || ((st === 'WaitingForApproval' || st === '3') && isApproved);
        }
        if (statusFilter === 'Completed') {
          return st === 'Completed' || st === '1';
        }
        if (statusFilter === 'Failed') {
          return st === 'Failed' || st === '2';
        }
        return true;
      });
    }

    // Restrict Machine Maintenance workflows to ONLY IT Admin
    if (!isITAdmin) {
      result = result.filter((w) => {
        const wt = (w.workflowType || '').toLowerCase();
        const id = (w.workflowId || '').toLowerCase();
        return wt !== 'maintenance' && !id.startsWith('wf-maint');
      });
    }

    // Type filter
    if (typeFilter !== 'ALL') {
      result = result.filter((w) => {
        const wt = w.workflowType || (w.workflowId?.startsWith('WF-MAINT') ? 'Maintenance' : w.workflowId?.startsWith('WF-QA') ? 'Quality' : 'Procurement');
        return wt.toLowerCase() === typeFilter.toLowerCase();
      });
    }

    // Approval status filter
    if (approvalFilter !== 'ALL') {
      result = result.filter((w) => {
        const appSt = String(w.approvalStatus || '');
        if (approvalFilter === 'Pending') return appSt === 'Pending' || appSt === '0' || !w.approvalStatus;
        if (approvalFilter === 'Approved') return appSt === 'Approved' || appSt === '1';
        if (approvalFilter === 'Rejected') return appSt === 'Rejected' || appSt === '2';
        return true;
      });
    }

    // Sort order
    result.sort((a, b) => {
      const dateA = new Date(a.startedAt || a.createdAt || 0).getTime();
      const dateB = new Date(b.startedAt || b.createdAt || 0).getTime();
      return sortOrder === 'desc' ? dateB - dateA : dateA - dateB;
    });

    return result;
  }, [workflows, search, statusFilter, typeFilter, approvalFilter, sortOrder]);

  const resetFilters = () => {
    setSearch('');
    setStatusFilter('ALL');
    setTypeFilter('ALL');
    setApprovalFilter('ALL');
    setSortOrder('desc');
  };

  const hasActiveFilters = search.trim() !== '' || statusFilter !== 'ALL' || typeFilter !== 'ALL' || approvalFilter !== 'ALL' || sortOrder !== 'desc';

  return (
    <AppLayout 
      title="Agent workflows" 
      subtitle={
        isWorker
          ? "Your material replenishment requests and workflow history"
          : isQA
          ? "Quality-validated agent workflows and inspection holds"
          : isManager
          ? "Supply chain and replenishment agent workflows"
          : "Recorded execution stages and system-wide decisions"
      }
    >
      <div className="workflow-monitor">
        {/* Hero Section */}
        <section className="wm-hero">
          <div className="wm-hero-copy">
            <span className="wm-eyebrow"><Sparkles size={14} aria-hidden="true" /> AI OPERATIONS</span>
            <h2>Workflow command center</h2>
            <p>Follow each request from agent analysis to validation and approval. See what has finished and what needs attention.</p>
          </div>
          <Link to="/worker/replenishment" className="wm-button wm-button-primary">
            Request replenishment <ArrowUpRight size={17} aria-hidden="true" />
          </Link>
        </section>

        {/* Interactive Stats Cards */}
        <div className="wm-summary" aria-label="Workflow summary">
          {[
            { label: 'Recorded', key: 'ALL', count: counts.total, icon: Layers3, tone: 'neutral' },
            { label: 'Running', key: 'Running', count: counts.running, icon: Activity, tone: 'cyan' },
            { label: 'Awaiting approval', key: 'WaitingForApproval', count: counts.waitingApproval, icon: Clock3, tone: 'amber' },
            { label: 'Completed', key: 'Completed', count: counts.completed, icon: CheckCircle2, tone: 'emerald' },
            { label: 'Needs attention', key: 'Failed', count: counts.failed, icon: CircleAlert, tone: 'rose' }
          ].map(({ label, key, count, icon: Icon, tone }) => {
            const isActive = statusFilter === key;
            return (
              <button
                type="button"
                key={label}
                onClick={() => setStatusFilter(statusFilter === key && key !== 'ALL' ? 'ALL' : key)}
                className={`wm-stat wm-tone-${tone} cursor-pointer transition-all text-left ${
                  isActive ? 'ring-2 ring-cyan-400 bg-slate-800/90 shadow-lg' : 'hover:bg-slate-800/40'
                }`}
                title={`Filter by ${label}`}
              >
                <Icon size={19} aria-hidden="true" />
                <div>
                  <span>{label}</span>
                  <strong>{loading ? '—' : count}</strong>
                </div>
              </button>
            );
          })}
        </div>

        {/* Filter and Search Bar */}
        <div className="space-y-3 p-4 rounded-2xl bg-slate-900/60 border border-slate-800/80 mb-6">
          <div className="flex flex-col lg:flex-row items-stretch lg:items-center justify-between gap-3">
            {/* Search Input */}
            <div className="relative flex-1">
              <Search className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
              <input
                type="text"
                placeholder="Search by ID (e.g. WF-1001), objective, agent, or outcome..."
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                className="w-full pl-9 pr-8 py-2.5 bg-slate-950/80 border border-slate-800 rounded-xl text-xs sm:text-sm text-white placeholder-slate-500 focus:outline-none focus:border-cyan-500/50 focus:ring-1 focus:ring-cyan-500/50 transition-all"
              />
              {search && (
                <button
                  type="button"
                  onClick={() => setSearch('')}
                  className="absolute right-2.5 top-1/2 -translate-y-1/2 text-slate-400 hover:text-white"
                >
                  <X className="w-4 h-4" />
                </button>
              )}
            </div>

            {/* Dropdown Filters */}
            <div className="flex flex-wrap items-center gap-2">
              {/* Workflow Type */}
              <select
                value={typeFilter}
                onChange={(e) => setTypeFilter(e.target.value)}
                className="bg-slate-950/80 border border-slate-800 text-xs text-slate-300 rounded-xl px-3 py-2.5 focus:outline-none focus:border-cyan-500/50 cursor-pointer"
              >
                <option value="ALL">All Types</option>
                <option value="Procurement">Procurement</option>
                {isITAdmin && <option value="Maintenance">Maintenance</option>}
                <option value="Quality">Quality & Safety</option>
              </select>

              {/* Approval Status */}
              <select
                value={approvalFilter}
                onChange={(e) => setApprovalFilter(e.target.value)}
                className="bg-slate-950/80 border border-slate-800 text-xs text-slate-300 rounded-xl px-3 py-2.5 focus:outline-none focus:border-cyan-500/50 cursor-pointer"
              >
                <option value="ALL">All Approvals</option>
                <option value="Pending">Pending Approval</option>
                <option value="Approved">Approved</option>
                <option value="Rejected">Rejected</option>
              </select>

              {/* Sort Order */}
              <select
                value={sortOrder}
                onChange={(e) => setSortOrder(e.target.value)}
                className="bg-slate-950/80 border border-slate-800 text-xs text-slate-300 rounded-xl px-3 py-2.5 focus:outline-none focus:border-cyan-500/50 cursor-pointer"
              >
                <option value="desc">Newest First</option>
                <option value="asc">Oldest First</option>
              </select>

              {/* Reset */}
              {hasActiveFilters && (
                <button
                  type="button"
                  onClick={resetFilters}
                  className="flex items-center gap-1.5 px-3 py-2.5 bg-slate-800/80 hover:bg-slate-700/80 text-slate-300 rounded-xl text-xs font-semibold border border-slate-700/60 transition-all cursor-pointer"
                  title="Reset all filters"
                >
                  <RotateCcw className="w-3.5 h-3.5 text-cyan-400" />
                  <span>Reset</span>
                </button>
              )}
            </div>
          </div>

          {/* Quick Action Chips Row */}
          <div className="flex items-center gap-2 overflow-x-auto pb-1 scrollbar-none pt-2 border-t border-slate-800/60">
            <button
              type="button"
              onClick={() => setStatusFilter('ALL')}
              className={`flex items-center gap-2 px-3 py-1.5 rounded-xl text-xs font-semibold transition-all shrink-0 cursor-pointer ${
                statusFilter === 'ALL'
                  ? 'bg-cyan-600 text-white shadow-md shadow-cyan-600/20'
                  : 'bg-slate-950/50 hover:bg-slate-800 text-slate-300 border border-slate-800'
              }`}
            >
              <span>All Workflows</span>
              <span className={`px-1.5 py-0.5 rounded-full text-[10px] font-bold ${
                statusFilter === 'ALL' ? 'bg-white/20 text-white' : 'bg-slate-800 text-slate-400'
              }`}>
                {counts.total}
              </span>
            </button>

            <button
              type="button"
              onClick={() => setStatusFilter('WaitingForApproval')}
              className={`flex items-center gap-2 px-3 py-1.5 rounded-xl text-xs font-semibold transition-all shrink-0 cursor-pointer ${
                statusFilter === 'WaitingForApproval'
                  ? 'bg-amber-600 text-white shadow-md shadow-amber-600/20'
                  : 'bg-slate-950/50 hover:bg-slate-800 text-slate-300 border border-slate-800'
              }`}
            >
              <Clock3 className="w-3.5 h-3.5 text-amber-400" />
              <span>Needs Approval</span>
              <span className={`px-1.5 py-0.5 rounded-full text-[10px] font-bold ${
                statusFilter === 'WaitingForApproval' ? 'bg-white/20 text-white' : 'bg-slate-800 text-slate-400'
              }`}>
                {counts.waitingApproval}
              </span>
            </button>

            <button
              type="button"
              onClick={() => setStatusFilter('Running')}
              className={`flex items-center gap-2 px-3 py-1.5 rounded-xl text-xs font-semibold transition-all shrink-0 cursor-pointer ${
                statusFilter === 'Running'
                  ? 'bg-indigo-600 text-white shadow-md shadow-indigo-600/20'
                  : 'bg-slate-950/50 hover:bg-slate-800 text-slate-300 border border-slate-800'
              }`}
            >
              <Activity className="w-3.5 h-3.5 text-indigo-400" />
              <span>Running</span>
              <span className={`px-1.5 py-0.5 rounded-full text-[10px] font-bold ${
                statusFilter === 'Running' ? 'bg-white/20 text-white' : 'bg-slate-800 text-slate-400'
              }`}>
                {counts.running}
              </span>
            </button>

            <button
              type="button"
              onClick={() => setStatusFilter('Completed')}
              className={`flex items-center gap-2 px-3 py-1.5 rounded-xl text-xs font-semibold transition-all shrink-0 cursor-pointer ${
                statusFilter === 'Completed'
                  ? 'bg-emerald-600 text-white shadow-md shadow-emerald-600/20'
                  : 'bg-slate-950/50 hover:bg-slate-800 text-slate-300 border border-slate-800'
              }`}
            >
              <CheckCircle2 className="w-3.5 h-3.5 text-emerald-400" />
              <span>Completed</span>
              <span className={`px-1.5 py-0.5 rounded-full text-[10px] font-bold ${
                statusFilter === 'Completed' ? 'bg-white/20 text-white' : 'bg-slate-800 text-slate-400'
              }`}>
                {counts.completed}
              </span>
            </button>

            <button
              type="button"
              onClick={() => setStatusFilter('Failed')}
              className={`flex items-center gap-2 px-3 py-1.5 rounded-xl text-xs font-semibold transition-all shrink-0 cursor-pointer ${
                statusFilter === 'Failed'
                  ? 'bg-rose-600 text-white shadow-md shadow-rose-600/20'
                  : 'bg-slate-950/50 hover:bg-slate-800 text-slate-300 border border-slate-800'
              }`}
            >
              <CircleAlert className="w-3.5 h-3.5 text-rose-400" />
              <span>Needs Attention</span>
              <span className={`px-1.5 py-0.5 rounded-full text-[10px] font-bold ${
                statusFilter === 'Failed' ? 'bg-white/20 text-white' : 'bg-slate-800 text-slate-400'
              }`}>
                {counts.failed}
              </span>
            </button>

            <span className="text-xs text-slate-500 ml-auto hidden sm:inline whitespace-nowrap">
              Showing {filteredWorkflows.length} of {workflows.length} workflows
            </span>
          </div>
        </div>

        {error && (
          <p role="alert" className="wm-notice wm-notice-error">
            <CircleAlert size={18} aria-hidden="true" />
            {error}
          </p>
        )}

        {loading && (
          <div className="wm-empty" role="status">
            <Bot size={28} aria-hidden="true" />
            <h3>Loading workflow records…</h3>
            <p>Gathering the latest agent activity.</p>
          </div>
        )}

        {!loading && !filteredWorkflows.length && (
          <div className="wm-empty">
            <Layers3 size={28} aria-hidden="true" />
            <h3>{workflows.length ? 'No matching workflows' : 'No workflow records yet'}</h3>
            <p>
              {workflows.length 
                ? 'Try adjusting your search query or reset your filters.' 
                : 'Your replenishment requests will appear here once analysis begins.'}
            </p>
            {hasActiveFilters && (
              <button
                type="button"
                onClick={resetFilters}
                className="wm-button wm-button-secondary mt-3 inline-flex"
              >
                Reset all filters
              </button>
            )}
          </div>
        )}

        {/* Workflow Records Feed */}
        <div className="wm-records">
          {filteredWorkflows.map((w) => {
            const isApproved = w.approvalStatus === 'Approved' || w.approvalStatus === 1;
            const isWaitingApproval = (w.status === 'WaitingForApproval' || w.status === 3) && !isApproved;
            const isPaymentDispatch = (w.status === 'WaitingForApproval' || w.status === 3) && isApproved;

            let displayStatus = statusLabels[w.status] || w.status;
            let statusClass = `wm-status-${w.status}`;

            if (isPaymentDispatch) {
              displayStatus = 'In Dispatch (Payment)';
              statusClass = 'wm-status-Running';
            }

            return (
              <article key={w.workflowId} className="wm-card">
                <details className="wm-disclosure">
                  <summary className="wm-card-summary">
                    <header className="wm-card-header">
                      <div className="wm-identity">
                        <div className="wm-agent-icon">
                          <Bot size={22} aria-hidden="true" />
                        </div>
                        <div>
                          <div className="flex items-center gap-2">
                            <span className="wm-eyebrow">{w.workflowType || 'Procurement'} workflow</span>
                            {w.workflowType && (
                              <span className="text-[10px] font-bold px-2 py-0.5 rounded-md bg-indigo-500/10 border border-indigo-500/20 text-indigo-300">
                                {w.workflowType}
                              </span>
                            )}
                          </div>
                          <h3>{w.workflowId}</h3>
                        </div>
                      </div>

                      <div className="flex items-center gap-2">
                        <span className={`wm-status ${statusClass}`}>
                          <span aria-hidden="true" />
                          {displayStatus}
                        </span>
                        {w.approvalStatus && (
                          <span className={`px-2 py-0.5 rounded-md text-[11px] font-semibold border ${
                            w.approvalStatus === 'Approved' || w.approvalStatus === 1
                              ? 'bg-emerald-500/10 text-emerald-300 border-emerald-500/30'
                              : w.approvalStatus === 'Rejected' || w.approvalStatus === 2
                              ? 'bg-rose-500/10 text-rose-300 border-rose-500/30'
                              : 'bg-amber-500/10 text-amber-300 border-amber-500/30'
                          }`}>
                            {w.approvalStatus === 1 ? 'Approved' : w.approvalStatus === 2 ? 'Rejected' : w.approvalStatus === 0 ? 'Pending' : w.approvalStatus}
                          </span>
                        )}
                      </div>
                    </header>

                    <p className="wm-objective">{w.objective}</p>

                    <div className="wm-context">
                      <div>
                        <Activity size={16} aria-hidden="true" />
                        <span>Current stage<strong>{isPaymentDispatch ? 'Payment / Dispatch' : (w.currentAgent || 'Queued')}</strong></span>
                      </div>
                      <div>
                        <ShieldCheck size={16} aria-hidden="true" />
                        <span>Approval status<strong>{w.approvalStatus || 'Not yet recorded'}</strong></span>
                      </div>
                    </div>

                    <span className="wm-expand-hint">
                      <span className="wm-show-details">View full details</span>
                      <span className="wm-hide-details">Hide details</span>
                      <ChevronDown size={16} aria-hidden="true" />
                    </span>
                  </summary>

                  <div className="wm-expanded-details">
                    {isWaitingApproval && w.workflowType === 'Procurement' && (
                      <p className="wm-notice wm-notice-wait">
                        <Clock3 size={18} aria-hidden="true" />
                        {w.purchaseOrderId
                          ? 'Supply Chain Manager reviews the linked purchase order.'
                          : 'Resolve the findings or add a confirmed supplier quote before a purchase order can be created.'}
                      </p>
                    )}

                    {isPaymentDispatch && (
                      <p className="wm-notice wm-notice-wait text-cyan-200 border-cyan-500/30 bg-cyan-500/10">
                        <CheckCircle2 size={18} className="text-cyan-400" aria-hidden="true" />
                        Purchase order approved by manager. Order is currently processing dispatch and payment.
                      </p>
                    )}

                    {!!w.details?.completed_steps?.length && (
                      <section className="wm-execution">
                        <h4>Completed steps</h4>
                        <ul>
                          {(w.details?.completed_steps || []).map((step, i) => (
                            <li key={i}>
                              <CheckCircle2 size={17} aria-hidden="true" />
                              <span>{step}</span>
                            </li>
                          ))}
                        </ul>
                      </section>
                    )}

                    {(w.details?.errors || []).map((message, i) => (
                      <p key={i} className="wm-notice wm-notice-error">
                        <CircleAlert size={18} aria-hidden="true" />
                        <span>{message}</span>
                      </p>
                    ))}

                    {w.finalOutcome && (
                      <section className="wm-outcome">
                        <h4>Outcome</h4>
                        <p>{w.finalOutcome}</p>
                      </section>
                    )}

                    {(w.purchaseOrderId ||
                      (w.workflowType === 'Procurement' &&
                        (w.status === 'Failed' || (w.currentAgent === 'Supplier Review' && !w.purchaseOrderId)))) && (
                      <footer className="wm-card-actions">
                        {w.purchaseOrderId && (
                          <Link className="wm-button wm-button-secondary" to={`/purchase-orders/${w.purchaseOrderId}`}>
                            <FileText size={16} aria-hidden="true" />
                            View purchase order <ArrowUpRight size={16} aria-hidden="true" />
                          </Link>
                        )}
                        {w.workflowType === 'Procurement' &&
                          (w.status === 'Failed' || (w.currentAgent === 'Supplier Review' && !w.purchaseOrderId)) && (
                            <button
                              disabled={retrying === w.workflowId}
                              onClick={() => retry(w.workflowId)}
                              className="wm-button wm-button-secondary"
                            >
                              <RotateCcw size={16} aria-hidden="true" />
                              {retrying === w.workflowId ? 'Queuing…' : 'Retry analysis'}
                            </button>
                          )}
                      </footer>
                    )}
                  </div>
                </details>
              </article>
            );
          })}
        </div>
      </div>
    </AppLayout>
  );
}

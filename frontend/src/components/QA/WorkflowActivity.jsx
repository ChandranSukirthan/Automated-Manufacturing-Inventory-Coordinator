import React, { useEffect, useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { 
  Activity, 
  AlertTriangle, 
  ArrowRight, 
  Boxes, 
  CheckCircle2, 
  Clock, 
  ExternalLink, 
  Filter, 
  RotateCcw, 
  Search, 
  ShieldCheck, 
  Sparkles, 
  Target, 
  Wrench, 
  X 
} from 'lucide-react';
import dashboardService from '../../services/dashboardService';
import agentWorkflowService from '../../services/agentWorkflowService';
import { parseErrorMessage } from '../../utils/errorHandler';

export default function WorkflowActivity({ quality = false }) {
  const [workflows, setWorkflows] = useState([]);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(true);

  // Filters State
  const [searchQuery, setSearchQuery] = useState('');
  const [statusChip, setStatusChip] = useState('ALL'); // 'ALL' | 'PASSED' | 'PENDING' | 'FAILED'
  const [typeFilter, setTypeFilter] = useState('ALL'); // 'ALL' | 'Procurement' | 'Maintenance' | 'Quality'
  const [validationFilter, setValidationFilter] = useState('ALL'); // 'ALL' | 'Passed' | 'Failed' | 'PendingOrNotReached'
  const [sortOrder, setSortOrder] = useState('newest'); // 'newest' | 'oldest'
  const [limit, setLimit] = useState(10);

  useEffect(() => {
    let active = true;
    let timer;
    const refresh = async () => {
      try {
        const data = await (quality ? dashboardService.getAiValidationHistory() : agentWorkflowService.getWorkflows());
        if (active) { 
          setWorkflows(Array.isArray(data) ? data : []); 
          setError(''); 
        }
      } catch (err) {
        if (active) setError(parseErrorMessage(err, 'Unable to load workflow activity.'));
      } finally {
        if (active) { 
          setLoading(false); 
          timer = setTimeout(refresh, 10000); 
        }
      }
    };
    void refresh();
    return () => { 
      active = false; 
      clearTimeout(timer); 
    };
  }, [quality]);

  // Status Counts
  const counts = useMemo(() => {
    let passed = 0;
    let failed = 0;
    let pending = 0;

    workflows.forEach((w) => {
      const valid = quality ? w.isValid : w.validationResults?.isValid;
      const checked = quality ? w.validationExecuted : Boolean(w.validationResults?.supplierValidation || w.validationResults?.materialValidation);
      const res = checked ? (valid === true ? 'Passed' : valid === false ? 'Failed' : 'Pending') : 'Not reached';
      const st = String(w.workflowStatus || w.status || '');

      if (res === 'Passed' || st === 'Completed' || st === '1') {
        passed += 1;
      } else if (res === 'Failed' || st === 'Failed' || st === '2') {
        failed += 1;
      } else {
        pending += 1;
      }
    });

    return { passed, failed, pending };
  }, [workflows, quality]);

  // Filtered & Sorted Workflows
  const filteredWorkflows = useMemo(() => {
    let list = [...workflows];

    // Search query
    if (searchQuery.trim()) {
      const q = searchQuery.trim().toLowerCase();
      list = list.filter((w) => {
        const id = (w.workflowId || '').toLowerCase();
        const mat = (w.materialName || w.details?.material_name || w.materialId || w.details?.material_id || '').toLowerCase();
        const obj = (w.objective || '').toLowerCase();
        const reason = (w.rejectionReason || w.validationResults?.rejectionReason || w.details?.errors?.join(' ') || w.finalOutcome || '').toLowerCase();
        return id.includes(q) || mat.includes(q) || obj.includes(q) || reason.includes(q);
      });
    }

    // Status chip
    if (statusChip === 'PASSED') {
      list = list.filter((w) => {
        const valid = quality ? w.isValid : w.validationResults?.isValid;
        const checked = quality ? w.validationExecuted : Boolean(w.validationResults?.supplierValidation || w.validationResults?.materialValidation);
        const res = checked ? (valid === true ? 'Passed' : valid === false ? 'Failed' : 'Pending') : 'Not reached';
        const st = String(w.workflowStatus || w.status || '');
        return res === 'Passed' || st === 'Completed' || st === '1';
      });
    } else if (statusChip === 'FAILED') {
      list = list.filter((w) => {
        const valid = quality ? w.isValid : w.validationResults?.isValid;
        const checked = quality ? w.validationExecuted : Boolean(w.validationResults?.supplierValidation || w.validationResults?.materialValidation);
        const res = checked ? (valid === true ? 'Passed' : valid === false ? 'Failed' : 'Pending') : 'Not reached';
        const st = String(w.workflowStatus || w.status || '');
        return res === 'Failed' || st === 'Failed' || st === '2';
      });
    } else if (statusChip === 'PENDING') {
      list = list.filter((w) => {
        const valid = quality ? w.isValid : w.validationResults?.isValid;
        const checked = quality ? w.validationExecuted : Boolean(w.validationResults?.supplierValidation || w.validationResults?.materialValidation);
        const res = checked ? (valid === true ? 'Passed' : valid === false ? 'Failed' : 'Pending') : 'Not reached';
        const st = String(w.workflowStatus || w.status || '');
        return res !== 'Passed' && res !== 'Failed' && st !== 'Completed' && st !== 'Failed';
      });
    }

    // Type filter
    if (typeFilter !== 'ALL') {
      list = list.filter((w) => {
        const id = w.workflowId || '';
        const isMaint = w.workflowType === 'Maintenance' || id.startsWith('WF-MAINT');
        const isQual = quality || w.workflowType === 'Quality' || id.startsWith('WF-QA');
        const wfType = isMaint ? 'Maintenance' : isQual ? 'Quality' : 'Procurement';
        return wfType === typeFilter;
      });
    }

    // Validation filter
    if (validationFilter !== 'ALL') {
      list = list.filter((w) => {
        const valid = quality ? w.isValid : w.validationResults?.isValid;
        const checked = quality ? w.validationExecuted : Boolean(w.validationResults?.supplierValidation || w.validationResults?.materialValidation);
        const res = checked ? (valid === true ? 'Passed' : valid === false ? 'Failed' : 'Pending') : 'Not reached';
        if (validationFilter === 'Passed') return res === 'Passed';
        if (validationFilter === 'Failed') return res === 'Failed';
        if (validationFilter === 'PendingOrNotReached') return res === 'Not reached' || res === 'Pending';
        return true;
      });
    }

    // Sort order
    if (sortOrder === 'oldest') {
      list.reverse();
    }

    return list;
  }, [workflows, searchQuery, statusChip, typeFilter, validationFilter, sortOrder, quality]);

  const resetFilters = () => {
    setSearchQuery('');
    setStatusChip('ALL');
    setTypeFilter('ALL');
    setValidationFilter('ALL');
    setSortOrder('newest');
    setLimit(10);
  };

  const hasActiveFilters = searchQuery.trim() !== '' || statusChip !== 'ALL' || typeFilter !== 'ALL' || validationFilter !== 'ALL' || sortOrder !== 'oldest';

  const displayedWorkflows = filteredWorkflows.slice(0, limit);

  return (
    <section 
      className="my-6 rounded-3xl border border-slate-800/80 bg-slate-900/50 p-6 backdrop-blur-md shadow-xl space-y-5" 
      aria-label={quality ? 'AI validation activity' : 'Replenishment workflow activity'}
    >
      {/* Top Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 pb-4 border-b border-slate-800/80">
        <div className="flex items-center gap-3">
          <div className="p-2.5 rounded-xl bg-cyan-500/10 border border-cyan-500/20 text-cyan-400">
            {quality ? <ShieldCheck className="w-5 h-5" /> : <Activity className="w-5 h-5" />}
          </div>
          <div>
            <h2 className="text-base font-bold text-white tracking-tight">
              {quality ? 'AI validation activity' : 'Replenishment workflow activity'}
            </h2>
            <p className="text-xs text-slate-400 mt-0.5">
              {quality 
                ? 'Validation outcomes and workflows blocked before validation.' 
                : 'Only validated proposals proceed to order approval. Payment follows approval.'}
            </p>
          </div>
        </div>

        <div className="flex items-center gap-2">
          <span className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-semibold bg-slate-800/80 text-slate-300 border border-slate-700/60">
            <span className="w-2 h-2 rounded-full bg-cyan-400 animate-pulse" />
            Live Monitor ({workflows.length})
          </span>
        </div>
      </div>

      {/* Filter and Search Bar */}
      {!loading && workflows.length > 0 && (
        <div className="space-y-3 p-4 rounded-2xl bg-slate-950/40 border border-slate-800/70">
          {/* Row 1: Search + Dropdowns */}
          <div className="flex flex-col lg:flex-row items-stretch lg:items-center gap-2.5">
            {/* Search Input */}
            <div className="relative flex-1">
              <Search className="w-4 h-4 text-slate-400 absolute left-3 top-1/2 -translate-y-1/2" />
              <input
                type="text"
                placeholder="Filter by ID, material, machine, or objective..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                className="w-full pl-9 pr-8 py-2 bg-slate-900/90 border border-slate-800 rounded-xl text-xs text-white placeholder-slate-500 focus:outline-none focus:border-cyan-500/50 focus:ring-1 focus:ring-cyan-500/50 transition-all"
              />
              {searchQuery && (
                <button
                  type="button"
                  onClick={() => setSearchQuery('')}
                  className="absolute right-2.5 top-1/2 -translate-y-1/2 text-slate-400 hover:text-white"
                >
                  <X className="w-3.5 h-3.5" />
                </button>
              )}
            </div>

            {/* Dropdowns */}
            <div className="flex flex-wrap items-center gap-2">
              {/* Type Filter */}
              <select
                value={typeFilter}
                onChange={(e) => setTypeFilter(e.target.value)}
                className="bg-slate-900/90 border border-slate-800 text-xs text-slate-300 rounded-xl px-3 py-2 focus:outline-none focus:border-cyan-500/50 cursor-pointer"
              >
                <option value="ALL">All Types</option>
                <option value="Procurement">Procurement</option>
                <option value="Maintenance">Maintenance</option>
                <option value="Quality">Quality & Safety</option>
              </select>

              {/* Validation Filter - Specific labels to avoid collision with card exact strings */}
              <select
                value={validationFilter}
                onChange={(e) => setValidationFilter(e.target.value)}
                className="bg-slate-900/90 border border-slate-800 text-xs text-slate-300 rounded-xl px-3 py-2 focus:outline-none focus:border-cyan-500/50 cursor-pointer"
              >
                <option value="ALL">All Validations</option>
                <option value="Passed">Validation: Passed</option>
                <option value="Failed">Validation: Failed</option>
                <option value="PendingOrNotReached">Validation: Pending / Unreached</option>
              </select>

              {/* Sort */}
              <select
                value={sortOrder}
                onChange={(e) => setSortOrder(e.target.value)}
                className="bg-slate-900/90 border border-slate-800 text-xs text-slate-300 rounded-xl px-3 py-2 focus:outline-none focus:border-cyan-500/50 cursor-pointer"
              >
                <option value="newest">Newest First</option>
                <option value="oldest">Oldest First</option>
              </select>

              {/* Reset */}
              {hasActiveFilters && (
                <button
                  type="button"
                  onClick={resetFilters}
                  className="flex items-center gap-1.5 px-3 py-2 bg-slate-800/80 hover:bg-slate-700/80 text-slate-300 rounded-xl text-xs font-semibold border border-slate-700/60 transition-all cursor-pointer"
                  title="Reset all filters"
                >
                  <RotateCcw className="w-3 h-3 text-cyan-400" />
                  <span>Reset</span>
                </button>
              )}
            </div>
          </div>

          {/* Row 2: Status Quick Chips */}
          <div className="flex items-center gap-2 overflow-x-auto pb-1 scrollbar-none pt-1 border-t border-slate-800/60">
            <button
              type="button"
              onClick={() => setStatusChip('ALL')}
              className={`flex items-center gap-2 px-3 py-1.5 rounded-xl text-xs font-semibold transition-all shrink-0 cursor-pointer ${
                statusChip === 'ALL'
                  ? 'bg-cyan-600 text-white shadow-md shadow-cyan-600/20'
                  : 'bg-slate-900/80 hover:bg-slate-800 text-slate-300 border border-slate-800'
              }`}
            >
              <span>All Workflows</span>
              <span className={`px-1.5 py-0.5 rounded-full text-[10px] font-bold ${
                statusChip === 'ALL' ? 'bg-white/20 text-white' : 'bg-slate-800 text-slate-400'
              }`}>
                {workflows.length}
              </span>
            </button>

            <button
              type="button"
              onClick={() => setStatusChip('PASSED')}
              className={`flex items-center gap-2 px-3 py-1.5 rounded-xl text-xs font-semibold transition-all shrink-0 cursor-pointer ${
                statusChip === 'PASSED'
                  ? 'bg-emerald-600 text-white shadow-md shadow-emerald-600/20'
                  : 'bg-slate-900/80 hover:bg-slate-800 text-slate-300 border border-slate-800'
              }`}
            >
              <CheckCircle2 className="w-3.5 h-3.5 text-emerald-400" />
              <span>Passed Validation</span>
              <span className={`px-1.5 py-0.5 rounded-full text-[10px] font-bold ${
                statusChip === 'PASSED' ? 'bg-white/20 text-white' : 'bg-slate-800 text-slate-400'
              }`}>
                {counts.passed}
              </span>
            </button>

            <button
              type="button"
              onClick={() => setStatusChip('PENDING')}
              className={`flex items-center gap-2 px-3 py-1.5 rounded-xl text-xs font-semibold transition-all shrink-0 cursor-pointer ${
                statusChip === 'PENDING'
                  ? 'bg-amber-600 text-white shadow-md shadow-amber-600/20'
                  : 'bg-slate-900/80 hover:bg-slate-800 text-slate-300 border border-slate-800'
              }`}
            >
              <Clock className="w-3.5 h-3.5 text-amber-400" />
              <span>In Progress / Pending</span>
              <span className={`px-1.5 py-0.5 rounded-full text-[10px] font-bold ${
                statusChip === 'PENDING' ? 'bg-white/20 text-white' : 'bg-slate-800 text-slate-400'
              }`}>
                {counts.pending}
              </span>
            </button>

            <button
              type="button"
              onClick={() => setStatusChip('FAILED')}
              className={`flex items-center gap-2 px-3 py-1.5 rounded-xl text-xs font-semibold transition-all shrink-0 cursor-pointer ${
                statusChip === 'FAILED'
                  ? 'bg-rose-600 text-white shadow-md shadow-rose-600/20'
                  : 'bg-slate-900/80 hover:bg-slate-800 text-slate-300 border border-slate-800'
              }`}
            >
              <AlertTriangle className="w-3.5 h-3.5 text-rose-400" />
              <span>Failed / Rejected</span>
              <span className={`px-1.5 py-0.5 rounded-full text-[10px] font-bold ${
                statusChip === 'FAILED' ? 'bg-white/20 text-white' : 'bg-slate-800 text-slate-400'
              }`}>
                {counts.failed}
              </span>
            </button>

            <span className="text-[11px] text-slate-500 ml-auto hidden sm:inline whitespace-nowrap">
              Showing {displayedWorkflows.length} of {filteredWorkflows.length}
            </span>
          </div>
        </div>
      )}

      {error && (
        <p role="alert" className="p-3 rounded-xl bg-rose-500/10 border border-rose-500/20 text-sm text-rose-300">
          {error}
        </p>
      )}

      {loading ? (
        <div className="p-8 text-center text-sm text-slate-400">
          <Clock className="w-6 h-6 text-slate-500 animate-spin mx-auto mb-2" />
          <p>Loading workflows…</p>
        </div>
      ) : workflows.length === 0 ? (
        <div className="p-8 text-center text-sm text-slate-400 bg-slate-950/40 rounded-2xl border border-slate-800/60">
          <p>No workflows recorded yet.</p>
        </div>
      ) : filteredWorkflows.length === 0 ? (
        <div className="p-8 text-center bg-slate-950/40 rounded-2xl border border-slate-800/60 space-y-3">
          <Filter className="w-7 h-7 text-slate-500 mx-auto" />
          <p className="text-sm text-slate-300 font-semibold">No workflows match your selected filters</p>
          <p className="text-xs text-slate-500">Try adjusting your search query or reset filters.</p>
          <button
            type="button"
            onClick={resetFilters}
            className="px-4 py-2 bg-slate-800 hover:bg-slate-700 text-slate-200 text-xs font-semibold rounded-xl border border-slate-700 transition-all cursor-pointer"
          >
            Reset all filters
          </button>
        </div>
      ) : (
        <div className="space-y-4">
          {displayedWorkflows.map((workflow) => {
            const state = workflow.details || {};
            const validation = workflow.validationResults || {};
            const id = workflow.workflowId;
            const material = workflow.materialName || state.material_name || workflow.materialId || state.material_id || 'Material unavailable';
            const sku = workflow.materialId || state.material_id;
            const quantity = workflow.quantity ?? state.draft_po?.quantity ?? state.required_quantity ?? state.requested_quantity;
            const valid = quality ? workflow.isValid : validation.isValid;
            const checked = quality ? workflow.validationExecuted : Boolean(validation.supplierValidation || validation.materialValidation);
            const result = checked ? (valid === true ? 'Passed' : valid === false ? 'Failed' : 'Pending') : 'Not reached';
            const reason = workflow.rejectionReason || validation.rejectionReason || state.errors?.join(' ') || workflow.finalOutcome;

            const rawStatus = workflow.workflowStatus || workflow.status || 'Unknown';
            const isMaintenance = workflow.workflowType === 'Maintenance' || id?.startsWith('WF-MAINT');
            const isQualityWf = quality || workflow.workflowType === 'Quality' || id?.startsWith('WF-QA');
            const workflowTypeLabel = isMaintenance ? 'Maintenance' : isQualityWf ? 'Quality & Safety' : 'Procurement';

            // Status Badge Styling
            let statusBadgeClasses = 'bg-slate-800/80 text-slate-300 border-slate-700/80';
            let statusDotClasses = 'bg-slate-400';
            if (rawStatus === 'Completed' || rawStatus === 1) {
              statusBadgeClasses = 'bg-emerald-500/10 text-emerald-300 border-emerald-500/25';
              statusDotClasses = 'bg-emerald-400';
            } else if (rawStatus === 'Failed' || rawStatus === 2) {
              statusBadgeClasses = 'bg-rose-500/10 text-rose-300 border-rose-500/25';
              statusDotClasses = 'bg-rose-400';
            } else if (rawStatus === 'WaitingForApproval' || rawStatus === 3) {
              if (workflow.approvalStatus === 1 || workflow.approvalStatus === 'Approved') {
                statusBadgeClasses = 'bg-cyan-500/10 text-cyan-300 border-cyan-500/25';
                statusDotClasses = 'bg-cyan-400';
              } else {
                statusBadgeClasses = 'bg-amber-500/10 text-amber-300 border-amber-500/25';
                statusDotClasses = 'bg-amber-400 animate-pulse';
              }
            } else if (rawStatus === 'Running' || rawStatus === 0) {
              statusBadgeClasses = 'bg-indigo-500/10 text-indigo-300 border-indigo-500/25';
              statusDotClasses = 'bg-indigo-400 animate-pulse';
            }

            // Validation Badge Styling
            let validationBadgeClass = 'bg-amber-500/10 text-amber-300 border-amber-500/30';
            let validationDotClass = 'bg-amber-400';
            if (result === 'Passed') {
              validationBadgeClass = 'bg-emerald-500/10 text-emerald-300 border-emerald-500/30';
              validationDotClass = 'bg-emerald-400';
            } else if (result === 'Failed') {
              validationBadgeClass = 'bg-rose-500/10 text-rose-300 border-rose-500/30';
              validationDotClass = 'bg-rose-400';
            }

            // Reason Callout Styling
            let reasonBoxClass = 'bg-amber-500/10 border-amber-500/25 text-amber-200';
            let reasonIconBoxClass = 'bg-amber-500/20 text-amber-400';
            if (result === 'Failed' || rawStatus === 'Failed' || rawStatus === 2) {
              reasonBoxClass = 'bg-rose-500/10 border-rose-500/25 text-rose-200';
              reasonIconBoxClass = 'bg-rose-500/20 text-rose-400';
            } else if (result === 'Passed' || rawStatus === 'Completed' || rawStatus === 1) {
              reasonBoxClass = 'bg-emerald-500/10 border-emerald-500/25 text-emerald-200';
              reasonIconBoxClass = 'bg-emerald-500/20 text-emerald-400';
            }

            return (
              <article 
                key={id} 
                className="rounded-2xl border border-slate-800/90 bg-slate-950/60 hover:bg-slate-950/80 hover:border-slate-700/80 transition-all duration-200 p-5 text-sm text-slate-300 space-y-4 shadow-sm"
              >
                {/* Header: ID, Workflow Category, and Status */}
                <div className="flex flex-wrap items-center justify-between gap-3 pb-3 border-b border-slate-800/80">
                  <div className="flex flex-wrap items-center gap-2">
                    <strong className="font-mono text-xs sm:text-sm font-bold text-cyan-300 bg-cyan-950/50 border border-cyan-800/40 px-3 py-1 rounded-xl">
                      {id}
                    </strong>
                    <span className="text-[11px] font-semibold px-2.5 py-0.5 rounded-lg border bg-slate-900 border-slate-800 text-slate-300">
                      {workflowTypeLabel}
                    </span>
                  </div>

                  <span className={`px-2.5 py-1 rounded-lg text-xs font-semibold border flex items-center gap-1.5 ${statusBadgeClasses}`}>
                    <span className={`w-1.5 h-1.5 rounded-full ${statusDotClasses}`} />
                    <span>{rawStatus}</span>
                  </span>
                </div>

                {/* Scope & Validation Row */}
                <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                  {/* Scope / Material Details */}
                  <div className="p-3 rounded-xl bg-slate-900/50 border border-slate-800/60 flex items-start gap-3">
                    <div className="p-2 rounded-lg bg-slate-800/60 text-slate-300 shrink-0">
                      {isMaintenance ? <Wrench className="w-4 h-4 text-amber-400" /> : <Boxes className="w-4 h-4 text-cyan-400" />}
                    </div>
                    <div className="space-y-0.5 min-w-0">
                      <span className="text-[10px] font-bold uppercase tracking-wider text-slate-500 block">
                        {isMaintenance ? 'Maintenance Target' : 'Target Resource & Volume'}
                      </span>
                      <p className="text-xs sm:text-sm font-medium text-slate-200">
                        {material}{sku && material !== sku ? ` (${sku})` : ''} · Quantity: {quantity ?? 'Unavailable'} {workflow.unit || state.unit || ''}
                      </p>
                    </div>
                  </div>

                  {/* Validation Result */}
                  <div className="p-3 rounded-xl bg-slate-900/50 border border-slate-800/60 flex items-start gap-3">
                    <div className="p-2 rounded-lg bg-slate-800/60 text-slate-300 shrink-0">
                      <ShieldCheck className="w-4 h-4 text-indigo-400" />
                    </div>
                    <div className="space-y-1 min-w-0">
                      <span className="text-[10px] font-bold uppercase tracking-wider text-slate-500 block">
                        Safety & AI Verification
                      </span>
                      <div className="flex flex-wrap items-center gap-2">
                        <span className="text-xs text-slate-400">Validation:</span>
                        <strong className={`px-2 py-0.5 rounded-md text-xs font-bold border inline-flex items-center gap-1.5 ${validationBadgeClass}`}>
                          <span className={`w-1.5 h-1.5 rounded-full ${validationDotClass}`} />
                          {result}
                        </strong>
                        {workflow.qualitySafetyStatus && (
                          <span className="text-xs text-slate-400">
                            · Safety: <span className="font-semibold text-slate-200">{workflow.qualitySafetyStatus}</span>
                          </span>
                        )}
                      </div>
                    </div>
                  </div>
                </div>

                {/* Multiple Items list if applicable */}
                {workflow.items?.length > 1 && (
                  <div className="p-3 rounded-xl bg-slate-900/40 border border-slate-800/60 space-y-2">
                    <span className="text-[10px] font-bold uppercase tracking-wider text-slate-500 block">
                      Itemized Manifest ({workflow.items.length} items)
                    </span>
                    <ul className="grid grid-cols-1 sm:grid-cols-2 gap-2 text-xs">
                      {workflow.items.map((item, index) => (
                        <li 
                          key={`${item.materialId}-${index}`}
                          className="p-2 rounded-lg bg-slate-900/90 border border-slate-800/80 text-slate-300 flex items-center justify-between"
                        >
                          <span className="font-medium text-slate-200 truncate">{item.materialName || item.materialId}</span>
                          <span className="font-mono text-cyan-300 font-semibold shrink-0 ml-2">{item.quantity} {item.unit}</span>
                        </li>
                      ))}
                    </ul>
                  </div>
                )}

                {/* Operational Objective */}
                {workflow.objective && (
                  <div className="p-3 rounded-xl bg-slate-900/40 border border-slate-800/60 text-xs text-slate-300 flex items-start gap-2.5">
                    <Target className="w-4 h-4 text-cyan-400 shrink-0 mt-0.5" />
                    <div className="space-y-0.5 min-w-0">
                      <span className="text-[10px] font-bold uppercase tracking-wider text-slate-500 block">
                        Operational Objective
                      </span>
                      <p className="text-slate-200 leading-relaxed font-medium">{workflow.objective}</p>
                    </div>
                  </div>
                )}

                {/* AI Reasoning / Decision Outcome Callout */}
                {reason && (
                  <div className={`p-3.5 rounded-xl border flex items-start gap-3 text-xs leading-relaxed ${reasonBoxClass}`}>
                    <div className={`p-1.5 rounded-lg shrink-0 ${reasonIconBoxClass}`}>
                      {result === 'Failed' || rawStatus === 'Failed' || rawStatus === 2 ? (
                        <AlertTriangle className="w-4 h-4" />
                      ) : result === 'Passed' || rawStatus === 'Completed' || rawStatus === 1 ? (
                        <CheckCircle2 className="w-4 h-4" />
                      ) : (
                        <Sparkles className="w-4 h-4" />
                      )}
                    </div>
                    <div className="space-y-0.5 min-w-0 flex-1">
                      <span className="text-[10px] font-bold uppercase tracking-wider block opacity-75">
                        {result === 'Failed' || rawStatus === 'Failed' || rawStatus === 2 
                          ? 'Rejection Reason / Blocked Checkpoint' 
                          : 'AI Resolution & Agent Outcome'}
                      </span>
                      <p className="font-medium text-slate-100">{reason}</p>
                    </div>
                  </div>
                )}

                {/* Action Footer */}
                <div className="pt-3 border-t border-slate-800/80 flex flex-wrap items-center justify-between gap-3">
                  {quality ? (
                    <Link 
                      className="inline-flex items-center gap-1.5 px-3.5 py-1.5 rounded-xl bg-cyan-500/15 border border-cyan-500/30 text-cyan-300 text-xs font-bold hover:bg-cyan-500/25 transition-all shadow-sm" 
                      to={`/quality/ai-validation?workflowId=${encodeURIComponent(id)}`}
                    >
                      <span>Inspect validation</span>
                      <ExternalLink className="w-3.5 h-3.5" />
                    </Link>
                  ) : workflow.purchaseOrderId ? (
                    <Link 
                      className="inline-flex items-center gap-1.5 px-3.5 py-1.5 rounded-xl bg-emerald-500/15 border border-emerald-500/30 text-emerald-300 text-xs font-bold hover:bg-emerald-500/25 transition-all shadow-sm" 
                      to={`/purchase-orders/${workflow.purchaseOrderId}`}
                    >
                      <span>Review purchase order</span>
                      <ArrowRight className="w-3.5 h-3.5" />
                    </Link>
                  ) : (
                    <div className="flex items-center gap-2 text-xs text-slate-400">
                      <Clock className="w-3.5 h-3.5 text-slate-500 shrink-0" />
                      <span>
                        No purchase order yet. {workflow.status === 'Failed' ? 'Resolve the failure before starting a new request.' : 'Waiting for a validated draft.'}
                      </span>
                    </div>
                  )}
                </div>
              </article>
            );
          })}

          {/* Show More Pagination Button */}
          {filteredWorkflows.length > limit && (
            <div className="text-center pt-2">
              <button
                type="button"
                onClick={() => setLimit((prev) => prev + 10)}
                className="px-4 py-2 rounded-xl bg-slate-800/80 hover:bg-slate-700 text-slate-300 text-xs font-semibold border border-slate-700 transition-all cursor-pointer shadow-sm"
              >
                Show more ({filteredWorkflows.length - limit} remaining)
              </button>
            </div>
          )}
        </div>
      )}

      {quality && (
        <div className="pt-2">
          <Link 
            to="/quality/ai-validation" 
            className="inline-flex items-center gap-1.5 text-xs font-bold text-cyan-400 hover:text-cyan-300 transition-colors"
          >
            <span>View full validation history</span>
            <ArrowRight className="w-3.5 h-3.5" />
          </Link>
        </div>
      )}
    </section>
  );
}

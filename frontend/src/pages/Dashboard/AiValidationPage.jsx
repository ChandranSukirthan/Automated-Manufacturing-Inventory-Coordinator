import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import {
  ShieldCheck,
  ShieldAlert,
  AlertTriangle,
  History,
  Activity,
  CheckCircle2,
  ChevronDown,
  ChevronUp,
  Loader2,
  Sparkles,
  RefreshCw,
  LayoutDashboard,
  FileText
} from 'lucide-react';
import dashboardService from '../../services/dashboardService';
import { parseErrorMessage } from '../../utils/errorHandler';
import EmptyState from '../../components/QA/EmptyState';

const displayValidationValue = (value) =>
  value === null || value === undefined || value === '' ? 'Unavailable' : String(value);

export default function AiValidationPage() {
  const navigate = useNavigate();
  const [aiValidation, setAiValidation] = useState(null);
  const [aiValidationLoading, setAiValidationLoading] = useState(true);
  const [aiValidationError, setAiValidationError] = useState('');

  const [aiValidationHistory, setAiValidationHistory] = useState([]);
  const [historyLoading, setHistoryLoading] = useState(true);
  const [historyError, setHistoryError] = useState('');

  const [expandedReasons, setExpandedReasons] = useState({});
  const [expandedRows, setExpandedRows] = useState({});

  // Manual Resolution Modal State
  const [resolveModalOpen, setResolveModalOpen] = useState(false);
  const [selectedWorkflow, setSelectedWorkflow] = useState(null);
  const [resolutionNote, setResolutionNote] = useState('');
  const [releaseQuarantineCheck, setReleaseQuarantineCheck] = useState(true);
  const [resolving, setResolving] = useState(false);
  const [resolveError, setResolveError] = useState('');
  const [resolveSuccess, setResolveSuccess] = useState('');

  const toggleExpand = (id) => {
    setExpandedReasons((prev) => ({
      ...prev,
      [id]: !prev[id]
    }));
  };

  const toggleRowExpand = (id) => {
    setExpandedRows((prev) => ({
      ...prev,
      [id]: !prev[id]
    }));
  };

  const loadAiValidation = async () => {
    setAiValidationLoading(true);
    setAiValidationError('');
    try {
      const result = await dashboardService.getAiValidation();
      setAiValidation(result ?? null);
    } catch (err) {
      setAiValidation(null);
      setAiValidationError(
        err.response?.status === 404
          ? 'AI Validation & Safety results are unavailable (HTTP 404).'
          : parseErrorMessage(err, 'Unable to load AI Validation & Safety results.')
      );
    } finally {
      setAiValidationLoading(false);
    }
  };

  const loadAiValidationHistory = async () => {
    setHistoryLoading(true);
    setHistoryError('');
    try {
      const historyData = await dashboardService.getAiValidationHistory();
      setAiValidationHistory(Array.isArray(historyData) ? historyData : []);
    } catch (err) {
      setAiValidationHistory([]);
      setHistoryError(parseErrorMessage(err, 'Unable to load Validation/Safety assessment history.'));
    } finally {
      setHistoryLoading(false);
    }
  };

  const refreshAll = () => {
    loadAiValidation();
    loadAiValidationHistory();
  };

  useEffect(() => {
    refreshAll();
  }, []);

  const openResolveModal = (wf) => {
    setSelectedWorkflow(wf);
    setResolutionNote('');
    setReleaseQuarantineCheck(true);
    setResolveError('');
    setResolveModalOpen(true);
  };

  const handleResolveSubmit = async (e) => {
    e.preventDefault();
    if (!selectedWorkflow || !resolutionNote.trim()) {
      setResolveError('A manual resolution note is required.');
      return;
    }
    setResolving(true);
    setResolveError('');
    try {
      await dashboardService.resolveAiValidation(selectedWorkflow.workflowId, {
        note: resolutionNote.trim(),
        releaseQuarantine: releaseQuarantineCheck
      });
      setResolveModalOpen(false);
      setResolveSuccess(`Workflow ${selectedWorkflow.workflowId} successfully resolved.`);
      setTimeout(() => setResolveSuccess(''), 5000);
      refreshAll();
    } catch (err) {
      setResolveError(parseErrorMessage(err, 'Failed to submit manual resolution.'));
    } finally {
      setResolving(false);
    }
  };

  return (
    <div className="p-6 lg:p-8 max-w-7xl mx-auto space-y-8">
      {/* Page Header */}
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between border-b border-slate-800 pb-6">
        <div>
          <div className="flex items-center gap-2">
            <span className="text-purple-400 uppercase tracking-widest text-xs font-bold">
              Quality Assurance
            </span>
            <span className="text-slate-600">•</span>
            <span className="text-cyan-400 text-xs font-semibold flex items-center gap-1">
              <Sparkles className="w-3.5 h-3.5 text-cyan-400" />
              Safety &amp; Compliance Agent
            </span>
          </div>
          <h1 className="text-3xl font-extrabold text-white tracking-tight mt-1">
            AI Validation &amp; Safety
          </h1>
          <p className="text-sm text-slate-400 mt-1">
            Authoritative assessment portal, safety compliance diagnostics, and persisted quality audit trails.
          </p>
        </div>

        {/* Action Button Group */}
        <div className="flex flex-wrap items-center gap-3">
          <button
            onClick={refreshAll}
            disabled={aiValidationLoading || historyLoading}
            className="px-4 py-2.5 rounded-xl border border-slate-700 bg-slate-900/60 text-slate-200 text-sm font-medium hover:bg-slate-800 hover:text-white transition-all shadow-sm flex items-center gap-2 disabled:opacity-50"
          >
            <RefreshCw className={`w-4 h-4 ${(aiValidationLoading || historyLoading) ? 'animate-spin' : ''}`} />
            <span>Refresh Live Data</span>
          </button>
          <button
            onClick={() => navigate('/quality')}
            className="px-4 py-2.5 rounded-xl border border-purple-500/40 bg-purple-500/10 text-purple-300 text-sm font-medium hover:bg-purple-500/20 transition-all shadow-sm flex items-center gap-2"
          >
            <LayoutDashboard className="w-4 h-4" />
            <span>QA Dashboard</span>
          </button>
        </div>
      </div>

      {/* Success Notification Banner */}
      {resolveSuccess && (
        <div className="rounded-2xl border border-emerald-500/30 bg-emerald-500/10 p-4 text-emerald-200 flex items-center gap-3 animate-in fade-in">
          <CheckCircle2 className="w-5 h-5 text-emerald-400 shrink-0" />
          <span className="text-sm font-medium">{resolveSuccess}</span>
        </div>
      )}

      {/* SECTION 1 & 2: LATEST VALIDATION/SAFETY ASSESSMENT & AUTOMATED CHECKS */}
      <section className="rounded-3xl border border-slate-800 bg-slate-900/60 p-6 backdrop-blur-sm space-y-6">
        <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between border-b border-slate-800/80 pb-4">
          <div>
            <h2 className="text-lg font-bold text-white tracking-tight">AI Validation &amp; Safety</h2>
            <p className="text-xs text-slate-400 mt-0.5">Latest Validation/Safety Agent assessment</p>
          </div>
          <div className="flex items-center gap-2">
            <span className="inline-flex items-center gap-1.5 rounded-full border border-cyan-500/30 bg-cyan-500/10 px-3 py-1 text-xs font-medium text-cyan-300">
              <Activity className="w-3.5 h-3.5 text-cyan-300 animate-pulse" />
              Real-time PostgreSQL Feed
            </span>
          </div>
        </div>

        {aiValidationLoading ? (
          <div className="flex items-center justify-center gap-3 py-12 text-slate-400" role="status" aria-live="polite">
            <Loader2 className="w-6 h-6 animate-spin text-cyan-300" />
            <span className="text-sm">Fetching authoritative assessment from agent engine...</span>
          </div>
        ) : aiValidationError ? (
          <div className="rounded-2xl border border-rose-500/30 bg-rose-500/10 p-4 text-rose-200 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
            <div className="flex items-center gap-3">
              <AlertTriangle className="w-5 h-5 text-rose-400 shrink-0" />
              <span className="text-sm font-medium">{aiValidationError}</span>
            </div>
            <button
              onClick={loadAiValidation}
              className="text-xs font-semibold underline hover:text-rose-100 sm:shrink-0"
            >
              Retry
            </button>
          </div>
        ) : !aiValidation ? (
          <EmptyState
            icon={ShieldAlert}
            title="No assessment available"
            description="The API did not return a Validation/Safety Agent assessment."
            actionLabel="Retry"
            onAction={loadAiValidation}
          />
        ) : (
          <div className="space-y-6">
            {/* Manual Review Required Banner (When Quarantine Active / Required and Unresolved) */}
            {(aiValidation.qualitySafetyStatus === 'QUARANTINE_REQUIRED' || aiValidation.qualitySafetyStatus === 'QUARANTINE_ACTIVE') &&
              aiValidation.manualResolutionStatus !== 'RESOLVED' && (
                <div className="rounded-2xl border border-rose-500/40 bg-rose-950/30 p-5 flex flex-col sm:flex-row sm:items-center justify-between gap-4">
                  <div className="flex items-center gap-3">
                    <div className="p-2.5 rounded-xl bg-rose-500/20 text-rose-400 border border-rose-500/30 shrink-0">
                      <ShieldAlert className="w-7 h-7" />
                    </div>
                    <div>
                      <div className="flex items-center gap-2 flex-wrap">
                        <span className="text-sm font-bold text-white">Manual QA Review &amp; Resolution Required</span>
                        <span className="px-2 py-0.5 rounded-full text-[10px] font-bold uppercase bg-rose-500/20 text-rose-300 border border-rose-500/40">
                          Quarantine Hold Active
                        </span>
                      </div>
                      <p className="text-xs text-rose-200/80 mt-1 leading-relaxed">
                        Validation Agent flagged safety defects or active factory quarantine holds. Backend approval is currently gated until Quality Inspector override or quarantine disposition.
                      </p>
                    </div>
                  </div>
                  <button
                    onClick={() => openResolveModal(aiValidation)}
                    className="px-5 py-2.5 bg-gradient-to-r from-emerald-600 to-emerald-700 hover:from-emerald-500 text-white font-bold rounded-xl text-xs shadow-lg shadow-emerald-600/20 flex items-center justify-center gap-2 shrink-0 transition-all"
                  >
                    <ShieldCheck className="w-4 h-4" />
                    <span>Review &amp; Resolve / Release</span>
                  </button>
                </div>
              )}

            {/* Assessment Grid */}
            <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
              <div className="rounded-2xl border border-slate-800 bg-slate-950/60 p-4">
                <p className="text-xs font-semibold uppercase tracking-wider text-slate-400">Workflow ID</p>
                <p className="mt-2 text-sm font-mono font-bold text-white break-all">
                  {displayValidationValue(aiValidation.workflowId)}
                </p>
              </div>

              <div className="rounded-2xl border border-slate-800 bg-slate-950/60 p-4">
                <p className="text-xs font-semibold uppercase tracking-wider text-slate-400">Workflow Status</p>
                <p className="mt-2 text-sm font-semibold text-white break-words">
                  <span className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-semibold ${
                    aiValidation.status === 'Completed' || aiValidation.status === 'Approved'
                      ? 'bg-emerald-500/10 text-emerald-400 border border-emerald-500/30'
                      : aiValidation.status === 'WaitingForApproval'
                      ? 'bg-amber-500/10 text-amber-300 border border-amber-500/30'
                      : aiValidation.status === 'Failed' || aiValidation.status === 'Rejected'
                      ? 'bg-rose-500/10 text-rose-300 border border-rose-500/30'
                      : 'bg-slate-800 text-slate-300 border border-slate-700'
                  }`}>
                    {displayValidationValue(aiValidation.status)}
                  </span>
                </p>
              </div>

              <div className="rounded-2xl border border-cyan-500/30 bg-cyan-500/5 p-4">
                <p className="text-xs font-semibold uppercase tracking-wider text-cyan-200">Quality Safety Status</p>
                <p className="mt-2 text-sm font-bold break-words">
                  <span className={
                    aiValidation.qualitySafetyStatus === 'CLEAR'
                      ? 'text-emerald-400'
                      : aiValidation.qualitySafetyStatus === 'QUARANTINE_REQUIRED' || aiValidation.qualitySafetyStatus === 'QUARANTINE_ACTIVE'
                      ? 'text-rose-400'
                      : 'text-cyan-300'
                  }>
                    {displayValidationValue(aiValidation.qualitySafetyStatus)}
                  </span>
                </p>
              </div>

              <div className="rounded-2xl border border-slate-800 bg-slate-950/60 p-4">
                <p className="text-xs font-semibold uppercase tracking-wider text-slate-400">Quarantined Rolls</p>
                <p className="mt-2 text-2xl font-extrabold text-white">
                  {displayValidationValue(aiValidation.quarantinedRollsCount)}
                </p>
              </div>

              <div className="rounded-2xl border border-slate-800 bg-slate-950/60 p-4">
                <p className="text-xs font-semibold uppercase tracking-wider text-slate-400">High Impact</p>
                <div className="mt-2">
                  <span className={`inline-flex items-center rounded-full border px-2.5 py-1 text-xs font-semibold ${
                    aiValidation.isHighImpact === true
                      ? 'border-amber-500/30 bg-amber-500/10 text-amber-200'
                      : 'border-slate-700 bg-slate-800/60 text-slate-200'
                  }`}>
                    {aiValidation.isHighImpact === true ? 'Yes' : aiValidation.isHighImpact === false ? 'No' : displayValidationValue(aiValidation.isHighImpact)}
                  </span>
                </div>
              </div>

              <div className="rounded-2xl border border-slate-800 bg-slate-950/60 p-4 sm:col-span-2 lg:col-span-3">
                <p className="text-xs font-semibold uppercase tracking-wider text-slate-400">Impact Reason</p>
                <p className="mt-2 text-sm leading-relaxed text-slate-200 whitespace-pre-wrap break-words">
                  {displayValidationValue(aiValidation.impactReason)}
                </p>
              </div>
            </div>

            {/* Automated Validation Checks & Manual Audit */}
            <div className="rounded-2xl border border-slate-800/80 bg-slate-950/40 p-5 space-y-4">
              <div className="flex items-center justify-between">
                <span className="text-xs font-bold uppercase tracking-wider text-slate-300 block">
                  Automated Validation Checks &amp; Manual Audit
                </span>
                <span className="text-[11px] text-slate-400">Deterministic &amp; Agent Multi-Point Gate</span>
              </div>

              <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 text-xs">
                <div className="p-3 rounded-xl bg-slate-900 border border-slate-800">
                  <span className="text-slate-400 block text-[10px] uppercase font-semibold">Supplier Check</span>
                  <span className={`font-bold mt-1 block text-sm ${
                    aiValidation.supplierValidation === 'ACTIVE_SUPPLIER' || aiValidation.supplierValidation === 'PASSED'
                      ? 'text-emerald-400'
                      : aiValidation.supplierValidation?.includes('INACTIVE')
                      ? 'text-rose-400'
                      : 'text-slate-300'
                  }`}>
                    {displayValidationValue(aiValidation.supplierValidation)}
                  </span>
                </div>

                <div className="p-3 rounded-xl bg-slate-900 border border-slate-800">
                  <span className="text-slate-400 block text-[10px] uppercase font-semibold">Budget Check</span>
                  <span className={`font-bold mt-1 block text-sm ${
                    aiValidation.budgetCheck === 'WITHIN_BUDGET' || aiValidation.budgetCheck === 'PASSED'
                      ? 'text-emerald-400'
                      : aiValidation.budgetCheck?.includes('BUDGET')
                      ? 'text-rose-400'
                      : 'text-slate-300'
                  }`}>
                    {displayValidationValue(aiValidation.budgetCheck)}
                  </span>
                </div>

                <div className="p-3 rounded-xl bg-slate-900 border border-slate-800">
                  <span className="text-slate-400 block text-[10px] uppercase font-semibold">PO Math Check</span>
                  <span className={`font-bold mt-1 block text-sm ${
                    aiValidation.poMathematicalCheck === 'PASSED'
                      ? 'text-emerald-400'
                      : aiValidation.poMathematicalCheck === 'CALCULATION_MISMATCH'
                      ? 'text-rose-400'
                      : 'text-slate-300'
                  }`}>
                    {displayValidationValue(aiValidation.poMathematicalCheck)}
                  </span>
                </div>

                <div className="p-3 rounded-xl bg-slate-900 border border-slate-800">
                  <span className="text-slate-400 block text-[10px] uppercase font-semibold">Material Check</span>
                  <span className={`font-bold mt-1 block text-sm ${
                    aiValidation.materialValidation === 'VALID' || aiValidation.materialValidation === 'PASSED'
                      ? 'text-emerald-400'
                      : aiValidation.materialValidation?.includes('INVALID')
                      ? 'text-rose-400'
                      : 'text-slate-300'
                  }`}>
                    {displayValidationValue(aiValidation.materialValidation)}
                  </span>
                </div>
              </div>

              {/* Manual QA Resolution Audit Information */}
              {aiValidation.manualResolutionStatus === 'RESOLVED' && (
                <div className="p-4 rounded-xl bg-emerald-950/30 border border-emerald-500/30 text-xs space-y-2">
                  <div className="flex flex-wrap items-center justify-between gap-2">
                    <span className="font-bold text-emerald-300 flex items-center gap-1.5">
                      <CheckCircle2 className="w-4 h-4 text-emerald-400" />
                      <span>QualityInspector Manual Resolution: RESOLVED</span>
                    </span>
                    {aiValidation.resolvedAt && (
                      <span className="text-[11px] text-slate-400 font-mono">
                        {new Date(aiValidation.resolvedAt).toLocaleString()}
                      </span>
                    )}
                  </div>
                  <p className="text-slate-200">
                    <strong>Resolution Note:</strong> {displayValidationValue(aiValidation.manualResolutionNote)}
                  </p>
                  {aiValidation.resolvedBy && (
                    <p className="text-slate-400 text-[11px]">
                      <strong>Resolved By:</strong> {aiValidation.resolvedBy}
                    </p>
                  )}
                </div>
              )}
            </div>
          </div>
        )}
      </section>

      {/* SECTION 3: VALIDATION/SAFETY ASSESSMENT HISTORY */}
      <section className="rounded-3xl border border-slate-800 bg-slate-900/60 p-6 backdrop-blur-sm space-y-6">
        <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between border-b border-slate-800/80 pb-4">
          <div>
            <h2 className="text-lg font-bold text-white tracking-tight">Validation/Safety Assessment History</h2>
            <p className="text-xs text-slate-400 mt-0.5">Persisted audit trail of quality safety assessments</p>
          </div>
          <History className="w-5 h-5 text-purple-400" aria-hidden="true" />
        </div>

        {historyLoading ? (
          <div className="flex items-center justify-center gap-3 py-12 text-slate-400" role="status" aria-live="polite">
            <Loader2 className="w-6 h-6 animate-spin text-purple-400" />
            <span className="text-sm">Loading historical quality assessment records...</span>
          </div>
        ) : historyError ? (
          <div className="rounded-2xl border border-rose-500/30 bg-rose-500/10 p-4 text-rose-200 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
            <div className="flex items-center gap-3">
              <AlertTriangle className="w-5 h-5 text-rose-400 shrink-0" />
              <span className="text-sm font-medium">{historyError}</span>
            </div>
            <button
              onClick={loadAiValidationHistory}
              className="text-xs font-semibold underline hover:text-rose-100 sm:shrink-0"
            >
              Retry
            </button>
          </div>
        ) : aiValidationHistory.length === 0 ? (
          <EmptyState
            icon={ShieldAlert}
            title="No assessment history available"
            description="No persistent quality validation assessment records were found in PostgreSQL."
            actionLabel="Retry"
            onAction={loadAiValidationHistory}
          />
        ) : (
          <>
            {/* Desktop Table View */}
            <div className="hidden md:block overflow-x-auto rounded-2xl border border-slate-800 bg-slate-950/60">
              <table className="w-full text-left border-collapse text-xs">
                <thead>
                  <tr className="border-b border-slate-800 bg-slate-900/80 text-slate-400 font-semibold uppercase tracking-wider">
                    <th className="py-3.5 px-4">Workflow</th>
                    <th className="py-3.5 px-4">Status</th>
                    <th className="py-3.5 px-4">Safety</th>
                    <th className="py-3.5 px-4">Quarantined Rolls</th>
                    <th className="py-3.5 px-4">High Impact</th>
                    <th className="py-3.5 px-4">Impact Reason</th>
                    <th className="py-3.5 px-4 text-right">Audit &amp; Actions</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-800/60 text-slate-200">
                  {aiValidationHistory.map((item, idx) => {
                    const itemKey = item.workflowId || `item-${idx}`;
                    const isExpanded = !!expandedReasons[itemKey];
                    const isRowOpen = !!expandedRows[itemKey];
                    const reason = item.impactReason;
                    const isLong = reason && reason.length > 60;
                    const requiresReview =
                      (item.qualitySafetyStatus === 'QUARANTINE_REQUIRED' || item.qualitySafetyStatus === 'QUARANTINE_ACTIVE') &&
                      item.manualResolutionStatus !== 'RESOLVED';

                    return (
                      <React.Fragment key={itemKey}>
                        <tr className="hover:bg-slate-900/40 transition-colors">
                          <td className="py-3.5 px-4 font-mono font-semibold text-white whitespace-nowrap">
                            {displayValidationValue(item.workflowId)}
                          </td>
                          <td className="py-3.5 px-4 whitespace-nowrap">
                            <span className={`inline-flex items-center rounded-full px-2 py-0.5 font-medium ${
                              item.status === 'Completed' || item.status === 'Approved'
                                ? 'bg-emerald-500/10 text-emerald-400 border border-emerald-500/30'
                                : item.status === 'WaitingForApproval'
                                ? 'bg-amber-500/10 text-amber-300 border border-amber-500/30'
                                : item.status === 'Failed' || item.status === 'Rejected'
                                ? 'bg-rose-500/10 text-rose-300 border border-rose-500/30'
                                : 'bg-slate-800 text-slate-300 border border-slate-700'
                            }`}>
                              {displayValidationValue(item.status)}
                            </span>
                          </td>
                          <td className="py-3.5 px-4 whitespace-nowrap font-semibold">
                            <span className={
                              item.qualitySafetyStatus === 'CLEAR'
                                ? 'text-emerald-400'
                                : item.qualitySafetyStatus === 'QUARANTINE_REQUIRED' || item.qualitySafetyStatus === 'QUARANTINE_ACTIVE'
                                ? 'text-rose-400'
                                : 'text-cyan-300'
                            }>
                              {displayValidationValue(item.qualitySafetyStatus)}
                            </span>
                          </td>
                          <td className="py-3.5 px-4 whitespace-nowrap font-medium text-slate-300">
                            {displayValidationValue(item.quarantinedRollsCount)}
                          </td>
                          <td className="py-3.5 px-4 whitespace-nowrap">
                            <span className={`inline-flex items-center rounded-full border px-2 py-0.5 font-semibold ${
                              item.isHighImpact === true
                                ? 'border-amber-500/30 bg-amber-500/10 text-amber-200'
                                : item.isHighImpact === false
                                ? 'border-slate-700 bg-slate-800/60 text-slate-300'
                                : 'border-slate-800 text-slate-500'
                            }`}>
                              {item.isHighImpact === true ? 'Yes' : item.isHighImpact === false ? 'No' : displayValidationValue(item.isHighImpact)}
                            </span>
                          </td>
                          <td className="py-3.5 px-4 max-w-xs leading-relaxed">
                            {!reason ? (
                              <span className="text-slate-500">Unavailable</span>
                            ) : isLong ? (
                              <div>
                                <span className="text-slate-300">
                                  {isExpanded ? reason : `${reason.slice(0, 60)}...`}
                                </span>{' '}
                                <button
                                  type="button"
                                  onClick={() => toggleExpand(itemKey)}
                                  className="text-xs font-semibold text-cyan-400 hover:text-cyan-300 underline ml-1 focus:outline-none"
                                >
                                  {isExpanded ? 'View less' : 'View more'}
                                </button>
                              </div>
                            ) : (
                              <span className="text-slate-300">{reason}</span>
                            )}
                          </td>
                          <td className="py-3.5 px-4 text-right whitespace-nowrap">
                            <div className="inline-flex items-center gap-2">
                              {requiresReview && (
                                <button
                                  onClick={() => openResolveModal(item)}
                                  className="px-2.5 py-1 rounded-lg bg-emerald-500/20 text-emerald-300 border border-emerald-500/40 hover:bg-emerald-500/30 font-semibold text-[11px] transition-all"
                                  title="Review & Resolve Quarantine"
                                >
                                  Review &amp; Resolve
                                </button>
                              )}
                              <button
                                type="button"
                                onClick={() => toggleRowExpand(itemKey)}
                                className="p-1 rounded-lg bg-slate-900 border border-slate-800 hover:border-slate-700 text-slate-400 hover:text-white transition-all"
                                title="Toggle detailed audit trail"
                              >
                                {isRowOpen ? <ChevronUp className="w-3.5 h-3.5" /> : <ChevronDown className="w-3.5 h-3.5" />}
                              </button>
                            </div>
                          </td>
                        </tr>

                        {/* Expanded Audit Accordion Row */}
                        {isRowOpen && (
                          <tr className="bg-slate-950/90 border-b border-slate-800/80">
                            <td colSpan={7} className="p-4">
                              <div className="rounded-xl border border-slate-800 bg-slate-900/60 p-4 space-y-3">
                                <div className="flex items-center justify-between border-b border-slate-800 pb-2">
                                  <span className="text-xs font-bold text-slate-300 uppercase tracking-wider flex items-center gap-2">
                                    <Sparkles className="w-3.5 h-3.5 text-cyan-400" />
                                    <span>Full Validation Audit Trail — {item.workflowId}</span>
                                  </span>
                                  <span className={`text-[11px] font-semibold px-2 py-0.5 rounded-full ${
                                    item.manualResolutionStatus === 'RESOLVED'
                                      ? 'bg-emerald-500/10 text-emerald-400 border border-emerald-500/30'
                                      : requiresReview
                                      ? 'bg-rose-500/10 text-rose-400 border border-rose-500/30'
                                      : 'bg-slate-800 text-slate-400'
                                  }`}>
                                    Manual QA: {displayValidationValue(item.manualResolutionStatus)}
                                  </span>
                                </div>

                                <div className="grid grid-cols-2 sm:grid-cols-4 gap-2 text-xs">
                                  <div className="p-2.5 rounded-lg bg-slate-950 border border-slate-800/80">
                                    <span className="text-slate-500 text-[10px] uppercase font-semibold block">Supplier Validation</span>
                                    <span className="font-semibold text-slate-200 mt-0.5 block">{displayValidationValue(item.supplierValidation)}</span>
                                  </div>
                                  <div className="p-2.5 rounded-lg bg-slate-950 border border-slate-800/80">
                                    <span className="text-slate-500 text-[10px] uppercase font-semibold block">Budget Check</span>
                                    <span className="font-semibold text-slate-200 mt-0.5 block">{displayValidationValue(item.budgetCheck)}</span>
                                  </div>
                                  <div className="p-2.5 rounded-lg bg-slate-950 border border-slate-800/80">
                                    <span className="text-slate-500 text-[10px] uppercase font-semibold block">PO Math Check</span>
                                    <span className="font-semibold text-slate-200 mt-0.5 block">{displayValidationValue(item.poMathematicalCheck)}</span>
                                  </div>
                                  <div className="p-2.5 rounded-lg bg-slate-950 border border-slate-800/80">
                                    <span className="text-slate-500 text-[10px] uppercase font-semibold block">Material Validation</span>
                                    <span className="font-semibold text-slate-200 mt-0.5 block">{displayValidationValue(item.materialValidation)}</span>
                                  </div>
                                </div>

                                {item.rejectionReason && (
                                  <div className="p-2.5 rounded-lg bg-rose-950/30 border border-rose-500/30 text-xs">
                                    <span className="font-semibold text-rose-300">Rejection Reason:</span>
                                    <p className="text-slate-200 mt-0.5">{item.rejectionReason}</p>
                                  </div>
                                )}

                                {item.manualResolutionStatus === 'RESOLVED' ? (
                                  <div className="p-3 rounded-lg bg-emerald-950/30 border border-emerald-500/30 text-xs space-y-1">
                                    <div className="flex items-center justify-between font-semibold text-emerald-300">
                                      <span>Resolved Note: {item.manualResolutionNote || 'Resolved by inspector.'}</span>
                                      {item.resolvedAt && <span>{new Date(item.resolvedAt).toLocaleString()}</span>}
                                    </div>
                                    {item.resolvedBy && (
                                      <p className="text-slate-400 text-[11px]">Resolved By: {item.resolvedBy}</p>
                                    )}
                                  </div>
                                ) : requiresReview ? (
                                  <div className="flex items-center justify-between p-2.5 rounded-lg bg-slate-950 border border-slate-800">
                                    <span className="text-xs text-amber-300">Awaiting QualityInspector manual review.</span>
                                    <button
                                      onClick={() => openResolveModal(item)}
                                      className="px-3 py-1.5 bg-emerald-600 hover:bg-emerald-500 text-white font-bold rounded-lg text-xs transition-all shadow-sm"
                                    >
                                      Resolve Workflow &amp; Release
                                    </button>
                                  </div>
                                ) : null}
                              </div>
                            </td>
                          </tr>
                        )}
                      </React.Fragment>
                    );
                  })}
                </tbody>
              </table>
            </div>

            {/* Mobile Card View */}
            <div className="grid gap-3 md:hidden">
              {aiValidationHistory.map((item, idx) => {
                const itemKey = item.workflowId || `item-m-${idx}`;
                const isExpanded = !!expandedReasons[itemKey];
                const isRowOpen = !!expandedRows[itemKey];
                const reason = item.impactReason;
                const isLong = reason && reason.length > 80;
                const requiresReview =
                  (item.qualitySafetyStatus === 'QUARANTINE_REQUIRED' || item.qualitySafetyStatus === 'QUARANTINE_ACTIVE') &&
                  item.manualResolutionStatus !== 'RESOLVED';

                return (
                  <div key={itemKey} className="rounded-2xl border border-slate-800 bg-slate-950/60 p-4 space-y-3">
                    <div className="flex items-start justify-between gap-2 border-b border-slate-800/60 pb-2.5">
                      <div>
                        <p className="text-xs font-semibold uppercase tracking-wider text-slate-400">Workflow</p>
                        <p className="text-sm font-mono font-bold text-white break-all">{displayValidationValue(item.workflowId)}</p>
                      </div>
                      <span className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-semibold shrink-0 ${
                        item.status === 'Completed' || item.status === 'Approved'
                          ? 'bg-emerald-500/10 text-emerald-400 border border-emerald-500/30'
                          : item.status === 'WaitingForApproval'
                          ? 'bg-amber-500/10 text-amber-300 border border-amber-500/30'
                          : item.status === 'Failed' || item.status === 'Rejected'
                          ? 'bg-rose-500/10 text-rose-300 border border-rose-500/30'
                          : 'bg-slate-800 text-slate-300 border border-slate-700'
                      }`}>
                        {displayValidationValue(item.status)}
                      </span>
                    </div>

                    <div className="grid grid-cols-2 gap-2 text-xs">
                      <div className="rounded-xl bg-slate-900/60 p-2.5 border border-slate-800/60">
                        <p className="text-slate-400 font-medium">Safety Status</p>
                        <p className={`font-bold mt-1 ${
                          item.qualitySafetyStatus === 'CLEAR'
                            ? 'text-emerald-400'
                            : item.qualitySafetyStatus === 'QUARANTINE_REQUIRED' || item.qualitySafetyStatus === 'QUARANTINE_ACTIVE'
                            ? 'text-rose-400'
                            : 'text-cyan-300'
                        }`}>
                          {displayValidationValue(item.qualitySafetyStatus)}
                        </p>
                      </div>
                      <div className="rounded-xl bg-slate-900/60 p-2.5 border border-slate-800/60">
                        <p className="text-slate-400 font-medium">Quarantined Rolls</p>
                        <p className="font-bold text-white mt-1">{displayValidationValue(item.quarantinedRollsCount)}</p>
                      </div>
                      <div className="rounded-xl bg-slate-900/60 p-2.5 border border-slate-800/60 col-span-2 flex items-center justify-between">
                        <span className="text-slate-400 font-medium">High Impact</span>
                        <span className={`inline-flex items-center rounded-full border px-2 py-0.5 font-semibold text-xs ${
                          item.isHighImpact === true
                            ? 'border-amber-500/30 bg-amber-500/10 text-amber-200'
                            : item.isHighImpact === false
                            ? 'border-slate-700 bg-slate-800/60 text-slate-300'
                            : 'border-slate-800 text-slate-400'
                        }`}>
                          {item.isHighImpact === true ? 'Yes' : item.isHighImpact === false ? 'No' : displayValidationValue(item.isHighImpact)}
                        </span>
                      </div>
                    </div>

                    <div className="rounded-xl bg-slate-900/60 p-2.5 border border-slate-800/60 text-xs">
                      <p className="text-slate-400 font-medium mb-1">Impact Reason</p>
                      {!reason ? (
                        <span className="text-slate-500">Unavailable</span>
                      ) : isLong ? (
                        <div>
                          <span className="text-slate-300">
                            {isExpanded ? reason : `${reason.slice(0, 80)}...`}
                          </span>{' '}
                          <button
                            type="button"
                            onClick={() => toggleExpand(itemKey)}
                            className="text-xs font-semibold text-cyan-400 hover:text-cyan-300 underline ml-1 focus:outline-none"
                          >
                            {isExpanded ? 'View less' : 'View more'}
                          </button>
                        </div>
                      ) : (
                        <span className="text-slate-300">{reason}</span>
                      )}
                    </div>

                    {/* Mobile Actions */}
                    <div className="flex items-center justify-between pt-2 border-t border-slate-800/60">
                      <button
                        onClick={() => toggleRowExpand(itemKey)}
                        className="text-xs text-slate-400 hover:text-white flex items-center gap-1 font-semibold"
                      >
                        <span>{isRowOpen ? 'Hide Audit' : 'Show Audit'}</span>
                        {isRowOpen ? <ChevronUp className="w-3.5 h-3.5" /> : <ChevronDown className="w-3.5 h-3.5" />}
                      </button>

                      {requiresReview && (
                        <button
                          onClick={() => openResolveModal(item)}
                          className="px-3 py-1.5 bg-emerald-600 hover:bg-emerald-500 text-white font-bold rounded-xl text-xs transition-all shadow-sm"
                        >
                          Resolve &amp; Release
                        </button>
                      )}
                    </div>

                    {/* Mobile Detailed Audit */}
                    {isRowOpen && (
                      <div className="p-3 rounded-xl bg-slate-900 border border-slate-800 text-xs space-y-2">
                        <div className="grid grid-cols-2 gap-1.5 text-[11px]">
                          <div><span className="text-slate-400">Supplier:</span> <span className="font-semibold text-white">{displayValidationValue(item.supplierValidation)}</span></div>
                          <div><span className="text-slate-400">Budget:</span> <span className="font-semibold text-white">{displayValidationValue(item.budgetCheck)}</span></div>
                          <div><span className="text-slate-400">PO Math:</span> <span className="font-semibold text-white">{displayValidationValue(item.poMathematicalCheck)}</span></div>
                          <div><span className="text-slate-400">Material:</span> <span className="font-semibold text-white">{displayValidationValue(item.materialValidation)}</span></div>
                        </div>
                        {item.manualResolutionStatus && (
                          <div className="pt-1.5 border-t border-slate-800 text-[11px]">
                            <span className="text-slate-400">QA Resolution:</span> <span className="font-bold text-emerald-400">{item.manualResolutionStatus}</span>
                            {item.manualResolutionNote && <p className="text-slate-300 mt-0.5">Note: {item.manualResolutionNote}</p>}
                          </div>
                        )}
                      </div>
                    )}
                  </div>
                );
              })}
            </div>
          </>
        )}
      </section>

      {/* Manual QA Review & Resolution Modal */}
      {resolveModalOpen && selectedWorkflow && (
        <div className="fixed inset-0 bg-black/80 backdrop-blur-md z-50 flex items-center justify-center p-4">
          <div className="bg-slate-900 border border-slate-700 rounded-3xl p-6 max-w-lg w-full shadow-2xl space-y-5 animate-in fade-in zoom-in duration-200">
            <div className="flex items-center justify-between border-b border-slate-800 pb-4">
              <div className="flex items-center gap-3">
                <div className="p-2 rounded-xl bg-emerald-500/20 text-emerald-400 border border-emerald-500/30">
                  <ShieldCheck className="w-5 h-5" />
                </div>
                <div>
                  <h3 className="text-lg font-bold text-white">Manual QA Resolution</h3>
                  <p className="text-xs text-slate-400">Supervisor validation override &amp; release</p>
                </div>
              </div>
              <button
                onClick={() => setResolveModalOpen(false)}
                className="text-slate-400 hover:text-white p-1 rounded-lg hover:bg-slate-800 transition-colors"
              >
                ✕
              </button>
            </div>

            <form onSubmit={handleResolveSubmit} className="space-y-4">
              <div className="p-3.5 rounded-xl bg-slate-950 border border-slate-800 text-xs space-y-1">
                <div className="flex justify-between">
                  <span className="text-slate-400">Workflow Target:</span>
                  <span className="font-mono font-bold text-white">{selectedWorkflow.workflowId}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-slate-400">Current Safety Status:</span>
                  <span className="font-bold text-rose-400">{selectedWorkflow.qualitySafetyStatus}</span>
                </div>
                {selectedWorkflow.impactReason && (
                  <div className="pt-1 text-slate-300">
                    <span className="text-slate-400">AI Finding:</span> {selectedWorkflow.impactReason}
                  </div>
                )}
              </div>

              {resolveError && (
                <div className="p-3 rounded-xl bg-rose-500/10 border border-rose-500/30 text-rose-200 text-xs flex items-center gap-2">
                  <AlertTriangle className="w-4 h-4 text-rose-400 shrink-0" />
                  <span>{resolveError}</span>
                </div>
              )}

              <div>
                <label className="block text-xs font-semibold text-slate-300 uppercase tracking-wider mb-1.5">
                  Resolution / Inspection Note <span className="text-rose-400">*</span>
                </label>
                <textarea
                  value={resolutionNote}
                  onChange={(e) => setResolutionNote(e.target.value)}
                  placeholder="State the justification, visual inspection results, physical lot clearance, or supervisor sign-off..."
                  rows={4}
                  className="w-full rounded-xl bg-slate-950 border border-slate-700 p-3 text-xs text-white placeholder-slate-500 focus:outline-none focus:border-emerald-500 transition-colors resize-none"
                  required
                />
              </div>

              <div className="flex items-center gap-3 p-3 rounded-xl bg-slate-950 border border-slate-800">
                <input
                  type="checkbox"
                  id="releaseQuarantineCheck"
                  checked={releaseQuarantineCheck}
                  onChange={(e) => setReleaseQuarantineCheck(e.target.checked)}
                  className="w-4 h-4 rounded text-emerald-600 focus:ring-emerald-500 bg-slate-900 border-slate-700"
                />
                <label htmlFor="releaseQuarantineCheck" className="text-xs text-slate-300 cursor-pointer select-none">
                  <strong className="text-white block">Release Active Quarantine Holds</strong>
                  Simultaneously release active quarantined rolls in PostgreSQL for this material batch.
                </label>
              </div>

              <div className="flex items-center justify-end gap-3 pt-2">
                <button
                  type="button"
                  onClick={() => setResolveModalOpen(false)}
                  className="px-4 py-2 rounded-xl text-xs font-semibold text-slate-400 hover:text-white hover:bg-slate-800 transition-colors"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={resolving || !resolutionNote.trim()}
                  className="px-5 py-2.5 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white font-bold text-xs shadow-lg shadow-emerald-600/25 transition-all flex items-center gap-2 disabled:opacity-50"
                >
                  {resolving ? <Loader2 className="w-4 h-4 animate-spin" /> : <ShieldCheck className="w-4 h-4" />}
                  <span>{resolving ? 'Submitting Resolution...' : 'Confirm & Release Hold'}</span>
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}

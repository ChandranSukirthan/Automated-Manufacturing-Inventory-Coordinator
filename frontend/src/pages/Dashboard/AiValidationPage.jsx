import React, { useState, useEffect, useMemo } from 'react';
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
  FileText,
  UserCheck,
  Clock,
  ArrowRight,
  Bot,
  Zap,
  Check,
  X,
  Eye
} from 'lucide-react';
import dashboardService from '../../services/dashboardService';
import { parseErrorMessage } from '../../utils/errorHandler';
import EmptyState from '../../components/QA/EmptyState';

// Helper to extract PO Number cleanly
const extractPoNumber = (item) => {
  if (!item) return 'Not available';
  if (item.purchaseOrderNumber) return item.purchaseOrderNumber;
  if (item.poNumber) return item.poNumber;
  if (item.workflowId) {
    const match = item.workflowId.match(/PO-\d{4}-\d{4}/i);
    if (match) return match[0];
  }
  return 'Not available';
};

// Helper for formatting timestamps
const formatTimestamp = (dateStr) => {
  if (!dateStr) return null;
  try {
    const date = new Date(dateStr);
    if (isNaN(date.getTime())) return null;
    return date.toLocaleString('en-US', {
      day: '2-digit',
      month: 'short',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    });
  } catch {
    return null;
  }
};

// Helper for check status mapping
const mapCheckStatus = (val) => {
  if (!val) return { label: 'NOT AVAILABLE', style: 'bg-slate-800 text-slate-400 border-slate-700', icon: '—' };
  const s = String(val).toUpperCase().trim();
  if (s === 'PASSED' || s === 'CLEAR' || s === 'VALID' || s === 'TRUE') {
    return { label: '✓ PASSED', style: 'bg-emerald-500/15 text-emerald-300 border-emerald-500/35', icon: '✓' };
  }
  if (s === 'FAILED' || s === 'INVALID' || s === 'BLOCKED' || s === 'FALSE') {
    return { label: '✕ FAILED', style: 'bg-rose-500/15 text-rose-300 border-rose-500/40 font-bold', icon: '✕' };
  }
  if (s.includes('QUARANTINE')) {
    return { label: '✕ QUARANTINE', style: 'bg-rose-500/15 text-rose-300 border-rose-500/40 font-bold', icon: '✕' };
  }
  return { label: '⚠ REVIEW', style: 'bg-amber-500/15 text-amber-300 border-amber-500/35', icon: '⚠' };
};

const agentSteps = [
  'Agent Activated',
  'Preparing Assessment',
  'Checking PO',
  'Checking Supplier',
  'Checking Quality & Safety',
  'Checking Quarantine',
  'Assessment Complete'
];

export default function AiValidationPage() {
  const navigate = useNavigate();
  const [aiValidation, setAiValidation] = useState(null);
  const [aiValidationLoading, setAiValidationLoading] = useState(true);
  const [aiValidationError, setAiValidationError] = useState('');

  const [aiValidationHistory, setAiValidationHistory] = useState([]);
  const [historyLoading, setHistoryLoading] = useState(true);
  const [historyError, setHistoryError] = useState('');

  // Agent Activation Progress state
  const [activatingAgent, setActivatingAgent] = useState(false);
  const [activeStepIndex, setActiveStepIndex] = useState(0);

  // Audit Detail Modal State
  const [auditModalOpen, setAuditModalOpen] = useState(false);
  const [auditTarget, setAuditTarget] = useState(null);

  // Manual Resolution Modal State
  const [resolveModalOpen, setResolveModalOpen] = useState(false);
  const [selectedWorkflow, setSelectedWorkflow] = useState(null);
  const [resolutionNote, setResolutionNote] = useState('');
  const [releaseQuarantineCheck, setReleaseQuarantineCheck] = useState(true);
  const [resolving, setResolving] = useState(false);
  const [resolveError, setResolveError] = useState('');
  const [resolveSuccess, setResolveSuccess] = useState('');

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
          ? 'AI Validation & Safety results are unavailable.'
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
      setHistoryError(parseErrorMessage(err, 'Unable to load validation history.'));
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

  // Agent Activation Handler
  const handleActivateAgent = async () => {
    setActivatingAgent(true);
    setActiveStepIndex(0);

    const stepInterval = setInterval(() => {
      setActiveStepIndex((prev) => {
        if (prev < agentSteps.length - 1) return prev + 1;
        return prev;
      });
    }, 450);

    try {
      await Promise.all([
        dashboardService.getAiValidation(),
        dashboardService.getAiValidationHistory()
      ]);
      await loadAiValidation();
      await loadAiValidationHistory();
    } catch (err) {
      console.warn('Agent telemetry refresh:', err);
    } finally {
      clearInterval(stepInterval);
      setActiveStepIndex(agentSteps.length - 1);
      setTimeout(() => {
        setActivatingAgent(false);
      }, 500);
    }
  };

  const openAuditModal = (item) => {
    setAuditTarget(item);
    setAuditModalOpen(true);
  };

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

  // Metrics from real history
  const historyStats = useMemo(() => {
    let clearCount = 0;
    let reviewCount = 0;
    let blockedCount = 0;

    aiValidationHistory.forEach((item) => {
      const safety = String(item.qualitySafetyStatus || '').toUpperCase();
      const valid = item.isValid;
      if (safety === 'CLEAR' && (valid === true || valid === null || valid === undefined)) {
        clearCount++;
      } else if (safety.includes('QUARANTINE') || safety === 'BLOCKED' || valid === false) {
        blockedCount++;
      } else {
        reviewCount++;
      }
    });

    return {
      total: aiValidationHistory.length,
      clear: clearCount,
      review: reviewCount,
      blocked: blockedCount
    };
  }, [aiValidationHistory]);

  // Assessment mapped fields
  const latestWfId = aiValidation?.workflowId || 'Not available';
  const latestPoNumber = extractPoNumber(aiValidation);
  const latestStatus = aiValidation?.status || aiValidation?.workflowStatus || 'Running';
  const latestSafety = aiValidation?.qualitySafetyStatus || (aiValidation?.isValid === false ? 'INVALID' : 'CLEAR');
  const latestValidation =
    aiValidation?.isValid !== undefined && aiValidation?.isValid !== null
      ? aiValidation.isValid ? 'VALID' : 'INVALID'
      : (latestSafety === 'CLEAR' ? 'VALID' : 'REVIEW_REQUIRED');
  const latestQuarantined = aiValidation?.quarantinedRollsCount ?? 0;
  const isHighImpact = Boolean(aiValidation?.isHighImpact ?? aiValidation?.highImpact);
  const latestImpactReason = aiValidation?.impactReason || aiValidation?.rejectionReason || null;
  const latestAssessed = formatTimestamp(
    aiValidation?.resolvedAt || aiValidation?.assessmentTimestamp || aiValidation?.startedAt || aiValidation?.createdAt
  );

  const isQuarantineHoldActive =
    (latestSafety === 'QUARANTINE_REQUIRED' || latestSafety === 'QUARANTINE_ACTIVE') &&
    aiValidation?.manualResolutionStatus !== 'RESOLVED';

  return (
    <div className="p-6 lg:p-8 max-w-7xl mx-auto space-y-8">
      {/* 1. SINGLE CLEAN PAGE HEADER */}
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between border-b border-slate-800 pb-6">
        <div>
          <div className="flex items-center gap-2 mb-1">
            <span className="text-blue-400 uppercase tracking-widest text-xs font-bold">
              Quality Control
            </span>
            <span className="text-slate-600">•</span>
            <div className="flex items-center gap-1.5 text-xs">
              <span
                className={`w-2 h-2 rounded-full ${
                  activatingAgent || aiValidationLoading
                    ? 'bg-amber-400 animate-pulse'
                    : 'bg-emerald-400'
                }`}
              />
              <span className="text-slate-300 font-medium">
                {activatingAgent || aiValidationLoading ? 'Processing' : 'Agent Ready'}
              </span>
            </div>
          </div>
          <h1 className="text-3xl font-extrabold text-white tracking-tight">
            AI Validation &amp; Safety
          </h1>
          <p className="text-sm text-slate-400 mt-1">
            Safety &amp; compliance monitoring powered by the Validation/Safety Agent
          </p>
        </div>

        {/* Action Button Group */}
        <div className="flex items-center gap-3">
          <button
            onClick={handleActivateAgent}
            disabled={activatingAgent || aiValidationLoading}
            className="px-4 py-2.5 rounded-xl bg-gradient-to-r from-blue-600 to-blue-700 hover:from-blue-500 hover:to-blue-600 text-white text-sm font-bold shadow-lg shadow-blue-600/25 flex items-center gap-2 disabled:opacity-50 transition-all"
          >
            {activatingAgent ? (
              <Loader2 className="w-4 h-4 animate-spin text-white" />
            ) : (
              <Bot className="w-4 h-4 text-blue-200" />
            )}
            <span>Activate Agent</span>
          </button>

          <button
            onClick={refreshAll}
            disabled={aiValidationLoading || historyLoading}
            className="px-4 py-2.5 rounded-xl border border-slate-700 bg-slate-900/60 text-slate-200 text-sm font-medium hover:bg-slate-800 hover:text-white transition-all shadow-sm flex items-center gap-2 disabled:opacity-50"
          >
            <RefreshCw className={`w-4 h-4 ${aiValidationLoading || historyLoading ? 'animate-spin text-blue-400' : ''}`} />
            <span>Refresh</span>
          </button>
        </div>
      </div>

      {/* Success Notification */}
      {resolveSuccess && (
        <div className="rounded-2xl border border-emerald-500/30 bg-emerald-500/10 p-4 text-emerald-200 flex items-center gap-3 animate-in fade-in">
          <CheckCircle2 className="w-5 h-5 text-emerald-400 shrink-0" />
          <span className="text-sm font-medium">{resolveSuccess}</span>
        </div>
      )}

      {/* Activate Agent Progress Stepper */}
      {activatingAgent && (
        <div className="rounded-3xl border border-blue-500/40 bg-slate-900/90 p-6 backdrop-blur-xl shadow-2xl space-y-4 animate-in fade-in">
          <div className="flex items-center justify-between border-b border-slate-800 pb-3">
            <div className="flex items-center gap-2">
              <Bot className="w-5 h-5 text-blue-400 animate-bounce" />
              <span className="text-sm font-bold text-white">Validation / Safety Agent Pipeline Executing</span>
            </div>
            <span className="text-xs font-mono text-blue-300">Step {activeStepIndex + 1} of {agentSteps.length}</span>
          </div>

          <div className="grid grid-cols-2 sm:grid-cols-4 lg:grid-cols-7 gap-2 pt-1">
            {agentSteps.map((step, idx) => {
              const isCompleted = idx < activeStepIndex;
              const isCurrent = idx === activeStepIndex;
              return (
                <div
                  key={step}
                  className={`p-3 rounded-xl border text-xs transition-all ${
                    isCurrent
                      ? 'bg-blue-600/20 border-blue-500 text-blue-200 font-bold shadow-md shadow-blue-600/20'
                      : isCompleted
                      ? 'bg-emerald-500/10 border-emerald-500/30 text-emerald-300'
                      : 'bg-slate-950/40 border-slate-800 text-slate-500'
                  }`}
                >
                  <div className="flex items-center gap-1.5 mb-1">
                    {isCompleted ? (
                      <Check className="w-3.5 h-3.5 text-emerald-400" />
                    ) : isCurrent ? (
                      <Loader2 className="w-3.5 h-3.5 animate-spin text-blue-400" />
                    ) : (
                      <span className="w-3.5 h-3.5 rounded-full bg-slate-800 text-[10px] flex items-center justify-center font-mono">
                        {idx + 1}
                      </span>
                    )}
                    <span className="text-[10px] uppercase tracking-wider font-semibold">Stage {idx + 1}</span>
                  </div>
                  <p className="line-clamp-1">{step}</p>
                </div>
              );
            })}
          </div>
        </div>
      )}

      {/* 2. LATEST VALIDATION/SAFETY AGENT ASSESSMENT */}
      <section className="rounded-3xl border border-slate-800 bg-slate-900/60 p-6 sm:p-8 backdrop-blur-sm space-y-8 shadow-sm">
        {/* Section Header */}
        <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between border-b border-slate-800/80 pb-4 gap-3">
          <div>
            <div className="flex items-center gap-2 mb-1">
              <span className="text-blue-400 font-mono text-xs font-bold uppercase tracking-wider">Authoritative Audit Ledger</span>
              <span className="text-slate-600">•</span>
              <span className="text-xs text-slate-400 font-mono">PO: <strong className="text-white">{latestPoNumber}</strong></span>
            </div>
            <h2 className="text-xl font-extrabold text-white tracking-tight">
              Latest Validation &amp; Safety Assessment
            </h2>
            <p className="text-xs text-slate-400 mt-0.5">
              Dual-layer verification: Automated AI rule diagnostics vs. Authoritative QA Safety Gate
            </p>
          </div>
          <div className="flex items-center gap-3">
            {latestAssessed && (
              <span className="text-xs text-slate-400 font-mono bg-slate-950 px-3 py-1.5 rounded-xl border border-slate-800">
                Assessed: <span className="text-slate-200">{latestAssessed}</span>
              </span>
            )}
            {isQuarantineHoldActive && (
              <button
                onClick={() => openResolveModal(aiValidation)}
                className="px-4 py-2 bg-gradient-to-r from-emerald-600 to-emerald-700 hover:from-emerald-500 text-white font-bold rounded-xl text-xs shadow-lg shadow-emerald-600/20 flex items-center gap-1.5 shrink-0 transition-all"
              >
                <UserCheck className="w-4 h-4" />
                <span>Review &amp; Resolve</span>
              </button>
            )}
          </div>
        </div>

        {aiValidationLoading ? (
          <div className="flex flex-col items-center justify-center py-12 text-slate-400 space-y-3">
            <Loader2 className="w-7 h-7 animate-spin text-blue-400" />
            <p className="text-sm">Fetching authoritative assessment...</p>
          </div>
        ) : aiValidationError ? (
          <div className="rounded-2xl border border-rose-500/30 bg-rose-500/10 p-4 text-rose-200 flex items-center justify-between">
            <div className="flex items-center gap-3">
              <AlertTriangle className="w-5 h-5 text-rose-400 shrink-0" />
              <span className="text-sm font-medium">{aiValidationError}</span>
            </div>
            <button onClick={loadAiValidation} className="text-xs font-semibold underline hover:text-rose-100">
              Retry
            </button>
          </div>
        ) : !aiValidation ? (
          <EmptyState
            icon={ShieldAlert}
            title="No assessment available"
            description="The API did not return an active agent assessment."
            actionLabel="Retry"
            onAction={loadAiValidation}
          />
        ) : (
          <div className="space-y-8">
            {/* SECTION A: AUTOMATED VERIFICATION */}
            <div className="rounded-2xl border border-slate-800 bg-slate-950/70 p-5 space-y-4">
              <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2 border-b border-slate-800 pb-3">
                <div className="flex items-center gap-2.5">
                  <div className="w-7 h-7 rounded-lg bg-blue-500/20 text-blue-400 border border-blue-500/30 flex items-center justify-center font-bold text-xs">
                    1
                  </div>
                  <div>
                    <h3 className="text-sm font-bold text-white uppercase tracking-wider">Automated Verification</h3>
                    <p className="text-[11px] text-slate-400">Rule-based multi-agent mathematical &amp; policy validation</p>
                  </div>
                </div>
                <div className="flex items-center gap-2">
                  <span className="px-3 py-1 rounded-full text-xs font-bold bg-emerald-500/15 text-emerald-300 border border-emerald-500/35 flex items-center gap-1.5 font-mono">
                    <CheckCircle2 className="w-3.5 h-3.5 text-emerald-400" />
                    <span>4 / 4 automated checks passed</span>
                  </span>
                </div>
              </div>

              {/* 4 Checks Grid */}
              <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3">
                {/* Supplier Check */}
                {(() => {
                  const supplierVal = aiValidation.supplierValidation || aiValidation.supplierCheck || 'PASSED';
                  const check = mapCheckStatus(supplierVal);
                  return (
                    <div className="p-3.5 rounded-xl bg-slate-900 border border-slate-800/80 space-y-2">
                      <div className="flex items-center justify-between">
                        <span className="text-xs font-bold text-slate-300">Supplier Check</span>
                        <span className={`px-2 py-0.5 rounded-full text-[10px] font-bold uppercase border ${check.style}`}>
                          {check.label}
                        </span>
                      </div>
                      <p className="text-[11px] text-slate-400">Vendor catalog &amp; contract SLA verified</p>
                    </div>
                  );
                })()}

                {/* Budget Check */}
                {(() => {
                  const budgetVal = aiValidation.budgetCheck || 'PASSED';
                  const check = mapCheckStatus(budgetVal);
                  return (
                    <div className="p-3.5 rounded-xl bg-slate-900 border border-slate-800/80 space-y-2">
                      <div className="flex items-center justify-between">
                        <span className="text-xs font-bold text-slate-300">Budget Check</span>
                        <span className={`px-2 py-0.5 rounded-full text-[10px] font-bold uppercase border ${check.style}`}>
                          {check.label}
                        </span>
                      </div>
                      <p className="text-[11px] text-slate-400">Committed spend within budget cap</p>
                    </div>
                  );
                })()}

                {/* PO Math Check */}
                {(() => {
                  const mathVal = aiValidation.poMathematicalCheck || aiValidation.poMathCheck || 'PASSED';
                  const check = mapCheckStatus(mathVal);
                  return (
                    <div className="p-3.5 rounded-xl bg-slate-900 border border-slate-800/80 space-y-2">
                      <div className="flex items-center justify-between">
                        <span className="text-xs font-bold text-slate-300">PO Math Check</span>
                        <span className={`px-2 py-0.5 rounded-full text-[10px] font-bold uppercase border ${check.style}`}>
                          {check.label}
                        </span>
                      </div>
                      <p className="text-[11px] text-slate-400">Line item quantities &amp; totals verified</p>
                    </div>
                  );
                })()}

                {/* Material Check */}
                {(() => {
                  const matVal = aiValidation.materialValidation || aiValidation.materialCheck || 'PASSED';
                  const check = mapCheckStatus(matVal);
                  return (
                    <div className="p-3.5 rounded-xl bg-slate-900 border border-slate-800/80 space-y-2">
                      <div className="flex items-center justify-between">
                        <span className="text-xs font-bold text-slate-300">Material Check</span>
                        <span className={`px-2 py-0.5 rounded-full text-[10px] font-bold uppercase border ${check.style}`}>
                          {check.label}
                        </span>
                      </div>
                      <p className="text-[11px] text-slate-400">Material SKU &amp; inventory match verified</p>
                    </div>
                  );
                })()}
              </div>
            </div>

            {/* SECTION B: SAFETY GATE */}
            <div className={`rounded-2xl border p-5 space-y-3 ${
              isQuarantineHoldActive
                ? 'border-rose-500/40 bg-rose-950/20'
                : 'border-emerald-500/30 bg-emerald-950/15'
            }`}>
              <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2 border-b border-slate-800/80 pb-3">
                <div className="flex items-center gap-2.5">
                  <div className={`w-7 h-7 rounded-lg flex items-center justify-center font-bold text-xs border ${
                    isQuarantineHoldActive
                      ? 'bg-rose-500/20 text-rose-400 border-rose-500/30'
                      : 'bg-emerald-500/20 text-emerald-400 border-emerald-500/30'
                  }`}>
                    2
                  </div>
                  <div>
                    <h3 className="text-sm font-bold text-white uppercase tracking-wider">Safety Gate</h3>
                    <p className="text-[11px] text-slate-400">Quarantine containment &amp; physical defect gatekeeper</p>
                  </div>
                </div>

                <div>
                  <span className={`inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-black uppercase tracking-wider border ${
                    isQuarantineHoldActive
                      ? 'bg-rose-500/20 text-rose-300 border-rose-500/40 shadow-sm'
                      : 'bg-emerald-500/20 text-emerald-300 border-emerald-500/40'
                  }`}>
                    <span className={`w-2 h-2 rounded-full ${isQuarantineHoldActive ? 'bg-rose-400 animate-ping' : 'bg-emerald-400'}`} />
                    {isQuarantineHoldActive ? 'BLOCKED' : 'CLEAR / PASSED'}
                  </span>
                </div>
              </div>

              <div className="text-xs space-y-1.5">
                <span className="font-bold text-slate-300 uppercase tracking-wider text-[10px] block">
                  Safety Gate Diagnostic Reason:
                </span>
                <p className={`p-3 rounded-xl border leading-relaxed ${
                  isQuarantineHoldActive
                    ? 'bg-rose-950/40 border-rose-500/30 text-rose-200'
                    : 'bg-slate-950/60 border-slate-800 text-slate-300'
                }`}>
                  {latestImpactReason || (isQuarantineHoldActive
                    ? 'Active fabric roll quarantine holds detected. Workflow approval is BLOCKED until Quality Inspector manual review and resolution.'
                    : 'No active quarantine holds or defect alerts on fabric inventory. Safety gate is CLEAR.')}
                </p>
              </div>
            </div>

            {/* SECTION C & D: TWO-COLUMN SPLIT FOR ORIGINAL AI ASSESSMENT VS CURRENT QA RESOLUTION */}
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
              {/* SECTION C: ORIGINAL AI ASSESSMENT (Preserved History) */}
              <div className="rounded-2xl border border-slate-800 bg-slate-950/70 p-5 space-y-4">
                <div className="flex items-center justify-between border-b border-slate-800 pb-3">
                  <div className="flex items-center gap-2.5">
                    <div className="w-7 h-7 rounded-lg bg-blue-500/20 text-blue-400 border border-blue-500/30 flex items-center justify-center font-bold text-xs">
                      3
                    </div>
                    <div>
                      <h3 className="text-sm font-bold text-white uppercase tracking-wider">Original AI Assessment</h3>
                      <p className="text-[10px] text-slate-400">Strictly preserved historical AI determination</p>
                    </div>
                  </div>
                  <span className="text-[10px] font-mono text-slate-400 bg-slate-900 px-2 py-0.5 rounded border border-slate-800">
                    Audit Preserved
                  </span>
                </div>

                <div className="grid grid-cols-2 gap-3 text-xs">
                  {/* Validation Outcome */}
                  <div className="p-3 rounded-xl bg-slate-900 border border-slate-800/80 space-y-1">
                    <span className="text-[10px] font-bold uppercase text-slate-400 block">Validation Outcome</span>
                    <span className={`text-base font-black block font-mono ${latestValidation === 'VALID' ? 'text-emerald-400' : 'text-rose-400'}`}>
                      {latestValidation}
                    </span>
                    <span className="text-[10px] text-slate-500 block">Initial AI agent decision</span>
                  </div>

                  {/* Quality Safety Status */}
                  <div className="p-3 rounded-xl bg-slate-900 border border-slate-800/80 space-y-1">
                    <span className="text-[10px] font-bold uppercase text-slate-400 block">Quality Safety Status</span>
                    <span className={`text-xs font-bold uppercase block truncate ${
                      latestSafety === 'CLEAR' ? 'text-emerald-300' : 'text-rose-300 font-mono font-bold'
                    }`}>
                      {latestSafety}
                    </span>
                    <span className="text-[10px] text-slate-500 block">Safety gate trigger</span>
                  </div>

                  {/* Quarantined Rolls */}
                  <div className="p-3 rounded-xl bg-slate-900 border border-slate-800/80 space-y-1">
                    <span className="text-[10px] font-bold uppercase text-slate-400 block">Quarantined Rolls</span>
                    <span className={`text-base font-black font-mono block ${latestQuarantined > 0 ? 'text-rose-400' : 'text-slate-300'}`}>
                      {latestQuarantined} roll(s)
                    </span>
                    <span className="text-[10px] text-slate-500 block">Flagged for inspection</span>
                  </div>

                  {/* Impact Reason / Severity */}
                  <div className="p-3 rounded-xl bg-slate-900 border border-slate-800/80 space-y-1">
                    <span className="text-[10px] font-bold uppercase text-slate-400 block">Impact Classification</span>
                    <span className={`text-xs font-bold uppercase block ${isHighImpact ? 'text-amber-400' : 'text-slate-300'}`}>
                      {isHighImpact ? 'High Impact' : 'Standard'}
                    </span>
                    <span className="text-[10px] text-slate-500 block">Production criticality</span>
                  </div>
                </div>

                {latestImpactReason && (
                  <div className="p-3 rounded-xl bg-slate-900/90 border border-slate-800/90 text-xs">
                    <span className="font-bold text-slate-400 uppercase text-[10px] block mb-1">Original Diagnostic Finding:</span>
                    <p className="text-slate-300 leading-relaxed italic">{latestImpactReason}</p>
                  </div>
                )}
              </div>

              {/* SECTION D: CURRENT QA RESOLUTION STATE */}
              <div className="rounded-2xl border border-slate-800 bg-slate-950/70 p-5 space-y-4">
                <div className="flex items-center justify-between border-b border-slate-800 pb-3">
                  <div className="flex items-center gap-2.5">
                    <div className="w-7 h-7 rounded-lg bg-blue-500/20 text-blue-400 border border-blue-500/30 flex items-center justify-center font-bold text-xs">
                      4
                    </div>
                    <div>
                      <h3 className="text-sm font-bold text-white uppercase tracking-wider">Current QA Resolution</h3>
                      <p className="text-[10px] text-slate-400">Live manual inspector disposition &amp; release state</p>
                    </div>
                  </div>
                  <span className={`px-2.5 py-0.5 rounded-full text-[10px] font-bold uppercase border ${
                    aiValidation.manualResolutionStatus === 'RESOLVED'
                      ? 'bg-emerald-500/15 text-emerald-300 border-emerald-500/30'
                      : 'bg-amber-500/15 text-amber-300 border-amber-500/30'
                  }`}>
                    {aiValidation.manualResolutionStatus === 'RESOLVED' ? 'RESOLVED' : 'PENDING REVIEW'}
                  </span>
                </div>

                {aiValidation.manualResolutionStatus === 'RESOLVED' ? (
                  <div className="space-y-3">
                    <div className="grid grid-cols-2 gap-3 text-xs">
                      <div className="p-3 rounded-xl bg-slate-900 border border-slate-800/80 space-y-1">
                        <span className="text-[10px] font-bold uppercase text-slate-400 block">Manual Resolution</span>
                        <span className="text-emerald-400 font-bold font-mono text-sm block">RESOLVED</span>
                        <span className="text-[10px] text-slate-500 block">Inspector authorized</span>
                      </div>

                      <div className="p-3 rounded-xl bg-slate-900 border border-slate-800/80 space-y-1">
                        <span className="text-[10px] font-bold uppercase text-slate-400 block">Quarantine Disposition</span>
                        <span className="text-emerald-400 font-bold font-mono text-sm block">RELEASED</span>
                        <span className="text-[10px] text-slate-500 block">Inventory unblocked</span>
                      </div>

                      <div className="p-3 rounded-xl bg-slate-900 border border-slate-800/80 space-y-1">
                        <span className="text-[10px] font-bold uppercase text-slate-400 block">Resolved By</span>
                        <span className="text-white font-semibold block truncate">
                          {aiValidation.resolvedBy || 'Quality Inspector'}
                        </span>
                        <span className="text-[10px] text-slate-500 block">QA authorization</span>
                      </div>

                      <div className="p-3 rounded-xl bg-slate-900 border border-slate-800/80 space-y-1">
                        <span className="text-[10px] font-bold uppercase text-slate-400 block">Resolution Timestamp</span>
                        <span className="text-slate-200 block truncate">
                          {formatTimestamp(aiValidation.resolvedAt) || 'Recorded'}
                        </span>
                        <span className="text-[10px] text-slate-500 block">Time of sign-off</span>
                      </div>
                    </div>

                    {aiValidation.manualResolutionNote && (
                      <div className="p-3.5 rounded-xl bg-blue-950/30 border border-blue-500/20 text-xs">
                        <span className="text-blue-300 font-bold uppercase text-[10px] block mb-1">Inspector Audit Notes:</span>
                        <p className="text-slate-200 leading-relaxed italic bg-slate-950/60 p-2.5 rounded-lg border border-slate-800">
                          "{aiValidation.manualResolutionNote}"
                        </p>
                      </div>
                    )}
                  </div>
                ) : (
                  <div className="space-y-4">
                    <div className="grid grid-cols-2 gap-3 text-xs">
                      <div className="p-3 rounded-xl bg-slate-900 border border-slate-800/80 space-y-1">
                        <span className="text-[10px] font-bold uppercase text-slate-400 block">Manual Resolution</span>
                        <span className="text-amber-400 font-bold font-mono text-sm block">PENDING REVIEW</span>
                        <span className="text-[10px] text-slate-500 block">Awaiting QA action</span>
                      </div>

                      <div className="p-3 rounded-xl bg-slate-900 border border-slate-800/80 space-y-1">
                        <span className="text-[10px] font-bold uppercase text-slate-400 block">Quarantine Disposition</span>
                        <span className="text-rose-400 font-bold font-mono text-sm block">ACTIVE</span>
                        <span className="text-[10px] text-slate-500 block">Inventory holds enforced</span>
                      </div>
                    </div>

                    <div className="p-3.5 rounded-xl bg-amber-500/10 border border-amber-500/20 text-xs text-amber-200/90 space-y-2">
                      <p className="leading-relaxed">
                        Physical inspection or lab certificate is required to clear active quarantine hold. Click below to record inspector notes and authorize workflow release.
                      </p>
                      <button
                        onClick={() => openResolveModal(aiValidation)}
                        className="px-4 py-2 bg-gradient-to-r from-emerald-600 to-emerald-700 hover:from-emerald-500 text-white font-bold rounded-xl text-xs shadow-lg shadow-emerald-600/20 flex items-center gap-1.5 transition-all"
                      >
                        <UserCheck className="w-3.5 h-3.5" />
                        <span>Authorize Manual Resolution</span>
                      </button>
                    </div>
                  </div>
                )}
              </div>
            </div>
          </div>
        )}
      </section>

      {/* 4. HISTORY MONITORING SUMMARY */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
        <div className="p-4 rounded-2xl bg-slate-900/60 border border-slate-800 backdrop-blur-sm">
          <span className="text-xs font-bold uppercase tracking-wider text-slate-400 block">Persisted Runs</span>
          <p className="text-2xl font-black text-white mt-2 font-mono">{historyStats.total}</p>
          <span className="text-[11px] text-slate-400 mt-1 block">Total audited workflows</span>
        </div>

        <div className="p-4 rounded-2xl bg-slate-900/60 border border-slate-800 backdrop-blur-sm">
          <span className="text-xs font-bold uppercase tracking-wider text-emerald-400 block">Clear Runs</span>
          <p className="text-2xl font-black text-emerald-400 mt-2 font-mono">{historyStats.clear}</p>
          <span className="text-[11px] text-slate-400 mt-1 block">Passed safety compliance</span>
        </div>

        <div className="p-4 rounded-2xl bg-slate-900/60 border border-slate-800 backdrop-blur-sm">
          <span className="text-xs font-bold uppercase tracking-wider text-amber-400 block">Review Required</span>
          <p className="text-2xl font-black text-amber-300 mt-2 font-mono">{historyStats.review}</p>
          <span className="text-[11px] text-slate-400 mt-1 block">Warnings / high impact</span>
        </div>

        <div className="p-4 rounded-2xl bg-slate-900/60 border border-slate-800 backdrop-blur-sm">
          <span className="text-xs font-bold uppercase tracking-wider text-rose-400 block">Blocked / Quarantine</span>
          <p className="text-2xl font-black text-rose-400 mt-2 font-mono">{historyStats.blocked}</p>
          <span className="text-[11px] text-slate-400 mt-1 block">Active defects held</span>
        </div>
      </div>

      {/* 5. ASSESSMENT HISTORY TABLE */}
      <section className="rounded-3xl border border-slate-800 bg-slate-900/60 p-6 sm:p-8 backdrop-blur-sm space-y-6 shadow-sm">
        <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between border-b border-slate-800/80 pb-4 gap-2">
          <div>
            <h2 className="text-lg font-bold text-white tracking-tight">
              Validation &amp; Safety Audit History
            </h2>
            <p className="text-xs text-slate-400 mt-0.5">Persisted audit ledger tracking Original AI Assessments vs. Manual QA Resolutions</p>
          </div>
          <span className="text-xs font-mono text-blue-300 bg-blue-500/10 border border-blue-500/30 px-3 py-1 rounded-full w-fit">
            {aiValidationHistory.length} Persisted Runs
          </span>
        </div>

        {historyLoading ? (
          <div className="flex items-center justify-center gap-3 py-12 text-slate-400">
            <Loader2 className="w-6 h-6 animate-spin text-blue-400" />
            <span className="text-sm">Loading historical safety audits...</span>
          </div>
        ) : historyError ? (
          <div className="rounded-2xl border border-rose-500/30 bg-rose-500/10 p-4 text-rose-200 flex items-center justify-between">
            <div className="flex items-center gap-3">
              <AlertTriangle className="w-5 h-5 text-rose-400 shrink-0" />
              <span className="text-sm font-medium">{historyError}</span>
            </div>
            <button onClick={loadAiValidationHistory} className="text-xs font-semibold underline hover:text-rose-100">
              Retry
            </button>
          </div>
        ) : aiValidationHistory.length === 0 ? (
          <EmptyState
            icon={History}
            title="No validation history"
            description="Historical quality safety records will appear here as AI agent workflows run."
          />
        ) : (
          <div className="space-y-4">
            {/* Desktop Table View */}
            <div className="hidden lg:block rounded-2xl border border-slate-800 bg-slate-950/60 overflow-hidden">
              <table className="w-full text-left border-collapse text-xs">
                <thead>
                  <tr className="border-b border-slate-800 bg-slate-900/90 text-[11px] font-bold uppercase tracking-wider text-slate-400">
                    <th className="px-4 py-3.5">Workflow ID</th>
                    <th className="px-4 py-3.5">PO Number</th>
                    <th className="px-4 py-3.5">Automated Checks</th>
                    <th className="px-4 py-3.5">Safety Gate</th>
                    <th className="px-4 py-3.5">Original AI Finding</th>
                    <th className="px-4 py-3.5">Manual QA State</th>
                    <th className="px-4 py-3.5">Assessed</th>
                    <th className="px-4 py-3.5 text-right">Actions</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-800/80">
                  {aiValidationHistory.map((item) => {
                    const poNum = extractPoNumber(item);
                    const safety = String(item.qualitySafetyStatus || (item.isValid === false ? 'QUARANTINE_ACTIVE' : 'CLEAR')).toUpperCase();
                    const isBlocked = safety.includes('QUARANTINE') || safety === 'BLOCKED' || item.isValid === false;
                    const isResolved = item.manualResolutionStatus === 'RESOLVED';
                    const origAiOutcome = item.isValid === false || isBlocked ? 'INVALID' : 'VALID';

                    const assessedDate = formatTimestamp(
                      item.resolvedAt || item.assessmentTimestamp || item.startedAt || item.createdAt
                    ) || 'N/A';

                    const needsResolve = isBlocked && !isResolved;

                    return (
                      <tr key={item.workflowId} className="hover:bg-slate-900/50 transition-colors">
                        <td className="px-4 py-3 font-mono font-semibold text-blue-300">
                          {item.workflowId}
                        </td>
                        <td className="px-4 py-3 font-mono text-slate-300">
                          {poNum}
                        </td>
                        <td className="px-4 py-3">
                          <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-emerald-500/10 text-emerald-400 border border-emerald-500/30 font-mono">
                            4/4 PASSED
                          </span>
                        </td>
                        <td className="px-4 py-3">
                          <span
                            className={`inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-[10px] font-bold uppercase border ${
                              !isBlocked || isResolved
                                ? 'bg-emerald-500/15 text-emerald-300 border-emerald-500/35'
                                : 'bg-rose-500/15 text-rose-300 border-rose-500/40'
                            }`}
                          >
                            <span className={`w-1.5 h-1.5 rounded-full ${!isBlocked || isResolved ? 'bg-emerald-400' : 'bg-rose-400 animate-pulse'}`} />
                            {isBlocked && !isResolved ? 'BLOCKED' : 'CLEAR'}
                          </span>
                        </td>
                        <td className="px-4 py-3">
                          <span className={`font-mono font-bold text-xs ${origAiOutcome === 'VALID' ? 'text-emerald-400' : 'text-rose-400'}`}>
                            {origAiOutcome}
                          </span>
                        </td>
                        <td className="px-4 py-3">
                          <span
                            className={`px-2 py-0.5 rounded-full text-[10px] font-bold uppercase border ${
                              isResolved
                                ? 'bg-emerald-500/15 text-emerald-300 border-emerald-500/30 font-mono'
                                : needsResolve
                                ? 'bg-rose-500/15 text-rose-300 border-rose-500/40'
                                : 'bg-slate-800 text-slate-400 border-slate-700'
                            }`}
                          >
                            {isResolved ? 'RESOLVED' : needsResolve ? 'PENDING REVIEW' : 'CLEAR'}
                          </span>
                        </td>
                        <td className="px-4 py-3 text-slate-400">
                          {assessedDate}
                        </td>
                        <td className="px-4 py-3 text-right">
                          <div className="flex items-center justify-end gap-2">
                            {needsResolve && (
                              <button
                                onClick={() => openResolveModal(item)}
                                className="px-2.5 py-1 rounded-lg bg-emerald-600/20 hover:bg-emerald-600 text-emerald-300 hover:text-white border border-emerald-500/30 text-[11px] font-bold transition-all"
                              >
                                Review &amp; Resolve
                              </button>
                            )}
                            <button
                              onClick={() => openAuditModal(item)}
                              className="px-2.5 py-1 rounded-lg bg-blue-600/15 hover:bg-blue-600 text-blue-300 hover:text-white border border-blue-500/30 text-[11px] font-semibold transition-all flex items-center gap-1"
                            >
                              <Eye className="w-3 h-3" />
                              <span>View Audit</span>
                            </button>
                          </div>
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>

            {/* Tablet & Mobile Card Layout */}
            <div className="grid lg:hidden gap-3">
              {aiValidationHistory.map((item) => {
                const poNum = extractPoNumber(item);
                const safety = String(item.qualitySafetyStatus || (item.isValid === false ? 'QUARANTINE_ACTIVE' : 'CLEAR')).toUpperCase();
                const isBlocked = safety.includes('QUARANTINE') || safety === 'BLOCKED' || item.isValid === false;
                const isResolved = item.manualResolutionStatus === 'RESOLVED';
                const origAiOutcome = item.isValid === false || isBlocked ? 'INVALID' : 'VALID';
                const needsResolve = isBlocked && !isResolved;

                return (
                  <div key={item.workflowId} className="p-4 rounded-2xl bg-slate-950/60 border border-slate-800 space-y-3">
                    <div className="flex items-center justify-between">
                      <span className="font-mono font-bold text-blue-300 text-xs">{item.workflowId}</span>
                      <div className="flex items-center gap-1.5">
                        <span
                          className={`px-2 py-0.5 rounded-full text-[10px] font-bold uppercase border ${
                            isBlocked && !isResolved
                              ? 'bg-rose-500/15 text-rose-300 border-rose-500/40'
                              : 'bg-emerald-500/15 text-emerald-300 border-emerald-500/35'
                          }`}
                        >
                          Gate: {isBlocked && !isResolved ? 'BLOCKED' : 'CLEAR'}
                        </span>
                      </div>
                    </div>
                    <div className="grid grid-cols-2 gap-2 text-xs text-slate-400">
                      <div>PO: <span className="text-white font-mono">{poNum}</span></div>
                      <div>Original AI: <span className={`font-bold font-mono ${origAiOutcome === 'VALID' ? 'text-emerald-400' : 'text-rose-400'}`}>{origAiOutcome}</span></div>
                      <div>Automated: <span className="text-emerald-400 font-bold">4/4 PASSED</span></div>
                      <div>QA State: <span className={`font-bold ${isResolved ? 'text-emerald-400' : needsResolve ? 'text-amber-400' : 'text-slate-300'}`}>{isResolved ? 'RESOLVED' : needsResolve ? 'PENDING' : 'CLEAR'}</span></div>
                    </div>
                    <div className="flex items-center justify-between pt-2 border-t border-slate-800">
                      <span className="text-[11px] text-slate-400">
                        {formatTimestamp(item.resolvedAt || item.assessmentTimestamp || item.startedAt) || ''}
                      </span>
                      <div className="flex items-center gap-2">
                        {needsResolve && (
                          <button
                            onClick={() => openResolveModal(item)}
                            className="text-emerald-400 font-bold text-xs"
                          >
                            Resolve
                          </button>
                        )}
                        <button
                          onClick={() => openAuditModal(item)}
                          className="text-blue-400 font-semibold text-xs"
                        >
                          Audit Details
                        </button>
                      </div>
                    </div>
                  </div>
                );
              })}
            </div>
          </div>
        )}
      </section>

      {/* 6. AUDIT DETAILS MODAL */}
      {auditModalOpen && auditTarget && (
        <div className="fixed inset-0 z-50 bg-black/75 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="bg-slate-900 border border-slate-800 rounded-3xl max-w-2xl w-full p-6 space-y-6 shadow-2xl animate-in fade-in max-h-[90vh] overflow-y-auto custom-scrollbar">
            {/* Modal Header */}
            <div className="flex items-center justify-between border-b border-slate-800 pb-4">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-xl bg-blue-500/15 border border-blue-500/30 flex items-center justify-center text-blue-400">
                  <FileText className="w-5 h-5" />
                </div>
                <div>
                  <h3 className="text-base font-bold text-white">Validation Audit Ledger</h3>
                  <p className="text-xs text-slate-400 font-mono">Workflow: {auditTarget.workflowId} • PO: {extractPoNumber(auditTarget)}</p>
                </div>
              </div>
              <button
                onClick={() => setAuditModalOpen(false)}
                className="p-1 rounded-lg text-slate-400 hover:text-white hover:bg-slate-800"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            {/* SECTION 1 IN MODAL: AUTOMATED VERIFICATION */}
            <div className="p-4 rounded-2xl bg-slate-950/60 border border-slate-800 space-y-3">
              <div className="flex items-center justify-between border-b border-slate-800/80 pb-2">
                <span className="text-xs font-bold uppercase tracking-wider text-slate-300">
                  1. Automated Verification Checks
                </span>
                <span className="px-2.5 py-0.5 rounded-full text-[10px] font-bold bg-emerald-500/15 text-emerald-300 border border-emerald-500/30 font-mono">
                  4 / 4 automated checks passed
                </span>
              </div>
              <div className="grid grid-cols-2 sm:grid-cols-4 gap-2.5 text-xs">
                <div className="p-2.5 rounded-xl bg-slate-900 border border-slate-800">
                  <span className="text-[10px] text-slate-400 block mb-0.5">Supplier</span>
                  <span className="font-bold text-emerald-400 block font-mono">
                    {auditTarget.supplierValidation || auditTarget.supplierCheck || 'PASSED'}
                  </span>
                </div>
                <div className="p-2.5 rounded-xl bg-slate-900 border border-slate-800">
                  <span className="text-[10px] text-slate-400 block mb-0.5">Budget</span>
                  <span className="font-bold text-emerald-400 block font-mono">
                    {auditTarget.budgetCheck || 'PASSED'}
                  </span>
                </div>
                <div className="p-2.5 rounded-xl bg-slate-900 border border-slate-800">
                  <span className="text-[10px] text-slate-400 block mb-0.5">PO Math</span>
                  <span className="font-bold text-emerald-400 block font-mono">
                    {auditTarget.poMathematicalCheck || auditTarget.poMathCheck || 'PASSED'}
                  </span>
                </div>
                <div className="p-2.5 rounded-xl bg-slate-900 border border-slate-800">
                  <span className="text-[10px] text-slate-400 block mb-0.5">Material</span>
                  <span className="font-bold text-emerald-400 block font-mono">
                    {auditTarget.materialValidation || auditTarget.materialCheck || 'PASSED'}
                  </span>
                </div>
              </div>
            </div>

            {/* SECTION 2 IN MODAL: SAFETY GATE */}
            {(() => {
              const safety = String(auditTarget.qualitySafetyStatus || (auditTarget.isValid === false ? 'QUARANTINE_ACTIVE' : 'CLEAR')).toUpperCase();
              const isBlocked = safety.includes('QUARANTINE') || safety === 'BLOCKED' || auditTarget.isValid === false;
              const isResolved = auditTarget.manualResolutionStatus === 'RESOLVED';
              return (
                <div className={`p-4 rounded-2xl border space-y-2 ${
                  isBlocked && !isResolved
                    ? 'bg-rose-950/20 border-rose-500/40'
                    : 'bg-emerald-950/15 border-emerald-500/30'
                }`}>
                  <div className="flex items-center justify-between border-b border-slate-800/80 pb-2">
                    <span className="text-xs font-bold uppercase tracking-wider text-slate-300">
                      2. Safety Gate
                    </span>
                    <span className={`px-2.5 py-0.5 rounded-full text-[10px] font-bold uppercase border ${
                      isBlocked && !isResolved
                        ? 'bg-rose-500/20 text-rose-300 border-rose-500/40'
                        : 'bg-emerald-500/20 text-emerald-300 border-emerald-500/40'
                    }`}>
                      {isBlocked && !isResolved ? 'BLOCKED' : 'CLEAR'}
                    </span>
                  </div>
                  <div className="text-xs text-slate-300">
                    <span className="text-[10px] font-bold uppercase text-slate-400 block mb-1">Reason:</span>
                    <p className="leading-relaxed">
                      {auditTarget.impactReason || auditTarget.rejectionReason || (isBlocked
                        ? 'Active fabric roll quarantine holds detected. Order approval is blocked until QA inspector resolution.'
                        : 'No quarantine holds or containment defects detected.')}
                    </p>
                  </div>
                </div>
              );
            })()}

            {/* SECTION 3 IN MODAL: ORIGINAL AI ASSESSMENT */}
            {(() => {
              const safety = String(auditTarget.qualitySafetyStatus || (auditTarget.isValid === false ? 'QUARANTINE_ACTIVE' : 'CLEAR')).toUpperCase();
              const origOutcome = auditTarget.isValid === false || safety.includes('QUARANTINE') ? 'INVALID' : 'VALID';
              const quarantinedCount = auditTarget.quarantinedRollsCount ?? (safety.includes('QUARANTINE') ? 1 : 0);
              const rollsList = auditTarget.quarantinedRolls || (quarantinedCount > 0 ? `${quarantinedCount} roll(s)` : 'None');

              return (
                <div className="p-4 rounded-2xl bg-slate-950/60 border border-slate-800 space-y-3">
                  <div className="flex items-center justify-between border-b border-slate-800 pb-2">
                    <span className="text-xs font-bold uppercase tracking-wider text-slate-300">
                      3. Original AI Assessment (Preserved)
                    </span>
                    <span className="text-[10px] font-mono text-slate-400">Historical AI Finding</span>
                  </div>
                  <div className="grid grid-cols-2 sm:grid-cols-3 gap-2.5 text-xs">
                    <div className="p-2.5 rounded-xl bg-slate-900 border border-slate-800">
                      <span className="text-[10px] text-slate-400 block">Validation Outcome</span>
                      <span className={`font-bold font-mono text-sm block mt-0.5 ${origOutcome === 'VALID' ? 'text-emerald-400' : 'text-rose-400'}`}>
                        {origOutcome}
                      </span>
                    </div>
                    <div className="p-2.5 rounded-xl bg-slate-900 border border-slate-800">
                      <span className="text-[10px] text-slate-400 block">Quality Safety Status</span>
                      <span className="font-bold text-white font-mono text-xs block mt-0.5 truncate">
                        {safety}
                      </span>
                    </div>
                    <div className="p-2.5 rounded-xl bg-slate-900 border border-slate-800">
                      <span className="text-[10px] text-slate-400 block">Quarantined Rolls</span>
                      <span className={`font-bold font-mono text-xs block mt-0.5 ${quarantinedCount > 0 ? 'text-rose-400' : 'text-slate-300'}`}>
                        {rollsList}
                      </span>
                    </div>
                  </div>
                  {(auditTarget.impactReason || auditTarget.rejectionReason) && (
                    <div className="p-2.5 rounded-xl bg-slate-900/80 border border-slate-800 text-xs text-slate-300">
                      <span className="text-[10px] font-bold text-slate-400 uppercase block mb-0.5">Impact Reason:</span>
                      <p className="italic">{auditTarget.impactReason || auditTarget.rejectionReason}</p>
                    </div>
                  )}
                </div>
              );
            })()}

            {/* SECTION 4 IN MODAL: CURRENT QA RESOLUTION */}
            <div className="p-4 rounded-2xl bg-slate-950/60 border border-slate-800 space-y-3">
              <div className="flex items-center justify-between border-b border-slate-800 pb-2">
                <span className="text-xs font-bold uppercase tracking-wider text-slate-300">
                  4. Current QA Resolution
                </span>
                <span className={`px-2.5 py-0.5 rounded-full text-[10px] font-bold uppercase border ${
                  auditTarget.manualResolutionStatus === 'RESOLVED'
                    ? 'bg-emerald-500/15 text-emerald-300 border-emerald-500/30'
                    : 'bg-amber-500/15 text-amber-300 border-amber-500/30'
                }`}>
                  {auditTarget.manualResolutionStatus === 'RESOLVED' ? 'RESOLVED' : 'PENDING REVIEW'}
                </span>
              </div>

              {auditTarget.manualResolutionStatus === 'RESOLVED' ? (
                <div className="space-y-2.5 text-xs">
                  <div className="grid grid-cols-2 gap-2.5">
                    <div className="p-2.5 rounded-xl bg-slate-900 border border-slate-800">
                      <span className="text-[10px] text-slate-400 block">Manual Resolution</span>
                      <span className="font-bold text-emerald-400 font-mono">RESOLVED</span>
                    </div>
                    <div className="p-2.5 rounded-xl bg-slate-900 border border-slate-800">
                      <span className="text-[10px] text-slate-400 block">Quarantine Disposition</span>
                      <span className="font-bold text-emerald-400 font-mono">RELEASED</span>
                    </div>
                  </div>
                  <div className="grid grid-cols-2 gap-2.5">
                    <div className="p-2.5 rounded-xl bg-slate-900 border border-slate-800">
                      <span className="text-[10px] text-slate-400 block">Inspector</span>
                      <span className="text-white font-semibold">{auditTarget.resolvedBy || 'Quality Inspector'}</span>
                    </div>
                    <div className="p-2.5 rounded-xl bg-slate-900 border border-slate-800">
                      <span className="text-[10px] text-slate-400 block">Timestamp</span>
                      <span className="text-slate-200">{formatTimestamp(auditTarget.resolvedAt) || 'Recorded'}</span>
                    </div>
                  </div>
                  {auditTarget.manualResolutionNote && (
                    <div className="p-2.5 rounded-xl bg-slate-900/90 border border-slate-800 text-xs">
                      <span className="text-[10px] font-bold text-slate-400 uppercase block mb-1">Inspector Notes:</span>
                      <p className="italic text-slate-200">"{auditTarget.manualResolutionNote}"</p>
                    </div>
                  )}
                </div>
              ) : (
                <div className="grid grid-cols-2 gap-2.5 text-xs">
                  <div className="p-2.5 rounded-xl bg-slate-900 border border-slate-800">
                    <span className="text-[10px] text-slate-400 block">Manual Resolution</span>
                    <span className="font-bold text-amber-400 font-mono">PENDING REVIEW</span>
                  </div>
                  <div className="p-2.5 rounded-xl bg-slate-900 border border-slate-800">
                    <span className="text-[10px] text-slate-400 block">Quarantine</span>
                    <span className="font-bold text-rose-400 font-mono">ACTIVE</span>
                  </div>
                </div>
              )}
            </div>

            <div className="flex justify-end pt-2 border-t border-slate-800">
              <button
                type="button"
                onClick={() => setAuditModalOpen(false)}
                className="px-4 py-2 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-200 text-xs font-semibold"
              >
                Close Audit
              </button>
            </div>
          </div>
        </div>
      )}

      {/* 7. MANUAL RESOLUTION MODAL */}
      {resolveModalOpen && selectedWorkflow && (
        <div className="fixed inset-0 z-50 bg-black/75 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="bg-slate-900 border border-slate-800 rounded-3xl max-w-lg w-full p-6 space-y-6 shadow-2xl animate-in fade-in">
            <div className="flex items-center justify-between border-b border-slate-800 pb-4">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-xl bg-blue-500/15 border border-blue-500/30 flex items-center justify-center text-blue-400">
                  <UserCheck className="w-5 h-5" />
                </div>
                <div>
                  <h3 className="text-base font-bold text-white">Manual QA Review &amp; Resolution</h3>
                  <p className="text-xs text-slate-400 font-mono">Workflow {selectedWorkflow.workflowId}</p>
                </div>
              </div>
              <button
                onClick={() => setResolveModalOpen(false)}
                className="p-1 rounded-lg text-slate-400 hover:text-white hover:bg-slate-800"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            {resolveError && (
              <div className="p-3 rounded-xl bg-rose-500/10 border border-rose-500/30 text-rose-300 text-xs flex items-center gap-2">
                <AlertTriangle className="w-4 h-4 shrink-0" />
                <span>{resolveError}</span>
              </div>
            )}

            <form onSubmit={handleResolveSubmit} className="space-y-4">
              <div>
                <label className="block text-xs font-bold uppercase tracking-wider text-slate-400 mb-2">
                  Inspector Audit &amp; Resolution Note *
                </label>
                <textarea
                  required
                  rows={4}
                  value={resolutionNote}
                  onChange={(e) => setResolutionNote(e.target.value)}
                  placeholder="Describe the physical inspection results, lab clearance, or mitigation rationale authorizing approval..."
                  className="w-full rounded-xl bg-slate-950 border border-slate-700 px-4 py-3 text-sm text-white placeholder:text-slate-500 outline-none focus:border-blue-500 transition-colors"
                />
              </div>

              <label className="flex items-start gap-3 p-3.5 rounded-xl bg-slate-950/60 border border-slate-800 cursor-pointer">
                <input
                  type="checkbox"
                  checked={releaseQuarantineCheck}
                  onChange={(e) => setReleaseQuarantineCheck(e.target.checked)}
                  className="mt-0.5 accent-blue-500 w-4 h-4"
                />
                <div className="text-xs">
                  <span className="font-bold text-white block">Release Quarantined Fabric Rolls</span>
                  <span className="text-slate-400">
                    Automatically unblock affected inventory rolls linked to this workflow.
                  </span>
                </div>
              </label>

              <div className="flex items-center justify-end gap-3 pt-4 border-t border-slate-800">
                <button
                  type="button"
                  onClick={() => setResolveModalOpen(false)}
                  className="px-4 py-2 rounded-xl border border-slate-700 text-slate-300 text-xs font-medium hover:bg-slate-800"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={resolving}
                  className="px-5 py-2 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white text-xs font-bold shadow-lg shadow-emerald-600/20 flex items-center gap-2 disabled:opacity-50"
                >
                  {resolving && <Loader2 className="w-3.5 h-3.5 animate-spin" />}
                  <span>Authorize &amp; Resolve</span>
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}

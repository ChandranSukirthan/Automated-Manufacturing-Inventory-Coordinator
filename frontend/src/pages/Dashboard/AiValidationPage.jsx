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
  Eye,
  Info
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

// Helper for formatting timestamps strictly from real data
const formatTimestamp = (dateStr) => {
  if (!dateStr) return 'Not available';
  try {
    const date = new Date(dateStr);
    if (isNaN(date.getTime())) return 'Not available';
    return date.toLocaleString('en-US', {
      month: 'short',
      day: 'numeric',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    });
  } catch {
    return 'Not available';
  }
};

// Helper for individual check mapping (DO NOT INFER MISSING VALUES AS PASSED)
const mapCheckStatus = (val) => {
  if (val === null || val === undefined || val === '') {
    return { label: 'Not available', style: 'bg-slate-900 text-slate-500 border-slate-800', isAvailable: false };
  }
  const s = String(val).toUpperCase().trim();
  if (s === 'PASSED' || s === 'CLEAR' || s === 'VALID' || s === 'TRUE') {
    return { label: 'PASSED', style: 'bg-emerald-500/15 text-emerald-300 border-emerald-500/35 font-mono', isAvailable: true };
  }
  if (s === 'FAILED' || s === 'INVALID' || s === 'BLOCKED' || s === 'FALSE') {
    return { label: 'FAILED', style: 'bg-rose-500/15 text-rose-300 border-rose-500/40 font-bold font-mono', isAvailable: true };
  }
  if (s === 'EXCEEDS_BUDGET_THRESHOLD') {
    return { label: 'EXCEEDS THRESHOLD', style: 'bg-amber-500/15 text-amber-300 border-amber-500/35 font-mono', isAvailable: true };
  }
  return { label: s, style: 'bg-slate-800 text-slate-300 border-slate-700 font-mono', isAvailable: true };
};

// Helper for aggregate automated checks (ONLY SHOW 4/4 PASSED IF ALL 4 ARE PRESENT & PASSED)
const formatAutomatedChecks = (item) => {
  if (!item) return { summary: 'Not available', allPassed: false, isAvailable: false, details: [] };

  const checks = [
    { name: 'Supplier Check', key: 'supplier', val: item.supplierValidation || item.supplierCheck },
    { name: 'Budget Check', key: 'budget', val: item.budgetCheck },
    { name: 'PO Math Check', key: 'poMath', val: item.poMathematicalCheck || item.poMathCheck },
    { name: 'Material Check', key: 'material', val: item.materialValidation || item.materialCheck }
  ];

  const presentChecks = checks.filter(c => c.val !== null && c.val !== undefined && c.val !== '');
  if (presentChecks.length === 0) {
    return { summary: 'Not available', allPassed: false, isAvailable: false, details: checks };
  }

  const passedChecks = checks.filter(c => {
    if (!c.val) return false;
    const s = String(c.val).toUpperCase().trim();
    return s === 'PASSED' || s === 'CLEAR' || s === 'VALID' || s === 'TRUE';
  });

  if (presentChecks.length === 4 && passedChecks.length === 4) {
    return { summary: '4 / 4 PASSED', allPassed: true, isAvailable: true, details: checks };
  }

  if (presentChecks.length === 4) {
    return { summary: `${passedChecks.length} / 4 PASSED`, allPassed: false, isAvailable: true, details: checks };
  }

  return { summary: `${passedChecks.length} / ${presentChecks.length} PASSED`, allPassed: false, isAvailable: true, details: checks };
};

// Helper to extract unified Original AI vs Current QA state from a SINGLE workflow record
const getWorkflowState = (item) => {
  if (!item) {
    return {
      origAiOutcome: 'Not available',
      origSafetyStatus: 'Not available',
      quarantinedRollsDisplay: 'Not available',
      highImpactDisplay: 'Not available',
      currentManualResolution: 'Not available',
      currentQuarantineDisposition: 'Not available',
      safetyGateState: 'Not available',
      isSafetyBlocked: false,
      isResolved: false,
      needsReview: false
    };
  }

  const hasExplicitValid = item.isValid !== null && item.isValid !== undefined;
  const safety = item.qualitySafetyStatus ? String(item.qualitySafetyStatus).toUpperCase().trim() : null;
  const manual = item.manualResolutionStatus ? String(item.manualResolutionStatus).toUpperCase().trim() : null;
  const quarantinedCount = item.quarantinedRollsCount !== null && item.quarantinedRollsCount !== undefined ? item.quarantinedRollsCount : null;

  // 1. Original AI Assessment (Strictly Preserved)
  let origAiOutcome = 'Not available';
  if (hasExplicitValid) {
    origAiOutcome = item.isValid ? 'VALID' : 'INVALID';
  } else if (safety) {
    origAiOutcome = (safety === 'CLEAR' || safety === 'PASSED') ? 'VALID' : 'INVALID';
  }

  const origSafetyStatus = safety || (quarantinedCount !== null ? (quarantinedCount > 0 ? 'QUARANTINE_ACTIVE' : 'CLEAR') : 'Not available');
  const quarantinedRollsDisplay = quarantinedCount !== null ? `${quarantinedCount} roll(s)` : 'Not available';
  const highImpactDisplay = item.isHighImpact !== null && item.isHighImpact !== undefined ? (item.isHighImpact ? 'YES' : 'NO') : 'Not available';

  // 2. Current QA & Quarantine State (Based on same workflow)
  const isResolved = manual === 'RESOLVED';
  const hasQuarantineTrigger = safety?.includes('QUARANTINE') || safety === 'BLOCKED' || (quarantinedCount !== null && quarantinedCount > 0) || item.isValid === false;

  let currentManualResolution = 'Not available';
  let currentQuarantineDisposition = 'Not available';
  let isSafetyBlocked = false;
  let needsReview = false;

  if (isResolved) {
    currentManualResolution = 'RESOLVED';
    currentQuarantineDisposition = 'RELEASED';
  } else if (manual === 'NOT_REQUIRED' || (safety === 'CLEAR' && (quarantinedCount === 0 || quarantinedCount === null) && item.isValid !== false)) {
    currentManualResolution = 'NOT REQUIRED';
    currentQuarantineDisposition = 'NONE';
  } else if (hasQuarantineTrigger) {
    currentManualResolution = 'PENDING REVIEW';
    currentQuarantineDisposition = 'ACTIVE';
    isSafetyBlocked = true;
    needsReview = true;
  } else if (safety) {
    currentManualResolution = 'NOT REQUIRED';
    currentQuarantineDisposition = 'NONE';
  }

  // 3. Safety Gate Status
  let safetyGateState = 'Not available';
  if (safety || hasExplicitValid || quarantinedCount !== null) {
    if (isResolved) {
      safetyGateState = 'RESOLVED';
    } else if (isSafetyBlocked) {
      safetyGateState = 'BLOCKED';
    } else {
      safetyGateState = 'CLEAR';
    }
  }

  return {
    origAiOutcome,
    origSafetyStatus,
    quarantinedRollsDisplay,
    highImpactDisplay,
    currentManualResolution,
    currentQuarantineDisposition,
    safetyGateState,
    isSafetyBlocked,
    isResolved,
    needsReview
  };
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
    let blockedCount = 0;
    let highImpactCount = 0;

    aiValidationHistory.forEach((item) => {
      const state = getWorkflowState(item);
      if (state.safetyGateState === 'CLEAR') {
        clearCount++;
      } else if (state.safetyGateState === 'BLOCKED' || state.safetyGateState === 'RESOLVED') {
        blockedCount++;
      }
      if (item.isHighImpact === true) {
        highImpactCount++;
      }
    });

    return {
      total: aiValidationHistory.length,
      clear: clearCount,
      blocked: blockedCount,
      highImpact: highImpactCount
    };
  }, [aiValidationHistory]);

  // Derived state for the latest workflow (ensuring BOTH sections refer to the SAME workflow record)
  const latestState = useMemo(() => getWorkflowState(aiValidation), [aiValidation]);
  const latestAutomated = useMemo(() => formatAutomatedChecks(aiValidation), [aiValidation]);
  const latestPoNumber = extractPoNumber(aiValidation);
  const latestAssessed = formatTimestamp(
    aiValidation?.resolvedAt || aiValidation?.assessmentTimestamp || aiValidation?.startedAt || aiValidation?.createdAt
  );

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
            Authoritative quality assurance ledger: Multi-agent validation rules and physical quarantine safety gates
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

      {/* 2. LATEST VALIDATION & SAFETY AGENT ASSESSMENT */}
      <section className="rounded-3xl border border-slate-800 bg-slate-900/60 p-6 sm:p-8 backdrop-blur-sm space-y-8 shadow-sm">
        {/* Section Header */}
        <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between border-b border-slate-800/80 pb-4 gap-3">
          <div>
            <div className="flex items-center gap-2 mb-1">
              <span className="text-blue-400 font-mono text-xs font-bold uppercase tracking-wider">Authoritative Record</span>
              <span className="text-slate-600">•</span>
              <span className="text-xs text-slate-400 font-mono">PO Reference: <strong className="text-white">{latestPoNumber}</strong></span>
            </div>
            <h2 className="text-xl font-extrabold text-white tracking-tight">
              Latest Validation &amp; Safety Assessment
            </h2>
            <p className="text-xs text-slate-400 mt-0.5">
              Dual-layer verification: Automated AI rule diagnostics vs. Authoritative QA Safety Gate
            </p>
          </div>
          <div className="flex items-center gap-3">
            <span className="text-xs text-slate-400 font-mono bg-slate-950 px-3 py-1.5 rounded-xl border border-slate-800">
              Assessed: <span className="text-slate-200">{latestAssessed}</span>
            </span>
            {latestState.needsReview && (
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
            {/* Top Workflow Summary Bar */}
            <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 text-xs">
              <div className="p-3.5 rounded-xl bg-slate-950/70 border border-slate-800">
                <span className="text-[10px] uppercase font-bold text-slate-400 block">Workflow ID</span>
                <span className="text-sm font-bold font-mono text-blue-300 truncate block mt-0.5">
                  {aiValidation.workflowId || 'Not available'}
                </span>
              </div>
              <div className="p-3.5 rounded-xl bg-slate-950/70 border border-slate-800">
                <span className="text-[10px] uppercase font-bold text-slate-400 block">PO Number</span>
                <span className="text-sm font-bold font-mono text-slate-200 truncate block mt-0.5">
                  {latestPoNumber}
                </span>
              </div>
              <div className="p-3.5 rounded-xl bg-slate-950/70 border border-slate-800">
                <span className="text-[10px] uppercase font-bold text-slate-400 block">Workflow Status</span>
                <span className="text-sm font-semibold text-slate-200 block mt-0.5">
                  {aiValidation.status || 'Running'}
                </span>
              </div>
              <div className="p-3.5 rounded-xl bg-slate-950/70 border border-slate-800">
                <span className="text-[10px] uppercase font-bold text-slate-400 block">Assessed Timestamp</span>
                <span className="text-sm font-medium text-slate-300 block mt-0.5">
                  {latestAssessed}
                </span>
              </div>
            </div>

            {/* SECTION A: AUTOMATED VERIFICATION (NO FAKE 4/4) */}
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
                <div>
                  <span className={`px-3 py-1 rounded-full text-xs font-bold border flex items-center gap-1.5 font-mono ${
                    latestAutomated.allPassed
                      ? 'bg-emerald-500/15 text-emerald-300 border-emerald-500/35'
                      : latestAutomated.isAvailable
                      ? 'bg-amber-500/15 text-amber-300 border-amber-500/35'
                      : 'bg-slate-900 text-slate-400 border-slate-800'
                  }`}>
                    {latestAutomated.allPassed && <CheckCircle2 className="w-3.5 h-3.5 text-emerald-400" />}
                    <span>{latestAutomated.summary}</span>
                  </span>
                </div>
              </div>

              {/* 4 Checks Grid */}
              <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3">
                {latestAutomated.details.map((checkItem) => {
                  const check = mapCheckStatus(checkItem.val);
                  return (
                    <div key={checkItem.key} className="p-3.5 rounded-xl bg-slate-900 border border-slate-800/80 space-y-2">
                      <div className="flex items-center justify-between">
                        <span className="text-xs font-bold text-slate-300">{checkItem.name}</span>
                        <span className={`px-2 py-0.5 rounded-full text-[10px] font-bold uppercase border ${check.style}`}>
                          {check.label}
                        </span>
                      </div>
                      <p className="text-[11px] text-slate-400 font-mono truncate">
                        {checkItem.val ? String(checkItem.val) : 'Not available'}
                      </p>
                    </div>
                  );
                })}
              </div>
            </div>

            {/* SECTION B: SAFETY GATE */}
            <div className={`rounded-2xl border p-5 space-y-3 ${
              latestState.isSafetyBlocked
                ? 'border-rose-500/40 bg-rose-950/20'
                : latestState.safetyGateState === 'RESOLVED'
                ? 'border-emerald-500/30 bg-emerald-950/20'
                : latestState.safetyGateState === 'CLEAR'
                ? 'border-emerald-500/30 bg-emerald-950/15'
                : 'border-slate-800 bg-slate-950/70'
            }`}>
              <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2 border-b border-slate-800/80 pb-3">
                <div className="flex items-center gap-2.5">
                  <div className={`w-7 h-7 rounded-lg flex items-center justify-center font-bold text-xs border ${
                    latestState.isSafetyBlocked
                      ? 'bg-rose-500/20 text-rose-400 border-rose-500/30'
                      : latestState.safetyGateState === 'RESOLVED' || latestState.safetyGateState === 'CLEAR'
                      ? 'bg-emerald-500/20 text-emerald-400 border-emerald-500/30'
                      : 'bg-slate-800 text-slate-400 border-slate-700'
                  }`}>
                    2
                  </div>
                  <div>
                    <h3 className="text-sm font-bold text-white uppercase tracking-wider">Safety Gate</h3>
                    <p className="text-[11px] text-slate-400">Physical quarantine containment &amp; fabric roll defect gate</p>
                  </div>
                </div>

                <div>
                  <span className={`inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-black uppercase tracking-wider border ${
                    latestState.isSafetyBlocked
                      ? 'bg-rose-500/20 text-rose-300 border-rose-500/40 shadow-sm'
                      : latestState.safetyGateState === 'RESOLVED'
                      ? 'bg-emerald-500/20 text-emerald-300 border-emerald-500/40 font-mono'
                      : latestState.safetyGateState === 'CLEAR'
                      ? 'bg-emerald-500/15 text-emerald-300 border-emerald-500/35'
                      : 'bg-slate-900 text-slate-400 border-slate-800'
                  }`}>
                    {latestState.isSafetyBlocked && <span className="w-2 h-2 rounded-full bg-rose-400 animate-ping" />}
                    {latestState.safetyGateState === 'RESOLVED' && <span className="w-2 h-2 rounded-full bg-emerald-400" />}
                    {latestState.safetyGateState === 'CLEAR' && <span className="w-2 h-2 rounded-full bg-emerald-400" />}
                    {latestState.safetyGateState}
                  </span>
                </div>
              </div>

              <div className="text-xs space-y-1.5">
                <span className="font-bold text-slate-300 uppercase tracking-wider text-[10px] block">
                  Safety Gate Diagnostic Reason:
                </span>
                <p className={`p-3 rounded-xl border leading-relaxed ${
                  latestState.isSafetyBlocked
                    ? 'bg-rose-950/40 border-rose-500/30 text-rose-200'
                    : 'bg-slate-950/60 border-slate-800 text-slate-300'
                }`}>
                  {aiValidation.impactReason || (latestState.isSafetyBlocked
                    ? 'Active fabric roll quarantine holds detected. Order approval is BLOCKED until Quality Inspector manual review and resolution.'
                    : latestState.safetyGateState === 'RESOLVED'
                    ? 'Safety hold was reviewed and released by Quality Inspector.'
                    : latestState.safetyGateState === 'CLEAR'
                    ? 'No active quarantine holds or defect alerts on fabric inventory. Safety gate is CLEAR.'
                    : 'Not available')}
                </p>
              </div>
            </div>

            {/* SECTION C & D: TWO-COLUMN SPLIT FOR ORIGINAL AI ASSESSMENT VS CURRENT QA RESOLUTION (SAME WORKFLOW SOURCE OF TRUTH) */}
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
                    <span className={`text-base font-black block font-mono ${
                      latestState.origAiOutcome === 'VALID' ? 'text-emerald-400' : latestState.origAiOutcome === 'INVALID' ? 'text-rose-400' : 'text-slate-400'
                    }`}>
                      {latestState.origAiOutcome}
                    </span>
                    <span className="text-[10px] text-slate-500 block">Initial AI agent finding</span>
                  </div>

                  {/* Quality Safety Status */}
                  <div className="p-3 rounded-xl bg-slate-900 border border-slate-800/80 space-y-1">
                    <span className="text-[10px] font-bold uppercase text-slate-400 block">Quality Safety Status</span>
                    <span className={`text-xs font-bold uppercase block truncate font-mono ${
                      latestState.origSafetyStatus === 'CLEAR' ? 'text-emerald-300' : latestState.origSafetyStatus.includes('QUARANTINE') ? 'text-rose-300 font-bold' : 'text-slate-400'
                    }`}>
                      {latestState.origSafetyStatus}
                    </span>
                    <span className="text-[10px] text-slate-500 block">Original safety flag</span>
                  </div>

                  {/* Quarantined Rolls */}
                  <div className="p-3 rounded-xl bg-slate-900 border border-slate-800/80 space-y-1">
                    <span className="text-[10px] font-bold uppercase text-slate-400 block">Quarantined Rolls</span>
                    <span className={`text-base font-black font-mono block ${
                      aiValidation.quarantinedRollsCount > 0 ? 'text-rose-400' : 'text-slate-300'
                    }`}>
                      {latestState.quarantinedRollsDisplay}
                    </span>
                    <span className="text-[10px] text-slate-500 block">Flagged for inspection</span>
                  </div>

                  {/* High Impact (Distinct Separate Metric - NOT QA Failure) */}
                  <div className="p-3 rounded-xl bg-slate-900 border border-slate-800/80 space-y-1">
                    <span className="text-[10px] font-bold uppercase text-slate-400 block">High Impact</span>
                    <div className="flex items-center gap-1.5 mt-0.5">
                      <span className={`px-2 py-0.5 rounded text-[11px] font-bold uppercase font-mono ${
                        aiValidation.isHighImpact === true
                          ? 'bg-amber-500/15 text-amber-300 border border-amber-500/35'
                          : aiValidation.isHighImpact === false
                          ? 'bg-slate-800 text-slate-400 border border-slate-700'
                          : 'bg-slate-900 text-slate-500'
                      }`}>
                        {latestState.highImpactDisplay}
                      </span>
                    </div>
                    <span className="text-[10px] text-slate-500 block">Production priority flag</span>
                  </div>
                </div>

                {aiValidation.impactReason && (
                  <div className="p-3 rounded-xl bg-slate-900/90 border border-slate-800/90 text-xs">
                    <span className="font-bold text-slate-400 uppercase text-[10px] block mb-1">Original Diagnostic Finding:</span>
                    <p className="text-slate-300 leading-relaxed italic">{aiValidation.impactReason}</p>
                  </div>
                )}
              </div>

              {/* SECTION D: CURRENT QA RESOLUTION STATE (Accurately Derived from the Same Record) */}
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
                    latestState.currentManualResolution === 'RESOLVED'
                      ? 'bg-emerald-500/15 text-emerald-300 border-emerald-500/30 font-mono'
                      : latestState.currentManualResolution === 'NOT REQUIRED'
                      ? 'bg-slate-800 text-slate-300 border-slate-700 font-mono'
                      : latestState.currentManualResolution === 'PENDING REVIEW'
                      ? 'bg-rose-500/15 text-rose-300 border-rose-500/30 font-mono'
                      : 'bg-slate-900 text-slate-500 border-slate-800'
                  }`}>
                    {latestState.currentManualResolution}
                  </span>
                </div>

                {latestState.currentManualResolution === 'RESOLVED' ? (
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
                        <span className="text-[10px] font-bold uppercase text-slate-400 block">Resolved At</span>
                        <span className="text-slate-200 block truncate font-mono">
                          {formatTimestamp(aiValidation.resolvedAt)}
                        </span>
                        <span className="text-[10px] text-slate-500 block">Time of sign-off</span>
                      </div>
                    </div>

                    {aiValidation.manualResolutionNote && (
                      <div className="p-3.5 rounded-xl bg-blue-950/30 border border-blue-500/20 text-xs">
                        <span className="text-blue-300 font-bold uppercase text-[10px] block mb-1">Inspector Resolution Note:</span>
                        <p className="text-slate-200 leading-relaxed italic bg-slate-950/60 p-2.5 rounded-lg border border-slate-800">
                          "{aiValidation.manualResolutionNote}"
                        </p>
                      </div>
                    )}
                  </div>
                ) : latestState.currentManualResolution === 'NOT REQUIRED' ? (
                  <div className="space-y-3 text-xs">
                    <div className="grid grid-cols-2 gap-3">
                      <div className="p-3 rounded-xl bg-slate-900 border border-slate-800/80 space-y-1">
                        <span className="text-[10px] font-bold uppercase text-slate-400 block">Manual Resolution</span>
                        <span className="text-slate-200 font-bold font-mono text-sm block">NOT REQUIRED</span>
                        <span className="text-[10px] text-slate-500 block">Safety gate clear</span>
                      </div>

                      <div className="p-3 rounded-xl bg-slate-900 border border-slate-800/80 space-y-1">
                        <span className="text-[10px] font-bold uppercase text-slate-400 block">Quarantine Disposition</span>
                        <span className="text-slate-200 font-bold font-mono text-sm block">NONE</span>
                        <span className="text-[10px] text-slate-500 block">No quarantined rolls</span>
                      </div>
                    </div>

                    <div className="p-3.5 rounded-xl bg-slate-900/80 border border-slate-800 text-slate-300 leading-relaxed">
                      No active quarantine holds or defect containment on this order. Manual Quality Inspector review is not required for approval.
                    </div>
                  </div>
                ) : latestState.currentManualResolution === 'PENDING REVIEW' ? (
                  <div className="space-y-4">
                    <div className="grid grid-cols-2 gap-3 text-xs">
                      <div className="p-3 rounded-xl bg-slate-900 border border-slate-800/80 space-y-1">
                        <span className="text-[10px] font-bold uppercase text-slate-400 block">Manual Resolution</span>
                        <span className="text-rose-400 font-bold font-mono text-sm block">PENDING REVIEW</span>
                        <span className="text-[10px] text-slate-500 block">Awaiting QA action</span>
                      </div>

                      <div className="p-3 rounded-xl bg-slate-900 border border-slate-800/80 space-y-1">
                        <span className="text-[10px] font-bold uppercase text-slate-400 block">Quarantine Disposition</span>
                        <span className="text-rose-400 font-bold font-mono text-sm block">ACTIVE</span>
                        <span className="text-[10px] text-slate-500 block">Inventory holds enforced</span>
                      </div>
                    </div>

                    <div className="p-3.5 rounded-xl bg-rose-500/10 border border-rose-500/20 text-xs text-rose-200/90 space-y-2">
                      <p className="leading-relaxed">
                        Physical inspection or lab certification is required to clear active quarantine hold. Click below to record inspector notes and authorize workflow release.
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
                ) : (
                  <div className="p-4 rounded-xl bg-slate-900 border border-slate-800 text-xs text-slate-400">
                    Manual resolution data is not available for this record.
                  </div>
                )}
              </div>
            </div>
          </div>
        )}
      </section>

      {/* 3. HISTORY MONITORING SUMMARY */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
        <div className="p-4 rounded-2xl bg-slate-900/60 border border-slate-800 backdrop-blur-sm">
          <span className="text-xs font-bold uppercase tracking-wider text-slate-400 block">Persisted Runs</span>
          <p className="text-2xl font-black text-white mt-2 font-mono">{historyStats.total}</p>
          <span className="text-[11px] text-slate-400 mt-1 block">Total audited workflows</span>
        </div>

        <div className="p-4 rounded-2xl bg-slate-900/60 border border-slate-800 backdrop-blur-sm">
          <span className="text-xs font-bold uppercase tracking-wider text-emerald-400 block">Clear Safety Runs</span>
          <p className="text-2xl font-black text-emerald-400 mt-2 font-mono">{historyStats.clear}</p>
          <span className="text-[11px] text-slate-400 mt-1 block">No quarantine holds</span>
        </div>

        <div className="p-4 rounded-2xl bg-slate-900/60 border border-slate-800 backdrop-blur-sm">
          <span className="text-xs font-bold uppercase tracking-wider text-rose-400 block">Quarantine Audits</span>
          <p className="text-2xl font-black text-rose-400 mt-2 font-mono">{historyStats.blocked}</p>
          <span className="text-[11px] text-slate-400 mt-1 block">Triggered / Resolved holds</span>
        </div>

        <div className="p-4 rounded-2xl bg-slate-900/60 border border-slate-800 backdrop-blur-sm">
          <span className="text-xs font-bold uppercase tracking-wider text-amber-400 block">High Impact</span>
          <p className="text-2xl font-black text-amber-300 mt-2 font-mono">{historyStats.highImpact}</p>
          <span className="text-[11px] text-slate-400 mt-1 block">Production critical items</span>
        </div>
      </div>

      {/* 4. ASSESSMENT HISTORY TABLE */}
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
                    const state = getWorkflowState(item);
                    const automated = formatAutomatedChecks(item);

                    const assessedDate = formatTimestamp(
                      item.resolvedAt || item.assessmentTimestamp || item.startedAt || item.createdAt
                    );

                    return (
                      <tr key={item.workflowId} className="hover:bg-slate-900/50 transition-colors">
                        <td className="px-4 py-3 font-mono font-semibold text-blue-300">
                          {item.workflowId}
                        </td>
                        <td className="px-4 py-3 font-mono text-slate-300">
                          {poNum}
                        </td>
                        <td className="px-4 py-3">
                          <span className={`px-2 py-0.5 rounded-full text-[10px] font-bold font-mono border ${
                            automated.allPassed
                              ? 'bg-emerald-500/10 text-emerald-400 border-emerald-500/30'
                              : automated.isAvailable
                              ? 'bg-amber-500/10 text-amber-300 border-amber-500/30'
                              : 'bg-slate-900 text-slate-500 border-slate-800'
                          }`}>
                            {automated.summary}
                          </span>
                        </td>
                        <td className="px-4 py-3">
                          <span
                            className={`inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-[10px] font-bold uppercase border ${
                              state.safetyGateState === 'CLEAR'
                                ? 'bg-emerald-500/15 text-emerald-300 border-emerald-500/35'
                                : state.safetyGateState === 'RESOLVED'
                                ? 'bg-emerald-500/15 text-emerald-300 border-emerald-500/35 font-mono'
                                : state.safetyGateState === 'BLOCKED'
                                ? 'bg-rose-500/15 text-rose-300 border-rose-500/40'
                                : 'bg-slate-900 text-slate-500 border-slate-800'
                            }`}
                          >
                            {state.safetyGateState === 'CLEAR' && <span className="w-1.5 h-1.5 rounded-full bg-emerald-400" />}
                            {state.safetyGateState === 'BLOCKED' && <span className="w-1.5 h-1.5 rounded-full bg-rose-400 animate-pulse" />}
                            {state.safetyGateState === 'RESOLVED' && <span className="w-1.5 h-1.5 rounded-full bg-emerald-400" />}
                            {state.safetyGateState}
                          </span>
                        </td>
                        <td className="px-4 py-3">
                          <span className={`font-mono font-bold text-xs ${
                            state.origAiOutcome === 'VALID' ? 'text-emerald-400' : state.origAiOutcome === 'INVALID' ? 'text-rose-400' : 'text-slate-500'
                          }`}>
                            {state.origAiOutcome}
                          </span>
                        </td>
                        <td className="px-4 py-3">
                          <span
                            className={`px-2 py-0.5 rounded-full text-[10px] font-bold uppercase border ${
                              state.currentManualResolution === 'RESOLVED'
                                ? 'bg-emerald-500/15 text-emerald-300 border-emerald-500/30 font-mono'
                                : state.currentManualResolution === 'NOT REQUIRED'
                                ? 'bg-slate-800 text-slate-400 border-slate-700 font-mono'
                                : state.currentManualResolution === 'PENDING REVIEW'
                                ? 'bg-rose-500/15 text-rose-300 border-rose-500/40'
                                : 'bg-slate-900 text-slate-500 border-slate-800'
                            }`}
                          >
                            {state.currentManualResolution}
                          </span>
                        </td>
                        <td className="px-4 py-3 text-slate-400 font-mono">
                          {assessedDate}
                        </td>
                        <td className="px-4 py-3 text-right">
                          <div className="flex items-center justify-end gap-2">
                            {state.needsReview && (
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
                const state = getWorkflowState(item);
                const automated = formatAutomatedChecks(item);
                const assessedDate = formatTimestamp(
                  item.resolvedAt || item.assessmentTimestamp || item.startedAt || item.createdAt
                );

                return (
                  <div key={item.workflowId} className="p-4 rounded-2xl bg-slate-950/60 border border-slate-800 space-y-3">
                    <div className="flex items-center justify-between">
                      <span className="font-mono font-bold text-blue-300 text-xs">{item.workflowId}</span>
                      <span
                        className={`px-2 py-0.5 rounded-full text-[10px] font-bold uppercase border ${
                          state.safetyGateState === 'CLEAR'
                            ? 'bg-emerald-500/15 text-emerald-300 border-emerald-500/35'
                            : state.safetyGateState === 'RESOLVED'
                            ? 'bg-emerald-500/15 text-emerald-300 border-emerald-500/35'
                            : state.safetyGateState === 'BLOCKED'
                            ? 'bg-rose-500/15 text-rose-300 border-rose-500/40'
                            : 'bg-slate-900 text-slate-500 border-slate-800'
                        }`}
                      >
                        Gate: {state.safetyGateState}
                      </span>
                    </div>
                    <div className="grid grid-cols-2 gap-2 text-xs text-slate-400">
                      <div>PO: <span className="text-white font-mono">{poNum}</span></div>
                      <div>Original AI: <span className={`font-bold font-mono ${state.origAiOutcome === 'VALID' ? 'text-emerald-400' : state.origAiOutcome === 'INVALID' ? 'text-rose-400' : 'text-slate-400'}`}>{state.origAiOutcome}</span></div>
                      <div>Automated: <span className="text-slate-200 font-mono font-semibold">{automated.summary}</span></div>
                      <div>QA State: <span className={`font-bold ${state.currentManualResolution === 'RESOLVED' ? 'text-emerald-400' : state.currentManualResolution === 'PENDING REVIEW' ? 'text-rose-400' : 'text-slate-300'}`}>{state.currentManualResolution}</span></div>
                    </div>
                    <div className="flex items-center justify-between pt-2 border-t border-slate-800">
                      <span className="text-[11px] text-slate-400 font-mono">
                        {assessedDate}
                      </span>
                      <div className="flex items-center gap-2">
                        {state.needsReview && (
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

      {/* 5. AUDIT DETAILS MODAL */}
      {auditModalOpen && auditTarget && (() => {
        const modalState = getWorkflowState(auditTarget);
        const modalAutomated = formatAutomatedChecks(auditTarget);
        const modalAssessed = formatTimestamp(
          auditTarget.resolvedAt || auditTarget.assessmentTimestamp || auditTarget.startedAt || auditTarget.createdAt
        );

        return (
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

              {/* Workflow Identification */}
              <div className="grid grid-cols-2 sm:grid-cols-4 gap-2.5 text-xs">
                <div className="p-3 rounded-xl bg-slate-950/70 border border-slate-800">
                  <span className="text-[10px] uppercase font-bold text-slate-400 block">Workflow ID</span>
                  <span className="font-mono text-blue-300 font-bold block truncate mt-0.5">{auditTarget.workflowId}</span>
                </div>
                <div className="p-3 rounded-xl bg-slate-950/70 border border-slate-800">
                  <span className="text-[10px] uppercase font-bold text-slate-400 block">PO Reference</span>
                  <span className="font-mono text-slate-200 font-bold block truncate mt-0.5">{extractPoNumber(auditTarget)}</span>
                </div>
                <div className="p-3 rounded-xl bg-slate-950/70 border border-slate-800">
                  <span className="text-[10px] uppercase font-bold text-slate-400 block">Status</span>
                  <span className="text-slate-200 font-semibold block truncate mt-0.5">{auditTarget.status || 'Running'}</span>
                </div>
                <div className="p-3 rounded-xl bg-slate-950/70 border border-slate-800">
                  <span className="text-[10px] uppercase font-bold text-slate-400 block">Assessed</span>
                  <span className="text-slate-300 font-mono block truncate mt-0.5">{modalAssessed}</span>
                </div>
              </div>

              {/* SECTION 1 IN MODAL: AUTOMATED VERIFICATION */}
              <div className="p-4 rounded-2xl bg-slate-950/60 border border-slate-800 space-y-3">
                <div className="flex items-center justify-between border-b border-slate-800/80 pb-2">
                  <span className="text-xs font-bold uppercase tracking-wider text-slate-300">
                    1. Automated Verification Checks
                  </span>
                  <span className={`px-2.5 py-0.5 rounded-full text-[10px] font-bold border font-mono ${
                    modalAutomated.allPassed
                      ? 'bg-emerald-500/15 text-emerald-300 border-emerald-500/30'
                      : modalAutomated.isAvailable
                      ? 'bg-amber-500/15 text-amber-300 border-amber-500/30'
                      : 'bg-slate-900 text-slate-500 border-slate-800'
                  }`}>
                    {modalAutomated.summary}
                  </span>
                </div>
                <div className="grid grid-cols-2 sm:grid-cols-4 gap-2.5 text-xs">
                  {modalAutomated.details.map((checkItem) => {
                    const check = mapCheckStatus(checkItem.val);
                    return (
                      <div key={checkItem.key} className="p-2.5 rounded-xl bg-slate-900 border border-slate-800">
                        <span className="text-[10px] text-slate-400 block mb-0.5">{checkItem.name}</span>
                        <span className={`block font-bold text-xs ${check.style}`}>
                          {check.label}
                        </span>
                      </div>
                    );
                  })}
                </div>
              </div>

              {/* SECTION 2 IN MODAL: SAFETY GATE */}
              <div className={`p-4 rounded-2xl border space-y-2 ${
                modalState.isSafetyBlocked
                  ? 'bg-rose-950/20 border-rose-500/40'
                  : modalState.safetyGateState === 'RESOLVED' || modalState.safetyGateState === 'CLEAR'
                  ? 'bg-emerald-950/15 border-emerald-500/30'
                  : 'bg-slate-950/60 border-slate-800'
              }`}>
                <div className="flex items-center justify-between border-b border-slate-800/80 pb-2">
                  <span className="text-xs font-bold uppercase tracking-wider text-slate-300">
                    2. Safety Gate
                  </span>
                  <span className={`px-2.5 py-0.5 rounded-full text-[10px] font-bold uppercase border ${
                    modalState.isSafetyBlocked
                      ? 'bg-rose-500/20 text-rose-300 border-rose-500/40'
                      : modalState.safetyGateState === 'RESOLVED' || modalState.safetyGateState === 'CLEAR'
                      ? 'bg-emerald-500/20 text-emerald-300 border-emerald-500/40 font-mono'
                      : 'bg-slate-900 text-slate-500 border-slate-800'
                  }`}>
                    {modalState.safetyGateState}
                  </span>
                </div>
                <div className="text-xs text-slate-300">
                  <span className="text-[10px] font-bold uppercase text-slate-400 block mb-1">Diagnostic Reason:</span>
                  <p className="leading-relaxed">
                    {auditTarget.impactReason || (modalState.isSafetyBlocked
                      ? 'Active fabric roll quarantine holds detected. Order approval is blocked until QA inspector resolution.'
                      : modalState.safetyGateState === 'RESOLVED'
                      ? 'Safety hold was reviewed and released by Quality Inspector.'
                      : modalState.safetyGateState === 'CLEAR'
                      ? 'No active quarantine holds or containment defects detected.'
                      : 'Not available')}
                  </p>
                </div>
              </div>

              {/* SECTION 3 IN MODAL: ORIGINAL AI ASSESSMENT */}
              <div className="p-4 rounded-2xl bg-slate-950/60 border border-slate-800 space-y-3">
                <div className="flex items-center justify-between border-b border-slate-800 pb-2">
                  <span className="text-xs font-bold uppercase tracking-wider text-slate-300">
                    3. Original AI Assessment (Preserved)
                  </span>
                  <span className="text-[10px] font-mono text-slate-400">Historical AI Finding</span>
                </div>
                <div className="grid grid-cols-2 sm:grid-cols-4 gap-2.5 text-xs">
                  <div className="p-2.5 rounded-xl bg-slate-900 border border-slate-800">
                    <span className="text-[10px] text-slate-400 block">Validation Outcome</span>
                    <span className={`font-bold font-mono text-sm block mt-0.5 ${
                      modalState.origAiOutcome === 'VALID' ? 'text-emerald-400' : modalState.origAiOutcome === 'INVALID' ? 'text-rose-400' : 'text-slate-400'
                    }`}>
                      {modalState.origAiOutcome}
                    </span>
                  </div>
                  <div className="p-2.5 rounded-xl bg-slate-900 border border-slate-800">
                    <span className="text-[10px] text-slate-400 block">Quality Safety Status</span>
                    <span className="font-bold text-white font-mono text-xs block mt-0.5 truncate">
                      {modalState.origSafetyStatus}
                    </span>
                  </div>
                  <div className="p-2.5 rounded-xl bg-slate-900 border border-slate-800">
                    <span className="text-[10px] text-slate-400 block">Quarantined Rolls</span>
                    <span className={`font-bold font-mono text-xs block mt-0.5 ${
                      auditTarget.quarantinedRollsCount > 0 ? 'text-rose-400' : 'text-slate-300'
                    }`}>
                      {modalState.quarantinedRollsDisplay}
                    </span>
                  </div>
                  <div className="p-2.5 rounded-xl bg-slate-900 border border-slate-800">
                    <span className="text-[10px] text-slate-400 block">High Impact</span>
                    <span className={`font-bold font-mono text-xs block mt-0.5 ${
                      auditTarget.isHighImpact === true ? 'text-amber-400' : 'text-slate-300'
                    }`}>
                      {modalState.highImpactDisplay}
                    </span>
                  </div>
                </div>
                {auditTarget.impactReason && (
                  <div className="p-2.5 rounded-xl bg-slate-900/80 border border-slate-800 text-xs text-slate-300">
                    <span className="text-[10px] font-bold text-slate-400 uppercase block mb-0.5">Impact Analysis:</span>
                    <p className="italic">{auditTarget.impactReason}</p>
                  </div>
                )}
              </div>

              {/* SECTION 4 IN MODAL: CURRENT QA RESOLUTION */}
              <div className="p-4 rounded-2xl bg-slate-950/60 border border-slate-800 space-y-3">
                <div className="flex items-center justify-between border-b border-slate-800 pb-2">
                  <span className="text-xs font-bold uppercase tracking-wider text-slate-300">
                    4. Current QA Resolution
                  </span>
                  <span className={`px-2.5 py-0.5 rounded-full text-[10px] font-bold uppercase border ${
                    modalState.currentManualResolution === 'RESOLVED'
                      ? 'bg-emerald-500/15 text-emerald-300 border-emerald-500/30 font-mono'
                      : modalState.currentManualResolution === 'NOT REQUIRED'
                      ? 'bg-slate-800 text-slate-300 border-slate-700 font-mono'
                      : modalState.currentManualResolution === 'PENDING REVIEW'
                      ? 'bg-rose-500/15 text-rose-300 border-rose-500/30 font-mono'
                      : 'bg-slate-900 text-slate-500 border-slate-800'
                  }`}>
                    {modalState.currentManualResolution}
                  </span>
                </div>

                {modalState.currentManualResolution === 'RESOLVED' ? (
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
                        <span className="text-[10px] text-slate-400 block">Resolved At</span>
                        <span className="text-slate-200 font-mono">{formatTimestamp(auditTarget.resolvedAt)}</span>
                      </div>
                    </div>
                    {auditTarget.manualResolutionNote && (
                      <div className="p-2.5 rounded-xl bg-slate-900/90 border border-slate-800 text-xs">
                        <span className="text-[10px] font-bold text-slate-400 uppercase block mb-1">Inspector Notes:</span>
                        <p className="italic text-slate-200">"{auditTarget.manualResolutionNote}"</p>
                      </div>
                    )}
                  </div>
                ) : modalState.currentManualResolution === 'NOT REQUIRED' ? (
                  <div className="grid grid-cols-2 gap-2.5 text-xs">
                    <div className="p-2.5 rounded-xl bg-slate-900 border border-slate-800">
                      <span className="text-[10px] text-slate-400 block">Manual Resolution</span>
                      <span className="font-bold text-slate-200 font-mono">NOT REQUIRED</span>
                    </div>
                    <div className="p-2.5 rounded-xl bg-slate-900 border border-slate-800">
                      <span className="text-[10px] text-slate-400 block">Quarantine</span>
                      <span className="font-bold text-slate-200 font-mono">NONE</span>
                    </div>
                  </div>
                ) : modalState.currentManualResolution === 'PENDING REVIEW' ? (
                  <div className="grid grid-cols-2 gap-2.5 text-xs">
                    <div className="p-2.5 rounded-xl bg-slate-900 border border-slate-800">
                      <span className="text-[10px] text-slate-400 block">Manual Resolution</span>
                      <span className="font-bold text-rose-400 font-mono">PENDING REVIEW</span>
                    </div>
                    <div className="p-2.5 rounded-xl bg-slate-900 border border-slate-800">
                      <span className="text-[10px] text-slate-400 block">Quarantine</span>
                      <span className="font-bold text-rose-400 font-mono">ACTIVE</span>
                    </div>
                  </div>
                ) : (
                  <div className="p-3 rounded-xl bg-slate-900 text-xs text-slate-400">
                    Not available
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
        );
      })()}

      {/* 6. MANUAL RESOLUTION MODAL */}
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

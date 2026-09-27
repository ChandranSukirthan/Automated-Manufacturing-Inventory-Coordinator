import React, { Fragment, useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import {
  AlertTriangle,
  AlertCircle,
  ClipboardList,
  ShieldAlert,
  ShieldCheck,
  Package,
  CheckCircle2,
  PlusCircle,
  FileText,
  History,
  ChevronRight,
  ChevronDown,
  ChevronUp,
  Loader2,
  Activity,
  ArrowUpRight,
  Check,
  UserCheck,
  Clock,
  Sparkles
} from 'lucide-react';
import dashboardService from '../../services/dashboardService';
import defectService from '../../services/defectService';
import quarantineService from '../../services/quarantineService';
import { useAuth } from '../../context/useAuth';
import { parseErrorMessage } from '../../utils/errorHandler';
import EmptyState from '../../components/QA/EmptyState';

const displayValidationValue = (value) =>
  value === null || value === undefined || value === '' ? 'Unavailable' : String(value);

const defectStatCards = [
  {
    key: 'totalDefects',
    label: 'Total Defects',
    sublabel: 'Cumulative logged defects',
    accent: 'purple',
    icon: ClipboardList
  },
  {
    key: 'highSeverityDefects',
    label: 'High Severity',
    sublabel: 'Critical & high priority',
    accent: 'rose',
    icon: AlertTriangle
  },
  {
    key: 'openDefects',
    label: 'Open Defects',
    sublabel: 'Pending inspection / review',
    accent: 'violet',
    icon: AlertCircle
  }
];

const quarantineStatCards = [
  {
    key: 'quarantinedBatches',
    label: 'Quarantined Batches',
    sublabel: 'Active hold batches',
    accent: 'amber',
    icon: ShieldAlert
  },
  {
    key: 'affectedInventory',
    label: 'Affected Inventory',
    sublabel: 'Rolls in quarantine hold',
    accent: 'orange',
    icon: Package
  },
  {
    key: 'releasedInventory',
    label: 'Released Inventory',
    sublabel: 'Passed and cleared rolls',
    accent: 'cyan',
    icon: CheckCircle2
  }
];

export default function QualityDashboard() {
  const navigate = useNavigate();
  const [summary, setSummary] = useState({
    totalDefects: 0,
    highSeverityDefects: 0,
    openDefects: 0,
    quarantinedBatches: 0,
    affectedInventory: 0,
    releasedInventory: 0
  });
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [aiValidation, setAiValidation] = useState(null);
  const [aiValidationLoading, setAiValidationLoading] = useState(true);
  const [aiValidationError, setAiValidationError] = useState('');
  const [aiValidationHistory, setAiValidationHistory] = useState([]);
  const [historyLoading, setHistoryLoading] = useState(true);
  const [historyError, setHistoryError] = useState('');
  const [expandedReasons, setExpandedReasons] = useState({});
  const [expandedRows, setExpandedRows] = useState({});
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
      await Promise.all([loadSummary(), loadAiValidation(), loadAiValidationHistory()]);
    } catch (err) {
      setResolveError(parseErrorMessage(err, 'Failed to submit manual resolution.'));
    } finally {
      setResolving(false);
    }
  };

  const loadSummary = async () => {
    setLoading(true);
    setError('');
    try {
      const [summaryData, defects, quarantines] = await Promise.all([
        dashboardService.getQualitySummary(),
        defectService.getAll(),
        quarantineService.getAll()
      ]);
      const activeQuarantines = quarantines.filter((record) => record.status === 'Active');
      const releasedQuarantines = quarantines.filter((record) => record.status === 'Released');
      setSummary({
        ...summaryData,
        totalDefects: defects.length,
        highSeverityDefects: defects.filter((defect) => ['HIGH', 'Critical'].includes(defect.severity)).length,
        openDefects: defects.filter((defect) => defect.status === 'Open').length,
        quarantinedBatches: new Set(activeQuarantines.map((record) => record.batchId)).size,
        affectedInventory: new Set(activeQuarantines.map((record) => record.inventoryRollId)).size,
        releasedInventory: new Set(releasedQuarantines.map((record) => record.inventoryRollId)).size
      });
    } catch (err) {
      setError(parseErrorMessage(err, 'Unable to load quality dashboard summary.'));
    } finally {
      setLoading(false);
    }
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

  useEffect(() => {
    loadSummary();
    loadAiValidation();
    loadAiValidationHistory();
  }, []);

  const cardStyles = {
    emerald: 'border-emerald-500/30 bg-emerald-500/10 text-emerald-300 shadow-emerald-500/5',
    purple: 'border-purple-500/30 bg-purple-500/10 text-purple-300 shadow-purple-500/5',
    violet: 'border-violet-500/30 bg-violet-500/10 text-violet-300 shadow-violet-500/5',
    rose: 'border-rose-500/30 bg-rose-500/10 text-rose-300 shadow-rose-500/5',
    amber: 'border-amber-500/30 bg-amber-500/10 text-amber-300 shadow-amber-500/5',
    orange: 'border-orange-500/30 bg-orange-500/10 text-orange-300 shadow-orange-500/5',
    cyan: 'border-cyan-500/30 bg-cyan-500/10 text-cyan-300 shadow-cyan-500/5'
  };

  const quickActions = [
    {
      title: 'Review Defect Reports',
      desc: 'Filter, inspect, and evaluate quality incidents',
      path: '/quality/defects',
      icon: FileText
    },
    {
      title: 'Open Quarantine Queue',
      desc: 'Manage segregated batches and inventory holds',
      path: '/quality/quarantine',
      icon: ShieldAlert
    },
    {
      title: 'Log New Defect',
      desc: 'Submit inspection defect and initiate quarantine',
      path: '/quality/defects/new',
      icon: PlusCircle
    },
    {
      title: 'View Quarantine History',
      desc: 'Review disposition audits and released records',
      path: '/quality/quarantine/history',
      icon: History
    }
  ];

  return (
    <div className="p-6 lg:p-8 max-w-7xl mx-auto space-y-8">
      {/* Dashboard Page Header */}
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between border-b border-slate-800 pb-6">
        <div>
          <div className="flex items-center gap-2">
            <span className="text-purple-400 uppercase tracking-widest text-xs font-bold">
              Quality Assurance
            </span>
            <span className="text-slate-600">•</span>
            <span className="text-slate-400 text-xs font-medium">Control Center</span>
          </div>
          <h1 className="text-3xl font-extrabold text-white tracking-tight mt-1">
            Quality Control Dashboard
          </h1>
          <p className="text-sm text-slate-400 mt-1">
            Monitor quality defects, inventory holds and inspection activity.
          </p>
        </div>

        {/* Action Button Group */}
        <div className="flex flex-wrap items-center gap-3">
          <button
            onClick={() => navigate('/quality/defects')}
            className="px-4 py-2.5 rounded-xl border border-slate-700 bg-slate-900/60 text-slate-200 text-sm font-medium hover:bg-slate-800 hover:text-white transition-all shadow-sm"
          >
            View Defects
          </button>
          <button
            onClick={() => navigate('/quality/quarantine')}
            className="px-4 py-2.5 rounded-xl border border-purple-500/40 bg-purple-500/10 text-purple-300 text-sm font-medium hover:bg-purple-500/20 transition-all shadow-sm"
          >
            Manage Quarantine
          </button>
          <button
            onClick={() => navigate('/quality/defects/new')}
            className="px-5 py-2.5 rounded-xl bg-purple-600 text-white font-bold text-sm hover:bg-purple-500 transition-all shadow-lg shadow-purple-600/25 flex items-center gap-2"
          >
            <PlusCircle className="w-4 h-4 stroke-[2.5]" />
            <span>+ New Defect</span>
          </button>
        </div>
      </div>

      {/* Error Alert */}
      {error && (
        <div className="rounded-2xl border border-rose-500/30 bg-rose-500/10 p-4 text-rose-200 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <AlertTriangle className="w-5 h-5 text-rose-400 shrink-0" />
            <span className="text-sm font-medium">{error}</span>
          </div>
          <button
            onClick={loadSummary}
            className="text-xs font-semibold underline hover:text-rose-100 ml-4"
          >
            Retry
          </button>
        </div>
      )}

      {/* Loading State */}
      {loading ? (
        <div className="flex flex-col items-center justify-center py-24 text-slate-400 space-y-3">
          <Loader2 className="w-8 h-8 animate-spin text-emerald-400" />
          <Loader2 className="w-8 h-8 animate-spin text-purple-400" />
          <p className="text-sm font-medium">Aggregating quality telemetry & inventory records...</p>
        </div>
      ) : (
        <>
          {/* Row 1: Defect Metrics (3 Cards) */}
          <div>
            <div className="flex items-center justify-between mb-3 px-1">
              <h2 className="text-xs font-bold uppercase tracking-wider text-slate-400">
                Defect Metrics
              </h2>
              <span className="text-xs text-slate-400">{error ? 'Unavailable' : 'Live summary'}</span>
            </div>
            <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
              {defectStatCards.map((card) => {
                const Icon = card.icon;
                return (
                  <div
                    key={card.key}
                    className={`rounded-2xl border p-5 transition-all shadow-sm hover:border-slate-700 ${
                      cardStyles[card.accent]
                    }`}
                  >
                    <div className="flex items-start justify-between">
                      <div>
                        <span className="text-xs font-bold uppercase tracking-wider opacity-85">
                          {card.label}
                        </span>
                        <p className="text-xs text-slate-400 mt-0.5">{card.sublabel}</p>
                      </div>
                      <div className="p-2 rounded-xl bg-slate-900/60 border border-current/20">
                        <Icon className="w-5 h-5" />
                      </div>
                    </div>
                    <div className="mt-4 text-4xl font-extrabold tracking-tight">
                      {error ? 'Unavailable' : summary[card.key]}
                    </div>
                  </div>
                );
              })}
            </div>
          </div>

          {/* Row 2: Quarantine & Hold Metrics (3 Cards) */}
          <div>
            <div className="flex items-center justify-between mb-3 px-1">
              <h2 className="text-xs font-bold uppercase tracking-wider text-slate-400">
                Quarantine & Hold Metrics
              </h2>
              <span className="text-xs text-slate-400">{error ? 'Unavailable' : 'Active containment status'}</span>
            </div>
            <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
              {quarantineStatCards.map((card) => {
                const Icon = card.icon;
                return (
                  <div
                    key={card.key}
                    className={`rounded-2xl border p-5 transition-all shadow-sm hover:border-slate-700 ${
                      cardStyles[card.accent]
                    }`}
                  >
                    <div className="flex items-start justify-between">
                      <div>
                        <span className="text-xs font-bold uppercase tracking-wider opacity-85">
                          {card.label}
                        </span>
                        <p className="text-xs text-slate-400 mt-0.5">{card.sublabel}</p>
                      </div>
                      <div className="p-2 rounded-xl bg-slate-900/60 border border-current/20">
                        <Icon className="w-5 h-5" />
                      </div>
                    </div>
                    <div className="mt-4 text-4xl font-extrabold tracking-tight">
                      {error ? 'Unavailable' : summary[card.key]}
                    </div>
                  </div>
                );
              })}
            </div>
          </div>

          {/* Success Banner */}
          {resolveSuccess && (
            <div className="rounded-2xl border border-emerald-500/30 bg-emerald-500/10 p-4 text-emerald-200 flex items-center gap-3 animate-in fade-in">
              <CheckCircle2 className="w-5 h-5 text-emerald-400 shrink-0" />
              <span className="text-sm font-medium">{resolveSuccess}</span>
            </div>
          )}

          {/* AI Validation & Safety */}
          <section className="rounded-3xl border border-slate-800 bg-slate-900/60 p-6 backdrop-blur-sm space-y-5">
            <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between border-b border-slate-800/80 pb-4">
              <div>
                <h2 className="text-lg font-bold text-white tracking-tight">AI Validation &amp; Safety</h2>
                <p className="text-xs text-slate-400 mt-0.5">Latest Validation/Safety Agent assessment</p>
              </div>
              <Activity className="w-5 h-5 text-cyan-300" aria-hidden="true" />
            </div>

            {aiValidationLoading ? (
              <div className="flex items-center justify-center gap-3 py-8 text-slate-400" role="status" aria-live="polite">
                <Loader2 className="w-5 h-5 animate-spin text-cyan-300" />
                <span className="text-sm">Loading Validation/Safety assessment...</span>
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
              <div className="space-y-4">
                {/* Resolution Action Callout if Quarantine Required / Active & Unresolved */}
                {(aiValidation.qualitySafetyStatus === 'QUARANTINE_REQUIRED' || aiValidation.qualitySafetyStatus === 'QUARANTINE_ACTIVE') &&
                  aiValidation.manualResolutionStatus !== 'RESOLVED' && (
                    <div className="rounded-2xl border border-rose-500/40 bg-rose-950/30 p-4 flex flex-col sm:flex-row sm:items-center justify-between gap-4">
                      <div className="flex items-center gap-3">
                        <div className="p-2 rounded-xl bg-rose-500/20 text-rose-400 border border-rose-500/30 shrink-0">
                          <ShieldAlert className="w-6 h-6" />
                        </div>
                        <div>
                          <div className="flex items-center gap-2">
                            <span className="text-sm font-bold text-white">Manual QA Review &amp; Resolution Required</span>
                            <span className="px-2 py-0.5 rounded-full text-[10px] font-bold uppercase bg-rose-500/20 text-rose-300 border border-rose-500/40">
                              Quarantine Hold Active
                            </span>
                          </div>
                          <p className="text-xs text-rose-200/80 mt-0.5">
                            AI safety validation detected defect conditions requiring physical inspection or supervisor resolution before backend approval.
                          </p>
                        </div>
                      </div>
                      <button
                        onClick={() => openResolveModal(aiValidation)}
                        className="px-4 py-2.5 bg-gradient-to-r from-emerald-600 to-emerald-700 hover:from-emerald-500 text-white font-bold rounded-xl text-xs shadow-lg shadow-emerald-600/20 flex items-center justify-center gap-2 shrink-0 transition-all"
                      >
                        <ShieldCheck className="w-4 h-4" />
                        <span>Review &amp; Resolve / Release</span>
                      </button>
                    </div>
                  )}

                {/* Primary Assessment Grid */}
                <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
                  <div className="rounded-2xl border border-slate-800 bg-slate-950/60 p-4">
                    <p className="text-xs font-semibold uppercase tracking-wider text-slate-500">Workflow ID</p>
                    <p className="mt-2 text-sm font-mono font-semibold text-white break-all">
                      {displayValidationValue(aiValidation.workflowId)}
                    </p>
                  </div>
                  <div className="rounded-2xl border border-slate-800 bg-slate-950/60 p-4">
                    <p className="text-xs font-semibold uppercase tracking-wider text-slate-500">Workflow Status</p>
                    <p className="mt-2 text-sm font-semibold text-white break-words">
                      {displayValidationValue(aiValidation.status)}
                    </p>
                  </div>
                  <div className="rounded-2xl border border-cyan-500/30 bg-cyan-500/5 p-4">
                    <p className="text-xs font-semibold uppercase tracking-wider text-cyan-200">Quality Safety Status</p>
                    <p className="mt-2 text-sm font-bold text-cyan-100 break-words">
                      {displayValidationValue(aiValidation.qualitySafetyStatus)}
                    </p>
                  </div>
                  <div className="rounded-2xl border border-slate-800 bg-slate-950/60 p-4">
                    <p className="text-xs font-semibold uppercase tracking-wider text-slate-500">Quarantined Rolls</p>
                    <p className="mt-2 text-2xl font-bold text-white">
                      {displayValidationValue(aiValidation.quarantinedRollsCount)}
                    </p>
                  </div>
                  <div className="rounded-2xl border border-slate-800 bg-slate-950/60 p-4">
                    <p className="text-xs font-semibold uppercase tracking-wider text-slate-500">High Impact</p>
                    <span className={`mt-2 inline-flex items-center rounded-full border px-2.5 py-1 text-xs font-semibold ${
                      aiValidation.isHighImpact === true
                        ? 'border-amber-500/30 bg-amber-500/10 text-amber-200'
                        : 'border-slate-700 bg-slate-800/60 text-slate-200'
                    }`}>
                      {displayValidationValue(aiValidation.isHighImpact)}
                    </span>
                  </div>
                  <div className="rounded-2xl border border-slate-800 bg-slate-950/60 p-4 sm:col-span-2 lg:col-span-3">
                    <p className="text-xs font-semibold uppercase tracking-wider text-slate-500">Impact Reason</p>
                    <p className="mt-2 text-sm leading-6 text-slate-200 whitespace-pre-wrap break-words">
                      {displayValidationValue(aiValidation.impactReason)}
                    </p>
                  </div>
                </div>

                {/* Extended Validation Breakdown & Manual Resolution Audit */}
                <div className="rounded-2xl border border-slate-800/80 bg-slate-950/40 p-4 space-y-3">
                  <span className="text-xs font-bold uppercase tracking-wider text-slate-400 block">
                    Automated Validation Checks &amp; Manual Audit
                  </span>
                  <div className="grid grid-cols-2 sm:grid-cols-4 gap-2 text-xs">
                    <div className="p-2.5 rounded-xl bg-slate-900 border border-slate-800">
                      <span className="text-slate-500 block text-[10px] uppercase font-semibold">Supplier Check</span>
                      <span className={`font-bold mt-0.5 block ${
                        aiValidation.supplierValidation === 'ACTIVE_SUPPLIER' || aiValidation.supplierValidation === 'PASSED'
                          ? 'text-emerald-400'
                          : aiValidation.supplierValidation?.includes('INACTIVE')
                          ? 'text-rose-400'
                          : 'text-slate-300'
                      }`}>
                        {displayValidationValue(aiValidation.supplierValidation)}
                      </span>
                    </div>

                    <div className="p-2.5 rounded-xl bg-slate-900 border border-slate-800">
                      <span className="text-slate-500 block text-[10px] uppercase font-semibold">Budget Check</span>
                      <span className={`font-bold mt-0.5 block ${
                        aiValidation.budgetCheck === 'WITHIN_BUDGET' || aiValidation.budgetCheck === 'PASSED'
                          ? 'text-emerald-400'
                          : aiValidation.budgetCheck === 'BUDGET_OVERRUN'
                          ? 'text-rose-400'
                          : 'text-slate-300'
                      }`}>
                        {displayValidationValue(aiValidation.budgetCheck)}
                      </span>
                    </div>

                    <div className="p-2.5 rounded-xl bg-slate-900 border border-slate-800">
                      <span className="text-slate-500 block text-[10px] uppercase font-semibold">PO Math Check</span>
                      <span className={`font-bold mt-0.5 block ${
                        aiValidation.poMathematicalCheck === 'PASSED'
                          ? 'text-emerald-400'
                          : aiValidation.poMathematicalCheck === 'CALCULATION_MISMATCH'
                          ? 'text-rose-400'
                          : 'text-slate-300'
                      }`}>
                        {displayValidationValue(aiValidation.poMathematicalCheck)}
                      </span>
                    </div>

                    <div className="p-2.5 rounded-xl bg-slate-900 border border-slate-800">
                      <span className="text-slate-500 block text-[10px] uppercase font-semibold">Material Check</span>
                      <span className={`font-bold mt-0.5 block ${
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
                    <div className="p-3 rounded-xl bg-emerald-950/30 border border-emerald-500/30 text-xs space-y-1.5">
                      <div className="flex items-center justify-between">
                        <span className="font-bold text-emerald-300 flex items-center gap-1.5">
                          <CheckCircle2 className="w-4 h-4 text-emerald-400" />
                          <span>QualityInspector Manual Resolution: RESOLVED</span>
                        </span>
                        {aiValidation.resolvedAt && (
                          <span className="text-[10px] text-slate-400 font-mono">
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

          {/* Validation/Safety Assessment History */}
          <section className="rounded-3xl border border-slate-800 bg-slate-900/60 p-6 backdrop-blur-sm space-y-5">
            <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between border-b border-slate-800/80 pb-4">
              <div>
                <h2 className="text-lg font-bold text-white tracking-tight">Validation/Safety Assessment History</h2>
                <p className="text-xs text-slate-400 mt-0.5">Persisted audit trail of quality safety assessments</p>
              </div>
              <History className="w-5 h-5 text-purple-400" aria-hidden="true" />
            </div>

            {historyLoading ? (
              <div className="flex items-center justify-center gap-3 py-8 text-slate-400" role="status" aria-live="polite">
                <Loader2 className="w-5 h-5 animate-spin text-purple-400" />
                <span className="text-sm">Loading Validation/Safety assessment history...</span>
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
                {/* Desktop Table View (Hidden on mobile) */}
                <div className="hidden md:block overflow-x-auto rounded-2xl border border-slate-800 bg-slate-950/60">
                  <table className="w-full text-left border-collapse text-xs">
                    <thead>
                      <tr className="border-b border-slate-800 bg-slate-900/80 text-slate-400 font-semibold uppercase tracking-wider">
                        <th className="py-3 px-4">Workflow</th>
                        <th className="py-3 px-4">Status</th>
                        <th className="py-3 px-4">Safety</th>
                        <th className="py-3 px-4">Quarantined Rolls</th>
                        <th className="py-3 px-4">High Impact</th>
                        <th className="py-3 px-4">Impact Reason</th>
                        <th className="py-3 px-4 text-right">Audit &amp; Actions</th>
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
                                    : item.qualitySafetyStatus === 'QUARANTINE_REQUIRED'
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

                {/* Mobile Card View (Hidden on desktop) */}
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
                            <p className="text-xs font-semibold uppercase tracking-wider text-slate-500">Workflow</p>
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
                            <p className="text-slate-500 font-medium">Safety Status</p>
                            <p className={`font-bold mt-1 ${
                              item.qualitySafetyStatus === 'CLEAR'
                                ? 'text-emerald-400'
                                : item.qualitySafetyStatus === 'QUARANTINE_REQUIRED'
                                ? 'text-rose-400'
                                : 'text-cyan-300'
                            }`}>
                              {displayValidationValue(item.qualitySafetyStatus)}
                            </p>
                          </div>
                          <div className="rounded-xl bg-slate-900/60 p-2.5 border border-slate-800/60">
                            <p className="text-slate-500 font-medium">Quarantined Rolls</p>
                            <p className="font-bold text-white mt-1">{displayValidationValue(item.quarantinedRollsCount)}</p>
                          </div>
                          <div className="rounded-xl bg-slate-900/60 p-2.5 border border-slate-800/60 col-span-2 flex items-center justify-between">
                            <span className="text-slate-500 font-medium">High Impact</span>
                            <span className={`inline-flex items-center rounded-full border px-2 py-0.5 font-semibold text-xs ${
                              item.isHighImpact === true
                                ? 'border-amber-500/30 bg-amber-500/10 text-amber-200'
                                : item.isHighImpact === false
                                ? 'border-slate-700 bg-slate-800/60 text-slate-300'
                                : 'border-slate-800 text-slate-500'
                            }`}>
                              {item.isHighImpact === true ? 'Yes' : item.isHighImpact === false ? 'No' : displayValidationValue(item.isHighImpact)}
                            </span>
                          </div>
                        </div>

                        <div className="rounded-xl bg-slate-900/60 p-2.5 border border-slate-800/60 text-xs">
                          <p className="text-slate-500 font-medium mb-1">Impact Reason</p>
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
                              <div><span className="text-slate-500">Supplier:</span> <span className="font-semibold text-white">{displayValidationValue(item.supplierValidation)}</span></div>
                              <div><span className="text-slate-500">Budget:</span> <span className="font-semibold text-white">{displayValidationValue(item.budgetCheck)}</span></div>
                              <div><span className="text-slate-500">PO Math:</span> <span className="font-semibold text-white">{displayValidationValue(item.poMathematicalCheck)}</span></div>
                              <div><span className="text-slate-500">Material:</span> <span className="font-semibold text-white">{displayValidationValue(item.materialValidation)}</span></div>
                            </div>
                            {item.manualResolutionStatus && (
                              <div className="pt-1.5 border-t border-slate-800 text-[11px]">
                                <span className="text-slate-500">QA Resolution:</span> <span className="font-bold text-emerald-400">{item.manualResolutionStatus}</span>
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

          {/* Operational Overview & Quick Actions Grid */}
          <div className="grid gap-6 lg:grid-cols-12 items-start">
            {/* Operational Overview (7 Columns) */}
            <div className="lg:col-span-7 rounded-3xl border border-slate-800 bg-slate-900/60 p-6 backdrop-blur-sm space-y-6">
              <div className="flex items-center justify-between border-b border-slate-800/80 pb-4">
                <div>
                  <h2 className="text-lg font-bold text-white tracking-tight">
                    Operational Overview
                  </h2>
                  <p className="text-xs text-slate-400 mt-0.5">
                    Real-time quality threshold and containment diagnostics
                  </p>
                </div>
                <span className="inline-flex items-center gap-1.5 rounded-full border border-emerald-500/30 bg-emerald-500/10 px-3 py-1 text-xs font-medium text-emerald-300">
                  <span className="w-2 h-2 rounded-full bg-emerald-400 animate-pulse" />
                  System online
                </span>
              </div>

              <div className="space-y-4">
                {/* Defect Risk Card */}
                <div className="rounded-2xl border border-slate-800 bg-slate-950 p-5 hover:border-slate-700 transition-colors">
                  <div className="flex items-center justify-between mb-2">
                    <span className="text-xs font-bold uppercase tracking-wider text-slate-400">
                      Defect Risk
                    </span>
                    <span
                      className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-semibold ${
                        error
                          ? 'bg-slate-800/60 text-slate-300 border border-slate-700'
                          : summary.highSeverityDefects > 0
                          ? 'bg-rose-500/20 text-rose-300 border border-rose-500/30'
                          : 'bg-emerald-500/20 text-emerald-300 border border-emerald-500/30'
                      }`}
                    >
                      {error ? 'Unavailable' : `${summary.highSeverityDefects} high priority`}
                    </span>
                  </div>
                  <div className="flex items-baseline justify-between">
                    <div className="text-2xl font-bold text-white tracking-tight">
                      {error ? 'Unavailable' : summary.highSeverityDefects > 0 ? 'Attention Required' : 'Stable'}
                    </div>
                  </div>
                  <p className="text-xs text-slate-400 mt-2">
                    {error
                      ? 'Defect data could not be loaded; no assessment is available.'
                      : summary.highSeverityDefects > 0
                      ? 'High or critical defects detected requiring immediate containment.'
                      : 'Zero critical defects on the manufacturing floor. Production within safety bounds.'}
                  </p>
                </div>

                {/* Quality Flow Card */}
                <div className="rounded-2xl border border-slate-800 bg-slate-950 p-5 hover:border-slate-700 transition-colors">
                  <div className="flex items-center justify-between mb-2">
                    <span className="text-xs font-bold uppercase tracking-wider text-slate-400">
                      Quality Flow
                    </span>
                    <span
                      className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-semibold ${
                        error
                          ? 'bg-slate-800/60 text-slate-300 border border-slate-700'
                          : summary.quarantinedBatches > 0
                          ? 'bg-amber-500/20 text-amber-300 border border-amber-500/30'
                          : 'bg-emerald-500/20 text-emerald-300 border border-emerald-500/30'
                      }`}
                    >
                      {error ? 'Unavailable' : `${summary.affectedInventory} inventory affected`}
                    </span>
                  </div>
                  <div className="flex items-baseline justify-between">
                    <div className="text-2xl font-bold text-white tracking-tight">
                      {error
                        ? 'Unavailable'
                        : summary.quarantinedBatches === 0
                        ? 'No Active Holds'
                        : `${summary.quarantinedBatches} batch${summary.quarantinedBatches === 1 ? '' : 'es'} on hold`}
                    </div>
                  </div>
                  <p className="text-xs text-slate-400 mt-2">
                    {error
                      ? 'Quarantine data could not be loaded; containment state is unavailable.'
                      : summary.quarantinedBatches === 0
                      ? 'All batches are flowing without quarantine interruptions.'
                      : 'Quarantine protocol engaged. Segregated inventory pending supervisor disposition.'}
                  </p>
                </div>
              </div>
            </div>

            {/* Quick Actions (5 Columns) */}
            <div className="lg:col-span-5 rounded-3xl border border-slate-800 bg-slate-900/60 p-6 backdrop-blur-sm space-y-4">
              <div className="border-b border-slate-800/80 pb-4">
                <h2 className="text-lg font-bold text-white tracking-tight">
                  Quick Actions
                </h2>
                <p className="text-xs text-slate-400 mt-0.5">
                  Frequent inspector workflows and navigation
                </p>
              </div>

              <div className="space-y-3">
                {quickActions.map((action) => {
                  const Icon = action.icon;
                  return (
                    <button
                      key={action.path}
                      onClick={() => navigate(action.path)}
                      className="w-full rounded-2xl border border-slate-800 bg-slate-950 p-4 text-left hover:border-emerald-500/40 hover:bg-slate-900/80 transition-all group flex items-center justify-between"
                    >
                      <div className="flex items-center gap-3.5 min-w-0">
                        <div className="w-10 h-10 rounded-xl bg-slate-900 border border-slate-800 flex items-center justify-center text-slate-400 group-hover:text-emerald-400 group-hover:border-emerald-500/30 transition-colors shrink-0">
                          <Icon className="w-5 h-5" />
                        </div>
                        <div className="truncate">
                          <p className="text-sm font-bold text-white group-hover:text-emerald-300 transition-colors truncate">
                            {action.title}
                          </p>
                          <p className="text-xs text-slate-400 truncate mt-0.5">
                            {action.desc}
                          </p>
                        </div>
                      </div>
                      <ChevronRight className="w-4 h-4 text-slate-500 group-hover:text-emerald-400 group-hover:translate-x-0.5 transition-all shrink-0 ml-2" />
                    </button>
                  );
                })}
              </div>
            </div>
          </div>
        </>
      )}
      {/* QualityInspector Manual Resolution Modal */}
      {resolveModalOpen && selectedWorkflow && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/80 backdrop-blur-md animate-in fade-in">
          <div className="w-full max-w-lg rounded-3xl bg-slate-900 border border-slate-700 shadow-2xl p-6 space-y-5">
            <div className="flex items-start justify-between border-b border-slate-800 pb-4">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-xl bg-emerald-500/20 text-emerald-400 border border-emerald-500/30 flex items-center justify-center">
                  <ShieldCheck className="w-5 h-5" />
                </div>
                <div>
                  <h3 className="text-base font-bold text-white">Manual Quality Review &amp; Resolution</h3>
                  <p className="text-xs font-mono text-cyan-300 mt-0.5">{selectedWorkflow.workflowId}</p>
                </div>
              </div>
              <button
                onClick={() => setResolveModalOpen(false)}
                className="p-1 rounded-lg text-slate-400 hover:text-white bg-slate-800"
              >
                ✕
              </button>
            </div>

            <form onSubmit={handleResolveSubmit} className="space-y-4">
              <div className="p-3 rounded-xl bg-slate-950 border border-slate-800 text-xs space-y-1">
                <div className="flex justify-between text-slate-400">
                  <span>AI Finding:</span>
                  <span className="font-bold text-rose-400">{selectedWorkflow.qualitySafetyStatus}</span>
                </div>
                {selectedWorkflow.impactReason && (
                  <p className="text-slate-300 italic pt-1">{selectedWorkflow.impactReason}</p>
                )}
              </div>

              {resolveError && (
                <div className="p-3 rounded-xl bg-rose-500/10 border border-rose-500/30 text-rose-300 text-xs flex items-center gap-2">
                  <AlertCircle className="w-4 h-4 shrink-0 text-rose-400" />
                  <span>{resolveError}</span>
                </div>
              )}

              <div className="space-y-1.5">
                <label className="text-xs font-bold uppercase tracking-wider text-slate-300 block">
                  Manual Resolution &amp; Disposition Note <span className="text-rose-400">*</span>
                </label>
                <textarea
                  value={resolutionNote}
                  onChange={(e) => setResolutionNote(e.target.value)}
                  placeholder="e.g., Physical batch re-tested. Tensile strength meets ASTM standard specifications. Cleared for production use."
                  rows={4}
                  required
                  className="w-full rounded-xl bg-slate-950 border border-slate-700 p-3 text-xs text-white placeholder-slate-500 focus:border-emerald-500 focus:outline-none"
                />
              </div>

              <label className="flex items-center gap-3 p-3 rounded-xl bg-slate-950 border border-slate-800 cursor-pointer">
                <input
                  type="checkbox"
                  checked={releaseQuarantineCheck}
                  onChange={(e) => setReleaseQuarantineCheck(e.target.checked)}
                  className="w-4 h-4 rounded text-emerald-500 border-slate-700 bg-slate-900 focus:ring-emerald-500"
                />
                <div className="text-xs">
                  <span className="font-bold text-white block">Release Active Quarantine Holds</span>
                  <span className="text-slate-400">Return quarantined inventory rolls back to 'Available' in PostgreSQL</span>
                </div>
              </label>

              <div className="flex items-center justify-end gap-3 pt-2">
                <button
                  type="button"
                  onClick={() => setResolveModalOpen(false)}
                  className="px-4 py-2 rounded-xl border border-slate-700 text-slate-300 text-xs font-semibold hover:bg-slate-800"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={resolving}
                  className="px-5 py-2 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white text-xs font-bold transition-all shadow-lg shadow-emerald-600/25 flex items-center gap-2 disabled:opacity-50"
                >
                  {resolving ? (
                    <>
                      <Loader2 className="w-3.5 h-3.5 animate-spin" />
                      <span>Submitting Resolution...</span>
                    </>
                  ) : (
                    <>
                      <Check className="w-3.5 h-3.5" />
                      <span>Confirm Resolution &amp; Release</span>
                    </>
                  )}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}

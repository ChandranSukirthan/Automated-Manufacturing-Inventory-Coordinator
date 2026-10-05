import { formatColomboDate } from '../../utils/locale.js';
import React, { useEffect, useState, useMemo } from 'react';
import { Link } from 'react-router-dom';
import {
  AlertTriangle,
  AlertCircle,
  ClipboardList,
  ShieldAlert,
  ShieldCheck,
  Package,
  CheckCircle2,
  PlusCircle,
  History,
  ChevronRight,
  Loader2,
  Activity,
  ArrowUpRight,
  Clock,
  Sparkles,
  RefreshCw,
  Layers,
  ArrowRight,
  FileText
} from 'lucide-react';
import dashboardService from '../../services/dashboardService';
import defectService from '../../services/defectService';
import quarantineService from '../../services/quarantineService';
import { parseErrorMessage } from '../../utils/errorHandler';
import StatusBadge from '../../components/QA/StatusBadge';
import SeverityBadge from '../../components/QA/SeverityBadge';

export default function QualityDashboard() {
  const [summary, setSummary] = useState({
    totalDefects: 0,
    highSeverityDefects: 0,
    openDefects: 0,
    quarantinedBatches: 0,
    affectedInventory: 0,
    releasedInventory: 0
  });
  const [defects, setDefects] = useState([]);
  const [quarantines, setQuarantines] = useState([]);
  const [aiValidation, setAiValidation] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [refreshing, setRefreshing] = useState(false);

  const loadAllTelemetry = async () => {
    try {
      const [summaryData, defectData, quarantineData, aiData] = await Promise.all([
        dashboardService.getQualitySummary().catch(() => ({
          totalDefects: 0,
          highSeverityDefects: 0,
          openDefects: 0,
          quarantinedBatches: 0,
          affectedInventory: 0,
          releasedInventory: 0
        })),
        defectService.getAll().catch(() => []),
        quarantineService.getAll().catch(() => []),
        dashboardService.getAiValidation().catch(() => null)
      ]);

      setSummary(summaryData || {});
      setDefects(Array.isArray(defectData) ? defectData : []);
      setQuarantines(Array.isArray(quarantineData) ? quarantineData : []);
      setAiValidation(aiData || null);
    } catch (err) {
      setError(parseErrorMessage(err, 'Unable to aggregate quality telemetry.'));
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  };

  useEffect(() => {
    const initialLoad = setTimeout(loadAllTelemetry, 0);
    return () => clearTimeout(initialLoad);
  }, []);

  const handleRefresh = () => {
    setRefreshing(true);
    loadAllTelemetry();
  };

  // Real data calculations
  const totalDefectsCount = defects.length || summary.totalDefects || 0;
  const criticalDefects = defects.filter((d) => String(d.severity).toLowerCase() === 'critical');
  const highDefects = defects.filter((d) => String(d.severity).toLowerCase() === 'high');
  const mediumDefects = defects.filter((d) => String(d.severity).toLowerCase() === 'medium');
  const lowDefects = defects.filter((d) => String(d.severity).toLowerCase() === 'low');

  const openDefectsList = defects.filter((d) => ['open', 'inreview'].includes(String(d.status).toLowerCase()));
  const resolvedDefects = defects.filter((d) => ['resolved', 'closed'].includes(String(d.status).toLowerCase()));

  const activeQuarantines = quarantines.filter((q) => String(q.status).toLowerCase() === 'active');
  const releasedQuarantines = quarantines.filter((q) => String(q.status).toLowerCase() === 'released');

  // Severity Distribution Data
  const severityDistribution = [
    { label: 'Critical', count: criticalDefects.length, color: 'bg-rose-500', text: 'text-rose-400', bar: 'bg-rose-500' },
    { label: 'High', count: highDefects.length, color: 'bg-orange-500', text: 'text-orange-400', bar: 'bg-orange-500' },
    { label: 'Medium', count: mediumDefects.length, color: 'bg-amber-500', text: 'text-amber-400', bar: 'bg-amber-500' },
    { label: 'Low', count: lowDefects.length, color: 'bg-slate-500', text: 'text-slate-400', bar: 'bg-slate-500' }
  ];

  // Defect Pipeline Status
  const statusPipeline = [
    { label: 'Open', count: defects.filter((d) => String(d.status).toLowerCase() === 'open').length, color: 'bg-blue-500', text: 'text-blue-400' },
    { label: 'In Review', count: defects.filter((d) => String(d.status).toLowerCase() === 'inreview').length, color: 'bg-amber-500', text: 'text-amber-400' },
    { label: 'Resolved', count: defects.filter((d) => String(d.status).toLowerCase() === 'resolved').length, color: 'bg-emerald-500', text: 'text-emerald-400' },
    { label: 'Closed', count: defects.filter((d) => String(d.status).toLowerCase() === 'closed').length, color: 'bg-slate-600', text: 'text-slate-400' }
  ];

  // Priority Attention Items
  const attentionItems = useMemo(() => {
    const items = [];

    // 1. Active Quarantines
    activeQuarantines.forEach((q) => {
      items.push({
        id: `q-${q.id}`,
        type: 'QUARANTINE HOLD',
        title: `Quarantine #${q.id.substring(0, 8)}`,
        subtitle: `Roll: ${q.inventoryRollId}`,
        description: q.reason || 'Inventory under active quarantine restriction.',
        severity: 'critical',
        path: `/quality/quarantine/${q.id}`,
        timestamp: q.createdAt
      });
    });

    // 2. Critical & High Unresolved Defects
    openDefectsList
      .filter((d) => ['critical', 'high'].includes(String(d.severity).toLowerCase()))
      .forEach((d) => {
        items.push({
          id: `d-${d.id}`,
          type: 'DEFECT ALERT',
          title: `Defect #${d.id.substring(0, 8)} (${d.severity})`,
          subtitle: `SKU: ${d.skuCode || 'N/A'} · Status: ${d.status}`,
          description: d.description || 'High-severity defect pending inspection.',
          severity: String(d.severity).toLowerCase(),
          path: `/quality/defects/${d.id}`,
          timestamp: d.createdAt
        });
      });

    // 3. AI Validation Blockers
    if (
      aiValidation &&
      (aiValidation.qualitySafetyStatus === 'QUARANTINE_REQUIRED' ||
        aiValidation.qualitySafetyStatus === 'QUARANTINE_ACTIVE') &&
      aiValidation.manualResolutionStatus !== 'RESOLVED'
    ) {
      items.push({
        id: `wf-${aiValidation.workflowId}`,
        type: 'AI SAFETY BLOCK',
        title: `Validation Hold: ${aiValidation.workflowId}`,
        subtitle: `PO: ${aiValidation.purchaseOrderNumber || 'PO-2026-X'} · Quarantined: ${aiValidation.quarantinedRollsCount || 0} rolls`,
        description: aiValidation.impactReason || 'Validation Agent detected active quality defects.',
        severity: 'critical',
        path: '/quality/ai-validation',
        timestamp: aiValidation.assessmentTimestamp
      });
    }

    return items.sort((a, b) => new Date(b.timestamp || 0) - new Date(a.timestamp || 0)).slice(0, 5);
  }, [activeQuarantines, openDefectsList, aiValidation]);

  // Combined Recent QA Activity
  const recentActivities = useMemo(() => {
    const list = [];

    defects.slice(0, 4).forEach((d) => {
      list.push({
        id: `act-d-${d.id}`,
        type: 'Defect Logged',
        ref: `DEF-${d.id.substring(0, 6)}`,
        detail: d.description || `Defect on SKU ${d.skuCode}`,
        status: d.status,
        timestamp: d.createdAt,
        path: `/quality/defects/${d.id}`
      });
    });

    quarantines.slice(0, 4).forEach((q) => {
      list.push({
        id: `act-q-${q.id}`,
        type: q.status === 'Released' ? 'Quarantine Released' : 'Quarantine Placed',
        ref: `QR-${q.id.substring(0, 6)}`,
        detail: `Roll ${q.inventoryRollId}`,
        status: q.status,
        timestamp: q.createdAt,
        path: `/quality/quarantine/${q.id}`
      });
    });

    return list.sort((a, b) => new Date(b.timestamp || 0) - new Date(a.timestamp || 0)).slice(0, 6);
  }, [defects, quarantines]);

  if (loading) {
    return (
      <div className="flex flex-col items-center justify-center min-h-[60vh] text-slate-400 space-y-3">
        <Loader2 className="w-8 h-8 animate-spin text-blue-400" />
        <p className="text-sm font-medium">Aggregating manufacturing QA telemetry...</p>
      </div>
    );
  }

  return (
    <div className="p-6 lg:p-8 max-w-7xl mx-auto space-y-8">
      {/* 1. Header Banner */}
      <div className="relative overflow-hidden rounded-3xl bg-gradient-to-r from-blue-900/40 via-cyan-900/20 to-slate-900/60 border border-blue-500/20 p-6 lg:p-8 backdrop-blur-xl shadow-2xl">
        <div className="relative z-10 flex flex-col md:flex-row md:items-center md:justify-between gap-6">
          <div className="space-y-2 max-w-2xl">
            <div className="flex items-center gap-2 flex-wrap">
              <span className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-blue-500/20 border border-blue-500/40 text-blue-300 text-xs font-bold tracking-wide uppercase">
                <ShieldCheck className="w-3.5 h-3.5 text-blue-300" />
                Quality Assurance · Student 3
              </span>
              <span className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-emerald-500/15 border border-emerald-500/30 text-emerald-300 text-xs font-medium">
                <span className="w-2 h-2 rounded-full bg-emerald-400 animate-pulse" />
                System Status: Operational
              </span>
            </div>
            <h1 className="text-2xl sm:text-3xl lg:text-4xl font-black text-white tracking-tight">
              Quality Control
            </h1>
            <p className="text-sm sm:text-base text-slate-300 leading-relaxed">
              Manufacturing quality, safety, defect and quarantine monitoring console. Real-time factory floor telemetry, AI compliance checks, and containment management.
            </p>
          </div>

          {/* Header Actions */}
          <div className="flex flex-wrap items-center gap-3">
            <button
              onClick={handleRefresh}
              disabled={refreshing}
              className="px-4 py-2.5 rounded-xl border border-slate-700 bg-slate-900/80 text-slate-200 text-sm font-medium hover:bg-slate-800 hover:text-white transition-all shadow-sm flex items-center gap-2 disabled:opacity-50"
            >
              <RefreshCw className={`w-4 h-4 ${refreshing ? 'animate-spin text-blue-400' : ''}`} />
              <span>Refresh Telemetry</span>
            </button>
            <Link
              to="/quality/defects/new"
              className="px-4 py-2.5 rounded-xl bg-gradient-to-r from-blue-600 to-blue-700 hover:from-blue-500 hover:to-blue-600 text-white text-sm font-bold shadow-lg shadow-blue-600/25 flex items-center gap-2 transition-all"
            >
              <PlusCircle className="w-4 h-4" />
              <span>Log Defect</span>
            </Link>
          </div>
        </div>
      </div>

      {error && (
        <div className="p-4 rounded-2xl bg-rose-500/10 border border-rose-500/30 text-rose-300 text-sm flex items-center gap-3">
          <AlertTriangle className="w-5 h-5 shrink-0 text-rose-400" />
          <span>{error}</span>
        </div>
      )}

      {/* 2. Top Level KPI Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 sm:gap-5">
        {/* Open Defects */}
        <div className="p-5 rounded-2xl bg-slate-900/60 border border-slate-800 backdrop-blur-sm relative overflow-hidden group hover:border-blue-500/40 transition-all">
          <div className="flex items-center justify-between">
            <span className="text-xs font-bold text-slate-400 uppercase tracking-wider">Open Defects</span>
            <div className="w-9 h-9 rounded-xl bg-blue-500/15 border border-blue-500/30 flex items-center justify-center text-blue-400">
              <ClipboardList className="w-4 h-4" />
            </div>
          </div>
          <p className="text-3xl font-extrabold text-white mt-3 tracking-tight">{openDefectsList.length}</p>
          <div className="flex items-center justify-between mt-2 pt-2 border-t border-slate-800/80 text-xs">
            <span className="text-slate-400">{totalDefectsCount} total logged</span>
            {criticalDefects.length > 0 && (
              <span className="text-rose-400 font-semibold">{criticalDefects.length} Critical</span>
            )}
          </div>
        </div>

        {/* Active Quarantines */}
        <div className="p-5 rounded-2xl bg-slate-900/60 border border-slate-800 backdrop-blur-sm relative overflow-hidden group hover:border-rose-500/40 transition-all">
          <div className="flex items-center justify-between">
            <span className="text-xs font-bold text-slate-400 uppercase tracking-wider">Active Quarantines</span>
            <div className="w-9 h-9 rounded-xl bg-rose-500/15 border border-rose-500/30 flex items-center justify-center text-rose-400">
              <ShieldAlert className="w-4 h-4" />
            </div>
          </div>
          <p className="text-3xl font-extrabold text-rose-400 mt-3 tracking-tight">{activeQuarantines.length}</p>
          <div className="flex items-center justify-between mt-2 pt-2 border-t border-slate-800/80 text-xs">
            <span className="text-slate-400">{summary.quarantinedRolls || summary.quarantinedBatches || activeQuarantines.length || 0} items held</span>
            <span className="text-emerald-400 font-semibold">{releasedQuarantines.length} released</span>
          </div>
        </div>

        {/* Affected Inventory */}
        <div className="p-5 rounded-2xl bg-slate-900/60 border border-slate-800 backdrop-blur-sm relative overflow-hidden group hover:border-amber-500/40 transition-all">
          <div className="flex items-center justify-between">
            <span className="text-xs font-bold text-slate-400 uppercase tracking-wider">Restricted Rolls</span>
            <div className="w-9 h-9 rounded-xl bg-amber-500/15 border border-amber-500/30 flex items-center justify-center text-amber-400">
              <Package className="w-4 h-4" />
            </div>
          </div>
          <p className="text-3xl font-extrabold text-amber-300 mt-3 tracking-tight">
            {summary.affectedInventory || activeQuarantines.length}
          </p>
          <div className="flex items-center justify-between mt-2 pt-2 border-t border-slate-800/80 text-xs">
            <span className="text-slate-400">Fabric rolls on hold</span>
            <span className="text-cyan-400 font-semibold">{summary.releasedInventory || 0} cleared</span>
          </div>
        </div>

        {/* AI Safety Assessment */}
        <div className="p-5 rounded-2xl bg-slate-900/60 border border-slate-800 backdrop-blur-sm relative overflow-hidden group hover:border-cyan-500/40 transition-all">
          <div className="flex items-center justify-between">
            <span className="text-xs font-bold text-slate-400 uppercase tracking-wider">AI Safety Status</span>
            <div className="w-9 h-9 rounded-xl bg-cyan-500/15 border border-cyan-500/30 flex items-center justify-center text-cyan-300">
              <Sparkles className="w-4 h-4" />
            </div>
          </div>
          <div className="mt-3 flex items-center gap-2">
            <span
              className={`text-lg font-black tracking-tight ${
                aiValidation?.qualitySafetyStatus === 'CLEAR'
                  ? 'text-emerald-400'
                  : aiValidation
                  ? 'text-rose-400'
                  : 'text-slate-400'
              }`}
            >
              {aiValidation?.qualitySafetyStatus || 'ACTIVE'}
            </span>
          </div>
          <div className="flex items-center justify-between mt-2 pt-2 border-t border-slate-800/80 text-xs">
            <span className="text-slate-400 truncate max-w-[120px]">
              {aiValidation?.workflowId || 'Real-time agent'}
            </span>
            <Link to="/quality/ai-validation" className="text-blue-400 hover:text-blue-300 font-semibold flex items-center gap-0.5">
              <span>Inspect</span>
              <ChevronRight className="w-3.5 h-3.5" />
            </Link>
          </div>
        </div>
      </div>

      {/* 3. Monitoring & Real Data Visuals Grid */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Severity Distribution Chart */}
        <div className="p-6 rounded-3xl bg-slate-900/60 border border-slate-800 backdrop-blur-sm space-y-4 shadow-sm">
          <div className="flex items-center justify-between border-b border-slate-800/80 pb-3">
            <div className="flex items-center gap-2">
              <AlertTriangle className="w-4 h-4 text-blue-400" />
              <h2 className="text-sm font-bold text-white uppercase tracking-wider">Defect Severity Breakdown</h2>
            </div>
            <span className="text-xs text-slate-400 font-mono">{totalDefectsCount} Total</span>
          </div>

          <div className="space-y-3.5 pt-1">
            {severityDistribution.map((item) => {
              const pct = totalDefectsCount > 0 ? Math.round((item.count / totalDefectsCount) * 100) : 0;
              return (
                <div key={item.label} className="space-y-1.5">
                  <div className="flex justify-between text-xs">
                    <span className="text-slate-300 font-medium">{item.label} Severity</span>
                    <span className={`font-bold font-mono ${item.text}`}>
                      {item.count} ({pct}%)
                    </span>
                  </div>
                  <div className="w-full bg-slate-950 rounded-full h-2 overflow-hidden border border-slate-800">
                    <div
                      className={`h-full rounded-full ${item.bar} transition-all duration-500`}
                      style={{ width: `${Math.max(pct, item.count > 0 ? 5 : 0)}%` }}
                    />
                  </div>
                </div>
              );
            })}
          </div>

          <div className="pt-3 border-t border-slate-800/80 flex items-center justify-between text-xs text-slate-400">
            <span>Critical & High: {criticalDefects.length + highDefects.length}</span>
            <Link to="/quality/defects" className="text-blue-400 hover:text-blue-300 font-semibold flex items-center gap-1">
              <span>View Defect Matrix</span>
              <ArrowRight className="w-3 h-3" />
            </Link>
          </div>
        </div>

        {/* Quarantine Status & Containment Ratio */}
        <div className="p-6 rounded-3xl bg-slate-900/60 border border-slate-800 backdrop-blur-sm space-y-4 shadow-sm">
          <div className="flex items-center justify-between border-b border-slate-800/80 pb-3">
            <div className="flex items-center gap-2">
              <ShieldAlert className="w-4 h-4 text-rose-400" />
              <h2 className="text-sm font-bold text-white uppercase tracking-wider">Quarantine Containment</h2>
            </div>
            <span className="text-xs text-slate-400 font-mono">{quarantines.length} Events</span>
          </div>

          <div className="pt-2 space-y-4">
            <div className="grid grid-cols-2 gap-3">
              <div className="p-3.5 rounded-2xl bg-rose-500/10 border border-rose-500/20 text-center">
                <span className="text-[11px] font-bold uppercase tracking-wider text-rose-400">Active Restriction</span>
                <p className="text-2xl font-black text-rose-300 mt-1">{activeQuarantines.length}</p>
                <span className="text-[10px] text-slate-400 mt-0.5 block">Held from production</span>
              </div>
              <div className="p-3.5 rounded-2xl bg-emerald-500/10 border border-emerald-500/20 text-center">
                <span className="text-[11px] font-bold uppercase tracking-wider text-emerald-400">Released / Cleared</span>
                <p className="text-2xl font-black text-emerald-300 mt-1">{releasedQuarantines.length}</p>
                <span className="text-[10px] text-slate-400 mt-0.5 block">Returned to stock</span>
              </div>
            </div>

            {/* Visual Containment Bar */}
            <div className="space-y-1.5">
              <div className="flex justify-between text-xs">
                <span className="text-slate-400">Containment Clearance Rate</span>
                <span className="text-emerald-400 font-bold font-mono">
                  {quarantines.length > 0
                    ? Math.round((releasedQuarantines.length / quarantines.length) * 100)
                    : 100}
                  %
                </span>
              </div>
              <div className="w-full bg-slate-950 rounded-full h-2.5 overflow-hidden border border-slate-800 flex">
                <div
                  className="bg-emerald-500 h-full transition-all"
                  style={{
                    width: `${
                      quarantines.length > 0
                        ? (releasedQuarantines.length / quarantines.length) * 100
                        : 100
                    }%`
                  }}
                />
                <div
                  className="bg-rose-500 h-full transition-all"
                  style={{
                    width: `${
                      quarantines.length > 0
                        ? (activeQuarantines.length / quarantines.length) * 100
                        : 0
                    }%`
                  }}
                />
              </div>
            </div>
          </div>

          <div className="pt-3 border-t border-slate-800/80 flex items-center justify-between text-xs text-slate-400">
            <span>Active Holds: {activeQuarantines.length}</span>
            <Link to="/quality/quarantine" className="text-blue-400 hover:text-blue-300 font-semibold flex items-center gap-1">
              <span>Manage Holds</span>
              <ArrowRight className="w-3 h-3" />
            </Link>
          </div>
        </div>

        {/* Defect Lifecycle Pipeline */}
        <div className="p-6 rounded-3xl bg-slate-900/60 border border-slate-800 backdrop-blur-sm space-y-4 shadow-sm">
          <div className="flex items-center justify-between border-b border-slate-800/80 pb-3">
            <div className="flex items-center gap-2">
              <Activity className="w-4 h-4 text-cyan-400" />
              <h2 className="text-sm font-bold text-white uppercase tracking-wider">Defect Resolution Pipeline</h2>
            </div>
            <span className="text-xs text-slate-400 font-mono">{defects.length} Total</span>
          </div>

          <div className="space-y-3 pt-1">
            {statusPipeline.map((stage) => {
              const pct = defects.length > 0 ? Math.round((stage.count / defects.length) * 100) : 0;
              return (
                <div key={stage.label} className="flex items-center justify-between p-2.5 rounded-xl bg-slate-950/40 border border-slate-800">
                  <div className="flex items-center gap-2.5">
                    <span className={`w-2 h-2 rounded-full ${stage.color}`} />
                    <span className="text-xs font-semibold text-slate-200">{stage.label}</span>
                  </div>
                  <div className="flex items-center gap-3">
                    <span className="text-xs text-slate-400">{pct}%</span>
                    <span className={`text-xs font-bold font-mono px-2 py-0.5 rounded-md bg-slate-900 border border-slate-800 ${stage.text}`}>
                      {stage.count}
                    </span>
                  </div>
                </div>
              );
            })}
          </div>

          <div className="pt-3 border-t border-slate-800/80 flex items-center justify-between text-xs text-slate-400">
            <span>Resolved / Closed: {resolvedDefects.length}</span>
            <Link to="/quality/defects" className="text-blue-400 hover:text-blue-300 font-semibold flex items-center gap-1">
              <span>Inspect Queue</span>
              <ArrowRight className="w-3 h-3" />
            </Link>
          </div>
        </div>
      </div>

      {/* 4. Priority / Requires Attention Panel & Recent Activity */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Requires Attention Section (2 Columns) */}
        <div className="lg:col-span-2 p-6 rounded-3xl bg-slate-900/60 border border-slate-800 backdrop-blur-sm space-y-4 shadow-sm">
          <div className="flex items-center justify-between border-b border-slate-800/80 pb-3">
            <div className="flex items-center gap-2">
              <div className="w-2.5 h-2.5 rounded-full bg-rose-500 animate-pulse" />
              <h2 className="text-base font-bold text-white tracking-tight">Requires Attention</h2>
            </div>
            <span className="text-xs text-rose-300 font-semibold uppercase tracking-wider px-2.5 py-0.5 rounded-full bg-rose-500/10 border border-rose-500/30">
              {attentionItems.length} Urgent Items
            </span>
          </div>

          {attentionItems.length === 0 ? (
            <div className="py-12 px-4 rounded-2xl bg-slate-950/40 border border-slate-800 text-center space-y-2">
              <div className="w-12 h-12 rounded-2xl bg-emerald-500/10 border border-emerald-500/30 flex items-center justify-center text-emerald-400 mx-auto">
                <CheckCircle2 className="w-6 h-6" />
              </div>
              <h3 className="text-sm font-bold text-white">All Systems Nominal</h3>
              <p className="text-xs text-slate-400 max-w-sm mx-auto">
                No active quarantine holds, critical defect alerts, or unresolved AI safety blocks currently require review.
              </p>
            </div>
          ) : (
            <div className="space-y-3">
              {attentionItems.map((item) => (
                <div
                  key={item.id}
                  className="p-4 rounded-2xl bg-slate-950/60 border border-slate-800 hover:border-blue-500/50 transition-all flex flex-col sm:flex-row sm:items-center justify-between gap-3 group"
                >
                  <div className="space-y-1 min-w-0">
                    <div className="flex items-center gap-2 flex-wrap">
                      <span className="text-[10px] font-extrabold uppercase px-2 py-0.5 rounded-full bg-rose-500/15 text-rose-300 border border-rose-500/30 tracking-wider">
                        {item.type}
                      </span>
                      <h4 className="text-sm font-bold text-white truncate">{item.title}</h4>
                    </div>
                    <p className="text-xs text-slate-400 font-mono">{item.subtitle}</p>
                    <p className="text-xs text-slate-300 line-clamp-1">{item.description}</p>
                  </div>
                  <Link
                    to={item.path}
                    className="px-3.5 py-2 rounded-xl bg-blue-600/20 hover:bg-blue-600 text-blue-300 hover:text-white border border-blue-500/30 text-xs font-bold transition-all shrink-0 flex items-center justify-center gap-1.5 shadow-sm"
                  >
                    <span>Inspect</span>
                    <ArrowRight className="w-3.5 h-3.5" />
                  </Link>
                </div>
              ))}
            </div>
          )}
        </div>

        {/* Recent QA Activity Stream */}
        <div className="p-6 rounded-3xl bg-slate-900/60 border border-slate-800 backdrop-blur-sm space-y-4 shadow-sm">
          <div className="flex items-center justify-between border-b border-slate-800/80 pb-3">
            <div className="flex items-center gap-2">
              <History className="w-4 h-4 text-blue-400" />
              <h2 className="text-base font-bold text-white tracking-tight">Recent QA Activity</h2>
            </div>
            <span className="text-xs text-slate-400">Live Stream</span>
          </div>

          <div className="space-y-3">
            {recentActivities.length === 0 ? (
              <p className="text-xs text-slate-400 text-center py-8">No recent QA events logged.</p>
            ) : (
              recentActivities.map((act) => (
                <Link
                  key={act.id}
                  to={act.path}
                  className="block p-3 rounded-2xl bg-slate-950/40 border border-slate-800/80 hover:border-slate-700 transition-colors"
                >
                  <div className="flex items-center justify-between text-[11px] mb-1">
                    <span className="font-bold text-blue-400">{act.type}</span>
                    <span className="text-slate-400">
                      {act.timestamp ? formatColomboDate(act.timestamp, 'toLocaleTimeString') : 'Recent'}
                    </span>
                  </div>
                  <p className="text-xs text-slate-200 font-medium truncate">{act.detail}</p>
                  <div className="flex items-center justify-between mt-2 pt-1 border-t border-slate-900 text-[10px]">
                    <span className="font-mono text-slate-400">{act.ref}</span>
                    <StatusBadge status={act.status} />
                  </div>
                </Link>
              ))
            )}
          </div>
        </div>
      </div>

      {/* 5. Navigation Shortcuts Bar */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 pt-2">
        <Link
          to="/quality/ai-validation"
          className="p-4 rounded-2xl bg-slate-900/40 border border-slate-800 hover:border-blue-500/40 hover:bg-slate-900/80 transition-all flex items-center justify-between group"
        >
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-blue-500/10 border border-blue-500/20 flex items-center justify-center text-blue-400 group-hover:scale-105 transition-transform">
              <Sparkles className="w-5 h-5" />
            </div>
            <div>
              <p className="text-xs font-bold text-white">AI Validation &amp; Safety</p>
              <p className="text-[11px] text-slate-400">Assessments &amp; Safety Gates</p>
            </div>
          </div>
          <ChevronRight className="w-4 h-4 text-slate-400 group-hover:text-white transition-colors" />
        </Link>

        <Link
          to="/quality/defects"
          className="p-4 rounded-2xl bg-slate-900/40 border border-slate-800 hover:border-blue-500/40 hover:bg-slate-900/80 transition-all flex items-center justify-between group"
        >
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-blue-500/10 border border-blue-500/20 flex items-center justify-center text-blue-400 group-hover:scale-105 transition-transform">
              <ClipboardList className="w-5 h-5" />
            </div>
            <div>
              <p className="text-xs font-bold text-white">Defect Reports</p>
              <p className="text-[11px] text-slate-400">Inspection &amp; Logging</p>
            </div>
          </div>
          <ChevronRight className="w-4 h-4 text-slate-400 group-hover:text-white transition-colors" />
        </Link>

        <Link
          to="/quality/quarantine"
          className="p-4 rounded-2xl bg-slate-900/40 border border-slate-800 hover:border-rose-500/40 hover:bg-slate-900/80 transition-all flex items-center justify-between group"
        >
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-rose-500/10 border border-rose-500/20 flex items-center justify-center text-rose-400 group-hover:scale-105 transition-transform">
              <ShieldAlert className="w-5 h-5" />
            </div>
            <div>
              <p className="text-xs font-bold text-white">Quarantine Control</p>
              <p className="text-[11px] text-slate-400">Active Holds &amp; Releases</p>
            </div>
          </div>
          <ChevronRight className="w-4 h-4 text-slate-400 group-hover:text-white transition-colors" />
        </Link>

        <Link
          to="/quality/quarantine/history"
          className="p-4 rounded-2xl bg-slate-900/40 border border-slate-800 hover:border-cyan-500/40 hover:bg-slate-900/80 transition-all flex items-center justify-between group"
        >
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-cyan-500/10 border border-cyan-500/20 flex items-center justify-center text-cyan-400 group-hover:scale-105 transition-transform">
              <History className="w-5 h-5" />
            </div>
            <div>
              <p className="text-xs font-bold text-white">Quarantine History</p>
              <p className="text-[11px] text-slate-400">Audit Ledger &amp; Dispositions</p>
            </div>
          </div>
          <ChevronRight className="w-4 h-4 text-slate-400 group-hover:text-white transition-colors" />
        </Link>

        <Link
          to="/quality/quarantine"
          className="p-4 rounded-2xl bg-slate-900/40 border border-slate-800 hover:border-rose-500/40 hover:bg-slate-900/80 transition-all flex items-center justify-between group"
        >
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-rose-500/10 border border-rose-500/20 flex items-center justify-center text-rose-400 group-hover:scale-105 transition-transform">
              <ShieldAlert className="w-5 h-5" />
            </div>
            <div>
              <p className="text-xs font-bold text-white">Quarantine Control</p>
              <p className="text-[11px] text-slate-400">Active Holds &amp; Releases</p>
            </div>
          </div>
          <ChevronRight className="w-4 h-4 text-slate-400 group-hover:text-white transition-colors" />
        </Link>

        <Link
          to="/quality/quarantine/history"
          className="p-4 rounded-2xl bg-slate-900/40 border border-slate-800 hover:border-cyan-500/40 hover:bg-slate-900/80 transition-all flex items-center justify-between group"
        >
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-cyan-500/10 border border-cyan-500/20 flex items-center justify-center text-cyan-400 group-hover:scale-105 transition-transform">
              <History className="w-5 h-5" />
            </div>
            <div>
              <p className="text-xs font-bold text-white">Quarantine History</p>
              <p className="text-[11px] text-slate-400">Audit Ledger &amp; Dispositions</p>
            </div>
          </div>
          <ChevronRight className="w-4 h-4 text-slate-400 group-hover:text-white transition-colors" />
        </Link>
      </div>
    </div>
  );
}

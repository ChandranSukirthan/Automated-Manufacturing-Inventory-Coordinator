import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import {
  AlertTriangle,
  AlertCircle,
  ClipboardList,
  ShieldAlert,
  Package,
  CheckCircle2,
  PlusCircle,
  FileText,
  History,
  ChevronRight,
  Loader2,
  Activity,
  ArrowUpRight
} from 'lucide-react';
import dashboardService from '../../services/dashboardService';
import defectService from '../../services/defectService';
import quarantineService from '../../services/quarantineService';
import { parseErrorMessage } from '../../utils/errorHandler';

const defectStatCards = [
  {
    key: 'totalDefects',
    label: 'Total Defects',
    sublabel: 'Cumulative logged defects',
    accent: 'emerald',
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

  useEffect(() => {
    loadSummary();
  }, []);

  const cardStyles = {
    emerald: 'border-emerald-500/30 bg-emerald-500/10 text-emerald-300 shadow-emerald-500/5',
    purple: 'border-purple-500/30 bg-purple-500/10 text-purple-300 shadow-purple-500/5',
    violet: 'border-violet-500/30 bg-violet-500/10 text-violet-300 shadow-violet-500/5',
    rose: 'border-rose-500/30 bg-rose-500/10 text-rose-300 shadow-rose-500/5',
    violet: 'border-violet-500/30 bg-violet-500/10 text-violet-300 shadow-violet-500/5',
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
            className="px-4 py-2.5 rounded-xl border border-emerald-500/40 bg-emerald-500/10 text-emerald-300 text-sm font-medium hover:bg-emerald-500/20 transition-all shadow-sm"
            className="px-4 py-2.5 rounded-xl border border-purple-500/40 bg-purple-500/10 text-purple-300 text-sm font-medium hover:bg-purple-500/20 transition-all shadow-sm"
          >
            Manage Quarantine
          </button>
          <button
            onClick={() => navigate('/quality/defects/new')}
            className="px-5 py-2.5 rounded-xl bg-emerald-500 text-slate-950 font-bold text-sm hover:bg-emerald-400 transition-all shadow-lg shadow-emerald-500/20 flex items-center gap-2"
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
              <span className="text-xs text-slate-400">Live summary</span>
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
                      {summary[card.key]}
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
              <span className="text-xs text-slate-400">Active containment status</span>
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
                      {summary[card.key]}
                    </div>
                  </div>
                );
              })}
            </div>
          </div>

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
                        summary.highSeverityDefects > 0
                          ? 'bg-rose-500/20 text-rose-300 border border-rose-500/30'
                          : 'bg-emerald-500/20 text-emerald-300 border border-emerald-500/30'
                      }`}
                    >
                      {summary.highSeverityDefects} high priority
                    </span>
                  </div>
                  <div className="flex items-baseline justify-between">
                    <div className="text-2xl font-bold text-white tracking-tight">
                      {summary.highSeverityDefects > 0 ? 'Attention Required' : 'Stable'}
                    </div>
                  </div>
                  <p className="text-xs text-slate-400 mt-2">
                    {summary.highSeverityDefects > 0
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
                        summary.quarantinedBatches > 0
                          ? 'bg-amber-500/20 text-amber-300 border border-amber-500/30'
                          : 'bg-emerald-500/20 text-emerald-300 border border-emerald-500/30'
                      }`}
                    >
                      {summary.affectedInventory} inventory affected
                    </span>
                  </div>
                  <div className="flex items-baseline justify-between">
                    <div className="text-2xl font-bold text-white tracking-tight">
                      {summary.quarantinedBatches === 0
                        ? 'No Active Holds'
                        : `${summary.quarantinedBatches} batch${summary.quarantinedBatches === 1 ? '' : 'es'} on hold`}
                    </div>
                  </div>
                  <p className="text-xs text-slate-400 mt-2">
                    {summary.quarantinedBatches === 0
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
    </div>
  );
}

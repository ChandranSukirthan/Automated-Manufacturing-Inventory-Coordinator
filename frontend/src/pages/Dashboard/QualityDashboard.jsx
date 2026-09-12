
import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import dashboardService from '../../services/dashboardService';
import defectService from '../../services/defectService';
import quarantineService from '../../services/quarantineService';
import { parseErrorMessage } from '../../utils/errorHandler';
import QANavigation from '../../components/Dashboard/QANavigation';

const statCards = [
  { key: 'totalDefects', label: 'Total Defects', accent: 'emerald' },
  { key: 'highSeverityDefects', label: 'High Severity', accent: 'rose' },
  { key: 'openDefects', label: 'Open Defects', accent: 'violet' },
  { key: 'quarantinedBatches', label: 'Quarantined Batches', accent: 'amber' },
  { key: 'affectedInventory', label: 'Affected Inventory', accent: 'orange' },
  { key: 'releasedInventory', label: 'Released Inventory', accent: 'cyan' }
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

  useEffect(() => {
    const loadSummary = async () => {
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
          highSeverityDefects: defects.filter((defect) => ['HIGH', 'CRITICAL'].includes(defect.severity)).length,
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

    loadSummary();
  }, []);

  const cardStyles = {
    emerald: 'border-emerald-500/30 bg-emerald-500/10 text-emerald-300',
    rose: 'border-rose-500/30 bg-rose-500/10 text-rose-300',
    violet: 'border-violet-500/30 bg-violet-500/10 text-violet-300',
    amber: 'border-amber-500/30 bg-amber-500/10 text-amber-300',
    orange: 'border-orange-500/30 bg-orange-500/10 text-orange-300',
    cyan: 'border-cyan-500/30 bg-cyan-500/10 text-cyan-300'
  };

  return (
    <div className="min-h-screen bg-slate-950 text-slate-100 p-8">
      <div className="max-w-6xl mx-auto">
        <QANavigation />

        <div className="flex flex-col gap-4 md:flex-row md:items-end md:justify-between mb-8">
          <div>
            <p className="text-emerald-400 uppercase tracking-wide text-sm font-semibold">Quality Assurance</p>
            <h1 className="text-4xl font-bold mt-2">Quality Control Dashboard</h1>
          </div>
          <div className="flex flex-wrap gap-3">
            <button onClick={() => navigate('/quality/defects')} className="px-4 py-2 rounded-xl border border-slate-700 text-slate-200 hover:bg-slate-800">View Defects</button>
            <button onClick={() => navigate('/quality/quarantine')} className="px-4 py-2 rounded-xl border border-emerald-500 text-emerald-300 hover:bg-emerald-500/10">Manage Quarantine</button>
            <button onClick={() => navigate('/quality/defects/new')} className="px-4 py-2 rounded-xl bg-emerald-500 text-slate-950 font-bold hover:bg-emerald-400">+ New Defect</button>
          </div>
        </div>

        {error ? (
          <div className="mb-6 rounded-xl border border-red-500/30 bg-red-500/10 p-4 text-red-200">{error}</div>
        ) : null}

        {loading ? (
          <div className="text-slate-400">Loading quality summary...</div>
        ) : (
          <>
            <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-3 mb-8">
              {statCards.map((card) => (
                <div key={card.key} className={`rounded-2xl border p-5 ${cardStyles[card.accent]}`}>
                  <div className="text-sm uppercase tracking-[0.15em] opacity-80">{card.label}</div>
                  <div className="mt-4 text-4xl font-bold">{summary[card.key]}</div>
                </div>
              ))}
            </div>

            <div className="grid gap-6 lg:grid-cols-[1.2fr_0.8fr]">
              <div className="rounded-3xl border border-slate-800 bg-slate-900/60 p-6">
                <div className="flex items-center justify-between mb-4">
                  <h2 className="text-xl font-semibold">Operational Overview</h2>
                  <span className="rounded-full border border-emerald-500/30 bg-emerald-500/10 px-2 py-1 text-xs text-emerald-300">System online</span>
                </div>

                <div className="space-y-4">
                  <div className="rounded-2xl border border-slate-800 bg-slate-950 p-4">
                    <div className="text-sm text-slate-400">Defect Risk</div>
                    <div className="mt-2 flex items-center justify-between">
                      <span className="text-2xl font-bold text-white">{summary.highSeverityDefects > 0 ? 'Attention required' : 'Stable'}</span>
                      <span className="text-sm text-rose-300">{summary.highSeverityDefects} high priority</span>
                    </div>
                  </div>

                  <div className="rounded-2xl border border-slate-800 bg-slate-950 p-4">
                    <div className="text-sm text-slate-400">Quality Flow</div>
                    <div className="mt-2 flex items-center justify-between">
                      <span className="text-2xl font-bold text-white">{summary.quarantinedBatches === 0 ? 'No active holds' : `${summary.quarantinedBatches} batches on hold`}</span>
                      <span className="text-sm text-amber-300">{summary.affectedInventory} inventory affected</span>
                    </div>
                  </div>
                </div>
              </div>

              <div className="rounded-3xl border border-slate-800 bg-slate-900/60 p-6">
                <h2 className="text-xl font-semibold mb-4">Quick Actions</h2>
                <div className="space-y-3">
                  <button onClick={() => navigate('/quality/defects')} className="w-full rounded-xl border border-slate-700 bg-slate-950 px-4 py-3 text-left hover:bg-slate-800">Review defect reports</button>
                  <button onClick={() => navigate('/quality/quarantine')} className="w-full rounded-xl border border-slate-700 bg-slate-950 px-4 py-3 text-left hover:bg-slate-800">Open quarantine queue</button>
                  <button onClick={() => navigate('/quality/defects/new')} className="w-full rounded-xl border border-slate-700 bg-slate-950 px-4 py-3 text-left hover:bg-slate-800">Log a new defect</button>
                  <button onClick={() => navigate('/quality/quarantine/history')} className="w-full rounded-xl border border-slate-700 bg-slate-950 px-4 py-3 text-left hover:bg-slate-800">View quarantine history</button>
                </div>
              </div>
            </div>
          </>
        )}
      </div>
    </div>
  );
}

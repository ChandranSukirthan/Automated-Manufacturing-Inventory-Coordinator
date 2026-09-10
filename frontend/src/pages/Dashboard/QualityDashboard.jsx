import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import dashboardService from '../../services/dashboardService';
import QANavigation from '../../components/Dashboard/QANavigation';
import { parseErrorMessage } from '../../utils/errorHandler';

export default function QualityDashboard() {
  const navigate = useNavigate();
  const [summary, setSummary] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    dashboardService.getQualitySummary()
      .then(setSummary)
      .catch((err) => setError(parseErrorMessage(err, 'Unable to load QA dashboard data.')))
      .finally(() => setLoading(false));
  }, []);

  return (
    <div className="min-h-screen bg-slate-950 text-white p-8">
      <div className="max-w-5xl mx-auto">
        <QANavigation />
        <div className="flex items-center justify-between">
          <div>
            <p className="text-emerald-400 uppercase tracking-wide text-sm font-semibold">Quality Assurance</p>
            <h1 className="text-4xl font-bold text-emerald-500 mt-2">Quality Control Dashboard</h1>
          </div>
        </div>

        {error && <div className="mt-6 p-3 rounded bg-red-500/10 text-red-300 border border-red-500/30">{error}</div>}
        <div className="grid sm:grid-cols-2 lg:grid-cols-4 gap-4 mt-8">
          {[
            ['Total Defects', summary?.totalDefects],
            ['High Severity', summary?.highSeverityDefects],
            ['Active Quarantines', summary?.activeQuarantines],
            ['Released Quarantines', summary?.releasedQuarantines]
          ].map(([label, value]) => (
            <div key={label} className="p-6 rounded-2xl border border-slate-800 bg-slate-900">
              <div className="text-slate-400 text-sm">{label}</div>
              <div className="text-4xl font-bold mt-2">{loading ? '...' : value ?? 0}</div>
            </div>
          ))}
        </div>

        <div className="grid md:grid-cols-3 gap-4 mt-8">
          <button onClick={() => navigate('/dashboard/quarantine')} className="p-6 rounded-3xl border border-amber-800 bg-slate-900 text-left">
            <div className="text-amber-300 text-sm font-bold">Inventory Control</div>
            <div className="text-2xl font-semibold mt-2">Quarantine Management</div>
          </button>
          <button onClick={() => navigate('/dashboard/defects/new')} className="p-6 rounded-3xl border border-slate-800 bg-slate-900 text-left">
            <div className="text-emerald-400 text-sm font-bold">Create</div>
            <div className="text-2xl font-semibold mt-2">New Defect</div>
          </button>
        </div>
      </div>
    </div>
  );
}

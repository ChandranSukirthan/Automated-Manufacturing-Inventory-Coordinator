import { useNavigate } from 'react-router-dom';

export default function QualityDashboard() {
  const navigate = useNavigate();

  return (
    <div className="min-h-screen bg-slate-950 text-white p-8">
      <div className="max-w-5xl mx-auto">
        <div className="flex items-center justify-between">
          <div>
            <p className="text-emerald-400 uppercase tracking-wide text-sm font-semibold">Quality Assurance</p>
            <h1 className="text-4xl font-bold text-emerald-500 mt-2">Quality Control Dashboard</h1>
          </div>
          <button onClick={() => navigate('/dashboard/defects')} className="px-5 py-3 rounded-xl bg-emerald-500 text-slate-950 font-bold hover:bg-emerald-400">
            Defect Reports
          </button>
        </div>

        <div className="grid md:grid-cols-3 gap-4 mt-8">
          <button onClick={() => navigate('/dashboard/defects')} className="p-6 rounded-3xl border border-slate-800 bg-slate-900 text-left">
            <div className="text-emerald-400 text-sm font-bold">QA Defect Operations</div>
            <div className="text-2xl font-semibold mt-2">View Reports</div>
          </button>
          <button onClick={() => navigate('/dashboard/defects/new')} className="p-6 rounded-3xl border border-slate-800 bg-slate-900 text-left">
            <div className="text-emerald-400 text-sm font-bold">Create</div>
            <div className="text-2xl font-semibold mt-2">New Defect</div>
          </button>
          <button onClick={() => navigate('/dashboard/defects')} className="p-6 rounded-3xl border border-slate-800 bg-slate-900 text-left">
            <div className="text-emerald-400 text-sm font-bold">Review</div>
            <div className="text-2xl font-semibold mt-2">QA Queue</div>
          </button>
        </div>
      </div>
    </div>
  );
}

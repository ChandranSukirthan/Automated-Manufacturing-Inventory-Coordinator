import { useEffect, useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import defectService from '../../services/defectService';
import { parseErrorMessage } from '../../utils/errorHandler';
import QANavigation from '../../components/Dashboard/QANavigation';

export default function DefectReportsPage() {
  const navigate = useNavigate();
  const [defects, setDefects] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const loadDefects = async () => {
    setLoading(true);
    try {
      const data = await defectService.getAll();
      setDefects(data);
    } catch (err) {
      setError(parseErrorMessage(err, 'Unable to load defect reports.'));
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadDefects();
  }, []);

  const handleDelete = async (id) => {
    if (!window.confirm('Delete this defect report?')) return;

    try {
      await defectService.delete(id);
      setDefects(defects.filter((d) => d.id !== id));
    } catch (err) {
      setError(parseErrorMessage(err, 'Unable to delete defect report.'));
    }
  };

  return (
    <div className="min-h-screen bg-slate-950 text-slate-100 p-8">
      <div className="max-w-6xl mx-auto">
        <QANavigation />
        <div className="flex items-center justify-between mb-8">
          <div>
            <p className="text-emerald-400 uppercase tracking-wide text-sm font-semibold">Quality Assurance</p>
            <h1 className="text-4xl font-bold mt-2">Defect Reports</h1>
          </div>
          <div className="flex gap-3">
            <button onClick={() => navigate('/dashboard/quality')} className="px-4 py-2 rounded-xl border border-slate-700 text-slate-200 hover:bg-slate-800">QA Dashboard</button>
            <button onClick={() => navigate('/dashboard/defects/new')} className="px-4 py-2 rounded-xl bg-emerald-500 text-slate-950 font-bold hover:bg-emerald-400">+ Create Defect</button>
          </div>
        </div>

        {error && <div className="mb-4 p-3 rounded bg-red-500/10 text-red-300 border border-red-500/30">{error}</div>}

        {loading ? (
          <div className="text-slate-400">Loading defects...</div>
        ) : (
          <div className="overflow-x-auto rounded-2xl border border-slate-800">
            <table className="min-w-full divide-y divide-slate-800">
              <thead className="bg-slate-900">
                <tr>
                  <th className="px-6 py-3 text-left text-xs font-semibold uppercase tracking-wider">Batch ID</th>
                  <th className="px-6 py-3 text-left text-xs font-semibold uppercase tracking-wider">Product Type</th>
                  <th className="px-6 py-3 text-left text-xs font-semibold uppercase tracking-wider">Severity</th>
                  <th className="px-6 py-3 text-left text-xs font-semibold uppercase tracking-wider">Status</th>
                  <th className="px-6 py-3 text-left text-xs font-semibold uppercase tracking-wider">Created</th>
                  <th className="px-6 py-3 text-left text-xs font-semibold uppercase tracking-wider">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-800">
                {defects.length === 0 ? (
                  <tr>
                    <td className="px-6 py-8 text-slate-400" colSpan="6">No defect reports found.</td>
                  </tr>
                ) : (
                  defects.map((defect) => (
                    <tr key={defect.id} className="hover:bg-slate-900/60">
                      <td className="px-6 py-4 font-medium text-white">{defect.batchId}</td>
                      <td className="px-6 py-4 text-slate-300">{defect.productType}</td>
                      <td className="px-6 py-4">
                        <span className="px-3 py-1 rounded-full text-xs font-bold border border-slate-600 text-slate-200">{defect.severity}</span>
                      </td>
                      <td className="px-6 py-4 text-slate-300">{defect.status}</td>
                      <td className="px-6 py-4 text-slate-400">{new Date(defect.createdAt).toLocaleString()}</td>
                      <td className="px-6 py-4">
                        <div className="flex gap-2">
                          <button onClick={() => navigate(`/dashboard/defects/${defect.id}`)} className="px-3 py-1 rounded-lg border border-slate-600 text-slate-300 hover:bg-slate-800">View</button>
                          <button onClick={() => navigate(`/dashboard/defects/${defect.id}/edit`)} className="px-3 py-1 rounded-lg border border-cyan-500 text-cyan-300 hover:bg-cyan-500/10">Edit</button>
                          <button onClick={() => handleDelete(defect.id)} className="px-3 py-1 rounded-lg border border-rose-500 text-rose-300 hover:bg-rose-500/10">Delete</button>
                        </div>
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}

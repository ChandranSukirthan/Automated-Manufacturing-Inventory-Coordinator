import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import quarantineService from '../../services/quarantineService';
import { parseErrorMessage } from '../../utils/errorHandler';

export default function QuarantineManagementPage() {
  const navigate = useNavigate();
  const [records, setRecords] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    quarantineService.getAll()
      .then(setRecords)
      .catch((err) => setError(parseErrorMessage(err, 'Unable to load quarantine records.')))
      .finally(() => setLoading(false));
  }, []);

  return (
    <div className="min-h-screen bg-slate-950 text-slate-100 p-8">
      <div className="max-w-6xl mx-auto">
        <div className="flex flex-wrap items-center justify-between gap-4 mb-8">
          <div>
            <p className="text-emerald-400 uppercase tracking-wide text-sm font-semibold">Quality Assurance</p>
            <h1 className="text-4xl font-bold mt-2">Quarantine Management</h1>
          </div>
          <div className="flex gap-3">
            <button onClick={() => navigate('/dashboard/quality')} className="px-4 py-2 rounded-xl border border-slate-700 hover:bg-slate-800">QA Dashboard</button>
            <button onClick={() => navigate('/dashboard/quarantine/history')} className="px-4 py-2 rounded-xl border border-cyan-500 text-cyan-300 hover:bg-cyan-500/10">History</button>
          </div>
        </div>

        {error && <div className="mb-4 p-3 rounded bg-red-500/10 text-red-300 border border-red-500/30">{error}</div>}
        {loading ? <div className="text-slate-400">Loading quarantine records...</div> : (
          <div className="overflow-x-auto rounded-2xl border border-slate-800">
            <table className="min-w-full divide-y divide-slate-800">
              <thead className="bg-slate-900"><tr>
                <th className="px-6 py-3 text-left text-xs uppercase">Inventory</th>
                <th className="px-6 py-3 text-left text-xs uppercase">Batch</th>
                <th className="px-6 py-3 text-left text-xs uppercase">Reason</th>
                <th className="px-6 py-3 text-left text-xs uppercase">Status</th>
                <th className="px-6 py-3 text-left text-xs uppercase">Created</th>
                <th className="px-6 py-3 text-left text-xs uppercase">Actions</th>
              </tr></thead>
              <tbody className="divide-y divide-slate-800">
                {records.length === 0 ? <tr><td colSpan="6" className="px-6 py-8 text-slate-400">No quarantine records found.</td></tr> : records.map((record) => (
                  <tr key={record.id} className="hover:bg-slate-900/60">
                    <td className="px-6 py-4 font-medium">{record.inventoryRollId}</td>
                    <td className="px-6 py-4 text-slate-300">{record.batchId}</td>
                    <td className="px-6 py-4 text-slate-300">{record.reason}</td>
                    <td className="px-6 py-4"><span className={record.status === 'Active' ? 'text-amber-300' : 'text-emerald-300'}>{record.status}</span></td>
                    <td className="px-6 py-4 text-slate-400">{new Date(record.createdAt).toLocaleString()}</td>
                    <td className="px-6 py-4"><button onClick={() => navigate(`/dashboard/quarantine/${record.id}`)} className="px-3 py-1 rounded-lg border border-slate-600 hover:bg-slate-800">View</button></td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}

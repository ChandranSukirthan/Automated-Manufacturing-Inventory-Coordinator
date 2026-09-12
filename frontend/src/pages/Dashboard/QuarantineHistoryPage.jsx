import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import quarantineService from '../../services/quarantineService';
import { parseErrorMessage } from '../../utils/errorHandler';
import QANavigation from '../../components/Dashboard/QANavigation';

export default function QuarantineHistoryPage() {
  const navigate = useNavigate();
  const [records, setRecords] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    const load = async () => {
      try {
        const data = await quarantineService.getAll();
        setRecords(data.filter((record) => record.status === 'Released'));
      } catch (err) {
        setError(parseErrorMessage(err, 'Unable to load quarantine history.'));
      } finally {
        setLoading(false);
      }
    };

    load();
  }, []);

  return (
    <div className="min-h-screen bg-slate-950 text-slate-100 p-8">
      <div className="max-w-6xl mx-auto">
        <QANavigation />

        <div className="flex flex-wrap items-center justify-between gap-4 mb-8">
          <div>
            <p className="text-emerald-400 uppercase tracking-wide text-sm font-semibold">Quality Assurance</p>
            <h1 className="text-4xl font-bold mt-2">Quarantine History</h1>
          </div>
          <button onClick={() => navigate('/quality/quarantine')} className="px-4 py-2 rounded-xl border border-slate-700 hover:bg-slate-800">
            Back to Quarantine
          </button>
        </div>

        {error && <div className="mb-4 p-3 rounded bg-red-500/10 text-red-300 border border-red-500/30">{error}</div>}

        {loading ? (
          <div className="text-slate-400">Loading quarantine history...</div>
        ) : (
          <div className="overflow-x-auto rounded-2xl border border-slate-800">
            <table className="min-w-full divide-y divide-slate-800">
              <thead className="bg-slate-900">
                <tr>
                  <th className="px-6 py-3 text-left text-xs uppercase">Inventory</th>
                  <th className="px-6 py-3 text-left text-xs uppercase">Batch</th>
                  <th className="px-6 py-3 text-left text-xs uppercase">Status</th>
                  <th className="px-6 py-3 text-left text-xs uppercase">Released</th>
                  <th className="px-6 py-3 text-left text-xs uppercase">Reason</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-800">
                {records.length === 0 ? (
                  <tr>
                    <td colSpan="5" className="px-6 py-8 text-slate-400">No released quarantine history found.</td>
                  </tr>
                ) : (
                  records.map((record) => (
                    <tr key={record.id} className="hover:bg-slate-900/60">
                      <td className="px-6 py-4 font-medium">{record.inventoryRollId}</td>
                      <td className="px-6 py-4 text-slate-300">{record.batchId}</td>
                      <td className="px-6 py-4 text-emerald-300">{record.status}</td>
                      <td className="px-6 py-4 text-slate-400">{record.releasedAt ? new Date(record.releasedAt).toLocaleString() : '—'}</td>
                      <td className="px-6 py-4 text-slate-300">{record.reason}</td>
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

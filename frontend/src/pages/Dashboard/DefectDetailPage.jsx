import { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import defectService from '../../services/defectService';
import { parseErrorMessage } from '../../utils/errorHandler';
import QANavigation from '../../components/Dashboard/QANavigation';

export default function DefectDetailPage() {
  const navigate = useNavigate();
  const { id } = useParams();
  const [defect, setDefect] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [inventoryRollId, setInventoryRollId] = useState('');
  const [reason, setReason] = useState('');
  const [quarantining, setQuarantining] = useState(false);

  useEffect(() => {
    const load = async () => {
      setLoading(true);
      try {
        const data = await defectService.getById(id);
        setDefect(data);
      } catch (err) {
        setError(parseErrorMessage(err, 'Unable to load defect.'));
      } finally {
        setLoading(false);
      }
    };

    load();
  }, [id]);

  if (loading) return <div className="min-h-screen bg-slate-950 text-slate-100 p-8">Loading defect...</div>;
  if (error) return <div className="min-h-screen bg-slate-950 text-slate-100 p-8">{error}</div>;
  if (!defect) return <div className="min-h-screen bg-slate-950 text-slate-100 p-8">Defect not found.</div>;

  const handleQuarantine = async (event) => {
    event.preventDefault();
    if (!reason.trim()) {
      setError('A quarantine reason is required.');
      return;
    }

    setQuarantining(true);
    try {
      const quarantine = await defectService.quarantine(defect.id, { inventoryRollId, reason });
      navigate(`/dashboard/quarantine/${quarantine.id}`);
    } catch (err) {
      setError(parseErrorMessage(err, 'Unable to quarantine inventory.'));
    } finally {
      setQuarantining(false);
    }
  };

  return (
    <div className="min-h-screen bg-slate-950 text-slate-100 p-8">
      <div className="max-w-4xl mx-auto">
        <QANavigation />
        <div className="flex justify-between items-center mb-6">
          <div>
            <p className="text-emerald-400 uppercase tracking-wide text-sm font-semibold">Quality Assurance</p>
            <h1 className="text-4xl font-bold mt-2">Defect Detail</h1>
          </div>
          <div className="flex gap-2">
            <button onClick={() => navigate('/dashboard/defects')} className="px-4 py-2 rounded-xl border border-slate-700 text-slate-200 hover:bg-slate-800">All Defects</button>
            <button onClick={() => navigate(`/dashboard/defects/${defect.id}/edit`)} className="px-4 py-2 rounded-xl border border-cyan-500 text-cyan-300 hover:bg-cyan-500/10">Edit</button>
          </div>

          <form onSubmit={handleQuarantine} className="border-t border-slate-800 pt-6 space-y-4">
            <div>
              <div className="text-slate-400 text-sm">Quarantine inventory</div>
              <p className="text-slate-500 text-sm mt-1">Leave the inventory ID blank to use this defect's batch ID.</p>
            </div>
            <input value={inventoryRollId} onChange={(event) => setInventoryRollId(event.target.value)} placeholder="Inventory roll ID (optional)" className="w-full rounded-xl bg-slate-950 border border-slate-700 px-4 py-3 text-white outline-none focus:border-amber-500" />
            <textarea value={reason} onChange={(event) => setReason(event.target.value)} placeholder="Reason for quarantine" rows="3" className="w-full rounded-xl bg-slate-950 border border-slate-700 px-4 py-3 text-white outline-none focus:border-amber-500" />
            <button type="submit" disabled={quarantining} className="px-5 py-3 rounded-xl bg-amber-400 text-slate-950 font-bold disabled:opacity-60">{quarantining ? 'Quarantining...' : 'Quarantine Inventory'}</button>
          </form>
        </div>

        <div className="bg-slate-900/60 rounded-3xl border border-slate-800 p-8 space-y-6">
          <div className="grid md:grid-cols-2 gap-6">
            <div>
              <div className="text-slate-400 text-sm">Batch ID</div>
              <div className="text-2xl font-semibold text-white">{defect.batchId}</div>
            </div>
            <div>
              <div className="text-slate-400 text-sm">Product Type</div>
              <div className="text-2xl font-semibold text-white">{defect.productType}</div>
            </div>
            <div>
              <div className="text-slate-400 text-sm">Severity</div>
              <div className="text-2xl font-semibold text-white">{defect.severity}</div>
            </div>
            <div>
              <div className="text-slate-400 text-sm">Status</div>
              <div className="text-2xl font-semibold text-white">{defect.status}</div>
            </div>
          </div>

          <div>
            <div className="text-slate-400 text-sm">Description</div>
            <div className="mt-2 p-4 rounded-xl bg-slate-950 border border-slate-700 text-slate-300 whitespace-pre-wrap">{defect.description}</div>
          </div>

          <div>
            <div className="text-slate-400 text-sm">Created At</div>
            <div className="text-slate-300">{new Date(defect.createdAt).toLocaleString()}</div>
          </div>
        </div>
      </div>
    </div>
  );
}

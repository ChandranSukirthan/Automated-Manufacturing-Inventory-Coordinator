import { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import quarantineService from '../../services/quarantineService';
import { parseErrorMessage } from '../../utils/errorHandler';
import QANavigation from '../../components/Dashboard/QANavigation';

export default function QuarantineDetailPage() {
  const navigate = useNavigate();
  const { id } = useParams();
  const [record, setRecord] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [releasing, setReleasing] = useState(false);

  const load = async () => {
    try {
      setRecord(await quarantineService.getById(id));
    } catch (err) {
      setError(parseErrorMessage(err, 'Unable to load quarantine record.'));
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { load(); }, [id]);

  const release = async () => {
    if (!window.confirm('Release this quarantine and return the inventory to normal business handling?')) return;
    setReleasing(true);
    try {
      setRecord(await quarantineService.release(id));
    } catch (err) {
      setError(parseErrorMessage(err, 'Unable to release quarantine.'));
    } finally {
      setReleasing(false);
    }
  };

  if (loading) return <div className="min-h-screen bg-slate-950 text-slate-100 p-8">Loading quarantine...</div>;
  if (error || !record) return <div className="min-h-screen bg-slate-950 text-slate-100 p-8">{error || 'Quarantine not found.'}</div>;

  return (
    <div className="min-h-screen bg-slate-950 text-slate-100 p-8">
      <div className="max-w-4xl mx-auto">
        <QANavigation />
        <div className="flex justify-between items-center mb-8">
          <div><p className="text-emerald-400 uppercase tracking-wide text-sm font-semibold">Quality Assurance</p><h1 className="text-4xl font-bold mt-2">Quarantine Details</h1></div>
          <button onClick={() => navigate('/dashboard/quarantine')} className="px-4 py-2 rounded-xl border border-slate-700 hover:bg-slate-800">Back to Management</button>
        </div>
        <div className="bg-slate-900/60 rounded-3xl border border-slate-800 p-8 space-y-6">
          <div className="grid md:grid-cols-2 gap-6">
            <div><div className="text-slate-400 text-sm">Defect</div><div className="font-semibold">{record.defectReportId}</div></div>
            <div><div className="text-slate-400 text-sm">Batch</div><div className="font-semibold">{record.batchId}</div></div>
            <div><div className="text-slate-400 text-sm">Inventory</div><div className="font-semibold">{record.inventoryRollId}</div></div>
            <div><div className="text-slate-400 text-sm">Status</div><div className={record.status === 'Active' ? 'text-amber-300 font-semibold' : 'text-emerald-300 font-semibold'}>{record.status}</div></div>
            <div><div className="text-slate-400 text-sm">Created</div><div>{new Date(record.createdAt).toLocaleString()}</div></div>
            <div><div className="text-slate-400 text-sm">Released</div><div>{record.releasedAt ? new Date(record.releasedAt).toLocaleString() : 'Not released'}</div></div>
          </div>
          <div><div className="text-slate-400 text-sm">Reason</div><div className="mt-2 p-4 rounded-xl bg-slate-950 border border-slate-700 whitespace-pre-wrap">{record.reason}</div></div>
          {record.status === 'Active' && <button onClick={release} disabled={releasing} className="px-5 py-3 rounded-xl bg-emerald-500 text-slate-950 font-bold disabled:opacity-60">{releasing ? 'Releasing...' : 'Release Quarantine'}</button>}
        </div>
      </div>
    </div>
  );
}

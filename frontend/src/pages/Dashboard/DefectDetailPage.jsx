import { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import defectService from '../../services/defectService';
import { parseErrorMessage } from '../../utils/errorHandler';

export default function DefectDetailPage() {
  const navigate = useNavigate();
  const { id } = useParams();
  const [defect, setDefect] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

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

  return (
    <div className="min-h-screen bg-slate-950 text-slate-100 p-8">
      <div className="max-w-4xl mx-auto">
        <div className="flex justify-between items-center mb-6">
          <div>
            <p className="text-emerald-400 uppercase tracking-wide text-sm font-semibold">Quality Assurance</p>
            <h1 className="text-4xl font-bold mt-2">Defect Detail</h1>
          </div>
          <div className="flex gap-2">
            <button onClick={() => navigate('/dashboard/defects')} className="px-4 py-2 rounded-xl border border-slate-700 text-slate-200 hover:bg-slate-800">All Defects</button>
            <button onClick={() => navigate(`/dashboard/defects/${defect.id}/edit`)} className="px-4 py-2 rounded-xl border border-cyan-500 text-cyan-300 hover:bg-cyan-500/10">Edit</button>
          </div>
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

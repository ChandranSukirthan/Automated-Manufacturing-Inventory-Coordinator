import { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import defectService from '../../services/defectService';
import { parseErrorMessage } from '../../utils/errorHandler';
import QANavigation from '../../components/Dashboard/QANavigation';

const productTypes = ['BoxPouch', 'BiscuitPackaging', 'TeaBag', 'Bag', 'Can', 'Bottle'];
const severities = ['LOW', 'MEDIUM', 'HIGH'];
const statuses = ['Open', 'InReview', 'Resolved', 'Closed'];

export default function DefectFormPage() {
  const navigate = useNavigate();
  const { id } = useParams();
  const isEdit = Boolean(id);

  const emptyForm = {
    batchId: '',
    productType: 'BoxPouch',
    severity: 'LOW',
    description: '',
    status: 'Open'
  };

  const [form, setForm] = useState(emptyForm);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    if (!isEdit) return;

    const load = async () => {
      setLoading(true);
      try {
        const data = await defectService.getById(id);
        setForm({
          batchId: data.batchId,
          productType: data.productType,
          severity: data.severity,
          description: data.description,
          status: data.status
        });
      } catch (err) {
        setError(parseErrorMessage(err, 'Unable to load defect.'));
      } finally {
        setLoading(false);
      }
    };

    load();
  }, [id, isEdit]);

  const handleChange = (e) => {
    const { name, value } = e.target;
    setForm({ ...form, [name]: value });
  };

  const validate = () => {
    if (!form.batchId.trim()) return 'Batch ID is required.';
    if (!form.description.trim()) return 'Description is required.';
    return '';
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    const validationError = validate();
    if (validationError) {
      setError(validationError);
      return;
    }

    setLoading(true);
    try {
      if (isEdit) {
        await defectService.update(id, {
          batchId: form.batchId,
          productType: form.productType,
          severity: form.severity,
          description: form.description,
          status: form.status
        });
      } else {
        await defectService.create({
          batchId: form.batchId,
          productType: form.productType,
          severity: form.severity,
          description: form.description,
          status: form.status
        });
      }
      navigate('/dashboard/defects');
    } catch (err) {
      setError(parseErrorMessage(err, 'Unable to save defect report.'));
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-slate-950 text-slate-100 p-8">
      <div className="max-w-3xl mx-auto">
        <QANavigation />
        <div className="flex justify-between items-center mb-8">
          <div>
            <p className="text-emerald-400 uppercase tracking-wide text-sm font-semibold">Quality Assurance</p>
            <h1 className="text-4xl font-bold mt-2">{isEdit ? 'Edit Defect Report' : 'Create Defect Report'}</h1>
          </div>
          <button onClick={() => navigate('/dashboard/defects')} className="px-4 py-2 rounded-xl border border-slate-700 text-slate-200 hover:bg-slate-800">Back to Defects</button>
        </div>

        {error && <div className="mb-4 p-3 rounded bg-red-500/10 text-red-300 border border-red-500/30">{error}</div>}

        <form onSubmit={handleSubmit} className="bg-slate-900/60 rounded-3xl border border-slate-800 p-8 space-y-6">
          <div className="grid md:grid-cols-2 gap-6">
            <div>
              <label className="block text-sm font-medium text-slate-300 mb-2">Batch ID</label>
              <input name="batchId" value={form.batchId} onChange={handleChange} className="w-full rounded-xl bg-slate-950 border border-slate-700 px-4 py-3 text-white outline-none focus:border-emerald-500" placeholder="Batch-001" />
            </div>

            <div>
              <label className="block text-sm font-medium text-slate-300 mb-2">Product Type</label>
              <select name="productType" value={form.productType} onChange={handleChange} className="w-full rounded-xl bg-slate-950 border border-slate-700 px-4 py-3 text-white outline-none focus:border-emerald-500">
                {productTypes.map((type) => <option key={type} value={type}>{type}</option>)}
              </select>
            </div>

            <div>
              <label className="block text-sm font-medium text-slate-300 mb-2">Severity</label>
              <select name="severity" value={form.severity} onChange={handleChange} className="w-full rounded-xl bg-slate-950 border border-slate-700 px-4 py-3 text-white outline-none focus:border-emerald-500">
                {severities.map((level) => <option key={level} value={level}>{level}</option>)}
              </select>
            </div>

            <div>
              <label className="block text-sm font-medium text-slate-300 mb-2">Status</label>
              <select name="status" value={form.status} onChange={handleChange} className="w-full rounded-xl bg-slate-950 border border-slate-700 px-4 py-3 text-white outline-none focus:border-emerald-500">
                {statuses.map((level) => <option key={level} value={level}>{level}</option>)}
              </select>
            </div>
          </div>

          <div>
            <label className="block text-sm font-medium text-slate-300 mb-2">Description</label>
            <textarea name="description" value={form.description} onChange={handleChange} rows="6" className="w-full rounded-xl bg-slate-950 border border-slate-700 px-4 py-3 text-white outline-none focus:border-emerald-500" placeholder="Describe the defect..." />
          </div>

          <div className="flex justify-end gap-3">
            <button type="button" onClick={() => navigate('/dashboard/defects')} className="px-5 py-3 rounded-xl border border-slate-700 text-slate-200 hover:bg-slate-800">Cancel</button>
            <button type="submit" disabled={loading} className="px-5 py-3 rounded-xl bg-emerald-500 text-slate-950 font-bold hover:bg-emerald-400 disabled:opacity-60">
              {loading ? 'Saving...' : isEdit ? 'Update Defect' : 'Create Defect'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}

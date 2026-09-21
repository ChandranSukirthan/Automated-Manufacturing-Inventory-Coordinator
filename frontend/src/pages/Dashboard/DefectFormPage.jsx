import { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import {
  ArrowLeft,
  Bot,
  Sparkles,
  Save,
  Loader2,
  AlertTriangle,
  CheckCircle2,
  ShieldAlert,
  Layers
} from 'lucide-react';
import defectService from '../../services/defectService';
import { parseErrorMessage } from '../../utils/errorHandler';
import PageHeader from '../../components/QA/PageHeader';

const productTypes = ['BoxPouch', 'BiscuitPackaging', 'TeaBag', 'Bag', 'Can', 'Bottle'];
const severities = ['LOW', 'MEDIUM', 'HIGH', 'Critical'];
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
  const [aiLoading, setAiLoading] = useState(false);
  const [aiError, setAiError] = useState('');
  const [aiRecommendation, setAiRecommendation] = useState(null);

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
      navigate('/quality/defects');
    } catch (err) {
      setError(parseErrorMessage(err, 'Unable to save defect report.'));
    } finally {
      setLoading(false);
    }
  };

  const handleAnalyzeWithAi = async () => {
    const validationError = validate();
    if (validationError) {
      setAiError(validationError);
      return;
    }

    setAiLoading(true);
    setAiError('');
    setAiRecommendation(null);
    try {
      const recommendation = await defectService.analyzeWithAi({
        batchId: form.batchId.trim(),
        productType: form.productType,
        severity: form.severity,
        description: form.description.trim()
      });
      setAiRecommendation(recommendation);
    } catch (err) {
      setAiError(parseErrorMessage(err, 'Unable to analyze the defect with AI. Ensure the AI service is running.'));
    } finally {
      setAiLoading(false);
    }
  };

  return (
    <div className="p-6 lg:p-8 max-w-4xl mx-auto space-y-6">
      {/* Page Header */}
      <PageHeader
        category="Quality Assurance"
        title={isEdit ? 'Edit Defect Report' : 'Create Defect Report'}
        subtitle={
          isEdit
            ? 'Update defect telemetry, severity metrics, and resolution status.'
            : 'Record manufacturing defect inspection findings and trigger safety protocols.'
        }
        actions={
          <button
            onClick={() => navigate('/quality/defects')}
            className="px-4 py-2.5 rounded-xl border border-slate-700 bg-slate-900/60 text-slate-200 text-sm font-medium hover:bg-slate-800 hover:text-white transition-all shadow-sm flex items-center gap-2"
          >
            <ArrowLeft className="w-4 h-4" />
            <span>Back to Defects</span>
          </button>
        }
      />

      {/* Error Banners */}
      {error && (
        <div className="rounded-2xl border border-rose-500/30 bg-rose-500/10 p-4 text-rose-200 flex items-center gap-3">
          <AlertTriangle className="w-5 h-5 text-rose-400 shrink-0" />
          <span className="text-sm font-medium">{error}</span>
        </div>
      )}
      {aiError && (
        <div className="rounded-2xl border border-amber-500/30 bg-amber-500/10 p-4 text-amber-200 flex items-center gap-3">
          <AlertTriangle className="w-5 h-5 text-amber-400 shrink-0" />
          <span className="text-sm font-medium">{aiError}</span>
        </div>
      )}

      {/* Main Form */}
      <form
        onSubmit={handleSubmit}
        className="rounded-3xl border border-slate-800 bg-slate-900/60 backdrop-blur-sm p-8 space-y-6 shadow-sm"
      >
        <div className="grid md:grid-cols-2 gap-6">
          {/* Batch ID */}
          <div>
            <label className="block text-xs font-bold uppercase tracking-wider text-slate-400 mb-2">
              Batch ID
            </label>
            <input
              name="batchId"
              value={form.batchId}
              onChange={handleChange}
              placeholder="e.g. Batch-001"
              className="w-full rounded-xl bg-slate-950 border border-slate-700 px-4 py-3 text-sm text-white placeholder:text-slate-500 outline-none focus:border-emerald-500 transition-colors"
            />
          </div>

          {/* Product Type */}
          <div>
            <label className="block text-xs font-bold uppercase tracking-wider text-slate-400 mb-2">
              Product Type
            </label>
            <select
              name="productType"
              value={form.productType}
              onChange={handleChange}
              className="w-full rounded-xl bg-slate-950 border border-slate-700 px-4 py-3 text-sm text-white outline-none focus:border-emerald-500 transition-colors"
            >
              {productTypes.map((type) => (
                <option key={type} value={type}>
                  {type}
                </option>
              ))}
            </select>
          </div>

          {/* Severity */}
          <div>
            <label className="block text-xs font-bold uppercase tracking-wider text-slate-400 mb-2">
              Severity Level
            </label>
            <select
              name="severity"
              value={form.severity}
              onChange={handleChange}
              className="w-full rounded-xl bg-slate-950 border border-slate-700 px-4 py-3 text-sm text-white outline-none focus:border-emerald-500 transition-colors"
            >
              {severities.map((level) => (
                <option key={level} value={level}>
                  {level}
                </option>
              ))}
            </select>
          </div>

          {/* Status */}
          <div>
            <label className="block text-xs font-bold uppercase tracking-wider text-slate-400 mb-2">
              Resolution Status
            </label>
            <select
              name="status"
              value={form.status}
              onChange={handleChange}
              className="w-full rounded-xl bg-slate-950 border border-slate-700 px-4 py-3 text-sm text-white outline-none focus:border-emerald-500 transition-colors"
            >
              {statuses.map((level) => (
                <option key={level} value={level}>
                  {level}
                </option>
              ))}
            </select>
          </div>
        </div>

        {/* Description */}
        <div>
          <label className="block text-xs font-bold uppercase tracking-wider text-slate-400 mb-2">
            Defect Description & Notes
          </label>
          <textarea
            name="description"
            value={form.description}
            onChange={handleChange}
            rows="5"
            placeholder="Describe defect symptoms, observed anomalies, and affected packaging parameters..."
            className="w-full rounded-xl bg-slate-950 border border-slate-700 px-4 py-3 text-sm text-white placeholder:text-slate-500 outline-none focus:border-emerald-500 transition-colors"
          />
        </div>

        {/* Form Action Buttons */}
        <div className="flex flex-wrap items-center justify-end gap-3 pt-4 border-t border-slate-800/80">
          <button
            type="button"
            onClick={() => navigate('/quality/defects')}
            className="px-5 py-2.5 rounded-xl border border-slate-700 bg-slate-900/60 text-slate-300 hover:bg-slate-800 hover:text-white text-sm font-medium transition-all"
          >
            Cancel
          </button>
          <button
            type="button"
            onClick={handleAnalyzeWithAi}
            disabled={loading || aiLoading}
            className="px-5 py-2.5 rounded-xl border border-cyan-500/40 bg-cyan-500/10 text-cyan-300 hover:bg-cyan-500/20 disabled:opacity-50 text-sm font-semibold transition-all flex items-center gap-2"
          >
            {aiLoading ? (
              <>
                <Loader2 className="w-4 h-4 animate-spin" />
                <span>Analyzing Telemetry...</span>
              </>
            ) : (
              <>
                <Sparkles className="w-4 h-4" />
                <span>Analyze with AI</span>
              </>
            )}
          </button>
          <button
            type="submit"
            disabled={loading}
            className="px-6 py-2.5 rounded-xl bg-emerald-500 text-slate-950 font-bold text-sm hover:bg-emerald-400 disabled:opacity-60 transition-all shadow-lg shadow-emerald-500/20 flex items-center gap-2"
          >
            {loading ? (
              <>
                <Loader2 className="w-4 h-4 animate-spin" />
                <span>Saving...</span>
              </>
            ) : (
              <>
                <Save className="w-4 h-4 stroke-[2.5]" />
                <span>{isEdit ? 'Update Defect' : 'Create Defect'}</span>
              </>
            )}
          </button>
        </div>
      </form>

      {/* AI Recommendation Card (Section 17) */}
      {aiRecommendation && (
        <section
          className="rounded-3xl border border-cyan-500/30 bg-cyan-500/10 p-6 backdrop-blur-sm space-y-4"
          aria-live="polite"
        >
          <div className="flex items-center gap-2.5 border-b border-cyan-500/20 pb-4">
            <div className="w-8 h-8 rounded-lg bg-cyan-500/20 flex items-center justify-center text-cyan-300">
              <Bot className="w-5 h-5" />
            </div>
            <div>
              <span className="text-cyan-300 uppercase tracking-widest text-xs font-bold">
                AI Defect Assessment
              </span>
              <p className="text-xs text-slate-300 mt-0.5">
                Machine learning risk analysis & quarantine disposition guidance
              </p>
            </div>
          </div>

          <div className="grid gap-4 sm:grid-cols-3">
            {/* Risk Level */}
            <div className="rounded-2xl border border-cyan-500/20 bg-slate-950/60 p-4">
              <span className="text-xs font-bold uppercase tracking-wider text-slate-400">
                Risk Level
              </span>
              <div className="mt-2 text-2xl font-extrabold text-white tracking-tight">
                {aiRecommendation.riskLevel}
              </div>
            </div>

            {/* Quarantine Required */}
            <div className="rounded-2xl border border-cyan-500/20 bg-slate-950/60 p-4">
              <span className="text-xs font-bold uppercase tracking-wider text-slate-400">
                Quarantine Required
              </span>
              <div className="mt-2 flex items-center gap-2">
                <span
                  className={`text-2xl font-extrabold tracking-tight ${
                    aiRecommendation.quarantineRequired ? 'text-amber-400' : 'text-emerald-400'
                  }`}
                >
                  {aiRecommendation.quarantineRequired ? 'YES' : 'NO'}
                </span>
                {aiRecommendation.quarantineRequired ? (
                  <ShieldAlert className="w-5 h-5 text-amber-400" />
                ) : (
                  <CheckCircle2 className="w-5 h-5 text-emerald-400" />
                )}
              </div>
            </div>

            {/* Affected Inventory */}
            <div className="rounded-2xl border border-cyan-500/20 bg-slate-950/60 p-4">
              <span className="text-xs font-bold uppercase tracking-wider text-slate-400">
                Affected Inventory
              </span>
              <div className="mt-2 text-sm font-mono text-cyan-200 break-words">
                {aiRecommendation.affectedInventory?.length
                  ? aiRecommendation.affectedInventory.join(', ')
                  : 'None identified'}
              </div>
            </div>
          </div>
        </section>
      )}
    </div>
  );
}

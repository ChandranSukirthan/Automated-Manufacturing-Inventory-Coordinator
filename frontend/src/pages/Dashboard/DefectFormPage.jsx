import { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { ArrowLeft, Bot, Sparkles, Save, Loader2, AlertTriangle, CheckCircle2, ShieldAlert } from 'lucide-react';
import defectService from '../../services/defectService';
import inventoryService from '../../services/inventoryService';
import { parseErrorMessage } from '../../utils/errorHandler';
import PageHeader from '../../components/QA/PageHeader';
import SeverityBadge from '../../components/QA/SeverityBadge';
import StatusBadge from '../../components/QA/StatusBadge';

const severities = ['LOW', 'MEDIUM', 'HIGH', 'Critical'];
const statuses = ['Open', 'InReview', 'Resolved', 'Closed'];

function getCreatedMaterials(inventoryItems, rawMaterials) {
  const rawMaterialBySku = new Map(
    rawMaterials
      .filter((material) => material.skuCode?.trim())
      .map((material) => [material.skuCode.trim().toLowerCase(), material])
  );

  return inventoryItems
    .filter((item, index, items) => {
      const sku = item.sku?.trim().toLowerCase();
      return sku && items.findIndex((candidate) => candidate.sku?.trim().toLowerCase() === sku) === index;
    })
    .map((item) => {
      const material = rawMaterialBySku.get(item.sku.trim().toLowerCase());
      return material
        ? { ...material, name: item.name || material.name, skuCode: item.sku.trim() }
        : null;
    })
    .filter(Boolean);
}

export default function DefectFormPage() {
  const navigate = useNavigate();
  const { id } = useParams();
  const isEdit = Boolean(id);
  const [form, setForm] = useState({ skuCode: '', rawMaterialName: '', severity: 'LOW', description: '', status: 'Open' });
  const [inventoryItems, setInventoryItems] = useState([]);
  const [rawMaterials, setRawMaterials] = useState([]);
  const [inventoryRolls, setInventoryRolls] = useState([]);
  const [selectedInventory, setSelectedInventory] = useState([]);
  const [loading, setLoading] = useState(false);
  const [loadingInventory, setLoadingInventory] = useState(true);
  const [error, setError] = useState('');
  const [aiError, setAiError] = useState('');
  const [aiLoading, setAiLoading] = useState(false);
  const [aiRecommendation, setAiRecommendation] = useState(null);

  useEffect(() => {
    const loadInventory = async () => {
      try {
        const [items, materials, rolls] = await Promise.all([
          inventoryService.getItems(),
          inventoryService.getRawMaterials(),
          inventoryService.getRolls(),
        ]);
        setInventoryItems(items || []);
        setRawMaterials(materials || []);
        setInventoryRolls(Array.from(new Map((rolls || []).map((roll) => [roll.id, roll])).values()));
      } catch (err) {
        setError(parseErrorMessage(err, 'Unable to load FloorWorker inventory.'));
      } finally {
        setLoadingInventory(false);
      }
    };
    loadInventory();
  }, []);

  useEffect(() => {
    if (!isEdit || inventoryRolls.length === 0) return;
    const load = async () => {
      setLoading(true);
      try {
        const data = await defectService.getById(id);
        const affected = data.affectedInventory || [];
        const roll = inventoryRolls.find((item) => affected.includes(item.id));
        const material = getCreatedMaterials(inventoryItems, rawMaterials)
          .find((item) => item.id === roll?.rawMaterialId);
        setForm({ skuCode: material?.skuCode || '', rawMaterialName: material?.name || '', severity: data.severity, description: data.description, status: data.status });
        setSelectedInventory(affected);
      } catch (err) {
        setError(parseErrorMessage(err, 'Unable to load defect.'));
      } finally {
        setLoading(false);
      }
    };
    load();
  }, [id, isEdit, inventoryRolls, inventoryItems, rawMaterials]);

  const createdMaterials = getCreatedMaterials(inventoryItems, rawMaterials);
  const selectedMaterial = createdMaterials.find((item) => item.skuCode.toLowerCase() === form.skuCode.toLowerCase());
  const skuRolls = inventoryRolls.filter((roll) => roll.rawMaterialId === selectedMaterial?.id);

  const handleSkuChange = async (event) => {
    const skuCode = event.target.value;
    const material = createdMaterials.find((item) => item.skuCode === skuCode);
    setSelectedInventory([]);
    setForm((current) => ({ ...current, skuCode, rawMaterialName: material?.name || '' }));
  };

  const handleChange = (event) => setForm({ ...form, [event.target.name]: event.target.value });

  const validate = (requireInventory = true) => {
    if (!form.skuCode) return 'Inventory roll is required.';
    if (requireInventory && selectedInventory.length === 0) return 'Select at least one inventory roll.';
    if (!form.description.trim()) return 'Description is required.';
    return '';
  };

  const payload = { skuCode: form.skuCode, severity: form.severity, description: form.description.trim(), status: form.status, affectedInventory: selectedInventory };
  const assessedRollIds = aiRecommendation?.affectedInventory || [];
  const assessedRolls = assessedRollIds.map((rollId) => inventoryRolls.find((roll) => roll.id === rollId)).filter(Boolean);

  const handleSubmit = async (event) => {
    event.preventDefault();
    const message = validate(true);
    if (message) return setError(message);
    setLoading(true);
    try {
      if (isEdit) await defectService.update(id, payload);
      else await defectService.create(payload);
      navigate('/quality/defects');
    } catch (err) {
      setError(parseErrorMessage(err, 'Unable to save defect report.'));
    } finally {
      setLoading(false);
    }
  };

  const analyze = async () => {
    const message = validate(false);
    if (message) return setAiError(message);
    setAiLoading(true);
    setAiError('');
    try {
      const recommendation = await defectService.analyzeWithAi(payload);
      setAiRecommendation(recommendation);
    } catch (err) {
      setAiError(parseErrorMessage(err, 'Unable to analyze the defect with AI.'));
    } finally {
      setAiLoading(false);
    }
  };

  return (
    <div className="p-6 lg:p-8 max-w-4xl mx-auto space-y-6">
      <PageHeader category="Quality Assurance" title={isEdit ? 'Edit Defect Report' : 'Create Defect Report'} subtitle="Use shared FloorWorker inventory data to record and assess a defect." actions={<button onClick={() => navigate('/quality/defects')} className="px-4 py-2.5 rounded-xl border border-slate-700 bg-slate-900/60 text-slate-200 text-sm font-medium flex items-center gap-2"><ArrowLeft className="w-4 h-4" />Back to Defects</button>} />
      {(error || aiError) && <div className="rounded-2xl border border-rose-500/30 bg-rose-500/10 p-4 text-rose-200 flex items-center gap-3"><AlertTriangle className="w-5 h-5" /><span>{error || aiError}</span></div>}
      <form onSubmit={handleSubmit} className="rounded-3xl border border-slate-800 bg-slate-900/60 p-8 space-y-6">
        <div className="grid md:grid-cols-2 gap-6">
          <label className="block text-xs font-bold uppercase tracking-wider text-slate-400">Inventory Roll<select value={form.skuCode} onChange={handleSkuChange} disabled={loadingInventory} className="mt-2 w-full rounded-xl bg-slate-950 border border-slate-700 px-4 py-3 text-sm text-white"><option value="">Select Inventory Roll</option>{createdMaterials.map((item) => <option key={item.skuCode} value={item.skuCode}>{item.skuCode}</option>)}</select></label>
          <label className="block text-xs font-bold uppercase tracking-wider text-slate-400">Raw Material<input readOnly value={form.rawMaterialName || 'Determined from selected inventory'} className="mt-2 w-full rounded-xl bg-slate-950 border border-slate-700 px-4 py-3 text-sm text-slate-300" /></label>
          <label className="block text-xs font-bold uppercase tracking-wider text-slate-400">Severity<select name="severity" value={form.severity} onChange={handleChange} className="mt-2 w-full rounded-xl bg-slate-950 border border-slate-700 px-4 py-3 text-sm text-white">{severities.map((value) => <option key={value}>{value}</option>)}</select></label>
          <label className="block text-xs font-bold uppercase tracking-wider text-slate-400">Status<select name="status" value={form.status} onChange={handleChange} className="mt-2 w-full rounded-xl bg-slate-950 border border-slate-700 px-4 py-3 text-sm text-white">{statuses.map((value) => <option key={value}>{value}</option>)}</select></label>
        </div>
        <label className="block text-xs font-bold uppercase tracking-wider text-slate-400">Description<textarea name="description" value={form.description} onChange={handleChange} rows="5" className="mt-2 w-full rounded-xl bg-slate-950 border border-slate-700 px-4 py-3 text-sm text-white" /></label>
        {aiRecommendation && <div><p className="text-xs font-bold uppercase tracking-wider text-slate-400 mb-3">Select Inventory Rolls</p><div className="grid gap-2 sm:grid-cols-2">{skuRolls.length === 0 ? <p className="text-sm text-slate-500">No current inventory rolls found.</p> : skuRolls.map((roll) => <label key={roll.id} className="flex gap-3 rounded-xl border border-slate-800 p-3 text-sm text-slate-200"><input type="checkbox" checked={selectedInventory.includes(roll.id)} onChange={(event) => setSelectedInventory((current) => event.target.checked ? [...current, roll.id] : current.filter((value) => value !== roll.id))} className="mt-1 accent-cyan-500" /><span><span className="block font-mono text-cyan-300">{roll.rollIdentifier || roll.id}</span><span className="block text-xs text-slate-400">Raw Material: {form.rawMaterialName} · {roll.currentQuantity} / {roll.initialQuantity} units — {roll.status}</span></span></label>)}</div><p className="mt-2 text-xs text-slate-500">Review or adjust the rolls selected for this defect.</p></div>}
        <div className="flex justify-end gap-3 border-t border-slate-800 pt-4"><button type="button" onClick={analyze} disabled={aiLoading} className="px-5 py-2.5 rounded-xl border border-cyan-500/40 bg-cyan-500/10 text-cyan-300 flex items-center gap-2">{aiLoading ? <Loader2 className="w-4 h-4 animate-spin" /> : <Sparkles className="w-4 h-4" />}Analyze with AI</button><button type="submit" disabled={loading} className="px-6 py-2.5 rounded-xl bg-emerald-500 text-slate-950 font-bold flex items-center gap-2">{loading ? <Loader2 className="w-4 h-4 animate-spin" /> : <Save className="w-4 h-4" />}{isEdit ? 'Update Defect' : 'Create Defect'}</button></div>
      </form>
      {aiLoading && (
        <section className="rounded-3xl border border-cyan-500/30 bg-slate-900/70 p-6" role="status" aria-live="polite">
          <div className="flex items-center gap-3 text-cyan-200">
            <Loader2 className="w-5 h-5 animate-spin" />
            <div>
              <p className="font-semibold">AI analysis in progress</p>
              <p className="text-sm text-slate-400 mt-1">Reviewing the submitted defect and selected inventory context.</p>
            </div>
          </div>
        </section>
      )}
      {aiRecommendation && !aiLoading && (
        <section className="rounded-3xl border border-cyan-500/30 bg-slate-900/70 overflow-hidden" aria-labelledby="ai-assessment-title">
          <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between border-b border-slate-800 bg-cyan-500/5 px-6 py-5">
            <div className="flex items-start gap-3">
              <div className="mt-0.5 flex h-10 w-10 shrink-0 items-center justify-center rounded-xl border border-cyan-500/30 bg-cyan-500/10 text-cyan-300">
                <Bot className="w-5 h-5" />
              </div>
              <div>
                <h2 id="ai-assessment-title" className="text-lg font-bold text-white">AI Defect Assessment</h2>
                <div className="mt-1 flex items-center gap-1.5 text-xs text-emerald-300"><CheckCircle2 className="w-3.5 h-3.5" />Analysis completed</div>
              </div>
            </div>
            <StatusBadge status={aiRecommendation.quarantineRequired ? 'Active' : 'Released'} />
          </div>
          <div className="p-6 space-y-6">
            <div className="grid gap-4 sm:grid-cols-2">
              <div className="rounded-2xl border border-slate-800 bg-slate-950/60 p-4">
                <p className="text-xs font-semibold uppercase tracking-wider text-slate-500">Risk Level</p>
                <div className="mt-3"><SeverityBadge severity={aiRecommendation.riskLevel} /></div>
              </div>
              <div className="rounded-2xl border border-slate-800 bg-slate-950/60 p-4">
                <p className="text-xs font-semibold uppercase tracking-wider text-slate-500">Quarantine Required</p>
                <div className={`mt-3 inline-flex items-center gap-2 text-lg font-bold ${aiRecommendation.quarantineRequired ? 'text-amber-300' : 'text-emerald-300'}`}>
                  <span className={`h-2.5 w-2.5 rounded-full ${aiRecommendation.quarantineRequired ? 'bg-amber-400' : 'bg-emerald-400'}`} />
                  {aiRecommendation.quarantineRequired ? 'YES' : 'NO'}
                </div>
              </div>
            </div>
            <div>
              <div className="flex items-center justify-between gap-3 mb-3">
                <div>
                  <h3 className="text-sm font-bold text-white">Affected Inventory Rolls</h3>
                  <p className="text-xs text-slate-500 mt-1">Rolls returned by the AI assessment.</p>
                </div>
                <span className="text-xs font-semibold text-slate-400">{assessedRollIds.length} roll{assessedRollIds.length === 1 ? '' : 's'}</span>
              </div>
              {assessedRolls.length > 0 ? (
                <div className="grid gap-2 sm:grid-cols-2">
                  {assessedRolls.map((roll) => (
                    <div key={roll.id} className="flex items-center justify-between gap-3 rounded-xl border border-slate-800 bg-slate-950/40 px-4 py-3">
                      <div className="min-w-0"><p className="truncate font-mono text-sm font-semibold text-cyan-300">{roll.rollIdentifier || roll.id}</p><p className="mt-1 text-xs text-slate-500">Raw Material: {form.rawMaterialName} · {roll.currentQuantity} / {roll.initialQuantity} units</p></div>
                      <StatusBadge status={roll.status || 'In Stock'} />
                    </div>
                  ))}
                </div>
              ) : <p className="rounded-xl border border-slate-800 bg-slate-950/40 px-4 py-3 text-sm text-slate-400">No affected rolls identified.</p>}
            </div>
            <div className="border-t border-slate-800 pt-4">
              <p className="text-xs font-semibold uppercase tracking-wider text-slate-500">Assessment Summary</p>
              <p className="mt-2 text-sm leading-6 text-slate-300">{aiRecommendation.reason || `The AI assessment returned a ${aiRecommendation.riskLevel || 'LOW'} risk level and quarantine is ${aiRecommendation.quarantineRequired ? 'required' : 'not required'}.`}</p>
            </div>
          </div>
        </section>
      )}
    </div>
  );
}

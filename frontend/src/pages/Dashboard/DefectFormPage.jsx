import React, { useEffect, useState } from 'react';
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
  Layers,
  Package,
  Check,
  ClipboardList
} from 'lucide-react';
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

const agentProgressSteps = [
  'Agent Activated',
  'Analyzing Defect Context',
  'Inspecting Related Inventory Rolls',
  'Evaluating Quarantine Thresholds',
  'Generating Roll Recommendations',
  'Assessment Complete'
];

export default function DefectFormPage() {
  const navigate = useNavigate();
  const { id } = useParams();
  const isEdit = Boolean(id);
  const [form, setForm] = useState({
    skuCode: '',
    rawMaterialName: '',
    severity: 'LOW',
    description: '',
    status: 'Open'
  });
  const [inventoryItems, setInventoryItems] = useState([]);
  const [rawMaterials, setRawMaterials] = useState([]);
  const [inventoryRolls, setInventoryRolls] = useState([]);
  const [selectedInventory, setSelectedInventory] = useState([]);
  const [loading, setLoading] = useState(false);
  const [loadingInventory, setLoadingInventory] = useState(true);
  const [error, setError] = useState('');
  const [aiError, setAiError] = useState('');
  const [aiLoading, setAiLoading] = useState(false);
  const [aiStepIndex, setAiStepIndex] = useState(0);
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
        setInventoryRolls(Array.from(new Map((rolls || []).map((roll) => [roll.rollIdentifier, { ...roll, id: roll.rollIdentifier }])).values()));
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
        setForm({
          skuCode: material?.skuCode || data.skuCode || '',
          rawMaterialName: material?.name || '',
          severity: data.severity,
          description: data.description,
          status: data.status
        });
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
  const inspectableMaterials = createdMaterials.filter((material) =>
    inventoryRolls.some((roll) => roll.rawMaterialId === material.id)
  );
  const selectedMaterial = createdMaterials.find(
    (item) => item.skuCode.toLowerCase() === form.skuCode.toLowerCase()
  );
  const skuRolls = inventoryRolls.filter((roll) => roll.rawMaterialId === selectedMaterial?.id);

  const handleSkuChange = async (event) => {
    const skuCode = event.target.value;
    const material = createdMaterials.find((item) => item.skuCode === skuCode);
    setSelectedInventory([]);
    setAiRecommendation(null);
    setForm((current) => ({ ...current, skuCode, rawMaterialName: material?.name || '' }));
  };

  const handleChange = (event) => setForm({ ...form, [event.target.name]: event.target.value });

  const validate = (requireInventory = true) => {
    if (!form.skuCode) return 'Inventory roll SKU is required.';
    if (requireInventory && selectedInventory.length === 0) {
      return 'Select at least one inventory roll or click "Activate Agent" to evaluate affected rolls.';
    }
    if (!form.description.trim()) return 'Description is required.';
    return '';
  };

  const payload = {
    skuCode: form.skuCode,
    severity: form.severity,
    description: form.description.trim(),
    status: form.status,
    affectedInventory: selectedInventory
  };

  const assessedRollIds = aiRecommendation?.affectedInventory || [];
  const assessedRolls = assessedRollIds
    .map((rollId) => inventoryRolls.find((roll) => roll.id === rollId))
    .filter(Boolean);

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

  const activateAgent = async () => {
    const message = validate(false);
    if (message) return setAiError(message);
    if (skuRolls.length === 0) {
      return setAiError('This SKU has no registered physical inventory rolls. Receive or register a roll before activating the QA agent.');
    }
    setAiLoading(true);
    setAiError('');
    setAiStepIndex(0);

    const stepInterval = setInterval(() => {
      setAiStepIndex((prev) => (prev < agentProgressSteps.length - 1 ? prev + 1 : prev));
    }, 450);

    try {
      const recommendation = await defectService.analyzeWithAi(payload);
      setAiRecommendation(recommendation);

      // Auto-select recommended rolls if provided by the agent
      if (recommendation?.affectedInventory && Array.isArray(recommendation.affectedInventory)) {
        setSelectedInventory((prev) => {
          const combined = Array.from(new Set([...prev, ...recommendation.affectedInventory]));
          return combined;
        });
      }
    } catch (err) {
      setAiError(parseErrorMessage(err, 'Unable to complete AI defect analysis.'));
    } finally {
      clearInterval(stepInterval);
      setAiStepIndex(agentProgressSteps.length - 1);
      setTimeout(() => {
        setAiLoading(false);
      }, 500);
    }
  };

  return (
    <div className="p-6 lg:p-8 max-w-4xl mx-auto space-y-6">
      {/* Page Header */}
      <PageHeader
        category="Quality Assurance"
        title={isEdit ? 'Edit Defect Report' : 'Create Defect Report'}
        subtitle="Record a manufacturing quality issue for investigation"
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

      {/* Error Notifications */}
      {(error || aiError) && (
        <div className="rounded-2xl border border-rose-500/30 bg-rose-500/10 p-4 text-rose-200 flex items-center gap-3 animate-in fade-in">
          <AlertTriangle className="w-5 h-5 text-rose-400 shrink-0" />
          <span className="text-sm font-medium">{error || aiError}</span>
        </div>
      )}

      {/* Main Input Form */}
      <form onSubmit={handleSubmit} className="rounded-3xl border border-slate-800 bg-slate-900/60 backdrop-blur-sm p-6 sm:p-8 space-y-6 shadow-sm">
        <div className="grid md:grid-cols-2 gap-6">
          <label className="block text-xs font-bold uppercase tracking-wider text-slate-400">
            Inventory Roll
            <select
              value={form.skuCode}
              onChange={handleSkuChange}
              disabled={loadingInventory}
              className="mt-2 w-full rounded-xl bg-slate-950 border border-slate-700 px-4 py-3 text-sm text-white outline-none focus:border-blue-500 transition-colors"
            >
              <option value="">Select Inventory Roll</option>
              {inspectableMaterials.map((item) => (
                <option key={item.skuCode} value={item.skuCode}>
                  {item.skuCode} ({item.name})
                </option>
              ))}
            </select>
            <span className="mt-2 block text-[11px] normal-case tracking-normal text-slate-500">
              Only SKUs with registered physical rolls are available for AI inspection.
            </span>
          </label>

          <label className="block text-xs font-bold uppercase tracking-wider text-slate-400">
            Raw Material
            <input
              readOnly
              value={form.rawMaterialName || 'Determined from selected inventory'}
              className="mt-2 w-full rounded-xl bg-slate-950 border border-slate-700 px-4 py-3 text-sm text-slate-300 cursor-not-allowed"
            />
          </label>

          <label className="block text-xs font-bold uppercase tracking-wider text-slate-400">
            Severity
            <select
              name="severity"
              value={form.severity}
              onChange={handleChange}
              className="mt-2 w-full rounded-xl bg-slate-950 border border-slate-700 px-4 py-3 text-sm text-white outline-none focus:border-blue-500 transition-colors"
            >
              {severities.map((value) => (
                <option key={value} value={value}>
                  {value}
                </option>
              ))}
            </select>
          </label>

          <label className="block text-xs font-bold uppercase tracking-wider text-slate-400">
            Status
            <select
              name="status"
              value={form.status}
              onChange={handleChange}
              className="mt-2 w-full rounded-xl bg-slate-950 border border-slate-700 px-4 py-3 text-sm text-white outline-none focus:border-blue-500 transition-colors"
            >
              {statuses.map((value) => (
                <option key={value} value={value}>
                  {value}
                </option>
              ))}
            </select>
          </label>
        </div>

        <label className="block text-xs font-bold uppercase tracking-wider text-slate-400">
          Description
          <textarea
            name="description"
            value={form.description}
            onChange={handleChange}
            rows={5}
            placeholder="Detail the observed imperfection, fabric distortion, batch anomalies, or inspection findings..."
            className="mt-2 w-full rounded-xl bg-slate-950 border border-slate-700 px-4 py-3 text-sm text-white placeholder:text-slate-500 outline-none focus:border-blue-500 transition-colors"
          />
        </label>

        {/* Rolls Selection Section (Displayed when AI recommendation is received or when editing) */}
        {(aiRecommendation || isEdit) && (
          <div className="pt-2 border-t border-slate-800/80">
            <p className="text-xs font-bold uppercase tracking-wider text-slate-400 mb-3">
              Select Inventory Rolls
            </p>
            <div className="grid gap-2 sm:grid-cols-2">
              {skuRolls.length === 0 ? (
                <p className="text-sm text-slate-500 p-3 rounded-xl bg-slate-950/40 border border-slate-800">
                  No current inventory rolls found for this SKU.
                </p>
              ) : (
                skuRolls.map((roll) => (
                  <label
                    key={roll.id}
                    className={`flex gap-3 rounded-xl border p-3 text-sm cursor-pointer transition-all ${
                      selectedInventory.includes(roll.id)
                        ? 'bg-blue-600/15 border-blue-500/40 text-white'
                        : 'bg-slate-950/40 border-slate-800 text-slate-200 hover:border-slate-700'
                    }`}
                  >
                    <input
                      type="checkbox"
                      checked={selectedInventory.includes(roll.id)}
                      onChange={(event) =>
                        setSelectedInventory((current) =>
                          event.target.checked
                            ? [...current, roll.id]
                            : current.filter((v) => v !== roll.id)
                        )
                      }
                      className="mt-1 accent-blue-500 w-4 h-4 rounded"
                    />
                    <span className="min-w-0">
                      <span className="block font-mono text-cyan-300 font-bold truncate">
                        {roll.rollIdentifier || roll.id}
                      </span>
                      <span className="block text-xs text-slate-400 mt-0.5">
                        Batch: {roll.batchId || 'Unassigned'} · Raw Material: {form.rawMaterialName} · {roll.currentQuantity} / {roll.initialQuantity} units — {roll.status}
                      </span>
                    </span>
                  </label>
                ))
              )}
            </div>
            <p className="mt-2 text-xs text-slate-500">
              Review or adjust the rolls selected for this defect report.
            </p>
          </div>
        )}

        {/* Action Buttons Toolbar */}
        <div className="flex justify-end gap-3 border-t border-slate-800 pt-4">
          <button
            type="button"
            onClick={activateAgent}
            disabled={aiLoading}
            className="px-5 py-2.5 rounded-xl border border-blue-500/40 bg-blue-500/10 text-blue-300 hover:bg-blue-500/20 text-sm font-bold flex items-center gap-2 transition-all shadow-sm disabled:opacity-50"
          >
            {aiLoading ? (
              <Loader2 className="w-4 h-4 animate-spin text-blue-300" />
            ) : (
              <Sparkles className="w-4 h-4 text-cyan-300" />
            )}
            <span>Activate Agent</span>
          </button>

          <button
            type="submit"
            disabled={loading}
            className="px-6 py-2.5 rounded-xl bg-gradient-to-r from-blue-600 to-blue-700 hover:from-blue-500 hover:to-blue-600 text-white font-bold text-sm flex items-center gap-2 shadow-lg shadow-blue-600/25 disabled:opacity-50 transition-all"
          >
            {loading ? <Loader2 className="w-4 h-4 animate-spin" /> : <Save className="w-4 h-4" />}
            <span>{isEdit ? 'Update Defect Report' : 'Create Defect Report'}</span>
          </button>
        </div>
      </form>

      {/* Stepped Progress Indicator during Agent Activation */}
      {aiLoading && (
        <section className="rounded-3xl border border-blue-500/40 bg-slate-900/90 p-6 shadow-2xl space-y-4 animate-in fade-in" role="status" aria-live="polite">
          <div className="flex items-center justify-between border-b border-slate-800 pb-3">
            <div className="flex items-center gap-2 text-blue-200">
              <Bot className="w-5 h-5 text-blue-400 animate-bounce" />
              <div>
                <p className="font-bold text-white text-sm">AI Defect Assessment Pipeline Running</p>
                <p className="text-xs text-slate-400 mt-0.5">Reviewing submitted defect context and evaluating related factory inventory.</p>
              </div>
            </div>
            <span className="text-xs font-mono text-blue-300 bg-blue-500/10 border border-blue-500/20 px-2.5 py-1 rounded-full">
              Step {aiStepIndex + 1} of {agentProgressSteps.length}
            </span>
          </div>

          <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-6 gap-2 pt-1">
            {agentProgressSteps.map((step, idx) => {
              const isCompleted = idx < aiStepIndex;
              const isCurrent = idx === aiStepIndex;
              return (
                <div
                  key={step}
                  className={`p-2.5 rounded-xl border text-xs transition-all ${
                    isCurrent
                      ? 'bg-blue-600/20 border-blue-500 text-blue-200 font-bold shadow-md'
                      : isCompleted
                      ? 'bg-emerald-500/10 border-emerald-500/30 text-emerald-300'
                      : 'bg-slate-950/40 border-slate-800 text-slate-500'
                  }`}
                >
                  <div className="flex items-center gap-1.5 mb-1">
                    {isCompleted ? (
                      <Check className="w-3.5 h-3.5 text-emerald-400 shrink-0" />
                    ) : isCurrent ? (
                      <Loader2 className="w-3.5 h-3.5 animate-spin text-blue-400 shrink-0" />
                    ) : (
                      <span className="w-3.5 h-3.5 rounded-full bg-slate-800 text-[9px] flex items-center justify-center font-mono shrink-0">
                        {idx + 1}
                      </span>
                    )}
                    <span className="text-[10px] uppercase font-semibold">Stage {idx + 1}</span>
                  </div>
                  <p className="line-clamp-1 text-[11px]">{step}</p>
                </div>
              );
            })}
          </div>
        </section>
      )}

      {/* AI Recommendation Box (Exact Text & Box Format as Previous, Clean Industrial Finish) */}
      {aiRecommendation && !aiLoading && (
        <section className="rounded-3xl border border-blue-500/30 bg-slate-900/70 overflow-hidden shadow-xl animate-in fade-in" aria-labelledby="ai-assessment-title">
          <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between border-b border-slate-800 bg-blue-500/10 px-6 py-5">
            <div className="flex items-start gap-3">
              <div className="mt-0.5 flex h-10 w-10 shrink-0 items-center justify-center rounded-xl border border-blue-500/30 bg-blue-500/15 text-blue-300 shadow-md">
                <Bot className="w-5 h-5" />
              </div>
              <div>
                <h2 id="ai-assessment-title" className="text-lg font-bold text-white">AI Defect Assessment</h2>
                <div className="mt-1 flex items-center gap-1.5 text-xs text-emerald-300">
                  <CheckCircle2 className="w-3.5 h-3.5 text-emerald-400" />
                  <span>Analysis completed</span>
                </div>
              </div>
            </div>
            <StatusBadge status={aiRecommendation.quarantineRequired ? 'Active' : 'Released'} />
          </div>

          <div className="p-6 space-y-6">
            {/* Risk Level and Quarantine Required Cards */}
            <div className="grid gap-4 sm:grid-cols-2">
              <div className="rounded-2xl border border-slate-800 bg-slate-950/60 p-4">
                <p className="text-xs font-semibold uppercase tracking-wider text-slate-400">Risk Level</p>
                <div className="mt-3">
                  <SeverityBadge severity={aiRecommendation.riskLevel} />
                </div>
              </div>

              <div className="rounded-2xl border border-slate-800 bg-slate-950/60 p-4">
                <p className="text-xs font-semibold uppercase tracking-wider text-slate-400">Quarantine Required</p>
                <div className={`mt-3 inline-flex items-center gap-2 text-lg font-bold ${aiRecommendation.quarantineRequired ? 'text-amber-300' : 'text-emerald-300'}`}>
                  <span className={`h-2.5 w-2.5 rounded-full ${aiRecommendation.quarantineRequired ? 'bg-amber-400 animate-pulse' : 'bg-emerald-400'}`} />
                  <span>{aiRecommendation.quarantineRequired ? 'YES' : 'NO'}</span>
                </div>
              </div>
            </div>

            {/* Affected Inventory Rolls List */}
            <div>
              <div className="flex items-center justify-between gap-3 mb-3">
                <div>
                  <h3 className="text-sm font-bold text-white">Affected Inventory Rolls</h3>
                  <p className="text-xs text-slate-400 mt-0.5">Rolls returned by the AI assessment.</p>
                </div>
                <span className="text-xs font-mono text-cyan-300 bg-cyan-500/10 border border-cyan-500/30 px-2.5 py-0.5 rounded-full">
                  {assessedRollIds.length} roll{assessedRollIds.length === 1 ? '' : 's'}
                </span>
              </div>

              {assessedRolls.length > 0 ? (
                <div className="grid gap-2 sm:grid-cols-2">
                  {assessedRolls.map((roll) => (
                    <div key={roll.id} className="flex items-center justify-between gap-3 rounded-xl border border-slate-800 bg-slate-950/60 px-4 py-3">
                      <div className="min-w-0">
                        <p className="truncate font-mono text-sm font-bold text-cyan-300">
                          {roll.rollIdentifier || roll.id}
                        </p>
                        <p className="mt-1 text-xs text-slate-400 truncate">
                          Raw Material: {form.rawMaterialName} · {roll.currentQuantity} / {roll.initialQuantity} units
                        </p>
                      </div>
                      <StatusBadge status={roll.status || 'In Stock'} />
                    </div>
                  ))}
                </div>
              ) : (
                <p className="rounded-xl border border-slate-800 bg-slate-950/40 px-4 py-3 text-sm text-slate-400">
                  No affected rolls identified.
                </p>
              )}
            </div>

            {/* Assessment Summary */}
            <div className="border-t border-slate-800 pt-4">
              <p className="text-xs font-semibold uppercase tracking-wider text-slate-400">Assessment Summary</p>
              <p className="mt-2 text-sm leading-6 text-slate-200 bg-slate-950/60 p-4 rounded-2xl border border-slate-800">
                {aiRecommendation.reason ||
                  `The AI assessment returned a ${aiRecommendation.riskLevel || 'LOW'} risk level and quarantine is ${
                    aiRecommendation.quarantineRequired ? 'required' : 'not required'
                  }.`}
              </p>
            </div>
          </div>
        </section>
      )}
    </div>
  );
}

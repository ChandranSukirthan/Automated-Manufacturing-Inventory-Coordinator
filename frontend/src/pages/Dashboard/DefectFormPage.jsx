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
  'Initializing Agent Context',
  'Analyzing Inventory Roll History',
  'Evaluating Defect Severity Rules',
  'Checking Quarantine Thresholds',
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
  const selectedMaterial = createdMaterials.find(
    (item) => item.skuCode.toLowerCase() === form.skuCode.toLowerCase()
  );
  const skuRolls = inventoryRolls.filter((roll) => roll.rawMaterialId === selectedMaterial?.id);

  const handleSkuChange = async (event) => {
    const skuCode = event.target.value;
    const material = createdMaterials.find((item) => item.skuCode === skuCode);
    setSelectedInventory([]);
    setForm((current) => ({ ...current, skuCode, rawMaterialName: material?.name || '' }));
  };

  const handleChange = (event) => setForm({ ...form, [event.target.name]: event.target.value });

  const validate = (requireInventory = true) => {
    if (!form.skuCode) return 'Inventory roll SKU is required.';
    if (requireInventory && selectedInventory.length === 0) return 'Select at least one inventory roll.';
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
    setAiLoading(true);
    setAiError('');
    setAiStepIndex(0);

    const interval = setInterval(() => {
      setAiStepIndex((prev) => (prev < agentProgressSteps.length - 1 ? prev + 1 : prev));
    }, 400);

    try {
      const recommendation = await defectService.analyzeWithAi(payload);
      setAiRecommendation(recommendation);
    } catch (err) {
      setAiError(parseErrorMessage(err, 'Unable to complete AI defect analysis.'));
    } finally {
      clearInterval(interval);
      setAiLoading(false);
    }
  };

  return (
    <div className="p-6 lg:p-8 max-w-4xl mx-auto space-y-6">
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

      {(error || aiError) && (
        <div className="rounded-2xl border border-rose-500/30 bg-rose-500/10 p-4 text-rose-200 flex items-center gap-3">
          <AlertTriangle className="w-5 h-5 text-rose-400 shrink-0" />
          <span className="text-sm font-medium">{error || aiError}</span>
        </div>
      )}

      <form onSubmit={handleSubmit} className="space-y-6">
        {/* Section 1: Defect Information */}
        <div className="rounded-3xl border border-slate-800 bg-slate-900/60 backdrop-blur-sm p-6 sm:p-8 space-y-6 shadow-sm">
          <div className="flex items-center gap-2 border-b border-slate-800/80 pb-4">
            <ClipboardList className="w-5 h-5 text-purple-400" />
            <h2 className="text-base font-bold text-white tracking-tight">Defect Information</h2>
          </div>

          <div className="grid sm:grid-cols-2 gap-5">
            <div>
              <label className="block text-xs font-bold uppercase tracking-wider text-slate-400 mb-2">
                Inventory Roll SKU *
              </label>
              <select
                value={form.skuCode}
                onChange={handleSkuChange}
                disabled={loadingInventory}
                className="w-full rounded-xl bg-slate-950 border border-slate-700 px-4 py-3 text-sm text-white outline-none focus:border-purple-500 transition-colors"
              >
                <option value="">Select Inventory Roll SKU</option>
                {createdMaterials.map((item) => (
                  <option key={item.skuCode} value={item.skuCode}>
                    {item.skuCode} ({item.name})
                  </option>
                ))}
              </select>
            </div>

            <div>
              <label className="block text-xs font-bold uppercase tracking-wider text-slate-400 mb-2">
                Raw Material Name
              </label>
              <input
                readOnly
                value={form.rawMaterialName || 'Auto-populated from selected SKU'}
                className="w-full rounded-xl bg-slate-950/60 border border-slate-800 px-4 py-3 text-sm text-slate-400 cursor-not-allowed"
              />
            </div>

            <div>
              <label className="block text-xs font-bold uppercase tracking-wider text-slate-400 mb-2">
                Severity Level *
              </label>
              <select
                name="severity"
                value={form.severity}
                onChange={handleChange}
                className="w-full rounded-xl bg-slate-950 border border-slate-700 px-4 py-3 text-sm text-white outline-none focus:border-purple-500 transition-colors"
              >
                {severities.map((value) => (
                  <option key={value} value={value}>{value}</option>
                ))}
              </select>
            </div>

            <div>
              <label className="block text-xs font-bold uppercase tracking-wider text-slate-400 mb-2">
                Inspection Status *
              </label>
              <select
                name="status"
                value={form.status}
                onChange={handleChange}
                className="w-full rounded-xl bg-slate-950 border border-slate-700 px-4 py-3 text-sm text-white outline-none focus:border-purple-500 transition-colors"
              >
                {statuses.map((value) => (
                  <option key={value} value={value}>{value}</option>
                ))}
              </select>
            </div>
          </div>

          <div>
            <label className="block text-xs font-bold uppercase tracking-wider text-slate-400 mb-2">
              Defect Description &amp; Findings *
            </label>
            <textarea
              name="description"
              value={form.description}
              onChange={handleChange}
              rows={4}
              placeholder="Detail the observed imperfection, fabric distortion, batch anomalies, or inspection findings..."
              className="w-full rounded-xl bg-slate-950 border border-slate-700 px-4 py-3 text-sm text-white placeholder:text-slate-500 outline-none focus:border-purple-500 transition-colors"
            />
          </div>
        </div>

        {/* Section 2: Affected Inventory Rolls */}
        {skuRolls.length > 0 && (
          <div className="rounded-3xl border border-slate-800 bg-slate-900/60 backdrop-blur-sm p-6 sm:p-8 space-y-4 shadow-sm">
            <div className="flex items-center justify-between border-b border-slate-800/80 pb-4">
              <div className="flex items-center gap-2">
                <Package className="w-5 h-5 text-cyan-400" />
                <h2 className="text-base font-bold text-white tracking-tight">Affected Inventory Rolls</h2>
              </div>
              <span className="text-xs text-slate-400 font-mono">
                {selectedInventory.length} selected
              </span>
            </div>

            <p className="text-xs text-slate-400">
              Select the specific warehouse fabric rolls tied to this defect report:
            </p>

            <div className="grid gap-3 sm:grid-cols-2">
              {skuRolls.map((roll) => {
                const isChecked = selectedInventory.includes(roll.id);
                return (
                  <label
                    key={roll.id}
                    className={`flex items-start gap-3 rounded-2xl border p-4 cursor-pointer transition-all ${
                      isChecked
                        ? 'bg-purple-600/15 border-purple-500/40 text-white'
                        : 'bg-slate-950/40 border-slate-800 text-slate-300 hover:border-slate-700'
                    }`}
                  >
                    <input
                      type="checkbox"
                      checked={isChecked}
                      onChange={(event) =>
                        setSelectedInventory((current) =>
                          event.target.checked
                            ? [...current, roll.id]
                            : current.filter((v) => v !== roll.id)
                        )
                      }
                      className="mt-1 accent-purple-500 w-4 h-4 rounded"
                    />
                    <div className="min-w-0">
                      <span className="block font-mono font-bold text-cyan-300 text-xs truncate">
                        {roll.rollIdentifier || roll.id}
                      </span>
                      <span className="block text-[11px] text-slate-400 mt-0.5">
                        Stock: {roll.currentQuantity} / {roll.initialQuantity} units · Status: {roll.status}
                      </span>
                    </div>
                  </label>
                );
              })}
            </div>
          </div>
        )}

        {/* Section 3: AI Safety Agent Assistant Card */}
        <div className="rounded-3xl border border-slate-800 bg-slate-900/60 backdrop-blur-sm p-6 sm:p-8 space-y-4 shadow-sm">
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 border-b border-slate-800/80 pb-4">
            <div className="flex items-center gap-2">
              <Bot className="w-5 h-5 text-purple-400" />
              <div>
                <h2 className="text-base font-bold text-white tracking-tight">AI Safety Agent Assistant</h2>
                <p className="text-xs text-slate-400">Automated defect severity and quarantine recommendation</p>
              </div>
            </div>

            <button
              type="button"
              onClick={activateAgent}
              disabled={aiLoading}
              className="px-4 py-2.5 rounded-xl bg-gradient-to-r from-purple-600 via-violet-600 to-cyan-600 hover:from-purple-500 hover:to-cyan-500 text-white text-xs font-bold shadow-md shadow-purple-600/20 flex items-center justify-center gap-2 disabled:opacity-50 transition-all shrink-0"
            >
              {aiLoading ? (
                <Loader2 className="w-4 h-4 animate-spin" />
              ) : (
                <Sparkles className="w-4 h-4 text-cyan-200" />
              )}
              <span>Activate Agent</span>
            </button>
          </div>

          {/* AI Stepped Progress Animation */}
          {aiLoading && (
            <div className="p-4 rounded-2xl bg-slate-950/60 border border-purple-500/30 space-y-2 animate-in fade-in">
              <div className="flex items-center gap-2 text-xs font-bold text-purple-300">
                <Loader2 className="w-4 h-4 animate-spin text-cyan-300" />
                <span>{agentProgressSteps[aiStepIndex]}...</span>
              </div>
              <div className="w-full bg-slate-900 rounded-full h-1.5 overflow-hidden">
                <div
                  className="bg-gradient-to-r from-purple-500 to-cyan-400 h-full transition-all duration-300"
                  style={{ width: `${((aiStepIndex + 1) / agentProgressSteps.length) * 100}%` }}
                />
              </div>
            </div>
          )}

          {/* AI Recommendation Output */}
          {aiRecommendation && !aiLoading && (
            <div className="p-5 rounded-2xl bg-slate-950/80 border border-purple-500/30 space-y-4 animate-in fade-in">
              <div className="flex items-center justify-between border-b border-slate-800 pb-3">
                <div className="flex items-center gap-2">
                  <CheckCircle2 className="w-4 h-4 text-emerald-400" />
                  <span className="text-xs font-bold text-white uppercase tracking-wider">Agent Evaluation Complete</span>
                </div>
                <StatusBadge status={aiRecommendation.quarantineRequired ? 'Active' : 'Released'} />
              </div>

              <div className="grid sm:grid-cols-2 gap-4">
                <div className="p-3 rounded-xl bg-slate-900/60 border border-slate-800">
                  <span className="text-[10px] uppercase font-bold text-slate-400 block">Recommended Risk Level</span>
                  <div className="mt-1">
                    <SeverityBadge severity={aiRecommendation.riskLevel} />
                  </div>
                </div>

                <div className="p-3 rounded-xl bg-slate-900/60 border border-slate-800">
                  <span className="text-[10px] uppercase font-bold text-slate-400 block">Quarantine Containment</span>
                  <p className={`text-sm font-bold mt-1 ${aiRecommendation.quarantineRequired ? 'text-rose-400' : 'text-emerald-400'}`}>
                    {aiRecommendation.quarantineRequired ? 'QUARANTINE REQUIRED' : 'NO QUARANTINE NEEDED'}
                  </p>
                </div>
              </div>

              {aiRecommendation.reason && (
                <div className="p-3 rounded-xl bg-purple-950/20 border border-purple-500/20 text-xs text-slate-200">
                  <span className="font-bold text-purple-300 block mb-1">Agent Diagnostic Rationale:</span>
                  <p className="leading-relaxed">{aiRecommendation.reason}</p>
                </div>
              )}
            </div>
          )}
        </div>

        {/* Form Submission Station */}
        <div className="flex items-center justify-end gap-3 pt-2">
          <button
            type="button"
            onClick={() => navigate('/quality/defects')}
            className="px-5 py-2.5 rounded-xl border border-slate-700 text-slate-300 text-sm font-medium hover:bg-slate-800 transition-colors"
          >
            Cancel
          </button>
          <button
            type="submit"
            disabled={loading}
            className="px-6 py-2.5 rounded-xl bg-gradient-to-r from-purple-600 to-violet-600 hover:from-purple-500 hover:to-violet-500 text-white text-sm font-bold shadow-lg shadow-purple-600/30 flex items-center gap-2 disabled:opacity-50 transition-all"
          >
            {loading ? <Loader2 className="w-4 h-4 animate-spin" /> : <Save className="w-4 h-4" />}
            <span>{isEdit ? 'Update Defect Report' : 'Create Defect Report'}</span>
          </button>
        </div>
      </form>
    </div>
  );
}

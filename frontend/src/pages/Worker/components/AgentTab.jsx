import React, { useState } from 'react';
import {
  Bot,
  Sparkles,
  CheckCircle2,
  ArrowRight,
  Zap,
  Settings,
  ShieldCheck,
  ClipboardList,
} from 'lucide-react';

/* ── Pipeline step cards ────────────────────────────────────── */
const STEPS = [
  {
    num: 1,
    label: 'Student 1 (Floor Worker)',
    title: 'Data Extraction',
    desc: 'Extracts stock level, burn rate, and required replenishment',
    icon: ClipboardList,
    accent: 'cyan',
  },
  {
    num: 2,
    label: 'Student 4 (Production)',
    title: 'Production Analysis',
    desc: 'Analyzes machine capacity, shift schedule, and output impact',
    icon: Settings,
    accent: 'violet',
  },
  {
    num: 3,
    label: 'Student 2 (Purchasing)',
    title: 'Supplier Procurement',
    desc: 'Calculates optimal supplier and drafts Purchase Order',
    icon: Zap,
    accent: 'amber',
  },
  {
    num: 4,
    label: 'Student 3 (Quality)',
    title: 'Validation & Safety',
    desc: 'Audits defect history and verifies quarantine holds',
    icon: ShieldCheck,
    accent: 'emerald',
  },
];

const accentMap = {
  cyan: {
    border: 'border-cyan-500/30',
    bg: 'bg-cyan-950/20',
    numBg: 'bg-cyan-500/20 text-cyan-400',
    text: 'text-cyan-400',
  },
  violet: {
    border: 'border-violet-500/30',
    bg: 'bg-violet-950/20',
    numBg: 'bg-violet-500/20 text-violet-400',
    text: 'text-violet-400',
  },
  amber: {
    border: 'border-amber-500/30',
    bg: 'bg-amber-950/20',
    numBg: 'bg-amber-500/20 text-amber-400',
    text: 'text-amber-400',
  },
  emerald: {
    border: 'border-emerald-500/30',
    bg: 'bg-emerald-950/20',
    numBg: 'bg-emerald-500/20 text-emerald-400',
    text: 'text-emerald-400',
  },
};

export default function AgentTab({
  rawMaterials,
  stockLevels,
  triggeringAi,
  aiWorkflowResult,
  onTriggerAi,
}) {
  const [selectedMaterial, setSelectedMaterial] = useState('RM-STEEL-001');
  const [qty, setQty] = useState(2000);
  const [showDetails, setShowDetails] = useState(false);

  // Build material options from stockLevels or rawMaterials
  const materialOptions = stockLevels.length > 0
    ? stockLevels.map((l) => ({ sku: l.skuCode, name: l.materialName }))
    : rawMaterials.map((m) => ({ sku: m.skuCode, name: m.name }));

  return (
    <div className="space-y-6 tab-slide-in">
      <div className="p-6 rounded-2xl bg-slate-900/60 border border-slate-800 space-y-6">
        {/* Header */}
        <div className="flex items-start gap-3">
          <div className="w-11 h-11 rounded-xl bg-gradient-to-br from-cyan-500/20 to-blue-500/20 border border-cyan-500/30 flex items-center justify-center text-cyan-400">
            <Bot className="w-5 h-5" />
          </div>
          <div>
            <h3 className="text-lg font-bold text-white">
              LangGraph Multi-Agent Workflow
            </h3>
            <p className="text-xs text-slate-400 mt-1">
              Trigger autonomous replenishment through the ASP.NET Core API Gateway
            </p>
          </div>
        </div>

        {/* Architecture pipeline */}
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3">
          {STEPS.map((step, i) => {
            const a = accentMap[step.accent];
            const Icon = step.icon;
            return (
              <div key={step.num} className="relative">
                <div className={`p-4 rounded-xl ${a.bg} border ${a.border} h-full`}>
                  <div className="flex items-center gap-2 mb-2">
                    <span
                      className={`w-6 h-6 rounded-full ${a.numBg} flex items-center justify-center text-[10px] font-bold`}
                    >
                      {step.num}
                    </span>
                    <span className={`text-[10px] font-mono uppercase font-bold ${a.text}`}>
                      {step.label}
                    </span>
                  </div>
                  <h4 className="text-sm font-bold text-white flex items-center gap-1.5">
                    <Icon className="w-3.5 h-3.5 text-slate-400" />
                    {step.title}
                  </h4>
                  <p className="text-xs text-slate-400 mt-1">{step.desc}</p>
                </div>
                {/* Connector arrow (hidden on last) */}
                {i < STEPS.length - 1 && (
                  <div className="hidden lg:flex absolute -right-2 top-1/2 -translate-y-1/2 z-10">
                    <ArrowRight className="w-4 h-4 text-slate-600" />
                  </div>
                )}
              </div>
            );
          })}
        </div>

        {/* Trigger Controls */}
        <div className="p-5 rounded-xl bg-slate-950 border border-slate-800">
          <h4 className="text-sm font-bold text-white mb-3">
            Trigger Replenishment Workflow
          </h4>
          <div className="flex flex-col sm:flex-row items-end gap-4">
            <div className="flex-1 w-full">
              <label className="block text-xs font-semibold text-slate-300 mb-1">
                Material
              </label>
              <select
                value={selectedMaterial}
                onChange={(e) => setSelectedMaterial(e.target.value)}
                className="w-full bg-slate-900 border border-slate-800 rounded-xl px-4 py-2 text-sm text-white focus:outline-none focus:border-cyan-500 transition"
              >
                {materialOptions.length > 0 ? (
                  materialOptions.map((m) => (
                    <option key={m.sku} value={m.sku}>
                      {m.sku} — {m.name}
                    </option>
                  ))
                ) : (
                  <option value="RM-STEEL-001">RM-STEEL-001</option>
                )}
              </select>
            </div>
            <div className="w-full sm:w-32">
              <label className="block text-xs font-semibold text-slate-300 mb-1">
                Quantity (KG)
              </label>
              <input
                type="number"
                min={100}
                step={100}
                value={qty}
                onChange={(e) => setQty(Number(e.target.value))}
                className="w-full bg-slate-900 border border-slate-800 rounded-xl px-4 py-2 text-sm text-white focus:outline-none focus:border-cyan-500 transition tabular-nums"
              />
            </div>
            <button
              onClick={() => onTriggerAi(selectedMaterial, qty)}
              disabled={triggeringAi}
              className="px-6 py-2.5 bg-gradient-to-r from-cyan-500 to-blue-600 hover:from-cyan-400 hover:to-blue-500 text-slate-950 font-bold text-xs rounded-xl transition flex items-center gap-2 shadow-lg shadow-cyan-500/20 disabled:opacity-50 shrink-0"
            >
              <Sparkles
                className={`w-4 h-4 ${triggeringAi ? 'animate-spin' : ''}`}
              />
              {triggeringAi ? 'Initiating...' : 'Run Auto Replenishment'}
            </button>
          </div>
          <p className="text-[11px] text-slate-500 mt-2">
            Executes multi-agent autonomous decision pipeline via ASP.NET Core gateway
          </p>
        </div>

        {/* Workflow Results */}
        {aiWorkflowResult && (
          <div className="p-5 rounded-xl bg-slate-950 border border-cyan-500/30 space-y-4">
            <div className="flex items-center justify-between">
              <span className="text-xs font-bold text-cyan-400 flex items-center gap-2">
                <CheckCircle2 className="w-4 h-4 text-emerald-400" />
                Workflow: {aiWorkflowResult.workflow_id || 'WF-ACTIVE'}
              </span>
              <div className="flex items-center gap-2">
                <span className="text-xs px-2.5 py-1 rounded-full bg-cyan-500/20 text-cyan-300 font-mono">
                  {aiWorkflowResult.status || 'Active'}
                </span>
                <button
                  onClick={() => setShowDetails(!showDetails)}
                  className="text-xs text-slate-400 hover:text-cyan-400 transition"
                >
                  {showDetails ? 'Hide Details' : 'Show Details'}
                </button>
              </div>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-3 gap-3 text-xs">
              <div className="p-3 bg-slate-900 rounded-lg border border-slate-800">
                <span className="text-slate-500">Current Agent</span>
                <p className="font-bold text-white mt-1">
                  {aiWorkflowResult.current_agent || 'Completed'}
                </p>
              </div>
              <div className="p-3 bg-slate-900 rounded-lg border border-slate-800">
                <span className="text-slate-500">Requires Approval</span>
                <p className="font-bold text-amber-400 mt-1">
                  {aiWorkflowResult.requires_approval ? 'Yes (> $5,000)' : 'No'}
                </p>
              </div>
              <div className="p-3 bg-slate-900 rounded-lg border border-slate-800">
                <span className="text-slate-500">Approval Status</span>
                <p className="font-bold text-cyan-400 mt-1">
                  {aiWorkflowResult.approval_status || 'Pending'}
                </p>
              </div>
            </div>

            {/* Collapsible details */}
            {showDetails && aiWorkflowResult.po_number && (
              <div className="p-3.5 rounded-xl bg-emerald-950/40 border border-emerald-500/30 tab-slide-in">
                <span className="text-[11px] font-bold text-emerald-400 uppercase tracking-wider block">
                  Purchase Order Generated & Submitted
                </span>
                <p className="text-xs text-slate-300 mt-1">
                  Draft order{' '}
                  <strong className="text-white font-mono">
                    {aiWorkflowResult.po_number}
                  </strong>{' '}
                  for {aiWorkflowResult.quantity} units ($
                  {aiWorkflowResult.total_amount?.toLocaleString(undefined, {
                    minimumFractionDigits: 2,
                  })}
                  ) has been routed to{' '}
                  <strong>Supply Chain Manager</strong>.
                </p>
                <span className="inline-block mt-2 px-2.5 py-1 rounded-md text-[11px] font-semibold bg-amber-500/20 text-amber-300 border border-amber-500/30">
                  Pending Manager Approval
                </span>
              </div>
            )}

            {/* Show PO card by default if no collapsible toggle used */}
            {!showDetails && aiWorkflowResult.po_number && (
              <div className="p-3.5 rounded-xl bg-emerald-950/40 border border-emerald-500/30">
                <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2">
                  <div>
                    <span className="text-[11px] font-bold text-emerald-400 uppercase tracking-wider block">
                      PO Generated
                    </span>
                    <p className="text-xs text-slate-300 mt-0.5">
                      <strong className="text-white font-mono">
                        {aiWorkflowResult.po_number}
                      </strong>{' '}
                      — {aiWorkflowResult.quantity} units
                    </p>
                  </div>
                  <span className="px-2.5 py-1 rounded-md text-[11px] font-semibold bg-amber-500/20 text-amber-300 border border-amber-500/30 shrink-0">
                    Pending Manager Approval
                  </span>
                </div>
              </div>
            )}
          </div>
        )}
      </div>
    </div>
  );
}


import React, { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import dashboardService from '../../services/dashboardService';
import agentWorkflowService from '../../services/agentWorkflowService';
import { parseErrorMessage } from '../../utils/errorHandler';

export default function WorkflowActivity({ quality = false }) {
  const [workflows, setWorkflows] = useState([]);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(true);
  useEffect(() => {
    let active = true;
    let timer;
    const refresh = async () => {
      try {
        const data = await (quality ? dashboardService.getAiValidationHistory() : agentWorkflowService.getWorkflows());
        if (active) { setWorkflows(Array.isArray(data) ? data : []); setError(''); }
      } catch (err) {
        if (active) setError(parseErrorMessage(err, 'Unable to load workflow activity.'));
      } finally {
        if (active) { setLoading(false); timer = setTimeout(refresh, 10000); }
      }
    };
    void refresh();
    return () => { active = false; clearTimeout(timer); };
  }, [quality]);

  return <section className="my-6 rounded-2xl border border-slate-800 bg-slate-900/60 p-5" aria-label={quality ? 'AI validation activity' : 'Replenishment workflow activity'}>
    <h2 className="font-bold text-white">{quality ? 'AI validation activity' : 'Replenishment workflow activity'}</h2>
    <p className="mt-1 text-sm text-slate-400">{quality ? 'Validation outcomes and workflows blocked before validation.' : 'Only validated proposals proceed to order approval. Payment follows approval.'}</p>
    {error && <p role="alert" className="mt-3 text-sm text-rose-300">{error}</p>}
    {loading ? <p className="mt-3 text-sm text-slate-400">Loading workflows…</p> : workflows.length === 0 ? <p className="mt-3 text-sm text-slate-400">No workflows recorded yet.</p> :
      <div className="mt-4 space-y-3">{workflows.slice(0, 8).map((workflow) => {
        const state = workflow.details || {};
        const validation = workflow.validationResults || {};
        const id = workflow.workflowId;
        const material = workflow.materialName || state.material_name || workflow.materialId || state.material_id || 'Material unavailable';
        const sku = workflow.materialId || state.material_id;
        const quantity = workflow.quantity ?? state.draft_po?.quantity ?? state.required_quantity ?? state.requested_quantity;
        const valid = quality ? workflow.isValid : validation.isValid;
        const checked = quality ? workflow.validationExecuted : Boolean(validation.supplierValidation || validation.materialValidation);
        const result = checked ? valid === true ? 'Passed' : valid === false ? 'Failed' : 'Pending' : 'Not reached';
        const reason = workflow.rejectionReason || validation.rejectionReason || state.errors?.join(' ') || workflow.finalOutcome;
        return <article key={id} className="rounded-xl border border-slate-800 bg-slate-950/50 p-4 text-sm text-slate-300">
          <div className="flex flex-wrap justify-between gap-2"><strong className="font-mono text-cyan-300">{id}</strong><span>{workflow.workflowStatus || workflow.status}</span></div>
          <p className="mt-2">{material}{sku && material !== sku ? ` (${sku})` : ''} · Quantity: {quantity ?? 'Unavailable'} {workflow.unit || state.unit || ''}</p>
          {workflow.items?.length > 1 && <ul className="mt-2 space-y-1">{workflow.items.map((item, index) => <li key={`${item.materialId}-${index}`}>{item.materialName || item.materialId} · {item.quantity} {item.unit}</li>)}</ul>}
          <p className="mt-1">Validation: <strong className={result === 'Passed' ? 'text-emerald-300' : result === 'Failed' ? 'text-rose-300' : 'text-amber-300'}>{result}</strong>{workflow.qualitySafetyStatus ? ` · Safety: ${workflow.qualitySafetyStatus}` : ''}</p>
          <p className="mt-1 text-xs text-slate-400">{workflow.objective}</p>
          {reason && <p className="mt-2 text-amber-200">{reason}</p>}
          {quality ? <Link className="mt-2 inline-block text-cyan-300 underline" to={`/quality/ai-validation?workflowId=${encodeURIComponent(id)}`}>Inspect validation</Link> : workflow.purchaseOrderId ?
            <Link className="mt-2 inline-block text-cyan-300 underline" to={`/purchase-orders/${workflow.purchaseOrderId}`}>Review purchase order</Link> : <p className="mt-2 text-xs text-slate-400">No purchase order yet. {workflow.status === 'Failed' ? 'Resolve the failure before starting a new request.' : 'Waiting for a validated draft.'}</p>}
        </article>;
      })}</div>}
    {quality && <Link to="/quality/ai-validation" className="mt-4 inline-block text-sm text-cyan-300 underline">View full validation history</Link>}
  </section>;
}

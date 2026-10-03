import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import AppLayout from '../../components/Layout/AppLayout';
import agentWorkflowService from '../../services/agentWorkflowService';
import { parseErrorMessage } from '../../utils/errorHandler';

export default function AgentWorkflowMonitor() {
  const [workflows, setWorkflows] = useState([]);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(true);
  const [retrying, setRetrying] = useState(null);
  const [filter, setFilter] = useState('All');
  useEffect(() => {
    let cancelled = false;
    async function load() {
      try { const data = await agentWorkflowService.getWorkflows(); if (!cancelled) { setWorkflows(data); setError(''); } }
      catch (err) { if (!cancelled) setError(parseErrorMessage(err, 'Could not load workflow status.')); }
      finally { if (!cancelled) setLoading(false); }
    }
    void load(); const interval = setInterval(load, 10000);
    return () => { cancelled = true; clearInterval(interval); };
  }, []);
  async function retry(id) {
    setRetrying(id);
    try { await agentWorkflowService.retry(id); setWorkflows(await agentWorkflowService.getWorkflows()); }
    catch (err) { setError(parseErrorMessage(err, 'Could not retry workflow.')); }
    finally { setRetrying(null); }
  }
  return <AppLayout title="Agent workflows" subtitle="Recorded execution stages and current decisions">
    <div className="flex gap-4 items-center">
      <Link to="/worker/replenishment" className="text-cyan-400">Request replenishment</Link>
      <label className="text-slate-300">Status <select value={filter} onChange={e => setFilter(e.target.value)} className="bg-slate-800 p-2 rounded">
        {['All', 'Running', 'WaitingForApproval', 'Failed', 'Completed'].map(status => <option key={status}>{status}</option>)}
      </select></label>
    </div>
    {error && <p role="alert" className="text-red-400">{error}</p>}
    {loading && <p className="text-slate-300">Loading workflow records…</p>}
    {!loading && !workflows.length && <p className="text-slate-400">No workflow records yet.</p>}
    {workflows.filter(w => filter === 'All' || w.status === filter).map(w => <article key={w.workflowId} className="p-5 rounded-2xl bg-slate-900/70 border border-white/10 space-y-3">
      <div className="flex justify-between gap-3 text-white"><strong>{w.workflowId}</strong><span>{w.workflowType} · {w.status}</span></div>
      <p className="text-slate-300">{w.objective}</p>
      <p className="text-slate-400">Current stage: {w.currentAgent || 'Queued'} · Approval: {w.approvalStatus}</p>
      {w.status === 'WaitingForApproval' && w.workflowType === 'Procurement' && <p className="text-amber-300">{w.purchaseOrderId ? 'Supply Chain Manager reviews the linked purchase order.' : 'Resolve the findings or add a confirmed supplier quote before a purchase order can be created.'}</p>}
      <ul className="text-sm text-slate-300 space-y-1">{(w.details?.completed_steps || []).map((step, i) => <li key={i}>{step}</li>)}</ul>
      {(w.details?.errors || []).map((message, i) => <p key={i} className="text-red-400">{message}</p>)}
      {w.finalOutcome && <p className="text-slate-200">{w.finalOutcome}</p>}
      {w.purchaseOrderId && <Link className="text-cyan-400" to={`/purchase-orders/${w.purchaseOrderId}`}>View purchase order</Link>}
      {w.workflowType === 'Procurement' && (w.status === 'Failed' || (w.currentAgent === 'Supplier Review' && !w.purchaseOrderId)) && <button disabled={retrying === w.workflowId} onClick={() => retry(w.workflowId)} className="bg-cyan-700 p-2 rounded text-white disabled:opacity-50">{retrying === w.workflowId ? 'Queuing…' : 'Retry analysis'}</button>}
    </article>)}
  </AppLayout>;
}

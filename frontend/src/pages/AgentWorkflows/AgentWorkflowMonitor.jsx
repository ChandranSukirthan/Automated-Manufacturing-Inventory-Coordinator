import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import AppLayout from '../../components/Layout/AppLayout';
import agentWorkflowService from '../../services/agentWorkflowService';
import { parseErrorMessage } from '../../utils/errorHandler';
import { Activity, ArrowUpRight, Bot, CheckCircle2, ChevronDown, CircleAlert, Clock3, FileText, Layers3, RotateCcw, ShieldCheck, Sparkles } from 'lucide-react';
import './workflow-monitor.css';

const statusLabels = { WaitingForApproval: 'Awaiting approval', Running: 'Running', Failed: 'Failed', Completed: 'Completed' };

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
    <div className="workflow-monitor">
      <section className="wm-hero">
        <div className="wm-hero-copy">
          <span className="wm-eyebrow"><Sparkles size={14} aria-hidden="true" /> AI OPERATIONS</span>
          <h2>Workflow command center</h2>
          <p>Follow each request from agent analysis to validation and approval. See what has finished and what needs attention.</p>
        </div>
        <Link to="/worker/replenishment" className="wm-button wm-button-primary">Request replenishment <ArrowUpRight size={17} aria-hidden="true" /></Link>
      </section>
      <div className="wm-summary" aria-label="Workflow summary">
        {[['Recorded', workflows.length, Layers3, 'neutral'], ['Running', workflows.filter(w => w.status === 'Running').length, Activity, 'cyan'], ['Awaiting approval', workflows.filter(w => w.status === 'WaitingForApproval').length, Clock3, 'amber'], ['Needs attention', workflows.filter(w => w.status === 'Failed').length, CircleAlert, 'rose']].map(([label, count, Icon, tone]) => <div className={`wm-stat wm-tone-${tone}`} key={label}><Icon size={19} aria-hidden="true" /><div><span>{label}</span><strong>{loading ? '—' : count}</strong></div></div>)}
      </div>
      <div className="wm-toolbar">
        <div><h3>Workflow activity</h3><p>Execution records and the latest decisions</p></div>
        <label className="wm-filter">Status <select value={filter} onChange={e => setFilter(e.target.value)}>
          {['All', 'Running', 'WaitingForApproval', 'Failed', 'Completed'].map(status => <option key={status} value={status}>{status === 'All' ? 'All statuses' : statusLabels[status]}</option>)}
        </select></label>
      </div>
      {error && <p role="alert" className="wm-notice wm-notice-error"><CircleAlert size={18} aria-hidden="true" />{error}</p>}
      {loading && <div className="wm-empty" role="status"><Bot size={28} aria-hidden="true" /><h3>Loading workflow records…</h3><p>Gathering the latest agent activity.</p></div>}
      {!loading && !workflows.filter(w => filter === 'All' || w.status === filter).length && <div className="wm-empty"><Layers3 size={28} aria-hidden="true" /><h3>{workflows.length ? 'No matching workflows' : 'No workflow records yet'}</h3><p>{workflows.length ? 'Choose another status to view more activity.' : 'Your replenishment requests will appear here once analysis begins.'}</p></div>}
      <div className="wm-records">
      {workflows.filter(w => filter === 'All' || w.status === filter).map(w => <article key={w.workflowId} className="wm-card">
        <details className="wm-disclosure">
        <summary className="wm-card-summary">
        <header className="wm-card-header">
          <div className="wm-identity"><div className="wm-agent-icon"><Bot size={22} aria-hidden="true" /></div><div><span className="wm-eyebrow">{w.workflowType} workflow</span><h3>{w.workflowId}</h3></div></div>
          <span className={`wm-status wm-status-${w.status}`}><span aria-hidden="true" />{statusLabels[w.status] || w.status}</span>
        </header>
        <p className="wm-objective">{w.objective}</p>
        <div className="wm-context"><div><Activity size={16} aria-hidden="true" /><span>Current stage<strong>{w.currentAgent || 'Queued'}</strong></span></div><div><ShieldCheck size={16} aria-hidden="true" /><span>Approval status<strong>{w.approvalStatus || 'Not yet recorded'}</strong></span></div></div>
        <span className="wm-expand-hint"><span className="wm-show-details">View full details</span><span className="wm-hide-details">Hide details</span><ChevronDown size={16} aria-hidden="true" /></span>
        </summary>
        <div className="wm-expanded-details">
        {w.status === 'WaitingForApproval' && w.workflowType === 'Procurement' && <p className="wm-notice wm-notice-wait"><Clock3 size={18} aria-hidden="true" />{w.purchaseOrderId ? 'Supply Chain Manager reviews the linked purchase order.' : 'Resolve the findings or add a confirmed supplier quote before a purchase order can be created.'}</p>}
        {!!w.details?.completed_steps?.length && <section className="wm-execution"><h4>Completed steps</h4><ul>{(w.details?.completed_steps || []).map((step, i) => <li key={i}><CheckCircle2 size={17} aria-hidden="true" /><span>{step}</span></li>)}</ul></section>}
        {(w.details?.errors || []).map((message, i) => <p key={i} className="wm-notice wm-notice-error"><CircleAlert size={18} aria-hidden="true" /><span>{message}</span></p>)}
        {w.finalOutcome && <section className="wm-outcome"><h4>Outcome</h4><p>{w.finalOutcome}</p></section>}
        {(w.purchaseOrderId || (w.workflowType === 'Procurement' && (w.status === 'Failed' || (w.currentAgent === 'Supplier Review' && !w.purchaseOrderId)))) && <footer className="wm-card-actions">
          {w.purchaseOrderId && <Link className="wm-button wm-button-secondary" to={`/purchase-orders/${w.purchaseOrderId}`}><FileText size={16} aria-hidden="true" />View purchase order <ArrowUpRight size={16} aria-hidden="true" /></Link>}
          {w.workflowType === 'Procurement' && (w.status === 'Failed' || (w.currentAgent === 'Supplier Review' && !w.purchaseOrderId)) && <button disabled={retrying === w.workflowId} onClick={() => retry(w.workflowId)} className="wm-button wm-button-secondary"><RotateCcw size={16} aria-hidden="true" />{retrying === w.workflowId ? 'Queuing…' : 'Retry analysis'}</button>}
        </footer>}
        </div>
        </details>
      </article>)}
      </div>
    </div>
  </AppLayout>;
}

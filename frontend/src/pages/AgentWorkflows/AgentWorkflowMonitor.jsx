import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import {
  Activity,
  Sparkles,
  CheckCircle2,
  Clock,
  AlertTriangle,
  ArrowRight,
  ShieldCheck,
  RefreshCw,
  ExternalLink,
  ChevronRight,
  Check,
  Loader2,
  Play,
  Cpu,
  Layers,
  FileCheck
} from 'lucide-react';
import AppLayout from '../../components/Layout/AppLayout';
import StatusBadge from '../../components/Common/StatusBadge';
import agentWorkflowService from '../../services/agentWorkflowService';
import { parseErrorMessage } from '../../utils/errorHandler';

export default function AgentWorkflowMonitor() {
  const [workflows, setWorkflows] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [filter, setFilter] = useState('All');
  const [triggerLoading, setTriggerLoading] = useState(false);
  const [triggerNotice, setTriggerNotice] = useState('');

  const loadWorkflows = async () => {
    setLoading(true);
    setError('');
    try {
      const data = await agentWorkflowService.getWorkflows();
      setWorkflows(data || []);
    } catch (err) {
      setError(parseErrorMessage(err, 'Failed to load agent workflow states.'));
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadWorkflows();
    const interval = setInterval(loadWorkflows, 10000);
    return () => clearInterval(interval);
  }, []);

  const handleManualTrigger = async () => {
    setTriggerLoading(true);
    setTriggerNotice('');
    try {
      const result = await agentWorkflowService.triggerEvaluation(1);
      setTriggerNotice('AI agent evaluation cycle triggered successfully. Pipeline state updated.');
      await loadWorkflows();
    } catch (err) {
      setError(parseErrorMessage(err, 'Agent evaluation dispatch failed.'));
    } finally {
      setTriggerLoading(false);
    }
  };

  // Metrics
  const totalWfs = workflows.length;
  const waitingApprovalWfs = workflows.filter(
    (w) => w.status === 'WaitingForApproval' || w.approvalStatus === 'PendingApproval'
  );
  const completedWfs = workflows.filter((w) => w.status === 'Completed');
  const activeWfs = workflows.filter((w) => w.status === 'Active');

  const filteredList = workflows.filter((w) => {
    if (filter === 'Waiting') return w.status === 'WaitingForApproval' || w.approvalStatus === 'PendingApproval';
    if (filter === 'Completed') return w.status === 'Completed';
    if (filter === 'Active') return w.status === 'Active';
    return true;
  });

  const pipelineStages = [
    { name: 'PLANNER', label: 'Planner Agent' },
    { name: 'DATA EXTRACTION', label: 'Data Extraction' },
    { name: 'PURCHASING', label: 'Purchasing Logic' },
    { name: 'VALIDATION', label: 'Validation Agent' },
    { name: 'WAITING FOR APPROVAL', label: 'Manager Gate' }
  ];

  return (
    <AppLayout
      title="Agent Workflow Monitor"
      subtitle="Supervise autonomous LangGraph multi-agent procurement pipelines with human-in-the-loop validation gates."
      actionButton={
        <div className="flex items-center gap-2">
          <button
            onClick={loadWorkflows}
            className="flex items-center gap-1.5 px-3 py-2 bg-slate-900 border border-slate-700 hover:bg-slate-800 text-slate-300 rounded-xl text-xs font-semibold transition-all"
          >
            <RefreshCw className="w-3.5 h-3.5" />
            <span>Refresh</span>
          </button>
          <button
            onClick={handleManualTrigger}
            disabled={triggerLoading}
            className="flex items-center gap-1.5 px-3.5 py-2 bg-gradient-to-r from-purple-600 to-indigo-600 hover:from-purple-500 text-white font-bold rounded-xl text-xs shadow-lg shadow-purple-600/20 transition-all disabled:opacity-50"
          >
            {triggerLoading ? <Loader2 className="w-3.5 h-3.5 animate-spin" /> : <Play className="w-3.5 h-3.5" />}
            <span>Simulate Low Stock AI Trigger</span>
          </button>
        </div>
      }
    >
      <div className="space-y-6">
        {/* Notice alert */}
        {triggerNotice && (
          <div className="p-4 rounded-xl bg-purple-500/10 border border-purple-500/30 text-purple-300 text-xs flex items-center justify-between">
            <div className="flex items-center gap-2">
              <Sparkles className="w-4 h-4 text-purple-400" />
              <span>{triggerNotice}</span>
            </div>
            <button onClick={() => setTriggerNotice('')} className="text-slate-500 hover:text-white">
              ✕
            </button>
          </div>
        )}

        {error && (
          <div className="p-4 rounded-xl bg-rose-500/10 border border-rose-500/30 text-rose-400 text-xs flex items-center gap-2">
            <AlertTriangle className="w-4 h-4 shrink-0" />
            <span>{error}</span>
          </div>
        )}

        {/* Top Metric Cards */}
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
          <div className="p-5 rounded-2xl bg-slate-900/80 border border-slate-800 flex items-center justify-between">
            <div>
              <p className="text-xs font-semibold text-slate-400 uppercase tracking-wider">Total Workflows</p>
              <h3 className="text-2xl font-bold text-white mt-1">{totalWfs}</h3>
              <p className="text-[11px] text-slate-500 mt-0.5">End-to-end agentic runs</p>
            </div>
            <div className="w-11 h-11 rounded-xl bg-brand-500/10 border border-brand-500/20 flex items-center justify-center text-brand-400">
              <Cpu className="w-5 h-5" />
            </div>
          </div>

          <div className="p-5 rounded-2xl bg-slate-900/80 border border-slate-800 flex items-center justify-between">
            <div>
              <p className="text-xs font-semibold text-amber-400 uppercase tracking-wider">Paused for Approval</p>
              <h3 className="text-2xl font-bold text-amber-400 mt-1">{waitingApprovalWfs.length}</h3>
              <p className="text-[11px] text-slate-500 mt-0.5">Awaiting manager decision</p>
            </div>
            <div className="w-11 h-11 rounded-xl bg-amber-500/10 border border-amber-500/20 flex items-center justify-center text-amber-400">
              <Clock className="w-5 h-5" />
            </div>
          </div>

          <div className="p-5 rounded-2xl bg-slate-900/80 border border-slate-800 flex items-center justify-between">
            <div>
              <p className="text-xs font-semibold text-emerald-400 uppercase tracking-wider">Completed &amp; Dispatched</p>
              <h3 className="text-2xl font-bold text-emerald-400 mt-1">{completedWfs.length}</h3>
              <p className="text-[11px] text-slate-500 mt-0.5">Executed orders</p>
            </div>
            <div className="w-11 h-11 rounded-xl bg-emerald-500/10 border border-emerald-500/20 flex items-center justify-center text-emerald-400">
              <CheckCircle2 className="w-5 h-5" />
            </div>
          </div>

          <div className="p-5 rounded-2xl bg-slate-900/80 border border-slate-800 flex items-center justify-between">
            <div>
              <p className="text-xs font-semibold text-indigo-400 uppercase tracking-wider">Active Executions</p>
              <h3 className="text-2xl font-bold text-indigo-400 mt-1">{activeWfs.length}</h3>
              <p className="text-[11px] text-slate-500 mt-0.5">Evaluating inventory telemetry</p>
            </div>
            <div className="w-11 h-11 rounded-xl bg-indigo-500/10 border border-indigo-500/20 flex items-center justify-center text-indigo-400">
              <Activity className="w-5 h-5" />
            </div>
          </div>
        </div>

        {/* Global Agentic Pipeline Architecture Visualizer */}
        <div className="p-6 rounded-2xl bg-gradient-to-r from-slate-950 via-slate-900 to-indigo-950/40 border border-slate-800 space-y-4">
          <div className="flex items-center justify-between">
            <h3 className="text-sm font-bold text-white flex items-center gap-2">
              <Layers className="w-4 h-4 text-purple-400" />
              <span>Standard Purchasing Agent Execution Pipeline</span>
            </h3>
            <span className="text-[11px] px-2.5 py-1 rounded-full bg-purple-500/10 border border-purple-500/30 text-purple-300 font-medium">
              LangGraph StateGraph
            </span>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-5 gap-2 pt-2">
            {pipelineStages.map((stage, idx) => (
              <div
                key={stage.name}
                className="relative p-3 rounded-xl bg-slate-900/90 border border-slate-800 flex flex-col items-center text-center gap-1.5"
              >
                <div className="w-7 h-7 rounded-full bg-purple-500/20 border border-purple-500/40 text-purple-300 font-mono text-xs flex items-center justify-center font-bold">
                  {idx + 1}
                </div>
                <span className="text-xs font-bold text-white tracking-tight">{stage.name}</span>
                <span className="text-[10px] text-slate-400">{stage.label}</span>
                {idx < pipelineStages.length - 1 && (
                  <div className="hidden sm:block absolute -right-2.5 top-1/2 -translate-y-1/2 z-10 text-slate-600">
                    <ChevronRight className="w-4 h-4" />
                  </div>
                )}
              </div>
            ))}
          </div>
        </div>

        {/* Filter Tabs */}
        <div className="flex items-center gap-2 border-b border-slate-800 pb-3">
          {[
            { key: 'All', label: `All Pipelines (${totalWfs})` },
            { key: 'Waiting', label: `Waiting for Approval (${waitingApprovalWfs.length})` },
            { key: 'Active', label: `Active (${activeWfs.length})` },
            { key: 'Completed', label: `Completed (${completedWfs.length})` }
          ].map((tab) => (
            <button
              key={tab.key}
              onClick={() => setFilter(tab.key)}
              className={`px-3.5 py-1.5 rounded-xl text-xs font-semibold transition-all ${
                filter === tab.key
                  ? 'bg-brand-600 text-white shadow-md shadow-brand-600/20'
                  : 'bg-slate-900 text-slate-400 hover:text-white'
              }`}
            >
              {tab.label}
            </button>
          ))}
        </div>

        {/* Workflows List */}
        {loading ? (
          <div className="p-16 flex flex-col items-center justify-center gap-3">
            <Loader2 className="w-8 h-8 text-brand-500 animate-spin" />
            <p className="text-xs text-slate-400">Querying live agentic stategraph registry...</p>
          </div>
        ) : filteredList.length === 0 ? (
          <div className="p-16 rounded-2xl bg-slate-900/40 border border-slate-800 flex flex-col items-center justify-center text-center gap-3">
            <CheckCircle2 className="w-10 h-10 text-slate-600" />
            <h4 className="text-sm font-semibold text-white">No workflows matching filter</h4>
            <p className="text-xs text-slate-500 max-w-sm">
              All agent pipelines are either in completed states or no active triggers were detected.
            </p>
          </div>
        ) : (
          <div className="space-y-4">
            {filteredList.map((wf) => {
              const isWaiting = wf.status === 'WaitingForApproval';
              const isCompleted = wf.status === 'Completed';
              const isRejected = wf.status === 'Rejected';

              return (
                <div
                  key={wf.workflowId}
                  className="p-5 rounded-2xl bg-slate-900/80 border border-slate-800 hover:border-slate-700 transition-all space-y-4"
                >
                  {/* Card Header */}
                  <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
                    <div className="flex items-center gap-3">
                      <div className="w-10 h-10 rounded-xl bg-purple-500/10 border border-purple-500/30 flex items-center justify-center text-purple-400 font-mono font-bold text-xs">
                        {wf.workflowId.slice(-3)}
                      </div>
                      <div>
                        <div className="flex items-center gap-2">
                          <span className="text-sm font-bold text-white font-mono">{wf.workflowId}</span>
                          <span
                            className={`px-2 py-0.5 rounded-md text-[10px] font-bold ${
                              isWaiting
                                ? 'bg-amber-500/10 text-amber-400 border border-amber-500/30'
                                : isCompleted
                                ? 'bg-emerald-500/10 text-emerald-400 border border-emerald-500/30'
                                : isRejected
                                ? 'bg-rose-500/10 text-rose-400 border border-rose-500/30'
                                : 'bg-indigo-500/10 text-indigo-400 border border-indigo-500/30'
                            }`}
                          >
                            {wf.status}
                          </span>
                        </div>
                        <p className="text-xs text-slate-400 mt-0.5">{wf.objective}</p>
                      </div>
                    </div>

                    <div className="flex items-center gap-2">
                      {isWaiting && (
                        <Link
                          to="/purchase-orders/approvals"
                          className="flex items-center gap-1.5 px-3 py-1.5 bg-amber-500/15 border border-amber-500/30 hover:bg-amber-500/25 text-amber-300 rounded-xl text-xs font-bold transition-all"
                        >
                          <ShieldCheck className="w-3.5 h-3.5" />
                          <span>Review &amp; Authorize</span>
                        </Link>
                      )}
                      <Link
                        to={`/purchase-orders/${wf.purchaseOrderId}`}
                        className="flex items-center gap-1 px-3 py-1.5 bg-slate-800 hover:bg-slate-700 text-slate-300 rounded-xl text-xs font-medium transition-all"
                      >
                        <span>View PO</span>
                        <ExternalLink className="w-3 h-3" />
                      </Link>
                    </div>
                  </div>

                  {/* Stage Stepper for this specific workflow */}
                  <div className="p-3.5 rounded-xl bg-slate-950/70 border border-slate-800/80">
                    <div className="grid grid-cols-5 gap-2">
                      {pipelineStages.map((stage, idx) => {
                        const stepNum = idx + 1;
                        const isDone = wf.currentStepIndex > stepNum || isCompleted;
                        const isCurrent = wf.currentStepIndex === stepNum && !isCompleted;

                        return (
                          <div
                            key={stage.name}
                            className={`p-2 rounded-lg text-center flex flex-col items-center gap-1 transition-all ${
                              isDone
                                ? 'bg-emerald-500/10 border border-emerald-500/20 text-emerald-400'
                                : isCurrent
                                ? 'bg-amber-500/15 border border-amber-500/30 text-amber-300 animate-pulse'
                                : 'bg-slate-900/40 text-slate-600 border border-slate-800/40'
                            }`}
                          >
                            <span className="text-[9px] font-bold font-mono">
                              {isDone ? '✓' : isCurrent ? '⏳' : `0${stepNum}`}
                            </span>
                            <span className="text-[10px] font-bold tracking-tight">{stage.name}</span>
                          </div>
                        );
                      })}
                    </div>
                  </div>

                  {/* Execution Meta Grid */}
                  <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 text-xs pt-1 border-t border-slate-800/60 text-slate-400">
                    <div>
                      <span className="text-[10px] text-slate-500 uppercase tracking-wider block">Current Agent</span>
                      <span className="font-semibold text-white">{wf.currentAgent}</span>
                    </div>
                    <div>
                      <span className="text-[10px] text-slate-500 uppercase tracking-wider block">Current Step</span>
                      <span className="font-semibold text-slate-300">{wf.currentStep}</span>
                    </div>
                    <div>
                      <span className="text-[10px] text-slate-500 uppercase tracking-wider block">Started At</span>
                      <span className="font-semibold text-slate-300">
                        {new Date(wf.startedAt).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                      </span>
                    </div>
                    <div>
                      <span className="text-[10px] text-slate-500 uppercase tracking-wider block">Outcome</span>
                      <span className="font-semibold text-brand-300 truncate block">{wf.finalOutcome}</span>
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>
    </AppLayout>
  );
}


import RoleLayout from '../../components/Layout/RoleLayout';
import React, { useEffect, useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import {
  AlertCircle,
  ArrowLeft,
  Bot,
  CheckCircle2,
  ClipboardList,
  LoaderCircle,
  PackagePlus,
  RefreshCw,
  ShieldCheck,
} from 'lucide-react';
import inventoryService from '../../services/inventoryService';
import { parseErrorMessage } from '../../utils/errorHandler';

const ACTIVE_ALERT_STATUSES = new Set(['pending', 'processing', 'acknowledged']);

const isActionable = (level) => {
  const status = String(level.status || '').toUpperCase();
  return status === 'LOW' || status === 'CRITICAL'
    || Number(level.currentStock) <= Number(level.minimumStock);
};

const workflowValue = (workflow, camelCase, snakeCase, fallback = 'Not available') =>
  workflow?.[camelCase] ?? workflow?.[snakeCase] ?? fallback;

export default function ReplenishmentRequestPage() {
  const [stockLevels, setStockLevels] = useState([]);
  const [alerts, setAlerts] = useState([]);
  const [selectedSku, setSelectedSku] = useState('');
  const [quantity, setQuantity] = useState('2000');
  const [search, setSearch] = useState('');
  const [loading, setLoading] = useState(true);
  const [submitting, setSubmitting] = useState(false);
  const [cancellingAlert, setCancellingAlert] = useState(false);
  const [loadError, setLoadError] = useState('');
  const [formError, setFormError] = useState('');
  const [result, setResult] = useState(null);

  const loadWorkspace = async () => {
    setLoading(true);
    setLoadError('');
    try {
      const [levels, activeAlerts] = await Promise.all([
        inventoryService.getStockLevels(),
        inventoryService.getAlerts(),
      ]);
      const nextLevels = Array.isArray(levels) ? levels : [];
      setStockLevels(nextLevels);
      setAlerts(Array.isArray(activeAlerts) ? activeAlerts : []);
      setSelectedSku((currentSku) => {
        if (nextLevels.some((level) => level.skuCode === currentSku)) return currentSku;
        return nextLevels.find(isActionable)?.skuCode || nextLevels[0]?.skuCode || '';
      });
    } catch {
      setLoadError('Unable to load stock levels. Check that the API is running and try again.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    const initialLoad = setTimeout(loadWorkspace, 0);
    return () => clearTimeout(initialLoad);
  }, []);

  const visibleLevels = useMemo(() => {
    const query = search.trim().toLowerCase();
    if (!query) return stockLevels;
    return stockLevels.filter((level) =>
      [level.skuCode, level.materialName, level.status]
        .some((value) => String(value || '').toLowerCase().includes(query))
    );
  }, [search, stockLevels]);

  const selectedLevel = stockLevels.find((level) => level.skuCode === selectedSku);
  const activeAlert = selectedSku && alerts.find((alert) =>
    String(alert.sku || '').toLowerCase() === selectedSku.toLowerCase()
      && ACTIVE_ALERT_STATUSES.has(String(alert.status || '').toLowerCase())
  );

  const handleDismissAlert = async () => {
    if (!activeAlert?.id) return;
    const confirmed = window.confirm(
      `Dismiss Alert #${activeAlert.id} for ${activeAlert.sku} (${activeAlert.quantityRequested} units)?\n\nThis will clear the pending request so you can adjust the quantity and submit a new replenishment request.`
    );
    if (!confirmed) return;

    setCancellingAlert(true);
    setFormError('');
    try {
      if (typeof inventoryService.updateAlertStatus === 'function') {
        await inventoryService.updateAlertStatus(activeAlert.id, 'Dismissed');
      }
      setResult(null);
      await loadWorkspace();
    } catch (error) {
      setFormError(parseErrorMessage(error, 'Unable to dismiss the active alert.'));
    } finally {
      setCancellingAlert(false);
    }
  };

  const handleSubmit = async (event) => {
    event.preventDefault();
    setFormError('');
    setResult(null);

    const isExisting = Boolean(activeAlert);
    const requestedQuantity = Number(activeAlert?.quantityRequested ?? quantity);
    if (!selectedLevel) {
      setFormError('Choose a material before submitting a replenishment request.');
      return;
    }
    if (!Number.isFinite(requestedQuantity) || requestedQuantity <= 0) {
      setFormError('Requested quantity must be greater than zero.');
      return;
    }

    setSubmitting(true);
    try {
      const alert = activeAlert || await inventoryService.createAlert({
        sku: selectedLevel.skuCode,
        packagingType: 'Standard Roll',
        quantityRequested: requestedQuantity,
      });
      let workflow = null;
      let workflowError = '';
      try {
        workflow = await inventoryService.triggerWorkflow(
          `Floor Worker Stock Replenishment: Reorder ${requestedQuantity} units of ${selectedLevel.skuCode}`,
          selectedLevel.skuCode,
          requestedQuantity,
          alert.id ? `WF-WORKER-ALERT-${alert.id}` : undefined,
        );
      } catch (error) {
        workflowError = `The request was saved, but the AI workflow could not start: ${parseErrorMessage(error)} Retry using the button above; the saved request will be reused.`;
      }
      setResult({ alert, workflow, workflowError, isExisting });
      await loadWorkspace();
    } catch (error) {
      setFormError(parseErrorMessage(error, 'Unable to submit the replenishment request.'));
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <RoleLayout title="Material Replenishment" subtitle="Requests and workflow status">
    <main className="worker-replenishment px-4 py-6 text-slate-100 sm:px-6">
      <div className="mx-auto max-w-7xl space-y-6">
        <Link
          to="/dashboard/worker"
          className="inline-flex items-center gap-2 text-sm font-medium text-slate-400 transition hover:text-cyan-300"
        >
          <ArrowLeft className="h-4 w-4" />
          Back to Floor Worker dashboard
        </Link>

        <section className="rounded-2xl border border-cyan-500/20 bg-gradient-to-br from-slate-900 to-slate-950 p-6 shadow-xl shadow-cyan-950/20">
          <div className="flex flex-col justify-between gap-4 sm:flex-row sm:items-start">
            <div className="flex gap-4">
              <div className="flex h-12 w-12 shrink-0 items-center justify-center rounded-xl border border-cyan-500/30 bg-cyan-500/10 text-cyan-300">
                <PackagePlus className="h-6 w-6" />
              </div>
              <div>
                <p className="text-xs font-bold uppercase tracking-wider text-cyan-400">Floor Worker workspace</p>
                <h1 className="mt-1 text-2xl font-bold text-white">Replenishment request and status</h1>
                <p className="mt-2 max-w-2xl text-sm leading-6 text-slate-400">
                  Submit a validated material request through the shared ASP.NET Core API and follow its Agentic AI workflow.
                </p>
              </div>
            </div>
            <button
              type="button"
              onClick={loadWorkspace}
              disabled={loading || submitting}
              className="inline-flex items-center justify-center gap-2 rounded-xl border border-slate-700 bg-slate-800 px-4 py-2.5 text-sm font-semibold text-slate-200 transition hover:border-cyan-500/50 hover:text-cyan-200 disabled:cursor-not-allowed disabled:opacity-50"
            >
              <RefreshCw className={`h-4 w-4 ${loading ? 'animate-spin' : ''}`} />
              Refresh
            </button>
          </div>
        </section>

        {loadError && (
          <section role="alert" className="flex flex-wrap items-center justify-between gap-3 rounded-xl border border-rose-500/30 bg-rose-500/10 p-4 text-sm text-rose-200">
            <span className="flex items-center gap-2"><AlertCircle className="h-5 w-5" />{loadError}</span>
            <button type="button" onClick={loadWorkspace} className="rounded-lg border border-rose-400/40 px-3 py-1.5 font-semibold hover:bg-rose-500/10">
              Try again
            </button>
          </section>
        )}

        {loading ? (
          <section className="flex min-h-64 items-center justify-center rounded-2xl border border-slate-800 bg-slate-900/60" aria-live="polite">
            <LoaderCircle className="h-7 w-7 animate-spin text-cyan-400" />
            <span className="ml-3 text-sm text-slate-400">Loading replenishment workspace…</span>
          </section>
        ) : !loadError && (
          <div className="grid gap-6 lg:grid-cols-[1.2fr_0.8fr]">
            <section className="worker-panel min-w-0 rounded-2xl border border-slate-800 bg-slate-900/60 p-5 sm:p-6">
              <div className="mb-5 flex items-start gap-3">
                <div className="rounded-xl bg-cyan-500/10 p-2.5 text-cyan-300"><ClipboardList className="h-5 w-5" /></div>
                <div>
                  <h2 className="font-bold text-white">Create replenishment request</h2>
                  <p className="mt-1 text-sm text-slate-400">Only one active request is allowed per material.</p>
                </div>
              </div>

              <form onSubmit={handleSubmit} className="space-y-5" noValidate>
                <div>
                  <label htmlFor="material-search" className="mb-1.5 block text-sm font-semibold text-slate-300">Find material</label>
                  <input
                    id="material-search"
                    value={search}
                    onChange={(event) => setSearch(event.target.value)}
                    placeholder="Search by SKU, material, or status"
                    className="w-full rounded-xl border border-slate-700 bg-slate-950 px-4 py-2.5 text-sm text-white placeholder:text-slate-600 focus:border-cyan-400 focus:outline-none"
                  />
                </div>
                <div>
                  <label htmlFor="material" className="mb-1.5 block text-sm font-semibold text-slate-300">Material</label>
                  <select
                    id="material"
                    value={selectedSku}
                    onChange={(event) => setSelectedSku(event.target.value)}
                    className="w-full rounded-xl border border-slate-700 bg-slate-950 px-4 py-2.5 text-sm text-white focus:border-cyan-400 focus:outline-none"
                  >
                    {visibleLevels.length === 0 ? (
                      <option value="">No matching materials</option>
                    ) : visibleLevels.map((level) => (
                      <option key={level.skuCode} value={level.skuCode}>
                        {level.skuCode} — {level.materialName} ({level.status || 'UNKNOWN'})
                      </option>
                    ))}
                  </select>
                </div>
                {activeAlert && (
                  <div className="rounded-xl border border-amber-500/30 bg-amber-500/10 p-4 text-amber-200">
                    <div className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
                      <div className="flex items-start gap-2.5">
                        <AlertCircle className="mt-0.5 h-5 w-5 shrink-0 text-amber-400" />
                        <div>
                          <p className="font-semibold text-amber-100">
                            Active Request in Progress (Alert #{activeAlert.id})
                          </p>
                          <p className="mt-1 text-xs leading-relaxed text-amber-200/90">
                            A request for <strong className="text-white">{activeAlert.quantityRequested} units</strong> is already <span className="font-semibold uppercase text-amber-300">{activeAlert.status}</span>.
                            Quantity is locked to prevent duplicate purchase orders. Clicking below will reconnect to or check the active workflow for this alert without creating a duplicate request.
                          </p>
                        </div>
                      </div>
                      <button
                        type="button"
                        onClick={handleDismissAlert}
                        disabled={cancellingAlert || submitting}
                        className="self-start shrink-0 rounded-lg border border-rose-500/40 bg-rose-500/20 px-3 py-1.5 text-xs font-semibold text-rose-200 transition hover:bg-rose-500/30 disabled:cursor-not-allowed disabled:opacity-50"
                      >
                        {cancellingAlert ? 'Dismissing…' : 'Dismiss / Clear to edit'}
                      </button>
                    </div>
                  </div>
                )}
                <div>
                  <div className="mb-1.5 flex items-center justify-between">
                    <label htmlFor="quantity" className="block text-sm font-semibold text-slate-300">Requested quantity (material units)</label>
                    {activeAlert && (
                      <span className="text-xs font-medium text-amber-400">Locked to Alert #{activeAlert.id}</span>
                    )}
                  </div>
                  <input
                    id="quantity"
                    disabled={Boolean(activeAlert)}
                    type="number"
                    min="1"
                    step="1"
                    inputMode="numeric"
                    value={activeAlert?.quantityRequested ?? quantity}
                    onChange={(event) => setQuantity(event.target.value)}
                    className="w-full rounded-xl border border-slate-700 bg-slate-950 px-4 py-2.5 text-sm text-white focus:border-cyan-400 focus:outline-none disabled:cursor-not-allowed disabled:opacity-75 disabled:bg-slate-900"
                  />
                </div>

                {selectedLevel && (
                  <div className="grid grid-cols-2 gap-3 rounded-xl border border-slate-800 bg-slate-950/70 p-4 text-sm">
                    <div><p className="text-xs text-slate-500">Current stock</p><p className="mt-1 font-bold text-white">{selectedLevel.currentStock} units</p></div>
                    <div><p className="text-xs text-slate-500">Reorder level</p><p className="mt-1 font-bold text-white">{selectedLevel.minimumStock} units</p></div>
                    <div><p className="text-xs text-slate-500">Days remaining</p><p className="mt-1 font-bold text-amber-300">{selectedLevel.daysRemaining ?? 'Unknown'} days</p></div>
                    <div><p className="text-xs text-slate-500">Status</p><p className="mt-1 font-bold text-cyan-300">{selectedLevel.status || 'Unknown'}</p></div>
                  </div>
                )}

                {formError && <p role="alert" className="rounded-lg border border-rose-500/30 bg-rose-500/10 p-3 text-sm text-rose-200">{formError}</p>}
                <div className="space-y-2">
                  <button
                    type="submit"
                    disabled={submitting || cancellingAlert || !selectedSku || visibleLevels.length === 0}
                    className="inline-flex w-full items-center justify-center gap-2 rounded-xl bg-gradient-to-r from-cyan-400 to-blue-500 px-5 py-3 text-sm font-bold text-slate-950 transition hover:from-cyan-300 hover:to-blue-400 disabled:cursor-not-allowed disabled:opacity-50"
                  >
                    {submitting ? <LoaderCircle className="h-4 w-4 animate-spin" /> : <Bot className="h-4 w-4" />}
                    {submitting ? 'Connecting to AI workflow…' : activeAlert ? 'Start or retry AI for saved request' : 'Submit and start AI workflow'}
                  </button>
                  {activeAlert && (
                    <p className="text-center text-xs text-slate-400">
                      Reconnecting to existing workflow session for Alert #{activeAlert.id}. No duplicate request will be created.
                    </p>
                  )}
                </div>
              </form>
            </section>

            <aside className="space-y-4">
              <section className="rounded-2xl border border-slate-800 bg-slate-900/60 p-5">
                <div className="flex items-center gap-2 text-sm font-bold text-white"><ShieldCheck className="h-5 w-5 text-emerald-400" />Request safeguards</div>
                <ul className="mt-4 space-y-3 text-sm leading-5 text-slate-400">
                  <li>Quantities must be positive.</li>
                  <li>Duplicate active material requests are blocked.</li>
                  <li>The client calls only the ASP.NET Core API; it never calls the AI service directly.</li>
                  <li>High-impact recommendations remain subject to authorized approval.</li>
                </ul>
              </section>
              <section className="rounded-2xl border border-slate-800 bg-slate-900/60 p-5">
                <h2 className="text-sm font-bold text-white">Active requests</h2>
                <p className="mt-1 text-sm text-slate-400">{alerts.filter((alert) => ACTIVE_ALERT_STATUSES.has(String(alert.status || '').toLowerCase())).length} request(s) awaiting resolution.</p>
              </section>
            </aside>
          </div>
        )}

        {result && (
          <section aria-live="polite" className="rounded-2xl border border-emerald-500/30 bg-emerald-500/10 p-5">
            <div className="flex items-start gap-3">
              <CheckCircle2 className="mt-0.5 h-6 w-6 shrink-0 text-emerald-400" />
              <div className="min-w-0">
                <h2 className="font-bold text-emerald-100">
                  {result.isExisting
                    ? `Replenishment request saved (Reconnected to Alert #${result.alert.id})`
                    : 'Replenishment request saved'}
                </h2>
                <p className="mt-1 text-sm text-emerald-100/80">
                  {result.isExisting ? (
                    <>
                      Reconnected to existing saved alert for <strong className="text-white">{workflowValue(result.alert, 'sku', 'sku', selectedSku)}</strong> ({workflowValue(result.alert, 'quantityRequested', 'quantity_requested', quantity)} units). No duplicate request was created.
                    </>
                  ) : (
                    <>
                      {workflowValue(result.alert, 'sku', 'sku', selectedSku)} has been recorded for {workflowValue(result.alert, 'quantityRequested', 'quantity_requested', quantity)} units.
                    </>
                  )}
                </p>
                {result.workflow ? (
                  <p className="mt-3 rounded-lg border border-emerald-400/20 bg-slate-950/40 p-3 text-sm text-slate-300">
                    Workflow <strong className="font-mono text-cyan-300">{workflowValue(result.workflow, 'workflowId', 'workflow_id', 'active')}</strong> is {workflowValue(result.workflow, 'status', 'status', 'active')}. Approval: {workflowValue(result.workflow, 'approvalStatus', 'approval_status', 'pending')}.
                  </p>
                ) : <p className="mt-3 text-sm text-amber-200">{result.workflowError}</p>}
              </div>
            </div>
          </section>
        )}
      </div>
    </main>
    </RoleLayout>
  );
}

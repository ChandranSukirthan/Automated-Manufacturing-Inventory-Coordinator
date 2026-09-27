import React, { useEffect, useState } from 'react';
import { useNavigate, useParams, Link } from 'react-router-dom';
import {
  ArrowLeft,
  Edit2,
  ShieldAlert,
  Loader2,
  AlertTriangle,
  Package,
  Layers,
  Calendar,
  User,
  ClipboardList,
  CheckCircle2
} from 'lucide-react';
import defectService from '../../services/defectService';
import quarantineService from '../../services/quarantineService';
import inventoryService from '../../services/inventoryService';
import { parseErrorMessage } from '../../utils/errorHandler';
import PageHeader from '../../components/QA/PageHeader';
import StatusBadge from '../../components/QA/StatusBadge';
import SeverityBadge from '../../components/QA/SeverityBadge';

export default function DefectDetailPage() {
  const navigate = useNavigate();
  const { id } = useParams();
  const [defect, setDefect] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [reason, setReason] = useState('');
  const [quarantining, setQuarantining] = useState(false);
  const [affectedInventory, setAffectedInventory] = useState([]);
  const [skuCode, setSkuCode] = useState('Unavailable');

  useEffect(() => {
    const load = async () => {
      setLoading(true);
      try {
        const [data, quarantineData, rolls, materials] = await Promise.all([
          defectService.getById(id),
          quarantineService.getAll().catch(() => []),
          inventoryService.getRolls().catch(() => []),
          inventoryService.getRawMaterials().catch(() => [])
        ]);
        const savedInventory = data.affectedInventory?.length
          ? data.affectedInventory
          : quarantineData
              .filter((record) => record.defectReportId === id)
              .map((record) => record.inventoryRollId);
        setDefect(data);
        setAffectedInventory(savedInventory);
        const selectedRoll = rolls.find((roll) => savedInventory.includes(roll.id));
        setSkuCode(
          materials.find((material) => material.id === selectedRoll?.rawMaterialId)?.skuCode ||
            data.skuCode ||
            'Unavailable'
        );
      } catch (err) {
        setError(parseErrorMessage(err, 'Unable to load defect.'));
      } finally {
        setLoading(false);
      }
    };

    load();
  }, [id]);

  const handleQuarantine = async (event) => {
    event.preventDefault();
    if (!reason.trim()) {
      setError('A quarantine reason is required.');
      return;
    }

    setQuarantining(true);
    try {
      const quarantines = await defectService.quarantine(defect.id, { reason });
      navigate(`/quality/quarantine/${quarantines[0].id}`);
    } catch (err) {
      setError(parseErrorMessage(err, 'Unable to quarantine inventory.'));
    } finally {
      setQuarantining(false);
    }
  };

  if (loading) {
    return (
      <div className="flex flex-col items-center justify-center min-h-[60vh] text-slate-400 space-y-3">
        <Loader2 className="w-8 h-8 animate-spin text-purple-400" />
        <p className="text-sm font-medium">Loading defect profile...</p>
      </div>
    );
  }

  if (error && !defect) {
    return (
      <div className="p-6 lg:p-8 max-w-4xl mx-auto space-y-6">
        <div className="rounded-2xl border border-rose-500/30 bg-rose-500/10 p-4 text-rose-200 flex items-center gap-3">
          <AlertTriangle className="w-5 h-5 text-rose-400 shrink-0" />
          <span className="text-sm font-medium">{error}</span>
        </div>
        <button
          onClick={() => navigate('/quality/defects')}
          className="px-4 py-2 rounded-xl border border-slate-700 text-slate-300 hover:bg-slate-800"
        >
          Back to Defects
        </button>
      </div>
    );
  }

  if (!defect) return null;

  const invList = defect.affectedInventory?.length ? defect.affectedInventory : affectedInventory;

  return (
    <div className="p-6 lg:p-8 max-w-4xl mx-auto space-y-6">
      {/* Page Header */}
      <PageHeader
        category="Quality Assurance"
        title="Defect Detail"
        subtitle={`Detailed inspection profile for SKU ${skuCode}`}
        actions={
          <div className="flex items-center gap-2.5">
            <button
              onClick={() => navigate('/quality/defects')}
              className="px-4 py-2.5 rounded-xl border border-slate-700 bg-slate-900/60 text-slate-200 text-sm font-medium hover:bg-slate-800 hover:text-white transition-all shadow-sm flex items-center gap-2"
            >
              <ArrowLeft className="w-4 h-4" />
              <span>All Defects</span>
            </button>
            <button
              onClick={() => navigate(`/quality/defects/${defect.id}/edit`)}
              className="px-4 py-2.5 rounded-xl border border-purple-500/40 bg-purple-500/10 text-purple-300 text-sm font-semibold hover:bg-purple-500/20 transition-all shadow-sm flex items-center gap-2"
            >
              <Edit2 className="w-4 h-4" />
              <span>Edit</span>
            </button>
          </div>
        }
      />

      {error && (
        <div className="rounded-2xl border border-rose-500/30 bg-rose-500/10 p-4 text-rose-200 flex items-center gap-3">
          <AlertTriangle className="w-5 h-5 text-rose-400 shrink-0" />
          <span className="text-sm font-medium">{error}</span>
        </div>
      )}

      {/* Primary Details Card */}
      <div className="rounded-3xl border border-slate-800 bg-slate-900/60 backdrop-blur-sm p-6 sm:p-8 space-y-8 shadow-sm">
        {/* Metric Attributes Grid */}
        <div className="grid sm:grid-cols-2 md:grid-cols-3 gap-6 border-b border-slate-800/80 pb-6">
          <div>
            <span className="text-xs font-bold uppercase tracking-wider text-slate-400">SKU Code</span>
            <div className="mt-1 text-xl font-bold font-mono text-cyan-300">{skuCode}</div>
          </div>

          <div>
            <span className="text-xs font-bold uppercase tracking-wider text-slate-400">Severity</span>
            <div className="mt-1">
              <SeverityBadge severity={defect.severity} />
            </div>
          </div>

          <div>
            <span className="text-xs font-bold uppercase tracking-wider text-slate-400">Inspection Status</span>
            <div className="mt-1">
              <StatusBadge status={defect.status} />
            </div>
          </div>

          <div>
            <span className="text-xs font-bold uppercase tracking-wider text-slate-400">Logged Timestamp</span>
            <div className="mt-1 text-sm text-slate-200">
              {defect.createdAt ? new Date(defect.createdAt).toLocaleString() : 'N/A'}
            </div>
          </div>

          <div>
            <span className="text-xs font-bold uppercase tracking-wider text-slate-400">Defect Reference ID</span>
            <div className="mt-1 text-sm font-mono text-purple-400">#{defect.id}</div>
          </div>
        </div>

        {/* Description */}
        <div className="space-y-2">
          <span className="text-xs font-bold uppercase tracking-wider text-slate-400">Defect Description &amp; Notes</span>
          <p className="text-sm text-slate-200 leading-relaxed bg-slate-950/60 p-4 rounded-2xl border border-slate-800">
            {defect.description || 'No detailed observations recorded.'}
          </p>
        </div>

        {/* Affected Rolls */}
        <div className="space-y-3 pt-2">
          <div className="flex items-center justify-between">
            <span className="text-xs font-bold uppercase tracking-wider text-slate-400">Linked Warehouse Rolls</span>
            <span className="text-xs font-mono text-cyan-400">{invList?.length || 0} Rolls</span>
          </div>

          {invList && invList.length > 0 ? (
            <div className="grid gap-2 sm:grid-cols-2">
              {invList.map((rollId) => (
                <div
                  key={rollId}
                  className="p-3 rounded-xl bg-slate-950/60 border border-slate-800 flex items-center justify-between"
                >
                  <span className="font-mono text-xs text-cyan-300">{rollId}</span>
                  <span className="text-[10px] uppercase font-bold text-slate-400 px-2 py-0.5 rounded bg-slate-900 border border-slate-800">
                    Linked
                  </span>
                </div>
              ))}
            </div>
          ) : (
            <p className="text-xs text-slate-400 italic">No specific inventory rolls attached to this defect report.</p>
          )}
        </div>

        {/* Immediate Quarantine Containment Station */}
        {defect.status !== 'Resolved' && defect.status !== 'Closed' && (
          <div className="pt-6 border-t border-slate-800/80 space-y-4">
            <div className="flex items-center gap-2">
              <ShieldAlert className="w-5 h-5 text-rose-400" />
              <h3 className="text-sm font-bold text-white uppercase tracking-wider">Immediate Quarantine Containment</h3>
            </div>
            <p className="text-xs text-slate-400">
              Apply a factory-wide quality hold on all inventory rolls linked to this defect report.
            </p>

            <form onSubmit={handleQuarantine} className="space-y-3">
              <textarea
                rows={2}
                required
                value={reason}
                onChange={(e) => setReason(e.target.value)}
                placeholder="Enter mandatory quarantine justification (e.g. Critical tensile failure detected)..."
                className="w-full rounded-xl bg-slate-950 border border-slate-700 px-4 py-2.5 text-xs text-white placeholder:text-slate-500 outline-none focus:border-rose-500 transition-colors"
              />
              <div className="flex justify-end">
                <button
                  type="submit"
                  disabled={quarantining}
                  className="px-4 py-2 rounded-xl bg-rose-600 hover:bg-rose-500 text-white text-xs font-bold shadow-md shadow-rose-600/20 flex items-center gap-2 disabled:opacity-50 transition-all"
                >
                  {quarantining ? <Loader2 className="w-3.5 h-3.5 animate-spin" /> : <ShieldAlert className="w-3.5 h-3.5" />}
                  <span>Enforce Quarantine Hold</span>
                </button>
              </div>
            </form>
          </div>
        )}
      </div>
    </div>
  );
}

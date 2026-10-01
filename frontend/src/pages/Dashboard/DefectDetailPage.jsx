import { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import {
  ArrowLeft,
  Edit2,
  ShieldAlert,
  Loader2,
  AlertTriangle,
  Package,
  Layers,
  Calendar,
  User
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
          quarantineService.getAll(),
          inventoryService.getRolls(),
          inventoryService.getRawMaterials()
        ]);
        const savedInventory = data.affectedInventory?.length
          ? data.affectedInventory
          : quarantineData
              .filter((record) => record.defectReportId === id)
              .map((record) => record.inventoryRollId);
        setDefect(data);
        setAffectedInventory(savedInventory);
        const selectedRoll = rolls.find((roll) => savedInventory.includes(roll.id));
        setSkuCode(materials.find((material) => material.id === selectedRoll?.rawMaterialId)?.skuCode || 'Unavailable');
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
      <div className="flex flex-col items-center justify-center py-24 text-slate-400 space-y-3">
        <Loader2 className="w-8 h-8 animate-spin text-emerald-400" />
        <p className="text-sm font-medium">Loading defect telemetry...</p>
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
              className="px-4 py-2.5 rounded-xl border border-cyan-500/40 bg-cyan-500/10 text-cyan-300 text-sm font-semibold hover:bg-cyan-500/20 transition-all shadow-sm flex items-center gap-2"
            >
              <Edit2 className="w-4 h-4" />
              <span>Edit</span>
            </button>
          </div>
        }
      />

      {/* Error alert if quarantine fails */}
      {error && (
        <div className="rounded-2xl border border-rose-500/30 bg-rose-500/10 p-4 text-rose-200 flex items-center gap-3">
          <AlertTriangle className="w-5 h-5 text-rose-400 shrink-0" />
          <span className="text-sm font-medium">{error}</span>
        </div>
      )}

      {/* Primary Details Card */}
      <div className="rounded-3xl border border-slate-800 bg-slate-900/60 backdrop-blur-sm p-8 space-y-8 shadow-sm">
        {/* Metric Attributes Grid */}
        <div className="grid sm:grid-cols-2 md:grid-cols-3 gap-6 border-b border-slate-800/80 pb-8">
          <div>
            <span className="text-xs font-bold uppercase tracking-wider text-slate-400">
              SKU Code
            </span>
            <div className="mt-1 text-xl font-bold font-mono text-white tracking-tight">
              {skuCode}
            </div>
          </div>

          <div>
            <span className="text-xs font-bold uppercase tracking-wider text-slate-400">
              Severity
            </span>
            <div className="mt-1">
              <SeverityBadge severity={defect.severity} />
            </div>
          </div>

          <div>
            <span className="text-xs font-bold uppercase tracking-wider text-slate-400">
              Status
            </span>
            <div className="mt-1">
              <StatusBadge status={defect.status} />
            </div>
          </div>

          <div>
            <span className="text-xs font-bold uppercase tracking-wider text-slate-400">
              Reported By
            </span>
            <div className="mt-1 text-sm font-mono text-slate-300">
              {defect.reportedByUserId || 'Unavailable'}
            </div>
          </div>

          <div>
            <span className="text-xs font-bold uppercase tracking-wider text-slate-400">
              Created Timestamp
            </span>
            <div className="mt-1 text-xs text-slate-400">
              {new Date(defect.createdAt).toLocaleString()}
            </div>
          </div>
        </div>

        {/* Description Section */}
        <div>
          <span className="text-xs font-bold uppercase tracking-wider text-slate-400">
            Defect Description
          </span>
          <div className="mt-2 p-5 rounded-2xl bg-slate-950 border border-slate-800 text-sm text-slate-300 whitespace-pre-wrap leading-relaxed">
            {defect.description}
          </div>
        </div>

        {/* Affected Inventory */}
        <div>
          <span className="text-xs font-bold uppercase tracking-wider text-slate-400">
            Affected Inventory Rolls
          </span>
          <div className="mt-2 p-4 rounded-2xl bg-slate-950 border border-slate-800 text-sm font-mono text-cyan-200">
            {invList.length ? invList.join(', ') : 'No specific rolls linked'}
          </div>
        </div>
      </div>

      {/* Quarantine Action Card */}
      <div className="rounded-3xl border border-amber-500/30 bg-amber-500/5 backdrop-blur-sm p-8 space-y-4 shadow-sm">
        <div className="flex items-center gap-3">
          <div className="p-2.5 rounded-xl bg-amber-500/10 border border-amber-500/30 text-amber-300">
            <ShieldAlert className="w-5 h-5" />
          </div>
          <div>
            <h3 className="text-base font-bold text-white tracking-tight">
              Quarantine Inventory Hold
            </h3>
            <p className="text-xs text-slate-400 mt-0.5">
              Affected inventory rolls will automatically be flagged and segregated under quarantine.
            </p>
          </div>
        </div>

        <form onSubmit={handleQuarantine} className="space-y-4 pt-2">
          <textarea
            value={reason}
            onChange={(e) => setReason(e.target.value)}
            placeholder="Specify reason for quarantine hold (e.g. Seal burst failure rate exceeded 2% threshold)..."
            rows="3"
            className="w-full rounded-xl bg-slate-950 border border-slate-700 px-4 py-3 text-sm text-white placeholder:text-slate-500 outline-none focus:border-amber-500 transition-colors"
          />
          <div className="flex justify-end">
            <button
              type="submit"
              disabled={quarantining}
              className="px-6 py-2.5 rounded-xl bg-amber-400 text-slate-950 font-bold text-sm hover:bg-amber-300 disabled:opacity-60 transition-all shadow-lg shadow-amber-500/20 flex items-center gap-2"
            >
              {quarantining ? (
                <>
                  <Loader2 className="w-4 h-4 animate-spin" />
                  <span>Initiating Hold...</span>
                </>
              ) : (
                <>
                  <ShieldAlert className="w-4 h-4 stroke-[2.5]" />
                  <span>Quarantine Inventory</span>
                </>
              )}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}

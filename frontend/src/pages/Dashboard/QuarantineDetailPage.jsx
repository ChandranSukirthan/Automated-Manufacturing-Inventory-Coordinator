import ModalOverlay from '../../components/Common/ModalOverlay';
import React, { useEffect, useState } from 'react';
import { useNavigate, useParams, Link } from 'react-router-dom';
import {
  ArrowLeft,
  ShieldCheck,
  ShieldAlert,
  Loader2,
  AlertTriangle,
  CheckCircle2,
  Calendar,
  Layers,
  UserCheck,
  Package,
  X
} from 'lucide-react';
import quarantineService from '../../services/quarantineService';
import defectService from '../../services/defectService';
import { parseErrorMessage } from '../../utils/errorHandler';
import PageHeader from '../../components/QA/PageHeader';
import StatusBadge from '../../components/QA/StatusBadge';
import SeverityBadge from '../../components/QA/SeverityBadge';

export default function QuarantineDetailPage() {
  const navigate = useNavigate();
  const { id } = useParams();
  const [record, setRecord] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [severity, setSeverity] = useState('Unknown');
  const [releasing, setReleasing] = useState(false);
  const [releaseModalOpen, setReleaseModalOpen] = useState(false);
  const [resolutionNote, setResolutionNote] = useState('');
  const [releaseSuccess, setReleaseSuccess] = useState('');

  useEffect(() => {
    const load = async () => {
      setLoading(true);
      try {
        const quarantine = await quarantineService.getById(id);
        const defect = await defectService.getById(quarantine.defectReportId).catch(() => null);
        setRecord(quarantine);
        setSeverity(defect?.severity || 'Unknown');
      } catch (err) {
        setError(parseErrorMessage(err, 'Unable to load quarantine record.'));
      } finally {
        setLoading(false);
      }
    };
    load();
  }, [id]);

  const handleReleaseConfirm = async (e) => {
    e.preventDefault();
    setReleasing(true);
    try {
      const updated = await quarantineService.release(id, {
        resolutionNote: resolutionNote.trim() || 'Passed inspection and authorized for return to production.'
      });
      setRecord(updated);
      setReleaseModalOpen(false);
      setReleaseSuccess('Quarantine hold successfully released.');
      setTimeout(() => setReleaseSuccess(''), 5000);
    } catch (err) {
      setError(parseErrorMessage(err, 'Unable to release quarantine.'));
    } finally {
      setReleasing(false);
    }
  };

  if (loading) {
    return (
      <div className="flex flex-col items-center justify-center min-h-[60vh] text-slate-400 space-y-3">
        <Loader2 className="w-8 h-8 animate-spin text-blue-400" />
        <p className="text-sm font-medium">Loading quarantine telemetry...</p>
      </div>
    );
  }

  if (error || !record) {
    return (
      <div className="p-6 lg:p-8 max-w-4xl mx-auto space-y-6">
        <div className="rounded-2xl border border-rose-500/30 bg-rose-500/10 p-4 text-rose-200 flex items-center gap-3">
          <AlertTriangle className="w-5 h-5 text-rose-400 shrink-0" />
          <span className="text-sm font-medium">{error || 'Quarantine record not found.'}</span>
        </div>
        <button
          onClick={() => navigate('/quality/quarantine')}
          className="px-4 py-2 rounded-xl border border-slate-700 text-slate-300 hover:bg-slate-800"
        >
          Back to Quarantine
        </button>
      </div>
    );
  }

  return (
    <div className="p-6 lg:p-8 max-w-4xl mx-auto space-y-6">
      {/* Page Header */}
      <PageHeader
        category="Quality Assurance"
        title="Quarantine Details"
        subtitle={`Quarantine containment profile for Roll ${record.inventoryRollId}`}
        actions={
          <button
            onClick={() => navigate('/quality/quarantine')}
            className="px-4 py-2.5 rounded-xl border border-slate-700 bg-slate-900/60 text-slate-200 text-sm font-medium hover:bg-slate-800 hover:text-white transition-all shadow-sm flex items-center gap-2"
          >
            <ArrowLeft className="w-4 h-4" />
            <span>Back to Management</span>
          </button>
        }
      />

      {releaseSuccess && (
        <div className="rounded-2xl border border-emerald-500/30 bg-emerald-500/10 p-4 text-emerald-200 flex items-center gap-3 animate-in fade-in">
          <CheckCircle2 className="w-5 h-5 text-emerald-400 shrink-0" />
          <span className="text-sm font-medium">{releaseSuccess}</span>
        </div>
      )}

      {/* Primary Detail Card */}
      <div className="rounded-3xl border border-slate-800 bg-slate-900/60 backdrop-blur-sm p-6 sm:p-8 space-y-8 shadow-sm">
        <div className="grid sm:grid-cols-2 md:grid-cols-3 gap-6 border-b border-slate-800/80 pb-6">
          <div>
            <span className="text-xs font-bold uppercase tracking-wider text-slate-400">Inventory Roll ID</span>
            <div className="mt-1 text-xl font-bold font-mono text-cyan-300">{record.inventoryRollId}</div>
          </div>

          <div>
            <span className="text-xs font-bold uppercase tracking-wider text-slate-400">Linked Defect ID</span>
            <div className="mt-1 text-sm font-mono text-blue-400">
              <Link to={`/quality/defects/${record.defectReportId}`} className="hover:underline">
                #{record.defectReportId}
              </Link>
            </div>
          </div>

          <div>
            <span className="text-xs font-bold uppercase tracking-wider text-slate-400">Severity</span>
            <div className="mt-1">
              <SeverityBadge severity={severity} />
            </div>
          </div>

          <div>
            <span className="text-xs font-bold uppercase tracking-wider text-slate-400">Quarantine Status</span>
            <div className="mt-1">
              <StatusBadge status={record.status} />
            </div>
          </div>

          <div>
            <span className="text-xs font-bold uppercase tracking-wider text-slate-400">Quarantined On</span>
            <div className="mt-1 text-sm text-slate-200">
              {record.createdAt ? new Date(record.createdAt).toLocaleString() : 'N/A'}
            </div>
          </div>
        </div>

        {/* Reason */}
        <div className="space-y-2">
          <span className="text-xs font-bold uppercase tracking-wider text-slate-400">Containment Reason &amp; Root Cause</span>
          <p className="text-sm text-slate-200 leading-relaxed bg-slate-950/60 p-4 rounded-2xl border border-slate-800">
            {record.reason || 'No detailed reason provided.'}
          </p>
        </div>

        {/* Release Station if Active */}
        {record.status === 'Active' && (
          <div className="pt-6 border-t border-slate-800/80 flex items-center justify-between gap-4 flex-wrap">
            <div>
              <h3 className="text-sm font-bold text-white">Authorized Quality Release</h3>
              <p className="text-xs text-slate-400 mt-0.5">
                Release this fabric roll from quarantine hold after physical re-inspection.
              </p>
            </div>
            <button
              onClick={() => setReleaseModalOpen(true)}
              className="px-5 py-2.5 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white text-xs font-bold shadow-lg shadow-emerald-600/20 flex items-center gap-2 transition-all"
            >
              <UserCheck className="w-4 h-4" />
              <span>Review &amp; Release</span>
            </button>
          </div>
        )}
      </div>

      {/* Release Confirmation Modal */}
      {releaseModalOpen && (
        <ModalOverlay className="fixed inset-0 z-50 bg-black/70 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="bg-slate-900 border border-slate-800 rounded-3xl max-w-md w-full p-6 space-y-6 shadow-2xl animate-in fade-in">
            <div className="flex items-center justify-between border-b border-slate-800 pb-4">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-xl bg-emerald-500/15 border border-emerald-500/30 flex items-center justify-center text-emerald-400">
                  <UserCheck className="w-5 h-5" />
                </div>
                <div>
                  <h3 className="text-base font-bold text-white">Release Quarantine</h3>
                  <p className="text-xs text-slate-400 font-mono">Roll {record.inventoryRollId}</p>
                </div>
              </div>
              <button
                onClick={() => setReleaseModalOpen(false)}
                className="p-1 rounded-lg text-slate-400 hover:text-white hover:bg-slate-800"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <form onSubmit={handleReleaseConfirm} className="space-y-4">
              <div>
                <label className="block text-xs font-bold uppercase tracking-wider text-slate-400 mb-2">
                  Resolution / Authorization Note *
                </label>
                <textarea
                  required
                  rows={3}
                  value={resolutionNote}
                  onChange={(e) => setResolutionNote(e.target.value)}
                  placeholder="Passed secondary tensile re-test and approved for floor utilization..."
                  className="w-full rounded-xl bg-slate-950 border border-slate-700 px-4 py-2.5 text-xs text-white placeholder:text-slate-500 outline-none focus:border-blue-500 transition-colors"
                />
              </div>

              <div className="flex items-center justify-end gap-3 pt-4 border-t border-slate-800">
                <button
                  type="button"
                  onClick={() => setReleaseModalOpen(false)}
                  className="px-4 py-2 rounded-xl border border-slate-700 text-slate-300 text-xs font-medium hover:bg-slate-800"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={releasing}
                  className="px-5 py-2 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white text-xs font-bold shadow-lg shadow-emerald-600/20 flex items-center gap-2 disabled:opacity-50"
                >
                  {releasing && <Loader2 className="w-3.5 h-3.5 animate-spin" />}
                  <span>Confirm Release</span>
                </button>
              </div>
            </form>
          </div>
        </ModalOverlay>
      )}
    </div>
  );
}

import React, { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import {
  ArrowLeft,
  ShieldCheck,
  ShieldAlert,
  Loader2,
  AlertTriangle,
  CheckCircle2,
  Calendar,
  Layers
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

  useEffect(() => {
    const load = async () => {
      setLoading(true);
      try {
        const quarantine = await quarantineService.getById(id);
        const defect = await defectService.getById(quarantine.defectReportId);
        setRecord(quarantine);
        setSeverity(defect.severity || 'Unknown');
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
    } catch (err) {
      setError(parseErrorMessage(err, 'Unable to release quarantine.'));
    } finally {
      setReleasing(false);
    }
  };

  if (loading) {
    return (
      <div className="flex flex-col items-center justify-center py-24 text-slate-400 space-y-3">
        <Loader2 className="w-8 h-8 animate-spin text-emerald-400" />
        <p className="text-sm font-medium">Loading quarantine record...</p>
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

      {/* Error Banner */}
      {error && (
        <div className="rounded-2xl border border-rose-500/30 bg-rose-500/10 p-4 text-rose-200 flex items-center gap-3">
          <AlertTriangle className="w-5 h-5 text-rose-400 shrink-0" />
          <span className="text-sm font-medium">{error}</span>
        </div>
      )}

      {/* Detail Card */}
      <div className="rounded-3xl border border-slate-800 bg-slate-900/60 backdrop-blur-sm p-8 space-y-8 shadow-sm">
        <div className="grid sm:grid-cols-2 md:grid-cols-3 gap-6 border-b border-slate-800/80 pb-8">
          <div>
            <span className="text-xs font-bold uppercase tracking-wider text-slate-400">
              Inventory Roll ID
            </span>
            <div className="mt-1 text-xl font-bold font-mono text-white tracking-tight">
              {record.inventoryRollId}
            </div>
          </div>

          <div>
            <span className="text-xs font-bold uppercase tracking-wider text-slate-400">
              Batch ID
            </span>
            <div className="mt-1 text-base font-semibold font-mono text-slate-200">
              {record.batchId}
            </div>
          </div>

          <div>
            <span className="text-xs font-bold uppercase tracking-wider text-slate-400">
              Linked Defect
            </span>
            <div className="mt-1 text-sm font-mono text-cyan-300">
              {record.defectReportId}
            </div>
          </div>

          <div>
            <span className="text-xs font-bold uppercase tracking-wider text-slate-400">
              Severity
            </span>
            <div className="mt-1">
              <SeverityBadge severity={severity} />
            </div>
          </div>

          <div>
            <span className="text-xs font-bold uppercase tracking-wider text-slate-400">
              Quarantine Status
            </span>
            <div className="mt-1">
              <StatusBadge status={record.status} />
            </div>
          </div>

          <div>
            <span className="text-xs font-bold uppercase tracking-wider text-slate-400">
              Created Timestamp
            </span>
            <div className="mt-1 text-xs text-slate-400">
              {new Date(record.createdAt).toLocaleString()}
            </div>
          </div>

          <div className="sm:col-span-2 md:col-span-3">
            <span className="text-xs font-bold uppercase tracking-wider text-slate-400">
              Released Timestamp
            </span>
            <div className="mt-1 text-sm text-slate-300">
              {record.releasedAt ? (
                <span className="text-emerald-300 flex items-center gap-1.5 font-medium">
                  <CheckCircle2 className="w-4 h-4" />
                  <span>{new Date(record.releasedAt).toLocaleString()}</span>
                </span>
              ) : (
                <span className="text-slate-500">Currently under quarantine hold (Not released)</span>
              )}
            </div>
          </div>
        </div>

        {/* Reason & Resolution Note */}
        <div className="space-y-4">
          <div>
            <span className="text-xs font-bold uppercase tracking-wider text-slate-400">
              Quarantine Containment Reason &amp; Resolution
            </span>
            <div className="mt-2 p-5 rounded-2xl bg-slate-950 border border-slate-800 text-sm text-slate-300 whitespace-pre-wrap leading-relaxed">
              {record.reason}
            </div>
          </div>
        </div>

        {/* Disposition Action Button */}
        {record.status === 'Active' && (
          <div className="pt-4 border-t border-slate-800/80 flex items-center justify-between">
            <div>
              <p className="text-sm font-bold text-white">Release Hold Disposition</p>
              <p className="text-xs text-slate-400 mt-0.5">
                Authorizes release of inventory roll back into active production handling.
              </p>
            </div>
            <button
              onClick={() => {
                setResolutionNote('');
                setReleaseModalOpen(true);
              }}
              disabled={releasing}
              className="px-6 py-2.5 rounded-xl bg-emerald-500 text-slate-950 font-bold text-sm hover:bg-emerald-400 disabled:opacity-60 transition-all shadow-lg shadow-emerald-500/20 flex items-center gap-2"
            >
              <ShieldCheck className="w-4 h-4 stroke-[2.5]" />
              <span>Release Quarantine</span>
            </button>
          </div>
        )}
      </div>

      {/* Release Disposition Modal */}
      {releaseModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/80 backdrop-blur-md animate-in fade-in">
          <div className="w-full max-w-lg rounded-3xl bg-slate-900 border border-slate-700 shadow-2xl p-6 space-y-5">
            <div className="flex items-start justify-between border-b border-slate-800 pb-4">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-xl bg-emerald-500/20 text-emerald-400 border border-emerald-500/30 flex items-center justify-center">
                  <ShieldCheck className="w-5 h-5" />
                </div>
                <div>
                  <h3 className="text-base font-bold text-white">Release Quarantine Hold</h3>
                  <p className="text-xs font-mono text-cyan-300 mt-0.5">Roll {record.inventoryRollId} • Batch {record.batchId}</p>
                </div>
              </div>
              <button
                onClick={() => setReleaseModalOpen(false)}
                className="p-1 rounded-lg text-slate-400 hover:text-white bg-slate-800"
              >
                ✕
              </button>
            </div>

            <form onSubmit={handleReleaseConfirm} className="space-y-4">
              <p className="text-xs text-slate-300 leading-relaxed">
                Confirming release will change the quarantine status to <strong>Released</strong> and restore the roll to <strong>Available</strong> status in PostgreSQL for manufacturing and purchasing operations.
              </p>

              <div className="space-y-1.5">
                <label className="text-xs font-bold uppercase tracking-wider text-slate-300 block">
                  Disposition / Release Note <span className="text-rose-400">*</span>
                </label>
                <textarea
                  value={resolutionNote}
                  onChange={(e) => setResolutionNote(e.target.value)}
                  placeholder="e.g., Secondary lab test confirmed tensile strength within tolerance. Quarantine lifted."
                  rows={4}
                  required
                  className="w-full rounded-xl bg-slate-950 border border-slate-700 p-3 text-xs text-white placeholder-slate-500 focus:border-emerald-500 focus:outline-none"
                />
              </div>

              <div className="flex items-center justify-end gap-3 pt-2">
                <button
                  type="button"
                  onClick={() => setReleaseModalOpen(false)}
                  className="px-4 py-2 rounded-xl border border-slate-700 text-slate-300 text-xs font-semibold hover:bg-slate-800"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={releasing}
                  className="px-5 py-2 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white text-xs font-bold transition-all shadow-lg shadow-emerald-600/25 flex items-center gap-2 disabled:opacity-50"
                >
                  {releasing ? (
                    <>
                      <Loader2 className="w-3.5 h-3.5 animate-spin" />
                      <span>Releasing...</span>
                    </>
                  ) : (
                    <>
                      <ShieldCheck className="w-3.5 h-3.5" />
                      <span>Confirm Release Disposition</span>
                    </>
                  )}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}

import ModalOverlay from '../../components/Common/ModalOverlay';
import React, { useEffect, useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import {
  History,
  Search,
  ArrowUpDown,
  RotateCcw,
  Eye,
  Loader2,
  AlertTriangle,
  ShieldAlert,
  CheckCircle2,
  Package,
  Layers,
  UserCheck,
  X,
  Sparkles
} from 'lucide-react';
import quarantineService from '../../services/quarantineService';
import defectService from '../../services/defectService';
import { parseErrorMessage } from '../../utils/errorHandler';
import PageHeader from '../../components/QA/PageHeader';
import StatusBadge from '../../components/QA/StatusBadge';
import SeverityBadge from '../../components/QA/SeverityBadge';
import EmptyState from '../../components/QA/EmptyState';
import TablePagination from '../../components/QA/TablePagination';

const PAGE_SIZE = 8;
const severities = ['LOW', 'MEDIUM', 'HIGH', 'Critical'];
const statuses = ['Active', 'Released'];

export default function QuarantineManagementPage() {
  const navigate = useNavigate();
  const [records, setRecords] = useState([]);
  const [defects, setDefects] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [query, setQuery] = useState('');
  const [severity, setSeverity] = useState('All');
  const [status, setStatus] = useState('All');
  const [sort, setSort] = useState({ key: 'createdAt', direction: 'desc' });
  const [page, setPage] = useState(1);

  // Review & Resolve Modal
  const [resolveModalOpen, setResolveModalOpen] = useState(false);
  const [selectedRecord, setSelectedRecord] = useState(null);
  const [resolutionNote, setResolutionNote] = useState('');
  const [resolving, setResolving] = useState(false);
  const [resolveError, setResolveError] = useState('');
  const [resolveSuccess, setResolveSuccess] = useState('');

  const loadQuarantines = async () => {
    setLoading(true);
    setError('');
    try {
      const [quarantineData, defectData] = await Promise.all([
        quarantineService.getAll(),
        defectService.getAll().catch(() => [])
      ]);
      setRecords(Array.isArray(quarantineData) ? quarantineData : []);
      setDefects(Array.isArray(defectData) ? defectData : []);
    } catch (err) {
      setError(parseErrorMessage(err, 'Unable to load quarantine records.'));
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    const initialLoad = setTimeout(loadQuarantines, 0);
    return () => clearTimeout(initialLoad);
  }, []);

  const severityFor = (record) =>
    defects.find((defect) => defect.id === record.defectReportId)?.severity || 'Unknown';

  // Metrics
  const activeRecords = records.filter((r) => r.status === 'Active');
  const criticalCases = records.filter((r) => String(severityFor(r)).toLowerCase() === 'critical').length;
  const releasedRecords = records.filter((r) => r.status === 'Released');

  const isFiltered = query.trim() !== '' || severity !== 'All' || status !== 'All';

  const clearFilters = () => {
    setQuery('');
    setSeverity('All');
    setStatus('All');
    setPage(1);
  };

  const filtered = records
    .filter((record) => {
      const recordSeverity = severityFor(record);
      const text = [
        record.inventoryRollId,
        record.reason,
        record.status,
        recordSeverity
      ]
        .join(' ')
        .toLowerCase();

      return (
        text.includes(query.trim().toLowerCase()) &&
        (severity === 'All' || recordSeverity.toLowerCase() === severity.toLowerCase()) &&
        (status === 'All' || record.status.toLowerCase() === status.toLowerCase())
      );
    })
    .sort((left, right) => {
      const values = {
        createdAt: [new Date(left.createdAt).getTime(), new Date(right.createdAt).getTime()],
        severity: [severityFor(left), severityFor(right)],
        status: [left.status, right.status]
      }[sort.key] || [new Date(left.createdAt).getTime(), new Date(right.createdAt).getTime()];

      const comparison =
        typeof values[0] === 'number'
          ? values[0] - values[1]
          : String(values[0]).localeCompare(String(values[1]));
      return sort.direction === 'asc' ? comparison : -comparison;
    });

  const totalPages = Math.max(1, Math.ceil(filtered.length / PAGE_SIZE));
  const visiblePage = Math.min(page, totalPages);
  const visibleRecords = filtered.slice((visiblePage - 1) * PAGE_SIZE, visiblePage * PAGE_SIZE);

  const handleSort = (key) => {
    setSort((current) =>
      current.key === key
        ? { key, direction: current.direction === 'asc' ? 'desc' : 'asc' }
        : { key, direction: 'asc' }
    );
    setPage(1);
  };

  const openResolveModal = (record) => {
    setSelectedRecord(record);
    setResolutionNote('');
    setResolveError('');
    setResolveModalOpen(true);
  };

  const handleResolveSubmit = async (e) => {
    e.preventDefault();
    if (!selectedRecord) return;
    setResolving(true);
    setResolveError('');
    try {
      await quarantineService.release(selectedRecord.id, {
        resolutionNote: resolutionNote.trim() || 'Passed inspection and authorized for return to production.'
      });
      setResolveModalOpen(false);
      setResolveSuccess(`Quarantine for Roll ${selectedRecord.inventoryRollId} successfully released.`);
      setTimeout(() => setResolveSuccess(''), 5000);
      loadQuarantines();
    } catch (err) {
      setResolveError(parseErrorMessage(err, 'Failed to release quarantine hold.'));
    } finally {
      setResolving(false);
    }
  };

  return (
    <div className="p-6 lg:p-8 max-w-7xl mx-auto space-y-6">
      {/* Page Header */}
      <PageHeader
        category="Quality Assurance"
        title="Quarantine Management"
        subtitle="Monitor and control inventory under quality restriction"
        actions={
          <button
            onClick={() => navigate('/quality/quarantine/history')}
            className="px-4 py-2.5 rounded-xl border border-blue-500/30 bg-blue-500/10 text-blue-300 text-sm font-semibold hover:bg-blue-500/20 transition-all shadow-sm flex items-center gap-2"
          >
            <History className="w-4 h-4" />
            <span>Quarantine History</span>
          </button>
        }
      />

      {/* Top Metrics Cards */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <div className="p-4 rounded-2xl bg-slate-900/60 border border-slate-800 backdrop-blur-sm">
          <div className="flex items-center justify-between">
            <span className="text-xs font-bold uppercase tracking-wider text-slate-400">Active Quarantines</span>
            <ShieldAlert className="w-4 h-4 text-rose-400" />
          </div>
          <p className="text-2xl font-extrabold text-rose-400 mt-2">{activeRecords.length}</p>
          <span className="text-[11px] text-slate-400 mt-1 block">Active containment holds</span>
        </div>

        <div className="p-4 rounded-2xl bg-slate-900/60 border border-slate-800 backdrop-blur-sm">
          <div className="flex items-center justify-between">
            <span className="text-xs font-bold uppercase tracking-wider text-slate-400">Critical Cases</span>
            <AlertTriangle className="w-4 h-4 text-orange-400" />
          </div>
          <p className="text-2xl font-extrabold text-orange-300 mt-2">{criticalCases}</p>
          <span className="text-[11px] text-slate-400 mt-1 block">High severity defects</span>
        </div>

        <div className="p-4 rounded-2xl bg-slate-900/60 border border-slate-800 backdrop-blur-sm">
          <div className="flex items-center justify-between">
            <span className="text-xs font-bold uppercase tracking-wider text-slate-400">Affected Rolls</span>
            <Package className="w-4 h-4 text-amber-400" />
          </div>
          <p className="text-2xl font-extrabold text-amber-300 mt-2">{records.length}</p>
          <span className="text-[11px] text-slate-400 mt-1 block">Total tracked rolls</span>
        </div>

        <div className="p-4 rounded-2xl bg-slate-900/60 border border-slate-800 backdrop-blur-sm">
          <div className="flex items-center justify-between">
            <span className="text-xs font-bold uppercase tracking-wider text-slate-400">Released</span>
            <CheckCircle2 className="w-4 h-4 text-emerald-400" />
          </div>
          <p className="text-2xl font-extrabold text-emerald-400 mt-2">{releasedRecords.length}</p>
          <span className="text-[11px] text-slate-400 mt-1 block">Returned to production</span>
        </div>
      </div>

      {/* Success Notification */}
      {resolveSuccess && (
        <div className="rounded-2xl border border-emerald-500/30 bg-emerald-500/10 p-4 text-emerald-200 flex items-center gap-3 animate-in fade-in">
          <CheckCircle2 className="w-5 h-5 text-emerald-400 shrink-0" />
          <span className="text-sm font-medium">{resolveSuccess}</span>
        </div>
      )}

      {/* Error Alert */}
      {error && (
        <div className="rounded-2xl border border-rose-500/30 bg-rose-500/10 p-4 text-rose-200 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <AlertTriangle className="w-5 h-5 text-rose-400 shrink-0" />
            <span className="text-sm font-medium">{error}</span>
          </div>
          <button onClick={loadQuarantines} className="text-xs font-semibold underline hover:text-rose-100 ml-4">
            Retry
          </button>
        </div>
      )}

      {/* Filter and Search Toolbar */}
      <div className="flex flex-col sm:flex-row items-stretch sm:items-center justify-between gap-3 p-4 rounded-2xl border border-slate-800 bg-slate-900/60 backdrop-blur-sm">
        <div className="relative flex-1 max-w-md">
          <Search className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" />
          <input
            value={query}
            onChange={(e) => {
              setQuery(e.target.value);
              setPage(1);
            }}
            placeholder="Search roll ID, containment reason..."
            className="w-full rounded-xl bg-slate-950 border border-slate-700 pl-10 pr-4 py-2 text-sm text-white placeholder:text-slate-500 outline-none focus:border-blue-500 transition-colors"
          />
        </div>

        <div className="flex flex-wrap items-center gap-2">
          <select
            value={severity}
            onChange={(e) => {
              setSeverity(e.target.value);
              setPage(1);
            }}
            className="rounded-xl bg-slate-950 border border-slate-700 px-3 py-2 text-xs font-semibold text-slate-200 outline-none focus:border-blue-500"
          >
            <option value="All">All Severities</option>
            {severities.map((s) => (
              <option key={s} value={s}>{s}</option>
            ))}
          </select>

          <select
            value={status}
            onChange={(e) => {
              setStatus(e.target.value);
              setPage(1);
            }}
            className="rounded-xl bg-slate-950 border border-slate-700 px-3 py-2 text-xs font-semibold text-slate-200 outline-none focus:border-blue-500"
          >
            <option value="All">All Statuses</option>
            {statuses.map((s) => (
              <option key={s} value={s}>{s}</option>
            ))}
          </select>

          {isFiltered && (
            <button
              onClick={clearFilters}
              className="p-2 rounded-xl border border-slate-700 text-slate-400 hover:text-white hover:bg-slate-800 transition-colors"
              title="Clear Filters"
            >
              <RotateCcw className="w-4 h-4" />
            </button>
          )}
        </div>
      </div>

      {/* Main Table / Data View */}
      {loading ? (
        <div className="flex flex-col items-center justify-center py-20 text-slate-400 space-y-3">
          <Loader2 className="w-8 h-8 animate-spin text-blue-400" />
          <p className="text-sm font-medium">Loading quarantine telemetry...</p>
        </div>
      ) : records.length === 0 ? (
        <EmptyState
          icon={ShieldAlert}
          title="No quarantine records"
          description="There are currently no inventory items in quarantine containment."
        />
      ) : visibleRecords.length === 0 ? (
        <EmptyState
          icon={Search}
          title="No matching records"
          description="No quarantine records match your search parameters."
          actionLabel="Reset Filters"
          onAction={clearFilters}
        />
      ) : (
        <div className="space-y-4">
          {/* Desktop Table */}
          <div className="hidden md:block rounded-2xl border border-slate-800 bg-slate-900/60 backdrop-blur-sm overflow-hidden shadow-sm">
            <table className="w-full text-left border-collapse text-xs">
              <thead>
                <tr className="border-b border-slate-800 bg-slate-900/90 text-[11px] font-bold uppercase tracking-wider text-slate-400">
                  <th className="px-4 py-3.5">Roll / Inventory</th>
                  <th className="px-4 py-3.5">Severity</th>
                  <th className="px-4 py-3.5">Reason</th>
                  <th className="px-4 py-3.5">Status</th>
                  <th className="px-4 py-3.5 cursor-pointer hover:text-white" onClick={() => handleSort('createdAt')}>
                    <div className="flex items-center gap-1">
                      <span>Quarantined</span>
                      <ArrowUpDown className="w-3.5 h-3.5" />
                    </div>
                  </th>
                  <th className="px-4 py-3.5 text-right">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-800/80">
                {visibleRecords.map((r) => (
                  <tr key={r.id} className="hover:bg-slate-800/40 transition-colors group">
                    <td className="px-4 py-3.5 font-mono font-semibold text-cyan-300">
                      {r.inventoryRollId}
                    </td>
                    <td className="px-4 py-3.5">
                      <SeverityBadge severity={severityFor(r)} />
                    </td>
                    <td className="px-4 py-3.5 text-slate-300 max-w-xs truncate">
                      {r.reason}
                    </td>
                    <td className="px-4 py-3.5">
                      <StatusBadge status={r.status} />
                    </td>
                    <td className="px-4 py-3.5 text-slate-400">
                      {r.createdAt ? new Date(r.createdAt).toLocaleDateString() : 'N/A'}
                    </td>
                    <td className="px-4 py-3.5 text-right">
                      <div className="flex items-center justify-end gap-2">
                        {r.status === 'Active' && (
                          <button
                            onClick={() => openResolveModal(r)}
                            className="px-2.5 py-1 rounded-lg bg-emerald-600/20 hover:bg-emerald-600 text-emerald-300 hover:text-white border border-emerald-500/30 text-[11px] font-bold transition-all"
                          >
                            Review &amp; Resolve
                          </button>
                        )}
                        <Link
                          to={`/quality/quarantine/${r.id}`}
                          className="p-1.5 rounded-lg text-slate-400 hover:text-blue-300 hover:bg-blue-500/10 border border-transparent hover:border-blue-500/20 transition-all"
                          title="View Details"
                        >
                          <Eye className="w-4 h-4" />
                        </Link>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          {/* Mobile Card Layout */}
          <div className="grid md:hidden gap-3">
            {visibleRecords.map((r) => (
              <div key={r.id} className="p-4 rounded-2xl bg-slate-900/60 border border-slate-800 space-y-3">
                <div className="flex items-center justify-between">
                  <span className="font-mono font-bold text-cyan-300 text-xs">{r.inventoryRollId}</span>
                  <StatusBadge status={r.status} />
                </div>
                <div className="flex items-center justify-between text-xs">
                  <span className="text-slate-400 text-[11px]">Severity:</span>
                  <SeverityBadge severity={severityFor(r)} />
                </div>
                <p className="text-xs text-slate-300 line-clamp-2">{r.reason}</p>
                <div className="flex items-center justify-between pt-2 border-t border-slate-800 text-[11px] text-slate-400">
                  <span>{r.createdAt ? new Date(r.createdAt).toLocaleDateString() : ''}</span>
                  <div className="flex items-center gap-2">
                    {r.status === 'Active' && (
                      <button
                        onClick={() => openResolveModal(r)}
                        className="text-emerald-400 font-bold"
                      >
                        Resolve
                      </button>
                    )}
                    <Link to={`/quality/quarantine/${r.id}`} className="text-blue-400 font-semibold">
                      Details
                    </Link>
                  </div>
                </div>
              </div>
            ))}
          </div>

          {/* Pagination */}
          <TablePagination
            page={visiblePage}
            totalPages={totalPages}
            totalItems={filtered.length}
            pageSize={PAGE_SIZE}
            onPageChange={(p) => setPage(p)}
          />
        </div>
      )}

      {/* REVIEW & RESOLVE MODAL */}
      {resolveModalOpen && selectedRecord && (
        <ModalOverlay className="fixed inset-0 z-50 bg-black/70 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="bg-slate-900 border border-slate-800 rounded-3xl max-w-lg w-full p-6 space-y-6 shadow-2xl animate-in fade-in">
            <div className="flex items-center justify-between border-b border-slate-800 pb-4">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-xl bg-blue-500/15 border border-blue-500/30 flex items-center justify-center text-blue-400">
                  <UserCheck className="w-5 h-5" />
                </div>
                <div>
                  <h3 className="text-base font-bold text-white">Review &amp; Release Quarantine</h3>
                  <p className="text-xs text-slate-400 font-mono">Roll {selectedRecord.inventoryRollId}</p>
                </div>
              </div>
              <button
                onClick={() => setResolveModalOpen(false)}
                className="p-1 rounded-lg text-slate-400 hover:text-white hover:bg-slate-800"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            {/* Quarantine Context Summary */}
            <div className="p-3.5 rounded-2xl bg-slate-950/60 border border-slate-800 space-y-1.5 text-xs">
              <div className="flex items-center justify-between">
                <span className="text-slate-400 font-semibold">Severity:</span>
                <SeverityBadge severity={severityFor(selectedRecord)} />
              </div>
              <div>
                <span className="text-slate-400 font-semibold block mb-0.5">Original Quarantine Reason:</span>
                <p className="text-slate-300 italic">{selectedRecord.reason}</p>
              </div>
            </div>

            {resolveError && (
              <div className="p-3 rounded-xl bg-rose-500/10 border border-rose-500/30 text-rose-300 text-xs flex items-center gap-2">
                <AlertTriangle className="w-4 h-4 shrink-0" />
                <span>{resolveError}</span>
              </div>
            )}

            <form onSubmit={handleResolveSubmit} className="space-y-4">
              <div>
                <label className="block text-xs font-bold uppercase tracking-wider text-slate-400 mb-2">
                  Inspector Disposition Note *
                </label>
                <textarea
                  required
                  rows={3}
                  value={resolutionNote}
                  onChange={(e) => setResolutionNote(e.target.value)}
                  placeholder="State the laboratory clearance, rework completion, or inspector authorization releasing this roll..."
                  className="w-full rounded-xl bg-slate-950 border border-slate-700 px-4 py-2.5 text-xs text-white placeholder:text-slate-500 outline-none focus:border-blue-500 transition-colors"
                />
              </div>

              <div className="flex items-center justify-end gap-3 pt-4 border-t border-slate-800">
                <button
                  type="button"
                  onClick={() => setResolveModalOpen(false)}
                  className="px-4 py-2 rounded-xl border border-slate-700 text-slate-300 text-xs font-medium hover:bg-slate-800"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={resolving}
                  className="px-5 py-2 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white text-xs font-bold shadow-lg shadow-emerald-600/20 flex items-center gap-2 disabled:opacity-50"
                >
                  {resolving && <Loader2 className="w-3.5 h-3.5 animate-spin" />}
                  <span>Authorize Release</span>
                </button>
              </div>
            </form>
          </div>
        </ModalOverlay>
      )}
    </div>
  );
}

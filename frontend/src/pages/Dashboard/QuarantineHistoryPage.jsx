import { formatColomboDate } from '../../utils/locale.js';
import React, { useEffect, useState, useMemo } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import {
  ArrowLeft,
  History,
  Search,
  Loader2,
  AlertTriangle,
  RotateCcw,
  CheckCircle2,
  ShieldAlert,
  ChevronDown,
  ChevronUp,
  Package,
  Layers,
  Eye,
  Calendar,
  FileText,
  ShieldCheck
} from 'lucide-react';
import quarantineService from '../../services/quarantineService';
import { parseErrorMessage } from '../../utils/errorHandler';
import PageHeader from '../../components/QA/PageHeader';
import StatusBadge from '../../components/QA/StatusBadge';
import EmptyState from '../../components/QA/EmptyState';
import TablePagination from '../../components/QA/TablePagination';

const PAGE_SIZE = 8;

const isRecordReleased = (r) => {
  if (!r) return false;
  const s = String(r.status ?? '').toLowerCase();
  return s === 'released' || r.status === 1;
};

export default function QuarantineHistoryPage() {
  const navigate = useNavigate();
  const [allRecords, setAllRecords] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [query, setQuery] = useState('');
  const [statusFilter, setStatusFilter] = useState('All');
  const [page, setPage] = useState(1);
  const [expandedRows, setExpandedRows] = useState({});

  const loadHistory = async () => {
    setLoading(true);
    setError('');
    try {
      const quarantineData = await quarantineService.getAll();
      setAllRecords(Array.isArray(quarantineData) ? quarantineData : []);
    } catch (err) {
      setError(parseErrorMessage(err, 'Unable to load quarantine history.'));
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    const initialLoad = setTimeout(loadHistory, 0);
    return () => clearTimeout(initialLoad);
  }, []);

  const toggleRow = (id) => {
    setExpandedRows((prev) => ({
      ...prev,
      [id]: !prev[id]
    }));
  };

  // Summary Metrics
  const releasedCount = useMemo(
    () => allRecords.filter((r) => isRecordReleased(r)).length,
    [allRecords]
  );
  const activeCount = useMemo(
    () => allRecords.filter((r) => !isRecordReleased(r)).length,
    [allRecords]
  );

  const filtered = useMemo(() => {
    return allRecords.filter((record) => {
      if (!record) return false;
      const released = isRecordReleased(record);

      if (statusFilter === 'Released' && !released) return false;
      if (statusFilter === 'Active' && released) return false;

      const text = [
        record.inventoryRollId || '',
        record.reason || '',
        record.status || '',
        record.defectReportId || ''
      ]
        .join(' ')
        .toLowerCase();

      return text.includes(query.trim().toLowerCase());
    });
  }, [allRecords, statusFilter, query]);

  const totalPages = Math.max(1, Math.ceil(filtered.length / PAGE_SIZE));
  const visiblePage = Math.min(page, totalPages);
  const visibleRecords = filtered.slice((visiblePage - 1) * PAGE_SIZE, visiblePage * PAGE_SIZE);

  const isFiltered = query.trim() !== '' || statusFilter !== 'All';

  const clearFilters = () => {
    setQuery('');
    setStatusFilter('All');
    setPage(1);
  };

  return (
    <div className="p-6 lg:p-8 max-w-7xl mx-auto space-y-6">
      {/* Page Header */}
      <PageHeader
        category="Quality Assurance"
        title="Quarantine History"
        subtitle="Audit trail of inventory quarantine and release activity"
        actions={
          <button
            onClick={() => navigate('/quality/quarantine')}
            className="px-4 py-2.5 rounded-xl border border-slate-700 bg-slate-900/60 text-slate-200 text-sm font-medium hover:bg-slate-800 hover:text-white transition-all shadow-sm flex items-center gap-2"
          >
            <ArrowLeft className="w-4 h-4" />
            <span>Quarantine Management</span>
          </button>
        }
      />

      {/* Top Metrics Cards */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <div className="p-4 rounded-2xl bg-slate-900/60 border border-slate-800 backdrop-blur-sm">
          <div className="flex items-center justify-between">
            <span className="text-xs font-bold uppercase tracking-wider text-slate-400">Total Quarantine Events</span>
            <History className="w-4 h-4 text-blue-400" />
          </div>
          <p className="text-2xl font-black text-white mt-2 font-mono">{allRecords.length}</p>
          <span className="text-[11px] text-slate-400 mt-1 block">Historical factory holds</span>
        </div>

        <div className="p-4 rounded-2xl bg-slate-900/60 border border-slate-800 backdrop-blur-sm">
          <div className="flex items-center justify-between">
            <span className="text-xs font-bold uppercase tracking-wider text-emerald-400">Released &amp; Cleared</span>
            <CheckCircle2 className="w-4 h-4 text-emerald-400" />
          </div>
          <p className="text-2xl font-black text-emerald-400 mt-2 font-mono">{releasedCount}</p>
          <span className="text-[11px] text-slate-400 mt-1 block">Cleared back to production</span>
        </div>

        <div className="p-4 rounded-2xl bg-slate-900/60 border border-slate-800 backdrop-blur-sm">
          <div className="flex items-center justify-between">
            <span className="text-xs font-bold uppercase tracking-wider text-rose-400">Active Holds</span>
            <ShieldAlert className="w-4 h-4 text-rose-400" />
          </div>
          <p className="text-2xl font-black text-rose-400 mt-2 font-mono">{activeCount}</p>
          <span className="text-[11px] text-slate-400 mt-1 block">Currently restricted rolls</span>
        </div>

        <div className="p-4 rounded-2xl bg-slate-900/60 border border-slate-800 backdrop-blur-sm">
          <div className="flex items-center justify-between">
            <span className="text-xs font-bold uppercase tracking-wider text-cyan-400">Audit Status</span>
            <ShieldCheck className="w-4 h-4 text-cyan-400" />
          </div>
          <p className="text-2xl font-black text-cyan-300 mt-2 font-mono">100% Gated</p>
          <span className="text-[11px] text-slate-400 mt-1 block">Full inspector audit log</span>
        </div>
      </div>

      {/* Error Alert */}
      {error && (
        <div className="rounded-2xl border border-rose-500/30 bg-rose-500/10 p-4 text-rose-200 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <AlertTriangle className="w-5 h-5 text-rose-400 shrink-0" />
            <span className="text-sm font-medium">{error}</span>
          </div>
          <button onClick={loadHistory} className="text-xs font-semibold underline hover:text-rose-100 ml-4">
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
            placeholder="Search roll ID, defect ID, or reason..."
            className="w-full rounded-xl bg-slate-950 border border-slate-700 pl-10 pr-4 py-2 text-sm text-white placeholder:text-slate-500 outline-none focus:border-blue-500 transition-colors"
          />
        </div>

        <div className="flex items-center gap-2">
          <select
            value={statusFilter}
            onChange={(e) => {
              setStatusFilter(e.target.value);
              setPage(1);
            }}
            className="rounded-xl bg-slate-950 border border-slate-700 px-3 py-2 text-xs font-semibold text-slate-200 outline-none focus:border-blue-500"
          >
            <option value="All">All Events ({allRecords.length})</option>
            <option value="Released">Released Only ({releasedCount})</option>
            <option value="Active">Active Holds ({activeCount})</option>
          </select>

          {isFiltered && (
            <button
              onClick={clearFilters}
              className="p-2 rounded-xl border border-slate-700 text-slate-400 hover:text-white hover:bg-slate-800 transition-colors"
              title="Reset Filters"
            >
              <RotateCcw className="w-4 h-4" />
            </button>
          )}
        </div>
      </div>

      {/* Main Content Area */}
      {loading ? (
        <div className="flex flex-col items-center justify-center py-20 text-slate-400 space-y-3">
          <Loader2 className="w-8 h-8 animate-spin text-blue-400" />
          <p className="text-sm font-medium">Loading historical quarantine records...</p>
        </div>
      ) : allRecords.length === 0 ? (
        <EmptyState
          icon={History}
          title="No quarantine records logged"
          description="Quarantine audit logs will appear here once inventory rolls have been placed into quality restriction."
          actionLabel="Go to Quarantine Management"
          onAction={() => navigate('/quality/quarantine')}
        />
      ) : visibleRecords.length === 0 ? (
        <EmptyState
          icon={Search}
          title="No matching quarantine records"
          description="No records match your current search and filter criteria."
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
                  <th className="px-4 py-3.5">Inventory Roll</th>
                  <th className="px-4 py-3.5">Status</th>
                  <th className="px-4 py-3.5">Quarantined On</th>
                  <th className="px-4 py-3.5">Released On</th>
                  <th className="px-4 py-3.5">Containment Reason</th>
                  <th className="px-4 py-3.5 text-right">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-800/80">
                {visibleRecords.map((r) => {
                  const isExpanded = expandedRows[r.id];
                  const released = isRecordReleased(r);
                  const createdDate = r.createdAt ? formatColomboDate(r.createdAt, 'toLocaleDateString') : 'N/A';
                  const releasedDate = r.releasedAt ? formatColomboDate(r.releasedAt, 'toLocaleDateString') : released ? 'Cleared' : '—';

                  return (
                    <React.Fragment key={r.id}>
                      <tr className="hover:bg-slate-800/40 transition-colors">
                        <td className="px-4 py-3.5 font-mono font-semibold text-cyan-300">
                          {r.inventoryRollId || 'Roll N/A'}
                        </td>
                        <td className="px-4 py-3.5">
                          <StatusBadge status={released ? 'Released' : 'Active'} />
                        </td>
                        <td className="px-4 py-3.5 text-slate-400 font-mono">
                          {createdDate}
                        </td>
                        <td className="px-4 py-3.5 text-slate-400 font-mono">
                          {releasedDate}
                        </td>
                        <td className="px-4 py-3.5 text-slate-300 max-w-xs truncate">
                          {r.reason || '—'}
                        </td>
                        <td className="px-4 py-3.5 text-right">
                          <div className="flex items-center justify-end gap-2">
                            <Link
                              to={`/quality/quarantine/${r.id}`}
                              className="p-1.5 rounded-lg text-slate-400 hover:text-blue-300 hover:bg-blue-500/10 transition-all"
                              title="Full Profile"
                            >
                              <Eye className="w-4 h-4" />
                            </Link>
                            <button
                              onClick={() => toggleRow(r.id)}
                              className="px-2.5 py-1 rounded-lg bg-slate-900 hover:bg-slate-800 text-slate-300 border border-slate-700 text-[11px] font-medium transition-colors"
                            >
                              {isExpanded ? 'Hide' : 'Audit'}
                            </button>
                          </div>
                        </td>
                      </tr>

                      {/* Expandable Audit Drawer */}
                      {isExpanded && (
                        <tr className="bg-slate-950/90">
                          <td colSpan={6} className="p-4 space-y-2 border-b border-slate-800 text-xs">
                            <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
                              <div>
                                <span className="text-slate-400 block font-semibold">Linked Defect ID</span>
                                <span className="font-mono text-blue-300">
                                  {r.defectReportId ? (
                                    <Link to={`/quality/defects/${r.defectReportId}`} className="hover:underline">
                                      #{r.defectReportId}
                                    </Link>
                                  ) : 'None'}
                                </span>
                              </div>
                              <div>
                                <span className="text-slate-400 block font-semibold">Quarantine Timestamp</span>
                                <span className="text-slate-200">
                                  {r.createdAt ? formatColomboDate(r.createdAt, 'toLocaleString') : 'N/A'}
                                </span>
                              </div>
                              <div>
                                <span className="text-slate-400 block font-semibold">Release Timestamp</span>
                                <span className={`font-semibold ${released ? 'text-emerald-400' : 'text-amber-400'}`}>
                                  {r.releasedAt ? formatColomboDate(r.releasedAt, 'toLocaleString') : released ? 'Released' : 'Active Hold'}
                                </span>
                              </div>
                            </div>
                            <div className="pt-2 border-t border-slate-800/80">
                              <span className="text-slate-400 block font-semibold mb-1">Containment / Disposition Notes:</span>
                              <p className="text-slate-300 bg-slate-900/60 p-2.5 rounded-xl border border-slate-800">
                                {r.reason || 'No specific notes recorded.'}
                              </p>
                            </div>
                          </td>
                        </tr>
                      )}
                    </React.Fragment>
                  );
                })}
              </tbody>
            </table>
          </div>

          {/* Mobile Card Layout */}
          <div className="grid md:hidden gap-3">
            {visibleRecords.map((r) => {
              const released = isRecordReleased(r);
              return (
                <div key={r.id} className="p-4 rounded-2xl bg-slate-900/60 border border-slate-800 space-y-2.5">
                  <div className="flex items-center justify-between">
                    <span className="font-mono font-bold text-cyan-300 text-xs">{r.inventoryRollId}</span>
                    <StatusBadge status={released ? 'Released' : 'Active'} />
                  </div>
                  <p className="text-xs text-slate-300 line-clamp-2">{r.reason}</p>
                  <div className="flex items-center justify-between pt-2 border-t border-slate-800 text-[11px] text-slate-400">
                    <span>{r.createdAt ? formatColomboDate(r.createdAt, 'toLocaleDateString') : ''}</span>
                    <Link to={`/quality/quarantine/${r.id}`} className="text-blue-400 font-semibold">
                      View Details
                    </Link>
                  </div>
                </div>
              );
            })}
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
    </div>
  );
}

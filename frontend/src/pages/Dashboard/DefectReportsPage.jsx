import React, { useEffect, useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import {
  PlusCircle,
  Search,
  ArrowUpDown,
  RotateCcw,
  Eye,
  Edit2,
  Trash2,
  Loader2,
  AlertTriangle,
  ClipboardList,
  ShieldAlert,
  CheckCircle2,
  Package,
  Layers
} from 'lucide-react';
import defectService from '../../services/defectService';
import quarantineService from '../../services/quarantineService';
import inventoryService from '../../services/inventoryService';
import { parseErrorMessage } from '../../utils/errorHandler';
import PageHeader from '../../components/QA/PageHeader';
import StatusBadge from '../../components/QA/StatusBadge';
import SeverityBadge from '../../components/QA/SeverityBadge';
import EmptyState from '../../components/QA/EmptyState';
import TablePagination from '../../components/QA/TablePagination';

const PAGE_SIZE = 8;
const severities = ['LOW', 'MEDIUM', 'HIGH', 'Critical'];
const statuses = ['Open', 'InReview', 'Resolved', 'Closed'];

export default function DefectReportsPage() {
  const navigate = useNavigate();
  const [defects, setDefects] = useState([]);
  const [quarantines, setQuarantines] = useState([]);
  const [inventoryRolls, setInventoryRolls] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [query, setQuery] = useState('');
  const [severity, setSeverity] = useState('All');
  const [status, setStatus] = useState('All');
  const [sort, setSort] = useState({ key: 'createdAt', direction: 'desc' });
  const [page, setPage] = useState(1);

  const loadDefects = async () => {
    setLoading(true);
    setError('');
    try {
      const [defectData, quarantineData, rollData] = await Promise.all([
        defectService.getAll(),
        quarantineService.getAll().catch(() => []),
        inventoryService.getRolls().catch(() => [])
      ]);
      setDefects(Array.isArray(defectData) ? defectData : []);
      setQuarantines(Array.isArray(quarantineData) ? quarantineData : []);
      setInventoryRolls(Array.isArray(rollData) ? rollData : []);
    } catch (err) {
      setError(parseErrorMessage(err, 'Unable to load defect reports.'));
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadDefects();
  }, []);

  const inventoryFor = (defect) => {
    if (defect.affectedInventory?.length) return defect.affectedInventory;
    return quarantines
      .filter((record) => record.defectReportId === defect.id)
      .map((record) => record.inventoryRollId);
  };

  const inventoryRollFor = (defect) => {
    const rollId = inventoryFor(defect)[0];
    const roll = inventoryRolls.find((item) => item.id === rollId);
    return roll?.rollIdentifier || roll?.id || defect.skuCode || 'Unavailable';
  };

  // Metrics
  const openDefects = defects.filter((d) => ['open', 'inreview'].includes(String(d.status).toLowerCase()));
  const criticalHighCount = defects.filter((d) => ['critical', 'high'].includes(String(d.severity).toLowerCase())).length;
  const mediumCount = defects.filter((d) => String(d.severity).toLowerCase() === 'medium').length;
  const resolvedCount = defects.filter((d) => ['resolved', 'closed'].includes(String(d.status).toLowerCase())).length;

  const isFiltered = query.trim() !== '' || severity !== 'All' || status !== 'All';

  const clearFilters = () => {
    setQuery('');
    setSeverity('All');
    setStatus('All');
    setPage(1);
  };

  const filtered = defects
    .filter((defect) => {
      const haystack = [
        inventoryRollFor(defect),
        defect.skuCode,
        defect.severity,
        defect.status,
        defect.description,
        ...inventoryFor(defect)
      ]
        .join(' ')
        .toLowerCase();

      return (
        haystack.includes(query.trim().toLowerCase()) &&
        (severity === 'All' || String(defect.severity).toLowerCase() === severity.toLowerCase()) &&
        (status === 'All' || String(defect.status).toLowerCase() === status.toLowerCase())
      );
    })
    .sort((left, right) => {
      const values = {
        createdAt: [new Date(left.createdAt).getTime(), new Date(right.createdAt).getTime()],
        severity: [left.severity, right.severity],
        inventoryRoll: [inventoryRollFor(left), inventoryRollFor(right)],
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
  const visibleDefects = filtered.slice((visiblePage - 1) * PAGE_SIZE, visiblePage * PAGE_SIZE);

  const handleSort = (key) => {
    setSort((current) =>
      current.key === key
        ? { key, direction: current.direction === 'asc' ? 'desc' : 'asc' }
        : { key, direction: 'asc' }
    );
    setPage(1);
  };

  const handleDelete = async (id) => {
    if (!window.confirm('Delete this defect report? This action cannot be undone.')) return;
    try {
      await defectService.delete(id);
      setDefects((current) => current.filter((defect) => defect.id !== id));
    } catch (err) {
      setError(parseErrorMessage(err, 'Unable to delete defect report.'));
    }
  };

  return (
    <div className="p-6 lg:p-8 max-w-7xl mx-auto space-y-6">
      {/* Page Header */}
      <PageHeader
        category="Quality Assurance"
        title="Defect Reports"
        subtitle="Track, investigate and manage manufacturing quality defects"
        actions={
          <Link
            to="/quality/defects/new"
            className="px-4 py-2.5 rounded-xl bg-gradient-to-r from-purple-600 to-violet-600 hover:from-purple-500 hover:to-violet-500 text-white text-sm font-bold shadow-lg shadow-purple-600/25 flex items-center gap-2 transition-all"
          >
            <PlusCircle className="w-4 h-4" />
            <span>Log Defect Report</span>
          </Link>
        }
      />

      {/* Top Metric Summary Cards */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <div className="p-4 rounded-2xl bg-slate-900/60 border border-slate-800 backdrop-blur-sm">
          <div className="flex items-center justify-between">
            <span className="text-xs font-bold uppercase tracking-wider text-slate-400">Total Open</span>
            <ClipboardList className="w-4 h-4 text-violet-400" />
          </div>
          <p className="text-2xl font-extrabold text-white mt-2">{openDefects.length}</p>
          <span className="text-[11px] text-slate-400 mt-1 block">Active investigation</span>
        </div>

        <div className="p-4 rounded-2xl bg-slate-900/60 border border-slate-800 backdrop-blur-sm">
          <div className="flex items-center justify-between">
            <span className="text-xs font-bold uppercase tracking-wider text-slate-400">Critical / High</span>
            <AlertTriangle className="w-4 h-4 text-rose-400" />
          </div>
          <p className="text-2xl font-extrabold text-rose-400 mt-2">{criticalHighCount}</p>
          <span className="text-[11px] text-slate-400 mt-1 block">Requires priority containment</span>
        </div>

        <div className="p-4 rounded-2xl bg-slate-900/60 border border-slate-800 backdrop-blur-sm">
          <div className="flex items-center justify-between">
            <span className="text-xs font-bold uppercase tracking-wider text-slate-400">Medium</span>
            <Layers className="w-4 h-4 text-amber-400" />
          </div>
          <p className="text-2xl font-extrabold text-amber-300 mt-2">{mediumCount}</p>
          <span className="text-[11px] text-slate-400 mt-1 block">Standard inspection</span>
        </div>

        <div className="p-4 rounded-2xl bg-slate-900/60 border border-slate-800 backdrop-blur-sm">
          <div className="flex items-center justify-between">
            <span className="text-xs font-bold uppercase tracking-wider text-slate-400">Resolved</span>
            <CheckCircle2 className="w-4 h-4 text-emerald-400" />
          </div>
          <p className="text-2xl font-extrabold text-emerald-400 mt-2">{resolvedCount}</p>
          <span className="text-[11px] text-slate-400 mt-1 block">Cleared or closed</span>
        </div>
      </div>

      {/* Error Alert */}
      {error && (
        <div className="rounded-2xl border border-rose-500/30 bg-rose-500/10 p-4 text-rose-200 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <AlertTriangle className="w-5 h-5 text-rose-400 shrink-0" />
            <span className="text-sm font-medium">{error}</span>
          </div>
          <button onClick={loadDefects} className="text-xs font-semibold underline hover:text-rose-100 ml-4">
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
            placeholder="Search SKU, roll, defect description..."
            className="w-full rounded-xl bg-slate-950 border border-slate-700 pl-10 pr-4 py-2 text-sm text-white placeholder:text-slate-500 outline-none focus:border-purple-500 transition-colors"
          />
        </div>

        <div className="flex flex-wrap items-center gap-2">
          {/* Severity Filter */}
          <select
            value={severity}
            onChange={(e) => {
              setSeverity(e.target.value);
              setPage(1);
            }}
            className="rounded-xl bg-slate-950 border border-slate-700 px-3 py-2 text-xs font-semibold text-slate-200 outline-none focus:border-purple-500"
          >
            <option value="All">All Severities</option>
            {severities.map((s) => (
              <option key={s} value={s}>{s}</option>
            ))}
          </select>

          {/* Status Filter */}
          <select
            value={status}
            onChange={(e) => {
              setStatus(e.target.value);
              setPage(1);
            }}
            className="rounded-xl bg-slate-950 border border-slate-700 px-3 py-2 text-xs font-semibold text-slate-200 outline-none focus:border-purple-500"
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
          <Loader2 className="w-8 h-8 animate-spin text-purple-400" />
          <p className="text-sm font-medium">Loading defect telemetry...</p>
        </div>
      ) : defects.length === 0 ? (
        <EmptyState
          icon={ClipboardList}
          title="No defect reports found"
          description="No quality defects have been logged yet. Click below to record a defect."
          actionLabel="Log Defect"
          onAction={() => navigate('/quality/defects/new')}
        />
      ) : visibleDefects.length === 0 ? (
        <EmptyState
          icon={Search}
          title="No matching defects"
          description="No defects match your current search and filter parameters."
          actionLabel="Reset Filters"
          onAction={clearFilters}
        />
      ) : (
        <div className="space-y-4">
          {/* Desktop Table View */}
          <div className="hidden md:block rounded-2xl border border-slate-800 bg-slate-900/60 backdrop-blur-sm overflow-hidden shadow-sm">
            <table className="w-full text-left border-collapse text-xs">
              <thead>
                <tr className="border-b border-slate-800 bg-slate-900/90 text-[11px] font-bold uppercase tracking-wider text-slate-400">
                  <th className="px-4 py-3.5">Defect ID</th>
                  <th className="px-4 py-3.5">SKU / Roll</th>
                  <th className="px-4 py-3.5">Severity</th>
                  <th className="px-4 py-3.5">Status</th>
                  <th className="px-4 py-3.5">Description</th>
                  <th className="px-4 py-3.5 cursor-pointer hover:text-white" onClick={() => handleSort('createdAt')}>
                    <div className="flex items-center gap-1">
                      <span>Logged</span>
                      <ArrowUpDown className="w-3.5 h-3.5" />
                    </div>
                  </th>
                  <th className="px-4 py-3.5 text-right">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-800/80">
                {visibleDefects.map((d) => (
                  <tr key={d.id} className="hover:bg-slate-800/40 transition-colors group">
                    <td className="px-4 py-3.5 font-mono font-semibold text-purple-300">
                      #{d.id.substring(0, 8)}
                    </td>
                    <td className="px-4 py-3.5">
                      <span className="font-mono text-cyan-300 font-medium">{inventoryRollFor(d)}</span>
                    </td>
                    <td className="px-4 py-3.5">
                      <SeverityBadge severity={d.severity} />
                    </td>
                    <td className="px-4 py-3.5">
                      <StatusBadge status={d.status} />
                    </td>
                    <td className="px-4 py-3.5 text-slate-300 max-w-xs truncate">
                      {d.description || '—'}
                    </td>
                    <td className="px-4 py-3.5 text-slate-400">
                      {d.createdAt ? new Date(d.createdAt).toLocaleDateString() : 'N/A'}
                    </td>
                    <td className="px-4 py-3.5 text-right">
                      <div className="flex items-center justify-end gap-1.5 opacity-90 group-hover:opacity-100">
                        <Link
                          to={`/quality/defects/${d.id}`}
                          className="p-1.5 rounded-lg text-slate-400 hover:text-cyan-300 hover:bg-cyan-500/10 border border-transparent hover:border-cyan-500/20 transition-all"
                          title="View Detail"
                        >
                          <Eye className="w-4 h-4" />
                        </Link>
                        <Link
                          to={`/quality/defects/${d.id}/edit`}
                          className="p-1.5 rounded-lg text-slate-400 hover:text-purple-300 hover:bg-purple-500/10 border border-transparent hover:border-purple-500/20 transition-all"
                          title="Edit"
                        >
                          <Edit2 className="w-4 h-4" />
                        </Link>
                        <button
                          onClick={() => handleDelete(d.id)}
                          className="p-1.5 rounded-lg text-slate-400 hover:text-rose-400 hover:bg-rose-500/10 border border-transparent hover:border-rose-500/20 transition-all"
                          title="Delete"
                        >
                          <Trash2 className="w-4 h-4" />
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          {/* Mobile Card Layout */}
          <div className="grid md:hidden gap-3">
            {visibleDefects.map((d) => (
              <div key={d.id} className="p-4 rounded-2xl bg-slate-900/60 border border-slate-800 space-y-3">
                <div className="flex items-center justify-between">
                  <span className="font-mono font-bold text-purple-300 text-xs">#{d.id.substring(0, 8)}</span>
                  <StatusBadge status={d.status} />
                </div>
                <div className="flex items-center justify-between text-xs">
                  <span className="font-mono text-cyan-300">{inventoryRollFor(d)}</span>
                  <SeverityBadge severity={d.severity} />
                </div>
                <p className="text-xs text-slate-300 line-clamp-2">{d.description}</p>
                <div className="flex items-center justify-between pt-2 border-t border-slate-800 text-[11px] text-slate-400">
                  <span>{d.createdAt ? new Date(d.createdAt).toLocaleDateString() : ''}</span>
                  <div className="flex items-center gap-2">
                    <Link to={`/quality/defects/${d.id}`} className="text-cyan-400 font-semibold">View</Link>
                    <Link to={`/quality/defects/${d.id}/edit`} className="text-purple-400 font-semibold">Edit</Link>
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
    </div>
  );
}
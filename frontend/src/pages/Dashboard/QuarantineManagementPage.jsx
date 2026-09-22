import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import {
  History,
  Search,
  ArrowUpDown,
  ArrowUp,
  ArrowDown,
  RotateCcw,
  Eye,
  Loader2,
  AlertTriangle,
  ShieldAlert
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

  const loadQuarantines = async () => {
    setLoading(true);
    setError('');
    try {
      const [quarantineData, defectData] = await Promise.all([
        quarantineService.getAll(),
        defectService.getAll()
      ]);
      setRecords(quarantineData);
      setDefects(defectData);
    } catch (err) {
      setError(parseErrorMessage(err, 'Unable to load quarantine records.'));
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadQuarantines();
  }, []);

  const severityFor = (record) =>
    defects.find((defect) => defect.id === record.defectReportId)?.severity || 'Unknown';

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
        record.batchId,
        record.inventoryRollId,
        record.reason,
        record.status,
        recordSeverity
      ]
        .join(' ')
        .toLowerCase();

      return (
        text.includes(query.trim().toLowerCase()) &&
        (severity === 'All' || recordSeverity === severity) &&
        (status === 'All' || record.status === status)
      );
    })
    .sort((left, right) => {
      const values = {
        createdAt: [new Date(left.createdAt).getTime(), new Date(right.createdAt).getTime()],
        severity: [severityFor(left), severityFor(right)],
        batchId: [left.batchId, right.batchId],
        status: [left.status, right.status]
      }[sort.key];
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

  const sortButtons = [
    { key: 'createdAt', label: 'Date' },
    { key: 'batchId', label: 'Batch' },
    { key: 'severity', label: 'Severity' },
    { key: 'status', label: 'Status' }
  ];

  return (
    <div className="p-6 lg:p-8 max-w-7xl mx-auto space-y-6">
      {/* Page Header */}
      <PageHeader
        category="Quality Assurance"
        title="Quarantine Management"
        subtitle="Review and manage inventory currently under quality hold."
        actions={
          <button
            onClick={() => navigate('/quality/quarantine/history')}
            className="px-4 py-2.5 rounded-xl border border-cyan-500/40 bg-cyan-500/10 text-cyan-300 text-sm font-semibold hover:bg-cyan-500/20 transition-all shadow-sm flex items-center gap-2"
          >
            <History className="w-4 h-4" />
            <span>History</span>
          </button>
        }
      />

      {/* Error Alert */}
      {error && (
        <div className="rounded-2xl border border-rose-500/30 bg-rose-500/10 p-4 text-rose-200 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <AlertTriangle className="w-5 h-5 text-rose-400 shrink-0" />
            <span className="text-sm font-medium">{error}</span>
          </div>
          <button
            onClick={loadQuarantines}
            className="text-xs font-semibold underline hover:text-rose-100 ml-4"
          >
            Retry
          </button>
        </div>
      )}

      {/* Filter Toolbar */}
      <div className="rounded-2xl border border-slate-800 bg-slate-900/60 p-5 backdrop-blur-sm space-y-4">
        <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-12 items-center">
          {/* Search Input */}
          <div className="relative sm:col-span-2 lg:col-span-6">
            <Search className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" />
            <input
              value={query}
              onChange={(e) => {
                setQuery(e.target.value);
                setPage(1);
              }}
              placeholder="Search batch, inventory, reason..."
              className="w-full rounded-xl bg-slate-950 border border-slate-700 pl-10 pr-4 py-2.5 text-sm text-white placeholder:text-slate-500 outline-none focus:border-purple-500 transition-colors"
            />
          </div>

          {/* Severity Filter */}
          <div className="lg:col-span-3">
            <select
              value={severity}
              onChange={(e) => {
                setSeverity(e.target.value);
                setPage(1);
              }}
              className="w-full rounded-xl bg-slate-950 border border-slate-700 px-3.5 py-2.5 text-sm text-white outline-none focus:border-purple-500 transition-colors"
            >
              <option value="All">All Severities</option>
              {severities.map((val) => (
                <option key={val} value={val}>
                  {val}
                </option>
              ))}
            </select>
          </div>

          {/* Status Filter */}
          <div className="lg:col-span-2">
            <select
              value={status}
              onChange={(e) => {
                setStatus(e.target.value);
                setPage(1);
              }}
              className="w-full rounded-xl bg-slate-950 border border-slate-700 px-3.5 py-2.5 text-sm text-white outline-none focus:border-purple-500 transition-colors"
            >
              <option value="All">All Statuses</option>
              {statuses.map((val) => (
                <option key={val} value={val}>
                  {val}
                </option>
              ))}
            </select>
          </div>

          {/* Reset Filters */}
          {isFiltered && (
            <div className="lg:col-span-1 flex justify-end">
              <button
                onClick={clearFilters}
                title="Reset filters"
                className="w-full flex items-center justify-center gap-1.5 px-3 py-2.5 rounded-xl border border-slate-700 bg-slate-800 text-slate-300 hover:text-white hover:bg-slate-700 text-xs font-medium transition-all"
              >
                <RotateCcw className="w-3.5 h-3.5" />
                <span className="lg:hidden">Reset</span>
              </button>
            </div>
          )}
        </div>

        {/* Sort Bar */}
        <div className="flex flex-wrap items-center justify-between gap-3 pt-3 border-t border-slate-800/80 text-xs text-slate-400">
          <div className="flex items-center gap-2">
            <span className="font-semibold text-slate-400 uppercase tracking-wider">Sort By:</span>
            <div className="flex flex-wrap items-center gap-1.5">
              {sortButtons.map(({ key, label }) => {
                const isActive = sort.key === key;
                return (
                  <button
                    key={key}
                    onClick={() => handleSort(key)}
                    className={`inline-flex items-center gap-1 px-3 py-1.5 rounded-lg border text-xs font-medium transition-all ${
                      isActive
                        ? 'border-purple-500/50 bg-purple-500/10 text-purple-300 font-bold'
                        : 'border-slate-800 bg-slate-950 text-slate-400 hover:text-slate-200 hover:border-slate-700'
                    }`}
                  >
                    <span>{label}</span>
                    {isActive ? (
                      sort.direction === 'asc' ? (
                        <ArrowUp className="w-3 h-3" />
                      ) : (
                        <ArrowDown className="w-3 h-3" />
                      )
                    ) : (
                      <ArrowUpDown className="w-3 h-3 opacity-40" />
                    )}
                  </button>
                );
              })}
            </div>
          </div>

          <div className="text-slate-400">
            {filtered.length} quarantine record{filtered.length === 1 ? '' : 's'} found
          </div>
        </div>
      </div>

      {/* Loading State */}
      {loading ? (
        <div className="flex flex-col items-center justify-center py-20 text-slate-400 space-y-3">
          <Loader2 className="w-8 h-8 animate-spin text-purple-400" />
          <p className="text-sm font-medium">Loading quarantine and hold records...</p>
        </div>
      ) : visibleRecords.length === 0 ? (
        /* Empty State */
        <EmptyState
          icon={ShieldAlert}
          title="No quarantine records"
          description={
            isFiltered
              ? 'There are currently no quality holds matching the selected filters.'
              : 'There are currently no inventory holds registered in the system.'
          }
          actionLabel={isFiltered ? 'Clear Filters' : undefined}
          onAction={isFiltered ? clearFilters : undefined}
        />
      ) : (
        /* Data Table */
        <div className="rounded-2xl border border-slate-800 bg-slate-900/60 backdrop-blur-sm overflow-hidden shadow-sm">
          <div className="overflow-x-auto">
            <table className="w-full text-left border-collapse text-sm">
              <thead>
                <tr className="border-b border-slate-800 bg-slate-900/90 text-xs font-bold uppercase tracking-wider text-slate-400">
                  <th className="px-5 py-4">Inventory Rolls</th>
                  <th className="px-5 py-4">Severity</th>
                  <th className="px-5 py-4">Reason</th>
                  <th className="px-5 py-4">Created</th>
                  <th className="px-5 py-4">Status</th>
                  <th className="px-5 py-4">Released</th>
                  <th className="px-5 py-4 text-right">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-800/80">
                {visibleRecords.map((record) => (
                  <tr
                    key={record.id}
                    className="hover:bg-slate-800/40 transition-colors group"
                  >
                    {/* Inventory Rolls */}
                    <td className="px-5 py-4 text-slate-300 font-mono text-xs">
                      {record.inventoryRollId}
                    </td>

                    {/* Severity */}
                    <td className="px-5 py-4">
                      <SeverityBadge severity={severityFor(record)} />
                    </td>

                    {/* Reason */}
                    <td className="px-5 py-4 text-slate-300 text-xs max-w-xs truncate" title={record.reason}>
                      {record.reason}
                    </td>

                    {/* Created */}
                    <td className="px-5 py-4 text-slate-400 text-xs whitespace-nowrap">
                      {new Date(record.createdAt).toLocaleString(undefined, {
                        month: 'short',
                        day: 'numeric',
                        hour: '2-digit',
                        minute: '2-digit'
                      })}
                    </td>

                    {/* Status */}
                    <td className="px-5 py-4">
                      <StatusBadge status={record.status} />
                    </td>

                    {/* Released */}
                    <td className="px-5 py-4 text-slate-400 text-xs whitespace-nowrap">
                      {record.releasedAt ? (
                        new Date(record.releasedAt).toLocaleString(undefined, {
                          month: 'short',
                          day: 'numeric',
                          hour: '2-digit',
                          minute: '2-digit'
                        })
                      ) : (
                        <span className="text-slate-500">Not released</span>
                      )}
                    </td>

                    {/* Actions */}
                    <td className="px-5 py-4 text-right">
                      <button
                        onClick={() => navigate(`/quality/quarantine/${record.id}`)}
                        title="View quarantine details"
                        className="inline-flex items-center gap-1 px-3 py-1.5 rounded-lg border border-slate-700 bg-slate-900/60 text-slate-300 hover:bg-slate-800 hover:text-white text-xs font-medium transition-all"
                      >
                        <Eye className="w-3.5 h-3.5" />
                        <span>View</span>
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          {/* Pagination */}
          <div className="border-t border-slate-800/80 px-4">
            <TablePagination
              currentPage={visiblePage}
              totalPages={totalPages}
              totalResults={filtered.length}
              pageSize={PAGE_SIZE}
              onPageChange={setPage}
            />
          </div>
        </div>
      )}
    </div>
  );
}
import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import {
  ArrowLeft,
  History,
  Search,
  Loader2,
  AlertTriangle
} from 'lucide-react';
import quarantineService from '../../services/quarantineService';
import { parseErrorMessage } from '../../utils/errorHandler';
import PageHeader from '../../components/QA/PageHeader';
import StatusBadge from '../../components/QA/StatusBadge';
import EmptyState from '../../components/QA/EmptyState';
import TablePagination from '../../components/QA/TablePagination';

const PAGE_SIZE = 8;

export default function QuarantineHistoryPage() {
  const navigate = useNavigate();
  const [records, setRecords] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [query, setQuery] = useState('');
  const [page, setPage] = useState(1);

  const loadHistory = async () => {
    setLoading(true);
    setError('');
    try {
      const data = await quarantineService.getAll();
      setRecords(data.filter((record) => record.status === 'Released'));
    } catch (err) {
      setError(parseErrorMessage(err, 'Unable to load quarantine history.'));
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadHistory();
  }, []);

  const filtered = records.filter((record) => {
    const text = [record.inventoryRollId, record.batchId, record.reason, record.status]
      .join(' ')
      .toLowerCase();
    return text.includes(query.trim().toLowerCase());
  });

  const totalPages = Math.max(1, Math.ceil(filtered.length / PAGE_SIZE));
  const visiblePage = Math.min(page, totalPages);
  const visibleRecords = filtered.slice((visiblePage - 1) * PAGE_SIZE, visiblePage * PAGE_SIZE);

  return (
    <div className="p-6 lg:p-8 max-w-7xl mx-auto space-y-6">
      {/* Page Header */}
      <PageHeader
        category="Quality Assurance"
        title="Quarantine History"
        subtitle="Review previously released quality holds."
        actions={
          <button
            onClick={() => navigate('/quality/quarantine')}
            className="px-4 py-2.5 rounded-xl border border-slate-700 bg-slate-900/60 text-slate-200 text-sm font-medium hover:bg-slate-800 hover:text-white transition-all shadow-sm flex items-center gap-2"
          >
            <ArrowLeft className="w-4 h-4" />
            <span>Back to Quarantine</span>
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
            onClick={loadHistory}
            className="text-xs font-semibold underline hover:text-rose-100 ml-4"
          >
            Retry
          </button>
        </div>
      )}

      {/* Search and Summary Toolbar */}
      {records.length > 0 && (
        <div className="flex flex-col sm:flex-row items-center justify-between gap-4 rounded-2xl border border-slate-800 bg-slate-900/60 p-4 backdrop-blur-sm">
          <div className="relative w-full sm:w-80">
            <Search className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" />
            <input
              value={query}
              onChange={(e) => {
                setQuery(e.target.value);
                setPage(1);
              }}
              placeholder="Filter released inventory, batch, reason..."
              className="w-full rounded-xl bg-slate-950 border border-slate-700 pl-10 pr-4 py-2 text-sm text-white placeholder:text-slate-500 outline-none focus:border-purple-500 transition-colors"
            />
          </div>
          <div className="text-xs text-slate-400">
            Showing <span className="text-white font-semibold">{filtered.length}</span> released audit records
          </div>
        </div>
      )}

      {/* Loading State */}
      {loading ? (
        <div className="flex flex-col items-center justify-center py-20 text-slate-400 space-y-3">
          <Loader2 className="w-8 h-8 animate-spin text-purple-400" />
          <p className="text-sm font-medium">Loading historical quarantine records...</p>
        </div>
      ) : records.length === 0 ? (
        /* Empty State */
        <EmptyState
          icon={History}
          title="No quarantine history"
          description="Released quality-hold records will appear here once quarantine actions have been completed."
        />
      ) : visibleRecords.length === 0 ? (
        <EmptyState
          icon={History}
          title="No matching history records"
          description="No released quarantine records match your search query."
          actionLabel="Clear Search"
          onAction={() => setQuery('')}
        />
      ) : (
        /* Data Table */
        <div className="rounded-2xl border border-slate-800 bg-slate-900/60 backdrop-blur-sm overflow-hidden shadow-sm">
          <div className="overflow-x-auto">
            <table className="w-full text-left border-collapse text-sm">
              <thead>
                <tr className="border-b border-slate-800 bg-slate-900/90 text-xs font-bold uppercase tracking-wider text-slate-400">
                  <th className="px-5 py-4">Inventory</th>
                  <th className="px-5 py-4">Batch</th>
                  <th className="px-5 py-4">Status</th>
                  <th className="px-5 py-4">Released At</th>
                  <th className="px-5 py-4">Disposition Reason</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-800/80">
                {visibleRecords.map((record) => (
                  <tr
                    key={record.id}
                    className="hover:bg-slate-800/40 transition-colors group"
                  >
                    {/* Inventory */}
                    <td className="px-5 py-4 font-mono font-bold text-white tracking-tight">
                      {record.inventoryRollId}
                    </td>

                    {/* Batch */}
                    <td className="px-5 py-4 text-slate-300 font-mono text-xs">
                      {record.batchId}
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
                        '—'
                      )}
                    </td>

                    {/* Reason */}
                    <td className="px-5 py-4 text-slate-300 text-xs max-w-md">
                      {record.reason}
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

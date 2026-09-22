import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import {
  PlusCircle,
  Search,
  ArrowUpDown,
  ArrowUp,
  ArrowDown,
  RotateCcw,
  Eye,
  Edit2,
  Trash2,
  Loader2,
  AlertTriangle,
  ClipboardList
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
const productTypes = ['BoxPouch', 'BiscuitPackaging', 'TeaBag', 'Bag', 'Can', 'Bottle'];
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
  const [productType, setProductType] = useState('All');
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
        quarantineService.getAll(),
        inventoryService.getRolls()
      ]);
      setDefects(defectData);
      setQuarantines(quarantineData);
      setInventoryRolls(rollData);
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
    return roll?.rollIdentifier || roll?.id || 'Unavailable';
  };

  const isFiltered = query.trim() !== '' || productType !== 'All' || severity !== 'All' || status !== 'All';

  const clearFilters = () => {
    setQuery('');
    setProductType('All');
    setSeverity('All');
    setStatus('All');
    setPage(1);
  };

  const filtered = defects
    .filter((defect) => {
      const haystack = [
        defect.batchId,
        inventoryRollFor(defect),
        defect.productType,
        defect.severity,
        defect.status,
        defect.description,
        ...inventoryFor(defect)
      ]
        .join(' ')
        .toLowerCase();

      return (
        haystack.includes(query.trim().toLowerCase()) &&
        (productType === 'All' || defect.productType === productType) &&
        (severity === 'All' || defect.severity === severity) &&
        (status === 'All' || defect.status === status)
      );
    })
    .sort((left, right) => {
      const values = {
        createdAt: [new Date(left.createdAt).getTime(), new Date(right.createdAt).getTime()],
        severity: [left.severity, right.severity],
        inventoryRoll: [inventoryRollFor(left), inventoryRollFor(right)],
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

  const sortButtons = [
    { key: 'createdAt', label: 'Date' },
    { key: 'inventoryRoll', label: 'Inventory Roll' },
    { key: 'severity', label: 'Severity' },
    { key: 'status', label: 'Status' }
  ];

  return (
    <div className="p-6 lg:p-8 max-w-7xl mx-auto space-y-6">
      {/* Page Header */}
      <PageHeader
        category="Quality Assurance"
        title="Defect Reports"
        subtitle="Monitor and review reported quality issues."
        actions={
          <button
            onClick={() => navigate('/quality/defects/new')}
            className="px-5 py-2.5 rounded-xl bg-purple-600 text-white font-bold text-sm hover:bg-purple-500 transition-all shadow-lg shadow-purple-600/25 flex items-center gap-2"
          >
            <PlusCircle className="w-4 h-4 stroke-[2.5]" />
            <span>+ Create Defect</span>
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
            onClick={loadDefects}
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
          <div className="relative sm:col-span-2 lg:col-span-4">
            <Search className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" />
            <input
              value={query}
              onChange={(e) => {
                setQuery(e.target.value);
                setPage(1);
              }}
              placeholder="Search inventory roll, description..."
              className="w-full rounded-xl bg-slate-950 border border-slate-700 pl-10 pr-4 py-2.5 text-sm text-white placeholder:text-slate-500 outline-none focus:border-purple-500 transition-colors"
            />
          </div>

          {/* Product Filter */}
          <div className="lg:col-span-3">
            <select
              value={productType}
              onChange={(e) => {
                setProductType(e.target.value);
                setPage(1);
              }}
              className="w-full rounded-xl bg-slate-950 border border-slate-700 px-3.5 py-2.5 text-sm text-white outline-none focus:border-purple-500 transition-colors"
            >
              <option value="All">All Product Types</option>
              {productTypes.map((val) => (
                <option key={val} value={val}>
                  {val}
                </option>
              ))}
            </select>
          </div>

          {/* Severity Filter */}
          <div className="lg:col-span-2">
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
            {filtered.length} defect report{filtered.length === 1 ? '' : 's'} found
          </div>
        </div>
      </div>

      {/* Loading State */}
      {loading ? (
        <div className="flex flex-col items-center justify-center py-20 text-slate-400 space-y-3">
          <Loader2 className="w-8 h-8 animate-spin text-purple-400" />
          <p className="text-sm font-medium">Loading defect telemetry and inspection reports...</p>
        </div>
      ) : visibleDefects.length === 0 ? (
        /* Empty State */
        <EmptyState
          icon={ClipboardList}
          title="No defect reports"
          description={
            isFiltered
              ? 'No quality defects match the selected filter criteria.'
              : 'There are currently no defect reports logged in the system.'
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
                  <th className="px-5 py-4">Inventory Roll</th>
                  <th className="px-5 py-4">Product</th>
                  <th className="px-5 py-4">Severity</th>
                  <th className="px-5 py-4">Status</th>
                  <th className="px-5 py-4">Reported By</th>
                  <th className="px-5 py-4">Affected Inventory</th>
                  <th className="px-5 py-4">Created</th>
                  <th className="px-5 py-4 text-right">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-800/80">
                {visibleDefects.map((defect) => {
                  const inv = inventoryFor(defect);
                  return (
                    <tr
                      key={defect.id}
                      className="hover:bg-slate-800/40 transition-colors group"
                    >
                      {/* SKU */}
                      <td className="px-5 py-4 font-mono font-bold text-white tracking-tight">
                        {inventoryRollFor(defect)}
                      </td>

                      {/* Product */}
                      <td className="px-5 py-4 text-slate-300 font-medium">
                        {defect.productType}
                      </td>

                      {/* Severity */}
                      <td className="px-5 py-4">
                        <SeverityBadge severity={defect.severity} />
                      </td>

                      {/* Status */}
                      <td className="px-5 py-4">
                        <StatusBadge status={defect.status} />
                      </td>

                      {/* Reported By */}
                      <td className="px-5 py-4 text-slate-400 text-xs font-mono">
                        {defect.reportedByUserId || 'System'}
                      </td>

                      {/* Affected Inventory */}
                      <td className="px-5 py-4 text-slate-400 text-xs font-mono">
                        {inv.length > 0 ? (
                          <span className="inline-block truncate max-w-[180px]" title={inv.join(', ')}>
                            {inv.join(', ')}
                          </span>
                        ) : (
                          <span className="text-slate-500">—</span>
                        )}
                      </td>

                      {/* Created */}
                      <td className="px-5 py-4 text-slate-400 text-xs whitespace-nowrap">
                        {new Date(defect.createdAt).toLocaleString(undefined, {
                          month: 'short',
                          day: 'numeric',
                          hour: '2-digit',
                          minute: '2-digit'
                        })}
                      </td>

                      {/* Actions */}
                      <td className="px-5 py-4 text-right">
                        <div className="flex items-center justify-end gap-1.5">
                          <button
                            onClick={() => navigate(`/quality/defects/${defect.id}`)}
                            title="View defect details"
                            className="inline-flex items-center gap-1 px-2.5 py-1.5 rounded-lg border border-slate-700 bg-slate-900/60 text-slate-300 hover:bg-slate-800 hover:text-white text-xs font-medium transition-all"
                          >
                            <Eye className="w-3.5 h-3.5" />
                            <span>View</span>
                          </button>
                          <button
                            onClick={() => navigate(`/quality/defects/${defect.id}/edit`)}
                            title="Edit defect"
                            className="inline-flex items-center gap-1 px-2.5 py-1.5 rounded-lg border border-cyan-500/40 bg-cyan-500/10 text-cyan-300 hover:bg-cyan-500/20 text-xs font-medium transition-all"
                          >
                            <Edit2 className="w-3.5 h-3.5" />
                            <span>Edit</span>
                          </button>
                          <button
                            onClick={() => handleDelete(defect.id)}
                            title="Delete defect"
                            className="inline-flex items-center gap-1 px-2.5 py-1.5 rounded-lg border border-rose-500/40 bg-rose-500/10 text-rose-300 hover:bg-rose-500/20 text-xs font-medium transition-all"
                          >
                            <Trash2 className="w-3.5 h-3.5" />
                            <span>Delete</span>
                          </button>
                        </div>
                      </td>
                    </tr>
                  );
                })}
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
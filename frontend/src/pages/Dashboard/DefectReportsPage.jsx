import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import defectService from '../../services/defectService';
import quarantineService from '../../services/quarantineService';
import { parseErrorMessage } from '../../utils/errorHandler';
import QANavigation from '../../components/Dashboard/QANavigation';

const PAGE_SIZE = 8;
const productTypes = ['BoxPouch', 'BiscuitPackaging', 'TeaBag', 'Bag', 'Can', 'Bottle'];
const severities = ['LOW', 'MEDIUM', 'HIGH', 'CRITICAL'];
const statuses = ['Open', 'InReview', 'Resolved', 'Closed'];

export default function DefectReportsPage() {
  const navigate = useNavigate();
  const [defects, setDefects] = useState([]);
  const [quarantines, setQuarantines] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [query, setQuery] = useState('');
  const [productType, setProductType] = useState('All');
  const [severity, setSeverity] = useState('All');
  const [status, setStatus] = useState('All');
  const [sort, setSort] = useState({ key: 'createdAt', direction: 'desc' });
  const [page, setPage] = useState(1);

  useEffect(() => {
    const load = async () => {
      try {
        const [defectData, quarantineData] = await Promise.all([defectService.getAll(), quarantineService.getAll()]);
        setDefects(defectData);
        setQuarantines(quarantineData);
      } catch (err) {
        setError(parseErrorMessage(err, 'Unable to load defect reports.'));
      } finally {
        setLoading(false);
      }
    };
    load();
  }, []);

  const inventoryFor = (defectId) => quarantines.filter((record) => record.defectReportId === defectId).map((record) => record.inventoryRollId);

  const filtered = defects.filter((defect) => {
    const haystack = [defect.batchId, defect.productType, defect.severity, defect.status, defect.description, ...inventoryFor(defect.id)].join(' ').toLowerCase();
    return haystack.includes(query.trim().toLowerCase())
      && (productType === 'All' || defect.productType === productType)
      && (severity === 'All' || defect.severity === severity)
      && (status === 'All' || defect.status === status);
  }).sort((left, right) => {
    const values = {
      createdAt: [new Date(left.createdAt).getTime(), new Date(right.createdAt).getTime()],
      severity: [left.severity, right.severity],
      batchId: [left.batchId, right.batchId],
      status: [left.status, right.status]
    }[sort.key];
    const comparison = typeof values[0] === 'number' ? values[0] - values[1] : String(values[0]).localeCompare(String(values[1]));
    return sort.direction === 'asc' ? comparison : -comparison;
  });

  const totalPages = Math.max(1, Math.ceil(filtered.length / PAGE_SIZE));
  const visiblePage = Math.min(page, totalPages);
  const visibleDefects = filtered.slice((visiblePage - 1) * PAGE_SIZE, visiblePage * PAGE_SIZE);
  const updateView = (setter) => (event) => { setter(event.target.value); setPage(1); };
  const handleSort = (key) => {
    setSort((current) => current.key === key ? { key, direction: current.direction === 'asc' ? 'desc' : 'asc' } : { key, direction: 'asc' });
    setPage(1);
  };
  const handleDelete = async (id) => {
    if (!window.confirm('Delete this defect report?')) return;
    try {
      await defectService.delete(id);
      setDefects((current) => current.filter((defect) => defect.id !== id));
    } catch (err) {
      setError(parseErrorMessage(err, 'Unable to delete defect report.'));
    }
  };

  return (
    <div className="min-h-screen bg-slate-950 text-slate-100 p-8">
      <div className="max-w-7xl mx-auto">
        <QANavigation />
        <div className="flex flex-wrap items-center justify-between gap-4 mb-8"><div><p className="text-emerald-400 uppercase tracking-wide text-sm font-semibold">Quality Assurance</p><h1 className="text-4xl font-bold mt-2">Defect Reports</h1></div><button onClick={() => navigate('/quality/defects/new')} className="px-4 py-2 rounded-xl bg-emerald-500 text-slate-950 font-bold hover:bg-emerald-400">+ Create Defect</button></div>
        {error && <div className="mb-4 p-3 rounded bg-red-500/10 text-red-300 border border-red-500/30">{error}</div>}
        <div className="mb-6 grid gap-3 md:grid-cols-2 xl:grid-cols-5">
          <input value={query} onChange={updateView(setQuery)} placeholder="Search batch, description, inventory..." className="xl:col-span-2 rounded-xl bg-slate-900 border border-slate-700 px-4 py-3 text-white outline-none focus:border-emerald-500" />
          <select value={productType} onChange={updateView(setProductType)} className="rounded-xl bg-slate-900 border border-slate-700 px-4 py-3 text-white"><option>All</option>{productTypes.map((value) => <option key={value}>{value}</option>)}</select>
          <select value={severity} onChange={updateView(setSeverity)} className="rounded-xl bg-slate-900 border border-slate-700 px-4 py-3 text-white"><option>All</option>{severities.map((value) => <option key={value}>{value}</option>)}</select>
          <select value={status} onChange={updateView(setStatus)} className="rounded-xl bg-slate-900 border border-slate-700 px-4 py-3 text-white"><option>All</option>{statuses.map((value) => <option key={value}>{value}</option>)}</select>
        </div>
        <div className="mb-3 flex flex-wrap items-center gap-2 text-sm text-slate-400"><span>Sort by:</span>{['createdAt', 'severity', 'batchId', 'status'].map((key) => <button key={key} onClick={() => handleSort(key)} className="rounded-lg border border-slate-700 px-3 py-1 hover:bg-slate-800">{key === 'createdAt' ? 'Date' : key === 'batchId' ? 'Batch' : key}{sort.key === key ? ` ${sort.direction === 'asc' ? '^' : 'v'}` : ''}</button>)}<span className="ml-auto">{filtered.length} result{filtered.length === 1 ? '' : 's'}</span></div>
        {loading ? <div className="text-slate-400">Loading defects...</div> : <div className="overflow-x-auto rounded-2xl border border-slate-800"><table className="min-w-full divide-y divide-slate-800"><thead className="bg-slate-900"><tr>{['Batch', 'Product', 'Severity', 'Status', 'Reported By', 'Affected Inventory', 'Created', 'Actions'].map((heading) => <th key={heading} className="px-5 py-3 text-left text-xs font-semibold uppercase tracking-wider">{heading}</th>)}</tr></thead><tbody className="divide-y divide-slate-800">{visibleDefects.length === 0 ? <tr><td className="px-5 py-8 text-slate-400" colSpan="8">No defect reports match the current view.</td></tr> : visibleDefects.map((defect) => <tr key={defect.id} className="hover:bg-slate-900/60"><td className="px-5 py-4 font-medium text-white">{defect.batchId}</td><td className="px-5 py-4 text-slate-300">{defect.productType}</td><td className="px-5 py-4">{defect.severity}</td><td className="px-5 py-4 text-slate-300">{defect.status}</td><td className="px-5 py-4 text-slate-400">{defect.reportedByUserId || 'Unavailable'}</td><td className="px-5 py-4 text-slate-400">{inventoryFor(defect.id).join(', ') || 'None'}</td><td className="px-5 py-4 text-slate-400">{new Date(defect.createdAt).toLocaleString()}</td><td className="px-5 py-4"><div className="flex gap-2"><button onClick={() => navigate(`/quality/defects/${defect.id}`)} className="px-3 py-1 rounded-lg border border-slate-600 hover:bg-slate-800">View</button><button onClick={() => navigate(`/quality/defects/${defect.id}/edit`)} className="px-3 py-1 rounded-lg border border-cyan-500 text-cyan-300 hover:bg-cyan-500/10">Edit</button><button onClick={() => handleDelete(defect.id)} className="px-3 py-1 rounded-lg border border-rose-500 text-rose-300 hover:bg-rose-500/10">Delete</button></div></td></tr>)}</tbody></table></div>}
        <div className="mt-4 flex items-center justify-between text-sm text-slate-400"><button disabled={visiblePage <= 1} onClick={() => setPage((current) => current - 1)} className="rounded-lg border border-slate-700 px-3 py-2 disabled:opacity-40">Previous</button><span>Page {visiblePage} of {totalPages}</span><button disabled={visiblePage >= totalPages} onClick={() => setPage((current) => current + 1)} className="rounded-lg border border-slate-700 px-3 py-2 disabled:opacity-40">Next</button></div>
      </div>
    </div>
  );
}
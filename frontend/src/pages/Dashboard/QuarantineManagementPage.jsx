import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import quarantineService from '../../services/quarantineService';
import defectService from '../../services/defectService';
import { parseErrorMessage } from '../../utils/errorHandler';
import QANavigation from '../../components/Dashboard/QANavigation';

const PAGE_SIZE = 8;
const severities = ['LOW', 'MEDIUM', 'HIGH', 'CRITICAL'];
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

  useEffect(() => {
    const load = async () => {
      try {
        const [quarantineData, defectData] = await Promise.all([quarantineService.getAll(), defectService.getAll()]);
        setRecords(quarantineData);
        setDefects(defectData);
      } catch (err) {
        setError(parseErrorMessage(err, 'Unable to load quarantine records.'));
      } finally {
        setLoading(false);
      }
    };
    load();
  }, []);

  const severityFor = (record) => defects.find((defect) => defect.id === record.defectReportId)?.severity || 'Unknown';
  const filtered = records.filter((record) => {
    const recordSeverity = severityFor(record);
    const text = [record.batchId, record.inventoryRollId, record.reason, record.status, recordSeverity].join(' ').toLowerCase();
    return text.includes(query.trim().toLowerCase()) && (severity === 'All' || recordSeverity === severity) && (status === 'All' || record.status === status);
  }).sort((left, right) => {
    const values = { createdAt: [new Date(left.createdAt).getTime(), new Date(right.createdAt).getTime()], severity: [severityFor(left), severityFor(right)], batchId: [left.batchId, right.batchId], status: [left.status, right.status] }[sort.key];
    const comparison = typeof values[0] === 'number' ? values[0] - values[1] : String(values[0]).localeCompare(String(values[1]));
    return sort.direction === 'asc' ? comparison : -comparison;
  });
  const totalPages = Math.max(1, Math.ceil(filtered.length / PAGE_SIZE));
  const visiblePage = Math.min(page, totalPages);
  const visibleRecords = filtered.slice((visiblePage - 1) * PAGE_SIZE, visiblePage * PAGE_SIZE);
  const updateView = (setter) => (event) => { setter(event.target.value); setPage(1); };
  const handleSort = (key) => { setSort((current) => current.key === key ? { key, direction: current.direction === 'asc' ? 'desc' : 'asc' } : { key, direction: 'asc' }); setPage(1); };

  return (
    <div className="min-h-screen bg-slate-950 text-slate-100 p-8"><div className="max-w-7xl mx-auto"><QANavigation /><div className="flex flex-wrap items-center justify-between gap-4 mb-8"><div><p className="text-emerald-400 uppercase tracking-wide text-sm font-semibold">Quality Assurance</p><h1 className="text-4xl font-bold mt-2">Quarantine Management</h1></div><button onClick={() => navigate('/quality/quarantine/history')} className="px-4 py-2 rounded-xl border border-cyan-500 text-cyan-300 hover:bg-cyan-500/10">History</button></div>
      {error && <div className="mb-4 p-3 rounded bg-red-500/10 text-red-300 border border-red-500/30">{error}</div>}
      <div className="mb-6 grid gap-3 md:grid-cols-3"><input value={query} onChange={updateView(setQuery)} placeholder="Search batch, inventory, reason..." className="rounded-xl bg-slate-900 border border-slate-700 px-4 py-3 text-white" /><select value={severity} onChange={updateView(setSeverity)} className="rounded-xl bg-slate-900 border border-slate-700 px-4 py-3 text-white"><option>All</option>{severities.map((value) => <option key={value}>{value}</option>)}</select><select value={status} onChange={updateView(setStatus)} className="rounded-xl bg-slate-900 border border-slate-700 px-4 py-3 text-white"><option>All</option>{statuses.map((value) => <option key={value}>{value}</option>)}</select></div>
      <div className="mb-3 flex flex-wrap items-center gap-2 text-sm text-slate-400"><span>Sort by:</span>{['createdAt', 'severity', 'batchId', 'status'].map((key) => <button key={key} onClick={() => handleSort(key)} className="rounded-lg border border-slate-700 px-3 py-1 hover:bg-slate-800">{key === 'createdAt' ? 'Date' : key === 'batchId' ? 'Batch' : key}{sort.key === key ? ` ${sort.direction === 'asc' ? '^' : 'v'}` : ''}</button>)}<span className="ml-auto">{filtered.length} results</span></div>
      {loading ? <div className="text-slate-400">Loading quarantine records...</div> : <div className="overflow-x-auto rounded-2xl border border-slate-800"><table className="min-w-full divide-y divide-slate-800"><thead className="bg-slate-900"><tr>{['Batch', 'Inventory Rolls', 'Severity', 'Reason', 'Created', 'Status', 'Released', 'Actions'].map((heading) => <th key={heading} className="px-5 py-3 text-left text-xs uppercase">{heading}</th>)}</tr></thead><tbody className="divide-y divide-slate-800">{visibleRecords.length === 0 ? <tr><td colSpan="8" className="px-5 py-8 text-slate-400">No quarantine records match the current view.</td></tr> : visibleRecords.map((record) => <tr key={record.id} className="hover:bg-slate-900/60"><td className="px-5 py-4 font-medium">{record.batchId}</td><td className="px-5 py-4">{record.inventoryRollId}</td><td className="px-5 py-4">{severityFor(record)}</td><td className="px-5 py-4 text-slate-300">{record.reason}</td><td className="px-5 py-4 text-slate-400">{new Date(record.createdAt).toLocaleString()}</td><td className="px-5 py-4">{record.status}</td><td className="px-5 py-4 text-slate-400">{record.releasedAt ? new Date(record.releasedAt).toLocaleString() : 'Not released'}</td><td className="px-5 py-4"><button onClick={() => navigate(`/quality/quarantine/${record.id}`)} className="px-3 py-1 rounded-lg border border-slate-600 hover:bg-slate-800">View</button></td></tr>)}</tbody></table></div>}
      <div className="mt-4 flex items-center justify-between text-sm text-slate-400"><button disabled={visiblePage <= 1} onClick={() => setPage((current) => current - 1)} className="rounded-lg border border-slate-700 px-3 py-2 disabled:opacity-40">Previous</button><span>Page {visiblePage} of {totalPages}</span><button disabled={visiblePage >= totalPages} onClick={() => setPage((current) => current + 1)} className="rounded-lg border border-slate-700 px-3 py-2 disabled:opacity-40">Next</button></div>
    </div></div>
  );
}
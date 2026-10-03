import { useEffect, useState } from 'react';
import supplierService from '../../services/supplierService';
import inventoryService from '../../services/inventoryService';
import { parseErrorMessage } from '../../utils/errorHandler';
import { useAuth } from '../../context/AuthContext';

const emptyQuote = { rawMaterialId: '', unitPrice: '', minimumOrderQuantity: 1, packSize: 1, availableQuantity: '', leadTimeDays: '', qualityEvidence: '', currency: 'USD', isActive: true };
export default function SupplierQuotesPanel({ supplierId }) {
  const { user } = useAuth();
  const manager = [1, '1', 'SupplyChainManager'].includes(user?.role);
  const [quotes, setQuotes] = useState([]);
  const [materials, setMaterials] = useState([]);
  const [form, setForm] = useState(emptyQuote);
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);
  useEffect(() => {
    if (!manager) return;
    let cancelled = false;
    Promise.all([supplierService.getQuotes(supplierId), inventoryService.getRawMaterials()]).then(([q, m]) => {
      if (!cancelled) { setQuotes(q); setMaterials(m); }
    }).catch(err => { if (!cancelled) setError(parseErrorMessage(err, 'Could not load material quotes.')); });
    return () => { cancelled = true; };
  }, [supplierId, manager]);
  async function save(e) {
    e.preventDefault(); setBusy(true); setError('');
    try {
      const data = { ...form };
      ['rawMaterialId', 'unitPrice', 'minimumOrderQuantity', 'packSize', 'availableQuantity', 'leadTimeDays'].forEach(k => { data[k] = Number(form[k]); });
      await supplierService.saveQuote(supplierId, data);
      setQuotes(await supplierService.getQuotes(supplierId)); setForm(emptyQuote);
    } catch (err) { setError(parseErrorMessage(err, 'Could not save quote.')); }
    finally { setBusy(false); }
  }
  async function deactivate(id) {
    setBusy(true); setError('');
    try { await supplierService.deactivateQuote(supplierId, id); setQuotes(await supplierService.getQuotes(supplierId)); }
    catch (err) { setError(parseErrorMessage(err, 'Could not deactivate quote.')); }
    finally { setBusy(false); }
  }
  if (!manager) return null;
  return <section className="p-5 rounded-2xl bg-slate-900/60 border border-white/10 space-y-3">
    <h2 className="text-lg font-semibold text-white">Supplier material quotes</h2>
    <p className="text-sm text-slate-400">Enter confirmed prices, availability and quality evidence for agent recommendations.</p>
    {error && <p role="alert" className="text-red-400">{error}</p>}
    {quotes.map(q => <div key={q.id} className="flex gap-3 items-center text-sm text-slate-300">
      <span>{materials.find(m => m.id === q.rawMaterialId)?.skuCode || q.rawMaterialId} · {q.unitPrice} {q.currency} · Available {q.availableQuantity} · {q.isActive ? 'Active' : 'Inactive'}</span>
      <button disabled={busy} onClick={() => setForm(q)} className="text-cyan-400">Edit</button>
      {q.isActive && <button disabled={busy} onClick={() => deactivate(q.id)} className="text-red-400">Deactivate</button>}
    </div>)}
    <form onSubmit={save} className="grid sm:grid-cols-2 gap-3">
      <label className="text-sm text-slate-300">Material<select required disabled={!!form.id} value={form.rawMaterialId} onChange={e => setForm({ ...form, rawMaterialId: e.target.value })} className="block w-full bg-slate-800 p-2 rounded">
        <option value="">Choose material</option>{materials.map(m => <option key={m.id} value={m.id}>{m.skuCode} · {m.name}</option>)}
      </select></label>
      {Object.entries({ unitPrice: 'Unit price', minimumOrderQuantity: 'Minimum order', packSize: 'Pack size', availableQuantity: 'Available quantity', leadTimeDays: 'Lead time (days)', qualityEvidence: 'Quality evidence', currency: 'Currency' }).map(([key, label]) => <label key={key} className="text-sm text-slate-300">{label}
        <input required type={['qualityEvidence', 'currency'].includes(key) ? 'text' : 'number'} min={['unitPrice', 'packSize'].includes(key) ? 0.001 : 0} step={key === 'leadTimeDays' ? 1 : 'any'} value={form[key]} onChange={e => setForm({ ...form, [key]: e.target.value })} className="block w-full bg-slate-800 p-2 rounded" />
      </label>)}
      <label className="text-sm text-slate-300"><input type="checkbox" checked={form.isActive} onChange={e => setForm({ ...form, isActive: e.target.checked })} /> Active quote</label>
      <button disabled={busy} className="bg-cyan-700 text-white p-2 rounded disabled:opacity-50">{busy ? 'Saving…' : form.id ? 'Update quote' : 'Add quote'}</button>
      {form.id && <button type="button" onClick={() => setForm(emptyQuote)} className="text-slate-300">Cancel edit</button>}
    </form>
  </section>;
}

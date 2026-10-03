import { useEffect, useState } from 'react';
import purchaseOrderService from '../../services/purchaseOrderService';
import { parseErrorMessage } from '../../utils/errorHandler';

export default function GoodsReceiptPanel({ po, onReceived }) {
  const [receipts, setReceipts] = useState([]);
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);
  const newForm = () => ({ receiptKey: crypto.randomUUID(), orderLineId: '', quantity: '', rollIdentifier: '', batchId: '' });
  const [form, setForm] = useState(newForm);
  const canReceive = ['Sent', 'InTransit'].includes(po.status);
  useEffect(() => {
    let cancelled = false;
    purchaseOrderService.getReceipts(po.id).then(data => { if (!cancelled) setReceipts(data); })
      .catch(err => { if (!cancelled) setError(parseErrorMessage(err, 'Could not load delivery receipts.')); });
    return () => { cancelled = true; };
  }, [po.id]);
  const lines = po.orderLines || po.lines || [];
  const remaining = line => line.quantity - receipts.filter(r => r.orderLineId === line.id).reduce((sum, r) => sum + r.quantity, 0);
  async function receive(e) {
    e.preventDefault(); setBusy(true); setError('');
    try {
      await purchaseOrderService.receiveGoods(po.id, { ...form, orderLineId: Number(form.orderLineId), quantity: Number(form.quantity) });
      setReceipts(await purchaseOrderService.getReceipts(po.id));
      setForm(newForm());
      await onReceived();
    } catch (err) { setError(parseErrorMessage(err, 'Could not record this delivery. You can retry this receipt.')); }
    finally { setBusy(false); }
  }
  return <section className="p-5 rounded-2xl bg-slate-900/60 border border-white/10 space-y-3">
    <h2 className="text-lg font-semibold text-white">Goods received</h2>
    <p className="text-sm text-slate-400">Record each physical roll when it arrives. Partial deliveries add only the quantity received.</p>
    {error && <p role="alert" className="text-red-400">{error}</p>}
    {receipts.map(r => <p key={r.id} className="text-sm text-slate-300">{r.rollIdentifier} · Batch {r.batchId} · {r.quantity} units · {new Date(r.receivedAt).toLocaleString()}</p>)}
    {!receipts.length && <p className="text-sm text-slate-400">No delivery receipts recorded.</p>}
    {canReceive && <form onSubmit={receive} className="grid sm:grid-cols-2 gap-3">
      <label className="text-sm text-slate-300">Order line<select required value={form.orderLineId} onChange={e => setForm({ ...form, orderLineId: e.target.value })} className="block w-full bg-slate-800 rounded p-2">
        <option value="">Choose material</option>{lines.filter(l => remaining(l) > 0).map(l => <option key={l.id} value={l.id}>{l.rawMaterialName || l.description} · {remaining(l)} remaining</option>)}
      </select></label>
      {['quantity', 'rollIdentifier', 'batchId'].map(name => <label key={name} className="text-sm text-slate-300">{{ quantity: 'Quantity received', rollIdentifier: 'Physical roll identifier', batchId: 'Batch identifier' }[name]}
        <input required maxLength={name === 'batchId' ? 80 : 120} type={name === 'quantity' ? 'number' : 'text'} min={1} step={1} value={form[name]} onChange={e => setForm({ ...form, [name]: e.target.value })} className="block w-full bg-slate-800 rounded p-2" />
      </label>)}
      <button disabled={busy} className="bg-emerald-600 text-white rounded p-2 disabled:opacity-50">{busy ? 'Recording…' : 'Record arrival'}</button>
    </form>}
  </section>;
}

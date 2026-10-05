import { formatColomboDate } from '../../utils/locale.js';
import { useEffect, useId, useState } from 'react';
import purchaseOrderService from '../../services/purchaseOrderService';
import inventoryService from '../../services/inventoryService';
import { parseErrorMessage } from '../../utils/errorHandler';

const generateRollId = () => `ROLL-${crypto.randomUUID().toUpperCase()}`;

export default function GoodsReceiptPanel({ po, onReceived }) {
  const batchListId = useId();
  const [receipts, setReceipts] = useState([]);
  const [rolls, setRolls] = useState([]);
  const [batchNotice, setBatchNotice] = useState('');
  const [success, setSuccess] = useState('');
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);
  const newForm = () => ({ receiptKey: crypto.randomUUID(), orderLineId: '', quantity: '', rollIdentifier: generateRollId(), batchId: '' });
  const [form, setForm] = useState(newForm);
  const canReceive = ['Sent', 'InTransit'].includes(po.status);
  useEffect(() => {
    let cancelled = false;
    setReceipts([]); setForm(newForm()); setError(''); setSuccess('');
    purchaseOrderService.getReceipts(po.id).then(data => { if (!cancelled) setReceipts(data); })
      .catch(err => { if (!cancelled) setError(parseErrorMessage(err, 'Could not load delivery receipts.')); });
    return () => { cancelled = true; };
  }, [po.id]);
  useEffect(() => {
    let cancelled = false;
    setRolls([]); setBatchNotice('');
    if (canReceive) inventoryService.getRolls().then(data => { if (!cancelled) setRolls(data); })
      .catch(() => { if (!cancelled) setBatchNotice('Existing batches could not be loaded. You can still type the batch number from the delivery label.'); });
    return () => { cancelled = true; };
  }, [po.id, canReceive]);
  const lines = po.orderLines || po.lines || [];
  const remaining = line => line.quantity - receipts.filter(r => r.orderLineId === line.id).reduce((sum, r) => sum + r.quantity, 0);
  const selectedLine = lines.find(line => String(line.id) === form.orderLineId);
  const batches = [...new Set([
    ...rolls.filter(roll => selectedLine?.rawMaterialId != null && String(roll.rawMaterialId) === String(selectedLine.rawMaterialId)).map(roll => roll.batchId),
    ...receipts.filter(receipt => receipt.orderLineId === selectedLine?.id).map(receipt => receipt.batchId),
  ].filter(Boolean))].sort();
  const unit = selectedLine?.unit || 'order units';
  async function receive(e) {
    e.preventDefault(); setBusy(true); setError(''); setSuccess('');
    try {
      if (!selectedLine || !Number.isInteger(Number(form.quantity)) || Number(form.quantity) < 1 || Number(form.quantity) > remaining(selectedLine)) throw new Error('Enter a positive whole quantity no greater than the remaining order quantity.');
      if (!form.rollIdentifier.trim() || !form.batchId.trim()) throw new Error('A roll identifier and supplier batch number are required.');
      await purchaseOrderService.receiveGoods(po.id, { ...form, rollIdentifier: form.rollIdentifier.trim(), batchId: form.batchId.trim(), orderLineId: Number(form.orderLineId), quantity: Number(form.quantity) });
      const updatedReceipts = await purchaseOrderService.getReceipts(po.id);
      setReceipts(updatedReceipts);
      const hasMore = selectedLine.quantity > updatedReceipts.filter(r => r.orderLineId === selectedLine.id).reduce((sum, r) => sum + r.quantity, 0);
      setForm({ ...newForm(), orderLineId: hasMore ? form.orderLineId : '', batchId: hasMore ? form.batchId.trim() : '' });
      setSuccess(hasMore ? 'Roll recorded. A new roll ID is ready; the material and batch are kept for the next roll.' : 'Roll recorded. This order line is fully received.');
      await onReceived();
    } catch (err) { setError(parseErrorMessage(err, 'Could not record this delivery. You can retry this receipt.')); }
    finally { setBusy(false); }
  }
  return <section className="p-5 rounded-2xl bg-slate-900/60 border border-white/10 space-y-3">
    <h2 className="text-lg font-semibold text-white">Goods received</h2>
    <p className="text-sm text-slate-400">Record one physical roll when it arrives. A unique roll ID is generated for you; use the supplier's batch number from the label or delivery note.</p>
    {error && <p role="alert" className="text-red-400">{error}</p>}
    {success && <p role="status" className="rounded-xl border border-emerald-400/20 bg-emerald-400/10 p-3 text-sm text-emerald-300">{success}</p>}
    {receipts.map(r => <p key={r.id} className="text-sm text-slate-300">{r.rollIdentifier} · Batch {r.batchId} · {r.quantity} units · {formatColomboDate(r.receivedAt, 'toLocaleString')}</p>)}
    {!receipts.length && <p className="text-sm text-slate-400">No delivery receipts recorded.</p>}
    {canReceive && <form onSubmit={receive} className="grid sm:grid-cols-2 gap-5">
      <label className="text-sm text-slate-300">Order line<select required disabled={busy} value={form.orderLineId} onChange={e => { setForm({ ...form, orderLineId: e.target.value, quantity: '', batchId: '' }); setSuccess(''); }} className="mt-2 block w-full border border-white/10 bg-slate-800 rounded-xl p-3 focus:ring-2 focus:ring-cyan-400/30">
        <option value="">Choose material</option>{lines.filter(l => remaining(l) > 0).map(l => <option key={l.id} value={l.id}>{l.rawMaterialName || l.description} · {remaining(l)} remaining</option>)}
      </select></label>
      {selectedLine && <div className="sm:col-span-2 rounded-xl border border-cyan-400/10 bg-cyan-400/5 p-3 text-sm text-slate-300">Ordered: <strong>{selectedLine.quantity}</strong> · Received: <strong>{selectedLine.quantity - remaining(selectedLine)}</strong> · Remaining: <strong className="text-cyan-200">{remaining(selectedLine)} {unit}</strong></div>}
      {['quantity', 'rollIdentifier', 'batchId'].map(name => <div key={name}><label className="text-sm text-slate-300">{{ quantity: 'Quantity received', rollIdentifier: 'Physical roll identifier', batchId: 'Supplier batch / lot number' }[name]}
        <input required disabled={busy} maxLength={name === 'batchId' ? 80 : 120} list={name === 'batchId' ? batchListId : undefined} placeholder={name === 'batchId' ? 'Search existing batches or enter a new number' : undefined} type={name === 'quantity' ? 'number' : 'text'} min={1} max={name === 'quantity' && selectedLine ? remaining(selectedLine) : undefined} step={1} value={form[name]} onChange={e => setForm({ ...form, [name]: e.target.value })} className="mt-2 block w-full border border-white/10 bg-slate-800 rounded-xl p-3 focus:ring-2 focus:ring-cyan-400/30" />
      </label>{name === 'quantity' && <p className="mt-2 text-xs text-slate-400">Enter the actual amount on this roll, in the order's unit.</p>}
      {name === 'rollIdentifier' && <><p className="mt-2 text-xs text-slate-400">Generated for a new roll. You can replace it with the supplier's unique roll ID.</p><button type="button" disabled={busy} onClick={() => setForm({ ...form, rollIdentifier: generateRollId() })} className="mt-2 text-xs text-cyan-300 hover:text-cyan-100 disabled:opacity-50">Generate another roll ID</button></>}
      {name === 'batchId' && <><datalist id={batchListId}>{batches.map(batch => <option key={batch} value={batch}>{batch}</option>)}</datalist><p className="mt-2 text-xs text-slate-400">Choose a batch for this material or type the supplier's lot number. A new batch is created when arrival is recorded.</p>{batchNotice && <p className="mt-2 text-xs text-amber-300">{batchNotice}</p>}</>}
      </div>)}
      <div className="sm:col-span-2 flex flex-wrap items-center gap-3 border-t border-white/10 pt-4"><button disabled={busy} className="bg-emerald-500 hover:bg-emerald-400 text-slate-950 font-semibold rounded-xl px-5 py-3 disabled:opacity-50">{busy ? 'Recording…' : 'Record arrival'}</button><p className="text-xs text-slate-400">For another roll, record arrival again. The batch stays selected on partial deliveries.</p></div>
    </form>}
  </section>;
}

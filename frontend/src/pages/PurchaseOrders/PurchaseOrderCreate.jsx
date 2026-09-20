import React, { useState, useEffect } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import {
  ShoppingCart,
  Plus,
  Trash2,
  Building2,
  DollarSign,
  AlertTriangle,
  CheckCircle2,
  ArrowLeft,
  Loader2,
  ShieldCheck,
  Send,
  Info,
  Package
} from 'lucide-react';
import AppLayout from '../../components/Layout/AppLayout';
import purchaseOrderService from '../../services/purchaseOrderService';
import supplierService from '../../services/supplierService';
import rawMaterialService from '../../services/rawMaterialService';
import { parseErrorMessage } from '../../utils/errorHandler';

export default function PurchaseOrderCreate() {
  const navigate = useNavigate();

  const [suppliers, setSuppliers] = useState([]);
  const [materials, setMaterials] = useState([]);
  const [loadingData, setLoadingData] = useState(true);
  const [submitting, setSubmitting] = useState(false);
  const [submitAndApprove, setSubmitAndApprove] = useState(false);
  const [errorMessage, setErrorMessage] = useState('');

  // Form State
  const [supplierId, setSupplierId] = useState('');
  const [currency, setCurrency] = useState('USD');
  const [budgetLimit, setBudgetLimit] = useState('10000');
  const [notes, setNotes] = useState('');
  const [lines, setLines] = useState([
    { rawMaterialId: '', description: '', quantity: '100', unitPrice: '15.00' }
  ]);

  useEffect(() => {
    const loadPrerequisites = async () => {
      setLoadingData(true);
      setErrorMessage('');
      try {
        const [suppliersData, materialsData] = await Promise.all([
          supplierService.getSuppliers(),
          rawMaterialService.getRawMaterials()
        ]);
        const activeSuppliers = (suppliersData || []).filter((s) => s.isActive);
        setSuppliers(activeSuppliers);
        if (activeSuppliers.length > 0) {
          setSupplierId(activeSuppliers[0].id.toString());
        }
        setMaterials(materialsData || []);
        if ((materialsData || []).length > 0) {
          setLines([
            {
              rawMaterialId: materialsData[0].id.toString(),
              description: materialsData[0].name || '',
              quantity: '100',
              unitPrice: '15.00'
            }
          ]);
        }
      } catch (err) {
        setErrorMessage(parseErrorMessage(err, 'Failed to load suppliers or materials.'));
      } finally {
        setLoadingData(false);
      }
    };
    loadPrerequisites();
  }, []);

  const handleLineChange = (index, field, value) => {
    const updated = [...lines];
    updated[index][field] = value;

    if (field === 'rawMaterialId') {
      const selected = materials.find((m) => m.id.toString() === value);
      if (selected && !updated[index].description) {
        updated[index].description = selected.name;
      }
    }

    setLines(updated);
  };

  const addLine = () => {
    const firstMatId = materials.length > 0 ? materials[0].id.toString() : '';
    const firstMatName = materials.length > 0 ? materials[0].name : '';
    setLines([
      ...lines,
      { rawMaterialId: firstMatId, description: firstMatName, quantity: '100', unitPrice: '10.00' }
    ]);
  };

  const removeLine = (index) => {
    if (lines.length <= 1) return;
    setLines(lines.filter((_, i) => i !== index));
  };

  // Calculations
  const calculatedTotal = lines.reduce((sum, line) => {
    const q = parseFloat(line.quantity) || 0;
    const p = parseFloat(line.unitPrice) || 0;
    return sum + q * p;
  }, 0);

  const budgetNum = parseFloat(budgetLimit) || 0;
  const exceedsBudget = calculatedTotal > budgetNum && budgetNum > 0;
  const requiresApproval = calculatedTotal > 5000;

  const selectedSupplier = suppliers.find((s) => s.id.toString() === supplierId);

  const handleSubmit = async (e, shouldSubmitForApproval = false) => {
    e.preventDefault();
    setErrorMessage('');

    if (!supplierId) {
      setErrorMessage('Please select a supplier.');
      return;
    }

    if (lines.length === 0) {
      setErrorMessage('At least one order line is required.');
      return;
    }

    for (let i = 0; i < lines.length; i++) {
      const l = lines[i];
      if (!l.rawMaterialId) {
        setErrorMessage(`Please select a raw material for Line #${i + 1}.`);
        return;
      }
      if (parseFloat(l.quantity) <= 0 || isNaN(parseFloat(l.quantity))) {
        setErrorMessage(`Line #${i + 1} quantity must be strictly greater than 0.`);
        return;
      }
      if (parseFloat(l.unitPrice) <= 0 || isNaN(parseFloat(l.unitPrice))) {
        setErrorMessage(`Line #${i + 1} unit price must be strictly greater than 0.`);
        return;
      }
    }

    if (exceedsBudget) {
      setErrorMessage(
        `Total cost ($${calculatedTotal.toFixed(2)}) exceeds budget limit ($${budgetNum.toFixed(2)}). Please increase budget or adjust quantities.`
      );
      return;
    }

    setSubmitting(true);
    setSubmitAndApprove(shouldSubmitForApproval);

    try {
      const payload = {
        supplierId: parseInt(supplierId, 10),
        currency,
        budgetLimit: budgetNum,
        notes: notes.trim(),
        lines: lines.map((l) => ({
          rawMaterialId: parseInt(l.rawMaterialId, 10),
          description: l.description.trim(),
          quantity: parseFloat(l.quantity),
          unitPrice: parseFloat(l.unitPrice)
        }))
      };

      const createdPo = await purchaseOrderService.createPurchaseOrder(payload);

      if (shouldSubmitForApproval) {
        await purchaseOrderService.submitPurchaseOrder(createdPo.id);
      }

      navigate(`/purchase-orders/${createdPo.id}`);
    } catch (err) {
      setErrorMessage(parseErrorMessage(err, 'Failed to create purchase order.'));
    } finally {
      setSubmitting(false);
      setSubmitAndApprove(false);
    }
  };

  return (
    <AppLayout
      title="Create Purchase Order"
      subtitle="Assemble purchase orders with real-time budget verification, automated cost calculation, and policy threshold checks."
    >
      <div className="max-w-5xl mx-auto space-y-6">
        {/* Back Link */}
        <div>
          <Link
            to="/purchase-orders"
            className="inline-flex items-center gap-2 text-xs font-semibold text-slate-400 hover:text-white transition-colors"
          >
            <ArrowLeft className="w-4 h-4" />
            <span>Back to Purchase Orders</span>
          </Link>
        </div>

        {/* Error Alert */}
        {errorMessage && (
          <div className="p-4 rounded-xl bg-rose-500/10 border border-rose-500/30 text-rose-400 text-sm flex items-start gap-3">
            <AlertTriangle className="w-5 h-5 shrink-0 mt-0.5" />
            <div className="flex-1">{errorMessage}</div>
          </div>
        )}

        {loadingData ? (
          <div className="p-16 flex flex-col items-center justify-center gap-3">
            <Loader2 className="w-8 h-8 text-brand-500 animate-spin" />
            <p className="text-sm text-slate-400">Loading catalog and supplier directories...</p>
          </div>
        ) : (
          <form onSubmit={(e) => handleSubmit(e, false)} className="space-y-6">
            {/* Header / Vendor Card */}
            <div className="p-6 rounded-2xl bg-slate-900/80 border border-slate-800 space-y-5">
              <h3 className="text-sm font-bold text-white flex items-center gap-2">
                <Building2 className="w-4 h-4 text-brand-400" />
                <span>Supplier & Currency Details</span>
              </h3>

              <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                {/* Supplier select */}
                <div>
                  <label className="block text-xs font-semibold text-slate-400 mb-1.5">
                    Supplier *
                  </label>
                  <select
                    value={supplierId}
                    onChange={(e) => setSupplierId(e.target.value)}
                    required
                    className="w-full px-3.5 py-2.5 bg-slate-950 border border-slate-700 rounded-xl text-sm text-white focus:outline-none focus:border-brand-500"
                  >
                    {suppliers.map((s) => (
                      <option key={s.id} value={s.id}>
                        {s.name} ({s.supplierCode || `SUP-${s.id}`}) — {s.leadTimeDays || 7}d Lead Time
                      </option>
                    ))}
                  </select>
                  {selectedSupplier && (
                    <p className="text-[11px] text-slate-500 mt-1">
                      Terms: {selectedSupplier.paymentTerms || 'Net 30'} | Email: {selectedSupplier.contactEmail}
                    </p>
                  )}
                </div>

                {/* Currency */}
                <div>
                  <label className="block text-xs font-semibold text-slate-400 mb-1.5">
                    Currency *
                  </label>
                  <select
                    value={currency}
                    onChange={(e) => setCurrency(e.target.value)}
                    className="w-full px-3.5 py-2.5 bg-slate-950 border border-slate-700 rounded-xl text-sm text-white focus:outline-none focus:border-brand-500"
                  >
                    <option value="USD">USD ($)</option>
                    <option value="EUR">EUR (€)</option>
                    <option value="GBP">GBP (£)</option>
                  </select>
                </div>

                {/* Budget Limit */}
                <div>
                  <label className="block text-xs font-semibold text-slate-400 mb-1.5">
                    Department Budget Limit *
                  </label>
                  <div className="relative">
                    <span className="absolute left-3.5 top-2.5 text-slate-500 text-sm">$</span>
                    <input
                      type="number"
                      step="0.01"
                      min="1"
                      value={budgetLimit}
                      onChange={(e) => setBudgetLimit(e.target.value)}
                      required
                      placeholder="10000.00"
                      className="w-full pl-8 pr-3.5 py-2.5 bg-slate-950 border border-slate-700 rounded-xl text-sm text-white focus:outline-none focus:border-brand-500"
                    />
                  </div>
                </div>
              </div>

              {/* Notes */}
              <div>
                <label className="block text-xs font-semibold text-slate-400 mb-1.5">
                  Order Justification / Production Notes
                </label>
                <textarea
                  rows="2"
                  value={notes}
                  onChange={(e) => setNotes(e.target.value)}
                  placeholder="E.g., Automated replenishment for low stock alert on extrusion Line 2..."
                  className="w-full px-3.5 py-2.5 bg-slate-950 border border-slate-700 rounded-xl text-sm text-white placeholder-slate-600 focus:outline-none focus:border-brand-500"
                />
              </div>
            </div>

            {/* Order Lines Card */}
            <div className="p-6 rounded-2xl bg-slate-900/80 border border-slate-800 space-y-4">
              <div className="flex items-center justify-between">
                <h3 className="text-sm font-bold text-white flex items-center gap-2">
                  <Package className="w-4 h-4 text-emerald-400" />
                  <span>Order Items & Quantities</span>
                </h3>
                <button
                  type="button"
                  onClick={addLine}
                  className="flex items-center gap-1.5 px-3 py-1.5 bg-brand-600/20 border border-brand-500/30 hover:bg-brand-600/30 text-brand-300 rounded-xl text-xs font-semibold transition-all"
                >
                  <Plus className="w-3.5 h-3.5" />
                  <span>Add Line</span>
                </button>
              </div>

              <div className="space-y-3">
                {lines.map((line, idx) => {
                  const lineSubtotal = (parseFloat(line.quantity) || 0) * (parseFloat(line.unitPrice) || 0);
                  return (
                    <div
                      key={idx}
                      className="p-4 rounded-xl bg-slate-950/70 border border-slate-800/80 grid grid-cols-1 md:grid-cols-12 gap-3 items-end"
                    >
                      {/* Material */}
                      <div className="md:col-span-4">
                        <label className="block text-[11px] font-semibold text-slate-400 mb-1">
                          Material #{idx + 1} *
                        </label>
                        <select
                          value={line.rawMaterialId}
                          onChange={(e) => handleLineChange(idx, 'rawMaterialId', e.target.value)}
                          required
                          className="w-full px-3 py-2 bg-slate-900 border border-slate-700 rounded-xl text-xs text-white focus:outline-none focus:border-brand-500"
                        >
                          {materials.map((m) => (
                            <option key={m.id} value={m.id}>
                              {m.name} ({m.skuCode}) [{m.unitOfMeasure}]
                            </option>
                          ))}
                        </select>
                      </div>

                      {/* Description */}
                      <div className="md:col-span-3">
                        <label className="block text-[11px] font-semibold text-slate-400 mb-1">
                          Description
                        </label>
                        <input
                          type="text"
                          value={line.description}
                          onChange={(e) => handleLineChange(idx, 'description', e.target.value)}
                          placeholder="Specification notes..."
                          className="w-full px-3 py-2 bg-slate-900 border border-slate-700 rounded-xl text-xs text-white focus:outline-none focus:border-brand-500"
                        />
                      </div>

                      {/* Quantity */}
                      <div className="md:col-span-2">
                        <label className="block text-[11px] font-semibold text-slate-400 mb-1">
                          Quantity *
                        </label>
                        <input
                          type="number"
                          step="0.001"
                          min="0.001"
                          value={line.quantity}
                          onChange={(e) => handleLineChange(idx, 'quantity', e.target.value)}
                          required
                          className="w-full px-3 py-2 bg-slate-900 border border-slate-700 rounded-xl text-xs text-white focus:outline-none focus:border-brand-500"
                        />
                      </div>

                      {/* Unit Price */}
                      <div className="md:col-span-2">
                        <label className="block text-[11px] font-semibold text-slate-400 mb-1">
                          Unit Price ($) *
                        </label>
                        <input
                          type="number"
                          step="0.01"
                          min="0.01"
                          value={line.unitPrice}
                          onChange={(e) => handleLineChange(idx, 'unitPrice', e.target.value)}
                          required
                          className="w-full px-3 py-2 bg-slate-900 border border-slate-700 rounded-xl text-xs text-white focus:outline-none focus:border-brand-500"
                        />
                      </div>

                      {/* Subtotal & Delete */}
                      <div className="md:col-span-1 flex items-center justify-between md:justify-end gap-2">
                        <div className="text-right">
                          <span className="block text-[10px] text-slate-500">Subtotal</span>
                          <span className="text-xs font-bold text-white">${lineSubtotal.toFixed(2)}</span>
                        </div>
                        {lines.length > 1 && (
                          <button
                            type="button"
                            onClick={() => removeLine(idx)}
                            className="p-1.5 text-slate-500 hover:text-rose-400 transition-colors"
                            title="Remove Line"
                          >
                            <Trash2 className="w-4 h-4" />
                          </button>
                        )}
                      </div>
                    </div>
                  );
                })}
              </div>
            </div>

            {/* Calculations & Business Rules Summary Panel */}
            <div className="p-6 rounded-2xl bg-gradient-to-br from-slate-900 via-slate-900 to-brand-950/40 border border-slate-800 space-y-4">
              <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
                <div>
                  <span className="text-xs font-semibold text-slate-400 uppercase tracking-wider">
                    Computed Purchase Order Total
                  </span>
                  <div className="text-3xl font-extrabold text-white mt-0.5">
                    ${calculatedTotal.toFixed(2)} <span className="text-sm font-normal text-slate-400">{currency}</span>
                  </div>
                </div>

                <div className="flex flex-col gap-2">
                  {requiresApproval ? (
                    <div className="inline-flex items-center gap-2 px-3.5 py-1.5 rounded-xl bg-amber-500/10 border border-amber-500/30 text-amber-300 text-xs font-semibold">
                      <AlertTriangle className="w-4 h-4" />
                      <span>Executive Approval Required (&gt; $5,000 threshold)</span>
                    </div>
                  ) : (
                    <div className="inline-flex items-center gap-2 px-3.5 py-1.5 rounded-xl bg-emerald-500/10 border border-emerald-500/30 text-emerald-300 text-xs font-semibold">
                      <CheckCircle2 className="w-4 h-4" />
                      <span>Standard Threshold (Within auto-routing limit)</span>
                    </div>
                  )}

                  {exceedsBudget && (
                    <div className="inline-flex items-center gap-2 px-3.5 py-1.5 rounded-xl bg-rose-500/10 border border-rose-500/30 text-rose-300 text-xs font-semibold">
                      <AlertTriangle className="w-4 h-4" />
                      <span>Exceeds Budget Limit (${budgetNum.toFixed(2)})</span>
                    </div>
                  )}
                </div>
              </div>

              <div className="text-xs text-slate-500 flex items-center gap-2 border-t border-slate-800/80 pt-3">
                <Info className="w-4 h-4 text-brand-400 shrink-0" />
                <span>
                  Totals and line subtotals are strictly recalculated and verified by ASP.NET Core on submission.
                </span>
              </div>
            </div>

            {/* Submission Actions */}
            <div className="flex items-center justify-end gap-3 pt-2">
              <Link
                to="/purchase-orders"
                className="px-5 py-2.5 rounded-xl bg-slate-900 border border-slate-700 text-slate-300 hover:text-white text-xs font-semibold transition-all"
              >
                Cancel
              </Link>
              <button
                type="submit"
                disabled={submitting || exceedsBudget}
                className="flex items-center gap-2 px-5 py-2.5 rounded-xl bg-slate-800 hover:bg-slate-700 text-white text-xs font-semibold border border-slate-600 transition-all disabled:opacity-50"
              >
                {submitting && !submitAndApprove && <Loader2 className="w-4 h-4 animate-spin" />}
                <span>Save as Draft</span>
              </button>
              <button
                type="button"
                onClick={(e) => handleSubmit(e, true)}
                disabled={submitting || exceedsBudget}
                className="flex items-center gap-2 px-6 py-2.5 rounded-xl bg-gradient-to-r from-brand-600 to-brand-700 hover:from-brand-500 text-white text-xs font-bold shadow-lg shadow-brand-600/25 transition-all disabled:opacity-50"
              >
                {submitting && submitAndApprove ? (
                  <Loader2 className="w-4 h-4 animate-spin" />
                ) : (
                  <Send className="w-4 h-4" />
                )}
                <span>Create &amp; Submit for Approval</span>
              </button>
            </div>
          </form>
        )}
      </div>
    </AppLayout>
  );
}


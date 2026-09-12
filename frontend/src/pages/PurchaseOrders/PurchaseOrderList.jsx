import React, { useState, useEffect, useMemo } from 'react';
import { Link, useSearchParams } from 'react-router-dom';
import {
  ShoppingCart,
  Plus,
  Search,
  Filter,
  ArrowUpDown,
  Building2,
  DollarSign,
  Clock,
  CheckCircle2,
  AlertTriangle,
  FileText,
  ExternalLink,
  Trash2,
  Loader2,
  AlertCircle,
  X
} from 'lucide-react';
import AppLayout from '../../components/Layout/AppLayout';
import StatusBadge from '../../components/Common/StatusBadge';
import purchaseOrderService from '../../services/purchaseOrderService';
import supplierService from '../../services/supplierService';
import rawMaterialService from '../../services/rawMaterialService';
import { parseErrorMessage } from '../../utils/errorHandler';

export default function PurchaseOrderList() {
  const [searchParams] = useSearchParams();
  const preselectedSupplierId = searchParams.get('newPoSupplierId');

  const [orders, setOrders] = useState([]);
  const [suppliers, setSuppliers] = useState([]);
  const [rawMaterials, setRawMaterials] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  // Filters, Search, Sort & Pagination
  const [searchTerm, setSearchTerm] = useState('');
  const [statusFilter, setStatusFilter] = useState('all');
  const [sortBy, setSortBy] = useState('date'); // 'date' | 'cost' | 'poNumber'
  const [sortOrder, setSortOrder] = useState('desc');
  const [currentPage, setCurrentPage] = useState(1);
  const itemsPerPage = 8;

  // Create PO Modal State
  const [isCreateOpen, setIsCreateOpen] = useState(Boolean(preselectedSupplierId));
  const [createLoading, setCreateLoading] = useState(false);
  const [createError, setCreateError] = useState('');

  const [poForm, setPoForm] = useState({
    supplierId: preselectedSupplierId ? parseInt(preselectedSupplierId, 10) : '',
    budgetLimit: 15000,
    notes: '',
    lines: [
      {
        rawMaterialId: 1,
        description: 'Standard Grade Industrial Material',
        quantity: 2000,
        unitPrice: 4.5
      }
    ]
  });

  const loadData = async () => {
    setLoading(true);
    setError('');
    try {
      const [ordersData, suppliersData, materialsData] = await Promise.all([
        purchaseOrderService.getPurchaseOrders(),
        supplierService.getSuppliers(),
        rawMaterialService.getRawMaterials()
      ]);
      setOrders(ordersData);
      setSuppliers(suppliersData.filter((s) => s.isActive));
      setRawMaterials(materialsData);

      // Default supplier if none preselected
      if (!poForm.supplierId && suppliersData.length > 0) {
        setPoForm((prev) => ({
          ...prev,
          supplierId: suppliersData[0].id
        }));
      }
    } catch (err) {
      setError(parseErrorMessage(err, 'Failed to load purchase orders.'));
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadData();
  }, []);

  // Compute calculated values in real-time for PO creation
  const calculatedTotalCost = useMemo(() => {
    return poForm.lines.reduce((sum, line) => {
      const qty = parseFloat(line.quantity) || 0;
      const price = parseFloat(line.unitPrice) || 0;
      return sum + qty * price;
    }, 0);
  }, [poForm.lines]);

  const exceedsThreshold = calculatedTotalCost > 5000;
  const exceedsBudget = calculatedTotalCost > parseFloat(poForm.budgetLimit || 0);

  // Line item handlers
  const handleAddLine = () => {
    setPoForm((prev) => ({
      ...prev,
      lines: [
        ...prev.lines,
        {
          rawMaterialId: rawMaterials[0]?.id || 1,
          description: '',
          quantity: 100,
          unitPrice: 10.0
        }
      ]
    }));
  };

  const handleRemoveLine = (index) => {
    if (poForm.lines.length <= 1) return;
    setPoForm((prev) => ({
      ...prev,
      lines: prev.lines.filter((_, i) => i !== index)
    }));
  };

  const handleLineChange = (index, field, value) => {
    setPoForm((prev) => {
      const updated = [...prev.lines];
      updated[index] = { ...updated[index], [field]: value };
      return { ...prev, lines: updated };
    });
  };

  const handleCreateSubmit = async (e) => {
    e.preventDefault();
    if (!poForm.supplierId) {
      setCreateError('Please select a valid supplier.');
      return;
    }
    if (poForm.lines.length === 0) {
      setCreateError('At least one order line item is required.');
      return;
    }
    if (exceedsBudget) {
      setCreateError('Total cost cannot exceed the specified budget limit.');
      return;
    }

    setCreateLoading(true);
    setCreateError('');
    try {
      const payload = {
        supplierId: parseInt(poForm.supplierId, 10),
        budgetLimit: parseFloat(poForm.budgetLimit),
        notes: poForm.notes,
        lines: poForm.lines.map((l) => ({
          rawMaterialId: parseInt(l.rawMaterialId, 10),
          description: l.description || 'Raw Material Order',
          quantity: parseFloat(l.quantity),
          unitPrice: parseFloat(l.unitPrice)
        }))
      };

      await purchaseOrderService.createPurchaseOrder(payload);
      setIsCreateOpen(false);
      await loadData();
    } catch (err) {
      setCreateError(parseErrorMessage(err, 'Failed to create purchase order.'));
    } finally {
      setCreateLoading(false);
    }
  };

  // Filter & Sort POs
  const filteredOrders = useMemo(() => {
    return orders
      .filter((o) => {
        const matchesSearch =
          o.poNumber.toLowerCase().includes(searchTerm.toLowerCase()) ||
          o.supplierName.toLowerCase().includes(searchTerm.toLowerCase());

        if (!matchesSearch) return false;

        if (statusFilter !== 'all') {
          return o.status.toLowerCase() === statusFilter.toLowerCase();
        }
        return true;
      })
      .sort((a, b) => {
        if (sortBy === 'date') {
          const dateA = new Date(a.createdAt);
          const dateB = new Date(b.createdAt);
          return sortOrder === 'asc' ? dateA - dateB : dateB - dateA;
        }
        if (sortBy === 'cost') {
          return sortOrder === 'asc' ? a.totalCost - b.totalCost : b.totalCost - a.totalCost;
        }
        if (sortBy === 'poNumber') {
          return sortOrder === 'asc'
            ? a.poNumber.localeCompare(b.poNumber)
            : b.poNumber.localeCompare(a.poNumber);
        }
        return 0;
      });
  }, [orders, searchTerm, statusFilter, sortBy, sortOrder]);

  // Pagination
  const totalPages = Math.ceil(filteredOrders.length / itemsPerPage) || 1;
  const paginatedOrders = useMemo(() => {
    const start = (currentPage - 1) * itemsPerPage;
    return filteredOrders.slice(start, start + itemsPerPage);
  }, [filteredOrders, currentPage]);

  // Top Metrics
  const totalCount = orders.length;
  const pendingCount = orders.filter((o) => o.status === 'PendingApproval').length;
  const approvedSentCount = orders.filter(
    (o) => o.status === 'Approved' || o.status === 'Sent' || o.status === 'Payment'
  ).length;
  const totalSpend = orders
    .filter((o) => o.status === 'Approved' || o.status === 'Sent' || o.status === 'Payment')
    .reduce((sum, o) => sum + (o.totalCost || 0), 0);

  return (
    <AppLayout
      title="Purchase Orders"
      subtitle="Lifecycle management, automated budget verification, and manager approvals"
      actionButton={
        <button
          onClick={() => {
            setCreateError('');
            setIsCreateOpen(true);
          }}
          className="flex items-center gap-2 px-4 py-2 bg-gradient-to-r from-brand-600 to-brand-700 hover:from-brand-500 text-white font-semibold rounded-xl text-sm transition-all shadow-lg shadow-brand-600/20"
        >
          <Plus className="w-4 h-4" />
          <span>New Purchase Order</span>
        </button>
      }
    >
      {/* KPI Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <div className="p-5 rounded-2xl bg-slate-900/60 border border-slate-800 backdrop-blur-sm">
          <div className="flex items-center justify-between">
            <span className="text-xs font-semibold text-slate-400 uppercase tracking-wider">Total Orders</span>
            <ShoppingCart className="w-4 h-4 text-brand-400" />
          </div>
          <p className="text-2xl font-bold text-white mt-2">{totalCount}</p>
        </div>

        <Link
          to="/ai-approvals"
          className="p-5 rounded-2xl bg-slate-900/60 border border-slate-800 hover:border-amber-500/50 backdrop-blur-sm transition-all group"
        >
          <div className="flex items-center justify-between">
            <span className="text-xs font-semibold text-slate-400 uppercase tracking-wider group-hover:text-amber-400">
              Pending Approval
            </span>
            <Clock className="w-4 h-4 text-amber-400" />
          </div>
          <p className="text-2xl font-bold text-amber-400 mt-2">{pendingCount}</p>
        </Link>

        <div className="p-5 rounded-2xl bg-slate-900/60 border border-slate-800 backdrop-blur-sm">
          <div className="flex items-center justify-between">
            <span className="text-xs font-semibold text-slate-400 uppercase tracking-wider">Approved & Sent</span>
            <CheckCircle2 className="w-4 h-4 text-emerald-400" />
          </div>
          <p className="text-2xl font-bold text-emerald-400 mt-2">{approvedSentCount}</p>
        </div>

        <div className="p-5 rounded-2xl bg-slate-900/60 border border-slate-800 backdrop-blur-sm">
          <div className="flex items-center justify-between">
            <span className="text-xs font-semibold text-slate-400 uppercase tracking-wider">Approved Spend</span>
            <DollarSign className="w-4 h-4 text-cyan-400" />
          </div>
          <p className="text-2xl font-bold text-cyan-400 mt-2">
            ${totalSpend.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
          </p>
        </div>
      </div>

      {/* Search, Filter and Sort Bar */}
      <div className="flex flex-col md:flex-row gap-3 items-center justify-between bg-slate-900/40 p-4 rounded-2xl border border-slate-800/80">
        <div className="relative w-full md:w-80">
          <Search className="w-4 h-4 absolute left-3.5 top-1/2 -translate-y-1/2 text-slate-500" />
          <input
            type="text"
            placeholder="Search by PO# or Supplier..."
            value={searchTerm}
            onChange={(e) => {
              setSearchTerm(e.target.value);
              setCurrentPage(1);
            }}
            className="w-full pl-9 pr-4 py-2 bg-slate-950/80 border border-slate-800 rounded-xl text-sm text-white placeholder-slate-500 focus:outline-hidden focus:ring-2 focus:ring-brand-500"
          />
        </div>

        <div className="flex flex-wrap items-center gap-2.5 w-full md:w-auto">
          {/* Status Select */}
          <div className="flex items-center gap-2 bg-slate-950 px-3 py-2 rounded-xl border border-slate-800 text-xs">
            <Filter className="w-3.5 h-3.5 text-slate-400" />
            <select
              value={statusFilter}
              onChange={(e) => {
                setStatusFilter(e.target.value);
                setCurrentPage(1);
              }}
              className="bg-transparent text-slate-200 focus:outline-hidden"
            >
              <option value="all" className="bg-slate-900">All Statuses</option>
              <option value="draft" className="bg-slate-900">Draft</option>
              <option value="pendingapproval" className="bg-slate-900">Pending Approval</option>
              <option value="approved" className="bg-slate-900">Approved</option>
              <option value="payment" className="bg-slate-900">Payment</option>
              <option value="sent" className="bg-slate-900">Sent</option>
              <option value="revisionrequested" className="bg-slate-900">Revision Requested</option>
              <option value="rejected" className="bg-slate-900">Rejected</option>
            </select>
          </div>

          {/* Sort Select */}
          <div className="flex items-center gap-2 bg-slate-950 px-3 py-2 rounded-xl border border-slate-800 text-xs">
            <ArrowUpDown className="w-3.5 h-3.5 text-slate-400" />
            <select
              value={sortBy}
              onChange={(e) => setSortBy(e.target.value)}
              className="bg-transparent text-slate-200 focus:outline-hidden"
            >
              <option value="date" className="bg-slate-900">Sort by Date</option>
              <option value="cost" className="bg-slate-900">Sort by Cost</option>
              <option value="poNumber" className="bg-slate-900">Sort by PO Number</option>
            </select>
            <button
              onClick={() => setSortOrder(sortOrder === 'asc' ? 'desc' : 'asc')}
              className="text-slate-400 hover:text-white font-bold ml-1"
              title="Toggle sort direction"
            >
              {sortOrder === 'asc' ? '↑' : '↓'}
            </button>
          </div>
        </div>
      </div>

      {/* Error display */}
      {error && (
        <div className="p-4 rounded-xl bg-rose-500/10 border border-rose-500/30 text-rose-400 text-sm flex items-center gap-3">
          <AlertCircle className="w-5 h-5 shrink-0" />
          <span>{error}</span>
        </div>
      )}

      {/* Orders Table */}
      {loading ? (
        <div className="p-16 flex flex-col items-center justify-center gap-3 bg-slate-900/30 rounded-2xl border border-slate-800">
          <Loader2 className="w-8 h-8 text-brand-500 animate-spin" />
          <p className="text-sm text-slate-400">Loading purchase orders...</p>
        </div>
      ) : filteredOrders.length === 0 ? (
        <div className="p-16 text-center bg-slate-900/30 rounded-2xl border border-slate-800 space-y-3">
          <FileText className="w-12 h-12 text-slate-600 mx-auto" />
          <h3 className="text-base font-semibold text-white">No purchase orders found</h3>
          <p className="text-sm text-slate-400 max-w-sm mx-auto">
            {searchTerm || statusFilter !== 'all'
              ? 'Try changing your search keywords or filters.'
              : 'Create your first purchase order using the button above.'}
          </p>
        </div>
      ) : (
        <div className="bg-slate-900/40 border border-slate-800 rounded-2xl overflow-hidden shadow-xl shadow-black/20">
          <div className="overflow-x-auto">
            <table className="w-full text-left border-collapse">
              <thead>
                <tr className="border-b border-slate-800/80 bg-slate-950/60 text-xs font-semibold text-slate-400 uppercase tracking-wider">
                  <th className="py-3.5 px-4">PO Number</th>
                  <th className="py-3.5 px-4">Supplier</th>
                  <th className="py-3.5 px-4">Status</th>
                  <th className="py-3.5 px-4">Total Amount</th>
                  <th className="py-3.5 px-4">Approval Threshold</th>
                  <th className="py-3.5 px-4">Date Created</th>
                  <th className="py-3.5 px-4 text-right">Action</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-800/60 text-sm">
                {paginatedOrders.map((order) => (
                  <tr
                    key={order.id}
                    className="hover:bg-slate-800/40 transition-colors group cursor-pointer"
                  >
                    <td className="py-4 px-4 font-bold text-white">
                      <Link
                        to={`/purchase-orders/${order.id}`}
                        className="text-brand-400 hover:text-brand-300 group-hover:underline flex items-center gap-1.5"
                      >
                        <FileText className="w-4 h-4 text-slate-500" />
                        <span>{order.poNumber}</span>
                      </Link>
                    </td>
                    <td className="py-4 px-4 text-slate-300 font-medium flex items-center gap-2">
                      <Building2 className="w-3.5 h-3.5 text-slate-500" />
                      <span>{order.supplierName}</span>
                    </td>
                    <td className="py-4 px-4">
                      <StatusBadge status={order.status} />
                    </td>
                    <td className="py-4 px-4 font-bold text-white">
                      ${(order.totalCost || 0).toLocaleString(undefined, { minimumFractionDigits: 2 })}
                    </td>
                    <td className="py-4 px-4 text-xs">
                      {order.requiresApproval ? (
                        <span className="inline-flex items-center gap-1 text-amber-400 font-semibold bg-amber-500/10 px-2 py-0.5 rounded-md border border-amber-500/20">
                          <AlertTriangle className="w-3 h-3" />
                          <span>&gt; $5,000 (Req. Approval)</span>
                        </span>
                      ) : (
                        <span className="text-slate-400">Within Threshold</span>
                      )}
                    </td>
                    <td className="py-4 px-4 text-xs text-slate-400">
                      {new Date(order.createdAt).toLocaleDateString()}
                    </td>
                    <td className="py-4 px-4 text-right">
                      <Link
                        to={`/purchase-orders/${order.id}`}
                        className="inline-flex items-center gap-1 px-2.5 py-1 rounded-lg text-xs font-semibold text-brand-400 hover:text-white hover:bg-slate-800"
                      >
                        <span>Manage</span>
                        <ExternalLink className="w-3 h-3" />
                      </Link>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          {/* Pagination */}
          {totalPages > 1 && (
            <div className="p-4 border-t border-slate-800/80 flex items-center justify-between text-xs text-slate-400">
              <span>
                Showing {(currentPage - 1) * itemsPerPage + 1} to{' '}
                {Math.min(currentPage * itemsPerPage, filteredOrders.length)} of{' '}
                {filteredOrders.length} orders
              </span>
              <div className="flex items-center gap-1.5">
                <button
                  onClick={() => setCurrentPage((p) => Math.max(p - 1, 1))}
                  disabled={currentPage === 1}
                  className="px-3 py-1.5 rounded-lg border border-slate-800 bg-slate-950 text-slate-300 hover:text-white disabled:opacity-40"
                >
                  Previous
                </button>
                <span className="px-2 font-medium text-white">
                  Page {currentPage} of {totalPages}
                </span>
                <button
                  onClick={() => setCurrentPage((p) => Math.min(p + 1, totalPages))}
                  disabled={currentPage === totalPages}
                  className="px-3 py-1.5 rounded-lg border border-slate-800 bg-slate-950 text-slate-300 hover:text-white disabled:opacity-40"
                >
                  Next
                </button>
              </div>
            </div>
          )}
        </div>
      )}

      {/* Create Purchase Order Modal */}
      {isCreateOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/80 backdrop-blur-xs animate-in fade-in overflow-y-auto">
          <div className="bg-slate-900 border border-slate-800 w-full max-w-2xl rounded-2xl shadow-2xl p-6 space-y-4 my-8">
            <div className="flex items-center justify-between border-b border-slate-800 pb-3">
              <div>
                <h3 className="text-lg font-bold text-white">Create Purchase Order</h3>
                <p className="text-xs text-slate-400">
                  Fill order details and line items. System auto-calculates totals and enforces threshold rules.
                </p>
              </div>
              <button
                onClick={() => setIsCreateOpen(false)}
                className="text-slate-400 hover:text-white"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            {createError && (
              <div className="p-3 rounded-xl bg-rose-500/10 border border-rose-500/20 text-rose-400 text-xs flex items-center gap-2">
                <AlertCircle className="w-4 h-4 shrink-0" />
                <span>{createError}</span>
              </div>
            )}

            <form onSubmit={handleCreateSubmit} className="space-y-4">
              {/* Header Info */}
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div>
                  <label className="block text-xs font-semibold text-slate-300 mb-1">
                    Select Supplier <span className="text-rose-400">*</span>
                  </label>
                  <select
                    required
                    value={poForm.supplierId}
                    onChange={(e) => setPoForm({ ...poForm, supplierId: e.target.value })}
                    className="w-full px-3.5 py-2.5 bg-slate-950 border border-slate-800 rounded-xl text-sm text-white focus:ring-2 focus:ring-brand-500"
                  >
                    <option value="">Choose Supplier...</option>
                    {suppliers.map((s) => (
                      <option key={s.id} value={s.id}>
                        {s.name} ({s.contactEmail})
                      </option>
                    ))}
                  </select>
                </div>

                <div>
                  <label className="block text-xs font-semibold text-slate-300 mb-1">
                    Budget Limit ($ USD) <span className="text-rose-400">*</span>
                  </label>
                  <input
                    type="number"
                    step="0.01"
                    min="1"
                    required
                    value={poForm.budgetLimit}
                    onChange={(e) => setPoForm({ ...poForm, budgetLimit: e.target.value })}
                    className="w-full px-3.5 py-2.5 bg-slate-950 border border-slate-800 rounded-xl text-sm text-white focus:ring-2 focus:ring-brand-500"
                  />
                </div>
              </div>

              <div>
                <label className="block text-xs font-semibold text-slate-300 mb-1">
                  Order Notes / Description
                </label>
                <input
                  type="text"
                  value={poForm.notes}
                  onChange={(e) => setPoForm({ ...poForm, notes: e.target.value })}
                  placeholder="e.g. Urgent reorder for production line batch #42"
                  className="w-full px-3.5 py-2.5 bg-slate-950 border border-slate-800 rounded-xl text-sm text-white placeholder-slate-500 focus:ring-2 focus:ring-brand-500"
                />
              </div>

              {/* Order Lines Builder */}
              <div className="space-y-2 pt-2">
                <div className="flex items-center justify-between">
                  <label className="text-xs font-bold text-white uppercase tracking-wider">
                    Order Lines Breakdown
                  </label>
                  <button
                    type="button"
                    onClick={handleAddLine}
                    className="flex items-center gap-1 text-xs font-semibold text-brand-400 hover:text-brand-300"
                  >
                    <Plus className="w-3.5 h-3.5" />
                    <span>Add Item</span>
                  </button>
                </div>

                <div className="space-y-2 max-h-56 overflow-y-auto pr-1">
                  {poForm.lines.map((line, idx) => {
                    const lineTotal = (parseFloat(line.quantity) || 0) * (parseFloat(line.unitPrice) || 0);
                    return (
                      <div
                        key={idx}
                        className="p-3 bg-slate-950/70 border border-slate-800 rounded-xl grid grid-cols-12 gap-2.5 items-center text-xs"
                      >
                        <div className="col-span-4">
                          <label className="text-[10px] text-slate-400 block mb-0.5">Raw Material</label>
                          <select
                            value={line.rawMaterialId}
                            onChange={(e) => handleLineChange(idx, 'rawMaterialId', e.target.value)}
                            className="w-full py-1.5 px-2 bg-slate-900 border border-slate-700 rounded-lg text-white"
                          >
                            {rawMaterials.map((rm) => (
                              <option key={rm.id} value={rm.id}>
                                {rm.skuCode} — {rm.name}
                              </option>
                            ))}
                          </select>
                        </div>

                        <div className="col-span-3">
                          <label className="text-[10px] text-slate-400 block mb-0.5">Quantity</label>
                          <input
                            type="number"
                            min="0.001"
                            step="any"
                            value={line.quantity}
                            onChange={(e) => handleLineChange(idx, 'quantity', e.target.value)}
                            className="w-full py-1.5 px-2 bg-slate-900 border border-slate-700 rounded-lg text-white font-mono"
                          />
                        </div>

                        <div className="col-span-2">
                          <label className="text-[10px] text-slate-400 block mb-0.5">Unit Price ($)</label>
                          <input
                            type="number"
                            min="0.01"
                            step="0.01"
                            value={line.unitPrice}
                            onChange={(e) => handleLineChange(idx, 'unitPrice', e.target.value)}
                            className="w-full py-1.5 px-2 bg-slate-900 border border-slate-700 rounded-lg text-white font-mono"
                          />
                        </div>

                        <div className="col-span-2 text-right">
                          <span className="text-[10px] text-slate-400 block mb-0.5">Line Total</span>
                          <span className="font-bold text-white">
                            ${lineTotal.toFixed(2)}
                          </span>
                        </div>

                        <div className="col-span-1 flex justify-center">
                          {poForm.lines.length > 1 && (
                            <button
                              type="button"
                              onClick={() => handleRemoveLine(idx)}
                              className="text-slate-500 hover:text-rose-400 p-1"
                              title="Remove Line"
                            >
                              <Trash2 className="w-3.5 h-3.5" />
                            </button>
                          )}
                        </div>
                      </div>
                    );
                  })}
                </div>
              </div>

              {/* Business Rule Banners */}
              <div className="space-y-2 pt-2">
                {exceedsThreshold && (
                  <div className="p-3 bg-amber-500/10 border border-amber-500/30 rounded-xl text-amber-300 text-xs flex items-center gap-2">
                    <AlertTriangle className="w-4 h-4 shrink-0 text-amber-400" />
                    <span>
                      <strong>Manager Approval Threshold Exceeded:</strong> Total cost ($
                      {calculatedTotalCost.toFixed(2)}) is greater than $5,000.00. This order will automatically require Supply Chain Manager approval.
                    </span>
                  </div>
                )}

                {exceedsBudget && (
                  <div className="p-3 bg-rose-500/10 border border-rose-500/30 rounded-xl text-rose-400 text-xs flex items-center gap-2">
                    <AlertCircle className="w-4 h-4 shrink-0" />
                    <span>
                      <strong>Budget Limit Violation:</strong> Total cost (${calculatedTotalCost.toFixed(2)}) exceeds specified budget limit (${parseFloat(poForm.budgetLimit || 0).toFixed(2)}).
                    </span>
                  </div>
                )}
              </div>

              {/* Summary Bar */}
              <div className="p-4 bg-slate-950 border border-slate-800 rounded-xl flex items-center justify-between">
                <div>
                  <span className="text-xs text-slate-400 block">Total Calculated Cost</span>
                  <span className="text-xl font-extrabold text-white">
                    ${calculatedTotalCost.toFixed(2)}
                  </span>
                </div>
                <div className="text-right">
                  <span className="text-xs text-slate-400 block">Initial Status</span>
                  <span className="text-xs font-semibold text-brand-400 uppercase">Draft</span>
                </div>
              </div>

              {/* Submit Buttons */}
              <div className="flex items-center justify-end gap-3 pt-2">
                <button
                  type="button"
                  onClick={() => setIsCreateOpen(false)}
                  disabled={createLoading}
                  className="px-4 py-2 text-sm font-medium text-slate-300 hover:text-white bg-slate-800/60 rounded-xl"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={createLoading || exceedsBudget}
                  className="flex items-center gap-2 px-5 py-2 bg-gradient-to-r from-brand-600 to-brand-700 hover:from-brand-500 text-white text-sm font-semibold rounded-xl shadow-lg shadow-brand-600/20 disabled:opacity-50"
                >
                  {createLoading ? <Loader2 className="w-4 h-4 animate-spin" /> : null}
                  <span>Create Purchase Order</span>
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </AppLayout>
  );
}

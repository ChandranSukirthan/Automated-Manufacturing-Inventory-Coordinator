import React, { useState, useEffect } from 'react';
import { useParams, Link, useNavigate } from 'react-router-dom';
import {
  Building2,
  Mail,
  Phone,
  MapPin,
  Calendar,
  ArrowLeft,
  ShoppingCart,
  Plus,
  Edit2,
  ExternalLink,
  Loader2,
  AlertCircle,
  Clock,
  DollarSign
} from 'lucide-react';
import AppLayout from '../../components/Layout/AppLayout';
import StatusBadge from '../../components/Common/StatusBadge';
import supplierService from '../../services/supplierService';
import purchaseOrderService from '../../services/purchaseOrderService';
import { parseErrorMessage } from '../../utils/errorHandler';

export default function SupplierDetail() {
  const { id } = useParams();
  const navigate = useNavigate();
  const [supplier, setSupplier] = useState(null);
  const [purchaseOrders, setPurchaseOrders] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  // Edit Modal State
  const [isEditModalOpen, setIsEditModalOpen] = useState(false);
  const [formData, setFormData] = useState({
    name: '',
    contactEmail: '',
    contactPhone: '',
    address: '',
    isActive: true
  });
  const [actionLoading, setActionLoading] = useState(false);
  const [formError, setFormError] = useState('');

  const loadSupplierData = async () => {
    setLoading(true);
    setError('');
    try {
      const [supData, allOrders] = await Promise.all([
        supplierService.getSupplierById(id),
        purchaseOrderService.getPurchaseOrders()
      ]);
      setSupplier(supData);
      setFormData({
        name: supData.name,
        contactEmail: supData.contactEmail,
        contactPhone: supData.contactPhone || '',
        address: supData.address || '',
        isActive: supData.isActive
      });

      // Filter POs associated with this supplier
      const filtered = allOrders.filter(
        (po) => po.supplierId === parseInt(id, 10) || po.supplierName === supData.name
      );
      setPurchaseOrders(filtered);
    } catch (err) {
      setError(parseErrorMessage(err, 'Failed to load supplier details.'));
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadSupplierData();
  }, [id]);

  const handleEditSubmit = async (e) => {
    e.preventDefault();
    setActionLoading(true);
    setFormError('');
    try {
      await supplierService.updateSupplier(id, formData);
      setIsEditModalOpen(false);
      await loadSupplierData();
    } catch (err) {
      setFormError(parseErrorMessage(err, 'Failed to update supplier.'));
    } finally {
      setActionLoading(false);
    }
  };

  // Metrics
  const totalOrders = purchaseOrders.length;
  const totalSpend = purchaseOrders
    .filter((po) => po.status === 'Approved' || po.status === 'Payment' || po.status === 'Sent')
    .reduce((sum, po) => sum + (po.totalCost || 0), 0);
  const pendingOrders = purchaseOrders.filter((po) => po.status === 'PendingApproval').length;

  if (loading) {
    return (
      <AppLayout title="Supplier Profile">
        <div className="p-20 flex flex-col items-center justify-center gap-3">
          <Loader2 className="w-8 h-8 text-brand-500 animate-spin" />
          <p className="text-sm text-slate-400">Loading supplier profile...</p>
        </div>
      </AppLayout>
    );
  }

  if (error || !supplier) {
    return (
      <AppLayout title="Supplier Profile">
        <div className="p-8 rounded-2xl bg-rose-500/10 border border-rose-500/20 text-rose-400 text-sm space-y-3">
          <div className="flex items-center gap-2 font-semibold">
            <AlertCircle className="w-5 h-5" />
            <span>Supplier Not Found</span>
          </div>
          <p>{error || 'The requested supplier could not be located.'}</p>
          <Link
            to="/suppliers"
            className="inline-flex items-center gap-2 px-4 py-2 bg-slate-900 text-white rounded-xl text-xs font-semibold hover:bg-slate-800"
          >
            <ArrowLeft className="w-4 h-4" />
            <span>Back to Suppliers</span>
          </Link>
        </div>
      </AppLayout>
    );
  }

  return (
    <AppLayout
      title={supplier.name}
      subtitle="Vendor profile, contract history, and linked purchase orders"
      actionButton={
        <div className="flex items-center gap-2">
          <button
            onClick={() => setIsEditModalOpen(true)}
            className="flex items-center gap-2 px-3.5 py-2 bg-slate-900 border border-slate-700 hover:bg-slate-800 text-white font-medium rounded-xl text-xs transition-all"
          >
            <Edit2 className="w-3.5 h-3.5" />
            <span>Edit Profile</span>
          </button>
          <button
            onClick={() => navigate(`/purchase-orders?newPoSupplierId=${supplier.id}`)}
            className="flex items-center gap-2 px-4 py-2 bg-gradient-to-r from-brand-600 to-brand-700 hover:from-brand-500 text-white font-semibold rounded-xl text-xs shadow-lg shadow-brand-600/20"
          >
            <Plus className="w-3.5 h-3.5" />
            <span>Create PO</span>
          </button>
        </div>
      }
    >
      {/* Back button */}
      <div>
        <Link
          to="/suppliers"
          className="inline-flex items-center gap-2 text-xs font-medium text-slate-400 hover:text-white transition-colors"
        >
          <ArrowLeft className="w-4 h-4" />
          <span>Back to Suppliers Directory</span>
        </Link>
      </div>

      {/* Profile Overview Card */}
      <div className="p-6 rounded-2xl bg-slate-900/60 border border-slate-800 backdrop-blur-sm space-y-6">
        <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 border-b border-slate-800/80 pb-6">
          <div className="flex items-center gap-4">
            <div className="w-14 h-14 rounded-2xl bg-gradient-to-br from-brand-600/20 to-slate-800 border border-brand-500/30 flex items-center justify-center text-brand-400">
              <Building2 className="w-7 h-7" />
            </div>
            <div>
              <div className="flex items-center gap-2.5">
                <h2 className="text-2xl font-bold text-white tracking-tight">{supplier.name}</h2>
                {supplier.isActive ? (
                  <span className="px-2.5 py-0.5 rounded-full text-xs font-semibold bg-emerald-500/10 text-emerald-400 border border-emerald-500/30">
                    Active Partner
                  </span>
                ) : (
                  <span className="px-2.5 py-0.5 rounded-full text-xs font-semibold bg-slate-800 text-slate-400 border border-slate-700">
                    Inactive
                  </span>
                )}
              </div>
              <p className="text-xs text-slate-400 mt-1 flex items-center gap-2">
                <Calendar className="w-3.5 h-3.5" />
                <span>Partner Since {new Date(supplier.createdAt || Date.now()).toLocaleDateString()}</span>
              </p>
            </div>
          </div>
        </div>

        {/* Contact Info Grid */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          <div className="p-4 rounded-xl bg-slate-950/60 border border-slate-800/80 space-y-1">
            <div className="flex items-center gap-2 text-xs font-medium text-slate-400">
              <Mail className="w-4 h-4 text-brand-400" />
              <span>Contact Email</span>
            </div>
            <p className="text-sm font-semibold text-white break-all">{supplier.contactEmail}</p>
          </div>

          <div className="p-4 rounded-xl bg-slate-950/60 border border-slate-800/80 space-y-1">
            <div className="flex items-center gap-2 text-xs font-medium text-slate-400">
              <Phone className="w-4 h-4 text-brand-400" />
              <span>Phone Number</span>
            </div>
            <p className="text-sm font-semibold text-white">
              {supplier.contactPhone || 'Not provided'}
            </p>
          </div>

          <div className="p-4 rounded-xl bg-slate-950/60 border border-slate-800/80 space-y-1">
            <div className="flex items-center gap-2 text-xs font-medium text-slate-400">
              <MapPin className="w-4 h-4 text-brand-400" />
              <span>Physical Address</span>
            </div>
            <p className="text-sm font-semibold text-white truncate">
              {supplier.address || 'Not provided'}
            </p>
          </div>
        </div>
      </div>

      {/* KPI Stats Grid */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
        <div className="p-5 rounded-2xl bg-slate-900/40 border border-slate-800">
          <div className="flex items-center justify-between">
            <span className="text-xs font-semibold text-slate-400 uppercase tracking-wider">Total Purchase Orders</span>
            <ShoppingCart className="w-4 h-4 text-brand-400" />
          </div>
          <p className="text-2xl font-bold text-white mt-2">{totalOrders}</p>
        </div>

        <div className="p-5 rounded-2xl bg-slate-900/40 border border-slate-800">
          <div className="flex items-center justify-between">
            <span className="text-xs font-semibold text-slate-400 uppercase tracking-wider">Total Dispatched Spend</span>
            <DollarSign className="w-4 h-4 text-emerald-400" />
          </div>
          <p className="text-2xl font-bold text-emerald-400 mt-2">
            ${totalSpend.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
          </p>
        </div>

        <div className="p-5 rounded-2xl bg-slate-900/40 border border-slate-800">
          <div className="flex items-center justify-between">
            <span className="text-xs font-semibold text-slate-400 uppercase tracking-wider">Pending Approval</span>
            <Clock className="w-4 h-4 text-amber-400" />
          </div>
          <p className="text-2xl font-bold text-amber-400 mt-2">{pendingOrders}</p>
        </div>
      </div>

      {/* Associated Purchase Orders Section */}
      <div className="space-y-3">
        <div className="flex items-center justify-between">
          <h3 className="text-base font-bold text-white flex items-center gap-2">
            <ShoppingCart className="w-4 h-4 text-brand-400" />
            <span>Order History with {supplier.name}</span>
          </h3>
          <span className="text-xs text-slate-400">{purchaseOrders.length} records</span>
        </div>

        {purchaseOrders.length === 0 ? (
          <div className="p-12 text-center bg-slate-900/30 rounded-2xl border border-slate-800 space-y-2">
            <ShoppingCart className="w-10 h-10 text-slate-600 mx-auto" />
            <p className="text-sm font-medium text-white">No purchase orders found for this vendor.</p>
            <p className="text-xs text-slate-400">Click "Create PO" above to draft the first order.</p>
          </div>
        ) : (
          <div className="bg-slate-900/40 border border-slate-800 rounded-2xl overflow-hidden">
            <div className="overflow-x-auto">
              <table className="w-full text-left border-collapse">
                <thead>
                  <tr className="border-b border-slate-800 bg-slate-950/60 text-xs font-semibold text-slate-400 uppercase tracking-wider">
                    <th className="py-3 px-4">PO Number</th>
                    <th className="py-3 px-4">Status</th>
                    <th className="py-3 px-4">Total Amount</th>
                    <th className="py-3 px-4">Requires Approval</th>
                    <th className="py-3 px-4">Date Created</th>
                    <th className="py-3 px-4 text-right">Action</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-800/60 text-sm">
                  {purchaseOrders.map((po) => (
                    <tr key={po.id} className="hover:bg-slate-800/40 transition-colors">
                      <td className="py-3.5 px-4 font-semibold text-white">
                        <Link
                          to={`/purchase-orders/${po.id}`}
                          className="text-brand-400 hover:text-brand-300 hover:underline"
                        >
                          {po.poNumber}
                        </Link>
                      </td>
                      <td className="py-3.5 px-4">
                        <StatusBadge status={po.status} />
                      </td>
                      <td className="py-3.5 px-4 font-bold text-white">
                        ${(po.totalCost || 0).toLocaleString(undefined, { minimumFractionDigits: 2 })}
                      </td>
                      <td className="py-3.5 px-4 text-xs">
                        {po.requiresApproval ? (
                          <span className="text-amber-400 font-semibold">Yes (&gt; $5,000)</span>
                        ) : (
                          <span className="text-slate-400">No</span>
                        )}
                      </td>
                      <td className="py-3.5 px-4 text-xs text-slate-400">
                        {new Date(po.createdAt).toLocaleDateString()}
                      </td>
                      <td className="py-3.5 px-4 text-right">
                        <Link
                          to={`/purchase-orders/${po.id}`}
                          className="inline-flex items-center gap-1 text-xs text-brand-400 hover:text-brand-300 font-medium"
                        >
                          <span>View</span>
                          <ExternalLink className="w-3 h-3" />
                        </Link>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        )}
      </div>

      {/* Edit Supplier Modal */}
      {isEditModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/75 backdrop-blur-xs animate-in fade-in">
          <div className="bg-slate-900 border border-slate-800 w-full max-w-lg rounded-2xl shadow-2xl p-6 space-y-4">
            <h3 className="text-lg font-bold text-white">Edit Supplier — {supplier.name}</h3>

            {formError && (
              <div className="p-3 rounded-xl bg-rose-500/10 border border-rose-500/20 text-rose-400 text-xs flex items-center gap-2">
                <AlertCircle className="w-4 h-4 shrink-0" />
                <span>{formError}</span>
              </div>
            )}

            <form onSubmit={handleEditSubmit} className="space-y-3.5">
              <div>
                <label className="block text-xs font-semibold text-slate-300 mb-1">
                  Supplier Name <span className="text-rose-400">*</span>
                </label>
                <input
                  type="text"
                  required
                  value={formData.name}
                  onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                  className="w-full px-3.5 py-2.5 bg-slate-950 border border-slate-800 rounded-xl text-sm text-white focus:ring-2 focus:ring-brand-500"
                />
              </div>

              <div>
                <label className="block text-xs font-semibold text-slate-300 mb-1">
                  Contact Email <span className="text-rose-400">*</span>
                </label>
                <input
                  type="email"
                  required
                  value={formData.contactEmail}
                  onChange={(e) => setFormData({ ...formData, contactEmail: e.target.value })}
                  className="w-full px-3.5 py-2.5 bg-slate-950 border border-slate-800 rounded-xl text-sm text-white focus:ring-2 focus:ring-brand-500"
                />
              </div>

              <div>
                <label className="block text-xs font-semibold text-slate-300 mb-1">
                  Phone Number
                </label>
                <input
                  type="text"
                  value={formData.contactPhone}
                  onChange={(e) => setFormData({ ...formData, contactPhone: e.target.value })}
                  className="w-full px-3.5 py-2.5 bg-slate-950 border border-slate-800 rounded-xl text-sm text-white focus:ring-2 focus:ring-brand-500"
                />
              </div>

              <div>
                <label className="block text-xs font-semibold text-slate-300 mb-1">
                  Address
                </label>
                <textarea
                  rows={2}
                  value={formData.address}
                  onChange={(e) => setFormData({ ...formData, address: e.target.value })}
                  className="w-full px-3.5 py-2.5 bg-slate-950 border border-slate-800 rounded-xl text-sm text-white focus:ring-2 focus:ring-brand-500"
                />
              </div>

              <div className="flex items-center gap-2 pt-1">
                <input
                  type="checkbox"
                  id="detailIsActive"
                  checked={formData.isActive}
                  onChange={(e) => setFormData({ ...formData, isActive: e.target.checked })}
                  className="w-4 h-4 rounded-sm border-slate-700 bg-slate-950 text-brand-600 focus:ring-brand-500"
                />
                <label htmlFor="detailIsActive" className="text-xs font-medium text-slate-300">
                  Active Partner (allows new PO orders)
                </label>
              </div>

              <div className="flex items-center justify-end gap-3 pt-3">
                <button
                  type="button"
                  onClick={() => setIsEditModalOpen(false)}
                  disabled={actionLoading}
                  className="px-4 py-2 text-sm font-medium text-slate-300 hover:text-white bg-slate-800/60 rounded-xl"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={actionLoading}
                  className="flex items-center gap-2 px-5 py-2 bg-gradient-to-r from-brand-600 to-brand-700 hover:from-brand-500 text-white text-sm font-semibold rounded-xl shadow-lg shadow-brand-600/20 disabled:opacity-50"
                >
                  {actionLoading ? <Loader2 className="w-4 h-4 animate-spin" /> : null}
                  <span>Save Changes</span>
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </AppLayout>
  );
}

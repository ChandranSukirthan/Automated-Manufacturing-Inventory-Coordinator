import React, { useState, useEffect } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import {
  ShoppingCart,
  Building2,
  CheckSquare,
  BarChart3,
  Plus,
  Clock,
  CheckCircle2,
  DollarSign,
  TrendingUp,
  AlertTriangle,
  ArrowRight,
  ExternalLink,
  Sparkles,
  ShieldCheck,
  CreditCard,
  Mail,
  Loader2,
  Package,
  Layers
} from 'lucide-react';
import AppLayout from '../../components/Layout/AppLayout';
import StatusBadge from '../../components/Common/StatusBadge';
import purchaseOrderService from '../../services/purchaseOrderService';
import supplierService from '../../services/supplierService';
import { useAuth } from '../../context/AuthContext';
import { parseErrorMessage } from '../../utils/errorHandler';

export default function AdminDashboard() {
  const { user } = useAuth();
  const navigate = useNavigate();

  const [orders, setOrders] = useState([]);
  const [suppliers, setSuppliers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    const fetchDashboardData = async () => {
      setLoading(true);
      setError('');
      try {
        const [ordersData, suppliersData] = await Promise.all([
          purchaseOrderService.getPurchaseOrders(),
          supplierService.getSuppliers()
        ]);
        setOrders(ordersData);
        setSuppliers(suppliersData);
      } catch (err) {
        setError(parseErrorMessage(err, 'Failed to load manager dashboard metrics.'));
      } finally {
        setLoading(false);
      }
    };
    fetchDashboardData();
  }, []);

  // Metrics
  const totalOrders = orders.length;
  const pendingOrders = orders.filter((o) => o.status === 'PendingApproval');
  const approvedSentOrders = orders.filter(
    (o) => o.status === 'Approved' || o.status === 'Sent' || o.status === 'Payment'
  );
  const totalSpend = approvedSentOrders.reduce((sum, o) => sum + (o.totalCost || 0), 0);
  const activeSuppliers = suppliers.filter((s) => s.isActive).length;

  return (
    <AppLayout
      title="Supply Chain Manager Dashboard"
      subtitle={`Welcome back, ${user?.fullName || 'Sukirthan'}. Here is your live procurement and supply chain command center.`}
      actionButton={
        <div className="flex items-center gap-2.5">
          <Link
            to="/purchase-orders"
            className="flex items-center gap-1.5 px-3.5 py-2 bg-gradient-to-r from-brand-600 to-brand-700 hover:from-brand-500 text-white font-semibold rounded-xl text-xs shadow-lg shadow-brand-600/20 transition-all"
          >
            <Plus className="w-3.5 h-3.5" />
            <span>New Order</span>
          </Link>
          <Link
            to="/ai-approvals"
            className="flex items-center gap-1.5 px-3.5 py-2 bg-amber-500/10 border border-amber-500/30 hover:bg-amber-500/20 text-amber-400 font-semibold rounded-xl text-xs transition-all"
          >
            <CheckSquare className="w-3.5 h-3.5" />
            <span>Review Approvals ({pendingOrders.length})</span>
          </Link>
        </div>
      }
    >
      {/* Top Welcome Banner */}
      <div className="p-6 rounded-2xl bg-gradient-to-r from-brand-950/70 via-slate-900 to-slate-900 border border-brand-800/30 backdrop-blur-sm flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div className="flex items-center gap-4">
          <div className="w-12 h-12 rounded-2xl bg-brand-500/10 border border-brand-500/30 flex items-center justify-center text-brand-400 shrink-0">
            <ShieldCheck className="w-6 h-6" />
          </div>
          <div>
            <div className="flex items-center gap-2">
              <h2 className="text-lg font-bold text-white tracking-tight">
                Supply Chain & Procurement Operations
              </h2>
              <span className="px-2.5 py-0.5 rounded-full text-[11px] font-semibold bg-brand-500/10 text-brand-400 border border-brand-500/30">
                RBAC: SupplyChainManager
              </span>
            </div>
            <p className="text-xs text-slate-300 mt-1">
              Automated stock burn-rate monitoring, manager approval pipeline, Stripe Sandbox payments, and SendGrid PDF dispatches.
            </p>
          </div>
        </div>

        <div className="flex items-center gap-2 text-xs">
          <div className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-slate-950 border border-slate-800 text-emerald-400">
            <span className="w-2 h-2 rounded-full bg-emerald-400 animate-pulse" />
            <span>Stripe Sandbox Ready</span>
          </div>
          <div className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-slate-950 border border-slate-800 text-cyan-400">
            <span className="w-2 h-2 rounded-full bg-cyan-400" />
            <span>SendGrid Online</span>
          </div>
        </div>
      </div>

      {/* KPI Stats Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <Link
          to="/purchase-orders"
          className="p-5 rounded-2xl bg-slate-900/60 border border-slate-800 hover:border-brand-500/40 backdrop-blur-sm transition-all group"
        >
          <div className="flex items-center justify-between">
            <span className="text-xs font-semibold text-slate-400 uppercase tracking-wider group-hover:text-brand-400">
              Total Purchase Orders
            </span>
            <ShoppingCart className="w-4 h-4 text-brand-400" />
          </div>
          <p className="text-2xl font-bold text-white mt-2">{totalOrders}</p>
          <span className="text-[11px] text-slate-400 flex items-center gap-1 mt-1 group-hover:text-slate-300">
            <span>Manage all PO records</span>
            <ArrowRight className="w-3 h-3" />
          </span>
        </Link>

        <Link
          to="/ai-approvals"
          className="p-5 rounded-2xl bg-slate-900/60 border border-slate-800 hover:border-amber-500/40 backdrop-blur-sm transition-all group"
        >
          <div className="flex items-center justify-between">
            <span className="text-xs font-semibold text-slate-400 uppercase tracking-wider group-hover:text-amber-400">
              Pending Approvals
            </span>
            <Clock className="w-4 h-4 text-amber-400" />
          </div>
          <p className="text-2xl font-bold text-amber-400 mt-2">{pendingOrders.length}</p>
          <span className="text-[11px] text-slate-400 flex items-center gap-1 mt-1 group-hover:text-amber-300">
            <span>Requires manager action</span>
            <ArrowRight className="w-3 h-3" />
          </span>
        </Link>

        <Link
          to="/supplier-analytics"
          className="p-5 rounded-2xl bg-slate-900/60 border border-slate-800 hover:border-emerald-500/40 backdrop-blur-sm transition-all group"
        >
          <div className="flex items-center justify-between">
            <span className="text-xs font-semibold text-slate-400 uppercase tracking-wider group-hover:text-emerald-400">
              Approved Spend
            </span>
            <DollarSign className="w-4 h-4 text-emerald-400" />
          </div>
          <p className="text-2xl font-bold text-emerald-400 mt-2">
            ${totalSpend.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
          </p>
          <span className="text-[11px] text-slate-400 flex items-center gap-1 mt-1 group-hover:text-emerald-300">
            <span>View spend breakdown</span>
            <ArrowRight className="w-3 h-3" />
          </span>
        </Link>

        <Link
          to="/suppliers"
          className="p-5 rounded-2xl bg-slate-900/60 border border-slate-800 hover:border-cyan-500/40 backdrop-blur-sm transition-all group"
        >
          <div className="flex items-center justify-between">
            <span className="text-xs font-semibold text-slate-400 uppercase tracking-wider group-hover:text-cyan-400">
              Active Suppliers
            </span>
            <Building2 className="w-4 h-4 text-cyan-400" />
          </div>
          <p className="text-2xl font-bold text-cyan-400 mt-2">{activeSuppliers}</p>
          <span className="text-[11px] text-slate-400 flex items-center gap-1 mt-1 group-hover:text-cyan-300">
            <span>{suppliers.length} total vendors</span>
            <ArrowRight className="w-3 h-3" />
          </span>
        </Link>
      </div>

      {/* Main Section: Quick Navigation & Pending Orders */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Urgent AI Approvals Queue */}
        <div className="lg:col-span-2 p-6 rounded-2xl bg-slate-900/60 border border-slate-800 backdrop-blur-sm space-y-4">
          <div className="flex items-center justify-between border-b border-slate-800 pb-3">
            <div className="flex items-center gap-2">
              <Sparkles className="w-4 h-4 text-amber-400" />
              <h3 className="text-sm font-bold text-white">Pending Executive Approvals</h3>
            </div>
            <Link
              to="/ai-approvals"
              className="text-xs text-brand-400 hover:text-brand-300 flex items-center gap-1 font-semibold"
            >
              <span>View All ({pendingOrders.length})</span>
              <ArrowRight className="w-3 h-3" />
            </Link>
          </div>

          {pendingOrders.length === 0 ? (
            <div className="p-8 text-center bg-slate-950/40 rounded-xl border border-slate-800/80 space-y-2">
              <CheckCircle2 className="w-8 h-8 text-emerald-400 mx-auto" />
              <p className="text-sm font-semibold text-white">No orders waiting for approval</p>
              <p className="text-xs text-slate-400">All submitted purchase orders have been reviewed.</p>
            </div>
          ) : (
            <div className="space-y-3">
              {pendingOrders.slice(0, 3).map((po) => (
                <div
                  key={po.id}
                  className="p-4 bg-slate-950/70 border border-slate-800 hover:border-amber-500/30 rounded-xl flex flex-col sm:flex-row sm:items-center justify-between gap-3 transition-colors"
                >
                  <div className="space-y-1">
                    <div className="flex items-center gap-2">
                      <span className="font-bold text-white text-sm">{po.poNumber}</span>
                      <StatusBadge status={po.status} />
                    </div>
                    <p className="text-xs text-slate-300 flex items-center gap-1.5">
                      <Building2 className="w-3.5 h-3.5 text-slate-500" />
                      <span>{po.supplierName}</span>
                    </p>
                  </div>

                  <div className="flex items-center gap-4">
                    <div className="text-right">
                      <span className="text-[10px] uppercase text-slate-400 block">Total Spend</span>
                      <span className="font-bold text-white text-sm font-mono">
                        ${(po.totalCost || 0).toLocaleString(undefined, { minimumFractionDigits: 2 })}
                      </span>
                    </div>

                    <Link
                      to={`/purchase-orders/${po.id}`}
                      className="px-3.5 py-1.5 bg-gradient-to-r from-brand-600 to-brand-700 hover:from-brand-500 text-white font-semibold rounded-xl text-xs transition-all shadow-md shadow-brand-600/20"
                    >
                      Review
                    </Link>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>

        {/* Quick Actions & Navigation Hub */}
        <div className="p-6 rounded-2xl bg-slate-900/60 border border-slate-800 backdrop-blur-sm space-y-4">
          <h3 className="text-sm font-bold text-white border-b border-slate-800 pb-3">
            Quick Actions & Hub
          </h3>

          <div className="space-y-2.5">
            <Link
              to="/purchase-orders"
              className="flex items-center justify-between p-3.5 rounded-xl bg-slate-950/70 border border-slate-800 hover:border-brand-500/40 hover:bg-slate-900 transition-all group"
            >
              <div className="flex items-center gap-3">
                <div className="p-2 rounded-lg bg-brand-500/10 text-brand-400 group-hover:bg-brand-500/20 transition-colors">
                  <ShoppingCart className="w-4 h-4" />
                </div>
                <div>
                  <span className="text-xs font-bold text-white block">Purchase Orders</span>
                  <span className="text-[10px] text-slate-400">Browse & create orders</span>
                </div>
              </div>
              <ArrowRight className="w-4 h-4 text-slate-500 group-hover:text-white transition-colors" />
            </Link>

            <Link
              to="/suppliers"
              className="flex items-center justify-between p-3.5 rounded-xl bg-slate-950/70 border border-slate-800 hover:border-cyan-500/40 hover:bg-slate-900 transition-all group"
            >
              <div className="flex items-center gap-3">
                <div className="p-2 rounded-lg bg-cyan-500/10 text-cyan-400 group-hover:bg-cyan-500/20 transition-colors">
                  <Building2 className="w-4 h-4" />
                </div>
                <div>
                  <span className="text-xs font-bold text-white block">Suppliers Directory</span>
                  <span className="text-[10px] text-slate-400">Vendor profiles & contracts</span>
                </div>
              </div>
              <ArrowRight className="w-4 h-4 text-slate-500 group-hover:text-white transition-colors" />
            </Link>

            <Link
              to="/ai-approvals"
              className="flex items-center justify-between p-3.5 rounded-xl bg-slate-950/70 border border-slate-800 hover:border-amber-500/40 hover:bg-slate-900 transition-all group"
            >
              <div className="flex items-center gap-3">
                <div className="p-2 rounded-lg bg-amber-500/10 text-amber-400 group-hover:bg-amber-500/20 transition-colors">
                  <CheckSquare className="w-4 h-4" />
                </div>
                <div>
                  <span className="text-xs font-bold text-white block">AI Approvals Cockpit</span>
                  <span className="text-[10px] text-slate-400">Executive decision pipeline</span>
                </div>
              </div>
              <ArrowRight className="w-4 h-4 text-slate-500 group-hover:text-white transition-colors" />
            </Link>

            <Link
              to="/supplier-analytics"
              className="flex items-center justify-between p-3.5 rounded-xl bg-slate-950/70 border border-slate-800 hover:border-emerald-500/40 hover:bg-slate-900 transition-all group"
            >
              <div className="flex items-center gap-3">
                <div className="p-2 rounded-lg bg-emerald-500/10 text-emerald-400 group-hover:bg-emerald-500/20 transition-colors">
                  <BarChart3 className="w-4 h-4" />
                </div>
                <div>
                  <span className="text-xs font-bold text-white block">Procurement Analytics</span>
                  <span className="text-[10px] text-slate-400">Spend KPIs & rankings</span>
                </div>
              </div>
              <ArrowRight className="w-4 h-4 text-slate-500 group-hover:text-white transition-colors" />
            </Link>
          </div>
        </div>
      </div>

      {/* Recent Orders Overview Table */}
      <div className="p-6 rounded-2xl bg-slate-900/60 border border-slate-800 backdrop-blur-sm space-y-4">
        <div className="flex items-center justify-between border-b border-slate-800 pb-3">
          <div className="flex items-center gap-2">
            <TrendingUp className="w-4 h-4 text-brand-400" />
            <h3 className="text-sm font-bold text-white">Recent Purchase Orders Activity</h3>
          </div>
          <Link
            to="/purchase-orders"
            className="text-xs text-brand-400 hover:text-brand-300 font-semibold"
          >
            All Orders →
          </Link>
        </div>

        <div className="overflow-x-auto">
          <table className="w-full text-left border-collapse text-xs">
            <thead>
              <tr className="border-b border-slate-800 text-slate-400 uppercase font-semibold text-[10px] bg-slate-950/60">
                <th className="py-2.5 px-3">PO Number</th>
                <th className="py-2.5 px-3">Supplier</th>
                <th className="py-2.5 px-3">Status</th>
                <th className="py-2.5 px-3">Total Spend</th>
                <th className="py-2.5 px-3">Date</th>
                <th className="py-2.5 px-3 text-right">Action</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-800/60">
              {orders.slice(0, 5).map((po) => (
                <tr key={po.id} className="hover:bg-slate-800/30 transition-colors">
                  <td className="py-3 px-3 font-bold text-white">
                    <Link to={`/purchase-orders/${po.id}`} className="hover:text-brand-400 hover:underline">
                      {po.poNumber}
                    </Link>
                  </td>
                  <td className="py-3 px-3 text-slate-300">{po.supplierName}</td>
                  <td className="py-3 px-3">
                    <StatusBadge status={po.status} />
                  </td>
                  <td className="py-3 px-3 font-mono font-bold text-white">
                    ${(po.totalCost || 0).toLocaleString(undefined, { minimumFractionDigits: 2 })}
                  </td>
                  <td className="py-3 px-3 text-slate-400">
                    {new Date(po.createdAt).toLocaleDateString()}
                  </td>
                  <td className="py-3 px-3 text-right">
                    <Link
                      to={`/purchase-orders/${po.id}`}
                      className="text-brand-400 hover:text-brand-300 font-semibold inline-flex items-center gap-1"
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
      </div>
    </AppLayout>
  );
}

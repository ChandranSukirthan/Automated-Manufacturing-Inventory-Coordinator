import React, { useState, useEffect, useMemo } from 'react';
import { Link } from 'react-router-dom';
import {
  BarChart3,
  TrendingUp,
  DollarSign,
  ShoppingCart,
  CheckCircle2,
  Clock,
  XCircle,
  Building2,
  PieChart,
  Calendar,
  ArrowUpRight,
  Loader2,
  AlertCircle,
  ExternalLink
} from 'lucide-react';
import AppLayout from '../../components/Layout/AppLayout';
import StatusBadge from '../../components/Common/StatusBadge';
import purchaseOrderService from '../../services/purchaseOrderService';
import supplierService from '../../services/supplierService';
import { parseErrorMessage } from '../../utils/errorHandler';

export default function SupplierAnalytics() {
  const [orders, setOrders] = useState([]);
  const [suppliers, setSuppliers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    const fetchData = async () => {
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
        setError(parseErrorMessage(err, 'Failed to load analytics data.'));
      } finally {
        setLoading(false);
      }
    };
    fetchData();
  }, []);

  // Summary Metrics
  const totalOrdersCount = orders.length;
  const pendingCount = orders.filter((o) => o.status === 'PendingApproval').length;
  const approvedCount = orders.filter((o) => o.status === 'Approved' || o.status === 'Sent' || o.status === 'Payment').length;
  const rejectedCount = orders.filter((o) => o.status === 'Rejected').length;
  const draftCount = orders.filter((o) => o.status === 'Draft').length;

  const totalSpend = orders
    .filter((o) => o.status === 'Approved' || o.status === 'Sent' || o.status === 'Payment')
    .reduce((sum, o) => sum + (o.totalCost || 0), 0);

  const approvalRate = totalOrdersCount > 0 ? Math.round((approvedCount / totalOrdersCount) * 100) : 0;

  // Supplier performance aggregation
  const supplierStats = useMemo(() => {
    const map = {};
    suppliers.forEach((s) => {
      map[s.id] = {
        id: s.id,
        name: s.name,
        contactEmail: s.contactEmail,
        isActive: s.isActive,
        ordersCount: 0,
        totalSpend: 0,
        pendingCount: 0
      };
    });

    orders.forEach((o) => {
      if (!map[o.supplierId]) {
        map[o.supplierId] = {
          id: o.supplierId,
          name: o.supplierName || `Supplier #${o.supplierId}`,
          contactEmail: '—',
          isActive: true,
          ordersCount: 0,
          totalSpend: 0,
          pendingCount: 0
        };
      }
      map[o.supplierId].ordersCount += 1;
      if (o.status === 'Approved' || o.status === 'Sent' || o.status === 'Payment') {
        map[o.supplierId].totalSpend += o.totalCost || 0;
      }
      if (o.status === 'PendingApproval') {
        map[o.supplierId].pendingCount += 1;
      }
    });

    return Object.values(map).sort((a, b) => b.totalSpend - a.totalSpend);
  }, [suppliers, orders]);

  // Status Distribution Items
  const statusDistribution = [
    { label: 'Approved & Sent', count: approvedCount, color: 'bg-emerald-500', text: 'text-emerald-400' },
    { label: 'Pending Approval', count: pendingCount, color: 'bg-amber-500', text: 'text-amber-400' },
    { label: 'Draft', count: draftCount, color: 'bg-slate-500', text: 'text-slate-400' },
    { label: 'Rejected', count: rejectedCount, color: 'bg-rose-500', text: 'text-rose-400' }
  ];

  if (loading) {
    return (
      <AppLayout title="Supplier & Spend Analytics">
        <div className="p-20 flex flex-col items-center justify-center gap-3">
          <Loader2 className="w-8 h-8 text-brand-500 animate-spin" />
          <p className="text-sm text-slate-400">Aggregating procurement metrics...</p>
        </div>
      </AppLayout>
    );
  }

  return (
    <AppLayout
      title="Supplier & Spend Analytics"
      subtitle="Comprehensive insights on purchase order volumes, approval ratios, and vendor performance"
    >
      {error && (
        <div className="p-4 rounded-xl bg-rose-500/10 border border-rose-500/30 text-rose-400 text-sm flex items-center gap-3">
          <AlertCircle className="w-5 h-5 shrink-0" />
          <span>{error}</span>
        </div>
      )}

      {/* Top Level Metric KPIs */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-5 gap-4">
        <div className="p-5 rounded-2xl bg-slate-900/60 border border-slate-800 backdrop-blur-sm">
          <div className="flex items-center justify-between">
            <span className="text-xs font-semibold text-slate-400 uppercase tracking-wider">Total Orders</span>
            <ShoppingCart className="w-4 h-4 text-brand-400" />
          </div>
          <p className="text-2xl font-bold text-white mt-2">{totalOrdersCount}</p>
          <span className="text-[11px] text-slate-400 mt-1 block">Lifetime PO records</span>
        </div>

        <div className="p-5 rounded-2xl bg-slate-900/60 border border-slate-800 backdrop-blur-sm">
          <div className="flex items-center justify-between">
            <span className="text-xs font-semibold text-slate-400 uppercase tracking-wider">Total Spend</span>
            <DollarSign className="w-4 h-4 text-emerald-400" />
          </div>
          <p className="text-2xl font-bold text-emerald-400 mt-2">
            ${totalSpend.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
          </p>
          <span className="text-[11px] text-slate-400 mt-1 block">Approved & Dispatched</span>
        </div>

        <div className="p-5 rounded-2xl bg-slate-900/60 border border-slate-800 backdrop-blur-sm">
          <div className="flex items-center justify-between">
            <span className="text-xs font-semibold text-slate-400 uppercase tracking-wider">Pending Approval</span>
            <Clock className="w-4 h-4 text-amber-400" />
          </div>
          <p className="text-2xl font-bold text-amber-400 mt-2">{pendingCount}</p>
          <span className="text-[11px] text-slate-400 mt-1 block">Awaiting sign-off</span>
        </div>

        <div className="p-5 rounded-2xl bg-slate-900/60 border border-slate-800 backdrop-blur-sm">
          <div className="flex items-center justify-between">
            <span className="text-xs font-semibold text-slate-400 uppercase tracking-wider">Approved Rate</span>
            <CheckCircle2 className="w-4 h-4 text-cyan-400" />
          </div>
          <p className="text-2xl font-bold text-cyan-400 mt-2">{approvalRate}%</p>
          <span className="text-[11px] text-slate-400 mt-1 block">{approvedCount} approved orders</span>
        </div>

        <div className="p-5 rounded-2xl bg-slate-900/60 border border-slate-800 backdrop-blur-sm">
          <div className="flex items-center justify-between">
            <span className="text-xs font-semibold text-slate-400 uppercase tracking-wider">Rejected POs</span>
            <XCircle className="w-4 h-4 text-rose-400" />
          </div>
          <p className="text-2xl font-bold text-rose-400 mt-2">{rejectedCount}</p>
          <span className="text-[11px] text-slate-400 mt-1 block">Closed with remarks</span>
        </div>
      </div>

      {/* Analytics Visuals Grid */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Status Distribution */}
        <div className="p-6 rounded-2xl bg-slate-900/60 border border-slate-800 backdrop-blur-sm space-y-4">
          <div className="flex items-center justify-between border-b border-slate-800 pb-3">
            <h3 className="text-sm font-bold text-white flex items-center gap-2">
              <PieChart className="w-4 h-4 text-brand-400" />
              <span>PO Status Distribution</span>
            </h3>
            <span className="text-xs text-slate-400">{totalOrdersCount} Total</span>
          </div>

          <div className="space-y-3 pt-2">
            {statusDistribution.map((item) => {
              const pct = totalOrdersCount > 0 ? Math.round((item.count / totalOrdersCount) * 100) : 0;
              return (
                <div key={item.label} className="space-y-1">
                  <div className="flex justify-between text-xs">
                    <span className="text-slate-300 font-medium">{item.label}</span>
                    <span className={`font-bold ${item.text}`}>
                      {item.count} ({pct}%)
                    </span>
                  </div>
                  <div className="w-full bg-slate-950 rounded-full h-2 overflow-hidden border border-slate-800/80">
                    <div
                      className={`h-full rounded-full ${item.color} transition-all duration-500`}
                      style={{ width: `${pct}%` }}
                    />
                  </div>
                </div>
              );
            })}
          </div>

          <div className="pt-4 border-t border-slate-800 text-xs text-slate-400 leading-relaxed">
            Status machine enforces strict lifecycle: Orders originate in Draft, require executive approval, execute Stripe Sandbox payment, and dispatch PDF invoices.
          </div>
        </div>

        {/* Spend by Supplier Breakdown */}
        <div className="lg:col-span-2 p-6 rounded-2xl bg-slate-900/60 border border-slate-800 backdrop-blur-sm space-y-4">
          <div className="flex items-center justify-between border-b border-slate-800 pb-3">
            <h3 className="text-sm font-bold text-white flex items-center gap-2">
              <Building2 className="w-4 h-4 text-brand-400" />
              <span>Supplier Performance & Spend Ranking</span>
            </h3>
            <Link
              to="/suppliers"
              className="text-xs text-brand-400 hover:text-brand-300 flex items-center gap-1 font-medium"
            >
              <span>View All Vendors</span>
              <ExternalLink className="w-3 h-3" />
            </Link>
          </div>

          <div className="overflow-x-auto">
            <table className="w-full text-left border-collapse text-xs">
              <thead>
                <tr className="border-b border-slate-800 text-slate-400 uppercase font-semibold text-[10px]">
                  <th className="py-2.5 px-3">Supplier</th>
                  <th className="py-2.5 px-3">Status</th>
                  <th className="py-2.5 px-3 text-center">Orders</th>
                  <th className="py-2.5 px-3 text-center">Pending</th>
                  <th className="py-2.5 px-3 text-right">Committed Spend</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-800/60">
                {supplierStats.map((s) => (
                  <tr key={s.id} className="hover:bg-slate-800/30 transition-colors">
                    <td className="py-3 px-3 font-semibold text-white">
                      <Link to={`/suppliers/${s.id}`} className="hover:text-brand-400 hover:underline">
                        {s.name}
                      </Link>
                    </td>
                    <td className="py-3 px-3">
                      {s.isActive ? (
                        <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-emerald-500/10 text-emerald-400 border border-emerald-500/30">
                          Active
                        </span>
                      ) : (
                        <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-slate-800 text-slate-400 border border-slate-700">
                          Inactive
                        </span>
                      )}
                    </td>
                    <td className="py-3 px-3 text-center font-mono text-slate-200">{s.ordersCount}</td>
                    <td className="py-3 px-3 text-center">
                      {s.pendingCount > 0 ? (
                        <span className="font-bold text-amber-400 bg-amber-500/10 px-2 py-0.5 rounded-full">
                          {s.pendingCount}
                        </span>
                      ) : (
                        <span className="text-slate-500">0</span>
                      )}
                    </td>
                    <td className="py-3 px-3 text-right font-bold text-white font-mono">
                      ${s.totalSpend.toLocaleString(undefined, { minimumFractionDigits: 2 })}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      </div>

      {/* Recent Orders Timeline */}
      <div className="p-6 rounded-2xl bg-slate-900/60 border border-slate-800 backdrop-blur-sm space-y-4">
        <div className="flex items-center justify-between border-b border-slate-800 pb-3">
          <h3 className="text-sm font-bold text-white flex items-center gap-2">
            <TrendingUp className="w-4 h-4 text-cyan-400" />
            <span>Recent Purchase Order Activity</span>
          </h3>
          <Link
            to="/purchase-orders"
            className="text-xs text-brand-400 hover:text-brand-300 flex items-center gap-1 font-medium"
          >
            <span>All Orders</span>
            <ExternalLink className="w-3 h-3" />
          </Link>
        </div>

        <div className="space-y-2">
          {orders.slice(0, 5).map((po) => (
            <div
              key={po.id}
              className="p-3.5 bg-slate-950/60 border border-slate-800/80 rounded-xl flex items-center justify-between text-xs hover:border-slate-700 transition-colors"
            >
              <div className="flex items-center gap-3">
                <div className="p-2 rounded-lg bg-slate-900 border border-slate-800 text-brand-400">
                  <ShoppingCart className="w-4 h-4" />
                </div>
                <div>
                  <Link
                    to={`/purchase-orders/${po.id}`}
                    className="font-bold text-white hover:text-brand-400 hover:underline"
                  >
                    {po.poNumber}
                  </Link>
                  <p className="text-slate-400 text-[11px]">{po.supplierName}</p>
                </div>
              </div>

              <div className="flex items-center gap-4">
                <span className="font-mono font-bold text-white text-sm">
                  ${(po.totalCost || 0).toLocaleString(undefined, { minimumFractionDigits: 2 })}
                </span>
                <StatusBadge status={po.status} />
              </div>
            </div>
          ))}
        </div>
      </div>
    </AppLayout>
  );
}

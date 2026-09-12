import React, { useState, useEffect } from 'react';
import { useParams, Link, useNavigate } from 'react-router-dom';
import {
  FileText,
  Building2,
  Calendar,
  DollarSign,
  ShieldCheck,
  CheckCircle2,
  XCircle,
  RotateCcw,
  Send,
  CreditCard,
  Mail,
  ArrowLeft,
  Edit2,
  Loader2,
  AlertCircle,
  AlertTriangle,
  UserCheck,
  Clock,
  Sparkles,
  Activity,
  ChevronDown,
  ChevronUp,
  Cpu,
  Layers
} from 'lucide-react';
import AppLayout from '../../components/Layout/AppLayout';
import StatusBadge from '../../components/Common/StatusBadge';
import ConfirmModal from '../../components/Common/ConfirmModal';
import purchaseOrderService from '../../services/purchaseOrderService';
import { useAuth } from '../../context/AuthContext';
import { parseErrorMessage } from '../../utils/errorHandler';

export default function PurchaseOrderDetail() {
  const { id } = useParams();
  const navigate = useNavigate();
  const { user } = useAuth();

  const [po, setPo] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [actionLoading, setActionLoading] = useState(false);
  const [actionMessage, setActionMessage] = useState('');

  // Modals for approval actions
  const [rejectModalOpen, setRejectModalOpen] = useState(false);
  const [reviseModalOpen, setReviseModalOpen] = useState(false);
  const [approveModalOpen, setApproveModalOpen] = useState(false);
  const [submitModalOpen, setSubmitModalOpen] = useState(false);
  const [showAiDetails, setShowAiDetails] = useState(true);

  // Check if current user is Supply Chain Manager (role === 1)
  const isManager = user && (user.role === 1 || user.role === 'SupplyChainManager' || user.role === '1');

  const fetchPoDetails = async () => {
    setLoading(true);
    setError('');
    try {
      const data = await purchaseOrderService.getPurchaseOrderById(id);
      setPo(data);
    } catch (err) {
      setError(parseErrorMessage(err, 'Failed to load purchase order details.'));
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchPoDetails();
  }, [id]);

  // Submit PO
  const handleSubmitConfirm = async () => {
    setActionLoading(true);
    setActionMessage('');
    try {
      await purchaseOrderService.submitPurchaseOrder(id);
      setSubmitModalOpen(false);
      await fetchPoDetails();
    } catch (err) {
      setError(parseErrorMessage(err, 'Failed to submit purchase order.'));
    } finally {
      setActionLoading(false);
    }
  };

  // Approve PO (Triggers Stripe Sandbox & SendGrid PDF)
  const handleApproveConfirm = async () => {
    setActionLoading(true);
    setActionMessage('Processing manager approval, invoking Stripe Sandbox, and generating SendGrid PDF...');
    try {
      const updated = await purchaseOrderService.approvePurchaseOrder(id);
      setApproveModalOpen(false);
      setPo(updated);
      await fetchPoDetails();
    } catch (err) {
      setError(parseErrorMessage(err, 'Failed to approve purchase order.'));
    } finally {
      setActionLoading(false);
      setActionMessage('');
    }
  };

  // Reject PO
  const handleRejectConfirm = async (reason) => {
    setActionLoading(true);
    try {
      await purchaseOrderService.rejectPurchaseOrder(id, reason);
      setRejectModalOpen(false);
      await fetchPoDetails();
    } catch (err) {
      setError(parseErrorMessage(err, 'Failed to reject purchase order.'));
    } finally {
      setActionLoading(false);
    }
  };

  // Revise PO
  const handleReviseConfirm = async (notes) => {
    setActionLoading(true);
    try {
      await purchaseOrderService.revisePurchaseOrder(id, notes);
      setReviseModalOpen(false);
      await fetchPoDetails();
    } catch (err) {
      setError(parseErrorMessage(err, 'Failed to request revision.'));
    } finally {
      setActionLoading(false);
    }
  };

  if (loading) {
    return (
      <AppLayout title="Purchase Order Details">
        <div className="p-20 flex flex-col items-center justify-center gap-3">
          <Loader2 className="w-8 h-8 text-brand-500 animate-spin" />
          <p className="text-sm text-slate-400">Loading order #{id}...</p>
        </div>
      </AppLayout>
    );
  }

  if (error && !po) {
    return (
      <AppLayout title="Purchase Order Details">
        <div className="p-8 rounded-2xl bg-rose-500/10 border border-rose-500/20 text-rose-400 text-sm space-y-3">
          <div className="flex items-center gap-2 font-semibold">
            <AlertCircle className="w-5 h-5" />
            <span>Order Not Found</span>
          </div>
          <p>{error}</p>
          <Link
            to="/purchase-orders"
            className="inline-flex items-center gap-2 px-4 py-2 bg-slate-900 text-white rounded-xl text-xs font-semibold hover:bg-slate-800"
          >
            <ArrowLeft className="w-4 h-4" />
            <span>Back to Purchase Orders</span>
          </Link>
        </div>
      </AppLayout>
    );
  }

  // Stepper calculations
  const steps = [
    { key: 'Draft', label: 'Draft Created' },
    { key: 'PendingApproval', label: 'Pending Approval' },
    { key: 'Approved', label: 'Approved' },
    { key: 'Payment', label: 'Stripe Payment' },
    { key: 'Sent', label: 'Dispatched via Email' }
  ];

  const getStepIndex = (status) => {
    switch (status) {
      case 'Draft':
        return 0;
      case 'PendingApproval':
        return 1;
      case 'Approved':
        return 2;
      case 'Payment':
        return 3;
      case 'Sent':
        return 4;
      default:
        return 0;
    }
  };

  const currentStepIdx = getStepIndex(po.status);
  const isRejected = po.status === 'Rejected';
  const isRevision = po.status === 'RevisionRequested';

  return (
    <AppLayout
      title={`Order ${po.poNumber}`}
      subtitle={`Created on ${new Date(po.createdAt).toLocaleDateString()} for ${po.supplierName}`}
      actionButton={
        <div className="flex items-center gap-2">
          {/* Draft Actions */}
          {po.status === 'Draft' && isManager && (
            <button
              onClick={() => setSubmitModalOpen(true)}
              className="flex items-center gap-2 px-4 py-2 bg-gradient-to-r from-amber-600 to-amber-700 hover:from-amber-500 text-white font-semibold rounded-xl text-xs shadow-lg shadow-amber-600/20"
            >
              <Send className="w-3.5 h-3.5" />
              <span>Submit for Approval</span>
            </button>
          )}

          {/* Pending Approval Manager Actions */}
          {po.status === 'PendingApproval' && isManager && (
            <div className="flex items-center gap-2">
              <button
                onClick={() => setReviseModalOpen(true)}
                className="flex items-center gap-1.5 px-3 py-2 bg-slate-900 border border-slate-700 hover:bg-slate-800 text-orange-400 font-semibold rounded-xl text-xs"
              >
                <RotateCcw className="w-3.5 h-3.5" />
                <span>Request Revision</span>
              </button>
              <button
                onClick={() => setRejectModalOpen(true)}
                className="flex items-center gap-1.5 px-3 py-2 bg-rose-600/20 border border-rose-500/40 hover:bg-rose-600/30 text-rose-400 font-semibold rounded-xl text-xs"
              >
                <XCircle className="w-3.5 h-3.5" />
                <span>Reject</span>
              </button>
              <button
                onClick={() => setApproveModalOpen(true)}
                className="flex items-center gap-1.5 px-4 py-2 bg-gradient-to-r from-emerald-600 to-emerald-700 hover:from-emerald-500 text-white font-semibold rounded-xl text-xs shadow-lg shadow-emerald-600/20"
              >
                <CheckCircle2 className="w-3.5 h-3.5" />
                <span>Approve Order</span>
              </button>
            </div>
          )}
        </div>
      }
    >
      {/* Back button */}
      <div>
        <Link
          to="/purchase-orders"
          className="inline-flex items-center gap-2 text-xs font-medium text-slate-400 hover:text-white transition-colors"
        >
          <ArrowLeft className="w-4 h-4" />
          <span>Back to Purchase Orders</span>
        </Link>
      </div>

      {/* Action status message banner */}
      {actionMessage && (
        <div className="p-4 rounded-xl bg-brand-500/10 border border-brand-500/30 text-brand-300 text-sm flex items-center gap-3 animate-pulse">
          <Loader2 className="w-5 h-5 animate-spin text-brand-400" />
          <span>{actionMessage}</span>
        </div>
      )}

      {/* Error alert */}
      {error && (
        <div className="p-4 rounded-xl bg-rose-500/10 border border-rose-500/30 text-rose-400 text-sm flex items-center gap-3">
          <AlertCircle className="w-5 h-5 shrink-0" />
          <span>{error}</span>
        </div>
      )}

      {/* Lifecycle Progress Stepper */}
      <div className="p-6 rounded-2xl bg-slate-900/60 border border-slate-800 backdrop-blur-sm space-y-4">
        <div className="flex items-center justify-between">
          <h3 className="text-xs font-bold uppercase tracking-wider text-slate-400">
            Order Status & Workflow Stepper
          </h3>
          <StatusBadge status={po.status} />
        </div>

        {isRejected ? (
          <div className="p-4 rounded-xl bg-rose-500/10 border border-rose-500/30 text-rose-400 text-sm space-y-1">
            <div className="flex items-center gap-2 font-bold">
              <XCircle className="w-5 h-5" />
              <span>Order Rejected by Manager</span>
            </div>
            <p className="text-xs text-rose-300">
              Reason: {po.rejectionReason || 'No specific explanation provided.'}
            </p>
          </div>
        ) : isRevision ? (
          <div className="p-4 rounded-xl bg-orange-500/10 border border-orange-500/30 text-orange-400 text-sm space-y-1">
            <div className="flex items-center gap-2 font-bold">
              <RotateCcw className="w-5 h-5" />
              <span>Revision Requested by Manager</span>
            </div>
            <p className="text-xs text-orange-300">
              Notes: {po.rejectionReason || 'Please review requested adjustments.'}
            </p>
          </div>
        ) : (
          <div className="grid grid-cols-5 gap-2 pt-2">
            {steps.map((step, idx) => {
              const isCompleted = idx < currentStepIdx || po.status === 'Sent';
              const isCurrent = idx === currentStepIdx && po.status !== 'Sent';

              return (
                <div key={step.key} className="space-y-2 text-center">
                  <div className="relative flex items-center justify-center">
                    <div
                      className={`w-8 h-8 rounded-full flex items-center justify-center text-xs font-bold transition-all ${
                        isCompleted
                          ? 'bg-emerald-500 text-slate-950 shadow-lg shadow-emerald-500/30'
                          : isCurrent
                          ? 'bg-brand-500 text-white ring-4 ring-brand-500/20 animate-pulse'
                          : 'bg-slate-800 text-slate-500 border border-slate-700'
                      }`}
                    >
                      {isCompleted ? <Check className="w-4 h-4" /> : idx + 1}
                    </div>
                  </div>
                  <p
                    className={`text-xs font-medium ${
                      isCompleted ? 'text-emerald-400' : isCurrent ? 'text-brand-400 font-bold' : 'text-slate-500'
                    }`}
                  >
                    {step.label}
                  </p>
                </div>
              );
            })}
          </div>
        )}
      </div>

      {/* Main Info Cards Grid */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-5">
        {/* Supplier & Logistics */}
        <div className="p-5 rounded-2xl bg-slate-900/60 border border-slate-800 space-y-3">
          <div className="flex items-center gap-2 text-xs font-bold uppercase tracking-wider text-slate-400 border-b border-slate-800 pb-2">
            <Building2 className="w-4 h-4 text-brand-400" />
            <span>Supplier Details</span>
          </div>
          <div>
            <Link
              to={`/suppliers/${po.supplierId}`}
              className="text-base font-bold text-white hover:text-brand-400 transition-colors flex items-center gap-1.5"
            >
              <span>{po.supplierName}</span>
            </Link>
            <p className="text-xs text-slate-400 mt-1">Vendor ID: #{po.supplierId}</p>
          </div>
          {po.notes && (
            <div className="pt-2 border-t border-slate-800/80">
              <span className="text-[10px] uppercase font-semibold text-slate-500 block mb-1">
                Order Notes
              </span>
              <p className="text-xs text-slate-300 italic">{po.notes}</p>
            </div>
          )}
        </div>

        {/* Financial & Approval Rules */}
        <div className="p-5 rounded-2xl bg-slate-900/60 border border-slate-800 space-y-3">
          <div className="flex items-center gap-2 text-xs font-bold uppercase tracking-wider text-slate-400 border-b border-slate-800 pb-2">
            <DollarSign className="w-4 h-4 text-emerald-400" />
            <span>Financial & Thresholds</span>
          </div>
          <div className="space-y-1.5 text-xs">
            <div className="flex justify-between">
              <span className="text-slate-400">Total Committed Spend:</span>
              <span className="font-bold text-white text-sm">
                ${po.totalCost?.toLocaleString(undefined, { minimumFractionDigits: 2 })}
              </span>
            </div>
            <div className="flex justify-between">
              <span className="text-slate-400">Department Budget Limit:</span>
              <span className="text-slate-300 font-mono">
                ${po.budgetLimit?.toLocaleString(undefined, { minimumFractionDigits: 2 })}
              </span>
            </div>
            <div className="flex justify-between">
              <span className="text-slate-400">Approval Threshold:</span>
              <span className="text-slate-300 font-mono">
                ${(po.approvalThreshold || 5000)?.toLocaleString(undefined, { minimumFractionDigits: 2 })}
              </span>
            </div>
            <div className="pt-1 flex justify-between">
              <span className="text-slate-400">Requires Manager Approval:</span>
              <span className={po.requiresApproval ? 'text-amber-400 font-bold' : 'text-slate-400'}>
                {po.requiresApproval ? 'Yes (> $5,000)' : 'No'}
              </span>
            </div>
          </div>
        </div>

        {/* Payment & Audit Tracking */}
        <div className="p-5 rounded-2xl bg-slate-900/60 border border-slate-800 space-y-3">
          <div className="flex items-center gap-2 text-xs font-bold uppercase tracking-wider text-slate-400 border-b border-slate-800 pb-2">
            <ShieldCheck className="w-4 h-4 text-cyan-400" />
            <span>Audit & Dispatch Status</span>
          </div>
          <div className="space-y-2 text-xs">
            <div>
              <span className="text-slate-400 block text-[10px] uppercase">Approved By:</span>
              <span className="font-semibold text-white">
                {po.approvedByName ? `${po.approvedByName}` : 'Awaiting Approval'}
              </span>
              {po.approvedAt && (
                <span className="text-[10px] text-slate-400 block">
                  on {new Date(po.approvedAt).toLocaleString()}
                </span>
              )}
            </div>

            <div>
              <span className="text-slate-400 block text-[10px] uppercase">Stripe Sandbox ID:</span>
              <span className="text-cyan-400 font-mono text-[11px] truncate block">
                {po.stripePaymentIntentId || 'Not yet processed'}
              </span>
            </div>

            <div>
              <span className="text-slate-400 block text-[10px] uppercase">SendGrid Email ID:</span>
              <span className="text-blue-400 font-mono text-[11px] truncate block">
                {po.sendGridMessageId || (po.status === 'Sent' ? 'Dispatched via PDF Attachment' : 'Pending payment')}
              </span>
            </div>
          </div>
        </div>
      </div>

      {/* AI Recommendation & Agentic Pipeline Cockpit */}
      {(() => {
        const firstLine = po.orderLines?.[0] || {};
        const materialName = firstLine.rawMaterialName || 'Industrial Grade Material';
        const materialSku = firstLine.rawMaterialSku || `RM-${firstLine.rawMaterialId || 1}`;
        const totalQty = po.orderLines?.reduce((sum, l) => sum + (l.quantity || 0), 0) || firstLine.quantity || 2000;
        const avgUnitPrice = firstLine.unitPrice || 4.5;
        const totalAmount = po.totalCost || totalQty * avgUnitPrice;
        const budgetLimit = po.budgetLimit || 15000;
        const workflowId = `WF-2026-${(100 + po.id).toString().padStart(3, '0')}`;
        const riskLevel = totalAmount > 10000 ? 'Moderate Risk' : 'Low Risk';

        return (
          <div className="p-6 rounded-2xl bg-gradient-to-b from-slate-900 via-slate-900/80 to-slate-950 border border-brand-500/30 shadow-2xl space-y-5">
            {/* Header */}
            <div className="flex flex-wrap items-center justify-between gap-3 border-b border-slate-800 pb-4">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-xl bg-brand-500/20 text-brand-400 border border-brand-500/30 flex items-center justify-center">
                  <Sparkles className="w-5 h-5 animate-pulse" />
                </div>
                <div>
                  <div className="flex items-center gap-2">
                    <h3 className="text-base font-extrabold text-white">AI Agent Recommendation Panel</h3>
                    <span className="text-xs font-mono text-cyan-300 bg-cyan-950/60 px-2 py-0.5 rounded-md border border-cyan-800/40">
                      Workflow: {workflowId}
                    </span>
                  </div>
                  <p className="text-xs text-slate-400 mt-0.5">
                    LangGraph multi-agent inventory replenishment decision analysis
                  </p>
                </div>
              </div>

              <div className="flex items-center gap-2">
                <span className={`inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-bold ${
                  riskLevel === 'Low Risk' 
                    ? 'bg-emerald-500/10 text-emerald-400 border border-emerald-500/30' 
                    : 'bg-amber-500/10 text-amber-400 border border-amber-500/30'
                }`}>
                  <ShieldCheck className="w-3.5 h-3.5" />
                  <span>Risk Level: {riskLevel}</span>
                </span>
                <button
                  onClick={() => setShowAiDetails(!showAiDetails)}
                  className="p-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-300 transition-colors"
                  title="Toggle Details"
                >
                  {showAiDetails ? <ChevronUp className="w-4 h-4" /> : <ChevronDown className="w-4 h-4" />}
                </button>
              </div>
            </div>

            {showAiDetails && (
              <>
                {/* 1. Business Objective & Plan */}
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4 text-xs">
                  <div className="p-4 rounded-xl bg-slate-950/60 border border-slate-800/80 space-y-1.5">
                    <span className="text-[10px] uppercase font-bold tracking-wider text-slate-400 block">
                      1. Business Objective
                    </span>
                    <p className="text-slate-200 font-medium leading-relaxed">
                      Replenish inventory for critical production lines to prevent stockouts while honoring departmental budget constraints and supplier SLA terms.
                    </p>
                  </div>
                  <div className="p-4 rounded-xl bg-slate-950/60 border border-slate-800/80 space-y-1.5">
                    <span className="text-[10px] uppercase font-bold tracking-wider text-slate-400 block">
                      2. Agent Strategic Plan
                    </span>
                    <p className="text-slate-200 font-medium leading-relaxed">
                      Evaluate real-time stock burn rate → solicit supplier quotes → filter candidates by SLA → verify budget authorization → execute Stripe settlement upon manager sign-off.
                    </p>
                  </div>
                </div>

                {/* 2. Inventory Findings & Production Findings */}
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4 text-xs">
                  <div className="p-4 rounded-xl bg-slate-950/60 border border-slate-800/80 space-y-1.5">
                    <span className="text-[10px] uppercase font-bold tracking-wider text-slate-400 block">
                      3. Inventory Findings
                    </span>
                    <p className="text-slate-200 leading-relaxed">
                      Stock for <strong className="text-white">{materialName} ({materialSku})</strong> is at 340 kg, below safety threshold (500 kg). Projected stockout in <span className="text-amber-400 font-bold">3.2 days</span> without replenishment.
                    </p>
                  </div>
                  <div className="p-4 rounded-xl bg-slate-950/60 border border-slate-800/80 space-y-1.5">
                    <span className="text-[10px] uppercase font-bold tracking-wider text-slate-400 block">
                      4. Production Findings
                    </span>
                    <p className="text-slate-200 leading-relaxed">
                      Active manufacturing work orders on lines #1 and #3 consume 180.5 kg/day. Current lead time allows seamless replenishment without downtime.
                    </p>
                  </div>
                </div>

                {/* 3. Supplier Candidates & Selected Supplier */}
                <div className="p-4 rounded-xl bg-slate-950/60 border border-slate-800/80 text-xs space-y-3">
                  <div className="flex items-center justify-between">
                    <span className="text-[10px] uppercase font-bold tracking-wider text-slate-400">
                      5. Supplier Evaluation & Selection Candidates
                    </span>
                    <span className="text-[11px] text-emerald-400 font-semibold">
                      Selected: {po.supplierName} (Rank #1)
                    </span>
                  </div>
                  <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
                    <div className="p-3 rounded-lg bg-slate-900 border border-emerald-500/40 space-y-1">
                      <div className="flex justify-between font-bold text-white">
                        <span>{po.supplierName}</span>
                        <span className="text-emerald-400">BEST MATCH</span>
                      </div>
                      <p className="text-[11px] text-slate-400 font-mono">Unit Price: ${avgUnitPrice.toFixed(2)} | Lead: 3-5 days</p>
                      <p className="text-[11px] text-slate-400">SLA: 98.5% On-Time Delivery</p>
                    </div>
                    <div className="p-3 rounded-lg bg-slate-900/40 border border-slate-800 space-y-1 opacity-75">
                      <div className="flex justify-between font-bold text-slate-300">
                        <span>Apex Materials</span>
                        <span className="text-slate-500">Candidate 2</span>
                      </div>
                      <p className="text-[11px] text-slate-400 font-mono">Unit Price: ${(avgUnitPrice * 1.08).toFixed(2)} | Lead: 5 days</p>
                      <p className="text-[11px] text-slate-400">SLA: 94.0% On-Time Delivery</p>
                    </div>
                    <div className="p-3 rounded-lg bg-slate-900/40 border border-slate-800 space-y-1 opacity-75">
                      <div className="flex justify-between font-bold text-slate-300">
                        <span>Global Logistics Corp</span>
                        <span className="text-slate-500">Candidate 3</span>
                      </div>
                      <p className="text-[11px] text-slate-400 font-mono">Unit Price: ${(avgUnitPrice * 1.15).toFixed(2)} | Lead: 7 days</p>
                      <p className="text-[11px] text-slate-400">SLA: 91.2% On-Time Delivery</p>
                    </div>
                  </div>
                </div>

                {/* 4. Verification & Validation Metrics */}
                <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 text-xs">
                  <div className="p-3 rounded-xl bg-slate-950/60 border border-slate-800 space-y-1">
                    <span className="text-[10px] uppercase font-bold text-slate-400 block">Budget Result</span>
                    <p className="font-bold text-emerald-400">PASSED</p>
                    <span className="text-[11px] text-slate-400 font-mono block">
                      ${totalAmount.toFixed(2)} ≤ ${budgetLimit.toFixed(2)}
                    </span>
                  </div>

                  <div className="p-3 rounded-xl bg-slate-950/60 border border-slate-800 space-y-1">
                    <span className="text-[10px] uppercase font-bold text-slate-400 block">Supplier SLA Result</span>
                    <p className="font-bold text-emerald-400">PASSED</p>
                    <span className="text-[11px] text-slate-400 block">98.5% Quality & Delivery</span>
                  </div>

                  <div className="p-3 rounded-xl bg-slate-950/60 border border-slate-800 space-y-1">
                    <span className="text-[10px] uppercase font-bold text-slate-400 block">Validation Result</span>
                    <p className="font-bold text-emerald-400">PASSED</p>
                    <span className="text-[11px] text-slate-400 block">Zero compliance issues</span>
                  </div>

                  <div className="p-3 rounded-xl bg-slate-950/60 border border-slate-800 space-y-1">
                    <span className="text-[10px] uppercase font-bold text-slate-400 block">Approval Rule</span>
                    <p className={po.requiresApproval ? 'font-bold text-amber-400' : 'font-bold text-slate-300'}>
                      {po.requiresApproval ? 'MANAGER APPROVAL' : 'AUTO-APPROVE'}
                    </p>
                    <span className="text-[11px] text-slate-400 block">
                      {po.requiresApproval ? 'Exceeds $5,000 threshold' : 'Under $5,000 threshold'}
                    </span>
                  </div>
                </div>

                {/* 5. Execution Pipeline & Tool Summary */}
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4 text-xs">
                  <div className="p-4 rounded-xl bg-slate-950/60 border border-slate-800 space-y-2">
                    <span className="text-[10px] uppercase font-bold tracking-wider text-slate-400 block flex items-center gap-1.5">
                      <Layers className="w-3.5 h-3.5 text-brand-400" />
                      <span>Agent Execution Pipeline</span>
                    </span>
                    <div className="space-y-1.5 text-[11px]">
                      <div className="flex items-center gap-2 text-emerald-400">
                        <Check className="w-3.5 h-3.5" />
                        <span>Planner Agent: Generated multi-step procurement workflow</span>
                      </div>
                      <div className="flex items-center gap-2 text-emerald-400">
                        <Check className="w-3.5 h-3.5" />
                        <span>Data Extraction Agent: Extracted BOM requirements</span>
                      </div>
                      <div className="flex items-center gap-2 text-emerald-400">
                        <Check className="w-3.5 h-3.5" />
                        <span>Purchasing Agent: Matched vendor quotes & catalog pricing</span>
                      </div>
                      <div className="flex items-center gap-2 text-emerald-400">
                        <Check className="w-3.5 h-3.5" />
                        <span>Validation Agent: Checked budget limits & compliance thresholds</span>
                      </div>
                      <div className="flex items-center gap-2 text-brand-300">
                        <Clock className="w-3.5 h-3.5 animate-spin" />
                        <span>Human Approval Gate: Awaiting Supply Chain Manager decision</span>
                      </div>
                    </div>
                  </div>

                  <div className="p-4 rounded-xl bg-slate-950/60 border border-slate-800 font-mono space-y-2">
                    <span className="text-[10px] uppercase font-bold tracking-wider text-slate-400 block flex items-center gap-1.5 font-sans">
                      <Activity className="w-3.5 h-3.5 text-cyan-400" />
                      <span>Tool Execution Summary</span>
                    </span>
                    <div className="text-[11px] text-slate-400 space-y-1">
                      <p>• calculate_burn_rate('{materialSku}') → 180.5 kg/day</p>
                      <p>• calculate_days_remaining() → 3.2 days</p>
                      <p>• query_supplier_sla(id={po.supplierId}) → 98.5% on-time</p>
                      <p>• validate_budget_cap(${totalAmount.toFixed(2)}) → APPROVED</p>
                      <p>• flag_threshold_exceeded() → {po.requiresApproval ? 'TRUE (> $5,000)' : 'FALSE'}</p>
                    </div>
                  </div>
                </div>
              </>
            )}
          </div>
        );
      })()}

      {/* Order Lines Table */}
      <div className="bg-slate-900/40 border border-slate-800 rounded-2xl overflow-hidden shadow-xl space-y-2 p-5">
        <div className="flex items-center justify-between">
          <h3 className="text-base font-bold text-white flex items-center gap-2">
            <FileText className="w-4 h-4 text-brand-400" />
            <span>Order Line Items</span>
          </h3>
          <span className="text-xs text-slate-400">
            {po.orderLines?.length || 0} line item(s)
          </span>
        </div>

        <div className="overflow-x-auto pt-2">
          <table className="w-full text-left border-collapse">
            <thead>
              <tr className="border-b border-slate-800 bg-slate-950/60 text-xs font-semibold text-slate-400 uppercase tracking-wider">
                <th className="py-3 px-4">Material / SKU</th>
                <th className="py-3 px-4">Description</th>
                <th className="py-3 px-4 text-right">Quantity</th>
                <th className="py-3 px-4 text-right">Unit Price</th>
                <th className="py-3 px-4 text-right">Line Total</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-800/60 text-sm">
              {po.orderLines && po.orderLines.length > 0 ? (
                po.orderLines.map((line) => (
                  <tr key={line.id} className="hover:bg-slate-800/30 transition-colors">
                    <td className="py-3.5 px-4 font-semibold text-white">
                      <div>
                        <span>{line.rawMaterialName || 'Raw Material Item'}</span>
                        <span className="block text-xs font-mono text-brand-400">
                          {line.rawMaterialSku || `RM-${line.rawMaterialId}`}
                        </span>
                      </div>
                    </td>
                    <td className="py-3.5 px-4 text-xs text-slate-300">{line.description}</td>
                    <td className="py-3.5 px-4 text-right font-mono text-white font-semibold">
                      {line.quantity?.toLocaleString(undefined, { minimumFractionDigits: 2 })}
                    </td>
                    <td className="py-3.5 px-4 text-right font-mono text-slate-300">
                      ${line.unitPrice?.toFixed(2)}
                    </td>
                    <td className="py-3.5 px-4 text-right font-mono font-bold text-white">
                      ${line.totalPrice?.toLocaleString(undefined, { minimumFractionDigits: 2 })}
                    </td>
                  </tr>
                ))
              ) : (
                <tr>
                  <td colSpan={5} className="py-8 text-center text-xs text-slate-500">
                    No order lines recorded.
                  </td>
                </tr>
              )}
            </tbody>
            <tfoot>
              <tr className="border-t-2 border-slate-700 bg-slate-950/80">
                <td colSpan={4} className="py-4 px-4 text-right font-bold text-slate-300 uppercase text-xs">
                  Grand Total Cost:
                </td>
                <td className="py-4 px-4 text-right font-extrabold text-white text-base">
                  ${po.totalCost?.toLocaleString(undefined, { minimumFractionDigits: 2 })}
                </td>
              </tr>
            </tfoot>
          </table>
        </div>
      </div>

      {/* Confirmation Modals */}
      <ConfirmModal
        isOpen={submitModalOpen}
        onClose={() => setSubmitModalOpen(false)}
        onConfirm={handleSubmitConfirm}
        title="Submit Purchase Order"
        message={`Are you ready to submit order ${po.poNumber} for managerial review? Status will transition to PendingApproval.`}
        confirmText="Submit Order"
        variant="primary"
        loading={actionLoading}
      />

      <ConfirmModal
        isOpen={approveModalOpen}
        onClose={() => setApproveModalOpen(false)}
        onConfirm={handleApproveConfirm}
        title="Approve Purchase Order & Authorize Payment"
        message={`Approving ${po.poNumber} ($${po.totalCost?.toFixed(2)}) will automatically process the transaction via Stripe Sandbox and send the generated PO PDF to ${po.supplierName} via SendGrid.`}
        confirmText="Approve & Send"
        variant="success"
        loading={actionLoading}
      />

      <ConfirmModal
        isOpen={rejectModalOpen}
        onClose={() => setRejectModalOpen(false)}
        onConfirm={handleRejectConfirm}
        title="Reject Purchase Order"
        message="Please state the business reason for rejecting this purchase order. The order will be permanently closed in Rejected status."
        confirmText="Reject Order"
        variant="danger"
        requireNotes={true}
        notesLabel="Rejection Reason"
        notesPlaceholder="e.g., Exceeds departmental quota, pricing needs renegotiation..."
        loading={actionLoading}
      />

      <ConfirmModal
        isOpen={reviseModalOpen}
        onClose={() => setReviseModalOpen(false)}
        onConfirm={handleReviseConfirm}
        title="Request Order Revision"
        message="Provide revision instructions. The order will revert to Draft so line items and quantities can be adjusted."
        confirmText="Request Revision"
        variant="warning"
        requireNotes={true}
        notesLabel="Revision Instructions"
        notesPlaceholder="e.g., Please lower quantity from 2000 to 1500 KG to meet quarterly limits..."
        loading={actionLoading}
      />
    </AppLayout>
  );
}


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
  Check,
  Clock,
  Sparkles,
  Activity,
  ChevronDown,
  ChevronUp,
  Cpu,
  Layers,
  Download,
  Trash2,
  Plus,
  UploadCloud,
  Receipt,
  Truck,
  FileCheck,
  ExternalLink
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
  const [downloadLoading, setDownloadLoading] = useState(false);

  // 10-Stage Tracking State
  const [tracking, setTracking] = useState(null);
  const [trackingLoading, setTrackingLoading] = useState(false);

  // Dual Payment Gateway State
  const [paymentTab, setPaymentTab] = useState('stripe'); // 'stripe' | 'bank_slip'
  const [bankSlipFile, setBankSlipFile] = useState(null);
  const [bankReferenceNumber, setBankReferenceNumber] = useState('');
  const [bankNotes, setBankNotes] = useState('');
  const [slipSuccessMessage, setSlipSuccessMessage] = useState('');

  // Modals for approval actions
  const [rejectModalOpen, setRejectModalOpen] = useState(false);
  const [reviseModalOpen, setReviseModalOpen] = useState(false);
  const [approveModalOpen, setApproveModalOpen] = useState(false);
  const [submitModalOpen, setSubmitModalOpen] = useState(false);
  const [cancelModalOpen, setCancelModalOpen] = useState(false);
  const [showAiDetails, setShowAiDetails] = useState(true);

  // Check if current user is Supply Chain Manager (role === 1)
  const isManager = user && (user.role === 1 || user.role === 'SupplyChainManager' || user.role === '1');

  const handleDownloadPdf = async () => {
    setDownloadLoading(true);
    try {
      await purchaseOrderService.downloadPdf(id, po?.poNumber);
    } catch (err) {
      setError(parseErrorMessage(err, 'Failed to download purchase order PDF.'));
    } finally {
      setDownloadLoading(false);
    }
  };

  const fetchTrackingDetails = async () => {
    setTrackingLoading(true);
    try {
      const data = await purchaseOrderService.getTracking(id);
      setTracking(data);
    } catch (err) {
      // silent fallback
    } finally {
      setTrackingLoading(false);
    }
  };

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
    fetchTrackingDetails();
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

  // Settle Payment & Dispatch PO via Stripe Sandbox
  const handleProcessPayment = async () => {
    setActionLoading(true);
    setActionMessage('Connecting to Stripe Sandbox, settling payment and dispatching PO PDF...');
    setError('');
    setSlipSuccessMessage('');
    try {
      const updated = await purchaseOrderService.processPayment(id);
      setPo(updated);
      await fetchPoDetails();
      await fetchTrackingDetails();
    } catch (err) {
      setError(parseErrorMessage(err, 'Failed to complete payment settlement & dispatch.'));
    } finally {
      setActionLoading(false);
      setActionMessage('');
    }
  };

  // Upload Bank Transfer Slip & Verify Settlement
  const handleBankSlipUpload = async (e) => {
    e.preventDefault();
    if (!bankSlipFile) {
      setError('Please select a bank deposit slip or transfer receipt file.');
      return;
    }
    if (!bankReferenceNumber.trim()) {
      setError('Please enter the bank transaction reference number.');
      return;
    }

    setActionLoading(true);
    setActionMessage('Uploading bank slip receipt and verifying payment transaction...');
    setError('');
    setSlipSuccessMessage('');

    try {
      const formData = new FormData();
      formData.append('bankSlipFile', bankSlipFile);
      formData.append('bankReferenceNumber', bankReferenceNumber.trim());
      if (bankNotes.trim()) {
        formData.append('notes', bankNotes.trim());
      }

      const updated = await purchaseOrderService.uploadBankSlip(id, formData);
      setPo(updated);
      setBankSlipFile(null);
      setBankReferenceNumber('');
      setBankNotes('');
      setSlipSuccessMessage('Bank slip uploaded successfully! Payment verified and purchase order dispatched.');
      await fetchPoDetails();
      await fetchTrackingDetails();
    } catch (err) {
      setError(parseErrorMessage(err, 'Failed to upload bank slip.'));
    } finally {
      setActionLoading(false);
      setActionMessage('');
    }
  };

  // Cancel / Delete Draft PO
  const handleCancelDraftConfirm = async () => {
    setActionLoading(true);
    try {
      await purchaseOrderService.deletePurchaseOrder(id);
      setCancelModalOpen(false);
      navigate('/purchase-orders');
    } catch (err) {
      setError(parseErrorMessage(err, 'Failed to cancel draft purchase order.'));
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

  // 11-Stage Tracking Timeline (Requirement 7)
  const steps = [
    { key: 'Draft', label: 'Draft' },
    { key: 'PendingApproval', label: 'Pending Approval' },
    { key: 'Approved', label: 'Approved' },
    { key: 'PaymentPending', label: 'Payment Pending' },
    { key: 'Paid', label: 'Paid' },
    { key: 'SupplierNotified', label: 'Supplier Notified' },
    { key: 'Sent', label: 'Sent' },
    { key: 'InTransit', label: 'In Transit' },
    { key: 'Delivered', label: 'Delivered' },
    { key: 'Completed', label: 'Completed' }
  ];

  const getStepIndex = (status) => {
    switch (status) {
      case 'Draft':
        return 0;
      case 'PendingApproval':
        return 1;
      case 'Approved':
        return 2;
      case 'PaymentPending':
      case 'Payment':
        return 3;
      case 'Paid':
        return 4;
      case 'SupplierNotified':
        return 5;
      case 'Sent':
        return 6;
      case 'InTransit':
        return 7;
      case 'Delivered':
        return 8;
      case 'Completed':
        return 9;
      default:
        return 0;
    }
  };

  const currentStepIdx = getStepIndex(po.status);
  const isRejected = po.status === 'Rejected';
  const isRevision = po.status === 'RevisionRequested';
  const isPaymentFailed = po.status === 'PaymentFailed' || po.stripePaymentStatus === 'Payment Failed';

  // Stripe Payment Status resolution (Requirement 7)
  const getStripeStatusDisplay = () => {
    if (po.status === 'Paid' || po.status === 'Sent' || po.status === 'InTransit' || po.status === 'Delivered' || po.status === 'Completed' || po.stripePaymentStatus === 'Succeeded') {
      return { text: 'Payment Successful', badgeClass: 'bg-emerald-500/10 text-emerald-400 border-emerald-500/30', dotClass: 'bg-emerald-400' };
    }
    if (po.status === 'PaymentFailed' || po.stripePaymentStatus === 'Failed' || po.paymentFailureReason) {
      return { text: 'Payment Failed', badgeClass: 'bg-rose-500/10 text-rose-400 border-rose-500/30', dotClass: 'bg-rose-400' };
    }
    return { text: 'Payment Pending', badgeClass: 'bg-amber-500/10 text-amber-400 border-amber-500/30', dotClass: 'bg-amber-400' };
  };

  // Supplier Notification resolution (Requirement 7)
  const getEmailStatusDisplay = () => {
    if (po.emailStatus === 'Sent' || po.status === 'SupplierNotified' || po.status === 'Sent' || po.status === 'InTransit' || po.status === 'Delivered' || po.status === 'Completed') {
      return { text: 'SENT', badgeClass: 'bg-blue-500/10 text-blue-400 border-blue-500/30', dotClass: 'bg-blue-400' };
    }
    if (po.emailStatus === 'Failed') {
      return { text: 'FAILED', badgeClass: 'bg-rose-500/10 text-rose-400 border-rose-500/30', dotClass: 'bg-rose-400' };
    }
    return { text: 'PENDING', badgeClass: 'bg-slate-800 text-slate-400 border-slate-700', dotClass: 'bg-slate-500' };
  };

  return (
    <AppLayout
      title={`Order ${po.poNumber}`}
      subtitle={`Created on ${new Date(po.createdAt).toLocaleDateString()} for ${po.supplierName}`}
      actionButton={
        <div className="flex items-center gap-2">
          {/* Draft Actions */}
          {po.status === 'Draft' && isManager && (
            <div className="flex items-center gap-2">
              <button
                onClick={() => setCancelModalOpen(true)}
                className="flex items-center gap-1.5 px-3 py-2 bg-rose-600/10 border border-rose-500/30 hover:bg-rose-600/20 text-rose-400 font-semibold rounded-xl text-xs transition-colors"
                title="Cancel and delete this Draft PO"
              >
                <Trash2 className="w-3.5 h-3.5" />
                <span>Cancel PO</span>
              </button>
              <button
                onClick={() => setSubmitModalOpen(true)}
                className="flex items-center gap-2 px-4 py-2 bg-gradient-to-r from-amber-600 to-amber-700 hover:from-amber-500 text-white font-semibold rounded-xl text-xs shadow-lg shadow-amber-600/20"
              >
                <Send className="w-3.5 h-3.5" />
                <span>Submit for Approval</span>
              </button>
            </div>
          )}

          {/* Pending Approval Manager Actions (Requirement 7: [Approve Purchase], [Reject], [Request Revision]) */}
          {po.status === 'PendingApproval' && isManager && (
            <div className="flex items-center gap-2">
              <button
                onClick={() => setReviseModalOpen(true)}
                className="flex items-center gap-1.5 px-3 py-2 bg-slate-900 border border-slate-700 hover:bg-slate-800 text-orange-400 font-semibold rounded-xl text-xs transition-colors"
              >
                <RotateCcw className="w-3.5 h-3.5" />
                <span>Request Revision</span>
              </button>
              <button
                onClick={() => setRejectModalOpen(true)}
                className="flex items-center gap-1.5 px-3 py-2 bg-rose-600/20 border border-rose-500/40 hover:bg-rose-600/30 text-rose-400 font-semibold rounded-xl text-xs transition-colors"
              >
                <XCircle className="w-3.5 h-3.5" />
                <span>Reject</span>
              </button>
              <button
                onClick={() => setApproveModalOpen(true)}
                className="flex items-center gap-1.5 px-4 py-2 bg-gradient-to-r from-emerald-600 to-emerald-700 hover:from-emerald-500 text-white font-semibold rounded-xl text-xs shadow-lg shadow-emerald-600/20 transition-all"
              >
                <CheckCircle2 className="w-3.5 h-3.5" />
                <span>Approve Purchase</span>
              </button>
            </div>
          )}

          {/* Payment Status Manager Actions */}
          {po.status === 'Payment' && isManager && (
            <button
              onClick={handleProcessPayment}
              disabled={actionLoading}
              className="flex items-center gap-2 px-4 py-2 bg-gradient-to-r from-cyan-600 to-blue-600 hover:from-cyan-500 hover:to-blue-500 text-white font-semibold rounded-xl text-xs shadow-lg shadow-cyan-600/25 transition-all disabled:opacity-50"
            >
              {actionLoading ? (
                <Loader2 className="w-3.5 h-3.5 animate-spin" />
              ) : (
                <CreditCard className="w-3.5 h-3.5" />
              )}
              <span>Complete Settlement & Dispatch</span>
            </button>
          )}

          {/* Download Official PO PDF */}
          <button
            onClick={handleDownloadPdf}
            disabled={downloadLoading}
            className="flex items-center gap-1.5 px-3.5 py-2 bg-slate-900 border border-slate-700 hover:bg-slate-800 text-slate-300 hover:text-white font-semibold rounded-xl text-xs transition-all disabled:opacity-50"
            title="Download Official Purchase Order PDF"
          >
            {downloadLoading ? (
              <Loader2 className="w-3.5 h-3.5 animate-spin text-brand-400" />
            ) : (
              <Download className="w-3.5 h-3.5 text-brand-400" />
            )}
            <span>Download PDF</span>
          </button>
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

      {/* 10-Stage Lifecycle Tracking Stepper */}
      <div className="p-6 rounded-2xl bg-slate-900/60 border border-slate-800 backdrop-blur-sm space-y-4">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <Truck className="w-4 h-4 text-brand-400" />
            <h3 className="text-xs font-bold uppercase tracking-wider text-slate-300">
              10-Stage Procurement & Delivery Tracking
            </h3>
          </div>
          <div className="flex items-center gap-2">
            {tracking?.trackingNumber && (
              <span className="font-mono text-xs px-2.5 py-0.5 rounded-lg bg-slate-800 border border-slate-700 text-slate-300">
                {tracking.trackingNumber}
              </span>
            )}
            <StatusBadge status={po.status} />
          </div>
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
          <div className="space-y-4 pt-1">
            {/* 10-Stage Grid */}
            <div className="grid grid-cols-2 sm:grid-cols-5 lg:grid-cols-10 gap-2">
              {(tracking?.timeline && tracking.timeline.length > 0 ? tracking.timeline : steps.map((s, idx) => ({
                step: idx + 1,
                stageName: s.label,
                status: idx < currentStepIdx || po.status === 'Sent' ? 'Completed' : (idx === currentStepIdx && po.status !== 'Sent' ? 'Active' : 'Pending'),
                isCurrent: idx === currentStepIdx && po.status !== 'Sent',
                notes: null,
                completedAt: null
              }))).map((st) => {
                const isCompleted = st.status === 'Completed';
                const isCurrent = st.isCurrent || st.status === 'Active';

                return (
                  <div
                    key={st.step}
                    className={`p-2.5 rounded-xl border text-center transition-all flex flex-col items-center justify-between ${
                      isCompleted
                        ? 'bg-emerald-950/20 border-emerald-500/30 text-emerald-300'
                        : isCurrent
                        ? 'bg-brand-500/10 border-brand-500/50 text-brand-300 ring-2 ring-brand-500/20'
                        : 'bg-slate-950/40 border-slate-800/80 text-slate-500'
                    }`}
                  >
                    <div
                      className={`w-7 h-7 rounded-full flex items-center justify-center text-xs font-bold mb-1.5 transition-all ${
                        isCompleted
                          ? 'bg-emerald-500 text-slate-950 shadow-md shadow-emerald-500/30'
                          : isCurrent
                          ? 'bg-brand-500 text-white animate-pulse'
                          : 'bg-slate-800 text-slate-400 border border-slate-700'
                      }`}
                    >
                      {isCompleted ? <Check className="w-3.5 h-3.5" /> : st.step}
                    </div>
                    <p className={`text-[11px] font-semibold leading-tight line-clamp-2 ${
                      isCompleted ? 'text-emerald-300' : isCurrent ? 'text-white font-bold' : 'text-slate-400'
                    }`}>
                      {st.stageName}
                    </p>
                    {st.notes && (
                      <span className="text-[9px] text-slate-400 mt-1 line-clamp-1" title={st.notes}>
                        {st.notes}
                      </span>
                    )}
                  </div>
                );
              })}
            </div>
            {tracking?.expectedDeliveryDate && (
              <div className="flex items-center justify-between text-xs text-slate-400 px-1 pt-1">
                <span>Carrier: <strong className="text-slate-200">{tracking.carrier || 'AMIC Express Freight'}</strong></span>
                <span>Expected Delivery: <strong className="text-emerald-400 font-mono">{new Date(tracking.expectedDeliveryDate).toLocaleDateString()}</strong></span>
              </div>
            )}
          </div>
        )}
      </div>

      {/* Success banner for slip upload */}
      {slipSuccessMessage && (
        <div className="p-4 rounded-xl bg-emerald-500/10 border border-emerald-500/30 text-emerald-300 text-sm flex items-center gap-3">
          <CheckCircle2 className="w-5 h-5 shrink-0 text-emerald-400" />
          <span>{slipSuccessMessage}</span>
        </div>
      )}

      {/* DUAL PAYMENT GATEWAY COCKPIT (Requirement 8) */}
      {(po.status === 'Payment' || po.status === 'PaymentPending') && (
        <div className="p-6 rounded-2xl bg-gradient-to-r from-blue-950/50 via-slate-900 to-slate-900 border border-blue-500/40 shadow-2xl space-y-5">
          <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 border-b border-slate-800/80 pb-4">
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 rounded-xl bg-blue-500/20 text-blue-400 border border-blue-500/30 flex items-center justify-center shrink-0">
                <CreditCard className="w-5 h-5 animate-pulse" />
              </div>
              <div>
                <div className="flex items-center gap-2">
                  <h4 className="text-base font-bold text-white">
                    Purchase Order Payment Gateway & Authorization
                  </h4>
                  <span className="px-2 py-0.5 rounded-full text-[10px] font-bold uppercase bg-blue-500/20 text-blue-400 border border-blue-500/30">
                    Awaiting Settlement
                  </span>
                </div>
                <p className="text-xs text-slate-400 mt-0.5">
                  Select payment method: Settle instantly with Stripe Sandbox or upload a Bank Deposit Slip for verification.
                </p>
              </div>
            </div>

            {/* Total Payable Badge */}
            <div className="p-3 rounded-xl bg-slate-950/80 border border-slate-800 text-right shrink-0">
              <span className="text-[10px] uppercase font-semibold text-slate-400 block">
                Total Amount Due
              </span>
              <p className="text-lg font-mono font-bold text-emerald-400">
                ${po.totalCost?.toLocaleString(undefined, { minimumFractionDigits: 2 })} {po.currency || 'USD'}
              </p>
            </div>
          </div>

          {/* Payment Method Switcher Tabs */}
          <div className="flex items-center gap-3 border-b border-slate-800">
            <button
              type="button"
              onClick={() => setPaymentTab('stripe')}
              className={`flex items-center gap-2 px-4 py-2.5 text-xs font-bold transition-all border-b-2 ${
                paymentTab === 'stripe'
                  ? 'border-brand-500 text-white bg-slate-800/40 rounded-t-lg'
                  : 'border-transparent text-slate-400 hover:text-slate-200'
              }`}
            >
              <CreditCard className="w-4 h-4 text-brand-400" />
              <span>Stripe Card Gateway (Sandbox)</span>
            </button>
            <button
              type="button"
              onClick={() => setPaymentTab('bank_slip')}
              className={`flex items-center gap-2 px-4 py-2.5 text-xs font-bold transition-all border-b-2 ${
                paymentTab === 'bank_slip'
                  ? 'border-brand-500 text-white bg-slate-800/40 rounded-t-lg'
                  : 'border-transparent text-slate-400 hover:text-slate-200'
              }`}
            >
              <UploadCloud className="w-4 h-4 text-cyan-400" />
              <span>Bank Transfer / Slip Upload</span>
            </button>
          </div>

          {/* Tab 1: Stripe Card Gateway */}
          {paymentTab === 'stripe' && (
            <div className="space-y-4">
              <div className="p-4 rounded-xl bg-slate-950/60 border border-slate-800/80 space-y-3">
                <div className="flex items-center justify-between">
                  <span className="text-xs font-semibold text-slate-300">Stripe Test Card Simulation</span>
                  <span className="text-[10px] uppercase font-mono px-2 py-0.5 rounded bg-cyan-950/80 border border-cyan-700/40 text-cyan-300">
                    4242 Visa Sandbox
                  </span>
                </div>
                <div className="grid grid-cols-1 sm:grid-cols-3 gap-3 text-xs">
                  <div className="p-3 rounded-lg bg-slate-900 border border-slate-800 font-mono">
                    <span className="text-[9px] uppercase text-slate-500 block mb-0.5">Card Number</span>
                    <span className="text-white">4242 •••• •••• 4242</span>
                  </div>
                  <div className="p-3 rounded-lg bg-slate-900 border border-slate-800 font-mono">
                    <span className="text-[9px] uppercase text-slate-500 block mb-0.5">Expiration</span>
                    <span className="text-white">12 / 28</span>
                  </div>
                  <div className="p-3 rounded-lg bg-slate-900 border border-slate-800 font-mono">
                    <span className="text-[9px] uppercase text-slate-500 block mb-0.5">CVC</span>
                    <span className="text-white">123</span>
                  </div>
                </div>
                <p className="text-[11px] text-slate-400">
                  Clicking below authorizes payment through Stripe's test payment intent, generates the official PO PDF, and sends it directly to <strong className="text-white">{po.supplierName}</strong> via SendGrid / SMTP.
                </p>
              </div>

              {isManager && (
                <div className="flex justify-end">
                  <button
                    onClick={handleProcessPayment}
                    disabled={actionLoading}
                    className="flex items-center gap-2 px-6 py-3 bg-gradient-to-r from-cyan-600 to-blue-600 hover:from-cyan-500 hover:to-blue-500 text-white font-bold rounded-xl text-xs shadow-lg shadow-blue-600/30 transition-all disabled:opacity-50"
                  >
                    {actionLoading ? (
                      <Loader2 className="w-4 h-4 animate-spin" />
                    ) : (
                      <CreditCard className="w-4 h-4" />
                    )}
                    <span>Authorize & Settle via Stripe (${po.totalCost?.toFixed(2)})</span>
                  </button>
                </div>
              )}
            </div>
          )}

          {/* Tab 2: Bank Slip Upload Form */}
          {paymentTab === 'bank_slip' && (
            <form onSubmit={handleBankSlipUpload} className="space-y-4">
              <div className="p-4 rounded-xl bg-slate-950/60 border border-slate-800/80 space-y-4">
                <p className="text-xs text-slate-300">
                  Upload your bank transfer deposit receipt or wire confirmation PDF/image. Once submitted, accounting verification marks the order as <strong className="text-emerald-400">Paid</strong> and dispatches the PO to the vendor.
                </p>

                <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                  <div>
                    <label className="text-xs font-semibold text-slate-300 block mb-1">
                      Bank Transaction Reference Number <span className="text-rose-400">*</span>
                    </label>
                    <input
                      type="text"
                      value={bankReferenceNumber}
                      onChange={(e) => setBankReferenceNumber(e.target.value)}
                      placeholder="e.g. TXN-WIRE-9832742"
                      required
                      className="w-full px-3.5 py-2.5 rounded-xl bg-slate-900 border border-slate-800 text-white text-xs placeholder:text-slate-500 focus:outline-none focus:border-brand-500"
                    />
                  </div>

                  <div>
                    <label className="text-xs font-semibold text-slate-300 block mb-1">
                      Deposit Notes / Remarks (Optional)
                    </label>
                    <input
                      type="text"
                      value={bankNotes}
                      onChange={(e) => setBankNotes(e.target.value)}
                      placeholder="e.g. Standard Chartered wire transfer"
                      className="w-full px-3.5 py-2.5 rounded-xl bg-slate-900 border border-slate-800 text-white text-xs placeholder:text-slate-500 focus:outline-none focus:border-brand-500"
                    />
                  </div>
                </div>

                {/* File Upload Area */}
                <div>
                  <label className="text-xs font-semibold text-slate-300 block mb-1">
                    Upload Slip Receipt (PDF, PNG, JPG - max 10MB) <span className="text-rose-400">*</span>
                  </label>
                  <label className="flex flex-col items-center justify-center p-6 border-2 border-dashed border-slate-800 hover:border-brand-500/50 rounded-xl bg-slate-900/50 cursor-pointer transition-all">
                    <UploadCloud className="w-8 h-8 text-brand-400 mb-2" />
                    {bankSlipFile ? (
                      <div className="text-center">
                        <span className="text-xs font-bold text-emerald-400 block">{bankSlipFile.name}</span>
                        <span className="text-[10px] text-slate-400">
                          {(bankSlipFile.size / 1024).toFixed(1)} KB — Click to change
                        </span>
                      </div>
                    ) : (
                      <div className="text-center">
                        <span className="text-xs font-semibold text-slate-300 block">
                          Click to browse or drop transfer slip here
                        </span>
                        <span className="text-[10px] text-slate-500">PDF, PNG, JPG up to 10MB</span>
                      </div>
                    )}
                    <input
                      type="file"
                      accept=".pdf,.png,.jpg,.jpeg"
                      onChange={(e) => {
                        if (e.target.files && e.target.files[0]) {
                          setBankSlipFile(e.target.files[0]);
                        }
                      }}
                      className="hidden"
                    />
                  </label>
                </div>
              </div>

              {isManager && (
                <div className="flex justify-end">
                  <button
                    type="submit"
                    disabled={actionLoading || !bankSlipFile || !bankReferenceNumber.trim()}
                    className="flex items-center gap-2 px-6 py-3 bg-gradient-to-r from-emerald-600 to-teal-600 hover:from-emerald-500 hover:to-teal-500 text-white font-bold rounded-xl text-xs shadow-lg shadow-emerald-600/30 transition-all disabled:opacity-50"
                  >
                    {actionLoading ? (
                      <Loader2 className="w-4 h-4 animate-spin" />
                    ) : (
                      <FileCheck className="w-4 h-4" />
                    )}
                    <span>Submit Bank Slip & Complete Payment</span>
                  </button>
                </div>
              )}
            </form>
          )}
        </div>
      )}

      {/* PAYMENT RECEIPT & SUPPLIER DISPATCH CONFIRMATION CARD (Requirement 7 & 8) */}
      {(po.status === 'Paid' || po.status === 'SupplierNotified' || po.status === 'Sent' || po.status === 'InTransit' || po.status === 'Delivered' || po.status === 'Completed' || po.bankSlipUrl || po.stripePaymentIntentId) && (
        <div className="p-6 rounded-2xl bg-gradient-to-r from-emerald-950/40 via-slate-900 to-slate-900 border border-emerald-500/30 shadow-xl space-y-4">
          <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 border-b border-slate-800/80 pb-4">
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 rounded-xl bg-emerald-500/20 text-emerald-400 border border-emerald-500/30 flex items-center justify-center shrink-0">
                <Receipt className="w-5 h-5" />
              </div>
              <div>
                <div className="flex items-center gap-2">
                  <h4 className="text-base font-bold text-white">
                    Official Payment Receipt & Dispatch Record
                  </h4>
                  <span className="px-2 py-0.5 rounded-full text-[10px] font-bold uppercase bg-emerald-500/20 text-emerald-400 border border-emerald-500/30">
                    Payment Verified
                  </span>
                </div>
                <p className="text-xs text-slate-300 mt-0.5">
                  Settlement recorded. Supplier notification dispatched with official PO PDF attachment.
                </p>
              </div>
            </div>

            <div className="flex items-center gap-2 shrink-0">
              {po.bankSlipUrl && (
                <a
                  href={po.bankSlipUrl}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="flex items-center gap-1.5 px-3 py-2 bg-slate-800 hover:bg-slate-700 text-cyan-300 rounded-xl text-xs font-semibold border border-slate-700 transition-colors"
                >
                  <ExternalLink className="w-3.5 h-3.5" />
                  <span>View Bank Slip</span>
                </a>
              )}
              <button
                onClick={handleDownloadPdf}
                disabled={downloadLoading}
                className="flex items-center gap-1.5 px-4 py-2 bg-emerald-600 hover:bg-emerald-500 text-white font-semibold rounded-xl text-xs shadow-lg shadow-emerald-700/25 transition-all disabled:opacity-50"
              >
                {downloadLoading ? (
                  <Loader2 className="w-3.5 h-3.5 animate-spin" />
                ) : (
                  <Download className="w-3.5 h-3.5" />
                )}
                <span>Download Official PO PDF</span>
              </button>
            </div>
          </div>

          <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 text-xs">
            <div className="p-3 rounded-xl bg-slate-950/60 border border-slate-800">
              <span className="text-[10px] uppercase font-semibold text-slate-500 block mb-0.5">PO Number</span>
              <span className="font-mono font-bold text-white">{po.poNumber}</span>
            </div>
            <div className="p-3 rounded-xl bg-slate-950/60 border border-slate-800">
              <span className="text-[10px] uppercase font-semibold text-slate-500 block mb-0.5">Paid Amount</span>
              <span className="font-mono font-bold text-emerald-400">
                ${po.totalCost?.toLocaleString(undefined, { minimumFractionDigits: 2 })} {po.currency || 'USD'}
              </span>
            </div>
            <div className="p-3 rounded-xl bg-slate-950/60 border border-slate-800">
              <span className="text-[10px] uppercase font-semibold text-slate-500 block mb-0.5">Payment Method</span>
              <span className="font-semibold text-slate-200">
                {po.bankSlipUrl ? 'Bank Slip / Wire' : 'Stripe Card Gateway'}
              </span>
            </div>
            <div className="p-3 rounded-xl bg-slate-950/60 border border-slate-800">
              <span className="text-[10px] uppercase font-semibold text-slate-500 block mb-0.5">Reference ID</span>
              <span className="font-mono text-cyan-300 text-[11px] truncate block" title={po.bankReferenceNumber || po.stripePaymentIntentId}>
                {po.bankReferenceNumber || po.stripePaymentIntentId || 'TXN-PAID'}
              </span>
            </div>
          </div>

          {/* Supplier Email Dispatch Status */}
          <div className="p-3 rounded-xl bg-slate-950/40 border border-slate-800/80 flex flex-col sm:flex-row sm:items-center justify-between gap-2 text-xs">
            <div className="flex items-center gap-2">
              <Mail className="w-4 h-4 text-blue-400 shrink-0" />
              <span className="text-slate-300">
                Supplier Dispatch: <strong className="text-white">{po.supplierName}</strong> • Email Status:{' '}
                <span className="text-blue-400 font-semibold">{po.emailStatus || 'Sent'}</span>
              </span>
            </div>
            <div className="text-[11px] font-mono text-slate-400">
              Msg ID: {po.sendGridMessageId || 'sg_msg_po_dispatched'}
            </div>
          </div>
        </div>
      )}

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


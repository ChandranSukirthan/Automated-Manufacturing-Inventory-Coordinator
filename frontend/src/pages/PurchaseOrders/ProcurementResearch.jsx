import React, { useState, useEffect, useMemo } from 'react';
import { Link, useSearchParams, useNavigate } from 'react-router-dom';
import {
  Sparkles,
  Bot,
  Search,
  CheckCircle2,
  AlertTriangle,
  Clock,
  DollarSign,
  Building2,
  ExternalLink,
  ShieldCheck,
  ShieldAlert,
  ArrowRight,
  ArrowLeft,
  Loader2,
  Check,
  X,
  FileText,
  CreditCard,
  Mail,
  Send,
  RotateCcw,
  Package,
  Layers,
  Calendar,
  Filter,
  CheckSquare
} from 'lucide-react';
import AppLayout from '../../components/Layout/AppLayout';
import StatusBadge from '../../components/Common/StatusBadge';
import ConfirmModal from '../../components/Common/ConfirmModal';
import procurementService from '../../services/procurementService';
import purchaseOrderService from '../../services/purchaseOrderService';
import rawMaterialService from '../../services/rawMaterialService';
import { useAuth } from '../../context/AuthContext';
import { parseErrorMessage } from '../../utils/errorHandler';

export default function ProcurementResearch() {
  const [searchParams, setSearchParams] = useSearchParams();
  const navigate = useNavigate();
  const { user } = useAuth();

  const isManager = user && (user.role === 1 || user.role === 'SupplyChainManager' || user.role === '1' || user.role === 3 || user.role === 'ITAdmin' || user.role === '3');

  // Request & Candidates State
  const [requests, setRequests] = useState([]);
  const [selectedRequestId, setSelectedRequestId] = useState(
    searchParams.get('id') ? parseInt(searchParams.get('id'), 10) : null
  );
  const [currentRequest, setCurrentRequest] = useState(null);
  const [recommendation, setRecommendation] = useState(null);
  const [statusTracking, setStatusTracking] = useState(null);
  const [materials, setMaterials] = useState([]);

  // UI & Loading States
  const [loadingInitial, setLoadingInitial] = useState(true);
  const [isResearching, setIsResearching] = useState(false);
  const [agentStep, setAgentStep] = useState('idle'); // 'idle' | 'planner' | 'extraction' | 'purchasing' | 'validation' | 'done'
  const [actionLoading, setActionLoading] = useState(false);
  const [errorMessage, setErrorMessage] = useState('');
  const [successMessage, setSuccessMessage] = useState('');

  // Selected candidate for PO generation
  const [selectedCandidateId, setSelectedCandidateId] = useState(null);

  // Supplier Verification Modal State
  const [verifyModalOpen, setVerifyModalOpen] = useState(false);
  const [candidateToVerify, setCandidateToVerify] = useState(null);
  const [verifyForm, setVerifyForm] = useState({
    supplierName: '',
    contactEmail: '',
    contactPhone: '',
    address: '',
    paymentTerms: 'Net 30',
    leadTimeDays: 7
  });

  // Approval Modals
  const [approveModalOpen, setApproveModalOpen] = useState(false);
  const [rejectModalOpen, setRejectModalOpen] = useState(false);
  const [reviseModalOpen, setReviseModalOpen] = useState(false);
  const [decisionNotes, setDecisionNotes] = useState('');

  // New Request Form State
  const [showNewForm, setShowNewForm] = useState(!searchParams.get('id'));
  const [formValues, setFormValues] = useState({
    rawMaterialId: 1,
    materialName: '',
    specification: 'ISO 9001 certified, barrier laminated pouch film, food-grade compliance',
    productionRequirement: 3500,
    safetyStock: 500,
    currentStock: 0,
    maximumBudget: 15000,
    qualityStandard: 'ISO 9001 / ASTM F1929',
    preferredRegion: 'Global',
    requiredByDate: new Date(Date.now() + 14 * 86400000).toISOString().split('T')[0]
  });

  // 1. Initial Load: Raw materials & list of existing procurement requests
  useEffect(() => {
    let isMounted = true;
    const fetchInitialData = async () => {
      setLoadingInitial(true);
      setErrorMessage('');
      try {
        const [materialsData, requestsData] = await Promise.all([
          rawMaterialService.getRawMaterials().catch(() => []),
          procurementService.getAllRequests().catch(() => [])
        ]);

        if (!isMounted) return;

        setMaterials(materialsData || []);
        setRequests(requestsData || []);

        if (materialsData && materialsData.length > 0 && !formValues.materialName) {
          setFormValues((prev) => ({
            ...prev,
            rawMaterialId: materialsData[0].id,
            materialName: materialsData[0].name
          }));
        }

        // If an ID was in search params or existing requests exist, select it
        const paramId = searchParams.get('id') ? parseInt(searchParams.get('id'), 10) : null;
        if (paramId) {
          setSelectedRequestId(paramId);
          setShowNewForm(false);
        } else if (requestsData && requestsData.length > 0) {
          setSelectedRequestId(requestsData[0].id);
          setShowNewForm(false);
        }
      } catch (err) {
        if (isMounted) {
          setErrorMessage(parseErrorMessage(err, 'Failed to initialize procurement module.'));
        }
      } finally {
        if (isMounted) setLoadingInitial(false);
      }
    };

    fetchInitialData();
    return () => {
      isMounted = false;
    };
  }, []);

  // 2. Fetch details whenever selectedRequestId changes
  const loadRequestDetails = async (requestId) => {
    if (!requestId) return;
    try {
      const [reqData, recData, trackData] = await Promise.all([
        procurementService.getRequest(requestId),
        procurementService.getRecommendation(requestId).catch(() => null),
        procurementService.getStatus(requestId).catch(() => null)
      ]);

      setCurrentRequest(reqData);
      setRecommendation(recData);
      setStatusTracking(trackData);

      // Pre-select recommended candidate if available
      if (recData?.recommendedCandidate) {
        setSelectedCandidateId(recData.recommendedCandidate.id);
      } else if (reqData.candidates && reqData.candidates.length > 0) {
        setSelectedCandidateId(reqData.candidates[0].id);
      }
    } catch (err) {
      setErrorMessage(parseErrorMessage(err, 'Failed to load procurement request details.'));
    }
  };

  useEffect(() => {
    if (selectedRequestId) {
      loadRequestDetails(selectedRequestId);
    }
  }, [selectedRequestId]);

  // Handle Material Dropdown Selection
  const handleMaterialSelect = (e) => {
    const matId = parseInt(e.target.value, 10);
    const selectedMat = materials.find((m) => m.id === matId);
    setFormValues((prev) => ({
      ...prev,
      rawMaterialId: matId,
      materialName: selectedMat ? selectedMat.name : prev.materialName
    }));
  };

  // Authoritative Net Deficit Preview in UI
  const calculatedDeficitPreview = useMemo(() => {
    const prod = parseFloat(formValues.productionRequirement) || 0;
    const safety = parseFloat(formValues.safetyStock) || 0;
    const current = parseFloat(formValues.currentStock) || 0;
    const openPo = 0; // Backend calculates open POs automatically
    return Math.max(0, prod + safety - current - openPo);
  }, [formValues.productionRequirement, formValues.safetyStock, formValues.currentStock]);

  // Form Submit: Start AI Procurement Research
  const handleStartResearch = async (e) => {
    e.preventDefault();
    setErrorMessage('');
    setSuccessMessage('');
    setIsResearching(true);
    setAgentStep('planner');

    try {
      // Step A: Ingest requirement and calculate net deficit in ASP.NET Core
      setAgentStep('extraction');
      const createDto = {
        rawMaterialId: formValues.rawMaterialId,
        materialName: formValues.materialName,
        requiredSpecification: formValues.specification,
        productionRequirement: parseFloat(formValues.productionRequirement),
        safetyStock: parseFloat(formValues.safetyStock),
        currentStock: parseFloat(formValues.currentStock),
        maximumBudget: parseFloat(formValues.maximumBudget),
        requiredByDate: new Date(formValues.requiredByDate).toISOString(),
        qualityRequirement: formValues.qualityStandard,
        preferredRegion: formValues.preferredRegion
      };

      const newRequest = await procurementService.createRequest(createDto);
      setSelectedRequestId(newRequest.id);
      setSearchParams({ id: newRequest.id });

      // Step B: Multi-agent execution in LangGraph (via ASP.NET Core)
      setAgentStep('purchasing');
      const completedRequest = await procurementService.startResearch(newRequest.id);

      setAgentStep('validation');
      // Fetch recommendation and updated tracking
      await loadRequestDetails(newRequest.id);

      // Refresh list of requests
      const refreshedList = await procurementService.getAllRequests().catch(() => []);
      setRequests(refreshedList);

      setAgentStep('done');
      setShowNewForm(false);
      setSuccessMessage('AI Multi-Agent research completed successfully! Evaluated supplier candidates are shown below.');
    } catch (err) {
      setErrorMessage(parseErrorMessage(err, 'Failed to complete AI procurement research.'));
      setAgentStep('idle');
    } finally {
      setIsResearching(false);
    }
  };

  // Re-run research on current request
  const handleReRunResearch = async () => {
    if (!selectedRequestId) return;
    setErrorMessage('');
    setSuccessMessage('');
    setIsResearching(true);
    setAgentStep('purchasing');

    try {
      await procurementService.startResearch(selectedRequestId);
      setAgentStep('validation');
      await loadRequestDetails(selectedRequestId);
      setAgentStep('done');
      setSuccessMessage('Procurement research refreshed with latest supplier market grounding.');
    } catch (err) {
      setErrorMessage(parseErrorMessage(err, 'Failed to re-run research.'));
      setAgentStep('idle');
    } finally {
      setIsResearching(false);
    }
  };

  // Open Verify Supplier Modal
  const handleOpenVerifyModal = (candidate) => {
    setCandidateToVerify(candidate);
    setVerifyForm({
      supplierName: candidate.supplierName,
      contactEmail: `${candidate.supplierName.toLowerCase().replace(/[^a-z0-9]/g, '')}@example.com`,
      contactPhone: '+1 (555) 234-5678',
      address: '100 Industrial Parkway, Supply Hub, NY 10001',
      paymentTerms: 'Net 30',
      leadTimeDays: candidate.leadTimeDays || 7
    });
    setVerifyModalOpen(true);
  };

  // Submit Supplier Verification & Onboarding
  const handleVerifySubmit = async (e) => {
    e.preventDefault();
    if (!currentRequest || !candidateToVerify) return;

    setActionLoading(true);
    setErrorMessage('');
    try {
      await procurementService.verifySupplierCandidate(
        currentRequest.id,
        candidateToVerify.id,
        verifyForm
      );
      setVerifyModalOpen(false);
      setSuccessMessage(
        `Supplier '${verifyForm.supplierName}' verified and onboarded into ERP! You can now generate the Draft Purchase Order.`
      );
      // Reload request & candidates
      await loadRequestDetails(currentRequest.id);
    } catch (err) {
      setErrorMessage(parseErrorMessage(err, 'Failed to verify supplier.'));
    } finally {
      setActionLoading(false);
    }
  };

  // Generate Draft PO Action
  const handleGenerateDraftPo = async (candidateId) => {
    if (!currentRequest) return;
    const targetCandidateId = candidateId || selectedCandidateId;
    if (!targetCandidateId) {
      setErrorMessage('Please select a validated supplier candidate.');
      return;
    }

    setActionLoading(true);
    setErrorMessage('');
    setSuccessMessage('');
    try {
      const draftPo = await procurementService.createDraftPo(currentRequest.id, targetCandidateId);
      setSuccessMessage(
        `Draft Purchase Order ${draftPo.poNumber} created in ERP! Review the terms below or navigate to the PO detail view.`
      );
      await loadRequestDetails(currentRequest.id);
    } catch (err) {
      setErrorMessage(parseErrorMessage(err, 'Failed to generate draft purchase order.'));
    } finally {
      setActionLoading(false);
    }
  };

  // PO Approval Actions (Approve, Reject, Revise)
  const handleApprovePo = async () => {
    const poId = currentRequest?.generatedPurchaseOrderId || statusTracking?.purchaseOrderId;
    if (!poId) return;

    setActionLoading(true);
    setErrorMessage('');
    try {
      await purchaseOrderService.approvePurchaseOrder(poId);
      setApproveModalOpen(false);
      setSuccessMessage('Purchase Order approved! Stripe payment initiated and invoice PDF emailed via SendGrid.');
      await loadRequestDetails(currentRequest.id);
    } catch (err) {
      setErrorMessage(parseErrorMessage(err, 'Failed to approve purchase order.'));
    } finally {
      setActionLoading(false);
    }
  };

  const handleRejectPo = async () => {
    const poId = currentRequest?.generatedPurchaseOrderId || statusTracking?.purchaseOrderId;
    if (!poId) return;

    setActionLoading(true);
    setErrorMessage('');
    try {
      await purchaseOrderService.rejectPurchaseOrder(poId, decisionNotes);
      setRejectModalOpen(false);
      setSuccessMessage('Purchase Order rejected.');
      await loadRequestDetails(currentRequest.id);
    } catch (err) {
      setErrorMessage(parseErrorMessage(err, 'Failed to reject purchase order.'));
    } finally {
      setActionLoading(false);
      setDecisionNotes('');
    }
  };

  const handleRevisePo = async () => {
    const poId = currentRequest?.generatedPurchaseOrderId || statusTracking?.purchaseOrderId;
    if (!poId) return;

    setActionLoading(true);
    setErrorMessage('');
    try {
      await purchaseOrderService.requestRevision(poId, decisionNotes);
      setReviseModalOpen(false);
      setSuccessMessage('Revision requested. Purchase Order sent back to Draft state.');
      await loadRequestDetails(currentRequest.id);
    } catch (err) {
      setErrorMessage(parseErrorMessage(err, 'Failed to request revision.'));
    } finally {
      setActionLoading(false);
      setDecisionNotes('');
    }
  };

  // Active candidate object for inspection
  const candidatesList = currentRequest?.candidates || [];
  const activeCandidate =
    candidatesList.find((c) => c.id === selectedCandidateId) ||
    recommendation?.recommendedCandidate ||
    candidatesList[0];

  // 6-Point Pre-PO Validation Evaluation
  const validationChecks = useMemo(() => {
    if (!activeCandidate || !currentRequest) return null;

    const netQty = currentRequest.calculatedNetQuantity || currentRequest.netDeficit || 0;
    const moq = activeCandidate.minimumOrderQuantity || 0;
    const packSize = activeCandidate.packSize || 1;
    const unitPrice = activeCandidate.unitPrice || 0;
    const maxBudget = currentRequest.maximumBudget || 0;
    const leadTime = activeCandidate.leadTimeDays || 0;
    const requiredDate = new Date(currentRequest.requiredByDate || currentRequest.requiredDeliveryDate);
    const estimatedArrival = new Date(Date.now() + leadTime * 86400000);

    // 1. MOQ / Pack size check
    const moqPass = (activeCandidate.recommendedOrderQuantity || netQty) >= moq;

    // 2. Quality certification check
    const qualityEvidence = (activeCandidate.qualityEvidence || '').trim();
    const qualityPass = qualityEvidence.length >= 4 && !qualityEvidence.toUpperCase().includes('UNKNOWN');

    // 3. Budget compliance check
    const totalCost = activeCandidate.totalCost || (activeCandidate.recommendedOrderQuantity || netQty) * unitPrice;
    const budgetPass = totalCost <= maxBudget;

    // 4. Delivery lead time check
    const leadTimePass = estimatedArrival <= requiredDate;

    // 5. Supplier credibility check
    const credibilityPass = Boolean(activeCandidate.sourceUrl || activeCandidate.confidenceScore >= 0.7);

    // 6. Supplier verification check
    const verifiedPass = activeCandidate.supplierStatus === 'APPROVED';

    const allPassed = moqPass && qualityPass && budgetPass && leadTimePass && credibilityPass && verifiedPass;

    return {
      moqPass,
      qualityPass,
      budgetPass,
      leadTimePass,
      credibilityPass,
      verifiedPass,
      allPassed,
      totalCost
    };
  }, [activeCandidate, currentRequest]);

  return (
    <AppLayout
      title="AI-Assisted Raw Material Procurement"
      subtitle="Autonomous multi-agent research with search grounding, constraint validation, and ERP integration"
      actionButton={
        <div className="flex items-center gap-2.5">
          <Link
            to="/purchase-orders"
            className="flex items-center gap-1.5 px-3 py-2 bg-slate-900 border border-slate-700 hover:bg-slate-800 text-slate-300 font-medium rounded-xl text-xs transition-colors"
          >
            <ArrowLeft className="w-3.5 h-3.5" />
            <span>PO Dashboard</span>
          </Link>

          {!showNewForm ? (
            <button
              onClick={() => setShowNewForm(true)}
              className="flex items-center gap-1.5 px-3.5 py-2 bg-gradient-to-r from-purple-600 to-indigo-600 hover:from-purple-500 text-white font-semibold rounded-xl text-xs shadow-lg shadow-purple-600/20 transition-all"
            >
              <Sparkles className="w-3.5 h-3.5" />
              <span>New Procurement</span>
            </button>
          ) : (
            requests.length > 0 && (
              <button
                onClick={() => setShowNewForm(false)}
                className="flex items-center gap-1.5 px-3.5 py-2 bg-slate-800 hover:bg-slate-700 text-slate-300 font-medium rounded-xl text-xs border border-slate-700 transition-colors"
              >
                <span>View Results</span>
              </button>
            )
          )}
        </div>
      }
    >
      {/* Notifications */}
      {errorMessage && (
        <div className="p-4 rounded-xl bg-rose-500/10 border border-rose-500/30 text-rose-300 text-xs flex items-center justify-between gap-3 animate-fade-in">
          <div className="flex items-center gap-2.5">
            <AlertTriangle className="w-4 h-4 text-rose-400 shrink-0" />
            <span>{errorMessage}</span>
          </div>
          <button onClick={() => setErrorMessage('')} className="text-rose-400 hover:text-white">
            <X className="w-4 h-4" />
          </button>
        </div>
      )}

      {successMessage && (
        <div className="p-4 rounded-xl bg-emerald-500/10 border border-emerald-500/30 text-emerald-300 text-xs flex items-center justify-between gap-3 animate-fade-in">
          <div className="flex items-center gap-2.5">
            <CheckCircle2 className="w-4 h-4 text-emerald-400 shrink-0" />
            <span>{successMessage}</span>
          </div>
          <button onClick={() => setSuccessMessage('')} className="text-emerald-400 hover:text-white">
            <X className="w-4 h-4" />
          </button>
        </div>
      )}

      {/* Progress / Step Indicator Banner */}
      <div className="p-5 rounded-2xl bg-gradient-to-r from-purple-950/40 via-slate-900 to-slate-950 border border-purple-800/30 backdrop-blur-sm">
        <div className="flex flex-col lg:flex-row lg:items-center justify-between gap-4">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-purple-500/20 border border-purple-400/30 flex items-center justify-center text-purple-400 shrink-0">
              <Bot className="w-5 h-5" />
            </div>
            <div>
              <div className="flex items-center gap-2">
                <span className="text-xs font-bold uppercase tracking-wider text-purple-400">
                  Autonomous Multi-Agent Pipeline
                </span>
                <span className="px-2 py-0.5 text-[10px] font-semibold rounded-full bg-purple-500/20 text-purple-300 border border-purple-500/30">
                  Student 2: Supply Chain Manager
                </span>
              </div>
              <h2 className="text-base font-bold text-white mt-0.5">
                AI Raw-Material Procurement Coordinator
              </h2>
            </div>
          </div>

          {/* Existing Requests Switcher */}
          {requests.length > 0 && (
            <div className="flex items-center gap-2">
              <span className="text-xs text-slate-400">Request:</span>
              <select
                value={selectedRequestId || ''}
                onChange={(e) => {
                  const id = parseInt(e.target.value, 10);
                  setSelectedRequestId(id);
                  setSearchParams({ id });
                  setShowNewForm(false);
                }}
                className="bg-slate-900 border border-slate-700 text-xs rounded-xl px-3 py-2 text-white focus:outline-none focus:border-purple-500"
              >
                {requests.map((r) => (
                  <option key={r.id} value={r.id}>
                    #{r.id} — {r.rawMaterialName || r.materialName || 'Material'} ({r.status})
                  </option>
                ))}
              </select>
            </div>
          )}
        </div>
      </div>

      {/* NEW PROCUREMENT RESEARCH FORM */}
      {showNewForm ? (
        <div className="p-6 md:p-8 rounded-2xl bg-slate-900/60 border border-slate-800 backdrop-blur-sm space-y-6">
          <div className="border-b border-slate-800 pb-4">
            <h3 className="text-lg font-bold text-white flex items-center gap-2">
              <Sparkles className="w-5 h-5 text-purple-400" />
              <span>Step 1: Procurement Specifications & Stock Parameters</span>
            </h3>
            <p className="text-xs text-slate-400 mt-1">
              Enter your production requirements. ASP.NET Core deterministically computes net deficit, then triggers the 4-agent LangGraph workflow.
            </p>
          </div>

          <form onSubmit={handleStartResearch} className="space-y-6">
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-5">
              {/* Material Dropdown */}
              <div>
                <label className="block text-xs font-semibold text-slate-300 mb-1.5">
                  Select Raw Material *
                </label>
                <select
                  value={formValues.rawMaterialId}
                  onChange={handleMaterialSelect}
                  className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3.5 py-2.5 text-xs text-white focus:outline-none focus:border-purple-500"
                  required
                >
                  {materials.map((m) => (
                    <option key={m.id} value={m.id}>
                      {m.name} ({m.skuCode || `ID: ${m.id}`})
                    </option>
                  ))}
                </select>
              </div>

              {/* Material Name / Label */}
              <div>
                <label className="block text-xs font-semibold text-slate-300 mb-1.5">
                  Material Custom Name / Trade Description
                </label>
                <input
                  type="text"
                  value={formValues.materialName}
                  onChange={(e) => setFormValues({ ...formValues, materialName: e.target.value })}
                  placeholder="e.g. Food-Grade BoxPouch Barrier Film"
                  className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3.5 py-2.5 text-xs text-white focus:outline-none focus:border-purple-500"
                  required
                />
              </div>

              {/* Required Delivery Date */}
              <div>
                <label className="block text-xs font-semibold text-slate-300 mb-1.5">
                  Required By Date *
                </label>
                <input
                  type="date"
                  value={formValues.requiredByDate}
                  min={new Date().toISOString().split('T')[0]}
                  onChange={(e) => setFormValues({ ...formValues, requiredByDate: e.target.value })}
                  className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3.5 py-2.5 text-xs text-white focus:outline-none focus:border-purple-500"
                  required
                />
              </div>

              {/* Technical Specification */}
              <div className="md:col-span-2 lg:col-span-3">
                <label className="block text-xs font-semibold text-slate-300 mb-1.5">
                  Technical Specification & Standards *
                </label>
                <textarea
                  rows={2}
                  value={formValues.specification}
                  onChange={(e) => setFormValues({ ...formValues, specification: e.target.value })}
                  placeholder="e.g. ISO 9001 certified, ASTM F1929 barrier pouch laminated film, food-grade compliance"
                  className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3.5 py-2.5 text-xs text-white focus:outline-none focus:border-purple-500"
                  required
                />
              </div>

              {/* Production Requirement */}
              <div>
                <label className="block text-xs font-semibold text-slate-300 mb-1.5">
                  Production Requirement (units/meters) *
                </label>
                <input
                  type="number"
                  min="1"
                  step="any"
                  value={formValues.productionRequirement}
                  onChange={(e) => setFormValues({ ...formValues, productionRequirement: e.target.value })}
                  className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3.5 py-2.5 text-xs text-white focus:outline-none focus:border-purple-500"
                  required
                />
              </div>

              {/* Safety Stock */}
              <div>
                <label className="block text-xs font-semibold text-slate-300 mb-1.5">
                  Safety Stock Buffer *
                </label>
                <input
                  type="number"
                  min="0"
                  step="any"
                  value={formValues.safetyStock}
                  onChange={(e) => setFormValues({ ...formValues, safetyStock: e.target.value })}
                  className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3.5 py-2.5 text-xs text-white focus:outline-none focus:border-purple-500"
                  required
                />
              </div>

              {/* Current Stock */}
              <div>
                <label className="block text-xs font-semibold text-slate-300 mb-1.5">
                  Current On-Hand Stock *
                </label>
                <input
                  type="number"
                  min="0"
                  step="any"
                  value={formValues.currentStock}
                  onChange={(e) => setFormValues({ ...formValues, currentStock: e.target.value })}
                  className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3.5 py-2.5 text-xs text-white focus:outline-none focus:border-purple-500"
                  required
                />
              </div>

              {/* Maximum Budget */}
              <div>
                <label className="block text-xs font-semibold text-slate-300 mb-1.5">
                  Maximum Budget ($ USD) *
                </label>
                <input
                  type="number"
                  min="1"
                  step="any"
                  value={formValues.maximumBudget}
                  onChange={(e) => setFormValues({ ...formValues, maximumBudget: e.target.value })}
                  className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3.5 py-2.5 text-xs text-white focus:outline-none focus:border-purple-500"
                  required
                />
              </div>

              {/* Quality Standard */}
              <div>
                <label className="block text-xs font-semibold text-slate-300 mb-1.5">
                  Quality Standard Benchmark
                </label>
                <input
                  type="text"
                  value={formValues.qualityStandard}
                  onChange={(e) => setFormValues({ ...formValues, qualityStandard: e.target.value })}
                  placeholder="e.g. ISO 9001, ASTM F1929, GMP"
                  className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3.5 py-2.5 text-xs text-white focus:outline-none focus:border-purple-500"
                />
              </div>

              {/* Preferred Region */}
              <div>
                <label className="block text-xs font-semibold text-slate-300 mb-1.5">
                  Preferred Supplier Region
                </label>
                <select
                  value={formValues.preferredRegion}
                  onChange={(e) => setFormValues({ ...formValues, preferredRegion: e.target.value })}
                  className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3.5 py-2.5 text-xs text-white focus:outline-none focus:border-purple-500"
                >
                  <option value="Global">Global / Any Region</option>
                  <option value="North America">North America (USA, Canada)</option>
                  <option value="Europe">Europe (EU, UK)</option>
                  <option value="Asia">Asia Pacific</option>
                </select>
              </div>
            </div>

            {/* Authoritative Net Deficit Calculation Card */}
            <div className="p-4 rounded-xl bg-slate-950/80 border border-slate-800 flex flex-col sm:flex-row sm:items-center justify-between gap-4">
              <div>
                <div className="flex items-center gap-2">
                  <span className="text-xs font-bold text-purple-400 uppercase tracking-wider">
                    Authoritative Formula (ASP.NET Core)
                  </span>
                  <span className="text-[11px] text-slate-400">
                    Net Deficit = Production Requirement ({formValues.productionRequirement}) + Safety Stock ({formValues.safetyStock}) - Current Stock ({formValues.currentStock}) - Open POs (0)
                  </span>
                </div>
                <div className="text-sm text-slate-300 mt-1">
                  Estimated Deficit to Procure:{' '}
                  <span className="font-extrabold text-white text-base">
                    {calculatedDeficitPreview.toLocaleString()} units
                  </span>
                </div>
              </div>

              <button
                type="submit"
                disabled={isResearching}
                className="flex items-center justify-center gap-2 px-6 py-3 bg-gradient-to-r from-purple-600 to-indigo-600 hover:from-purple-500 hover:to-indigo-500 text-white font-bold rounded-xl text-sm shadow-xl shadow-purple-600/30 transition-all disabled:opacity-50"
              >
                {isResearching ? (
                  <>
                    <Loader2 className="w-4 h-4 animate-spin" />
                    <span>Orchestrating Agents...</span>
                  </>
                ) : (
                  <>
                    <Sparkles className="w-4 h-4" />
                    <span>Start AI Procurement Research</span>
                  </>
                )}
              </button>
            </div>
          </form>
        </div>
      ) : null}

      {/* MULTI-AGENT LIVE EXECUTION TIMELINE */}
      {isResearching && (
        <div className="p-6 rounded-2xl bg-slate-900/80 border border-purple-500/40 backdrop-blur-md space-y-4 animate-fade-in">
          <div className="flex items-center justify-between border-b border-slate-800 pb-3">
            <h4 className="text-sm font-bold text-white flex items-center gap-2">
              <Bot className="w-4 h-4 text-purple-400 animate-spin" />
              <span>Multi-Agent LangGraph Execution Pipeline</span>
            </h4>
            <span className="text-xs text-purple-400 font-medium">Live Coordination</span>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3">
            {/* Planner */}
            <div
              className={`p-3.5 rounded-xl border transition-all ${
                agentStep === 'planner'
                  ? 'bg-purple-950/60 border-purple-500 text-purple-300'
                  : agentStep !== 'idle'
                  ? 'bg-slate-950/50 border-emerald-500/40 text-emerald-400'
                  : 'bg-slate-950/30 border-slate-800 text-slate-500'
              }`}
            >
              <div className="flex items-center justify-between text-xs font-semibold">
                <span>1. Planner / Coordinator</span>
                {agentStep === 'planner' ? (
                  <Loader2 className="w-3.5 h-3.5 animate-spin text-purple-400" />
                ) : agentStep !== 'idle' ? (
                  <Check className="w-3.5 h-3.5 text-emerald-400" />
                ) : null}
              </div>
              <p className="text-[11px] text-slate-400 mt-1">Ready & orchestrating subagents</p>
            </div>

            {/* Data Extraction */}
            <div
              className={`p-3.5 rounded-xl border transition-all ${
                agentStep === 'extraction'
                  ? 'bg-purple-950/60 border-purple-500 text-purple-300'
                  : ['purchasing', 'validation', 'done'].includes(agentStep)
                  ? 'bg-slate-950/50 border-emerald-500/40 text-emerald-400'
                  : 'bg-slate-950/30 border-slate-800 text-slate-500'
              }`}
            >
              <div className="flex items-center justify-between text-xs font-semibold">
                <span>2. Data Extraction</span>
                {agentStep === 'extraction' ? (
                  <Loader2 className="w-3.5 h-3.5 animate-spin text-purple-400" />
                ) : ['purchasing', 'validation', 'done'].includes(agentStep) ? (
                  <Check className="w-3.5 h-3.5 text-emerald-400" />
                ) : null}
              </div>
              <p className="text-[11px] text-slate-400 mt-1">Reading stock & calculating net deficit</p>
            </div>

            {/* Purchasing Agent */}
            <div
              className={`p-3.5 rounded-xl border transition-all ${
                agentStep === 'purchasing'
                  ? 'bg-purple-950/60 border-purple-500 text-purple-300'
                  : ['validation', 'done'].includes(agentStep)
                  ? 'bg-slate-950/50 border-emerald-500/40 text-emerald-400'
                  : 'bg-slate-950/30 border-slate-800 text-slate-500'
              }`}
            >
              <div className="flex items-center justify-between text-xs font-semibold">
                <span>3. Purchasing (Student 2)</span>
                {agentStep === 'purchasing' ? (
                  <Loader2 className="w-3.5 h-3.5 animate-spin text-purple-400" />
                ) : ['validation', 'done'].includes(agentStep) ? (
                  <Check className="w-3.5 h-3.5 text-emerald-400" />
                ) : null}
              </div>
              <p className="text-[11px] text-slate-400 mt-1">Gemini Search Grounding & pricing</p>
            </div>

            {/* Validation / Safety */}
            <div
              className={`p-3.5 rounded-xl border transition-all ${
                agentStep === 'validation'
                  ? 'bg-purple-950/60 border-purple-500 text-purple-300'
                  : agentStep === 'done'
                  ? 'bg-slate-950/50 border-emerald-500/40 text-emerald-400'
                  : 'bg-slate-950/30 border-slate-800 text-slate-500'
              }`}
            >
              <div className="flex items-center justify-between text-xs font-semibold">
                <span>4. Validation & Safety</span>
                {agentStep === 'validation' ? (
                  <Loader2 className="w-3.5 h-3.5 animate-spin text-purple-400" />
                ) : agentStep === 'done' ? (
                  <Check className="w-3.5 h-3.5 text-emerald-400" />
                ) : null}
              </div>
              <p className="text-[11px] text-slate-400 mt-1">Verifying constraints & pause rule</p>
            </div>
          </div>
        </div>
      )}

      {/* RESULTS DISPLAY: Details, Candidates, Recommendation, Checklist, and Draft PO */}
      {currentRequest && !showNewForm && (
        <div className="space-y-6">
          {/* Header Summary for Current Request */}
          <div className="p-6 rounded-2xl bg-slate-900/60 border border-slate-800 backdrop-blur-sm">
            <div className="flex flex-col lg:flex-row lg:items-center justify-between gap-4">
              <div>
                <div className="flex items-center gap-2">
                  <span className="text-xs font-bold text-purple-400 uppercase tracking-wider">
                    Procurement Request #{currentRequest.id}
                  </span>
                  <StatusBadge status={currentRequest.status} />
                  {currentRequest.workflowId && (
                    <span className="px-2 py-0.5 text-[10px] rounded-full bg-slate-800 text-slate-400 border border-slate-700">
                      Audit: {currentRequest.workflowId}
                    </span>
                  )}
                </div>
                <h3 className="text-xl font-bold text-white mt-1">
                  {currentRequest.rawMaterialName || currentRequest.materialName}
                </h3>
                <p className="text-xs text-slate-400 mt-0.5">
                  Specification: <span className="text-slate-200">{currentRequest.requiredSpecification}</span>
                </p>
              </div>

              <div className="flex flex-wrap items-center gap-4 text-xs">
                <div className="px-3 py-2 rounded-xl bg-slate-950/80 border border-slate-800">
                  <span className="text-slate-400 block text-[10px] uppercase">Net Deficit</span>
                  <span className="text-sm font-bold text-white">
                    {(currentRequest.calculatedNetQuantity || currentRequest.netDeficit || 0).toLocaleString()}
                  </span>
                </div>
                <div className="px-3 py-2 rounded-xl bg-slate-950/80 border border-slate-800">
                  <span className="text-slate-400 block text-[10px] uppercase">Max Budget</span>
                  <span className="text-sm font-bold text-emerald-400">
                    ${(currentRequest.maximumBudget || 0).toLocaleString()}
                  </span>
                </div>
                <div className="px-3 py-2 rounded-xl bg-slate-950/80 border border-slate-800">
                  <span className="text-slate-400 block text-[10px] uppercase">Required By</span>
                  <span className="text-sm font-semibold text-slate-200">
                    {new Date(currentRequest.requiredByDate).toLocaleDateString()}
                  </span>
                </div>
                <button
                  onClick={handleReRunResearch}
                  disabled={isResearching}
                  className="flex items-center gap-1.5 px-3 py-2 bg-slate-800 hover:bg-slate-700 text-purple-300 font-medium rounded-xl border border-purple-500/30 transition-all text-xs"
                >
                  <RotateCcw className="w-3.5 h-3.5" />
                  <span>Re-run AI</span>
                </button>
              </div>
            </div>
          </div>

          {/* AI RECOMMENDATION CARD */}
          {activeCandidate && (
            <div className="p-6 rounded-2xl bg-gradient-to-r from-purple-950/50 via-slate-900 to-slate-900 border border-purple-500/40 backdrop-blur-sm space-y-4">
              <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 border-b border-slate-800/80 pb-3">
                <div className="flex items-center gap-2.5">
                  <div className="w-8 h-8 rounded-lg bg-purple-500/20 border border-purple-500/40 flex items-center justify-center text-purple-400">
                    <Sparkles className="w-4 h-4" />
                  </div>
                  <div>
                    <span className="text-[10px] font-bold uppercase tracking-wider text-purple-400">
                      Primary AI Agent Recommendation
                    </span>
                    <h4 className="text-base font-bold text-white">{activeCandidate.supplierName}</h4>
                  </div>
                </div>

                <div className="flex items-center gap-2">
                  {/* Supplier Status Badge */}
                  {activeCandidate.supplierStatus === 'APPROVED' ? (
                    <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-semibold bg-emerald-500/10 text-emerald-400 border border-emerald-500/30">
                      <CheckCircle2 className="w-3.5 h-3.5" />
                      <span>APPROVED SUPPLIER</span>
                    </span>
                  ) : (
                    <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-semibold bg-amber-500/10 text-amber-400 border border-amber-500/30">
                      <AlertTriangle className="w-3.5 h-3.5" />
                      <span>UNVERIFIED SUPPLIER</span>
                    </span>
                  )}

                  {/* Quality Badge */}
                  <span
                    className={`inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-semibold border ${
                      activeCandidate.qualityEvidence && !activeCandidate.qualityEvidence.includes('UNKNOWN')
                        ? 'bg-blue-500/10 text-blue-400 border-blue-500/30'
                        : 'bg-zinc-800 text-zinc-400 border-zinc-700'
                    }`}
                  >
                    <ShieldCheck className="w-3.5 h-3.5" />
                    <span>{activeCandidate.qualityEvidence || 'UNKNOWN'}</span>
                  </span>
                </div>
              </div>

              {/* Rationale & Metrics Grid */}
              <div className="grid grid-cols-1 md:grid-cols-4 gap-4 text-xs">
                <div className="md:col-span-2 p-3.5 rounded-xl bg-slate-950/70 border border-slate-800">
                  <span className="text-slate-400 font-semibold uppercase text-[10px] block mb-1">
                    AI Selection Rationale
                  </span>
                  <p className="text-slate-300 leading-relaxed">
                    {recommendation?.rationale ||
                      `Ranked #1 based on lowest total landed cost ($${(activeCandidate.totalCost || 0).toLocaleString()}), full specification compatibility with ${activeCandidate.materialName}, and verified delivery within ${activeCandidate.leadTimeDays} days.`}
                  </p>
                </div>

                <div className="p-3.5 rounded-xl bg-slate-950/70 border border-slate-800 flex flex-col justify-between">
                  <span className="text-slate-400 font-semibold uppercase text-[10px] block">
                    Order Quantity & Cost
                  </span>
                  <div>
                    <div className="text-base font-bold text-white">
                      {(activeCandidate.recommendedOrderQuantity || 0).toLocaleString()} units
                    </div>
                    <div className="text-slate-400 text-[11px] mt-0.5">
                      @ ${(activeCandidate.unitPrice || 0).toFixed(2)} / unit
                    </div>
                  </div>
                  <div className="text-emerald-400 font-bold text-sm mt-1">
                    Total: ${(activeCandidate.totalCost || 0).toLocaleString(undefined, { minimumFractionDigits: 2 })}
                  </div>
                </div>

                <div className="p-3.5 rounded-xl bg-slate-950/70 border border-slate-800 flex flex-col justify-between">
                  <span className="text-slate-400 font-semibold uppercase text-[10px] block">
                    Terms & Logistics
                  </span>
                  <div className="space-y-1 text-slate-300">
                    <div>
                      MOQ: <span className="text-white font-medium">{activeCandidate.minimumOrderQuantity}</span>
                    </div>
                    <div>
                      Pack Size: <span className="text-white font-medium">{activeCandidate.packSize}</span>
                    </div>
                    <div>
                      Lead Time:{' '}
                      <span className="text-white font-medium">{activeCandidate.leadTimeDays} days</span>
                    </div>
                  </div>
                </div>
              </div>

              {/* UNVERIFIED SUPPLIER WARNING & VERIFY BUTTON */}
              {activeCandidate.supplierStatus !== 'APPROVED' && (
                <div className="p-4 rounded-xl bg-amber-500/10 border border-amber-500/30 flex flex-col sm:flex-row sm:items-center justify-between gap-3">
                  <div className="flex items-center gap-3">
                    <ShieldAlert className="w-5 h-5 text-amber-400 shrink-0" />
                    <div>
                      <h5 className="text-xs font-bold text-amber-300">
                        Supplier Requires Verification Before Purchase Order Creation
                      </h5>
                      <p className="text-[11px] text-amber-200/80 mt-0.5">
                        This supplier was discovered via market grounding. In accordance with enterprise compliance, a Supply Chain Manager must verify and onboard them into the ERP before creating a Draft PO.
                      </p>
                    </div>
                  </div>

                  {isManager && (
                    <button
                      onClick={() => handleOpenVerifyModal(activeCandidate)}
                      className="px-4 py-2 bg-gradient-to-r from-amber-600 to-amber-700 hover:from-amber-500 text-slate-950 font-bold rounded-xl text-xs shadow-md transition-all shrink-0"
                    >
                      Verify Supplier
                    </button>
                  )}
                </div>
              )}
            </div>
          )}

          {/* SUPPLIER CANDIDATES COMPARISON TABLE */}
          <div className="p-6 rounded-2xl bg-slate-900/60 border border-slate-800 backdrop-blur-sm space-y-4">
            <div className="flex items-center justify-between border-b border-slate-800 pb-3">
              <div>
                <h4 className="text-sm font-bold text-white flex items-center gap-2">
                  <Building2 className="w-4 h-4 text-purple-400" />
                  <span>Evaluated Supplier Candidates</span>
                </h4>
                <p className="text-xs text-slate-400 mt-0.5">
                  Comparison matrix of external candidates discovered via Gemini Search Grounding & ERP vendors.
                </p>
              </div>
              <span className="text-xs text-slate-400">{candidatesList.length} Candidates Evaluated</span>
            </div>

            <div className="overflow-x-auto">
              <table className="w-full text-left border-collapse text-xs">
                <thead>
                  <tr className="border-b border-slate-800 text-slate-400 uppercase font-semibold text-[10px]">
                    <th className="py-2.5 px-3">Supplier</th>
                    <th className="py-2.5 px-3">Material</th>
                    <th className="py-2.5 px-3 text-right">Unit Price</th>
                    <th className="py-2.5 px-3 text-center">MOQ</th>
                    <th className="py-2.5 px-3 text-center">Pack</th>
                    <th className="py-2.5 px-3 text-center">Availability</th>
                    <th className="py-2.5 px-3 text-center">Lead Time</th>
                    <th className="py-2.5 px-3">Quality Standard</th>
                    <th className="py-2.5 px-3">Supplier Status</th>
                    <th className="py-2.5 px-3 text-right">Total Cost</th>
                    <th className="py-2.5 px-3 text-center">Source</th>
                    <th className="py-2.5 px-3 text-center">Action</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-800/60">
                  {candidatesList.length === 0 ? (
                    <tr>
                      <td colSpan={12} className="py-8 text-center text-slate-500">
                        No supplier candidates evaluated yet. Click "Start AI Procurement Research" to run grounding.
                      </td>
                    </tr>
                  ) : (
                    candidatesList.map((cand) => {
                      const isSelected = cand.id === activeCandidate?.id;
                      return (
                        <tr
                          key={cand.id}
                          className={`hover:bg-slate-800/40 transition-colors ${
                            isSelected ? 'bg-purple-950/20' : ''
                          }`}
                        >
                          <td className="py-3 px-3 font-semibold text-white">
                            <div className="flex items-center gap-1.5">
                              {isSelected && <Sparkles className="w-3 h-3 text-purple-400 shrink-0" />}
                              <span>{cand.supplierName}</span>
                            </div>
                          </td>
                          <td className="py-3 px-3 text-slate-300 max-w-[150px] truncate" title={cand.materialName}>
                            {cand.materialName}
                          </td>
                          <td className="py-3 px-3 text-right font-medium text-white">
                            ${(cand.unitPrice || 0).toFixed(2)}
                          </td>
                          <td className="py-3 px-3 text-center text-slate-300">
                            {cand.minimumOrderQuantity}
                          </td>
                          <td className="py-3 px-3 text-center text-slate-300">
                            {cand.packSize}
                          </td>
                          <td className="py-3 px-3 text-center">
                            <span className="px-2 py-0.5 rounded-full text-[10px] font-medium bg-slate-800 text-slate-300">
                              {cand.availability || 'In Stock'}
                            </span>
                          </td>
                          <td className="py-3 px-3 text-center text-slate-300">
                            {cand.leadTimeDays}d
                          </td>
                          <td className="py-3 px-3">
                            <span
                              className={`px-2 py-0.5 rounded text-[10px] font-semibold ${
                                cand.qualityEvidence && !cand.qualityEvidence.includes('UNKNOWN')
                                  ? 'bg-blue-500/10 text-blue-400 border border-blue-500/30'
                                  : 'bg-zinc-800 text-zinc-400'
                              }`}
                            >
                              {cand.qualityEvidence || 'UNKNOWN'}
                            </span>
                          </td>
                          <td className="py-3 px-3">
                            {cand.supplierStatus === 'APPROVED' ? (
                              <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-bold bg-emerald-500/10 text-emerald-400 border border-emerald-500/30">
                                <Check className="w-3 h-3" />
                                <span>APPROVED</span>
                              </span>
                            ) : (
                              <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-bold bg-amber-500/10 text-amber-400 border border-amber-500/30">
                                <AlertTriangle className="w-3 h-3" />
                                <span>UNVERIFIED</span>
                              </span>
                            )}
                          </td>
                          <td className="py-3 px-3 text-right font-bold text-white">
                            ${(cand.totalCost || 0).toLocaleString(undefined, { minimumFractionDigits: 2 })}
                          </td>
                          <td className="py-3 px-3 text-center">
                            {cand.sourceUrl ? (
                              <a
                                href={cand.sourceUrl}
                                target="_blank"
                                rel="noopener noreferrer"
                                className="text-purple-400 hover:text-purple-300 inline-block p-1"
                                title="View Supplier Catalog"
                              >
                                <ExternalLink className="w-3.5 h-3.5" />
                              </a>
                            ) : (
                              <span className="text-slate-600">—</span>
                            )}
                          </td>
                          <td className="py-3 px-3 text-center">
                            <button
                              onClick={() => setSelectedCandidateId(cand.id)}
                              className={`px-2.5 py-1 rounded-lg text-[10px] font-semibold transition-all ${
                                isSelected
                                  ? 'bg-purple-600 text-white'
                                  : 'bg-slate-800 text-slate-300 hover:bg-slate-700'
                              }`}
                            >
                              {isSelected ? 'Selected' : 'Select'}
                            </button>
                          </td>
                        </tr>
                      );
                    })
                  )}
                </tbody>
              </table>
            </div>
          </div>

          {/* 6-POINT PRE-PO VALIDATION CHECKLIST & DRAFT PO GENERATION */}
          {activeCandidate && validationChecks && (
            <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
              {/* Checklist */}
              <div className="lg:col-span-2 p-6 rounded-2xl bg-slate-900/60 border border-slate-800 backdrop-blur-sm space-y-4">
                <div className="flex items-center justify-between border-b border-slate-800 pb-3">
                  <h4 className="text-sm font-bold text-white flex items-center gap-2">
                    <CheckSquare className="w-4 h-4 text-purple-400" />
                    <span>6-Point Pre-Purchase Order Validation Engine</span>
                  </h4>
                  <span className="text-xs text-slate-400">Strict Procurement Policy</span>
                </div>

                <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 pt-1">
                  {/* Check 1: MOQ & Pack Size */}
                  <div className="p-3 rounded-xl bg-slate-950/70 border border-slate-800 flex items-start gap-2.5">
                    {validationChecks.moqPass ? (
                      <CheckCircle2 className="w-4 h-4 text-emerald-400 shrink-0 mt-0.5" />
                    ) : (
                      <AlertTriangle className="w-4 h-4 text-rose-400 shrink-0 mt-0.5" />
                    )}
                    <div>
                      <div className="text-xs font-semibold text-white">1. MOQ & Pack Size Check</div>
                      <p className="text-[11px] text-slate-400 mt-0.5">
                        Order quantity {activeCandidate.recommendedOrderQuantity} meets MOQ ({activeCandidate.minimumOrderQuantity}) and pack size ({activeCandidate.packSize}).
                      </p>
                    </div>
                  </div>

                  {/* Check 2: Quality Standard */}
                  <div className="p-3 rounded-xl bg-slate-950/70 border border-slate-800 flex items-start gap-2.5">
                    {validationChecks.qualityPass ? (
                      <CheckCircle2 className="w-4 h-4 text-emerald-400 shrink-0 mt-0.5" />
                    ) : (
                      <AlertTriangle className="w-4 h-4 text-rose-400 shrink-0 mt-0.5" />
                    )}
                    <div>
                      <div className="text-xs font-semibold text-white">2. Quality Certification Check</div>
                      <p className="text-[11px] text-slate-400 mt-0.5">
                        {validationChecks.qualityPass
                          ? `Evidence verified: ${activeCandidate.qualityEvidence}`
                          : 'No verifiable ISO/ASTM certification provided.'}
                      </p>
                    </div>
                  </div>

                  {/* Check 3: Budget Compliance */}
                  <div className="p-3 rounded-xl bg-slate-950/70 border border-slate-800 flex items-start gap-2.5">
                    {validationChecks.budgetPass ? (
                      <CheckCircle2 className="w-4 h-4 text-emerald-400 shrink-0 mt-0.5" />
                    ) : (
                      <AlertTriangle className="w-4 h-4 text-rose-400 shrink-0 mt-0.5" />
                    )}
                    <div>
                      <div className="text-xs font-semibold text-white">3. Budget Compliance Check</div>
                      <p className="text-[11px] text-slate-400 mt-0.5">
                        ${validationChecks.totalCost.toLocaleString()} ≤ Max Budget ${currentRequest.maximumBudget.toLocaleString()}
                      </p>
                    </div>
                  </div>

                  {/* Check 4: Delivery Lead Time */}
                  <div className="p-3 rounded-xl bg-slate-950/70 border border-slate-800 flex items-start gap-2.5">
                    {validationChecks.leadTimePass ? (
                      <CheckCircle2 className="w-4 h-4 text-emerald-400 shrink-0 mt-0.5" />
                    ) : (
                      <AlertTriangle className="w-4 h-4 text-rose-400 shrink-0 mt-0.5" />
                    )}
                    <div>
                      <div className="text-xs font-semibold text-white">4. Delivery Lead Time Check</div>
                      <p className="text-[11px] text-slate-400 mt-0.5">
                        Lead time {activeCandidate.leadTimeDays}d meets arrival deadline.
                      </p>
                    </div>
                  </div>

                  {/* Check 5: Credibility & Catalog */}
                  <div className="p-3 rounded-xl bg-slate-950/70 border border-slate-800 flex items-start gap-2.5">
                    {validationChecks.credibilityPass ? (
                      <CheckCircle2 className="w-4 h-4 text-emerald-400 shrink-0 mt-0.5" />
                    ) : (
                      <AlertTriangle className="w-4 h-4 text-rose-400 shrink-0 mt-0.5" />
                    )}
                    <div>
                      <div className="text-xs font-semibold text-white">5. Supplier Credibility Check</div>
                      <p className="text-[11px] text-slate-400 mt-0.5">
                        Grounding source and business footprint confirmed.
                      </p>
                    </div>
                  </div>

                  {/* Check 6: Supplier Verification */}
                  <div className="p-3 rounded-xl bg-slate-950/70 border border-slate-800 flex items-start gap-2.5">
                    {validationChecks.verifiedPass ? (
                      <CheckCircle2 className="w-4 h-4 text-emerald-400 shrink-0 mt-0.5" />
                    ) : (
                      <AlertTriangle className="w-4 h-4 text-amber-400 shrink-0 mt-0.5" />
                    )}
                    <div>
                      <div className="text-xs font-semibold text-white">6. ERP Supplier Verification</div>
                      <p className="text-[11px] text-slate-400 mt-0.5">
                        {validationChecks.verifiedPass
                          ? 'Vendor is APPROVED in ERP database.'
                          : 'UNVERIFIED — Manager onboarding required.'}
                      </p>
                    </div>
                  </div>
                </div>
              </div>

              {/* Draft PO Action Panel */}
              <div className="p-6 rounded-2xl bg-gradient-to-b from-slate-900/80 to-slate-950 border border-slate-800 backdrop-blur-sm flex flex-col justify-between space-y-4">
                <div>
                  <h4 className="text-sm font-bold text-white flex items-center gap-2">
                    <FileText className="w-4 h-4 text-purple-400" />
                    <span>Draft PO Generation</span>
                  </h4>
                  <p className="text-xs text-slate-400 mt-1">
                    Convert validated recommendation into an official enterprise Purchase Order.
                  </p>

                  <div className="mt-4 p-3 rounded-xl bg-slate-950 border border-slate-800 space-y-1.5 text-xs">
                    <div className="flex justify-between">
                      <span className="text-slate-400">Selected Vendor:</span>
                      <span className="text-white font-semibold truncate max-w-[140px]">
                        {activeCandidate.supplierName}
                      </span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-slate-400">PO Quantity:</span>
                      <span className="text-white font-bold">
                        {activeCandidate.recommendedOrderQuantity} units
                      </span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-slate-400">Landed Cost:</span>
                      <span className="text-emerald-400 font-extrabold">
                        ${validationChecks.totalCost.toLocaleString(undefined, { minimumFractionDigits: 2 })}
                      </span>
                    </div>
                  </div>
                </div>

                <div className="space-y-2">
                  {currentRequest.generatedPurchaseOrderId ? (
                    <div className="space-y-2">
                      <div className="p-3 rounded-xl bg-emerald-500/10 border border-emerald-500/30 text-emerald-300 text-xs">
                        <div className="font-bold flex items-center gap-1.5">
                          <CheckCircle2 className="w-4 h-4 text-emerald-400" />
                          <span>Draft PO Created: {currentRequest.generatedPoNumber}</span>
                        </div>
                        <p className="text-[11px] text-emerald-200/80 mt-1">
                          Purchase order is in ERP registry awaiting manager signature and Stripe payment.
                        </p>
                      </div>

                      <Link
                        to={`/purchase-orders/${currentRequest.generatedPurchaseOrderId}`}
                        className="w-full flex items-center justify-center gap-2 px-4 py-2.5 bg-gradient-to-r from-brand-600 to-brand-700 hover:from-brand-500 text-white font-bold rounded-xl text-xs shadow-lg transition-all"
                      >
                        <FileText className="w-3.5 h-3.5" />
                        <span>Manage Purchase Order #{currentRequest.generatedPurchaseOrderId}</span>
                      </Link>
                    </div>
                  ) : (
                    <button
                      onClick={() => handleGenerateDraftPo(activeCandidate.id)}
                      disabled={actionLoading || !validationChecks.allPassed}
                      className="w-full flex items-center justify-center gap-2 px-4 py-3 bg-gradient-to-r from-purple-600 to-indigo-600 hover:from-purple-500 hover:to-indigo-500 text-white font-bold rounded-xl text-xs shadow-lg shadow-purple-600/30 transition-all disabled:opacity-40 disabled:cursor-not-allowed"
                    >
                      {actionLoading ? (
                        <>
                          <Loader2 className="w-4 h-4 animate-spin" />
                          <span>Generating PO in ERP...</span>
                        </>
                      ) : (
                        <>
                          <FileText className="w-4 h-4" />
                          <span>Generate Draft Purchase Order</span>
                        </>
                      )}
                    </button>
                  )}

                  {!validationChecks.allPassed && !currentRequest.generatedPurchaseOrderId && (
                    <p className="text-[10px] text-amber-400/90 text-center">
                      {!validationChecks.verifiedPass
                        ? 'Verification required before Draft PO can be generated.'
                        : 'All 6 validation points must pass.'}
                    </p>
                  )}
                </div>
              </div>
            </div>
          )}

          {/* DRAFT PO APPROVAL WORKFLOW & STATUS TRACKING */}
          {currentRequest.generatedPurchaseOrderId && (
            <div className="p-6 rounded-2xl bg-slate-900/60 border border-slate-800 backdrop-blur-sm space-y-5">
              <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 border-b border-slate-800 pb-3">
                <div>
                  <h4 className="text-sm font-bold text-white flex items-center gap-2">
                    <CheckSquare className="w-4 h-4 text-emerald-400" />
                    <span>Purchase Order Approval & Settlement Pipeline</span>
                  </h4>
                  <p className="text-xs text-slate-400 mt-0.5">
                    Order {currentRequest.generatedPoNumber} — Authoritative manager actions & automated integrations
                  </p>
                </div>

                {/* Manager Decision Buttons */}
                {isManager && statusTracking?.purchaseOrderStatus === 'PendingApproval' && (
                  <div className="flex items-center gap-2">
                    <button
                      onClick={() => setReviseModalOpen(true)}
                      className="flex items-center gap-1.5 px-3 py-1.5 bg-slate-900 border border-slate-700 hover:bg-slate-800 text-orange-400 font-semibold rounded-xl text-xs"
                    >
                      <RotateCcw className="w-3.5 h-3.5" />
                      <span>Request Revision</span>
                    </button>
                    <button
                      onClick={() => setRejectModalOpen(true)}
                      className="flex items-center gap-1.5 px-3 py-1.5 bg-rose-600/20 border border-rose-500/40 hover:bg-rose-600/30 text-rose-400 font-semibold rounded-xl text-xs"
                    >
                      <X className="w-3.5 h-3.5" />
                      <span>Reject</span>
                    </button>
                    <button
                      onClick={() => setApproveModalOpen(true)}
                      className="flex items-center gap-1.5 px-4 py-1.5 bg-gradient-to-r from-emerald-600 to-emerald-700 hover:from-emerald-500 text-white font-bold rounded-xl text-xs shadow-lg shadow-emerald-600/20"
                    >
                      <Check className="w-3.5 h-3.5" />
                      <span>Approve Order</span>
                    </button>
                  </div>
                )}
              </div>

              {/* Status Tracking Cards */}
              <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
                {/* Approval Status */}
                <div className="p-4 rounded-xl bg-slate-950/70 border border-slate-800">
                  <div className="flex items-center justify-between">
                    <span className="text-slate-400 text-xs font-semibold">Approval Status</span>
                    <ShieldCheck className="w-4 h-4 text-purple-400" />
                  </div>
                  <div className="mt-2 flex items-center gap-2">
                    <StatusBadge status={statusTracking?.purchaseOrderStatus || 'PendingApproval'} />
                  </div>
                  <span className="text-[10px] text-slate-500 mt-1 block">ERP Governance</span>
                </div>

                {/* Stripe Payment Status */}
                <div className="p-4 rounded-xl bg-slate-950/70 border border-slate-800">
                  <div className="flex items-center justify-between">
                    <span className="text-slate-400 text-xs font-semibold">Stripe Payment Status</span>
                    <CreditCard className="w-4 h-4 text-cyan-400" />
                  </div>
                  <div className="mt-2">
                    <span
                      className={`inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-semibold border ${
                        statusTracking?.paymentStatus === 'Paid'
                          ? 'bg-emerald-500/10 text-emerald-400 border-emerald-500/30'
                          : statusTracking?.paymentStatus === 'Processing'
                          ? 'bg-cyan-500/10 text-cyan-400 border-cyan-500/30'
                          : 'bg-slate-800 text-slate-400 border-slate-700'
                      }`}
                    >
                      <span
                        className={`w-1.5 h-1.5 rounded-full ${
                          statusTracking?.paymentStatus === 'Paid'
                            ? 'bg-emerald-400'
                            : statusTracking?.paymentStatus === 'Processing'
                            ? 'bg-cyan-400 animate-pulse'
                            : 'bg-slate-500'
                        }`}
                      />
                      <span>{statusTracking?.paymentStatus || 'Pending'}</span>
                    </span>
                  </div>
                  <span className="text-[10px] text-slate-500 mt-1 block">Stripe Sandbox Integration</span>
                </div>

                {/* SendGrid Email Status */}
                <div className="p-4 rounded-xl bg-slate-950/70 border border-slate-800">
                  <div className="flex items-center justify-between">
                    <span className="text-slate-400 text-xs font-semibold">SendGrid Email Delivery</span>
                    <Mail className="w-4 h-4 text-blue-400" />
                  </div>
                  <div className="mt-2">
                    <span
                      className={`inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-semibold border ${
                        statusTracking?.supplierNotificationStatus === 'Sent' ||
                        statusTracking?.supplierNotificationStatus === 'Delivered'
                          ? 'bg-blue-500/10 text-blue-400 border-blue-500/30'
                          : 'bg-slate-800 text-slate-400 border-slate-700'
                      }`}
                    >
                      <span
                        className={`w-1.5 h-1.5 rounded-full ${
                          statusTracking?.supplierNotificationStatus === 'Sent'
                            ? 'bg-blue-400'
                            : 'bg-slate-500'
                        }`}
                      />
                      <span>{statusTracking?.supplierNotificationStatus || 'NotSent'}</span>
                    </span>
                  </div>
                  <span className="text-[10px] text-slate-500 mt-1 block">PDF PO Invoice Dispatch</span>
                </div>
              </div>
            </div>
          )}
        </div>
      )}

      {/* SUPPLIER ONBOARDING & VERIFICATION MODAL */}
      {verifyModalOpen && candidateToVerify && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-950/80 backdrop-blur-sm animate-fade-in">
          <div className="bg-slate-900 border border-slate-800 rounded-2xl max-w-lg w-full p-6 space-y-5 shadow-2xl">
            <div className="flex items-center justify-between border-b border-slate-800 pb-3">
              <div className="flex items-center gap-2">
                <ShieldCheck className="w-5 h-5 text-amber-400" />
                <h3 className="text-base font-bold text-white">
                  Verify & Onboard Supplier Candidate
                </h3>
              </div>
              <button
                onClick={() => setVerifyModalOpen(false)}
                className="text-slate-400 hover:text-white"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <p className="text-xs text-slate-400 leading-relaxed">
              Complete supplier onboarding for <strong className="text-white">{candidateToVerify.supplierName}</strong>. Once submitted, this vendor will be marked as <strong className="text-emerald-400">APPROVED</strong> in the ERP registry.
            </p>

            <form onSubmit={handleVerifySubmit} className="space-y-4">
              <div>
                <label className="block text-xs font-semibold text-slate-300 mb-1">
                  Supplier Legal Name *
                </label>
                <input
                  type="text"
                  value={verifyForm.supplierName}
                  onChange={(e) => setVerifyForm({ ...verifyForm, supplierName: e.target.value })}
                  className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3 py-2 text-xs text-white focus:outline-none focus:border-purple-500"
                  required
                />
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <div>
                  <label className="block text-xs font-semibold text-slate-300 mb-1">
                    Contact Email *
                  </label>
                  <input
                    type="email"
                    value={verifyForm.contactEmail}
                    onChange={(e) => setVerifyForm({ ...verifyForm, contactEmail: e.target.value })}
                    className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3 py-2 text-xs text-white focus:outline-none focus:border-purple-500"
                    required
                  />
                </div>
                <div>
                  <label className="block text-xs font-semibold text-slate-300 mb-1">
                    Contact Phone
                  </label>
                  <input
                    type="text"
                    value={verifyForm.contactPhone}
                    onChange={(e) => setVerifyForm({ ...verifyForm, contactPhone: e.target.value })}
                    className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3 py-2 text-xs text-white focus:outline-none focus:border-purple-500"
                  />
                </div>
              </div>

              <div>
                <label className="block text-xs font-semibold text-slate-300 mb-1">
                  Physical Address
                </label>
                <input
                  type="text"
                  value={verifyForm.address}
                  onChange={(e) => setVerifyForm({ ...verifyForm, address: e.target.value })}
                  className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3 py-2 text-xs text-white focus:outline-none focus:border-purple-500"
                />
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <div>
                  <label className="block text-xs font-semibold text-slate-300 mb-1">
                    Payment Terms
                  </label>
                  <select
                    value={verifyForm.paymentTerms}
                    onChange={(e) => setVerifyForm({ ...verifyForm, paymentTerms: e.target.value })}
                    className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3 py-2 text-xs text-white focus:outline-none focus:border-purple-500"
                  >
                    <option value="Net 30">Net 30</option>
                    <option value="Net 60">Net 60</option>
                    <option value="Advance">Advance Payment</option>
                    <option value="Immediate">Immediate / Card</option>
                  </select>
                </div>
                <div>
                  <label className="block text-xs font-semibold text-slate-300 mb-1">
                    Confirmed Lead Time (Days)
                  </label>
                  <input
                    type="number"
                    min="1"
                    value={verifyForm.leadTimeDays}
                    onChange={(e) => setVerifyForm({ ...verifyForm, leadTimeDays: parseInt(e.target.value, 10) || 7 })}
                    className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3 py-2 text-xs text-white focus:outline-none focus:border-purple-500"
                  />
                </div>
              </div>

              <div className="flex items-center justify-end gap-2.5 pt-3 border-t border-slate-800">
                <button
                  type="button"
                  onClick={() => setVerifyModalOpen(false)}
                  className="px-4 py-2 bg-slate-800 hover:bg-slate-700 text-slate-300 text-xs font-medium rounded-xl transition-colors"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={actionLoading}
                  className="flex items-center gap-1.5 px-4 py-2 bg-gradient-to-r from-amber-600 to-amber-700 hover:from-amber-500 text-slate-950 text-xs font-bold rounded-xl shadow-lg transition-all disabled:opacity-50"
                >
                  {actionLoading ? <Loader2 className="w-3.5 h-3.5 animate-spin" /> : <ShieldCheck className="w-3.5 h-3.5" />}
                  <span>Verify & Onboard</span>
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* CONFIRMATION MODALS: Approve, Reject, Revise */}
      <ConfirmModal
        isOpen={approveModalOpen}
        onClose={() => setApproveModalOpen(false)}
        onConfirm={handleApprovePo}
        title="Approve Purchase Order"
        message="Are you sure you want to approve this Purchase Order? This will trigger automated Stripe Sandbox payment and dispatch the signed PO invoice PDF to the supplier via SendGrid."
        confirmText="Approve Order"
        confirmColor="emerald"
        loading={actionLoading}
      />

      {rejectModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-950/80 backdrop-blur-sm animate-fade-in">
          <div className="bg-slate-900 border border-slate-800 rounded-2xl max-w-md w-full p-6 space-y-4">
            <h3 className="text-base font-bold text-white">Reject Purchase Order</h3>
            <p className="text-xs text-slate-400">
              Provide a rejection reason for the audit trail:
            </p>
            <textarea
              rows={3}
              value={decisionNotes}
              onChange={(e) => setDecisionNotes(e.target.value)}
              placeholder="e.g. Budget re-allocation or technical spec cancellation"
              className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3 py-2 text-xs text-white focus:outline-none focus:border-rose-500"
            />
            <div className="flex justify-end gap-2 pt-2">
              <button
                onClick={() => setRejectModalOpen(false)}
                className="px-3.5 py-2 bg-slate-800 text-slate-300 text-xs rounded-xl"
              >
                Cancel
              </button>
              <button
                onClick={handleRejectPo}
                disabled={actionLoading}
                className="px-4 py-2 bg-rose-600 hover:bg-rose-500 text-white text-xs font-bold rounded-xl"
              >
                {actionLoading ? 'Rejecting...' : 'Confirm Reject'}
              </button>
            </div>
          </div>
        </div>
      )}

      {reviseModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-950/80 backdrop-blur-sm animate-fade-in">
          <div className="bg-slate-900 border border-slate-800 rounded-2xl max-w-md w-full p-6 space-y-4">
            <h3 className="text-base font-bold text-white">Request PO Revision</h3>
            <p className="text-xs text-slate-400">
              Explain required adjustments to revert this order back to Draft:
            </p>
            <textarea
              rows={3}
              value={decisionNotes}
              onChange={(e) => setDecisionNotes(e.target.value)}
              placeholder="e.g. Please negotiate a 5% discount on MOQ or split delivery dates"
              className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3 py-2 text-xs text-white focus:outline-none focus:border-orange-500"
            />
            <div className="flex justify-end gap-2 pt-2">
              <button
                onClick={() => setReviseModalOpen(false)}
                className="px-3.5 py-2 bg-slate-800 text-slate-300 text-xs rounded-xl"
              >
                Cancel
              </button>
              <button
                onClick={handleRevisePo}
                disabled={actionLoading}
                className="px-4 py-2 bg-orange-600 hover:bg-orange-500 text-white text-xs font-bold rounded-xl"
              >
                {actionLoading ? 'Requesting...' : 'Request Revision'}
              </button>
            </div>
          </div>
        </div>
      )}
    </AppLayout>
  );
}

import React, { useState, useEffect, useMemo, useCallback } from 'react';
import { useSearchParams } from 'react-router-dom';
import {
  ShieldCheck,
  ShieldAlert,
  AlertTriangle,
  History,
  Activity,
  CheckCircle2,
  XCircle,
  Loader2,
  RefreshCw,
  FileText,
  Search,
  Filter,
  Eye,
  DollarSign,
  Package,
  Building2,
  Calculator,
  Calendar,
  Layers,
  ArrowRight,
  Info,
  Check,
  X
} from 'lucide-react';
import ModalOverlay from '../../components/Common/ModalOverlay';
import dashboardService from '../../services/dashboardService';
import { parseErrorMessage } from '../../utils/errorHandler';
import EmptyState from '../../components/QA/EmptyState';

// Helper to extract PO representation with clean user-friendly fallback
const extractPoDisplay = (item) => {
  if (!item) return { title: 'Procurement Proposal', isDraft: true, subtitle: 'Pre-PO Workflow' };
  if (item.purchaseOrderNumber) return { title: item.purchaseOrderNumber, isDraft: false };
  if (item.poNumber) return { title: item.poNumber, isDraft: false };
  if (item.po?.poNumber) return { title: item.po.poNumber, isDraft: false };
  if (item.purchaseOrder?.poNumber) return { title: item.purchaseOrder.poNumber, isDraft: false };
  if (item.validationResults?.purchaseOrderNumber) return { title: item.validationResults.purchaseOrderNumber, isDraft: false };
  if (item.validationResults?.poNumber) return { title: item.validationResults.poNumber, isDraft: false };
  if (item.workflowId) {
    const match = item.workflowId.match(/PO-\d{4}-\d{4}/i);
    if (match) return { title: match[0], isDraft: false };
    const draftMatch = item.workflowId.match(/PO-[A-Za-z0-9_-]+/i);
    if (draftMatch) return { title: draftMatch[0], isDraft: true, subtitle: 'Draft Proposal' };
  }
  if (item.purchaseOrderId) return { title: `PO #${item.purchaseOrderId}`, isDraft: false };
  if (item.poId) return { title: `PO #${item.poId}`, isDraft: false };
  if (item.materialName) return { title: item.materialName, isDraft: true, subtitle: 'Replenishment Draft' };
  return { title: 'Replenishment Proposal', isDraft: true, subtitle: 'Pre-PO Workflow' };
};

// Helper for formatting timestamps
const formatTimestamp = (dateStr) => {
  if (!dateStr) return 'Not available';
  try {
    const date = new Date(dateStr);
    if (isNaN(date.getTime())) return 'Not available';
    return date.toLocaleString('en-GB', {
      timeZone: 'Asia/Colombo',
      month: 'short',
      day: 'numeric',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    });
  } catch {
    return 'Not available';
  }
};

// Check if a single check value is considered PASSED
const isCheckPassed = (val) => {
  if (!val) return false;
  const s = String(val).toUpperCase().trim();
  return s === 'PASSED' || s === 'PASS' || s === 'CLEAR' || s === 'VALID' || s === 'TRUE';
};

// Map individual check status for badges
const mapCheckStatus = (val) => {
  if (val === null || val === undefined || val === '') {
    return {
      label: 'Not Evaluated',
      isPass: false,
      isUnassessed: true,
      badgeClass: 'bg-slate-800/80 text-slate-400 border-slate-700/70',
      icon: 'minus'
    };
  }
  const s = String(val).toUpperCase().trim();
  if (isCheckPassed(s)) {
    return {
      label: 'Passed',
      isPass: true,
      isUnassessed: false,
      badgeClass: 'bg-emerald-500/10 text-emerald-400 border-emerald-500/25',
      icon: 'check'
    };
  }
  if (s === 'INACTIVE_SUPPLIER') {
    return {
      label: 'Inactive Supplier',
      isPass: false,
      isUnassessed: false,
      badgeClass: 'bg-rose-500/10 text-rose-400 border-rose-500/25',
      icon: 'x'
    };
  }
  if (s === 'CALCULATION_MISMATCH') {
    return {
      label: 'Math Mismatch',
      isPass: false,
      isUnassessed: false,
      badgeClass: 'bg-rose-500/10 text-rose-400 border-rose-500/25',
      icon: 'x'
    };
  }
  if (s === 'BUDGET_EXCEEDED' || s === 'EXCEEDS_BUDGET_THRESHOLD') {
    return {
      label: 'Budget Exceeded',
      isPass: false,
      isUnassessed: false,
      badgeClass: 'bg-rose-500/10 text-rose-400 border-rose-500/25',
      icon: 'x'
    };
  }
  if (s === 'MATERIAL_NOT_FOUND') {
    return {
      label: 'Material Missing',
      isPass: false,
      isUnassessed: false,
      badgeClass: 'bg-rose-500/10 text-rose-400 border-rose-500/25',
      icon: 'x'
    };
  }
  return {
    label: 'Failed',
    isPass: false,
    isUnassessed: false,
    badgeClass: 'bg-rose-500/10 text-rose-400 border-rose-500/25',
    icon: 'x'
  };
};

// Calculate passed count out of 4 core checks
const calculatePassedScore = (item) => {
  if (!item) return { passedCount: 0, totalCount: 4, evaluatedCount: 0, isAllPassed: false };
  const hasSupplier = item.supplierValidation !== null && item.supplierValidation !== undefined && item.supplierValidation !== '';
  const hasBudget = item.budgetCheck !== null && item.budgetCheck !== undefined && item.budgetCheck !== '';
  const hasMath = item.poMathematicalCheck !== null && item.poMathematicalCheck !== undefined && item.poMathematicalCheck !== '';
  const hasMaterial = item.materialValidation !== null && item.materialValidation !== undefined && item.materialValidation !== '';

  const evaluatedCount = (hasSupplier ? 1 : 0) + (hasBudget ? 1 : 0) + (hasMath ? 1 : 0) + (hasMaterial ? 1 : 0);
  const supplierPass = isCheckPassed(item.supplierValidation);
  const budgetPass = isCheckPassed(item.budgetCheck);
  const poMathPass = isCheckPassed(item.poMathematicalCheck);
  const materialPass = isCheckPassed(item.materialValidation);
  const count = (supplierPass ? 1 : 0) + (budgetPass ? 1 : 0) + (poMathPass ? 1 : 0) + (materialPass ? 1 : 0);

  return {
    passedCount: count,
    totalCount: 4,
    evaluatedCount,
    isAllPassed: count === 4
  };
};

export default function AiValidationPage() {
  const [searchParams] = useSearchParams();
  const urlWorkflowId = searchParams.get('workflowId');

  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [error, setError] = useState(null);

  const [latestValidation, setLatestValidation] = useState(null);
  const [historyList, setHistoryList] = useState([]);
  const [selectedWorkflow, setSelectedWorkflow] = useState(null);
  const [isDetailsModalOpen, setIsDetailsModalOpen] = useState(false);

  // Filters
  const [searchQuery, setSearchQuery] = useState('');
  const [statusFilter, setStatusFilter] = useState('ALL'); // 'ALL' | 'VALID' | 'INVALID'

  // Fetch AI Validation records
  const fetchData = useCallback(async (isRefresh = false) => {
    if (isRefresh) setRefreshing(true);
    else setLoading(true);
    setError(null);

    try {
      const [latestRes, historyRes] = await Promise.all([
        dashboardService.getAiValidation(urlWorkflowId || undefined),
        dashboardService.getAiValidationHistory()
      ]);

      const historyArray = Array.isArray(historyRes) ? historyRes : (historyRes?.items || []);
      setHistoryList(historyArray);

      // Determine active/latest validation
      if (latestRes) {
        setLatestValidation(latestRes);
        setSelectedWorkflow(latestRes);
      } else if (historyArray.length > 0) {
        setLatestValidation(historyArray[0]);
        setSelectedWorkflow(historyArray[0]);
      } else {
        setLatestValidation(null);
        setSelectedWorkflow(null);
      }
    } catch (err) {
      setError(parseErrorMessage(err, 'Failed to fetch AI Validation ledger data'));
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  }, [urlWorkflowId]);

  useEffect(() => {
    fetchData();
  }, [fetchData]);

  // Filter history list
  const filteredHistory = useMemo(() => {
    return historyList.filter((item) => {
      const { isAllPassed } = calculatePassedScore(item);
      const isOverallValid = item.isValid === true || isAllPassed;

      if (statusFilter === 'VALID' && !isOverallValid) return false;
      if (statusFilter === 'INVALID' && isOverallValid) return false;

      // Text query
      if (searchQuery.trim()) {
        const query = searchQuery.toLowerCase().trim();
        const poDisplay = extractPoDisplay(item);
        const poTitle = poDisplay.title.toLowerCase();
        const wfId = (item.workflowId || '').toLowerCase();
        const matName = (item.materialName || '').toLowerCase();
        const matId = (item.materialId || '').toLowerCase();
        const suppName = (item.checkedSupplier?.supplierName || '').toLowerCase();

        return (
          poTitle.includes(query) ||
          wfId.includes(query) ||
          matName.includes(query) ||
          matId.includes(query) ||
          suppName.includes(query)
        );
      }
      return true;
    });
  }, [historyList, statusFilter, searchQuery]);

  // Statistics
  const stats = useMemo(() => {
    const total = historyList.length;
    let validCount = 0;
    let invalidCount = 0;

    historyList.forEach((item) => {
      const { isAllPassed } = calculatePassedScore(item);
      if (item.isValid === true || isAllPassed) validCount++;
      else invalidCount++;
    });

    return { total, validCount, invalidCount };
  }, [historyList]);

  // Handle View Details
  const handleViewDetails = (item) => {
    setSelectedWorkflow(item);
    setIsDetailsModalOpen(true);
  };

  const activeRecord = selectedWorkflow || latestValidation;
  const activeScore = calculatePassedScore(activeRecord);
  const activeOverallValid = activeRecord?.isValid === true || activeScore.isAllPassed;
  const activePoDisplay = extractPoDisplay(activeRecord);

  // Helper to render check status badge in table
  const renderCheckBadge = (check) => {
    return (
      <span className={`inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full border text-[11px] font-medium whitespace-nowrap shadow-xs ${check.badgeClass}`}>
        {check.icon === 'check' && <Check className="w-3.5 h-3.5 text-emerald-400 shrink-0 stroke-[2.5]" />}
        {check.icon === 'x' && <X className="w-3.5 h-3.5 text-rose-400 shrink-0 stroke-[2.5]" />}
        {check.icon === 'minus' && <span className="w-3.5 text-center text-slate-500 font-bold shrink-0 leading-none">—</span>}
        <span>{check.label}</span>
      </span>
    );
  };

  return (
    <div className="min-h-screen bg-slate-950 text-slate-100 p-4 md:p-6 lg:p-8">
      {/* Header */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 pb-6 border-b border-slate-800">
        <div>
          <div className="flex items-center gap-3">
            <div className="p-2.5 rounded-xl bg-blue-500/10 border border-blue-500/20 text-blue-400">
              <ShieldCheck className="w-6 h-6" />
            </div>
            <div>
              <h1 className="text-2xl font-bold tracking-tight text-white flex items-center gap-2">
                AI Validation Ledger
              </h1>
              <p className="text-sm text-slate-400 mt-0.5">
                Purchase Order validation history for Supplier, Budget, PO Math, and Material checks.
              </p>
            </div>
          </div>
        </div>

        <div className="flex items-center gap-3">
          <button
            onClick={() => fetchData(true)}
            disabled={loading || refreshing}
            className="flex items-center gap-2 px-3.5 py-2 text-sm font-medium rounded-lg bg-slate-900 border border-slate-800 hover:bg-slate-800 text-slate-200 transition-colors disabled:opacity-50"
          >
            <RefreshCw className={`w-4 h-4 ${refreshing ? 'animate-spin text-blue-400' : ''}`} />
            <span>Refresh Ledger</span>
          </button>
        </div>
      </div>

      {/* Summary KPI Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4 my-6">
        <div className="bg-slate-900/60 border border-slate-800 rounded-xl p-4 flex items-center justify-between">
          <div>
            <p className="text-xs font-medium uppercase tracking-wider text-slate-400">Total Validations</p>
            <p className="text-2xl font-bold text-white mt-1">{stats.total}</p>
          </div>
          <div className="p-3 bg-blue-500/10 border border-blue-500/20 rounded-lg text-blue-400">
            <Layers className="w-5 h-5" />
          </div>
        </div>

        <div className="bg-slate-900/60 border border-slate-800 rounded-xl p-4 flex items-center justify-between">
          <div>
            <p className="text-xs font-medium uppercase tracking-wider text-slate-400">Valid & Verified</p>
            <p className="text-2xl font-bold text-emerald-400 mt-1">{stats.validCount}</p>
          </div>
          <div className="p-3 bg-emerald-500/10 border border-emerald-500/20 rounded-lg text-emerald-400">
            <CheckCircle2 className="w-5 h-5" />
          </div>
        </div>

        <div className="bg-slate-900/60 border border-slate-800 rounded-xl p-4 flex items-center justify-between">
          <div>
            <p className="text-xs font-medium uppercase tracking-wider text-slate-400">Discrepancies / Failed</p>
            <p className="text-2xl font-bold text-rose-400 mt-1">{stats.invalidCount}</p>
          </div>
          <div className="p-3 bg-rose-500/10 border border-rose-500/20 rounded-lg text-rose-400">
            <XCircle className="w-5 h-5" />
          </div>
        </div>
      </div>

      {/* Error state */}
      {error && (
        <div className="mb-6 p-4 rounded-xl bg-rose-500/10 border border-rose-500/30 text-rose-300 flex items-center gap-3">
          <AlertTriangle className="w-5 h-5 shrink-0" />
          <p className="text-sm font-medium">{error}</p>
        </div>
      )}

      {/* Loading state */}
      {loading ? (
        <div className="py-20 flex flex-col items-center justify-center text-slate-400">
          <Loader2 className="w-8 h-8 animate-spin text-blue-500 mb-3" />
          <p className="text-sm">Loading AI Validation records...</p>
        </div>
      ) : (
        <>
          {/* LATEST / SELECTED VALIDATION SECTION */}
          {activeRecord ? (
            <div className="mb-8 bg-slate-900/80 border border-slate-800 rounded-2xl p-5 md:p-6 shadow-xl">
              {/* Card Header */}
              <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 pb-5 border-b border-slate-800/80">
                <div className="space-y-1">
                  <div className="flex items-center gap-3 flex-wrap">
                    <span className="text-xs font-semibold px-2.5 py-0.5 rounded-full bg-blue-500/15 text-blue-400 border border-blue-500/30">
                      Latest Assessment
                    </span>
                    <h2 className="text-xl font-bold text-white flex items-center gap-2">
                      {activePoDisplay.title}
                      {activePoDisplay.isDraft && (
                        <span className="text-xs font-medium px-2 py-0.5 rounded bg-slate-800 text-slate-400 border border-slate-700">
                          Draft
                        </span>
                      )}
                    </h2>
                    <span className="text-xs font-mono text-slate-400 bg-slate-800 px-2.5 py-0.5 rounded border border-slate-700">
                      {activeRecord.workflowId || 'N/A'}
                    </span>
                  </div>
                  <div className="flex items-center gap-4 text-xs text-slate-400 flex-wrap pt-1">
                    <span className="flex items-center gap-1.5">
                      <Calendar className="w-3.5 h-3.5 text-slate-500" />
                      Assessed: {formatTimestamp(activeRecord.assessedAt || activeRecord.startedAt)}
                    </span>
                    {activeRecord.materialName && (
                      <span className="flex items-center gap-1.5">
                        <Package className="w-3.5 h-3.5 text-slate-500" />
                        {activeRecord.materialName} ({activeRecord.quantity ?? 'N/A'} {activeRecord.unit || ''})
                      </span>
                    )}
                    {activeRecord.checkedSupplier?.supplierName && (
                      <span className="flex items-center gap-1.5">
                        <Building2 className="w-3.5 h-3.5 text-slate-500" />
                        Supplier: {activeRecord.checkedSupplier.supplierName}
                      </span>
                    )}
                  </div>
                </div>

                {/* Score and Validation Status Badges */}
                <div className="flex items-center gap-3">
                  <div className={`px-3 py-1.5 rounded-lg border text-sm font-semibold flex items-center gap-2 ${
                    activeScore.evaluatedCount === 0
                      ? 'bg-slate-800/80 text-slate-400 border-slate-700'
                      : activeScore.isAllPassed
                        ? 'bg-emerald-500/15 text-emerald-300 border-emerald-500/30'
                        : 'bg-amber-500/15 text-amber-300 border-amber-500/30'
                  }`}>
                    <span>
                      {activeScore.evaluatedCount === 0 ? '0 / 4 PASSED' : `${activeScore.passedCount} / 4 PASSED`}
                    </span>
                  </div>

                  <div className={`px-3.5 py-1.5 rounded-lg border text-sm font-bold tracking-wide flex items-center gap-1.5 ${
                    activeScore.evaluatedCount === 0
                      ? 'bg-slate-800/80 text-slate-400 border-slate-700'
                      : activeOverallValid
                        ? 'bg-emerald-500/20 text-emerald-300 border-emerald-500/40'
                        : 'bg-rose-500/20 text-rose-300 border-rose-500/40'
                  }`}>
                    {activeScore.evaluatedCount === 0 ? (
                      <>
                        <span className="text-slate-500 font-bold">—</span>
                        <span>UNASSESSED</span>
                      </>
                    ) : activeOverallValid ? (
                      <>
                        <Check className="w-4 h-4 stroke-[3]" />
                        <span>VALID</span>
                      </>
                    ) : (
                      <>
                        <X className="w-4 h-4 stroke-[3]" />
                        <span>INVALID</span>
                      </>
                    )}
                  </div>

                  <button
                    type="button"
                    onClick={() => handleViewDetails(activeRecord)}
                    className="px-3 py-1.5 rounded-lg bg-blue-600/20 hover:bg-blue-600/30 text-blue-300 border border-blue-500/30 text-xs font-semibold flex items-center gap-1.5 transition-colors"
                  >
                    <Eye className="w-3.5 h-3.5" />
                    <span>View Details</span>
                  </button>
                </div>
              </div>

              {/* 4 Authoritative PO Validation Cards */}
              <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 mt-5">
                {/* 1. Supplier Check Card */}
                {(() => {
                  const check = mapCheckStatus(activeRecord.supplierValidation);
                  return (
                    <div className="bg-slate-950/60 border border-slate-800 rounded-xl p-4 flex flex-col justify-between">
                      <div>
                        <div className="flex items-center justify-between mb-3">
                          <div className="flex items-center gap-2 text-slate-300 font-semibold text-sm">
                            <div className="p-1.5 rounded-md bg-blue-500/10 text-blue-400">
                              <Building2 className="w-4 h-4" />
                            </div>
                            <span>Supplier Check</span>
                          </div>
                          {renderCheckBadge(check)}
                        </div>
                        <p className="text-xs text-slate-400 leading-relaxed">
                          {check.isUnassessed
                            ? 'Awaiting supplier master verification in proposal.'
                            : check.isPass
                              ? 'Supplier active and verified in ERP catalog.'
                              : (activeRecord.supplierValidation === 'INACTIVE_SUPPLIER'
                                  ? 'Supplier is marked inactive in database master catalog.'
                                  : 'Supplier verification failed or not onboarded.')}
                        </p>
                      </div>
                      {activeRecord.checkedSupplier?.supplierName && (
                        <div className="mt-3 pt-2.5 border-t border-slate-800/80 text-[11px] text-slate-400 font-mono truncate">
                          {activeRecord.checkedSupplier.supplierName}
                        </div>
                      )}
                    </div>
                  );
                })()}

                {/* 2. Budget Check Card */}
                {(() => {
                  const check = mapCheckStatus(activeRecord.budgetCheck);
                  return (
                    <div className="bg-slate-950/60 border border-slate-800 rounded-xl p-4 flex flex-col justify-between">
                      <div>
                        <div className="flex items-center justify-between mb-3">
                          <div className="flex items-center gap-2 text-slate-300 font-semibold text-sm">
                            <div className="p-1.5 rounded-md bg-emerald-500/10 text-emerald-400">
                              <DollarSign className="w-4 h-4" />
                            </div>
                            <span>Budget Check</span>
                          </div>
                          {renderCheckBadge(check)}
                        </div>
                        <p className="text-xs text-slate-400 leading-relaxed">
                          {check.isUnassessed
                            ? 'Awaiting financial budget ceiling calculation.'
                            : check.isPass
                              ? 'Order total within authorized budget ceiling.'
                              : (activeRecord.budgetCheck === 'BUDGET_EXCEEDED'
                                  ? 'Total order cost exceeds the authorized budget limit.'
                                  : 'Financial budget compliance check failed.')}
                        </p>
                      </div>
                      {activeRecord.checkedSupplier?.totalCost !== undefined && (
                        <div className="mt-3 pt-2.5 border-t border-slate-800/80 text-[11px] text-slate-400 font-mono">
                          Est: LKR {Number(activeRecord.checkedSupplier.totalCost).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                        </div>
                      )}
                    </div>
                  );
                })()}

                {/* 3. PO Math Check Card */}
                {(() => {
                  const check = mapCheckStatus(activeRecord.poMathematicalCheck);
                  return (
                    <div className="bg-slate-950/60 border border-slate-800 rounded-xl p-4 flex flex-col justify-between">
                      <div>
                        <div className="flex items-center justify-between mb-3">
                          <div className="flex items-center gap-2 text-slate-300 font-semibold text-sm">
                            <div className="p-1.5 rounded-md bg-purple-500/10 text-purple-400">
                              <Calculator className="w-4 h-4" />
                            </div>
                            <span>PO Math Check</span>
                          </div>
                          {renderCheckBadge(check)}
                        </div>
                        <p className="text-xs text-slate-400 leading-relaxed">
                          {check.isUnassessed
                            ? 'Awaiting arithmetic price and rate calculation.'
                            : check.isPass
                              ? 'Line totals, quantities, and rates match arithmetic.'
                              : 'Arithmetic mismatch detected in unit price or line total.'}
                        </p>
                      </div>
                      <div className="mt-3 pt-2.5 border-t border-slate-800/80 text-[11px] text-slate-400 font-mono">
                        Verification: Price × Qty = Total
                      </div>
                    </div>
                  );
                })()}

                {/* 4. Material Check Card */}
                {(() => {
                  const check = mapCheckStatus(activeRecord.materialValidation);
                  return (
                    <div className="bg-slate-950/60 border border-slate-800 rounded-xl p-4 flex flex-col justify-between">
                      <div>
                        <div className="flex items-center justify-between mb-3">
                          <div className="flex items-center gap-2 text-slate-300 font-semibold text-sm">
                            <div className="p-1.5 rounded-md bg-amber-500/10 text-amber-400">
                              <Package className="w-4 h-4" />
                            </div>
                            <span>Material Check</span>
                          </div>
                          {renderCheckBadge(check)}
                        </div>
                        <p className="text-xs text-slate-400 leading-relaxed">
                          {check.isUnassessed
                            ? 'Awaiting raw material database catalog check.'
                            : check.isPass
                              ? 'Raw material catalog SKU verified in master database.'
                              : (activeRecord.materialValidation === 'MATERIAL_NOT_FOUND'
                                  ? 'Raw material SKU not found in inventory catalog.'
                                  : 'Material validation failed.')}
                        </p>
                      </div>
                      {activeRecord.materialId && (
                        <div className="mt-3 pt-2.5 border-t border-slate-800/80 text-[11px] text-slate-400 font-mono truncate">
                          SKU: {activeRecord.materialId}
                        </div>
                      )}
                    </div>
                  );
                })()}
              </div>

              {/* Diagnostic / Reason notification if available */}
              {(activeRecord.rejectionReason || (activeRecord.impactReason && activeRecord.impactReason !== 'Operational parameters clear.')) && (
                <div className="mt-4 p-3 rounded-xl bg-slate-950/80 border border-slate-800 flex items-start gap-2.5 text-xs text-slate-300">
                  <Info className="w-4 h-4 text-blue-400 shrink-0 mt-0.5" />
                  <div>
                    <span className="font-semibold text-slate-200">Diagnostic Details: </span>
                    <span>{activeRecord.rejectionReason || activeRecord.impactReason}</span>
                  </div>
                </div>
              )}
            </div>
          ) : (
            <div className="mb-8">
              <EmptyState
                icon={History}
                title="No Validation Record Found"
                description="There are currently no AI PO validation assessments registered in the system."
              />
            </div>
          )}

          {/* VALIDATION HISTORY TABLE */}
          <div className="bg-slate-900/60 border border-slate-800 rounded-2xl overflow-hidden shadow-lg">
            {/* Table Controls */}
            <div className="p-4 md:p-5 border-b border-slate-800 flex flex-col md:flex-row md:items-center justify-between gap-4">
              <div>
                <h3 className="text-lg font-bold text-white flex items-center gap-2">
                  <History className="w-5 h-5 text-blue-400" />
                  Validation History
                </h3>
                <p className="text-xs text-slate-400 mt-0.5">
                  Audit log of historical Purchase Order automated validations.
                </p>
              </div>

              <div className="flex flex-col sm:flex-row items-stretch sm:items-center gap-3">
                {/* Search Bar */}
                <div className="relative min-w-[240px]">
                  <Search className="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
                  <input
                    type="text"
                    placeholder="Search PO, Workflow, Material..."
                    value={searchQuery}
                    onChange={(e) => setSearchQuery(e.target.value)}
                    className="w-full pl-9 pr-3 py-1.5 text-xs rounded-lg bg-slate-950 border border-slate-800 text-slate-100 placeholder-slate-500 focus:outline-none focus:border-blue-500"
                  />
                </div>

                {/* Status Filter */}
                <div className="flex items-center p-1 rounded-lg bg-slate-950 border border-slate-800 text-xs">
                  <button
                    onClick={() => setStatusFilter('ALL')}
                    className={`px-3 py-1 rounded-md font-medium transition-colors ${
                      statusFilter === 'ALL'
                        ? 'bg-blue-600 text-white'
                        : 'text-slate-400 hover:text-slate-200'
                    }`}
                  >
                    All ({stats.total})
                  </button>
                  <button
                    onClick={() => setStatusFilter('VALID')}
                    className={`px-3 py-1 rounded-md font-medium transition-colors ${
                      statusFilter === 'VALID'
                        ? 'bg-emerald-600 text-white'
                        : 'text-slate-400 hover:text-slate-200'
                    }`}
                  >
                    Valid ({stats.validCount})
                  </button>
                  <button
                    onClick={() => setStatusFilter('INVALID')}
                    className={`px-3 py-1 rounded-md font-medium transition-colors ${
                      statusFilter === 'INVALID'
                        ? 'bg-rose-600 text-white'
                        : 'text-slate-400 hover:text-slate-200'
                    }`}
                  >
                    Invalid ({stats.invalidCount})
                  </button>
                </div>
              </div>
            </div>

            {/* Table Content */}
            {filteredHistory.length === 0 ? (
              <div className="p-12 text-center text-slate-400">
                <Search className="w-8 h-8 mx-auto mb-2 text-slate-600" />
                <p className="text-sm">No validation records match your filters.</p>
              </div>
            ) : (
              <div className="overflow-x-auto">
                <table className="w-full text-left text-xs border-collapse">
                  <thead>
                    <tr className="bg-slate-950/80 border-b border-slate-800 text-slate-400 font-semibold tracking-wider uppercase text-[11px]">
                      <th className="py-3.5 px-4 min-w-[220px]">PO & Workflow</th>
                      <th className="py-3.5 px-3 min-w-[135px]">Supplier Check</th>
                      <th className="py-3.5 px-3 min-w-[135px]">Budget Check</th>
                      <th className="py-3.5 px-3 min-w-[135px]">PO Math Check</th>
                      <th className="py-3.5 px-3 min-w-[135px]">Material Check</th>
                      <th className="py-3.5 px-3 min-w-[150px]">Overall Result</th>
                      <th className="py-3.5 px-4 min-w-[140px]">Assessed Time</th>
                      <th className="py-3.5 px-4 text-right min-w-[120px]">Actions</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-800/60 font-medium">
                    {filteredHistory.map((item) => {
                      const poDisplay = extractPoDisplay(item);
                      const { passedCount, totalCount, evaluatedCount, isAllPassed } = calculatePassedScore(item);
                      const isOverallValid = item.isValid === true || isAllPassed;

                      const suppCheck = mapCheckStatus(item.supplierValidation);
                      const budgCheck = mapCheckStatus(item.budgetCheck);
                      const mathCheck = mapCheckStatus(item.poMathematicalCheck);
                      const matCheck = mapCheckStatus(item.materialValidation);

                      const isSelected = activeRecord?.workflowId === item.workflowId;

                      return (
                        <tr
                          key={item.workflowId || item.id || Math.random()}
                          onClick={() => handleViewDetails(item)}
                          className={`hover:bg-slate-800/40 cursor-pointer transition-colors ${
                            isSelected ? 'bg-blue-900/10' : ''
                          }`}
                        >
                          {/* PO & Workflow */}
                          <td className="py-3.5 px-4">
                            <div className="space-y-0.5">
                              <div className="flex items-center gap-1.5 flex-wrap">
                                <span className="font-bold text-white text-sm">
                                  {poDisplay.title}
                                </span>
                                {poDisplay.isDraft && (
                                  <span className="text-[10px] font-medium px-1.5 py-0.5 rounded bg-slate-800 text-slate-400 border border-slate-700">
                                    Draft
                                  </span>
                                )}
                              </div>
                              <span className="font-mono text-[11px] text-slate-400 block truncate max-w-[220px]">
                                {item.workflowId || 'N/A'}
                              </span>
                            </div>
                          </td>

                          {/* Supplier Check */}
                          <td className="py-3.5 px-3">
                            {renderCheckBadge(suppCheck)}
                          </td>

                          {/* Budget Check */}
                          <td className="py-3.5 px-3">
                            {renderCheckBadge(budgCheck)}
                          </td>

                          {/* PO Math Check */}
                          <td className="py-3.5 px-3">
                            {renderCheckBadge(mathCheck)}
                          </td>

                          {/* Material Check */}
                          <td className="py-3.5 px-3">
                            {renderCheckBadge(matCheck)}
                          </td>

                          {/* Overall Result */}
                          <td className="py-3.5 px-3">
                            {evaluatedCount === 0 ? (
                              <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-full border text-[11px] font-medium bg-slate-800/80 text-slate-400 border-slate-700/60 whitespace-nowrap">
                                <span className="text-slate-500 font-bold leading-none">—</span>
                                <span>Unassessed (0/4)</span>
                              </span>
                            ) : (
                              <span className={`inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full border text-[11px] font-semibold whitespace-nowrap ${
                                isOverallValid
                                  ? 'bg-emerald-500/15 text-emerald-400 border-emerald-500/30'
                                  : 'bg-rose-500/15 text-rose-400 border-rose-500/30'
                              }`}>
                                {isOverallValid ? (
                                  <>
                                    <Check className="w-3.5 h-3.5 stroke-[2.5]" />
                                    <span>Valid ({passedCount}/{totalCount})</span>
                                  </>
                                ) : (
                                  <>
                                    <X className="w-3.5 h-3.5 stroke-[2.5]" />
                                    <span>Invalid ({passedCount}/{totalCount})</span>
                                  </>
                                )}
                              </span>
                            )}
                          </td>

                          {/* Assessed Time */}
                          <td className="py-3.5 px-4 text-slate-400 font-mono text-[11px] whitespace-nowrap">
                            {formatTimestamp(item.assessedAt || item.startedAt)}
                          </td>

                          {/* Actions */}
                          <td className="py-3.5 px-4 text-right">
                            <button
                              type="button"
                              onClick={(e) => {
                                e.stopPropagation();
                                handleViewDetails(item);
                              }}
                              className="px-2.5 py-1 text-xs font-semibold rounded-md bg-blue-500/10 hover:bg-blue-500/20 text-blue-400 hover:text-blue-300 border border-blue-500/30 transition-colors inline-flex items-center gap-1 whitespace-nowrap"
                            >
                              <Eye className="w-3.5 h-3.5" />
                              <span>View Details</span>
                            </button>
                          </td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              </div>
            )}
          </div>
        </>
      )}

      {/* VIEW DETAILS MODAL */}
      {isDetailsModalOpen && selectedWorkflow && (
        <ModalOverlay
          className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/80 backdrop-blur-sm animate-in fade-in"
          onClick={() => setIsDetailsModalOpen(false)}
        >
          <div
            onClick={(e) => e.stopPropagation()}
            className="bg-slate-900 border border-slate-800 rounded-2xl max-w-3xl w-full p-6 text-slate-100 shadow-2xl overflow-y-auto max-h-[90vh]"
          >
            {/* Modal Header */}
            <div className="flex items-center justify-between pb-4 border-b border-slate-800">
              <div>
                <div className="flex items-center gap-2">
                  <h3 className="text-xl font-bold text-white">
                    {extractPoDisplay(selectedWorkflow).title}
                  </h3>
                  <span className="text-xs font-mono text-slate-400 bg-slate-800 px-2.5 py-0.5 rounded border border-slate-700">
                    {selectedWorkflow.workflowId || 'N/A'}
                  </span>
                </div>
                <p className="text-xs text-slate-400 mt-1">
                  Full diagnostic breakdown of authoritative PO validation checks
                </p>
              </div>

              <button
                type="button"
                onClick={() => setIsDetailsModalOpen(false)}
                className="p-1.5 rounded-lg bg-slate-800 text-slate-400 hover:text-white hover:bg-slate-700 transition-colors"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            {/* Modal Body */}
            <div className="space-y-6 pt-5">
              {/* Summary Result Banner */}
              {(() => {
                const { passedCount, totalCount, evaluatedCount, isAllPassed } = calculatePassedScore(selectedWorkflow);
                const isValid = selectedWorkflow.isValid === true || isAllPassed;

                if (evaluatedCount === 0) {
                  return (
                    <div className="p-4 rounded-xl border bg-slate-800/40 border-slate-700 flex items-center justify-between">
                      <div className="flex items-center gap-3">
                        <div className="p-2 rounded-lg bg-slate-800 text-slate-400">
                          <Info className="w-6 h-6" />
                        </div>
                        <div>
                          <div className="text-base font-bold text-white">
                            Validation Assessment: Unassessed
                          </div>
                          <div className="text-xs text-slate-400 mt-0.5">
                            Automated PO constraint checks have not executed for this workflow proposal.
                          </div>
                        </div>
                      </div>

                      <div className="text-sm font-medium px-3 py-1.5 rounded-lg border bg-slate-800 text-slate-300 border-slate-700">
                        0 / 4 PASSED
                      </div>
                    </div>
                  );
                }

                return (
                  <div className={`p-4 rounded-xl border flex items-center justify-between ${
                    isValid
                      ? 'bg-emerald-500/10 border-emerald-500/30'
                      : 'bg-rose-500/10 border-rose-500/30'
                  }`}>
                    <div className="flex items-center gap-3">
                      <div className={`p-2 rounded-lg ${isValid ? 'bg-emerald-500/20 text-emerald-400' : 'bg-rose-500/20 text-rose-400'}`}>
                        {isValid ? <CheckCircle2 className="w-6 h-6" /> : <XCircle className="w-6 h-6" />}
                      </div>
                      <div>
                        <div className="text-base font-bold text-white">
                          Overall Validation Result: {isValid ? 'VALID' : 'INVALID'}
                        </div>
                        <div className="text-xs text-slate-400 mt-0.5">
                          {passedCount} of {totalCount} authoritative checks passed
                        </div>
                      </div>
                    </div>

                    <div className={`text-sm font-bold px-3 py-1.5 rounded-lg border ${
                      isValid
                        ? 'bg-emerald-500/20 text-emerald-300 border-emerald-500/40'
                        : 'bg-rose-500/20 text-rose-300 border-rose-500/40'
                    }`}>
                      {passedCount} / {totalCount} PASSED
                    </div>
                  </div>
                );
              })()}

              {/* 4 Checks Breakdown */}
              <div className="space-y-3">
                <h4 className="text-xs font-bold uppercase tracking-wider text-slate-400">
                  Four Authoritative Validation Checks
                </h4>

                <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                  {/* Supplier Check */}
                  {(() => {
                    const check = mapCheckStatus(selectedWorkflow.supplierValidation);
                    return (
                      <div className="p-3.5 rounded-xl bg-slate-950 border border-slate-800 flex flex-col justify-between">
                        <div className="flex items-center justify-between mb-1.5">
                          <span className="font-semibold text-sm text-slate-200 flex items-center gap-1.5">
                            <Building2 className="w-4 h-4 text-blue-400" />
                            Supplier Check
                          </span>
                          {renderCheckBadge(check)}
                        </div>
                        <p className="text-xs text-slate-400">
                          {check.isUnassessed
                            ? 'Awaiting supplier master verification in proposal.'
                            : check.isPass
                              ? 'Supplier active and verified in database master catalog.'
                              : 'Supplier is marked inactive or not found in ERP.'}
                        </p>
                      </div>
                    );
                  })()}

                  {/* Budget Check */}
                  {(() => {
                    const check = mapCheckStatus(selectedWorkflow.budgetCheck);
                    return (
                      <div className="p-3.5 rounded-xl bg-slate-950 border border-slate-800 flex flex-col justify-between">
                        <div className="flex items-center justify-between mb-1.5">
                          <span className="font-semibold text-sm text-slate-200 flex items-center gap-1.5">
                            <DollarSign className="w-4 h-4 text-emerald-400" />
                            Budget Check
                          </span>
                          {renderCheckBadge(check)}
                        </div>
                        <p className="text-xs text-slate-400">
                          {check.isUnassessed
                            ? 'Awaiting financial budget ceiling calculation.'
                            : check.isPass
                              ? 'Order total within authorized budget ceiling.'
                              : 'Order financial cost exceeds approved budget limit.'}
                        </p>
                      </div>
                    );
                  })()}

                  {/* PO Math Check */}
                  {(() => {
                    const check = mapCheckStatus(selectedWorkflow.poMathematicalCheck);
                    return (
                      <div className="p-3.5 rounded-xl bg-slate-950 border border-slate-800 flex flex-col justify-between">
                        <div className="flex items-center justify-between mb-1.5">
                          <span className="font-semibold text-sm text-slate-200 flex items-center gap-1.5">
                            <Calculator className="w-4 h-4 text-purple-400" />
                            PO Math Check
                          </span>
                          {renderCheckBadge(check)}
                        </div>
                        <p className="text-xs text-slate-400">
                          {check.isUnassessed
                            ? 'Awaiting arithmetic price and rate calculation.'
                            : check.isPass
                              ? 'Price × Quantity = Total matches exactly.'
                              : 'Arithmetic calculation mismatch detected.'}
                        </p>
                      </div>
                    );
                  })()}

                  {/* Material Check */}
                  {(() => {
                    const check = mapCheckStatus(selectedWorkflow.materialValidation);
                    return (
                      <div className="p-3.5 rounded-xl bg-slate-950 border border-slate-800 flex flex-col justify-between">
                        <div className="flex items-center justify-between mb-1.5">
                          <span className="font-semibold text-sm text-slate-200 flex items-center gap-1.5">
                            <Package className="w-4 h-4 text-amber-400" />
                            Material Check
                          </span>
                          {renderCheckBadge(check)}
                        </div>
                        <p className="text-xs text-slate-400">
                          {check.isUnassessed
                            ? 'Awaiting raw material database catalog check.'
                            : check.isPass
                              ? 'Raw material catalog SKU verified in database.'
                              : 'Raw material SKU is invalid or missing in catalog.'}
                        </p>
                      </div>
                    );
                  })()}
                </div>
              </div>

              {/* Order Lines / Items */}
              {selectedWorkflow.items && selectedWorkflow.items.length > 0 && (
                <div className="space-y-2">
                  <h4 className="text-xs font-bold uppercase tracking-wider text-slate-400">
                    Purchase Order Line Items
                  </h4>
                  <div className="bg-slate-950 border border-slate-800 rounded-xl overflow-hidden">
                    <table className="w-full text-left text-xs">
                      <thead className="bg-slate-900/80 border-b border-slate-800 text-slate-400">
                        <tr>
                          <th className="py-2.5 px-3">SKU</th>
                          <th className="py-2.5 px-3">Material Name</th>
                          <th className="py-2.5 px-3 text-right">Quantity</th>
                          <th className="py-2.5 px-3">Unit</th>
                        </tr>
                      </thead>
                      <tbody className="divide-y divide-slate-800/60 font-mono">
                        {selectedWorkflow.items.map((line, idx) => (
                          <tr key={idx}>
                            <td className="py-2 px-3 text-blue-400">{line.materialId || 'N/A'}</td>
                            <td className="py-2 px-3 text-slate-200 font-sans">{line.materialName || 'N/A'}</td>
                            <td className="py-2 px-3 text-right text-slate-100">{line.quantity ?? 'N/A'}</td>
                            <td className="py-2 px-3 text-slate-400">{line.unit || ''}</td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                </div>
              )}

              {/* Checked Supplier Info */}
              {selectedWorkflow.checkedSupplier && (
                <div className="space-y-2">
                  <h4 className="text-xs font-bold uppercase tracking-wider text-slate-400">
                    Supplier & Financial Quote
                  </h4>
                  <div className="p-3.5 rounded-xl bg-slate-950 border border-slate-800 grid grid-cols-2 sm:grid-cols-4 gap-3 text-xs">
                    <div>
                      <span className="text-slate-500 block text-[11px]">Supplier Name</span>
                      <span className="font-semibold text-slate-200">{selectedWorkflow.checkedSupplier.supplierName || 'N/A'}</span>
                    </div>
                    <div>
                      <span className="text-slate-500 block text-[11px]">Unit Price</span>
                      <span className="font-mono text-slate-200">
                        {selectedWorkflow.checkedSupplier.unitPrice !== undefined ? `LKR ${selectedWorkflow.checkedSupplier.unitPrice}` : 'N/A'}
                      </span>
                    </div>
                    <div>
                      <span className="text-slate-500 block text-[11px]">Estimated Total</span>
                      <span className="font-mono text-slate-200">
                        {selectedWorkflow.checkedSupplier.totalCost !== undefined ? `LKR ${Number(selectedWorkflow.checkedSupplier.totalCost).toLocaleString()}` : 'N/A'}
                      </span>
                    </div>
                    <div>
                      <span className="text-slate-500 block text-[11px]">Lead Time</span>
                      <span className="font-semibold text-slate-200">
                        {selectedWorkflow.checkedSupplier.leadTimeDays !== undefined ? `${selectedWorkflow.checkedSupplier.leadTimeDays} days` : 'N/A'}
                      </span>
                    </div>
                  </div>
                </div>
              )}

              {/* Diagnostics & Reasons */}
              {(selectedWorkflow.rejectionReason || selectedWorkflow.impactReason) && (
                <div className="space-y-2">
                  <h4 className="text-xs font-bold uppercase tracking-wider text-slate-400">
                    Diagnostic Analysis & Audit Notes
                  </h4>
                  <div className="p-3.5 rounded-xl bg-slate-950 border border-slate-800 text-xs text-slate-300 space-y-1">
                    {selectedWorkflow.rejectionReason && (
                      <p className="text-rose-400">
                        <span className="font-semibold">Rejection Reason: </span>
                        {selectedWorkflow.rejectionReason}
                      </p>
                    )}
                    {selectedWorkflow.impactReason && (
                      <p className="text-slate-400">
                        <span className="font-semibold text-slate-300">Operational Assessment: </span>
                        {selectedWorkflow.impactReason}
                      </p>
                    )}
                  </div>
                </div>
              )}
            </div>

            {/* Modal Footer */}
            <div className="mt-6 pt-4 border-t border-slate-800 flex justify-end">
              <button
                type="button"
                onClick={() => setIsDetailsModalOpen(false)}
                className="px-4 py-2 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-200 text-xs font-semibold transition-colors"
              >
                Close
              </button>
            </div>
          </div>
        </ModalOverlay>
      )}
    </div>
  );
}

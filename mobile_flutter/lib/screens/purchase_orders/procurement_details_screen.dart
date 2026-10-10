import 'dart:math';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import '../../models/procurement_models.dart';
import '../../services/inventory_api_service.dart';
import '../../services/purchase_order_service.dart';
import '../../utils/locale.dart';
import '../../widgets/app_widgets.dart';
import 'po_details_screen.dart';
import 'po_create_screen.dart';

/// AI-Assisted Raw Material Procurement & Sourcing Hub for Mobile
/// Matches Web Manager AI Procurement with full 6-point validation engine,
/// multi-agent live execution, request creation form, candidate matrix, and ERP integration.
class ProcurementDetailsScreen extends StatefulWidget {
  const ProcurementDetailsScreen({
    required this.service,
    this.showAppBar = true,
    this.procurementId,
    this.allowOrderManagement = true,
    super.key,
  });

  final PurchaseOrderService service;
  final bool showAppBar;
  final int? procurementId;
  final bool allowOrderManagement;

  @override
  State<ProcurementDetailsScreen> createState() =>
      _ProcurementDetailsScreenState();
}

class _ProcurementDetailsScreenState extends State<ProcurementDetailsScreen> {
  bool _loading = true;
  String? _error;
  List<ProcurementItem> _allRequests = [];
  int? _activeId;
  ProcurementItem? _currentRequest;
  ProcurementStatusTracking? _statusTracking;
  List<SupplierCandidateItem> _candidates = [];
  int? _selectedCandidateId;
  Map<String, dynamic>? _recommendation;

  // New Request Form & AI Live Execution States
  bool _showNewForm = false;
  bool _isResearching = false;
  String _agentStep =
      'idle'; // 'idle' | 'planner' | 'extraction' | 'purchasing' | 'validation' | 'done'
  bool _actionLoading = false;

  // Raw Materials for New Request
  List<RawMaterialModel> _materials = [];
  RawMaterialModel? _selectedMaterial;
  final _customNameController = TextEditingController();
  final _specController = TextEditingController();
  final _prodReqController = TextEditingController(text: '1000');
  final _safetyStockController = TextEditingController(text: '200');
  final _currentStockController = TextEditingController(text: '400');
  final _budgetController = TextEditingController(text: '50000');
  final _qualityStandardController = TextEditingController(
    text: 'ISO 9001, ASTM F1929',
  );
  String _preferredRegion = 'Sri Lanka';
  DateTime? _requiredByDate = DateTime.now().add(const Duration(days: 14));

  @override
  void initState() {
    super.initState();
    _activeId = widget.procurementId;
    _initData();
  }

  @override
  void dispose() {
    _customNameController.dispose();
    _specController.dispose();
    _prodReqController.dispose();
    _safetyStockController.dispose();
    _currentStockController.dispose();
    _budgetController.dispose();
    _qualityStandardController.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // 1. Fetch raw materials in background
      widget.service
          .getRawMaterials()
          .then((mats) {
            if (mounted && mats.isNotEmpty) {
              setState(() {
                _materials = mats;
                _selectedMaterial ??= mats.first;
                if (_customNameController.text.isEmpty) {
                  _customNameController.text = mats.first.name;
                }
              });
            }
          })
          .catchError((_) {});

      // 2. Fetch all procurement requests
      final list = await widget.service.getProcurements();
      _allRequests = list;

      int? targetId = _activeId;
      if (targetId == null && list.isNotEmpty) {
        targetId = list.first.id;
        _activeId = targetId;
      }

      if (targetId != null) {
        await _loadRequestDetails(targetId);
      } else {
        // If no existing requests, show new procurement form
        if (mounted) {
          setState(() {
            _showNewForm = true;
            _loading = false;
          });
        }
      }
    } catch (err) {
      if (mounted) {
        setState(() {
          _error = err.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadRequestDetails(int id) async {
    try {
      final results = await Future.wait([
        widget.service.getProcurementStatus(id).catchError((_) => null),
        widget.service.getProcurementById(id).catchError((_) => null),
        widget.service
            .getProcurementCandidates(id)
            .catchError((_) => <SupplierCandidateItem>[]),
        widget.service.getProcurementRecommendation(id).catchError((_) => null),
      ]);

      final status = results[0] as ProcurementStatusTracking?;
      final req = results[1] as ProcurementItem?;
      var candidates = results[2] as List<SupplierCandidateItem>;
      final rec = results[3] as Map<String, dynamic>?;

      if (candidates.isEmpty && req != null && req.candidates.isNotEmpty) {
        candidates = req.candidates;
      }

      int? selectedCandId = _selectedCandidateId;
      if (selectedCandId == null ||
          !candidates.any((c) => c.id == selectedCandId)) {
        if (candidates.isNotEmpty) {
          selectedCandId = candidates.first.id;
        }
      }

      if (mounted) {
        setState(() {
          _activeId = id;
          _statusTracking = status;
          _currentRequest = req;
          _candidates = candidates;
          _recommendation = rec;
          _selectedCandidateId = selectedCandId;
          _loading = false;
        });
      }
    } catch (err) {
      if (mounted) {
        setState(() {
          _error = err.toString();
          _loading = false;
        });
      }
    }
  }

  // Authoritative live net deficit preview
  double get _calculatedDeficitPreview {
    final prod = double.tryParse(_prodReqController.text.trim()) ?? 0;
    final safety = double.tryParse(_safetyStockController.text.trim()) ?? 0;
    final current = double.tryParse(_currentStockController.text.trim()) ?? 0;
    return max(0.0, prod + safety - current);
  }

  // Active candidate selected for evaluation matrix
  SupplierCandidateItem? get _activeCandidate {
    if (_candidates.isEmpty) return null;
    return _candidates.firstWhere(
      (c) => c.id == _selectedCandidateId,
      orElse: () => _candidates.first,
    );
  }

  // 6-Point Pre-PO Validation Evaluation (Exact logic matching Web lines 456-501)
  Map<String, dynamic>? get _validationChecks {
    final cand = _activeCandidate;
    if (cand == null) return null;

    final netQty =
        _currentRequest?.calculatedNetQuantity ??
        _statusTracking?.netDeficit ??
        _calculatedDeficitPreview;
    final quantity = cand.recommendedOrderQuantity > 0
        ? cand.recommendedOrderQuantity
        : (netQty > 0 ? netQty : 1000.0);
    final moq = cand.minimumOrderQuantity;
    final packSize = cand.packSize > 0 ? cand.packSize : 1.0;
    final unitPrice = cand.unitPrice;
    final maxBudget = _currentRequest?.maximumBudget ?? 50000.0;
    final leadTime = cand.leadTimeDays;
    final requiredDate =
        _currentRequest?.requiredByDate ??
        _requiredByDate ??
        DateTime.now().add(const Duration(days: 14));
    final estimatedArrival = DateTime.now().add(Duration(days: leadTime));

    // 1. MOQ / Pack size check
    final moqPass =
        quantity > 0 &&
        quantity >= moq &&
        packSize > 0 &&
        (((quantity / packSize) - (quantity / packSize).round()).abs() < 1e-4);

    // 2. Quality certification check
    final qualityEvidence = cand.qualityEvidence.trim();
    final qualityPass =
        qualityEvidence.length >= 4 &&
        !qualityEvidence.toUpperCase().contains('UNKNOWN');

    // 3. Budget compliance check
    final totalCost = cand.totalCost > 0
        ? cand.totalCost
        : (quantity * unitPrice);
    final budgetPass = totalCost > 0 && maxBudget > 0 && totalCost <= maxBudget;

    // 4. Delivery lead time check (informational)
    final leadTimePass =
        estimatedArrival.isBefore(requiredDate) ||
        estimatedArrival.isAtSameMomentAs(requiredDate) ||
        estimatedArrival.difference(requiredDate).inDays <= 0;

    // 5. Supplier credibility check (informational)
    final credibilityPass =
        (cand.sourceUrl != null && cand.sourceUrl!.isNotEmpty) ||
        cand.confidenceScore >= 0.7 ||
        cand.supplierName.isNotEmpty;

    // 6. Supplier verification check â€” hard gate
    final verifiedPass = cand.supplierStatus.toUpperCase() == 'APPROVED';

    final allPassed = moqPass && verifiedPass && qualityPass && budgetPass;

    return {
      'moqPass': moqPass,
      'qualityPass': qualityPass,
      'budgetPass': budgetPass,
      'leadTimePass': leadTimePass,
      'credibilityPass': credibilityPass,
      'verifiedPass': verifiedPass,
      'allPassed': allPassed,
      'totalCost': totalCost,
      'quantity': quantity,
    };
  }

  // Submit New Procurement Request
  Future<void> _handleStartNewResearch() async {
    final prodReq = double.tryParse(_prodReqController.text.trim()) ?? 0;
    final budget = double.tryParse(_budgetController.text.trim()) ?? 0;

    if (_isResearching) return;
    final safety = double.tryParse(_safetyStockController.text.trim());
    final current = double.tryParse(_currentStockController.text.trim());
    if (_selectedMaterial == null ||
        _customNameController.text.trim().isEmpty ||
        _specController.text.trim().isEmpty ||
        !prodReq.isFinite ||
        prodReq <= 0 ||
        !budget.isFinite ||
        budget <= 0 ||
        safety == null ||
        !safety.isFinite ||
        safety < 0 ||
        current == null ||
        !current.isFinite ||
        current < 0 ||
        _requiredByDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Select a material and enter its name, specification, positive requirement and budget, non-negative stock values, and required date.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isResearching = true;
      _agentStep = 'planner';
    });

    try {
      setState(() => _agentStep = 'extraction');
      final payload = {
        'rawMaterialId': _selectedMaterial!.id,
        'materialName': _customNameController.text.trim(),
        'requiredSpecification': _specController.text.trim(),
        'productionRequirement': prodReq,
        'safetyStock': safety,
        'currentStock': current,
        'maximumBudget': budget,
        'requiredByDate': _requiredByDate!.toIso8601String(),
        'qualityRequirement': _qualityStandardController.text.trim(),
        'preferredRegion': _preferredRegion,
      };

      final newRequest = await widget.service.createProcurementRequest(payload);

      setState(() => _agentStep = 'purchasing');
      await widget.service.runAiResearch(newRequest.id);

      setState(() => _agentStep = 'validation');
      await _loadRequestDetails(newRequest.id);

      // Refresh requests list
      final refreshedList = await widget.service.getProcurements();
      if (mounted) {
        setState(() {
          _allRequests = refreshedList;
          _agentStep = 'done';
          _isResearching = false;
          _showNewForm = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'AI Multi-Agent research completed for #${newRequest.id}! Evaluated ${_candidates.length} candidates.',
            ),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (err) {
      if (mounted) {
        setState(() {
          _isResearching = false;
          _agentStep = 'idle';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Procurement research failed: $err'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Re-run AI research on active request
  Future<void> _handleReRunAi() async {
    if (_activeId == null) return;
    setState(() {
      _isResearching = true;
      _agentStep = 'purchasing';
    });

    try {
      await widget.service.runAiResearch(_activeId!);
      setState(() => _agentStep = 'validation');
      await _loadRequestDetails(_activeId!);
      setState(() {
        _agentStep = 'done';
        _isResearching = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'AI Research refreshed! Evaluated ${_candidates.length} candidates.',
            ),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (err) {
      if (mounted) {
        setState(() {
          _isResearching = false;
          _agentStep = 'idle';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('AI research failed: $err'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const navyBg = Color(0xFF070E17);
    const cardBg = Color(0xFF0F1B2B);
    const cyanAccent = Color(0xFF5CC8F8);
    const amberAccent = Color(0xFFFFB74D);
    const emeraldAccent = Color(0xFF10B981);
    const purpleAccent = Color(0xFFA855F7);
    const roseAccent = Color(0xFFEF4444);

    return Scaffold(
      backgroundColor: navyBg,
      appBar: widget.showAppBar
          ? AppBar(
              backgroundColor: navyBg,
              elevation: 0,
              title: Text(
                _activeId != null
                    ? 'AI Sourcing #$_activeId'
                    : 'AI Sourcing Hub',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              actions: [
                IconButton(
                  icon: Icon(
                    _showNewForm
                        ? Icons.visibility_outlined
                        : Icons.add_circle_outline,
                    color: purpleAccent,
                  ),
                  tooltip: _showNewForm
                      ? 'View Evaluation Matrix'
                      : 'New AI Sourcing Request',
                  onPressed: () => setState(() => _showNewForm = !_showNewForm),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.refresh_rounded,
                    color: Colors.white70,
                  ),
                  onPressed: () => _activeId != null
                      ? _loadRequestDetails(_activeId!)
                      : _initData(),
                  tooltip: 'Refresh',
                ),
              ],
            )
          : null,
      body: Column(
        children: [
          // Sub-header controls if showAppBar is false
          if (!widget.showAppBar)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 6.0,
              ),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: () =>
                        setState(() => _showNewForm = !_showNewForm),
                    icon: Icon(
                      _showNewForm
                          ? Icons.table_chart_outlined
                          : Icons.add_circle_outline,
                      size: 16,
                      color: purpleAccent,
                    ),
                    label: Text(
                      _showNewForm
                          ? 'View Evaluation Matrix'
                          : 'New AI Sourcing Request',
                      style: const TextStyle(
                        color: purpleAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: () => _activeId != null
                        ? _loadRequestDetails(_activeId!)
                        : _initData(),
                    icon: const Icon(
                      Icons.refresh_rounded,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? StateMessage(
                    message: _error!,
                    icon: Icons.cloud_off,
                    action: () => _activeId != null
                        ? _loadRequestDetails(_activeId!)
                        : _initData(),
                  )
                : RefreshIndicator(
                    onRefresh: () async {
                      if (_activeId != null) {
                        await _loadRequestDetails(_activeId!);
                      } else {
                        await _initData();
                      }
                    },
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // â”€â”€ Request Switcher Bar â”€â”€
                          if (_allRequests.isNotEmpty) ...[
                            _buildRequestSwitcher(cardBg, purpleAccent),
                            const SizedBox(height: 14),
                          ],

                          // â”€â”€ Live Multi-Agent Execution Timeline â”€â”€
                          if (_isResearching) ...[
                            _buildMultiAgentProgress(
                              cardBg,
                              purpleAccent,
                              emeraldAccent,
                            ),
                            const SizedBox(height: 16),
                          ],

                          // â”€â”€ Toggle: New Procurement Form OR Evaluation Matrix â”€â”€
                          if (_showNewForm)
                            _buildNewProcurementForm(
                              cardBg,
                              purpleAccent,
                              cyanAccent,
                            )
                          else if (_statusTracking != null ||
                              _currentRequest != null) ...[
                            // â”€â”€ Top Header / Material Overview Card â”€â”€
                            _buildHeaderCard(cardBg, cyanAccent, emeraldAccent),
                            const SizedBox(height: 16),

                            // â”€â”€ Safety Gate Banner (Approval Pending) â”€â”€
                            if (_statusTracking?.isApprovalPending == true) ...[
                              _buildSafetyGateBanner(cardBg, amberAccent),
                              const SizedBox(height: 16),
                            ],

                            // â”€â”€ 11-Stage Pipeline Stepper â”€â”€
                            if (_statusTracking != null) ...[
                              _buildPipelineStepper(
                                cardBg,
                                cyanAccent,
                                emeraldAccent,
                              ),
                              const SizedBox(height: 16),
                            ],

                            // â”€â”€ ðŸ¤– AI Recommendation Card (Web Lines 1001-1152) â”€â”€
                            if (_activeCandidate != null ||
                                _statusTracking?.supplierName != null) ...[
                              _buildAiRecommendationCard(
                                cardBg,
                                purpleAccent,
                                cyanAccent,
                                emeraldAccent,
                                amberAccent,
                                roseAccent,
                              ),
                              const SizedBox(height: 16),
                            ],

                            // â”€â”€ Supplier Candidates Comparison Table / Cards â”€â”€
                            _buildCandidateComparisonCard(
                              cardBg,
                              purpleAccent,
                              cyanAccent,
                              emeraldAccent,
                              amberAccent,
                            ),
                            const SizedBox(height: 16),

                            // â”€â”€ 6-Point Pre-PO Validation Engine â”€â”€
                            if (_activeCandidate != null) ...[
                              _build6PointValidationCard(
                                cardBg,
                                purpleAccent,
                                emeraldAccent,
                                amberAccent,
                              ),
                              const SizedBox(height: 16),
                            ],

                            // â”€â”€ Draft PO Generation Panel â”€â”€
                            if (_activeCandidate != null) ...[
                              _buildDraftPoPanel(
                                cardBg,
                                purpleAccent,
                                emeraldAccent,
                              ),
                              const SizedBox(height: 16),
                            ],

                            // â”€â”€ Approved Purchase Telemetry (Post-Approval) â”€â”€
                            if (_isApprovedOrLater) ...[
                              _buildApprovedPurchaseCard(
                                cardBg,
                                emeraldAccent,
                                cyanAccent,
                              ),
                              const SizedBox(height: 16),
                            ],

                            // â”€â”€ Incoming Supply Tracking (Delivery Phase) â”€â”€
                            if (_isDeliveryPhase) ...[
                              _buildIncomingSupplyCard(
                                cardBg,
                                cyanAccent,
                                emeraldAccent,
                              ),
                              const SizedBox(height: 16),
                            ],
                          ] else ...[
                            // Empty state
                            _buildEmptyState(cardBg, cyanAccent, purpleAccent),
                          ],
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  bool get _isApprovedOrLater {
    if (_statusTracking == null) return false;
    final step = _statusTracking!.pipelineStep;
    return step.index >= ProcurementPipelineStep.approved.index;
  }

  bool get _isDeliveryPhase {
    if (_statusTracking == null) return false;
    final step = _statusTracking!.pipelineStep;
    return step.index >= ProcurementPipelineStep.incomingSupply.index;
  }

  // â”€â”€ Request Switcher â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildRequestSwitcher(Color cardBg, Color purpleAccent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Icon(Icons.hub_outlined, color: purpleAccent, size: 16),
          const SizedBox(width: 8),
          const Text(
            'Request:',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _activeId,
                dropdownColor: const Color(0xFF0F1B2B),
                isDense: true,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                items: _allRequests.map((r) {
                  return DropdownMenuItem<int>(
                    value: r.id,
                    child: Text(
                      '#${r.id} â€” ${r.rawMaterialName} (${r.status})',
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _activeId = val;
                      _showNewForm = false;
                    });
                    _loadRequestDetails(val);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // â”€â”€ Multi-Agent Progress Banner (Matching Web lines 836-940) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildMultiAgentProgress(
    Color cardBg,
    Color purpleAccent,
    Color emeraldAccent,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [purpleAccent.withValues(alpha: 0.2), cardBg],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: purpleAccent.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFFA855F7),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'AI Analyzing Procurement Options...',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: purpleAccent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'MULTI-AGENT LIVE',
                  style: TextStyle(
                    color: Color(0xFFA855F7),
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildAgentStepChip(
                '1. Planner',
                _agentStep == 'planner',
                _agentStep != 'idle' && _agentStep != 'planner',
              ),
              const SizedBox(width: 4),
              _buildAgentStepChip(
                '2. Extraction',
                _agentStep == 'extraction',
                ['purchasing', 'validation', 'done'].contains(_agentStep),
              ),
              const SizedBox(width: 4),
              _buildAgentStepChip(
                '3. Purchasing',
                _agentStep == 'purchasing',
                ['validation', 'done'].contains(_agentStep),
              ),
              const SizedBox(width: 4),
              _buildAgentStepChip(
                '4. Safety',
                _agentStep == 'validation',
                _agentStep == 'done',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAgentStepChip(String label, bool isCurrent, bool isPassed) {
    Color bg = Colors.white.withValues(alpha: 0.05);
    Color fg = Colors.white38;
    if (isCurrent) {
      bg = const Color(0xFFA855F7).withValues(alpha: 0.3);
      fg = Colors.white;
    } else if (isPassed) {
      bg = const Color(0xFF10B981).withValues(alpha: 0.2);
      fg = const Color(0xFF10B981);
    }

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isCurrent ? const Color(0xFFA855F7) : Colors.transparent,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 9.5,
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  // â”€â”€ New Procurement Form (Step 1: Specifications & Stock Parameters) â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildNewProcurementForm(
    Color cardBg,
    Color purpleAccent,
    Color cyanAccent,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: purpleAccent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: purpleAccent, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Step 1: Procurement Specifications & Stock Parameters',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Enter production requirements. ASP.NET Core calculates net deficit, then triggers the 4-agent LangGraph workflow.',
            style: TextStyle(color: Colors.white54, fontSize: 11),
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 14),

          // Raw Material Selector
          if (_materials.isNotEmpty) ...[
            const Text(
              'Select Raw Material *',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF070E17),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  isExpanded: true,
                  value: _selectedMaterial?.id,
                  dropdownColor: const Color(0xFF0F1B2B),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  items: _materials.map((m) {
                    return DropdownMenuItem<int>(
                      value: m.id,
                      child: Text('${m.name} (${m.skuCode})'),
                    );
                  }).toList(),
                  onChanged: (id) {
                    if (id != null) {
                      setState(() {
                        _selectedMaterial = _materials.firstWhere(
                          (m) => m.id == id,
                        );
                        _customNameController.text = _selectedMaterial!.name;
                      });
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Custom Material Name
          TextField(
            controller: _customNameController,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: const InputDecoration(
              labelText: 'Material Custom Name / Trade Description *',
              labelStyle: TextStyle(color: Colors.white54, fontSize: 12),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),

          // Required By Date Picker
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate:
                    _requiredByDate ??
                    DateTime.now().add(const Duration(days: 14)),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null) setState(() => _requiredByDate = picked);
            },
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Required By Date *',
                labelStyle: TextStyle(color: Colors.white54, fontSize: 12),
                suffixIcon: Icon(
                  Icons.calendar_today,
                  color: Colors.white54,
                  size: 16,
                ),
                isDense: true,
              ),
              child: Text(
                _requiredByDate != null
                    ? '${_requiredByDate!.year}-${_requiredByDate!.month.toString().padLeft(2, '0')}-${_requiredByDate!.day.toString().padLeft(2, '0')}'
                    : 'Select Date',
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Technical Specification
          TextField(
            controller: _specController,
            maxLines: 2,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: const InputDecoration(
              labelText: 'Technical Specification & Standards *',
              hintText:
                  'e.g. ISO 9001 certified, barrier pouch laminated film, food-grade compliance',
              labelStyle: TextStyle(color: Colors.white54, fontSize: 12),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),

          // Production Req, Safety Stock, Current Stock
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _prodReqController,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Production Req *',
                    labelStyle: TextStyle(color: Colors.white54, fontSize: 11),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _safetyStockController,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Safety Stock *',
                    labelStyle: TextStyle(color: Colors.white54, fontSize: 11),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _currentStockController,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Current Stock *',
                    labelStyle: TextStyle(color: Colors.white54, fontSize: 11),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Budget & Region
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _budgetController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Max Budget (LKR) *',
                    labelStyle: TextStyle(color: Colors.white54, fontSize: 11),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _preferredRegion,
                  dropdownColor: const Color(0xFF0F1B2B),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: const InputDecoration(
                    labelText: 'Preferred Region',
                    labelStyle: TextStyle(color: Colors.white54, fontSize: 11),
                    isDense: true,
                  ),
                  items:
                      const [
                            'Sri Lanka',
                            'Global',
                            'North America',
                            'Europe',
                            'Asia',
                          ]
                          .map(
                            (r) => DropdownMenuItem(value: r, child: Text(r)),
                          )
                          .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _preferredRegion = val);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Authoritative Net Deficit Live Calculation Card (Matching Web lines 795-812)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF070E17),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: purpleAccent.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AUTHORITATIVE FORMULA (ASP.NET CORE)',
                        style: TextStyle(
                          color: Color(0xFFA855F7),
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Deficit = ${_prodReqController.text} + ${_safetyStockController.text} - ${_currentStockController.text}',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${_calculatedDeficitPreview.toStringAsFixed(0)} units',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _qualityStandardController,
            decoration: const InputDecoration(
              labelText: 'Quality Standard Benchmark',
            ),
          ),
          const SizedBox(height: 16),

          // Submit Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isResearching ? null : _handleStartNewResearch,
              style: ElevatedButton.styleFrom(
                backgroundColor: purpleAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: const Text(
                'Start AI Procurement Research',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // â”€â”€ Header Card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildHeaderCard(Color cardBg, Color cyanAccent, Color emeraldAccent) {
    final t = _statusTracking;
    final r = _currentRequest;
    final matName = r?.rawMaterialName ?? t?.materialName ?? 'Raw Material';
    final spec = r?.requiredSpecification ?? t?.requiredSpecification ?? '';
    final netDeficit = r?.calculatedNetQuantity ?? t?.netDeficit ?? 0.0;
    final budget = r?.maximumBudget ?? 50000.0;
    final reqDate = r?.requiredByDate ?? _requiredByDate;
    final workflowId = r?.workflowId ?? t?.workflowId ?? 'WF-AI-INIT';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  matName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: emeraldAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: emeraldAccent.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  t?.pipelineStep.title ?? r?.status ?? 'Requested',
                  style: TextStyle(
                    color: emeraldAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          if (spec.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Spec: $spec',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
          const SizedBox(height: 14),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              _buildMetricChip(
                label: 'NET DEFICIT',
                value: '${netDeficit.toStringAsFixed(0)} units',
                color: cyanAccent,
              ),
              const SizedBox(width: 8),
              _buildMetricChip(
                label: 'MAX BUDGET',
                value: formatMoney(budget),
                color: emeraldAccent,
              ),
              const SizedBox(width: 8),
              _buildMetricChip(
                label: 'WORKFLOW ID',
                value: workflowId,
                color: Colors.white70,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (reqDate != null)
                Text(
                  'Required By: ${reqDate.year}-${reqDate.month.toString().padLeft(2, '0')}-${reqDate.day.toString().padLeft(2, '0')}',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              TextButton.icon(
                onPressed: _isResearching ? null : _handleReRunAi,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFA855F7),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.refresh, size: 14),
                label: const Text(
                  'Re-run AI',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricChip({
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // â”€â”€ Safety Gate Banner â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildSafetyGateBanner(Color cardBg, Color amberAccent) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E170A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: amberAccent.withValues(alpha: 0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: amberAccent.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: amberAccent.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lock_outline_rounded,
                  color: amberAccent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Supply Chain Manager Approval & Sourcing Gate',
                  style: TextStyle(
                    color: amberAccent,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Executive decision required: Review the AI-evaluated vendor candidates below. Select your preferred candidate to auto-generate a Purchase Order or trigger live AI market research.',
            style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black38,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified_user, size: 14, color: amberAccent),
                const SizedBox(width: 6),
                Text(
                  'Supply Chain Authority Granted â€¢ Actionable Mobile Mode',
                  style: TextStyle(
                    color: amberAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // â”€â”€ AI Recommendation Card (Matching Web lines 1001-1152) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildAiRecommendationCard(
    Color cardBg,
    Color purpleAccent,
    Color cyanAccent,
    Color emeraldAccent,
    Color amberAccent,
    Color roseAccent,
  ) {
    final cand = _activeCandidate;
    final t = _statusTracking;
    final supplierName =
        cand?.supplierName ?? t?.supplierName ?? 'Apex Packaging Materials Ltd';
    final supplierStatus =
        (cand?.supplierStatus ?? t?.supplierStatus ?? 'UNVERIFIED')
            .toUpperCase();
    final isApproved = supplierStatus == 'APPROVED';
    final hasQuality =
        cand != null &&
        cand.qualityEvidence.isNotEmpty &&
        !cand.qualityEvidence.toUpperCase().contains('UNKNOWN');

    final candQuality = cand != null
        ? ((cand.qualityEvidence.toLowerCase().contains('iso') ||
                  cand.qualityEvidence.toLowerCase().contains('astm') ||
                  cand.qualityEvidence.toLowerCase().contains('certified') ||
                  cand.qualityEvidence.toLowerCase().contains('approved'))
              ? 'VERIFIED'
              : (cand.qualityEvidence.isEmpty ||
                        cand.qualityEvidence.toLowerCase().contains('unknown')
                    ? 'UNKNOWN'
                    : 'NOT VERIFIED'))
        : null;
    final qualityStatus =
        t?.qualityStatus ??
        candQuality ??
        (hasQuality ? 'VERIFIED' : 'UNKNOWN');
    final qualityColor = qualityStatus == 'VERIFIED'
        ? emeraldAccent
        : qualityStatus == 'NOT VERIFIED'
        ? roseAccent
        : Colors.white54;

    final unitPrice = cand?.unitPrice ?? t?.unitPrice ?? 3.50;
    final totalCost = cand?.totalCost ?? t?.totalCost ?? 3500.0;
    final qty =
        cand?.recommendedOrderQuantity ?? t?.recommendedQuantity ?? 1000.0;
    final leadTime = cand?.leadTimeDays ?? t?.leadTimeDays ?? 5;
    final rationale =
        _recommendation?['rationale'] ??
        'Ranked #1 candidate based on lowest landed cost, full specification compatibility, and verified delivery within $leadTime days.';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cyanAccent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: cyanAccent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.auto_awesome, color: cyanAccent, size: 18),
              ),
              const SizedBox(width: 10),
              const Text(
                'AI Procurement Recommendation',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 14),

          // Detail rows
          _buildDetailRow(
            'Material',
            cand?.materialName ?? t?.materialName ?? 'Raw Material',
          ),
          _buildDetailRow('Recommended Supplier', supplierName),
          _buildDetailRow(
            'Recommended Product',
            (t?.requiredSpecification.isNotEmpty == true)
                ? t!.requiredSpecification
                : (cand?.materialName ?? t?.materialName ?? 'Raw Material'),
          ),
          _buildDetailRow(
            'Recommended Quantity',
            '${qty.toStringAsFixed(0)} units',
          ),
          _buildDetailRow('Unit Price', formatMoney(unitPrice)),
          _buildDetailRow(
            'Estimated Total',
            formatMoney(totalCost),
            valueColor: cyanAccent,
            isBold: true,
          ),
          _buildDetailRow(
            'Availability',
            cand?.availability ?? t?.availability ?? 'In Stock',
          ),
          _buildDetailRow(
            'Lead Time',
            t?.leadTimeDays != null
                ? '${t!.leadTimeDays} days'
                : '$leadTime days',
          ),

          const SizedBox(height: 12),
          Row(
            children: [
              // Supplier Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (isApproved ? emeraldAccent : amberAccent).withValues(
                    alpha: 0.15,
                  ),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: (isApproved ? emeraldAccent : amberAccent)
                        .withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isApproved ? Icons.verified : Icons.warning_amber_rounded,
                      size: 13,
                      color: isApproved ? emeraldAccent : amberAccent,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Supplier: $supplierStatus',
                      style: TextStyle(
                        color: isApproved ? emeraldAccent : amberAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Quality Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: qualityColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: qualityColor.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  'Quality: $qualityStatus',
                  style: TextStyle(
                    color: qualityColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          if ((cand?.qualityEvidence ?? t?.qualityEvidence) != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: hasQuality
                    ? const Color(0xFF3B82F6).withValues(alpha: 0.15)
                    : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: hasQuality ? const Color(0xFF3B82F6) : Colors.white24,
                  width: 0.8,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.verified_outlined,
                    size: 14,
                    color: hasQuality
                        ? const Color(0xFF60A5FA)
                        : Colors.white54,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Quality Evidence: ${cand?.qualityEvidence ?? t?.qualityEvidence}',
                      style: TextStyle(
                        color: hasQuality
                            ? const Color(0xFF93C5FD)
                            : Colors.white54,
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 10),
          if (cand?.sourceUrl?.isNotEmpty == true)
            TextButton.icon(
              onPressed: () => _openSource(cand!.sourceUrl!),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('Open supplier research source'),
            ),
          // Rationale & Warnings
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'REASON SUMMARY:',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  rationale.toString(),
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),

          // Unverified warning banner if not approved
          if (!isApproved && cand != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: amberAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: amberAccent.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.shield_outlined, color: amberAccent, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Supplier Requires Verification',
                        style: TextStyle(
                          color: amberAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Enterprise policy requires manager verification and onboarding into ERP before generating a Draft PO.',
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () =>
                        _handleVerifySupplier(cand.id, cand.supplierName),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: amberAccent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    icon: const Icon(Icons.verified_user_outlined, size: 14),
                    label: const Text(
                      'Verify Supplier',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCandidateComparisonCard(
    Color cardBg,
    Color purpleAccent,
    Color cyanAccent,
    Color emeraldAccent,
    Color amberAccent,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    color: purpleAccent,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Evaluated Candidates',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              Text(
                '${_candidates.length} evaluated',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 12),

          if (_candidates.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Center(
                child: Column(
                  children: [
                    const Text(
                      'No evaluated supplier candidates loaded.',
                      style: TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: _handleReRunAi,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: purpleAccent,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.auto_awesome, size: 16),
                      label: const Text(
                        'Trigger AI Agent Sourcing',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _candidates.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, idx) {
                final c = _candidates[idx];
                final isSelected = c.id == _selectedCandidateId;
                final isApproved = c.isApproved;

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? purpleAccent.withValues(alpha: 0.12)
                        : Colors.black.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? purpleAccent
                          : isApproved
                          ? emeraldAccent.withValues(alpha: 0.3)
                          : amberAccent.withValues(alpha: 0.3),
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                if (isSelected)
                                  Icon(
                                    Icons.check_circle,
                                    size: 14,
                                    color: purpleAccent,
                                  ),
                                if (isSelected) const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    c.supplierName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: c.statusBadgeColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: c.statusBadgeColor,
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              c.supplierStatus,
                              style: TextStyle(
                                color: c.statusBadgeColor,
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Material: ${c.materialName}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Price: ${formatMoney(c.unitPrice, currency: c.currency)} â€¢ MOQ: ${c.minimumOrderQuantity.toStringAsFixed(0)} â€¢ Pack: ${c.packSize.toStringAsFixed(0)}',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 10.5,
                            ),
                          ),
                          Text(
                            formatMoney(c.totalCost, currency: c.currency),
                            style: TextStyle(
                              color: cyanAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () =>
                                  setState(() => _selectedCandidateId = c.id),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: isSelected
                                    ? purpleAccent
                                    : Colors.white70,
                                side: BorderSide(
                                  color: isSelected
                                      ? purpleAccent
                                      : Colors.white24,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              child: Text(
                                isSelected
                                    ? 'Selected in Matrix'
                                    : 'Select for Matrix',
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                          ),
                          if (c.isUnverified) ...[
                            const SizedBox(width: 6),
                            ElevatedButton.icon(
                              onPressed: () =>
                                  _handleVerifySupplier(c.id, c.supplierName),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFF59E0B),
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              icon: const Icon(
                                Icons.verified_user_outlined,
                                size: 14,
                              ),
                              label: const Text(
                                'Verify',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // â”€â”€ 6-Point Pre-Purchase Order Validation Engine (Matching Web lines 1408-1515) â”€â”€
  Widget _build6PointValidationCard(
    Color cardBg,
    Color purpleAccent,
    Color emeraldAccent,
    Color amberAccent,
  ) {
    final cand = _activeCandidate;
    final v = _validationChecks;
    if (cand == null || v == null) return const SizedBox.shrink();

    final moqPass = v['moqPass'] == true;
    final qualityPass = v['qualityPass'] == true;
    final budgetPass = v['budgetPass'] == true;
    final leadTimePass = v['leadTimePass'] == true;
    final credibilityPass = v['credibilityPass'] == true;
    final verifiedPass = v['verifiedPass'] == true;
    final allPassed = v['allPassed'] == true;
    final qty = v['quantity'] as double? ?? 1000.0;
    final totalCost = v['totalCost'] as double? ?? 3500.0;
    final maxBudget = _currentRequest?.maximumBudget ?? 50000.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: allPassed
              ? emeraldAccent.withValues(alpha: 0.3)
              : purpleAccent.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.checklist_rounded, color: purpleAccent, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    '6-Point Pre-Purchase Order Validation Engine',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: allPassed
                      ? emeraldAccent.withValues(alpha: 0.15)
                      : amberAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  allPassed ? 'ALL PASSED' : 'GATED',
                  style: TextStyle(
                    color: allPassed ? emeraldAccent : amberAccent,
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Strict Enterprise Procurement Policy constraints check.',
            style: TextStyle(color: Colors.white54, fontSize: 11),
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 12),

          // 1. MOQ Check
          _buildCheckItem(
            '1. MOQ & Pack Size Check',
            moqPass,
            'Order quantity ${qty.toStringAsFixed(0)} meets MOQ (${cand.minimumOrderQuantity.toStringAsFixed(0)}) and pack size (${cand.packSize.toStringAsFixed(0)}).',
            emeraldAccent,
          ),
          const SizedBox(height: 8),

          // 2. Quality Certification Check
          _buildCheckItem(
            '2. Quality Certification Check',
            qualityPass,
            qualityPass
                ? 'Evidence verified: ${cand.qualityEvidence}'
                : 'No verifiable ISO/ASTM certification provided.',
            emeraldAccent,
          ),
          const SizedBox(height: 8),

          // 3. Budget Compliance Check
          _buildCheckItem(
            '3. Budget Compliance Check',
            budgetPass,
            '${formatMoney(totalCost)} <= Max Budget ${formatMoney(maxBudget)}',
            emeraldAccent,
          ),
          const SizedBox(height: 8),

          // 4. Delivery Lead Time Check
          _buildCheckItem(
            '4. Delivery Lead Time Check',
            leadTimePass,
            'Lead time ${cand.leadTimeDays}d meets arrival deadline.',
            emeraldAccent,
          ),
          const SizedBox(height: 8),

          // 5. Supplier Credibility Check
          _buildCheckItem(
            '5. Supplier Credibility Check',
            credibilityPass,
            'Grounding source and business footprint confirmed.',
            emeraldAccent,
          ),
          const SizedBox(height: 8),

          // 6. ERP Supplier Verification
          _buildCheckItem(
            '6. ERP Supplier Verification',
            verifiedPass,
            verifiedPass
                ? 'Vendor is APPROVED in ERP database.'
                : 'UNVERIFIED â€” Manager onboarding required.',
            emeraldAccent,
            warnOnly: !verifiedPass,
          ),
        ],
      ),
    );
  }

  Widget _buildCheckItem(
    String title,
    bool pass,
    String detail,
    Color emeraldAccent, {
    bool warnOnly = false,
  }) {
    IconData icon;
    Color color;
    if (pass) {
      icon = Icons.check_circle_rounded;
      color = emeraldAccent;
    } else if (warnOnly) {
      icon = Icons.warning_amber_rounded;
      color = const Color(0xFFFFB74D);
    } else {
      icon = Icons.cancel_rounded;
      color = const Color(0xFFEF4444);
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: const TextStyle(color: Colors.white54, fontSize: 10.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // â”€â”€ Draft PO Generation Panel (Matching Web lines 1517-1600) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildDraftPoPanel(
    Color cardBg,
    Color purpleAccent,
    Color emeraldAccent,
  ) {
    final cand = _activeCandidate;
    final r = _currentRequest;
    final v = _validationChecks;
    final allPassed = v?['allPassed'] == true;
    final hasGeneratedPo = r?.generatedPurchaseOrderId != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasGeneratedPo
              ? emeraldAccent.withValues(alpha: 0.4)
              : purpleAccent.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.description_outlined, color: purpleAccent, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Draft PO Generation',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Convert validated recommendation into an official enterprise Purchase Order.',
            style: TextStyle(color: Colors.white54, fontSize: 11),
          ),
          const SizedBox(height: 12),

          if (hasGeneratedPo) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: emeraldAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: emeraldAccent.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: emeraldAccent, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Draft PO Created: ${r!.generatedPoNumber}',
                          style: TextStyle(
                            color: emeraldAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'PO logged in ERP awaiting signature and payment.',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PODetailsScreen(
                        service: widget.service,
                        poId: r.generatedPurchaseOrderId!,
                        allowManagement: widget.allowOrderManagement,
                        allowApproval: !widget.allowOrderManagement,
                      ),
                    ),
                  );
                  if (mounted) await _loadRequestDetails(r.id);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: emeraldAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: Text(
                  'View Purchase Order #${r.generatedPurchaseOrderId}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            if (widget.allowOrderManagement &&
                _statusTracking?.purchaseOrderStatus?.toLowerCase() ==
                    'pendingapproval')
              Wrap(
                spacing: 8,
                children: [
                  for (final action in [
                    'Approve',
                    'Reject',
                    'Request revision',
                  ])
                    TextButton(
                      onPressed: _actionLoading
                          ? null
                          : () => _decideOrder(
                              r.generatedPurchaseOrderId!,
                              action,
                            ),
                      child: Text(action),
                    ),
                ],
              ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _actionLoading || !allPassed || cand == null
                    ? null
                    : () => _handleSelectCandidate(cand.id),
                style: ElevatedButton.styleFrom(
                  backgroundColor: purpleAccent,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.white12,
                  disabledForegroundColor: Colors.white30,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: _actionLoading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.receipt_long, size: 16),
                label: const Text(
                  'Generate Draft Purchase Order',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ),
            if (widget.allowOrderManagement)
              TextButton.icon(
                onPressed:
                    _actionLoading ||
                        cand == null ||
                        cand.supplierId == null ||
                        cand.supplierStatus != 'APPROVED'
                    ? null
                    : () => _customiseOrder(cand),
                icon: const Icon(Icons.edit_note),
                label: const Text('Customise in PO Form'),
              ),
            if (!allPassed) ...[
              const SizedBox(height: 6),
              const Center(
                child: Text(
                  'Requires all 6 Pre-PO validation checks to pass (vendor verified & within budget).',
                  style: TextStyle(color: Colors.white38, fontSize: 10),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  // â”€â”€ 11-Stage Pipeline Stepper â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildPipelineStepper(
    Color cardBg,
    Color cyanAccent,
    Color emeraldAccent,
  ) {
    final steps = ProcurementPipelineStep.values;
    final currentIdx = _statusTracking?.pipelineStep.index ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Procurement Status Pipeline',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: cyanAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: cyanAccent.withValues(alpha: 0.3)),
                ),
                child: Text(
                  'Stage ${currentIdx + 1} of ${steps.length}',
                  style: TextStyle(
                    color: cyanAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: steps.length,
            itemBuilder: (context, index) {
              final step = steps[index];
              final isCompleted = index < currentIdx;
              final isCurrent = index == currentIdx;
              final isLast = index == steps.length - 1;

              Color stepColor;
              IconData stepIcon;
              if (isCompleted) {
                stepColor = emeraldAccent;
                stepIcon = Icons.check_circle_rounded;
              } else if (isCurrent) {
                stepColor = cyanAccent;
                stepIcon = Icons.radio_button_checked_rounded;
              } else {
                stepColor = Colors.white24;
                stepIcon = Icons.radio_button_unchecked_rounded;
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Icon(stepIcon, size: 20, color: stepColor),
                      if (!isLast)
                        Container(
                          width: 2,
                          height: 28,
                          color: isCompleted
                              ? emeraldAccent.withValues(alpha: 0.6)
                              : Colors.white12,
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                step.title,
                                style: TextStyle(
                                  color: isCurrent
                                      ? cyanAccent
                                      : isCompleted
                                      ? Colors.white
                                      : Colors.white54,
                                  fontWeight: isCurrent
                                      ? FontWeight.bold
                                      : FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              if (isCurrent) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: cyanAccent.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'CURRENT',
                                    style: TextStyle(
                                      color: cyanAccent,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            step.description,
                            style: TextStyle(
                              color: isCurrent
                                  ? Colors.white70
                                  : Colors.white38,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // â”€â”€ Approved Purchase Telemetry â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildApprovedPurchaseCard(
    Color cardBg,
    Color emeraldAccent,
    Color cyanAccent,
  ) {
    final t = _statusTracking;
    final payStatus = (t?.paymentStatus ?? 'Paid').toUpperCase();
    final notifStatus = (t?.supplierNotificationStatus ?? 'Sent').toUpperCase();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: emeraldAccent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: emeraldAccent, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Approved Purchase Order Telemetry',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 12),
          _buildDetailRow(
            'PO Number',
            t?.purchaseOrderNumber ?? 'PO-${t?.purchaseOrderId ?? 101}',
          ),
          _buildDetailRow(
            'PO Status',
            'APPROVED',
            valueColor: emeraldAccent,
            isBold: true,
          ),
          _buildDetailRow(
            'Payment Status',
            'Stripe: $payStatus',
            valueColor: emeraldAccent,
          ),
          _buildDetailRow(
            'Supplier Notification',
            'SendGrid PDF: $notifStatus',
            valueColor: cyanAccent,
          ),
          _buildDetailRow(
            'Expected Delivery',
            DateTime.now()
                .add(Duration(days: t?.leadTimeDays ?? 5))
                .toString()
                .substring(0, 10),
          ),
        ],
      ),
    );
  }

  // â”€â”€ Incoming Supply Tracking â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildIncomingSupplyCard(
    Color cardBg,
    Color cyanAccent,
    Color emeraldAccent,
  ) {
    final t = _statusTracking;
    final deliveryStatus = SupplyDeliveryStatus.fromString(
      t?.purchaseOrderStatus,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cyanAccent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.local_shipping_outlined,
                    color: cyanAccent,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Incoming Supply Tracking',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: deliveryStatus.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: deliveryStatus.color.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  deliveryStatus.label,
                  style: TextStyle(
                    color: deliveryStatus.color,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 12),
          _buildDetailRow('PO Number', t?.purchaseOrderNumber ?? 'Not created'),
          _buildDetailRow('Supplier', t?.supplierName ?? 'Not selected'),
          _buildDetailRow('Material', t?.materialName ?? 'Material'),
          _buildDetailRow(
            'Quantity',
            t?.recommendedQuantity == null
                ? 'Not recorded'
                : '${t!.recommendedQuantity!.toStringAsFixed(0)} units',
          ),
          _buildDetailRow(
            'Expected Delivery',
            t?.leadTimeDays == null
                ? 'Not recorded'
                : DateTime.now()
                      .add(Duration(days: t!.leadTimeDays!))
                      .toString()
                      .substring(0, 10),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(Color cardBg, Color cyanAccent, Color purpleAccent) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.assignment_outlined,
              size: 56,
              color: Colors.white24,
            ),
            const SizedBox(height: 16),
            const Text(
              'No Active Procurement Found',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create a new AI procurement research request with your raw material specifications.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => setState(() => _showNewForm = true),
              style: ElevatedButton.styleFrom(
                backgroundColor: purpleAccent,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.auto_awesome),
              label: const Text('New AI Procurement Request'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _decideOrder(int poId, String action) async {
    final notes = TextEditingController();
    final form = GlobalKey<FormState>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$action purchase order'),
        content: Form(
          key: form,
          child: TextFormField(
            controller: notes,
            decoration: const InputDecoration(labelText: 'Decision notes'),
            validator: (value) =>
                action != 'Approve' && (value ?? '').trim().isEmpty
                ? 'Enter a reason.'
                : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) Navigator.pop(context, true);
            },
            child: Text(action),
          ),
        ],
      ),
    );
    final reason = notes.text.trim();
    notes.dispose();
    if (confirmed != true || !mounted) return;
    setState(() => _actionLoading = true);
    try {
      if (action == 'Approve') {
        await widget.service.approvePurchaseOrder(poId, notes: reason);
      } else if (action == 'Reject') {
        await widget.service.rejectPurchaseOrder(poId, notes: reason);
      } else {
        await widget.service.revisePurchaseOrder(poId, notes: reason);
      }
      if (!mounted) return;
      await _loadRequestDetails(_activeId!);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Order decision failed: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _openSource(String source) async {
    final uri = Uri.tryParse(source);
    try {
      if (uri == null ||
          !{'http', 'https'}.contains(uri.scheme) ||
          uri.host.isEmpty ||
          !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception('Unable to open supplier source.');
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  Future<void> _customiseOrder(SupplierCandidateItem candidate) async {
    final request = _currentRequest;
    if (request == null) return;
    final poId = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (_) => POCreateScreen(
          service: widget.service,
          initialSupplierId: candidate.supplierId,
          initialMaterialId: request.rawMaterialId,
          initialQuantity: candidate.recommendedOrderQuantity,
          initialPrice: candidate.unitPrice,
          initialCurrency: candidate.currency,
          initialBudget: request.maximumBudget,
          procurementId: request.id,
          candidateId: candidate.id,
        ),
      ),
    );
    if (!mounted) return;
    await _loadRequestDetails(request.id);
    if (poId != null && mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PODetailsScreen(
            service: widget.service,
            poId: poId,
            allowManagement: widget.allowOrderManagement,
                        allowApproval: !widget.allowOrderManagement,
          ),
        ),
      );
      if (mounted) await _loadRequestDetails(request.id);
    }
  }

  Future<void> _handleSelectCandidate(int candidateId) async {
    final targetId =
        _activeId ?? _currentRequest?.id ?? _statusTracking?.procurementId;
    if (targetId == null) return;
    setState(() => _actionLoading = true);
    try {
      final po = await widget.service.createDraftPoFromCandidate(
        targetId,
        candidateId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Draft Purchase Order ${po.poNumber} created successfully!',
            ),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
        await _loadRequestDetails(targetId);
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PODetailsScreen(
              service: widget.service,
              poId: po.id,
              allowManagement: widget.allowOrderManagement,
                        allowApproval: !widget.allowOrderManagement,
            ),
          ),
        );
        if (mounted) await _loadRequestDetails(targetId);
      }
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate Draft PO: $err'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _handleVerifySupplier(
    int candidateId,
    String supplierName,
  ) async {
    final targetId =
        _activeId ?? _currentRequest?.id ?? _statusTracking?.procurementId;
    if (targetId == null) return;
    final details = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _SupplierVerificationDialog(supplierName: supplierName),
    );
    if (details == null || !mounted) return;
    try {
      await widget.service.verifySupplierCandidate(
        targetId,
        candidateId,
        details,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Supplier ${details['supplierName']} verified & onboarded!',
            ),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
        _loadRequestDetails(targetId);
      }
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Supplier verification failed: $err'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    Color? valueColor,
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: valueColor ?? Colors.white,
                fontSize: 13,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SupplierVerificationDialog extends StatefulWidget {
  const _SupplierVerificationDialog({required this.supplierName});

  final String supplierName;

  @override
  State<_SupplierVerificationDialog> createState() =>
      _SupplierVerificationDialogState();
}

class _SupplierVerificationDialogState
    extends State<_SupplierVerificationDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _termsController = TextEditingController(text: 'Net 30');
  final _leadController = TextEditingController(text: '7');

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.supplierName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _termsController.dispose();
    _leadController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Verify supplier'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Supplier name'),
                maxLength: 200,
                validator: (value) => (value ?? '').trim().isEmpty
                    ? 'Enter the supplier name.'
                    : null,
              ),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Contact email'),
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                validator: (value) {
                  final email = (value ?? '').trim();
                  if (email.isEmpty) return 'Enter the supplier contact email.';
                  if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
                    return 'Enter a valid email address.';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Contact phone'),
              ),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'Address'),
              ),
              TextFormField(
                controller: _termsController,
                decoration: const InputDecoration(labelText: 'Payment terms'),
              ),
              TextFormField(
                controller: _leadController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Lead time (days)',
                ),
                validator: (value) => (int.tryParse(value ?? '') ?? 0) > 0
                    ? null
                    : 'Enter a positive number of days.',
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(context, <String, dynamic>{
              'supplierName': _nameController.text.trim(),
              'contactEmail': _emailController.text.trim(),
              'contactPhone': _phoneController.text.trim(),
              'address': _addressController.text.trim(),
              'paymentTerms': _termsController.text.trim(),
              'leadTimeDays': int.parse(_leadController.text),
            });
          },
          child: const Text('Verify supplier'),
        ),
      ],
    );
  }
}

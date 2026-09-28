import 'dart:async';
import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../models/quality_models.dart';
import '../services/api_client.dart';
import '../services/quality_service.dart';

class AiValidationScreen extends StatefulWidget {
  const AiValidationScreen({
    required this.service,
    this.initialWorkflowId,
    super.key,
  });

  final QualityService service;
  final String? initialWorkflowId;

  @override
  State<AiValidationScreen> createState() => _AiValidationScreenState();
}

class _AiValidationScreenState extends State<AiValidationScreen> {
  static const _agentSteps = [
    'Agent Activated',
    'Preparing Assessment',
    'Checking PO',
    'Checking Supplier',
    'Checking Quality & Safety',
    'Checking Quarantine',
    'Assessment Complete',
  ];

  AiValidationData? _latestValidation;
  List<AiValidationData> _history = [];
  bool _loadingLatest = true;
  bool _loadingHistory = true;
  String? _error;
  String? _historyError;
  String? _successMessage;

  // Agent Activation Progress state
  bool _activatingAgent = false;
  int _activeStepIndex = 0;
  Timer? _stepTimer;

  // Filter for history
  String _historyFilter = 'ALL'; // ALL, BLOCKED, CLEAR, HIGH_IMPACT

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _stepTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAll() async {
    _loadLatest();
    _loadHistory();
  }

  Future<void> _loadLatest() async {
    setState(() {
      _loadingLatest = true;
      _error = null;
    });
    try {
      final result = await widget.service.getAiValidation(
        workflowId: widget.initialWorkflowId,
      );
      if (mounted) {
        setState(() {
          _latestValidation = result;
          _loadingLatest = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loadingLatest = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Unable to load AI Validation & Safety results.';
          _loadingLatest = false;
        });
      }
    }
  }

  Future<void> _loadHistory() async {
    setState(() {
      _loadingHistory = true;
      _historyError = null;
    });
    try {
      final historyList = await widget.service.getAiValidationHistory();
      if (mounted) {
        setState(() {
          _history = historyList;
          _loadingHistory = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _historyError = 'Unable to load validation history.';
          _loadingHistory = false;
        });
      }
    }
  }

  void _handleActivateAgent() {
    setState(() {
      _activatingAgent = true;
      _activeStepIndex = 0;
    });

    _stepTimer?.cancel();
    _stepTimer = Timer.periodic(const Duration(milliseconds: 400), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_activeStepIndex < _agentSteps.length - 1) {
        setState(() => _activeStepIndex++);
      } else {
        timer.cancel();
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            setState(() => _activatingAgent = false);
            _loadAll();
          }
        });
      }
    });
  }

  void _openResolveDialog(AiValidationData wf) {
    showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (_) => _ResolveWorkflowDialog(
        workflow: wf,
        onResolve: (note, releaseQuarantine) async {
          final res = await widget.service.resolveAiValidation(
            wf.workflowId,
            note: note,
            releaseQuarantine: releaseQuarantine,
          );
          if (mounted) {
            setState(() {
              _latestValidation = res;
              _successMessage =
                  'Workflow ${wf.workflowId} successfully resolved.';
            });
            Future.delayed(const Duration(seconds: 4), () {
              if (mounted) setState(() => _successMessage = null);
            });
            _loadAll();
          }
        },
      ),
    );
  }

  void _openAuditDialog(AiValidationData wf) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (_) => _AuditLedgerDialog(workflow: wf),
    );
  }

  @override
  Widget build(BuildContext context) {
    final historyStats = _computeHistoryStats();
    final filteredHistory = _filterHistoryList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Validation & Safety'),
        leading: BackButton(onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(
            onPressed: _loadingLatest || _loadingHistory ? null : _loadAll,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAll,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 36),
          children: [
            // 1. Single Page Header
            _buildPageHeader(),
            const SizedBox(height: 16),

            // Success banner
            if (_successMessage != null) ...[
              _buildSuccessBanner(_successMessage!),
              const SizedBox(height: 16),
            ],

            // Stepped progress indicator during agent activation
            if (_activatingAgent) ...[
              _buildAgentProgressStepper(),
              const SizedBox(height: 16),
            ],

            // 2. Latest Validation & Safety Assessment
            _buildLatestAssessmentSection(),
            const SizedBox(height: 24),

            // 3. History Monitoring Summary (4 Stat Cards)
            _buildHistorySummaryCards(historyStats),
            const SizedBox(height: 24),

            // 4. Validation & Safety Audit History Ledger
            _buildHistoryLedgerSection(filteredHistory),
          ],
        ),
      ),
    );
  }

  Widget _buildPageHeader() => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF161B2E), Color(0xFF0F1523)],
      ),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFF2A3958), width: 1.2),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.25),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'QUALITY CONTROL',
              style: TextStyle(
                color: AppColors.primaryLight,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 4,
              height: 4,
              decoration: const BoxDecoration(
                color: AppColors.mutedText,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _activatingAgent || _loadingLatest
                    ? AppColors.warning
                    : const Color(0xFF10B981),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              _activatingAgent || _loadingLatest ? 'Processing' : 'Agent Ready',
              style: const TextStyle(
                color: AppColors.secondaryText,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'AI Validation & Safety',
          style: TextStyle(
            color: AppColors.strongText,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Authoritative quality assurance ledger: Multi-agent validation rules and physical quarantine safety gates.',
          style: TextStyle(
            color: AppColors.mutedText,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _activatingAgent || _loadingLatest
                    ? null
                    : _handleActivateAgent,
                icon: _activatingAgent
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.smart_toy_outlined, size: 18),
                label: const Text(
                  'Activate Agent',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton.icon(
              onPressed: _loadingLatest || _loadingHistory ? null : _loadAll,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Refresh'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.secondaryText,
                side: const BorderSide(color: Color(0xFF2A3958)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _buildSuccessBanner(String message) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFF10B981).withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: const Color(0xFF10B981).withValues(alpha: 0.4),
      ),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.check_circle_rounded,
          color: Color(0xFF10B981),
          size: 20,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(
              color: Color(0xFFD1FAE5),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildAgentProgressStepper() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFF0F172A),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: AppColors.primary.withValues(alpha: 0.5),
        width: 1.5,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.smart_toy_rounded,
                  color: AppColors.primaryLight,
                  size: 18,
                ),
                SizedBox(width: 8),
                Text(
                  'Pipeline Executing',
                  style: TextStyle(
                    color: AppColors.strongText,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            Text(
              'Step ${_activeStepIndex + 1} of ${_agentSteps.length}',
              style: const TextStyle(
                color: AppColors.primaryLight,
                fontSize: 11,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LinearProgressIndicator(
          value: (_activeStepIndex + 1) / _agentSteps.length,
          backgroundColor: const Color(0xFF1E293B),
          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
          minHeight: 6,
          borderRadius: BorderRadius.circular(4),
        ),
        const SizedBox(height: 8),
        Text(
          _agentSteps[_activeStepIndex],
          style: const TextStyle(
            color: AppColors.primaryLight,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );

  Widget _buildLatestAssessmentSection() {
    if (_loadingLatest) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        decoration: _cardBoxDecoration(),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(strokeWidth: 2.5),
            SizedBox(height: 12),
            Text(
              'Fetching authoritative assessment...',
              style: TextStyle(color: AppColors.mutedText, fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (_error != null && _latestValidation == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.error.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.errorText),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _error!,
                style: const TextStyle(
                  color: AppColors.errorText,
                  fontSize: 13,
                ),
              ),
            ),
            TextButton(onPressed: _loadLatest, child: const Text('Retry')),
          ],
        ),
      );
    }

    final wf = _latestValidation;
    if (wf == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        decoration: _cardBoxDecoration(),
        child: const Column(
          children: [
            Icon(
              Icons.shield_outlined,
              size: 40,
              color: AppColors.mutedText,
            ),
            SizedBox(height: 8),
            Text(
              'No assessment available',
              style: TextStyle(
                color: AppColors.strongText,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'The API did not return an active agent assessment.',
              style: TextStyle(color: AppColors.mutedText, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardBoxDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Authoritative Header Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'AUTHORITATIVE RECORD',
                          style: TextStyle(
                            color: AppColors.primaryLight,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 3,
                          height: 3,
                          decoration: const BoxDecoration(
                            color: AppColors.mutedText,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'PO: ${wf.poReference}',
                            style: const TextStyle(
                              color: AppColors.strongText,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'monospace',
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Latest Validation & Safety Assessment',
                      style: TextStyle(
                        color: AppColors.strongText,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Dual-layer verification: Automated AI rule diagnostics vs. Authoritative QA Safety Gate',
                      style: TextStyle(
                        color: AppColors.mutedText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Metadata badges row
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildMiniMeta('Workflow', wf.workflowId),
              _buildMiniMeta('PO', wf.poReference),
              _buildMiniMeta('Status', wf.status),
              if (wf.resolvedAt != null)
                _buildMiniMeta('Assessed', _formatDate(wf.resolvedAt!)),
            ],
          ),
          const SizedBox(height: 16),

          // Action: Review & Resolve (If needed)
          if (wf.needsReview) ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _openResolveDialog(wf),
                icon: const Icon(Icons.verified_user_outlined, size: 18),
                label: const Text('Review & Resolve Safety Hold'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // SECTION 1: AUTOMATED VERIFICATION (4/4 Passed)
          _buildAutomatedVerificationCard(wf),
          const SizedBox(height: 14),

          // SECTION 2: SAFETY GATE (CLEAR / BLOCKED / RESOLVED)
          _buildSafetyGateCard(wf),
          const SizedBox(height: 14),

          // SECTION 3 & 4: DUAL ASSESSMENT (ORIGINAL AI vs CURRENT QA)
          _buildDualAssessmentSection(wf),
        ],
      ),
    );
  }

  Widget _buildMiniMeta(String label, String value) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xFF0B0F19),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xFF1E293B)),
    ),
    child: Text(
      '$label: $value',
      style: const TextStyle(
        color: AppColors.secondaryText,
        fontSize: 10,
        fontWeight: FontWeight.w600,
        fontFamily: 'monospace',
      ),
    ),
  );

  Widget _buildAutomatedVerificationCard(AiValidationData wf) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0B0F19),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.4),
                      ),
                    ),
                    child: const Text(
                      '1',
                      style: TextStyle(
                        color: AppColors.primaryLight,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Automated Verification',
                        style: TextStyle(
                          color: AppColors.strongText,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Multi-agent mathematical & policy rules',
                        style: TextStyle(
                          color: AppColors.mutedText,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: wf.allAutomatedPassed
                      ? const Color(0xFF10B981).withValues(alpha: 0.15)
                      : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: wf.allAutomatedPassed
                        ? const Color(0xFF10B981).withValues(alpha: 0.4)
                        : const Color(0xFFF59E0B).withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  wf.automatedSummary,
                  style: TextStyle(
                    color: wf.allAutomatedPassed
                        ? const Color(0xFF34D399)
                        : const Color(0xFFFBBF24),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 2.2,
            children: wf.automatedCheckItems.map((c) {
              return Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF111827),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF1F2937)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            c.name,
                            style: const TextStyle(
                              color: AppColors.mutedText,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        _buildCheckBadge(c),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      c.value ?? 'Not available',
                      style: const TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 10,
                        fontFamily: 'monospace',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckBadge(ValidationCheckItem check) {
    if (!check.isAvailable) {
      return const Text(
        'N/A',
        style: TextStyle(color: AppColors.mutedText, fontSize: 9),
      );
    }
    final color = check.isPassed
        ? const Color(0xFF34D399)
        : check.isFailed
        ? AppColors.error
        : const Color(0xFFFBBF24);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        check.displayLabel,
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.w800,
          fontFamily: 'monospace',
        ),
      ),
    );
  }

  Widget _buildSafetyGateCard(AiValidationData wf) {
    final isBlocked = wf.isSafetyBlocked;
    final isResolved = wf.safetyGateState == 'RESOLVED';
    final isClear = wf.safetyGateState == 'CLEAR';

    final gateColor = isBlocked
        ? AppColors.error
        : (isResolved || isClear)
        ? const Color(0xFF10B981)
        : AppColors.mutedText;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isBlocked
            ? const Color(0xFF450A0A).withValues(alpha: 0.3)
            : isResolved || isClear
            ? const Color(0xFF064E3B).withValues(alpha: 0.25)
            : const Color(0xFF0B0F19),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: gateColor.withValues(alpha: 0.4),
          width: 1.2,
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
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: gateColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: gateColor.withValues(alpha: 0.4),
                      ),
                    ),
                    child: const Text(
                      '2',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Safety Gate',
                        style: TextStyle(
                          color: AppColors.strongText,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Physical quarantine containment & roll gate',
                        style: TextStyle(
                          color: AppColors.mutedText,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: gateColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: gateColor.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: gateColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      wf.safetyGateState,
                      style: TextStyle(
                        color: gateColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Safety Gate Diagnostic Reason:',
            style: TextStyle(
              color: AppColors.mutedText,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF0B0F19),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            child: Text(
              wf.impactReason ??
                  (isBlocked
                      ? 'Active fabric roll quarantine holds detected. Order approval is BLOCKED until Quality Inspector manual review and resolution.'
                      : isResolved
                      ? 'Safety hold was reviewed and released by Quality Inspector.'
                      : isClear
                      ? 'No active quarantine holds or defect alerts on fabric inventory. Safety gate is CLEAR.'
                      : 'Not available'),
              style: TextStyle(
                color: isBlocked
                    ? const Color(0xFFFECDD3)
                    : AppColors.primaryText,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDualAssessmentSection(AiValidationData wf) {
    return Column(
      children: [
        // 3. Original AI Assessment Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF0B0F19),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF1E293B)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.4),
                          ),
                        ),
                        child: const Text(
                          '3',
                          style: TextStyle(
                            color: AppColors.primaryLight,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Original AI Assessment',
                            style: TextStyle(
                              color: AppColors.strongText,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'Strictly preserved historical determination',
                            style: TextStyle(
                              color: AppColors.mutedText,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111827),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF374151)),
                    ),
                    child: const Text(
                      'Audit Preserved',
                      style: TextStyle(
                        color: AppColors.mutedText,
                        fontSize: 9,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 2.1,
                children: [
                  _buildStatTile(
                    'Validation Outcome',
                    wf.origAiOutcome,
                    wf.origAiOutcome == 'VALID'
                        ? const Color(0xFF34D399)
                        : wf.origAiOutcome == 'INVALID'
                        ? AppColors.error
                        : AppColors.mutedText,
                    'Initial AI agent finding',
                  ),
                  _buildStatTile(
                    'Quality Safety Status',
                    wf.origSafetyStatus,
                    wf.origSafetyStatus == 'CLEAR'
                        ? const Color(0xFF34D399)
                        : wf.origSafetyStatus.contains('QUARANTINE')
                        ? AppColors.error
                        : AppColors.mutedText,
                    'Original safety flag',
                  ),
                  _buildStatTile(
                    'Quarantined Rolls',
                    wf.quarantinedRollsDisplay,
                    (wf.quarantinedRollsCount ?? 0) > 0
                        ? AppColors.error
                        : AppColors.secondaryText,
                    'Flagged for inspection',
                  ),
                  _buildStatTile(
                    'High Impact',
                    wf.highImpactDisplay,
                    wf.isHighImpact == true
                        ? const Color(0xFFFBBF24)
                        : AppColors.mutedText,
                    'Production priority flag',
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 4. Current QA Resolution Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF0B0F19),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF1E293B)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.4),
                          ),
                        ),
                        child: const Text(
                          '4',
                          style: TextStyle(
                            color: AppColors.primaryLight,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Current QA Resolution',
                            style: TextStyle(
                              color: AppColors.strongText,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'Live manual inspector disposition & release',
                            style: TextStyle(
                              color: AppColors.mutedText,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: wf.currentManualResolution == 'RESOLVED'
                          ? const Color(0xFF10B981).withValues(alpha: 0.15)
                          : wf.currentManualResolution == 'PENDING REVIEW'
                          ? AppColors.error.withValues(alpha: 0.15)
                          : const Color(0xFF1F2937),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: wf.currentManualResolution == 'RESOLVED'
                            ? const Color(0xFF10B981).withValues(alpha: 0.4)
                            : wf.currentManualResolution == 'PENDING REVIEW'
                            ? AppColors.error.withValues(alpha: 0.4)
                            : const Color(0xFF374151),
                      ),
                    ),
                    child: Text(
                      wf.currentManualResolution,
                      style: TextStyle(
                        color: wf.currentManualResolution == 'RESOLVED'
                            ? const Color(0xFF34D399)
                            : wf.currentManualResolution == 'PENDING REVIEW'
                            ? AppColors.error
                            : AppColors.secondaryText,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (wf.currentManualResolution == 'RESOLVED') ...[
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 2.1,
                  children: [
                    _buildStatTile(
                      'Manual Resolution',
                      'RESOLVED',
                      const Color(0xFF34D399),
                      'Inspector authorized',
                    ),
                    _buildStatTile(
                      'Quarantine Disposition',
                      'RELEASED',
                      const Color(0xFF34D399),
                      'Inventory unblocked',
                    ),
                    _buildStatTile(
                      'Resolved By',
                      wf.resolvedBy ?? 'Quality Inspector',
                      AppColors.strongText,
                      'QA authorization',
                    ),
                    _buildStatTile(
                      'Resolved At',
                      wf.resolvedAt != null
                          ? _formatDate(wf.resolvedAt!)
                          : 'Recent',
                      AppColors.secondaryText,
                      'Time of sign-off',
                    ),
                  ],
                ),
                if (wf.manualResolutionNote != null &&
                    wf.manualResolutionNote!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Inspector Resolution Note:',
                          style: TextStyle(
                            color: AppColors.primaryLight,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '"${wf.manualResolutionNote}"',
                          style: const TextStyle(
                            color: AppColors.strongText,
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ] else if (wf.currentManualResolution == 'PENDING REVIEW') ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Physical inspection or lab certification is required to clear active quarantine hold.',
                        style: TextStyle(
                          color: Color(0xFFFECDD3),
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 10),
                      FilledButton.icon(
                        onPressed: () => _openResolveDialog(wf),
                        icon: const Icon(
                          Icons.verified_user_outlined,
                          size: 16,
                        ),
                        label: const Text('Authorize Manual Resolution'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111827),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'No active quarantine holds or defect containment on this order. Manual review is not required.',
                    style: TextStyle(
                      color: AppColors.mutedText,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatTile(
    String label,
    String value,
    Color valueColor,
    String subtitle,
  ) => Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: const Color(0xFF111827),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFF1F2937)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: AppColors.mutedText,
            fontSize: 9,
            fontWeight: FontWeight.w700,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 13,
            fontWeight: FontWeight.w900,
            fontFamily: 'monospace',
          ),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 1),
        Text(
          subtitle,
          style: const TextStyle(color: Color(0xFF6B7280), fontSize: 8),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    ),
  );

  Widget _buildHistorySummaryCards(_HistoryStats stats) => GridView.count(
    crossAxisCount: 2,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    crossAxisSpacing: 10,
    mainAxisSpacing: 10,
    childAspectRatio: 1.7,
    children: [
      _buildSummaryCard(
        'Persisted Runs',
        '${stats.total}',
        AppColors.strongText,
        'Total audited workflows',
      ),
      _buildSummaryCard(
        'Clear Safety Runs',
        '${stats.clear}',
        const Color(0xFF34D399),
        'No quarantine holds',
      ),
      _buildSummaryCard(
        'Quarantine Audits',
        '${stats.blocked}',
        AppColors.error,
        'Triggered / Resolved holds',
      ),
      _buildSummaryCard(
        'High Impact',
        '${stats.highImpact}',
        const Color(0xFFFBBF24),
        'Production critical items',
      ),
    ],
  );

  Widget _buildSummaryCard(
    String label,
    String count,
    Color countColor,
    String subtitle,
  ) => Container(
    padding: const EdgeInsets.all(12),
    decoration: _cardBoxDecoration(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: AppColors.mutedText,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          count,
          style: TextStyle(
            color: countColor,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: const TextStyle(color: AppColors.mutedText, fontSize: 9),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    ),
  );

  Widget _buildHistoryLedgerSection(List<AiValidationData> items) => Container(
    padding: const EdgeInsets.all(18),
    decoration: _cardBoxDecoration(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Validation & Safety Audit History',
                  style: TextStyle(
                    color: AppColors.strongText,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Persisted audit ledger tracking Original AI vs. QA Resolutions',
                  style: TextStyle(color: AppColors.mutedText, fontSize: 11),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.35),
                ),
              ),
              child: Text(
                '${_history.length} Runs',
                style: const TextStyle(
                  color: AppColors.primaryLight,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Filter chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _filterChip('ALL', 'All'),
              _filterChip('BLOCKED', 'Safety Holds'),
              _filterChip('CLEAR', 'Clear Runs'),
              _filterChip('HIGH_IMPACT', 'High Impact'),
            ],
          ),
        ),
        const SizedBox(height: 14),

        if (_loadingHistory)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_historyError != null)
          Text(
            _historyError!,
            style: const TextStyle(color: AppColors.errorText, fontSize: 12),
          )
        else if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Text(
                'No historical records match this filter.',
                style: TextStyle(color: AppColors.mutedText, fontSize: 12),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = items[index];
              final isBlocked = item.isSafetyBlocked;
              final isResolved = item.safetyGateState == 'RESOLVED';
              final isClear = item.safetyGateState == 'CLEAR';

              final gateColor = isBlocked
                  ? AppColors.error
                  : (isResolved || isClear)
                  ? const Color(0xFF10B981)
                  : AppColors.mutedText;

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0B0F19),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF1E293B)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            item.workflowId,
                            style: const TextStyle(
                              color: AppColors.primaryLight,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'monospace',
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: gateColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: gateColor.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Text(
                            'Gate: ${item.safetyGateState}',
                            style: TextStyle(
                              color: gateColor,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'PO: ${item.poReference}',
                            style: const TextStyle(
                              color: AppColors.strongText,
                              fontSize: 11,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Original: ${item.origAiOutcome}',
                            style: TextStyle(
                              color: item.origAiOutcome == 'VALID'
                                  ? const Color(0xFF34D399)
                                  : item.origAiOutcome == 'INVALID'
                                  ? AppColors.error
                                  : AppColors.mutedText,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Checks: ${item.automatedSummary}',
                            style: const TextStyle(
                              color: AppColors.mutedText,
                              fontSize: 11,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'QA: ${item.currentManualResolution}',
                            style: TextStyle(
                              color: item.currentManualResolution == 'RESOLVED'
                                  ? const Color(0xFF34D399)
                                  : item.currentManualResolution ==
                                          'PENDING REVIEW'
                                  ? AppColors.error
                                  : AppColors.mutedText,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          item.resolvedAt != null
                              ? _formatDate(item.resolvedAt!)
                              : 'Audited',
                          style: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 10,
                            fontFamily: 'monospace',
                          ),
                        ),
                        Row(
                          children: [
                            if (item.needsReview) ...[
                              TextButton(
                                onPressed: () => _openResolveDialog(item),
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFF34D399),
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                ),
                                child: const Text(
                                  'Resolve',
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                              ),
                              const SizedBox(width: 4),
                            ],
                            OutlinedButton.icon(
                              onPressed: () => _openAuditDialog(item),
                              icon: const Icon(
                                Icons.visibility_outlined,
                                size: 14,
                              ),
                              label: const Text('View Audit'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primaryLight,
                                side: const BorderSide(
                                  color: Color(0xFF2A3958),
                                ),
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                textStyle: const TextStyle(fontSize: 11),
                              ),
                            ),
                          ],
                        ),
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

  Widget _filterChip(String id, String label) {
    final selected = _historyFilter == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _historyFilter = id),
        selectedColor: AppColors.primary.withValues(alpha: 0.3),
        backgroundColor: const Color(0xFF0B0F19),
        labelStyle: TextStyle(
          color: selected ? AppColors.primaryLight : AppColors.mutedText,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: selected ? AppColors.primary : const Color(0xFF1E293B),
          ),
        ),
      ),
    );
  }

  _HistoryStats _computeHistoryStats() {
    int clear = 0;
    int blocked = 0;
    int highImpact = 0;

    for (final item in _history) {
      if (item.safetyGateState == 'CLEAR') {
        clear++;
      } else if (item.safetyGateState == 'BLOCKED' ||
          item.safetyGateState == 'RESOLVED') {
        blocked++;
      }
      if (item.isHighImpact == true) {
        highImpact++;
      }
    }
    return _HistoryStats(
      total: _history.length,
      clear: clear,
      blocked: blocked,
      highImpact: highImpact,
    );
  }

  List<AiValidationData> _filterHistoryList() {
    switch (_historyFilter) {
      case 'BLOCKED':
        return _history
            .where(
              (h) =>
                  h.safetyGateState == 'BLOCKED' ||
                  h.safetyGateState == 'RESOLVED',
            )
            .toList();
      case 'CLEAR':
        return _history.where((h) => h.safetyGateState == 'CLEAR').toList();
      case 'HIGH_IMPACT':
        return _history.where((h) => h.isHighImpact == true).toList();
      default:
        return _history;
    }
  }

  BoxDecoration _cardBoxDecoration() => BoxDecoration(
    gradient: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF161B2E), Color(0xFF0F1523)],
    ),
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: const Color(0xFF2A3958), width: 1.2),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.25),
        blurRadius: 10,
        offset: const Offset(0, 4),
      ),
    ],
  );

  String _formatDate(String dateStr) {
    final parsed = DateTime.tryParse(dateStr);
    if (parsed == null) return dateStr;
    final local = parsed.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.month}/${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
  }
}

class _HistoryStats {
  const _HistoryStats({
    required this.total,
    required this.clear,
    required this.blocked,
    required this.highImpact,
  });

  final int total;
  final int clear;
  final int blocked;
  final int highImpact;
}

/// Dialog for Manual QA Review & Resolution
class _ResolveWorkflowDialog extends StatefulWidget {
  const _ResolveWorkflowDialog({
    required this.workflow,
    required this.onResolve,
  });

  final AiValidationData workflow;
  final Future<void> Function(String note, bool releaseQuarantine) onResolve;

  @override
  State<_ResolveWorkflowDialog> createState() => _ResolveWorkflowDialogState();
}

class _ResolveWorkflowDialogState extends State<_ResolveWorkflowDialog> {
  final _noteController = TextEditingController();
  bool _releaseQuarantine = true;
  bool _resolving = false;
  String? _error;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final note = _noteController.text.trim();
    if (note.isEmpty) {
      setState(() => _error = 'A manual resolution note is required.');
      return;
    }
    setState(() {
      _resolving = true;
      _error = null;
    });
    try {
      await widget.onResolve(note, _releaseQuarantine);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _resolving = false;
          _error = 'Failed to submit manual resolution: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
    backgroundColor: Colors.transparent,
    child: Container(
      constraints: const BoxConstraints(maxWidth: 420),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2A3958), width: 1.4),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.verified_user_outlined,
                    color: AppColors.primaryLight,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Manual QA Review & Resolution',
                        style: TextStyle(
                          color: AppColors.strongText,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Workflow ${widget.workflow.workflowId}',
                        style: const TextStyle(
                          color: AppColors.mutedText,
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(
                    color: AppColors.errorText,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            const Text(
              'INSPECTOR RESOLUTION NOTE *',
              style: TextStyle(
                color: AppColors.mutedText,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _noteController,
              maxLines: 4,
              style: const TextStyle(color: AppColors.strongText, fontSize: 13),
              decoration: const InputDecoration(
                hintText:
                    'Describe physical inspection results, lab clearance, or mitigation authorizing release...',
                hintStyle: TextStyle(color: AppColors.mutedText, fontSize: 12),
              ),
            ),
            const SizedBox(height: 14),
            CheckboxListTile(
              value: _releaseQuarantine,
              onChanged: (val) =>
                  setState(() => _releaseQuarantine = val ?? true),
              contentPadding: EdgeInsets.zero,
              activeColor: AppColors.primary,
              title: const Text(
                'Release Quarantined Fabric Rolls',
                style: TextStyle(
                  color: AppColors.strongText,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: const Text(
                'Automatically unblock affected inventory rolls linked to this workflow.',
                style: TextStyle(color: AppColors.mutedText, fontSize: 11),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _resolving ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _resolving ? null : _submit,
                  icon: _resolving
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check, size: 16),
                  label: const Text('Authorize & Resolve'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

/// Dialog for Viewing Detailed Audit Ledger
class _AuditLedgerDialog extends StatelessWidget {
  const _AuditLedgerDialog({required this.workflow});

  final AiValidationData workflow;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 460),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF2A3958), width: 1.4),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Validation Audit Ledger',
                    style: TextStyle(
                      color: AppColors.strongText,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 18),
                    color: AppColors.mutedText,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              Text(
                'Workflow: ${workflow.workflowId} • PO: ${workflow.poReference}',
                style: const TextStyle(
                  color: AppColors.primaryLight,
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
              ),
              const Divider(height: 20, color: Color(0xFF1E293B)),

              // 1. Automated Verification
              _buildSectionTitle('1. Automated Verification Checks'),
              const SizedBox(height: 6),
              ...workflow.automatedCheckItems.map(
                (c) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        c.name,
                        style: const TextStyle(
                          color: AppColors.mutedText,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        c.displayLabel,
                        style: TextStyle(
                          color: c.isPassed
                              ? const Color(0xFF34D399)
                              : c.isFailed
                              ? AppColors.error
                              : const Color(0xFFFBBF24),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 20, color: Color(0xFF1E293B)),

              // 2. Safety Gate
              _buildSectionTitle('2. Safety Gate'),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Gate Status',
                    style: TextStyle(color: AppColors.mutedText, fontSize: 12),
                  ),
                  Text(
                    workflow.safetyGateState,
                    style: TextStyle(
                      color: workflow.isSafetyBlocked
                          ? AppColors.error
                          : const Color(0xFF34D399),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
              if (workflow.impactReason != null) ...[
                const SizedBox(height: 4),
                Text(
                  workflow.impactReason!,
                  style: const TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 11,
                  ),
                ),
              ],
              const Divider(height: 20, color: Color(0xFF1E293B)),

              // 3. Original AI Assessment
              _buildSectionTitle('3. Original AI Assessment (Preserved)'),
              const SizedBox(height: 6),
              _rowKV('Validation Outcome', workflow.origAiOutcome),
              _rowKV('Quality Safety Status', workflow.origSafetyStatus),
              _rowKV('Quarantined Rolls', workflow.quarantinedRollsDisplay),
              _rowKV('High Impact', workflow.highImpactDisplay),
              const Divider(height: 20, color: Color(0xFF1E293B)),

              // 4. Current QA Resolution
              _buildSectionTitle('4. Current QA Resolution'),
              const SizedBox(height: 6),
              _rowKV('Manual QA State', workflow.currentManualResolution),
              _rowKV(
                'Quarantine Disposition',
                workflow.currentQuarantineDisposition,
              ),
              if (workflow.resolvedBy != null)
                _rowKV('Inspector', workflow.resolvedBy!),
              if (workflow.resolvedAt != null)
                _rowKV('Resolved At', workflow.resolvedAt!),
              if (workflow.manualResolutionNote != null &&
                  workflow.manualResolutionNote!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111827),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '"${workflow.manualResolutionNote}"',
                    style: const TextStyle(
                      color: AppColors.strongText,
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close Audit'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) => Text(
    title,
    style: const TextStyle(
      color: AppColors.strongText,
      fontSize: 13,
      fontWeight: FontWeight.w800,
    ),
  );

  Widget _rowKV(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2.5),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          k,
          style: const TextStyle(color: AppColors.mutedText, fontSize: 12),
        ),
        Text(
          v,
          style: const TextStyle(
            color: AppColors.strongText,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            fontFamily: 'monospace',
          ),
        ),
      ],
    ),
  );
}

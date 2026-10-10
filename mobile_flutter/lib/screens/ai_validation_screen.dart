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
    this.showAppBar = true,
    super.key,
  });

  final QualityService service;
  final String? initialWorkflowId;
  final bool showAppBar;

  @override
  State<AiValidationScreen> createState() => _AiValidationScreenState();
}

class _AiValidationScreenState extends State<AiValidationScreen> {
  AiValidationData? _latestValidation;
  List<AiValidationData> _history = [];
  bool _loadingLatest = true;
  bool _loadingHistory = true;
  String? _error;
  String? _historyError;
  String? _successMessage;

  // Filter for history
  String _historyFilter = 'ALL'; // ALL, VALID, FAILED, HIGH_IMPACT

  @override
  void initState() {
    super.initState();
    _loadAll();
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
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text('AI Validation & Safety'),
              leading: BackButton(onPressed: () => Navigator.pop(context)),
              actions: [
                IconButton(
                  onPressed: _loadingLatest || _loadingHistory ? null : _loadAll,
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Refresh',
                ),
              ],
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _loadAll,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 36),
          children: [
            // 1. Single Responsive Ledger Card
            _buildPageHeader(),
            const SizedBox(height: 16),

            // Success banner
            if (_successMessage != null) ...[
              _buildSuccessBanner(_successMessage!),
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
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
      ),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: const Color(0xFF38BDF8).withValues(alpha: 0.3),
        width: 1.2,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.3),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ],
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
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.auto_awesome, color: Color(0xFF38BDF8), size: 18),
                ),
                const SizedBox(width: 10),
                const Text(
                  'AI Safety Ledger',
                  style: TextStyle(
                    color: AppColors.strongText,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: (_loadingLatest || _loadingHistory)
                    ? AppColors.warning.withValues(alpha: 0.15)
                    : const Color(0xFF10B981).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: (_loadingLatest || _loadingHistory)
                      ? AppColors.warning.withValues(alpha: 0.35)
                      : const Color(0xFF10B981).withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: (_loadingLatest || _loadingHistory)
                          ? AppColors.warning
                          : const Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    (_loadingLatest || _loadingHistory) ? 'Syncing...' : 'Live Gate Active',
                    style: TextStyle(
                      color: (_loadingLatest || _loadingHistory)
                          ? AppColors.warning
                          : const Color(0xFF34D399),
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const Text(
          'Authoritative QA ledger: Autonomous replenishment safety gates and multi-agent compliance rules.',
          style: TextStyle(
            color: AppColors.mutedText,
            fontSize: 11.5,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            onPressed: _loadingLatest || _loadingHistory ? null : _loadAll,
            icon: _loadingLatest || _loadingHistory
                ? const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.mutedText),
                  )
                : const Icon(Icons.refresh_rounded, size: 14),
            label: const Text('Refresh Ledger', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF38BDF8),
              side: const BorderSide(color: Color(0xFF1E293B)),
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
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
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 2,
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
                        Container(
                          width: 3,
                          height: 3,
                          decoration: const BoxDecoration(
                            color: AppColors.mutedText,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Text(
                          'PO: ${wf.poReference}',
                          style: const TextStyle(
                            color: AppColors.strongText,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'monospace',
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Latest Validation Assessment',
                      style: TextStyle(
                        color: AppColors.strongText,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Multi-agent mathematical and policy rule verification',
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

          // AUTOMATED VERIFICATION CHECKS
          _buildAutomatedVerificationCard(wf),
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
              Expanded(
                child: Row(
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
                      child: const Icon(
                        Icons.fact_check_outlined,
                        size: 13,
                        color: AppColors.primaryLight,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Automated Verification',
                            style: TextStyle(
                              color: AppColors.strongText,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Multi-agent mathematical & policy rules',
                            style: TextStyle(
                              color: AppColors.mutedText,
                              fontSize: 10,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
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
            childAspectRatio: 2.0,
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
                        const SizedBox(width: 4),
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

  Widget _buildHistorySummaryCards(_HistoryStats stats) => GridView.count(
    crossAxisCount: 2,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    crossAxisSpacing: 8,
    mainAxisSpacing: 8,
    childAspectRatio: 1.55,
    children: [
      _buildSummaryCard(
        'Total Audits',
        '${stats.total}',
        AppColors.strongText,
        'Total audited workflows',
      ),
      _buildSummaryCard(
        'Valid & Clear',
        '${stats.valid}',
        const Color(0xFF34D399),
        'Passed all 4 checks',
      ),
      _buildSummaryCard(
        'Discrepancies',
        '${stats.discrepancies}',
        AppColors.error,
        'Rule mismatches / fails',
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
    padding: const EdgeInsets.all(10),
    decoration: _cardBoxDecoration(),
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
          count,
          style: TextStyle(
            color: countColor,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            fontFamily: 'monospace',
          ),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 1),
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
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Validation Audit History',
                    style: TextStyle(
                      color: AppColors.strongText,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Persisted audit ledger tracking automated AI validation runs',
                    style: TextStyle(color: AppColors.mutedText, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
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
              _filterChip('VALID', 'Valid (4/4)'),
              _filterChip('FAILED', 'Discrepancies'),
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
              final isValid = item.allAutomatedPassed;
              final statusColor = isValid
                  ? const Color(0xFF10B981)
                  : AppColors.error;

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
                            color: statusColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: statusColor.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Text(
                            isValid ? 'VALID (4/4)' : 'DISCREPANCY',
                            style: TextStyle(
                              color: isValid
                                  ? const Color(0xFF34D399)
                                  : AppColors.error,
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
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Outcome: ${item.origAiOutcome}',
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
                            overflow: TextOverflow.ellipsis,
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
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
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
    int valid = 0;
    int discrepancies = 0;
    int highImpact = 0;

    for (final item in _history) {
      if (item.allAutomatedPassed) {
        valid++;
      } else {
        discrepancies++;
      }
      if (item.isHighImpact == true) {
        highImpact++;
      }
    }
    return _HistoryStats(
      total: _history.length,
      valid: valid,
      discrepancies: discrepancies,
      highImpact: highImpact,
    );
  }

  List<AiValidationData> _filterHistoryList() {
    switch (_historyFilter) {
      case 'VALID':
        return _history.where((h) => h.allAutomatedPassed).toList();
      case 'FAILED':
        return _history.where((h) => !h.allAutomatedPassed).toList();
      case 'HIGH_IMPACT':
        return _history.where((h) => h.isHighImpact == true).toList();
      default:
        return _history;
    }
  }

  BoxDecoration _cardBoxDecoration() => BoxDecoration(
    color: const Color(0xFF0F172A),
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: const Color(0xFF1E293B), width: 1.2),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.3),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ],
  );

  String _formatDate(String dateStr) {
    final parsed = DateTime.tryParse(dateStr);
    if (parsed == null) return dateStr;
    final local = parsed.toUtc().add(const Duration(hours: 5, minutes: 30));
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.month}/${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
  }
}

class _HistoryStats {
  const _HistoryStats({
    required this.total,
    required this.valid,
    required this.discrepancies,
    required this.highImpact,
  });

  final int total;
  final int valid;
  final int discrepancies;
  final int highImpact;
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
          border: Border.all(color: const Color(0xFF1E293B), width: 1.4),
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

              // Automated Verification Checks
              const Text(
                'Automated Verification Checks',
                style: TextStyle(
                  color: AppColors.strongText,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              ...workflow.automatedCheckItems.map(
                (c) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          c.name,
                          style: const TextStyle(
                            color: AppColors.mutedText,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
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
}

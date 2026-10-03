import 'dart:async';
import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../models/quality_models.dart';
import '../services/api_client.dart';
import '../services/inventory_api_service.dart';
import '../services/quality_service.dart';

class DefectFormScreen extends StatefulWidget {
  const DefectFormScreen({required this.service, this.defect, super.key});

  final QualityService service;
  final DefectReport? defect;

  @override
  State<DefectFormScreen> createState() => _DefectFormScreenState();
}

class _DefectFormScreenState extends State<DefectFormScreen> {
  static const _severities = ['LOW', 'MEDIUM', 'HIGH', 'Critical'];
  static const _statuses = ['Open', 'InReview', 'Resolved', 'Closed'];
  static const _agentProgressSteps = [
    'Agent Activated',
    'Analyzing Defect Context',
    'Inspecting Related Inventory Rolls',
    'Evaluating Quarantine Thresholds',
    'Generating Roll Recommendations',
    'Assessment Complete',
  ];

  final _formKey = GlobalKey<FormState>();
  final _description = TextEditingController();
  final _inventory = InventoryApiService();

  List<InventoryItemModel> _items = [];
  List<RawMaterialModel> _materials = [];
  List<InventoryRollModel> _rolls = [];
  String? _skuCode;
  String _severity = 'LOW';
  String _status = 'Open';
  Set<String> _selectedRolls = {};

  bool _loadingInventory = true;
  bool _saving = false;
  bool _analyzing = false;
  int _aiStepIndex = 0;
  Timer? _stepTimer;
  String? _error;
  String? _aiError;
  QualityRecommendation? _recommendation;

  bool get _isEditing => widget.defect != null;

  List<RawMaterialModel> get _createdMaterials {
    final materialBySku = {
      for (final material in _materials)
        material.skuCode.trim().toLowerCase(): material,
    };
    final seen = <String>{};
    return _items
        .where((item) => seen.add(item.sku.trim().toLowerCase()))
        .map((item) {
          final material = materialBySku[item.sku.trim().toLowerCase()];
          if (material == null) return null;
          return RawMaterialModel(
            id: material.id,
            skuCode: item.sku.trim(),
            name: item.name.isEmpty ? material.name : item.name,
            category: material.category,
            unitOfMeasure: material.unitOfMeasure,
            reorderThreshold: material.reorderThreshold,
          );
        })
        .whereType<RawMaterialModel>()
        .toList();
  }

  RawMaterialModel? get _selectedMaterial => _createdMaterials
      .where((material) => material.skuCode == _skuCode)
      .firstOrNull;

  List<InventoryRollModel> get _skuRolls => _rolls
      .where((roll) => roll.rawMaterialId == _selectedMaterial?.id)
      .toList();

  @override
  void initState() {
    super.initState();
    _description.text = widget.defect?.description ?? '';
    _severity = widget.defect?.severity ?? 'LOW';
    _status = widget.defect?.status ?? 'Open';
    _loadInventory();
  }

  @override
  void dispose() {
    _stepTimer?.cancel();
    _description.dispose();
    super.dispose();
  }

  Future<void> _loadInventory() async {
    try {
      final results = await Future.wait([
        _inventory.fetchOwnedInventory(),
        _inventory.fetchRawMaterials(),
        _inventory.fetchOwnedRolls(),
      ]);
      if (!mounted) return;
      setState(() {
        _items = results[0] as List<InventoryItemModel>;
        _materials = results[1] as List<RawMaterialModel>;
        _rolls = results[2] as List<InventoryRollModel>;
        _loadingInventory = false;
      });
      await _restoreDefectSelection();
    } on ApiException catch (exception) {
      if (mounted) {
        setState(() {
          _error = exception.message;
          _loadingInventory = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Unable to load FloorWorker inventory.';
          _loadingInventory = false;
        });
      }
    }
  }

  Future<void> _restoreDefectSelection() async {
    final defect = widget.defect;
    if (defect == null) return;
    final affected = defect.affectedInventory.toSet();
    final roll = _rolls.where((item) => affected.contains(item.id)).firstOrNull;
    final material = _materials
        .where((item) => item.id == roll?.rawMaterialId)
        .firstOrNull;
    if (!mounted) return;
    setState(() {
      _skuCode = material?.skuCode ?? defect.skuCode;
      _selectedRolls = affected;
    });
  }

  Future<void> _selectSku(String? sku) async {
    setState(() {
      _skuCode = sku;
      _selectedRolls = {};
      _recommendation = null;
      _aiError = null;
    });
  }

  String? _validate({required bool requireRolls}) {
    if (_skuCode == null || _skuCode!.isEmpty) {
      return 'Inventory roll SKU is required.';
    }
    if (requireRolls && _selectedRolls.isEmpty) {
      return 'Select at least one inventory roll or click "Activate Agent" to evaluate affected rolls.';
    }
    if (_description.text.trim().isEmpty) return 'Description is required.';
    return null;
  }

  Future<void> _activateAgent() async {
    final message = _validate(requireRolls: false);
    if (message != null) {
      setState(() => _aiError = message);
      return;
    }
    setState(() {
      _analyzing = true;
      _aiError = null;
      _aiStepIndex = 0;
    });

    _stepTimer?.cancel();
    _stepTimer = Timer.periodic(const Duration(milliseconds: 450), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_aiStepIndex < _agentProgressSteps.length - 1) {
        setState(() => _aiStepIndex++);
      }
    });

    try {
      final recommendation = await widget.service.analyzeDefect(
        skuCode: _skuCode,
        severity: _severity,
        description: _description.text.trim(),
        affectedInventory: _selectedRolls.toList(),
      );
      if (mounted) {
        setState(() {
          _recommendation = recommendation;
          // Auto-select recommended rolls
          if (recommendation.affectedInventory.isNotEmpty) {
            _selectedRolls = {
              ..._selectedRolls,
              ...recommendation.affectedInventory,
            };
          }
        });
      }
    } on ApiException catch (exception) {
      if (mounted) setState(() => _aiError = exception.message);
    } catch (_) {
      if (mounted) {
        setState(() => _aiError = 'Unable to complete AI defect analysis.');
      }
    } finally {
      _stepTimer?.cancel();
      if (mounted) {
        setState(() {
          _aiStepIndex = _agentProgressSteps.length - 1;
          _analyzing = false;
        });
      }
    }
  }

  Future<void> _save() async {
    final message = _validate(requireRolls: true);
    if (message != null) {
      setState(() => _error = message);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final values = _selectedRolls.toList();
      if (_isEditing) {
        await widget.service.updateDefect(
          id: widget.defect!.id,
          skuCode: _skuCode,
          severity: _severity,
          description: _description.text.trim(),
          status: _status,
          affectedInventory: values,
        );
      } else {
        await widget.service.createDefect(
          skuCode: _skuCode,
          severity: _severity,
          description: _description.text.trim(),
          status: _status,
          affectedInventory: values,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (exception) {
      if (mounted) setState(() => _error = exception.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedMaterial = _selectedMaterial;
    final rolls = _skuRolls;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Defect Report' : 'Create Defect Report'),
        leading: BackButton(onPressed: () => Navigator.pop(context)),
      ),
      body: _loadingInventory
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 36),
                children: [
                  const Text(
                    'QUALITY ASSURANCE',
                    style: TextStyle(
                      color: AppColors.primaryLight,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isEditing ? 'Edit Defect Report' : 'Create Defect Report',
                    style: const TextStyle(
                      color: AppColors.strongText,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Record a manufacturing quality issue for investigation',
                    style: TextStyle(color: AppColors.mutedText, fontSize: 13),
                  ),
                  const SizedBox(height: 18),

                  if (_error != null) _errorAlert(_error!),
                  if (_aiError != null) _errorAlert(_aiError!),

                  // Form Container
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: _cardBoxDecoration(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _FormSelect<String>(
                          label: 'Inventory Roll',
                          value: _skuCode,
                          items: _createdMaterials
                              .map(
                                (material) => DropdownMenuItem<String>(
                                  value: material.skuCode,
                                  child: Text(
                                    '${material.skuCode} (${material.name})',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: _selectSku,
                          validator: (_) => _skuCode == null
                              ? 'Inventory roll is required.'
                              : null,
                        ),
                        const SizedBox(height: 14),

                        _FormFieldShell(
                          label: 'Raw Material',
                          child: Text(
                            selectedMaterial?.name ??
                                'Determined from selected inventory',
                            style: TextStyle(
                              color: selectedMaterial == null
                                  ? AppColors.mutedText
                                  : AppColors.strongText,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        Row(
                          children: [
                            Expanded(
                              child: _FormSelect<String>(
                                label: 'Severity',
                                value: _severity,
                                items: _severities
                                    .map(
                                      (value) => DropdownMenuItem(
                                        value: value,
                                        child: Text(value),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) =>
                                    setState(() => _severity = value!),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _FormSelect<String>(
                                label: 'Status',
                                value: _status,
                                items: _statuses
                                    .map(
                                      (value) => DropdownMenuItem(
                                        value: value,
                                        child: Text(value),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) =>
                                    setState(() => _status = value!),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        _DescriptionField(
                          controller: _description,
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Description is required.'
                              : null,
                        ),
                        const SizedBox(height: 16),

                        // Rolls Selection Checkbox List
                        if (_recommendation != null || _isEditing) ...[
                          const Divider(height: 24, color: Color(0xFF1E293B)),
                          const Text(
                            'Select Inventory Rolls',
                            style: TextStyle(
                              color: AppColors.strongText,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (rolls.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0B0F19),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'No current inventory rolls found for this SKU.',
                                style: TextStyle(
                                  color: AppColors.mutedText,
                                  fontSize: 12,
                                ),
                              ),
                            )
                          else
                            ...rolls.map((roll) {
                              final selected = _selectedRolls.contains(roll.id);
                              return Material(
                                color: Colors.transparent,
                                child: CheckboxListTile(
                                  value: selected,
                                  activeColor: AppColors.primary,
                                  onChanged: (val) => setState(() {
                                    if (val == true) {
                                      _selectedRolls.add(roll.id);
                                    } else {
                                      _selectedRolls.remove(roll.id);
                                    }
                                  }),
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    roll.rollIdentifier.isNotEmpty
                                        ? roll.rollIdentifier
                                        : roll.id,
                                    style: const TextStyle(
                                      color: Color(0xFF67E8F9),
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Raw Material: ${selectedMaterial?.name ?? ''} · ${roll.currentQuantity} / ${roll.initialQuantity} units — ${roll.status}',
                                    style: const TextStyle(
                                      color: AppColors.mutedText,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              );
                            }),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Stepped Progress Indicator during Agent Activation
                  if (_analyzing) ...[
                    _buildAgentProgressSection(),
                    const SizedBox(height: 16),
                  ],

                  // AI Recommendation Box (Exact format from React reference)
                  if (_recommendation != null && !_analyzing) ...[
                    _buildAiRecommendationBox(),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
      bottomNavigationBar: _loadingInventory
          ? null
          : Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                border: Border(top: BorderSide(color: Color(0xFF1E293B))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _saving || _analyzing ? null : _activateAgent,
                      icon: _analyzing
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primaryLight,
                              ),
                            )
                          : const Icon(
                              Icons.auto_awesome_outlined,
                              size: 18,
                              color: Color(0xFF67E8F9),
                            ),
                      label: const Text('Activate Agent'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryLight,
                        side: const BorderSide(
                          color: AppColors.primary,
                          width: 1.2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _saving || _analyzing ? null : _save,
                      icon: _saving
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save_outlined, size: 18),
                      label: Text(
                        _isEditing
                            ? 'Update Defect Report'
                            : 'Create Defect Report',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _errorAlert(String message) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.error.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.error.withValues(alpha: 0.35)),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.error_outline_rounded,
          color: AppColors.errorText,
          size: 18,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(color: AppColors.errorText, fontSize: 12),
          ),
        ),
      ],
    ),
  );

  Widget _buildAgentProgressSection() => Container(
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
                  'AI Defect Assessment Pipeline',
                  style: TextStyle(
                    color: AppColors.strongText,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            Text(
              'Step ${_aiStepIndex + 1} of ${_agentProgressSteps.length}',
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
          value: (_aiStepIndex + 1) / _agentProgressSteps.length,
          backgroundColor: const Color(0xFF1E293B),
          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
          minHeight: 6,
          borderRadius: BorderRadius.circular(4),
        ),
        const SizedBox(height: 8),
        Text(
          _agentProgressSteps[_aiStepIndex],
          style: const TextStyle(
            color: AppColors.primaryLight,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );

  Widget _buildAiRecommendationBox() {
    final rec = _recommendation!;
    final isQuarantine = rec.quarantineRequired;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.4),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.all(14),
            color: AppColors.primary.withValues(alpha: 0.15),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.smart_toy_outlined,
                    color: AppColors.primaryLight,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Defect Assessment',
                        style: TextStyle(
                          color: AppColors.strongText,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            color: Color(0xFF10B981),
                            size: 13,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Analysis completed',
                            style: TextStyle(
                              color: Color(0xFF34D399),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: isQuarantine
                        ? AppColors.error.withValues(alpha: 0.15)
                        : const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isQuarantine
                          ? AppColors.error.withValues(alpha: 0.4)
                          : const Color(0xFF10B981).withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    isQuarantine ? 'Active' : 'Released',
                    style: TextStyle(
                      color: isQuarantine
                          ? AppColors.error
                          : const Color(0xFF34D399),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 2 Metric Cards: Risk Level and Quarantine Required
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0B0F19),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF1E293B)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'RISK LEVEL',
                              style: TextStyle(
                                color: AppColors.mutedText,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              rec.riskLevel.toUpperCase(),
                              style: TextStyle(
                                color: rec.riskLevel.toUpperCase() == 'CRITICAL'
                                    ? AppColors.error
                                    : rec.riskLevel.toUpperCase() == 'HIGH'
                                    ? const Color(0xFFFB923C)
                                    : const Color(0xFFFBBF24),
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0B0F19),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF1E293B)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'QUARANTINE REQUIRED',
                              style: TextStyle(
                                color: AppColors.mutedText,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isQuarantine ? 'YES' : 'NO',
                              style: TextStyle(
                                color: isQuarantine
                                    ? const Color(0xFFFBBF24)
                                    : const Color(0xFF34D399),
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Affected Inventory Rolls
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Affected Inventory Rolls',
                      style: TextStyle(
                        color: AppColors.strongText,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${rec.affectedInventory.length} roll${rec.affectedInventory.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                        color: Color(0xFF67E8F9),
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Rolls returned by the AI assessment.',
                  style: TextStyle(color: AppColors.mutedText, fontSize: 11),
                ),
                const SizedBox(height: 8),

                if (rec.affectedInventory.isEmpty)
                  const Text(
                    'No affected rolls identified.',
                    style: TextStyle(color: AppColors.mutedText, fontSize: 12),
                  )
                else
                  ...rec.affectedInventory.map((rollId) {
                    final roll = _rolls
                        .where((r) => r.id == rollId)
                        .firstOrNull;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0B0F19),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF1E293B)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  roll?.rollIdentifier.isNotEmpty == true
                                      ? roll!.rollIdentifier
                                      : rollId,
                                  style: const TextStyle(
                                    color: Color(0xFF67E8F9),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                                Text(
                                  'Raw Material: ${_selectedMaterial?.name ?? ''} · ${roll?.currentQuantity ?? 0} / ${roll?.initialQuantity ?? 0} units',
                                  style: const TextStyle(
                                    color: AppColors.mutedText,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF111827),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              roll?.status ?? 'In Stock',
                              style: const TextStyle(
                                color: AppColors.primaryLight,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                const Divider(height: 20, color: Color(0xFF1E293B)),

                // Assessment Summary
                const Text(
                  'ASSESSMENT SUMMARY',
                  style: TextStyle(
                    color: AppColors.mutedText,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B0F19),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF1E293B)),
                  ),
                  child: Text(
                    rec.reason ??
                        'The AI assessment returned a ${rec.riskLevel} risk level and quarantine is ${isQuarantine ? 'required' : 'not required'}.',
                    style: const TextStyle(
                      color: AppColors.primaryText,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
}

class _FormFieldShell extends StatelessWidget {
  const _FormFieldShell({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
    decoration: BoxDecoration(
      color: const Color(0xFF0B1120),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFF1E293B), width: 1.2),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.mutedText,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 7),
        child,
      ],
    ),
  );
}

class _FormSelect<T> extends StatelessWidget {
  const _FormSelect({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.validator,
  });

  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final FormFieldValidator<T>? validator;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<T>(
    initialValue: value,
    isExpanded: true,
    items: items,
    onChanged: onChanged,
    validator: validator,
    style: const TextStyle(color: AppColors.strongText, fontSize: 14),
    dropdownColor: const Color(0xFF0F172A),
    iconEnabledColor: AppColors.mutedText,
    decoration: InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.mutedText, fontSize: 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      filled: true,
      fillColor: const Color(0xFF0B1120),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF1E293B), width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error),
      ),
    ),
  );
}

class _DescriptionField extends StatelessWidget {
  const _DescriptionField({required this.controller, required this.validator});

  final TextEditingController controller;
  final FormFieldValidator<String> validator;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    maxLines: 4,
    style: const TextStyle(color: AppColors.strongText, fontSize: 14),
    decoration: InputDecoration(
      labelText: 'Description',
      hintText:
          'Detail the observed imperfection, fabric distortion, batch anomalies...',
      hintStyle: const TextStyle(color: AppColors.mutedText, fontSize: 12),
      alignLabelWithHint: true,
      filled: true,
      fillColor: const Color(0xFF0B1120),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF1E293B), width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error),
      ),
    ),
    validator: validator,
  );
}

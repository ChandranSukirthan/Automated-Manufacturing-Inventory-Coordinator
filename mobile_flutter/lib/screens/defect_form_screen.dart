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
  int _analysisStatusIndex = 0;
  Timer? _analysisStatusTimer;
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
    _analysisStatusTimer?.cancel();
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
      _skuCode = material?.skuCode;
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
      return 'Inventory roll is required.';
    }
    if (requireRolls && _selectedRolls.isEmpty) {
      return 'Select at least one inventory roll.';
    }
    if (_description.text.trim().isEmpty) return 'Description is required.';
    return null;
  }

  Future<void> _analyzeWithAi() async {
    final message = _validate(requireRolls: false);
    if (message != null) {
      setState(() => _aiError = message);
      return;
    }
    setState(() {
      _analyzing = true;
      _aiError = null;
      _analysisStatusIndex = 0;
    });
    _analysisStatusTimer?.cancel();
    _analysisStatusTimer = Timer.periodic(const Duration(milliseconds: 1500), (
      timer,
    ) {
      if (!mounted || !_analyzing) {
        timer.cancel();
        return;
      }
      setState(() {
        _analysisStatusIndex = (_analysisStatusIndex + 1) % 3;
      });
    });
    try {
      final recommendation = await widget.service.analyzeDefect(
        skuCode: _skuCode,
        severity: _severity,
        description: _description.text.trim(),
        affectedInventory: _selectedRolls.toList(),
      );
      if (mounted) setState(() => _recommendation = recommendation);
    } on ApiException catch (exception) {
      if (mounted) setState(() => _aiError = exception.message);
    } finally {
      _analysisStatusTimer?.cancel();
      if (mounted) setState(() => _analyzing = false);
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
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
                children: [
                  const Text(
                    'QUALITY ASSURANCE  •  CONTROL CENTER',
                    style: TextStyle(
                      color: AppColors.primaryLight,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isEditing ? 'Edit defect report' : 'Create defect report',
                    style: const TextStyle(
                      color: AppColors.strongText,
                      fontSize: 27,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Capture the issue details and let AI assess the quality risk.',
                    style: TextStyle(color: AppColors.mutedText, fontSize: 14),
                  ),
                  const SizedBox(height: 22),
                  if (_error != null) _message(_error!, AppColors.errorText),
                  if (_aiError != null)
                    _message(_aiError!, AppColors.warningText),
                  _FormSelect<String>(
                    label: 'Inventory Roll',
                    value: _skuCode,
                    items: _createdMaterials
                        .map(
                          (material) => DropdownMenuItem<String>(
                            value: material.skuCode,
                            child: Text(material.skuCode),
                          ),
                        )
                        .toList(),
                    onChanged: _selectSku,
                    validator: (_) =>
                        _skuCode == null ? 'Inventory roll is required.' : null,
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
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Description is required.'
                        : null,
                  ),
                  if (_analyzing) ...[
                    const SizedBox(height: 20),
                    _analysisPanel(),
                  ] else if (_recommendation != null) ...[
                    const SizedBox(height: 20),
                    _rollSelection(rolls),
                    const SizedBox(height: 20),
                    _assessmentCard(),
                  ],
                  const SizedBox(height: 112),
                ],
              ),
            ),
      bottomNavigationBar: _loadingInventory
          ? null
          : _ActionBar(
              analyzing: _analyzing,
              saving: _saving,
              canSave: _recommendation != null,
              isEditing: _isEditing,
              onAnalyze: _analyzeWithAi,
              onSave: _save,
            ),
    );
  }

  Widget _analysisPanel() => _AiAnalysisPanel(
    statusIndex: _analysisStatusIndex,
  );

  Widget _rollSelection(List<InventoryRollModel> rolls) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF161B2E), Color(0xFF0F1523)],
      ),
      borderRadius: BorderRadius.circular(16),
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
          Text(
            'Select Inventory Rolls',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (rolls.isEmpty)
            const Text('No current inventory rolls found.')
          else
            ...rolls.map((roll) {
              final selected = _selectedRolls.contains(roll.id);
              return CheckboxListTile(
                value: selected,
                onChanged: (value) => setState(() {
                  final next = {..._selectedRolls};
                  if (value == true) {
                    next.add(roll.id);
                  } else {
                    next.remove(roll.id);
                  }
                  _selectedRolls = next;
                }),
                contentPadding: EdgeInsets.zero,
                title: Text(
                  roll.rollIdentifier.isEmpty ? roll.id : roll.rollIdentifier,
                ),
                subtitle: Text(
                  '${roll.currentQuantity} / ${roll.initialQuantity} units - ${roll.status}',
                ),
              );
            }),
          const SizedBox(height: 4),
          const Text('Review or adjust the rolls selected for this defect.'),
      ],
    ),
  );

  Widget _message(String text, Color color) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(text, style: TextStyle(color: color)),
  );

  Widget _assessmentCard() {
    final recommendation = _recommendation!;
    final contextById = {
      for (final item in recommendation.inventoryContext)
        item['inventoryRollId']?.toString(): item,
    };
    final assessedIds = recommendation.affectedInventory;
    final assessedRolls = assessedIds.map((id) {
      final local = _rolls.where((roll) => roll.id == id).firstOrNull;
      final context = contextById[id];
      return (id: id, roll: local, context: context);
    }).toList();
    final status = recommendation.quarantineRequired ? 'Active' : 'Released';
    final risk = recommendation.riskLevel.toUpperCase();
    final summary = recommendation.reason?.trim().isNotEmpty == true
        ? recommendation.reason!.trim()
        : 'The AI assessment returned a $risk risk level and quarantine is '
              '${recommendation.quarantineRequired ? 'required' : 'not required'}.';

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF161B2E), Color(0xFF0F1523)],
        ),
        borderRadius: BorderRadius.circular(16),
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
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            color: AppColors.violet.withValues(alpha: 0.1),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.violet.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.violet.withValues(alpha: 0.35),
                    ),
                  ),
                  child: const Icon(Icons.smart_toy_outlined),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Defect Assessment',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text('Analysis completed'),
                    ],
                  ),
                ),
                _AssessmentPill(label: status),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _AssessmentMetric(
                        label: 'Risk Level',
                        value: risk,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _AssessmentMetric(
                        label: 'Quarantine Required',
                        value: recommendation.quarantineRequired ? 'YES' : 'NO',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Affected Inventory Rolls',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      '${assessedRolls.length} roll${assessedRolls.length == 1 ? '' : 's'}',
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text('Rolls returned by the AI assessment.'),
                const SizedBox(height: 10),
                if (assessedRolls.isEmpty)
                  const Text('No affected rolls identified.')
                else
                  ...assessedRolls.map(
                    (entry) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(
                        entry.roll?.rollIdentifier.isNotEmpty == true
                            ? entry.roll!.rollIdentifier
                            : entry.id,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(_contextLabel(entry.context, entry.roll)),
                      trailing: _AssessmentPill(
                        label:
                            entry.context?['status']?.toString() ??
                            entry.roll?.status ??
                            'In Stock',
                      ),
                    ),
                  ),
                const Divider(height: 24),
                const Text(
                  'Assessment Summary',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(summary),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _contextLabel(
    Map<String, dynamic>? context,
    InventoryRollModel? roll,
  ) {
    final material =
        context?['rawMaterialName']?.toString() ??
        _selectedMaterial?.name ??
        'Raw material';
    final current = context?['currentQuantity'] ?? roll?.currentQuantity ?? 0;
    final initial = context?['initialQuantity'] ?? roll?.initialQuantity ?? 0;
    return '$material · $current / $initial units';
  }
}

class _FormFieldShell extends StatelessWidget {
  const _FormFieldShell({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
    decoration: _fieldDecoration,
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
    dropdownColor: AppColors.surface,
    iconEnabledColor: AppColors.mutedText,
    decoration: InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.mutedText, fontSize: 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      filled: true,
      fillColor: Colors.transparent,
      enabledBorder: _fieldBorder,
      focusedBorder: _fieldBorder.copyWith(
        borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
      ),
      errorBorder: _fieldBorder.copyWith(
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
    maxLines: 5,
    style: const TextStyle(color: AppColors.strongText, fontSize: 14),
    decoration: InputDecoration(
      labelText: 'Description',
      hintText: 'Description',
      hintStyle: const TextStyle(color: AppColors.mutedText),
      alignLabelWithHint: true,
      filled: true,
      fillColor: Colors.transparent,
      enabledBorder: _fieldBorder,
      focusedBorder: _fieldBorder.copyWith(
        borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
      ),
      errorBorder: _fieldBorder.copyWith(
        borderSide: const BorderSide(color: AppColors.error),
      ),
    ),
    validator: validator,
  );
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.analyzing,
    required this.saving,
    required this.canSave,
    required this.isEditing,
    required this.onAnalyze,
    required this.onSave,
  });

  final bool analyzing;
  final bool saving;
  final bool canSave;
  final bool isEditing;
  final VoidCallback onAnalyze;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.97),
        border: Border(top: BorderSide(color: AppColors.border.withValues(alpha: 0.8))),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: saving || analyzing ? null : onAnalyze,
              icon: const Icon(Icons.bolt_rounded, size: 18),
              label: const Text('Analyze with AI'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryLight,
                side: BorderSide(color: AppColors.primary.withValues(alpha: 0.75)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton.icon(
              onPressed: saving || analyzing || !canSave ? null : onSave,
              icon: saving
                  ? const SizedBox.square(
                      dimension: 17,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined, size: 18),
              label: Text(isEditing ? 'Update Defect' : 'Create Defect'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.strongText,
                disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.25),
                disabledForegroundColor: AppColors.mutedText,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _AiAnalysisPanel extends StatefulWidget {
  const _AiAnalysisPanel({required this.statusIndex});

  final int statusIndex;

  @override
  State<_AiAnalysisPanel> createState() => _AiAnalysisPanelState();
}

class _AiAnalysisPanelState extends State<_AiAnalysisPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat();

  static const _statuses = [
    'Agentic AI analyzing rolls...',
    'Evaluating risk patterns...',
    'Synthesizing quality data...',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF161B2E), Color(0xFF0F1523)],
      ),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFF2A3958), width: 1.2),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.25),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.smart_toy_outlined,
                  color: AppColors.primaryLight,
                  size: 21,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'AI Defect Assessment',
                  softWrap: true,
                  style: TextStyle(
                    color: AppColors.strongText,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const Center(
            child: SizedBox.square(
              dimension: 52,
              child: CircularProgressIndicator(
                strokeWidth: 4,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                backgroundColor: Color(0xFF2A3958),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              _statuses[widget.statusIndex % _statuses.length],
              textAlign: TextAlign.center,
              softWrap: true,
              style: const TextStyle(
                color: AppColors.primaryLight,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 18),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _statuses.length,
            itemBuilder: (context, index) {
              final isCurrent = index == widget.statusIndex % _statuses.length;
              final isComplete = index < widget.statusIndex % _statuses.length;
              final color = isCurrent || isComplete
                  ? AppColors.primaryLight
                  : AppColors.mutedText;
              return Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Row(
                  children: [
                    Icon(
                      isComplete
                          ? Icons.check_circle_rounded
                          : isCurrent
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: color,
                      size: 17,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        _statuses[index],
                        softWrap: true,
                        style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: isCurrent
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    ),
  );
}

final _fieldBorder = OutlineInputBorder(
  borderRadius: BorderRadius.circular(12),
  borderSide: const BorderSide(color: Color(0xFF2A3958), width: 1.2),
);

final _fieldDecoration = BoxDecoration(
  gradient: const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF161B2E), Color(0xFF0F1523)],
  ),
  borderRadius: BorderRadius.circular(12),
  border: Border.all(color: const Color(0xFF2A3958), width: 1.2),
);

class _AssessmentMetric extends StatelessWidget {
  const _AssessmentMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.background.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.strongText,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

class _AssessmentPill extends StatelessWidget {
  const _AssessmentPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final isReleased = label.toLowerCase() == 'released' ||
        label.toLowerCase() == 'in stock';
    final color = isReleased ? const Color(0xFF86EFAC) : AppColors.primaryLight;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

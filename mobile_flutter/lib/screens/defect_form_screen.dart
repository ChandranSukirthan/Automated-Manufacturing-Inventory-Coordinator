import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../models/quality_models.dart';
import '../services/api_client.dart';
import '../services/inventory_api_service.dart';
import '../services/quality_service.dart';

class DefectFormScreen extends StatefulWidget {
  const DefectFormScreen({
    required this.service,
    this.defect,
    this.initialBatchId,
    super.key,
  });

  final QualityService service;
  final DefectReport? defect;
  final String? initialBatchId;

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
      if (widget.initialBatchId != null) {
        final roll = _rolls
            .where((item) => item.batchId == widget.initialBatchId)
            .firstOrNull;
        final material = _materials
            .where((item) => item.id == roll?.rawMaterialId)
            .firstOrNull;
        if (mounted && material != null) {
          setState(() {
            _skuCode = material.skuCode;
          });
        }
      }
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
    if (roll?.batchId != null && roll!.batchId!.isNotEmpty) {
    }
  }

  Future<void> _selectSku(String? sku) async {
    setState(() {
      _skuCode = sku;
      _selectedRolls = {};
      _recommendation = null;
      _aiError = null;
    });
    final firstRoll = _skuRolls.firstOrNull;
    if (firstRoll?.batchId != null && firstRoll!.batchId!.isNotEmpty) {
    }
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
                padding: const EdgeInsets.all(20),
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Quality Assurance  •  Control Center',
                              style: TextStyle(
                                color: Color(0xFFC4B5FD),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Create Defect Report',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Use shared FloorWorker inventory data to record and assess a defect.',
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back, size: 17),
                        label: const Text('Back to Defects'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (_error != null) _message(_error!, AppColors.errorText),
                  if (_aiError != null)
                    _message(_aiError!, AppColors.warningText),
                  DropdownButtonFormField<String>(
                    initialValue: _skuCode,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Inventory Roll',
                    ),
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
                  const SizedBox(height: 16),
                  TextFormField(
                    readOnly: true,
                    initialValue:
                        selectedMaterial?.name ??
                        'Determined from selected inventory',
                    decoration: const InputDecoration(
                      labelText: 'Raw Material',
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _severity,
                    decoration: const InputDecoration(labelText: 'Severity'),
                    items: _severities
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _severity = value!),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: _statuses
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _status = value!),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _description,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      alignLabelWithHint: true,
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Description is required.'
                        : null,
                  ),
                  if (_recommendation != null) ...[
                    const SizedBox(height: 20),
                    _rollSelection(rolls),
                    const SizedBox(height: 20),
                    _assessmentCard(),
                  ],
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: _saving || _analyzing ? null : _analyzeWithAi,
                    icon: _analyzing
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome),
                    label: Text(
                      _analyzing ? 'Analyzing...' : 'Analyze with AI',
                    ),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(_isEditing ? 'Update Defect' : 'Create Defect'),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _rollSelection(List<InventoryRollModel> rolls) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
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

    return Card(
      clipBehavior: Clip.antiAlias,
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
            color: Color(0xFFC4B5FD),
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
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: AppColors.violet.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.violet.withValues(alpha: 0.35)),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: Color(0xFFC4B5FD),
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

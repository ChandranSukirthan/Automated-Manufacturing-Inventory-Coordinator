import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../models/quality_models.dart';
import '../services/api_client.dart';
import '../services/inventory_api_service.dart';
import '../services/quality_service.dart';
import '../widgets/catalog_sku_fields.dart';

/// A floor worker submits an issue against the catalogue SKU. Rolls and
/// batches are optional downstream quality-control details, not prerequisites
/// for reporting a defect.
class DefectFormScreen extends StatefulWidget {
  const DefectFormScreen({required this.service, this.defect, super.key});

  final QualityService service;
  final DefectReport? defect;

  @override
  State<DefectFormScreen> createState() => _DefectFormScreenState();
}

class _DefectFormScreenState extends State<DefectFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _inventory = InventoryApiService();
  final _description = TextEditingController();
  final _skuNumber = TextEditingController();

  List<PackagingTypeModel> _packagingTypes = const [];
  List<RawMaterialModel> _materials = const [];
  int? _packagingTypeId;
  int? _rawMaterialId;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  bool get _isEditing => widget.defect != null;

  PackagingTypeModel? get _packaging =>
      packagingById(_packagingTypes, _packagingTypeId);

  RawMaterialModel? get _rawMaterial => materialById(
    _materials,
    _rawMaterialId,
  );

  String? get _sku => _packaging == null || _rawMaterial == null
      ? null
      : buildSku(_packaging!, _rawMaterial!, _skuNumber.text);

  @override
  void initState() {
    super.initState();
    _description.text = widget.defect?.description ?? '';
    _loadCatalogue();
  }

  @override
  void dispose() {
    _description.dispose();
    _skuNumber.dispose();
    super.dispose();
  }

  Future<void> _loadCatalogue() async {
    try {
      final results = await Future.wait([
        _inventory.fetchPackagingTypes(),
        _inventory.fetchRawMaterials(),
      ]);
      if (!mounted) return;
      setState(() {
        _packagingTypes = results[0] as List<PackagingTypeModel>;
        _materials = results[1] as List<RawMaterialModel>;
        _restoreExistingSku();
        _loading = false;
      });
    } on ApiException catch (exception) {
      if (mounted) {
        setState(() {
          _error = exception.message;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'The material catalogue could not be loaded.';
          _loading = false;
        });
      }
    }
  }

  void _restoreExistingSku() {
    final existingSku = widget.defect?.skuCode.trim() ?? '';
    if (existingSku.isEmpty) return;
    final material = _materials
        .where((item) => item.skuCode.toUpperCase() == existingSku.toUpperCase())
        .firstOrNull;
    if (material == null) return;

    _packagingTypeId = material.packagingTypeId;
    _rawMaterialId = materialOptionsFor(_packagingTypeId, _materials)
        .where((item) => item.materialCode == material.materialCode)
        .firstOrNull
        ?.id;
    _skuNumber.text = existingSku.split('-').last;
  }

  void _clearForm() {
    _formKey.currentState?.reset();
    setState(() {
      _packagingTypeId = null;
      _rawMaterialId = null;
      _skuNumber.clear();
      _description.clear();
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final sku = _sku;
    if (sku == null ||
        !_materials.any(
          (material) => material.skuCode.toUpperCase() == sku.toUpperCase(),
        )) {
      setState(() {
        _error = 'That SKU is not in the catalogue. Use one of the listed SKU numbers.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (_isEditing) {
        await widget.service.updateDefect(
          id: widget.defect!.id,
          skuCode: sku,
          severity: widget.defect!.severity,
          description: _description.text.trim(),
          status: widget.defect!.status,
        );
      } else {
        await widget.service.createDefect(
          skuCode: sku,
          severity: 'MEDIUM',
          description: _description.text.trim(),
          status: 'Open',
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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(_isEditing ? 'Edit defect report' : 'Report defect'),
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'REPORT A DEFECT',
                  style: TextStyle(
                    color: AppColors.primaryLight,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Material issue report',
                  style: TextStyle(
                    color: AppColors.strongText,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Choose the material from the live catalogue, describe the issue, then submit it for manager and admin review.',
                  style: TextStyle(color: AppColors.mutedText, height: 1.4),
                ),
                const SizedBox(height: 24),
                if (_error != null) ...[
                  _ErrorMessage(message: _error!),
                  const SizedBox(height: 14),
                ],
                CatalogSkuFields(
                  packagingTypes: _packagingTypes,
                  rawMaterials: _materials,
                  packagingTypeId: _packagingTypeId,
                  rawMaterialId: _rawMaterialId,
                  skuNumberController: _skuNumber,
                  onPackagingTypeChanged: (value) => setState(() {
                    _packagingTypeId = value;
                    _rawMaterialId = materialOptionsFor(value, _materials)
                        .firstOrNull
                        ?.id;
                    _skuNumber.clear();
                  }),
                  onRawMaterialChanged: (value) => setState(() {
                    _rawMaterialId = value;
                    _skuNumber.clear();
                  }),
                  onSkuNumberChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 18),
                _SkuDisplay(value: _sku),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _description,
                  maxLines: 6,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Describe the defect you observed...',
                    alignLabelWithHint: true,
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a description of the defect.'
                      : null,
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving ? null : _clearForm,
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _submit,
                        icon: _saving
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.send_outlined),
                        label: const Text('Submit report'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
  );
}

class _SkuDisplay extends StatelessWidget {
  const _SkuDisplay({required this.value});

  final String? value;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SKU',
          style: TextStyle(color: AppColors.mutedText, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          value ?? 'Choose packaging type and raw material',
          style: const TextStyle(
            color: AppColors.strongText,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.error.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.error),
    ),
    child: Text(message, style: const TextStyle(color: AppColors.errorText)),
  );
}

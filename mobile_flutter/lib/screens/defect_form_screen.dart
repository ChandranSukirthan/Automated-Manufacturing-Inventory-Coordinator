import 'package:flutter/material.dart';

import '../models/quality_models.dart';
import '../services/api_client.dart';
import '../services/quality_service.dart';

class DefectFormScreen extends StatefulWidget {
  const DefectFormScreen({required this.service, this.defect, super.key});

  final QualityService service;
  final DefectReport? defect;

  @override
  State<DefectFormScreen> createState() => _DefectFormScreenState();
}

class _DefectFormScreenState extends State<DefectFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _batch = TextEditingController();
  final _description = TextEditingController();
  final _severityValues = ['LOW', 'MEDIUM', 'HIGH'];
  final _statusValues = ['Open', 'InReview', 'Resolved', 'Closed'];
  final _productValues = [
    'BoxPouch',
    'BiscuitPackaging',
    'TeaBag',
    'Bag',
    'Can',
    'Bottle',
  ];
  String _severity = 'MEDIUM';
  String _product = 'BoxPouch';
  String _status = 'Open';
  bool _saving = false;

  bool get _isEditing => widget.defect != null;

  @override
  void initState() {
    super.initState();
    final defect = widget.defect;
    if (defect != null) {
      _batch.text = defect.batchId;
      _description.text = defect.description;
      _product = defect.productType;
      _severity = defect.severity;
      _status = defect.status;
    }
  }

  @override
  void dispose() {
    _batch.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      if (_isEditing) {
        await widget.service.updateDefect(
          id: widget.defect!.id,
          batchId: _batch.text.trim(),
          productType: _product,
          severity: _severity,
          description: _description.text.trim(),
          status: _status,
        );
      } else {
        await widget.service.createDefect(
          batchId: _batch.text.trim(),
          productType: _product,
          severity: _severity,
          description: _description.text.trim(),
          status: _status,
        );
      }
      if (mounted) {
        Navigator.pop(context, true);
      }
    } on ApiException catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(exception.message)));
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(_isEditing ? 'Edit defect report' : 'Report a defect'),
    ),
    body: Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextFormField(
            controller: _batch,
            decoration: const InputDecoration(labelText: 'Batch ID'),
            validator: _required,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _product,
            decoration: const InputDecoration(labelText: 'Product type'),
            items: _productValues
                .map(
                  (value) => DropdownMenuItem(value: value, child: Text(value)),
                )
                .toList(),
            onChanged: (value) => setState(() => _product = value!),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _severity,
            decoration: const InputDecoration(labelText: 'Severity'),
            items: _severityValues
                .map(
                  (value) => DropdownMenuItem(value: value, child: Text(value)),
                )
                .toList(),
            onChanged: (value) => setState(() => _severity = value!),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _status,
            decoration: const InputDecoration(labelText: 'Status'),
            items: _statusValues
                .map(
                  (value) => DropdownMenuItem(value: value, child: Text(value)),
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
            validator: _required,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(_isEditing ? 'Update report' : 'Create report'),
          ),
        ],
      ),
    ),
  );

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'This field is required.' : null;
}

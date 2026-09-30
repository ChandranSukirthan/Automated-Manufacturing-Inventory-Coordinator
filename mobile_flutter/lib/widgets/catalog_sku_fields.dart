import 'package:flutter/material.dart';

import '../services/inventory_api_service.dart';

/// Reusable database-catalogue selector for every screen that needs to refer
/// to a material SKU. Workers choose the first two segments; they only type the
/// final sequence number.
class CatalogSkuFields extends StatelessWidget {
  const CatalogSkuFields({
    super.key,
    required this.packagingTypes,
    required this.rawMaterials,
    required this.packagingTypeId,
    required this.rawMaterialId,
    required this.skuNumberController,
    required this.onPackagingTypeChanged,
    required this.onRawMaterialChanged,
    this.onSkuNumberChanged,
    this.enabled = true,
    this.dark = false,
  });

  final List<PackagingTypeModel> packagingTypes;
  final List<RawMaterialModel> rawMaterials;
  final int? packagingTypeId;
  final int? rawMaterialId;
  final TextEditingController skuNumberController;
  final ValueChanged<int?> onPackagingTypeChanged;
  final ValueChanged<int?> onRawMaterialChanged;
  final ValueChanged<String>? onSkuNumberChanged;
  final bool enabled;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final materials = materialOptionsFor(packagingTypeId, rawMaterials);
    final selectedMaterial = materials
        .where((material) => material.id == rawMaterialId)
        .firstOrNull;
    final selectedPackaging = packagingTypes
        .where((type) => type.id == packagingTypeId)
        .firstOrNull;
    final decoration = InputDecoration(
      labelText: 'SKU Number',
      hintText: 'e.g. 3',
      prefixText: selectedPackaging == null || selectedMaterial == null
          ? null
          : '${selectedPackaging.shortCode}-${selectedMaterial.materialCode}-',
    );

    return Column(
      children: [
        DropdownButtonFormField<int>(
          initialValue: packagingTypes.any((type) => type.id == packagingTypeId)
              ? packagingTypeId
              : null,
          isExpanded: true,
          decoration: _decorate('Packaging Type'),
          items: packagingTypes
              .map(
                (type) => DropdownMenuItem<int>(
                  value: type.id,
                  child: Text(type.name, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: enabled ? onPackagingTypeChanged : null,
          validator: (value) =>
              value == null ? 'Select a packaging type.' : null,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          initialValue:
              materials.any((material) => material.id == rawMaterialId)
              ? rawMaterialId
              : null,
          isExpanded: true,
          decoration: _decorate('Raw Material'),
          items: materials
              .map(
                (material) => DropdownMenuItem<int>(
                  value: material.id,
                  child: Text(
                    '${material.name} (${material.materialCode})',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: enabled && packagingTypeId != null
              ? onRawMaterialChanged
              : null,
          validator: (value) => value == null ? 'Select a raw material.' : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: skuNumberController,
          onChanged: onSkuNumberChanged,
          enabled: enabled && selectedMaterial != null,
          keyboardType: TextInputType.number,
          decoration: dark
              ? decoration.copyWith(
                  filled: true,
                  fillColor: const Color(0xFF262626),
                  labelStyle: const TextStyle(color: Colors.white60),
                )
              : decoration,
          validator: (value) {
            final number = int.tryParse(value?.trim() ?? '');
            if (number == null || number < 1 || number > 999999) {
              return 'Enter an SKU number from 1 to 999999.';
            }
            return null;
          },
        ),
        if (selectedPackaging != null && selectedMaterial != null) ...[
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'SKU preview: ${buildSku(selectedPackaging, selectedMaterial, skuNumberController.text)}',
              style: TextStyle(
                fontSize: 12,
                color: dark ? Colors.white60 : Theme.of(context).hintColor,
              ),
            ),
          ),
        ],
      ],
    );
  }

  InputDecoration _decorate(String label) => InputDecoration(
    labelText: label,
    filled: dark,
    fillColor: dark ? const Color(0xFF262626) : null,
    labelStyle: dark ? const TextStyle(color: Colors.white60) : null,
  );
}

List<RawMaterialModel> materialOptionsFor(
  int? packagingTypeId,
  List<RawMaterialModel> materials,
) {
  if (packagingTypeId == null) return const [];
  final seenCodes = <String>{};
  return materials
      .where((material) => material.packagingTypeId == packagingTypeId)
      .where((material) => seenCodes.add(material.materialCode))
      .toList();
}

String buildSku(
  PackagingTypeModel packagingType,
  RawMaterialModel rawMaterial,
  String numberText,
) {
  final number = int.tryParse(numberText.trim());
  final suffix = number == null ? '???' : number.toString().padLeft(3, '0');
  return '${packagingType.shortCode}-${rawMaterial.materialCode}-$suffix';
}

PackagingTypeModel? packagingById(List<PackagingTypeModel> types, int? id) =>
    types.where((type) => type.id == id).firstOrNull;

RawMaterialModel? materialById(List<RawMaterialModel> materials, int? id) =>
    materials.where((material) => material.id == id).firstOrNull;

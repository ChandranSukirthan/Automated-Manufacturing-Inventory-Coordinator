import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../controllers/inventory_controller.dart';
import '../services/api_client.dart';
import '../services/inventory_api_service.dart';
import '../widgets/app_widgets.dart';
import '../widgets/catalog_sku_fields.dart';

class StockView extends StatefulWidget {
  final InventoryController controller;
  final VoidCallback? onBack;

  const StockView({
    super.key,
    required this.controller,
    this.onBack,
    this.onTriggerAi,
  });
  final Future<void> Function(String sku, num quantity)? onTriggerAi;

  @override
  State<StockView> createState() => _StockViewState();
}

class _StockViewState extends State<StockView> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final InventoryApiService _apiService = InventoryApiService();

  List<InventoryItemModel> _inventoryItems = [];
  List<StockAlertModel> _alerts = [];
  List<RawMaterialModel> _rawMaterials = [];
  List<PackagingTypeModel> _packagingTypes = [];
  List<InventoryRollModel> _rolls = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _apiService.fetchOwnedInventory(),
        _apiService.fetchAlerts(),
        _apiService.fetchRawMaterials(),
        _apiService.fetchOwnedRolls(),
        _apiService.fetchPackagingTypes(),
      ]);
      if (!mounted) return;
      setState(() {
        _inventoryItems = results[0] as List<InventoryItemModel>;
        _alerts = results[1] as List<StockAlertModel>;
        _rawMaterials = results[2] as List<RawMaterialModel>;
        _rolls = results[3] as List<InventoryRollModel>;
        _packagingTypes = results[4] as List<PackagingTypeModel>;
        _isLoading = false;
      });
    } on ApiException catch (exception) {
      if (!mounted) return;
      setState(() {
        _error = exception.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Inventory could not be loaded. Check the API connection.';
        _isLoading = false;
      });
    }
  }

  Future<void> _showRegisterRollForm() async {
    final identifierNumber = TextEditingController();
    final quantity = TextEditingController();
    final batch = TextEditingController();
    final formKey = GlobalKey<FormState>();
    int? packagingTypeId = _packagingTypes
        .where((type) => _firstRollMaterialId(type.id) != null)
        .firstOrNull
        ?.id;
    int? rawMaterialId = _firstRollMaterialId(packagingTypeId);
    String? sku = _rollSkuOptionsFor(packagingTypeId, rawMaterialId)
        .firstOrNull
        ?.sku;
    String? submissionError;

    try {
      final createdRoll = await showDialog<InventoryRollModel>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) {
            final materialOptions = materialOptionsFor(
              packagingTypeId,
              _rawMaterials,
            );
            final skuOptions = _rollSkuOptionsFor(
              packagingTypeId,
              rawMaterialId,
            );
            final selectedItem = _inventoryItems
                .where((item) => item.sku == sku)
                .firstOrNull;
            final selectedMaterial = selectedItem == null
                ? null
                : materialById(_rawMaterials, selectedItem.rawMaterialId);
            final currentStock = selectedItem?.stockLevel ?? 0;
            final enteredQuantity = int.tryParse(quantity.text.trim()) ?? 0;
            final rollIdentifier = _buildRollIdentifier(
              selectedItem?.sku,
              identifierNumber.text,
            );
            return AlertDialog(
              scrollable: true,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 24,
              ),
              title: const Text('Register New Roll'),
              content: SizedBox(
                width: 360,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<int>(
                        initialValue: packagingTypeId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Packaging Type',
                        ),
                        items: _packagingTypes
                            .map(
                              (packaging) => DropdownMenuItem<int>(
                                value: packaging.id,
                                child: Text(
                                  packaging.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => setDialogState(() {
                          packagingTypeId = value;
                          rawMaterialId = _firstRollMaterialId(value);
                          sku = _rollSkuOptionsFor(value, rawMaterialId)
                              .firstOrNull
                              ?.sku;
                          identifierNumber.clear();
                          submissionError = null;
                        }),
                        validator: (value) => value == null
                            ? 'Select a packaging type.'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        initialValue: rawMaterialId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Raw Material',
                        ),
                        items: materialOptions
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
                        onChanged: packagingTypeId == null
                            ? null
                            : (value) => setDialogState(() {
                                rawMaterialId = value;
                                sku = _rollSkuOptionsFor(
                                  packagingTypeId,
                                  value,
                                ).firstOrNull?.sku;
                                identifierNumber.clear();
                                submissionError = null;
                              }),
                        validator: (value) => value == null
                            ? 'Select a raw material.'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: skuOptions.any((item) => item.sku == sku)
                            ? sku
                            : null,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'SKU Number'),
                        items: skuOptions
                            .map(
                              (item) => DropdownMenuItem<String>(
                                value: item.sku,
                                child: Text(
                                  '${_skuNumberLabel(item)} '
                                  '(${item.stockLevel} units in stock)',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: skuOptions.isEmpty
                            ? null
                            : (value) => setDialogState(() {
                                sku = value;
                                identifierNumber.clear();
                                submissionError = null;
                              }),
                        validator: (value) => value == null
                            ? 'Select an SKU number in stock.'
                            : null,
                      ),
                      if (selectedItem != null) ...[
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'SKU preview: ${selectedItem.sku}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.mutedText,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: identifierNumber,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setDialogState(() {
                          submissionError = null;
                        }),
                        decoration: InputDecoration(
                          labelText: 'Roll Identifier',
                          hintText: 'e.g. 01',
                          prefixText: selectedItem == null
                              ? null
                              : 'ROLL-${selectedItem.sku}-',
                        ),
                        validator: (value) {
                          final number = value?.trim() ?? '';
                          final parsed = int.tryParse(number);
                          if (!RegExp(r'^\d{1,6}$').hasMatch(number) ||
                              parsed == null ||
                              parsed <= 0) {
                            return 'Enter a roll number greater than zero.';
                          }
                          if (_rolls.any(
                            (roll) =>
                                roll.rollIdentifier.toUpperCase() ==
                                rollIdentifier.toUpperCase(),
                          )) {
                            return 'This roll number is already registered for this SKU.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: TextFormField(
                          controller: quantity,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setDialogState(() {
                            submissionError = null;
                          }),
                          decoration: const InputDecoration(
                            labelText: 'Roll Quantity',
                            hintText: 'Enter quantity',
                          ),
                          validator: (value) {
                            final parsed = int.tryParse(value?.trim() ?? '');
                            if (parsed == null || parsed <= 0) {
                              return 'Roll quantity must be greater than zero.';
                            }
                            return null;
                          },
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          selectedMaterial == null
                              ? 'Select an SKU in stock.'
                              : enteredQuantity > 0
                              ? 'Stock after registration: '
                                  '${currentStock + enteredQuantity} units '
                                  '(currently $currentStock)'
                              : 'Current stock: $currentStock units. '
                                  'Registering this roll adds to stock.',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.mutedText,
                          ),
                        ),
                      ),
                        TextFormField(controller: batch, maxLength: 80,
                          decoration: const InputDecoration(labelText: 'Batch identifier'),
                          validator: (value) => (value ?? '').trim().isEmpty ? 'Enter the batch identifier.' : null),
                        if (submissionError != null) ...[
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            submissionError!,
                            style: const TextStyle(color: Colors.redAccent),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    if (selectedMaterial == null) {
                      setDialogState(() => submissionError =
                          'Select an inventory SKU before registering a roll.');
                      return;
                    }
                    try {
                      final roll = await _apiService.createRoll(
                        rollIdentifier: rollIdentifier,
                        batchId: batch.text.trim(),
                        quantity: double.parse(quantity.text),
                        rawMaterialId: selectedMaterial.id,
                      );
                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext, roll);
                      }
                    } on ApiException catch (exception) {
                      if (dialogContext.mounted) {
                        setDialogState(() => submissionError = exception.message);
                      }
                    }
                  },
                  child: const Text('Register Roll'),
                ),
              ],
            );
          },
        ),
      );
      if (createdRoll != null && mounted) {
        await _fetchData();
        if (mounted) await _showRollQr(createdRoll);
      }
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        identifierNumber.dispose();
        quantity.dispose();
        batch.dispose();
      });
    }
  }

  List<RawMaterialModel> _rollRegistrableMaterials() {
    return _rawMaterials
        .where(
          (material) => _inventoryItems.any(
            (item) =>
                item.sku.toLowerCase() == material.skuCode.toLowerCase() &&
                item.stockLevel > 0,
          ),
        )
        .toList();
  }

  int? _firstRollMaterialId(int? packagingTypeId) => materialOptionsFor(
    packagingTypeId,
    _rawMaterials,
  ).where((material) => _rollSkuOptionsFor(packagingTypeId, material.id).isNotEmpty)
      .firstOrNull
      ?.id;

  List<InventoryItemModel> _rollSkuOptionsFor(
    int? packagingTypeId,
    int? rawMaterialId,
  ) {
    final selectedMaterial = materialById(_rawMaterials, rawMaterialId);
    if (packagingTypeId == null || selectedMaterial == null) return const [];

    final options = _inventoryItems.where((item) {
      final itemMaterial = materialById(_rawMaterials, item.rawMaterialId);
      return item.stockLevel > 0 &&
          item.packagingTypeId == packagingTypeId &&
          itemMaterial?.materialCode == selectedMaterial.materialCode &&
          itemMaterial != null;
    }).toList();
    options.sort((left, right) => (left.skuNumber ?? 0).compareTo(right.skuNumber ?? 0));
    return options;
  }

  String _skuNumberLabel(InventoryItemModel item) {
    final number = item.skuNumber;
    if (number != null) return number.toString().padLeft(3, '0');
    return item.sku.split('-').last;
  }

  String _buildRollIdentifier(String? selectedSku, String numberText) {
    final parsed = int.tryParse(numberText.trim());
    final suffix = parsed == null ? '??' : parsed.toString().padLeft(2, '0');
    return 'ROLL-${selectedSku ?? 'SKU'}-$suffix';
  }

  Future<void> _showItemRolls(InventoryItemModel item) async {
    final material = _rawMaterials
        .where(
          (candidate) =>
              candidate.skuCode.toLowerCase() == item.sku.toLowerCase(),
        )
        .firstOrNull;
    final rolls = material == null
        ? <InventoryRollModel>[]
        : _rolls.where((roll) => roll.rawMaterialId == material.id).toList();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * .65,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.qr_code_2),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Created Rolls â€¢ ${item.sku}',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const Divider(),
                if (rolls.isEmpty)
                  const Expanded(
                    child: Center(
                      child: Text(
                        'No rolls created for this SKU by this account.',
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.separated(
                      itemCount: rolls.length,
                      separatorBuilder: (_, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final roll = rolls[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.inventory_2_outlined),
                          title: Text('${roll.currentQuantity} units'),
                          subtitle: Text(
                            'Original quantity: ${roll.initialQuantity} units',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(roll.status),
                              IconButton(
                                tooltip: 'Show QR code',
                                icon: const Icon(Icons.qr_code_2),
                                onPressed: () => _showRollQr(roll),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showRollQr(InventoryRollModel roll) {
    final material = materialById(_rawMaterials, roll.rawMaterialId);
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: const Text('Roll QR code'),
        content: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'This QR code is created automatically for this physical roll. '
                'Scan it to load this roll and its remaining quantity.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FutureBuilder<Uint8List>(
                future: _apiService.fetchRollQr(roll.rollIdentifier),
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const SizedBox.square(
                      dimension: 220,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.hasError || !snapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'The QR code could not be loaded. Check the server connection and try again.',
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  return Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(12),
                    child: Image.memory(
                      snapshot.data!,
                      width: 220,
                      height: 220,
                      fit: BoxFit.contain,
                      semanticLabel: 'QR code for this inventory roll',
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              Text(
                '${material?.skuCode ?? 'Selected SKU'} â€¢ '
                '${roll.currentQuantity} units remaining',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.mutedText,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _showItemForm([InventoryItemModel? item]) async {
    final skuNumber = TextEditingController(
      text: item?.skuNumber?.toString() ?? '',
    );
    final stock = TextEditingController(
      text: item == null ? '' : item.stockLevel.toString(),
    );
    final reorder = TextEditingController(
      text: item == null ? '' : item.reorderThreshold.toString(),
    );
    final formKey = GlobalKey<FormState>();
    int? packagingTypeId = item?.packagingTypeId;
    int? rawMaterialId = item?.rawMaterialId;

    try {
      final saved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            scrollable: true,
            title: Text(item == null ? 'Add Stock Item' : 'Edit Stock Item'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (item == null)
                    CatalogSkuFields(
                      packagingTypes: _packagingTypes,
                      rawMaterials: _rawMaterials,
                      packagingTypeId: packagingTypeId,
                      rawMaterialId: rawMaterialId,
                      skuNumberController: skuNumber,
                      onPackagingTypeChanged: (value) => setDialogState(() {
                        packagingTypeId = value;
                        rawMaterialId = null;
                        skuNumber.clear();
                      }),
                      onRawMaterialChanged: (value) => setDialogState(() {
                        rawMaterialId = value;
                        skuNumber.clear();
                      }),
                      onSkuNumberChanged: (_) => setDialogState(() {}),
                    )
                  else
                    _catalogueSummary(item),
                  const SizedBox(height: 12),
                  _numberField(
                    stock,
                    'Current Stock',
                    hintText: 'Enter current stock',
                  ),
                  _numberField(
                    reorder,
                    'Reorder Level',
                    hintText: 'Enter reorder level',
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  try {
                    if (item == null) {
                      await _apiService.createItem(
                        packagingTypeId: packagingTypeId!,
                        rawMaterialId: rawMaterialId!,
                        skuNumber: int.parse(skuNumber.text.trim()),
                        stockLevel: int.parse(stock.text),
                        reorderThreshold: int.parse(reorder.text),
                      );
                    } else {
                      await _apiService.updateItem(
                        InventoryItemModel(
                          id: item.id,
                          sku: item.sku,
                          name: item.name,
                          category: item.category,
                          packagingTypeId: item.packagingTypeId,
                          rawMaterialId: item.rawMaterialId,
                          skuNumber: item.skuNumber,
                          stockLevel: int.parse(stock.text),
                          reorderThreshold: int.parse(reorder.text),
                        ),
                      );
                    }
                    if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                  } on ApiException catch (exception) {
                    if (dialogContext.mounted) {
                      ScaffoldMessenger.of(
                        dialogContext,
                      ).showSnackBar(SnackBar(content: Text(exception.message)));
                    }
                  }
                },
                child: Text(item == null ? 'Create Item' : 'Save Changes'),
              ),
            ],
          ),
        ),
      );
      if (saved == true && mounted) await _fetchData();
    } finally {
      // AlertDialog removes its text fields on the next frame. Disposing the
      // controllers now causes Flutter to rebuild those fields with disposed
      // controllers when the dialog is dismissed (including via Cancel).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        skuNumber.dispose();
        stock.dispose();
        reorder.dispose();
      });
    }
  }

  Widget _catalogueSummary(InventoryItemModel item) {
    final packaging = packagingById(_packagingTypes, item.packagingTypeId);
    final material = materialById(_rawMaterials, item.rawMaterialId);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.inventory_2_outlined),
      title: Text(item.sku),
      subtitle: Text(
        '${packaging?.name ?? item.category} â€¢ ${material?.name ?? item.name}',
      ),
    );
  }

  Widget _numberField(
    TextEditingController controller,
    String label, {
    bool decimal = false,
    String? hintText,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      decoration: InputDecoration(labelText: label, hintText: hintText),
      validator: (value) {
        final parsed = decimal
            ? double.tryParse(value ?? '')
            : int.tryParse(value ?? '');
        if (parsed == null || parsed < 0) return 'Enter a nonnegative number.';
        if (decimal && parsed == 0) {
          return 'Quantity must be greater than zero.';
        }
        return null;
      },
    ),
  );

  Future<void> _deleteItem(InventoryItemModel item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete stock item?'),
        content: Text('Delete ${item.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _apiService.deleteItem(item.id);
      if (mounted) await _fetchData();
    } on ApiException catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(exception.message)));
      }
    }
  }

  bool _hasPredictiveAlert(String sku) {
    return _alerts.any(
      (alert) =>
          alert.sku == sku &&
          alert.workerId.contains('Predictive') &&
          alert.status != 'Resolved',
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const accent = AppColors.violet;
    const accentBright = Color(0xFFC4B5FD);
    const darkBg = AppColors.background;
    const cardBg = AppColors.surface;

    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, child) {
        final filteredItems = _inventoryItems.where((item) {
          if (_searchQuery.isEmpty) return true;
          return item.name.toLowerCase().contains(_searchQuery) ||
              item.sku.toLowerCase().contains(_searchQuery);
        }).toList();
        return Scaffold(
          backgroundColor: darkBg,
          appBar: AppBar(
            backgroundColor: darkBg,
            elevation: 0,
            automaticallyImplyLeading: false,
            centerTitle: true,
            title: const Text(
              'RAW MATERIALS & ITEMS',
              style: TextStyle(
                color: accent,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showItemForm(),
            backgroundColor: accent,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add),
            label: const Text(
              'Add Item',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0x268B5CF6),
                      child: Icon(Icons.qr_code_2, color: accentBright),
                    ),
                    title: const Text(
                      'Register New Roll',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      _rollRegistrableMaterials().isEmpty
                          ? 'Add an inventory SKU before registering a roll'
                          : 'Receive a physical roll into stock',
                      style: const TextStyle(color: AppColors.mutedText),
                    ),
                    trailing: FilledButton.icon(
                      onPressed: _rollRegistrableMaterials().isEmpty
                          ? null
                          : _showRegisterRollForm,
                      icon: const Icon(Icons.add),
                      label: const Text('Register'),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Filter materials by SKU or name...',
                    hintStyle: const TextStyle(
                      color: Colors.white38,
                      fontSize: 14,
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: accentBright,
                      size: 22,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.clear,
                              color: Colors.white54,
                              size: 20,
                            ),
                            onPressed: () => _searchController.clear(),
                          )
                        : null,
                    filled: true,
                    fillColor: cardBg,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.white12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.white12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: accent, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                // ListView displaying current inventory items
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(color: accent),
                        )
                      : _error != null
                      ? StateMessage(
                          message: _error!,
                          icon: Icons.cloud_off,
                          action: _fetchData,
                        )
                      : RefreshIndicator(
                          color: accent,
                          backgroundColor: cardBg,
                          onRefresh: _fetchData,
                          child: filteredItems.isEmpty
                              ? ListView(
                                  children: [
                                    const SizedBox(height: 100),
                                    Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: const [
                                          Icon(
                                            Icons.inventory_2_outlined,
                                            color: Colors.white24,
                                            size: 56,
                                          ),
                                          SizedBox(height: 12),
                                          Text(
                                            'No matching materials found',
                                            style: TextStyle(
                                              color: Colors.white54,
                                              fontSize: 15,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                )
                              : ListView.separated(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  itemCount: filteredItems.length,
                                  separatorBuilder: (context, index) =>
                                      const SizedBox(height: 12),
                                  itemBuilder: (context, index) {
                                    final item = filteredItems[index];
                                    return _buildStockItemCard(
                                      item: item,
                                      cardBg: cardBg,
                                    );
                                  },
                                ),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStockItemCard({
    required InventoryItemModel item,
    required Color cardBg,
  }) {
    const predictiveWarningColor = AppColors.violet;

    final isLowStock = item.stockLevel <= item.reorderThreshold;
    final hasPredictiveAlert = _hasPredictiveAlert(item.sku);
    final isWarning = isLowStock || hasPredictiveAlert;

    Color borderColor = Colors.white12;
    if (isLowStock) {
      borderColor = const Color(0xFFFF5252);
    } else if (hasPredictiveAlert) {
      borderColor = predictiveWarningColor;
    }

    // Determine the status text and colors
    String statusText = 'In Stock';
    Color statusColor = const Color(0xFFC4B5FD);
    Color statusBg = const Color(0x268B5CF6);

    if (isLowStock) {
      statusText = 'Low Stock';
      statusColor = const Color(0xFFFF5252);
      statusBg = const Color(0x33FF5252);
    } else if (hasPredictiveAlert) {
      statusText = 'Predictive Alert';
      statusColor = predictiveWarningColor;
      statusBg = predictiveWarningColor.withValues(alpha: 0.2);
    }

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: isWarning ? 2.0 : 1.0),
        boxShadow: isWarning
            ? [
                BoxShadow(
                  color: borderColor.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ]
            : const [
                BoxShadow(
                  color: Color(0x0F000000),
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
      ),
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left Column: Name & SKU
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'SKU: ${item.sku}',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Category: ${item.category.isEmpty ? 'General' : item.category}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  'Reorder Level: ${item.reorderThreshold} units',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                if (hasPredictiveAlert && !isLowStock)
                  const Padding(
                    padding: EdgeInsets.only(top: 4.0),
                    child: Text(
                      'Forecasted Stockout (< 5 Days)',
                      style: TextStyle(
                        color: predictiveWarningColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${item.stockLevel} Units',
                style: TextStyle(
                  color: isLowStock ? AppColors.error : const Color(0xFFC4B5FD),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isLowStock ? 'Low Stock' : 'Optimal',
                style: TextStyle(
                  color: statusColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: statusColor, width: 1),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 2,
                runSpacing: 2,
                children: [
                  if (isLowStock && widget.onTriggerAi != null)
                    IconButton(
                      tooltip: 'Analyze low-stock data',
                      onPressed: () => widget.onTriggerAi!(item.sku, 0),
                      icon: const Icon(
                        Icons.auto_awesome,
                        color: AppColors.violet,
                        size: 18,
                      ),
                    ),
                  IconButton(
                    tooltip: 'View created rolls',
                    onPressed: () => _showItemRolls(item),
                    icon: const Icon(
                      Icons.visibility_outlined,
                      color: AppColors.violet,
                      size: 18,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Edit item',
                    onPressed: () => _showItemForm(item),
                    icon: const Icon(
                      Icons.edit_outlined,
                      color: Colors.white70,
                      size: 18,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Delete item',
                    onPressed: () => _deleteItem(item),
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.redAccent,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../controllers/inventory_controller.dart';
import '../services/api_client.dart';
import '../services/inventory_api_service.dart';
import '../widgets/app_widgets.dart';

class StockView extends StatefulWidget {
  final InventoryController controller;
  final VoidCallback? onBack;

  const StockView({
    super.key,
    required this.controller,
    this.onBack,
    this.onTriggerAi,
    this.triggeringAi = false,
  });
  final Future<void> Function(String sku, num quantity)? onTriggerAi;
  final bool triggeringAi;

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
      ]);
      if (!mounted) return;
      setState(() {
        _inventoryItems = results[0] as List<InventoryItemModel>;
        _alerts = results[1] as List<StockAlertModel>;
        _rawMaterials = results[2] as List<RawMaterialModel>;
        _rolls = results[3] as List<InventoryRollModel>;
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
    final identifier = TextEditingController();
    final quantity = TextEditingController(text: '1');
    final formKey = GlobalKey<FormState>();
    final ownedSkus = _inventoryItems
        .map((item) => item.sku.toLowerCase())
        .toSet();
    final availableMaterials = _rawMaterials
        .where((material) => ownedSkus.contains(material.skuCode.toLowerCase()))
        .toList();
    int? selectedMaterial = availableMaterials.isEmpty
        ? null
        : availableMaterials.first.id;

    try {
      final saved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Register New Roll'),
            content: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * .48,
                maxWidth: 420,
              ),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _textField(identifier, 'Roll Identifier', required: true),
                      _numberField(quantity, 'Roll Quantity', decimal: true),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: Text(
                            'Cannot exceed current stock.',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ),
                      ),
                      if (availableMaterials.isEmpty)
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Create stock for this account before registering a roll.',
                          ),
                        )
                      else
                        DropdownButtonFormField<int>(
                          initialValue: selectedMaterial,
                          decoration: const InputDecoration(
                            labelText: 'Raw Material',
                          ),
                          items: availableMaterials
                              .map(
                                (material) => DropdownMenuItem<int>(
                                  value: material.id,
                                  child: Text(
                                    '${material.skuCode} - ${material.name}',
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setDialogState(() => selectedMaterial = value),
                          validator: (value) =>
                              value == null ? 'Select a raw material.' : null,
                        ),
                    ],
                  ),
                ),
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
                    await _apiService.createRoll(
                      rollIdentifier: identifier.text.trim(),
                      quantity: double.parse(quantity.text),
                      rawMaterialId: selectedMaterial!,
                    );
                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext, true);
                    }
                  } on ApiException catch (exception) {
                    if (dialogContext.mounted) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        SnackBar(content: Text(exception.message)),
                      );
                    }
                  }
                },
                child: const Text('Register Roll'),
              ),
            ],
          ),
        ),
      );
      if (saved == true && mounted) await _fetchData();
    } finally {
      identifier.dispose();
      quantity.dispose();
    }
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
                        'Created Rolls • ${item.sku}',
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
                          title: Text(roll.rollIdentifier),
                          subtitle: Text(
                            'Quantity ${roll.currentQuantity} / ${roll.initialQuantity}',
                          ),
                          trailing: Text(roll.status),
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

  Future<void> _showItemForm([InventoryItemModel? item]) async {
    final sku = TextEditingController(text: item?.sku ?? '');
    final name = TextEditingController(text: item?.name ?? '');
    final category = TextEditingController(text: item?.category ?? 'Metal');
    final stock = TextEditingController(text: '${item?.stockLevel ?? 100}');
    final reorder = TextEditingController(
      text: '${item?.reorderThreshold ?? 50}',
    );
    final formKey = GlobalKey<FormState>();

    try {
      final saved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(item == null ? 'Add Stock Item' : 'Edit Stock Item'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _textField(sku, 'SKU Code', required: true),
                  _textField(name, 'Item Name', required: true),
                  _textField(category, 'Category'),
                  _numberField(stock, 'Current Stock'),
                  _numberField(reorder, 'Reorder Level'),
                ],
              ),
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
                  final values = (
                    sku: sku.text.trim(),
                    name: name.text.trim(),
                    category: category.text.trim(),
                    stock: int.parse(stock.text),
                    reorder: int.parse(reorder.text),
                  );
                  if (item == null) {
                    await _apiService.createItem(
                      sku: values.sku,
                      name: values.name,
                      category: values.category,
                      stockLevel: values.stock,
                      reorderThreshold: values.reorder,
                    );
                  } else {
                    await _apiService.updateItem(
                      InventoryItemModel(
                        id: item.id,
                        sku: values.sku,
                        name: values.name,
                        category: values.category,
                        stockLevel: values.stock,
                        reorderThreshold: values.reorder,
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
      );
      if (saved == true && mounted) await _fetchData();
    } finally {
      sku.dispose();
      name.dispose();
      category.dispose();
      stock.dispose();
      reorder.dispose();
    }
  }

  Widget _textField(
    TextEditingController controller,
    String label, {
    bool required = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
      validator: required
          ? (value) => value == null || value.trim().isEmpty
                ? '$label is required.'
                : null
          : null,
    ),
  );

  Widget _numberField(
    TextEditingController controller,
    String label, {
    bool decimal = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      decoration: InputDecoration(labelText: label),
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(exception.message)));
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

  bool _hasActiveAlert(String sku) {
    return _alerts.any(
      (alert) =>
          alert.sku.toLowerCase() == sku.toLowerCase() &&
          const [
            'Pending',
            'Processing',
            'Acknowledged',
          ].contains(alert.status),
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
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back,
                color: AppColors.secondaryText,
                size: 24,
              ),
              onPressed: () {
                if (widget.onBack != null) {
                  widget.onBack!();
                } else if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
              },
            ),
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
                    subtitle: const Text(
                      'Create a roll from available stock',
                      style: TextStyle(color: AppColors.mutedText),
                    ),
                    trailing: FilledButton.icon(
                      onPressed: _inventoryItems.isEmpty
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
                      borderSide: const BorderSide(
                        color: accent,
                        width: 1.5,
                      ),
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
                    _hasActiveAlert(item.sku)
                        ? const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              'In Progress',
                              style: TextStyle(
                                color: predictiveWarningColor,
                                fontSize: 11,
                              ),
                            ),
                          )
                        : IconButton(
                            tooltip: 'Reorder via AI',
                            onPressed: widget.triggeringAi
                                ? null
                                : () async {
                                    await widget.onTriggerAi!(item.sku, 2000);
                                    if (mounted) await _fetchData();
                                  },
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

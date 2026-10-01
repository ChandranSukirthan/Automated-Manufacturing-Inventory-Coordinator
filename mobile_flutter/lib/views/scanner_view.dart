import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../controllers/inventory_controller.dart';
import '../services/api_client.dart';
import '../services/inventory_api_service.dart';
import '../widgets/catalog_sku_fields.dart';

String _normalizeSku(String value) => value
    .trim()
    .toUpperCase()
    .replaceAll('-', '')
    .replaceAll(' ', '');

class ScannerView extends StatefulWidget {
  final InventoryController controller;
  final VoidCallback? onBack;

  const ScannerView({
    super.key,
    required this.controller,
    this.onBack,
  });

  @override
  State<ScannerView> createState() => _ScannerViewState();
}

class _ScannerViewState extends State<ScannerView> {
  final MobileScannerController _scannerController = MobileScannerController();
  final InventoryApiService _inventoryApi = InventoryApiService();
  bool _hasScanned = false;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _handleBarcode(BarcodeCapture capture) async {
    if (_hasScanned) return;

    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      if (barcode.rawValue != null && barcode.rawValue!.isNotEmpty) {
        setState(() {
          _hasScanned = true;
        });

        final scannedCode = barcode.rawValue!;
        await _scannerController.stop();
        Map<String, dynamic> roll;
        try {
          roll = await _inventoryApi.lookupRoll(scannedCode);
        } on ApiException catch (exception) {
          if (!mounted) return;
          _showInvalidCodeMessage(exception.message);
          break;
        }
        if (!mounted) return;

        final sku = (roll['skuCode'] as String?)?.trim() ?? '';
        if (sku.isEmpty) {
          _showInvalidCodeMessage('This QR code is not linked to a material SKU.');
          break;
        }
        final useSku = await _showRollDetails(roll, scannedCode);
        if (!mounted) return;
        if (useSku == true) widget.controller.setSku(sku);
        setState(() => _hasScanned = false);
        await _scannerController.start();

        break;
      }
    }
  }

  void _showInvalidCodeMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 3),
        content: Text(
          '$message Scan a QR code generated for a registered roll.',
        ),
      ),
    );
    Future.delayed(const Duration(seconds: 3), () async {
      if (!mounted) return;
      setState(() => _hasScanned = false);
      await _scannerController.start();
    });
  }

  Future<bool?> _showRollDetails(
    Map<String, dynamic> roll,
    String scannedCode,
  ) => showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.check_circle_outline, color: Color(0xFFFFD700)),
          SizedBox(width: 10),
          Text('Roll scanned'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _rollDetail('Roll identifier', roll['rollIdentifier'] ?? scannedCode),
          _rollDetail('SKU', roll['skuCode'] ?? 'Unknown'),
          _rollDetail('Material', roll['materialName'] ?? 'Unknown'),
          _rollDetail('Initial quantity', '${roll['initialQuantity'] ?? 0}'),
          _rollDetail(
            'Remaining in this roll',
            '${roll['remainingQuantity'] ?? 0}',
          ),
          _rollDetail(
            'Current SKU stock',
            '${roll['currentSkuStock'] ?? 0}',
          ),
          _rollDetail('Status', roll['status'] ?? 'Unknown'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Use SKU'),
        ),
      ],
    ),
  );

  Widget _rollDetail(String label, Object value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          TextSpan(text: value.toString()),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    const yellowAccent = Color(0xFFFFD700);
    const darkBg = Color(0xFF121212);

    return Scaffold(
      backgroundColor: darkBg,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
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
          'SCAN INVENTORY ROLL',
          style: TextStyle(
            color: yellowAccent,
            fontWeight: FontWeight.bold,
            fontSize: 18,
            letterSpacing: 1.1,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Switch front or rear camera',
            icon: const Icon(Icons.cameraswitch_outlined, color: Colors.white),
            onPressed: () => _scannerController.switchCamera(),
          ),
          IconButton(
            tooltip: 'Toggle flashlight',
            icon: ValueListenableBuilder<MobileScannerState>(
              valueListenable: _scannerController,
              builder: (context, state, child) {
                if (state.torchState == TorchState.on) {
                  return const Icon(Icons.flash_on, color: yellowAccent);
                }
                return const Icon(Icons.flash_off, color: Colors.white70);
              },
            ),
            onPressed: () => _scannerController.toggleTorch(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Large centered camera viewport
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                MobileScanner(
                  controller: _scannerController,
                  onDetect: _handleBarcode,
                ),

                // Semi-transparent dark overlay mask
                ColorFiltered(
                  colorFilter: const ColorFilter.mode(
                    Color(0x8C000000),
                    BlendMode.srcOut,
                  ),
                  child: Stack(
                    children: [
                      Container(
                        decoration: const BoxDecoration(
                          color: Colors.black,
                          backgroundBlendMode: BlendMode.dstOut,
                        ),
                      ),
                      Align(
                        alignment: Alignment.center,
                        child: Container(
                          height: 260,
                          width: 260,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Yellow targeting frame overlay
                Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: yellowAccent,
                      width: 3,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33FFD700),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      _buildCornerAccent(Alignment.topLeft),
                      _buildCornerAccent(Alignment.topRight),
                      _buildCornerAccent(Alignment.bottomLeft),
                      _buildCornerAccent(Alignment.bottomRight),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Instructional text & manual fallback button below camera
          Container(
            color: darkBg,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              children: [
                const Text(
                  'Align QR code within the frame to track material usage.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 16),

                // Yellow text button "Enter SKU Manually"
                TextButton(
                  onPressed: _showManualSkuEntry,
                  child: const Text(
                    'Enter SKU Manually',
                    style: TextStyle(
                      color: yellowAccent,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                      decorationColor: yellowAccent,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCornerAccent(Alignment alignment) {
    const yellowAccent = Color(0xFFFFD700);

    return Align(
      alignment: alignment,
      child: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: yellowAccent,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }

  Future<void> _showManualSkuEntry() async {
    List<InventoryItemModel> inventoryItems = const [];
    List<PackagingTypeModel> packagingTypes = const [];
    List<RawMaterialModel> rawMaterials = const [];
    try {
      final catalogue = await Future.wait([
        _inventoryApi.fetchInventory(),
        _inventoryApi.fetchPackagingTypes(),
        _inventoryApi.fetchRawMaterials(),
      ]);
      inventoryItems = catalogue[0] as List<InventoryItemModel>;
      packagingTypes = catalogue[1] as List<PackagingTypeModel>;
      rawMaterials = catalogue[2] as List<RawMaterialModel>;
    } on ApiException catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(exception.message)));
      }
      return;
    }
    if (!mounted) return;

    await _scannerController.stop();
    final enteredSku = await showDialog<String>(
      context: context,
      builder: (_) => _ManualSkuDialog(
        inventoryItems: inventoryItems,
        packagingTypes: packagingTypes,
        rawMaterials: rawMaterials,
      ),
    );

    final sku = enteredSku?.trim();
    if (!mounted) return;
    if (sku == null || sku.isEmpty) {
      await _scannerController.start();
      return;
    }

    final matchingItem = inventoryItems
        .where((item) => _normalizeSku(item.sku) == _normalizeSku(sku))
        .firstOrNull;
    if (matchingItem == null || matchingItem.stockLevel <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('SKU is not a currently available inventory item.'),
          ),
        );
      }
      await _scannerController.start();
      return;
    }
    final useSku = await _showManualSkuDetails(matchingItem);
    if (!mounted) return;
    if (useSku == true) widget.controller.setSku(matchingItem.sku);
    await _scannerController.start();
  }

  Future<bool?> _showManualSkuDetails(InventoryItemModel item) =>
      showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.inventory_2_outlined, color: Color(0xFFFFD700)),
              SizedBox(width: 10),
              Text('Material selected'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _rollDetail('SKU', item.sku),
              _rollDetail('Material', item.name),
              _rollDetail('Current SKU stock', '${item.stockLevel}'),
              _rollDetail('Reorder level', '${item.reorderThreshold}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Use SKU'),
            ),
          ],
        ),
      );

}

/// Owns the field controller for the manual-SKU route.  This ensures Flutter
/// disposes it only after the dialog subtree is detached; disposing it as soon
/// as Navigator.pop completed caused the Cancel assertion seen on device.
class _ManualSkuDialog extends StatefulWidget {
  const _ManualSkuDialog({
    required this.inventoryItems,
    required this.packagingTypes,
    required this.rawMaterials,
  });

  final List<InventoryItemModel> inventoryItems;
  final List<PackagingTypeModel> packagingTypes;
  final List<RawMaterialModel> rawMaterials;

  @override
  State<_ManualSkuDialog> createState() => _ManualSkuDialogState();
}

class _ManualSkuDialogState extends State<_ManualSkuDialog> {
  final _formKey = GlobalKey<FormState>();
  int? _packagingTypeId;
  int? _rawMaterialId;
  String? _sku;

  @override
  void initState() {
    super.initState();
    _packagingTypeId = widget.packagingTypes
        .where((type) => _firstMaterialId(type.id) != null)
        .firstOrNull
        ?.id;
    _rawMaterialId = _firstMaterialId(_packagingTypeId);
    _sku = _skuOptions.firstOrNull?.sku;
  }

  List<RawMaterialModel> get _materialOptions => materialOptionsFor(
    _packagingTypeId,
    widget.rawMaterials,
  );

  List<InventoryItemModel> get _skuOptions {
    final selectedMaterial = materialById(
      widget.rawMaterials,
      _rawMaterialId,
    );
    if (_packagingTypeId == null || selectedMaterial == null) return const [];
    final options = widget.inventoryItems.where((item) {
      final itemMaterial = materialById(widget.rawMaterials, item.rawMaterialId);
      return item.stockLevel > 0 &&
          item.packagingTypeId == _packagingTypeId &&
          itemMaterial?.materialCode == selectedMaterial.materialCode;
    }).toList();
    options.sort((left, right) => (left.skuNumber ?? 0).compareTo(right.skuNumber ?? 0));
    return options;
  }

  int? _firstMaterialId(int? packagingTypeId) => materialOptionsFor(
    packagingTypeId,
    widget.rawMaterials,
  ).where((material) {
    final matches = widget.inventoryItems.where((item) {
      final itemMaterial = materialById(widget.rawMaterials, item.rawMaterialId);
      return item.stockLevel > 0 &&
          item.packagingTypeId == packagingTypeId &&
          itemMaterial?.materialCode == material.materialCode;
    });
    return matches.isNotEmpty;
  }).firstOrNull?.id;

  String _skuNumberLabel(InventoryItemModel item) =>
      item.skuNumber?.toString().padLeft(3, '0') ?? item.sku.split('-').last;

  void _useSku() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, _sku);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Select material SKU'),
    content: Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<int>(
            initialValue: _packagingTypeId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Packaging Type'),
            items: widget.packagingTypes
                .map(
                  (type) => DropdownMenuItem<int>(
                    value: type.id,
                    child: Text(type.name, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() {
              _packagingTypeId = value;
              _rawMaterialId = _firstMaterialId(value);
              _sku = _skuOptions.firstOrNull?.sku;
            }),
            validator: (value) =>
                value == null ? 'Select a packaging type.' : null,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _rawMaterialId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Raw Material'),
            items: _materialOptions
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
            onChanged: _packagingTypeId == null
                ? null
                : (value) => setState(() {
                    _rawMaterialId = value;
                    _sku = _skuOptions.firstOrNull?.sku;
                  }),
            validator: (value) => value == null ? 'Select a raw material.' : null,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _skuOptions.any((item) => item.sku == _sku)
                ? _sku
                : null,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'SKU Number',
              helperText: 'Only SKUs currently in stock are shown.',
            ),
            items: _skuOptions
                .map(
                  (item) => DropdownMenuItem<String>(
                    value: item.sku,
                    child: Text(
                      '${_skuNumberLabel(item)} (${item.stockLevel} units in stock)',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: _skuOptions.isEmpty
                ? null
                : (value) => setState(() => _sku = value),
            validator: (value) => value == null
                ? 'Select an SKU number with available stock.'
                : null,
          ),
          if (_sku != null) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'SKU preview: $_sku',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _useSku, child: const Text('Use SKU')),
    ],
  );
}

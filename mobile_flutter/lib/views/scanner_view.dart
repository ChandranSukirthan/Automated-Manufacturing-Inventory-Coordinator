import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../controllers/inventory_controller.dart';
import '../services/api_client.dart';
import '../services/inventory_api_service.dart';

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
        Map<String, dynamic>? roll;
        String? lookupError;
        try {
          roll = await _inventoryApi.lookupRoll(scannedCode);
        } on ApiException catch (exception) {
          lookupError = exception.message;
        }
        if (!mounted) return;

        widget.controller.setSku(
          (roll?['skuCode'] as String?)?.trim().isNotEmpty == true
            ? roll!['skuCode'] as String
            : scannedCode,
        );

        // Show yellow SnackBar saying "Scan Successful"
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFFFD700),
            duration: const Duration(seconds: 2),
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.black),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    roll == null
                      ? lookupError == null
                        ? 'Code captured: $scannedCode'
                        : 'Code captured; lookup unavailable'
                      : 'Roll found: ${roll['rollIdentifier'] ?? scannedCode}',
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            if (widget.onBack != null) {
              widget.onBack!();
            } else if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              setState(() {
                _hasScanned = false;
              });
            }
          }
        });

        break;
      }
    }
  }

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
    final skuController = TextEditingController(text: widget.controller.sku);
    String? enteredSku;
    try {
      enteredSku = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Enter material SKU'),
          content: TextField(
            controller: skuController,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Material SKU',
              hintText: 'e.g. CR-001',
            ),
            onSubmitted: (value) => Navigator.pop(dialogContext, value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, skuController.text),
              child: const Text('Use SKU'),
            ),
          ],
        ),
      );
    } finally {
      skuController.dispose();
    }

    final sku = enteredSku?.trim();
    if (sku == null || sku.isEmpty || !mounted) return;

    // Manual input must select a material that actually exists in the live
    // catalogue.  This prevents arbitrary text such as "Testsku" from being
    // carried into a low-stock alert as though it were an inventory item.
    try {
      final materials = await _inventoryApi.fetchRawMaterials();
      final normalizedSku = _normalizeSku(sku);
      final matchingMaterial = materials.where(
        (material) => _normalizeSku(material.skuCode) == normalizedSku,
      );
      if (matchingMaterial.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'SKU not found. Select an existing material from inventory.',
              ),
            ),
          );
        }
        return;
      }
      widget.controller.setSku(matchingMaterial.first.skuCode);
    } on ApiException catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(exception.message)),
        );
      }
      return;
    }

    // Do not add a snackbar or stop the camera while popping this route. The
    // old sequence raced the scanner's native view teardown and could cause a
    // Flutter render-tree assertion after manual entry.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.onBack != null) {
        widget.onBack!();
      } else if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    });
  }

  String _normalizeSku(String value) => value
      .trim()
      .toUpperCase()
      .replaceAll('-', '')
      .replaceAll(' ', '');
}

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../services/api_client.dart';
import '../services/quality_service.dart';
import '../widgets/app_widgets.dart';
import 'batch_details_screen.dart';

class BatchScanScreen extends StatefulWidget {
  const BatchScanScreen({required this.service, super.key});

  final QualityService service;

  @override
  State<BatchScanScreen> createState() => _BatchScanScreenState();
}

class _BatchScanScreenState extends State<BatchScanScreen> {
  bool _handlingScan = false;
  String? _error;

  Future<void> _handleScan(BarcodeCapture capture) async {
    if (_handlingScan) return;
    String? value;
    for (final barcode in capture.barcodes) {
      final scanned = barcode.rawValue?.trim();
      if (scanned != null && scanned.isNotEmpty) {
        value = scanned;
        break;
      }
    }
    if (value == null) return;

    setState(() {
      _handlingScan = true;
      _error = null;
    });
    try {
      final batch = await widget.service.getBatch(value);
      if (!mounted) return;
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => BatchDetailsScreen(
            service: widget.service,
            batch: batch,
          ),
        ),
      );
    } on ApiException catch (exception) {
      if (mounted) setState(() => _error = exception.message);
    } finally {
      if (mounted) setState(() => _handlingScan = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Scan batch QR')),
    body: Column(
      children: [
        Expanded(
          child: MobileScanner(onDetect: _handleScan),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Text('Point the camera at a batch or inventory QR code.'),
              if (_handlingScan) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                StateMessage(message: _error!, icon: Icons.qr_code_2),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}
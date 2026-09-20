import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../app_state.dart';
import '../qr_payload.dart';
import '../services/api_client.dart';
import '../services/quality_service.dart';
import '../widgets/app_widgets.dart';
import 'batch_details_screen.dart';

class BatchScanScreen extends StatefulWidget {
  const BatchScanScreen({
    required this.service,
    required this.appState,
    super.key,
  });

  final QualityService service;
  final AppState appState;

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
    if (value == null) {
      if (mounted) {
        setState(() => _error = 'The QR code did not contain a value.');
      }
      return;
    }

    setState(() {
      _handlingScan = true;
      _error = null;
    });
    try {
      final payload = QrPayload.parse(value);
      final batch = await widget.service.getBatch(payload.value);
      QrResolution.fromBatch(batch, payload.value);
      if (!mounted) return;
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) =>
              BatchDetailsScreen(service: widget.service, batch: batch),
        ),
      );
    } on ApiException catch (exception) {
      if (mounted) setState(() => _error = exception.message);
    } on QrPayloadException catch (exception) {
      if (mounted) setState(() => _error = exception.message);
    } finally {
      if (mounted) setState(() => _handlingScan = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.appState.isAuthenticated ||
        !widget.appState.session!.user.isQualityInspector) {
      return const Scaffold(
        body: StateMessage(
          message: 'Quality Inspector access is required to scan QR codes.',
          icon: Icons.lock_outline,
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Scan batch QR')),
      body: Column(
        children: [
          Expanded(
            child: MobileScanner(
              onDetect: _handleScan,
              errorBuilder: (context, error) => StateMessage(
                message: 'Unable to start the camera scanner: $error',
                icon: Icons.camera_alt_outlined,
              ),
            ),
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
}

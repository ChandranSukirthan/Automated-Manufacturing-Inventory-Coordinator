import 'package:flutter/material.dart';

/// Displays a QR code for an existing InventoryRoll through the ASP.NET Core
/// API. `apiBaseUrl` must end with `/api`; it is never a third-party QR URL.
class InventoryRollQrCode extends StatelessWidget {
  const InventoryRollQrCode({
    super.key,
    required this.rollIdentifier,
    required this.apiBaseUrl,
    required this.accessToken,
    this.size = 220,
  });

  final String rollIdentifier;
  final String apiBaseUrl;
  final String accessToken;
  final double size;

  @override
  Widget build(BuildContext context) {
    final identifier = rollIdentifier.trim();
    if (identifier.isEmpty) {
      return const Text('An inventory-roll identifier is required.');
    }

    final imageUrl = Uri.parse(
      '${apiBaseUrl.replaceFirst(RegExp(r'/$'), '')}'
      '/inventory/rolls/${Uri.encodeComponent(identifier)}/qr',
    );

    return Semantics(
      label: 'QR code for inventory roll $identifier',
      image: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          imageUrl.toString(),
          width: size,
          height: size,
          fit: BoxFit.contain,
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Accept': 'image/png',
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return SizedBox(
              width: size,
              height: size,
              child: const Center(child: CircularProgressIndicator()),
            );
          },
          errorBuilder: (context, error, stackTrace) => SizedBox(
            width: size,
            height: size,
            child: const Center(
              child: Text(
                'QR code unavailable',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LowStockAlert {
  final String packagingType;
  final String sku;
  final int quantityRequested;

  const LowStockAlert({
    required this.packagingType,
    required this.sku,
    required this.quantityRequested,
  });

  Map<String, dynamic> toJson() {
    return {
      'packagingType': packagingType,
      'sku': sku,
      'quantityRequested': quantityRequested,
    };
  }

  factory LowStockAlert.fromJson(Map<String, dynamic> json) {
    return LowStockAlert(
      packagingType: json['packagingType'] as String? ?? '',
      sku: json['sku'] as String? ?? '',
      quantityRequested: (json['quantityRequested'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  String toString() {
    return 'LowStockAlert(packagingType: $packagingType, sku: $sku, quantityRequested: $quantityRequested)';
  }
}

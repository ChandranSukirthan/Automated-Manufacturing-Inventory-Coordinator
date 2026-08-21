import 'package:flutter/material.dart';
import '../services/inventory_api_service.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final InventoryApiService _apiService = InventoryApiService();
  
  List<InventoryItemModel> _inventoryItems = [];
  List<StockAlertModel> _alerts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
    });
    
    // Fetch both inventory and alerts concurrently
    final results = await Future.wait([
      _apiService.fetchInventory(),
      _apiService.fetchAlerts(),
    ]);

    setState(() {
      _inventoryItems = results[0] as List<InventoryItemModel>;
      _alerts = results[1] as List<StockAlertModel>;
      _isLoading = false;
    });
  }

  bool _hasPredictiveAlert(String sku) {
    return _alerts.any((alert) => 
      alert.sku == sku && 
      alert.workerId.contains('Predictive') &&
      alert.status != 'Resolved' // Assuming they aren't resolved
    );
  }

  @override
  Widget build(BuildContext context) {
    const darkBg = Color(0xFF121212);
    const cardBg = Color(0xFF1E1E1E);
    const warningColor = Color(0xFFFF5252);
    const predictiveWarningColor = Colors.orange;

    return Scaffold(
      backgroundColor: darkBg,
      appBar: AppBar(
        backgroundColor: darkBg,
        elevation: 0,
        title: const Text(
          'LIVE INVENTORY',
          style: TextStyle(
            color: Color(0xFFFFD700),
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFFD700)),
            )
          : RefreshIndicator(
              color: const Color(0xFFFFD700),
              backgroundColor: cardBg,
              onRefresh: _fetchData,
              child: _inventoryItems.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 100),
                        Center(
                          child: Text(
                            'No inventory data available.',
                            style: TextStyle(color: Colors.white54),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16.0),
                      itemCount: _inventoryItems.length,
                      itemBuilder: (context, index) {
                        final item = _inventoryItems[index];
                        
                        final isLowStock = item.stockLevel <= item.reorderThreshold;
                        final hasPredictiveAlert = _hasPredictiveAlert(item.sku);
                        final isWarning = isLowStock || hasPredictiveAlert;

                        Color borderColor = Colors.white12;
                        if (isLowStock) {
                          borderColor = warningColor;
                        } else if (hasPredictiveAlert) {
                          borderColor = predictiveWarningColor;
                        }

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12.0),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: borderColor, width: isWarning ? 2.0 : 1.0),
                            boxShadow: isWarning ? [
                              BoxShadow(
                                color: borderColor.withValues(alpha: 0.3),
                                blurRadius: 8,
                                spreadRadius: 1,
                              )
                            ] : [],
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16.0),
                            title: Text(
                              item.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'SKU: \${item.sku}',
                                    style: const TextStyle(color: Colors.white70),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Stock: \${item.stockLevel} / Threshold: \${item.reorderThreshold}',
                                    style: TextStyle(
                                      color: isLowStock ? warningColor : Colors.white60,
                                      fontWeight: isLowStock ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                  if (hasPredictiveAlert && !isLowStock)
                                    const Padding(
                                      padding: EdgeInsets.only(top: 4.0),
                                      child: Text(
                                        'Predictive Alert Active (Forecasted Stockout)',
                                        style: TextStyle(
                                          color: predictiveWarningColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            trailing: isWarning 
                              ? Icon(
                                  Icons.warning_amber_rounded,
                                  color: borderColor,
                                  size: 32,
                                )
                              : const Icon(
                                  Icons.check_circle_outline,
                                  color: Colors.green,
                                  size: 32,
                                ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}

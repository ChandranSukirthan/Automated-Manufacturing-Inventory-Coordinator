import 'package:flutter/material.dart';
import '../controllers/inventory_controller.dart';
import '../services/inventory_api_service.dart';

class StockView extends StatefulWidget {
  final InventoryController controller;
  final VoidCallback? onBack;

  const StockView({
    super.key,
    required this.controller,
    this.onBack,
  });

  @override
  State<StockView> createState() => _StockViewState();
}

class _StockViewState extends State<StockView> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  
  final InventoryApiService _apiService = InventoryApiService();
  
  List<InventoryItemModel> _inventoryItems = [];
  List<StockAlertModel> _alerts = [];
  bool _isLoading = true;

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
    });
    
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
      alert.status != 'Resolved'
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const yellowAccent = Color(0xFFFFD700);
    const darkBg = Color(0xFF121212);
    const cardBg = Color(0xFF1E1E1E);

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
              'LIVE STOCK STATUS',
              style: TextStyle(
                color: yellowAccent,
                fontWeight: FontWeight.bold,
                fontSize: 18,
                letterSpacing: 1.1,
              ),
            ),
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Search Bar at the top (dark background with yellow focus border)
                TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Filter materials by SKU or name...',
                    hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
                    prefixIcon: const Icon(Icons.search, color: yellowAccent, size: 22),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.white54, size: 20),
                            onPressed: () => _searchController.clear(),
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFF1E1E1E),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                      borderSide: const BorderSide(color: yellowAccent, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                // ListView displaying current inventory items
                Expanded(
                  child: _isLoading 
                    ? const Center(
                        child: CircularProgressIndicator(color: yellowAccent),
                      )
                    : RefreshIndicator(
                        color: yellowAccent,
                        backgroundColor: cardBg,
                        onRefresh: _fetchData,
                        child: filteredItems.isEmpty
                          ? ListView(
                              children: [
                                const SizedBox(height: 100),
                                Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
                                      Icon(Icons.inventory_2_outlined, color: Colors.white24, size: 56),
                                      SizedBox(height: 12),
                                      Text(
                                        'No matching materials found',
                                        style: TextStyle(color: Colors.white54, fontSize: 15),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          : ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemCount: filteredItems.length,
                              separatorBuilder: (context, index) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final item = filteredItems[index];
                                return _buildStockItemCard(item: item, cardBg: cardBg);
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
    const yellowAccent = Color(0xFFFFD700);
    const predictiveWarningColor = Colors.orange;

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
    Color statusColor = const Color(0xFF4CAF50);
    Color statusBg = const Color(0x334CAF50);

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
        boxShadow: isWarning ? [
          BoxShadow(
            color: borderColor.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ] : const [
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

          // Right Column: Bold yellow stock quantity & Status Badge
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${item.stockLevel} Units',
                style: TextStyle(
                  color: isLowStock ? const Color(0xFFFF5252) : yellowAccent,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: statusColor,
                    width: 1,
                  ),
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
            ],
          ),
        ],
      ),
    );
  }
}

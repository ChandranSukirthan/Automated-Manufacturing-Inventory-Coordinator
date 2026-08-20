import 'package:flutter/material.dart';
import '../controllers/inventory_controller.dart';

class StockItem {
  final String name;
  final String sku;
  final int quantity;
  final String unit;
  final bool isLowStock;

  const StockItem({
    required this.name,
    required this.sku,
    required this.quantity,
    this.unit = 'Units',
    required this.isLowStock,
  });
}

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

  final List<StockItem> _defaultItems = const [
    StockItem(
      name: 'Polyethylene Film',
      sku: 'RM-PLASTIC-502',
      quantity: 150,
      isLowStock: true,
    ),
    StockItem(
      name: 'Box Pouch',
      sku: 'BX-POUCH-101',
      quantity: 850,
      isLowStock: false,
    ),
    StockItem(
      name: 'Biscuit Packaging',
      sku: 'PK-BISCUIT-04',
      quantity: 1200,
      isLowStock: false,
    ),
    StockItem(
      name: 'Tea Bag Roll',
      sku: 'TB-ROLL-88',
      quantity: 90,
      isLowStock: true,
    ),
    StockItem(
      name: 'Aluminum Can',
      sku: 'CN-ALUM-330',
      quantity: 3400,
      isLowStock: false,
    ),
    StockItem(
      name: 'Plastic Bottle',
      sku: 'BT-PET-500',
      quantity: 45,
      isLowStock: true,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
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
        // Build item list incorporating current controller SKU/quantity if set
        final List<StockItem> items = [
          if (widget.controller.sku.isNotEmpty)
            StockItem(
              name: '${widget.controller.packagingType} (Current Request)',
              sku: widget.controller.sku,
              quantity: widget.controller.quantityRequested,
              isLowStock: widget.controller.quantityRequested < 200,
            ),
          ..._defaultItems,
        ];

        final filteredItems = items.where((item) {
          if (_searchQuery.isEmpty) return true;
          return item.name.toLowerCase().contains(_searchQuery) ||
              item.sku.toLowerCase().contains(_searchQuery);
        }).toList();

        return Scaffold(
          // 1. Scaffold background must be dark (0xFF121212)
          backgroundColor: darkBg,

          // 2. AppBar: Bold yellow title "LIVE STOCK STATUS", white back button
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
                // 3. Search Bar at the top (dark background with yellow focus border)
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

                // 4. ListView displaying current inventory items
                Expanded(
                  child: filteredItems.isEmpty
                      ? Center(
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
                        )
                      : ListView.separated(
                          itemCount: filteredItems.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final item = filteredItems[index];
                            return _buildStockItemCard(item: item, cardBg: cardBg);
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 5. Dark Card (0xFF1E1E1E) with subtle border, material name, SKU, bold yellow stock numbers, status badge
  Widget _buildStockItemCard({
    required StockItem item,
    required Color cardBg,
  }) {
    const yellowAccent = Color(0xFFFFD700);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12, width: 1),
        boxShadow: const [
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
              ],
            ),
          ),

          // Right Column: Bold yellow stock quantity & Status Badge
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${item.quantity} ${item.unit}',
                style: const TextStyle(
                  color: yellowAccent,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: item.isLowStock
                      ? const Color(0x33FF5252)
                      : const Color(0x334CAF50),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: item.isLowStock
                        ? const Color(0xFFFF5252)
                        : const Color(0xFF4CAF50),
                    width: 1,
                  ),
                ),
                child: Text(
                  item.isLowStock ? 'Low Stock' : 'In Stock',
                  style: TextStyle(
                    color: item.isLowStock
                        ? const Color(0xFFFF5252)
                        : const Color(0xFF4CAF50),
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

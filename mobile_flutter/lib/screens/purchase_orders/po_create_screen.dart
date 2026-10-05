import 'package:flutter/material.dart';
import '../../models/purchase_order_models.dart';
import '../../services/purchase_order_service.dart';

class POCreateScreen extends StatefulWidget {
  const POCreateScreen({
    required this.service,
    this.materialId,
    this.sku,
    this.quantity,
    super.key,
  });

  final PurchaseOrderService service;
  final int? materialId;
  final String? sku;
  final num? quantity;

  @override
  State<POCreateScreen> createState() => _POCreateScreenState();
}

class _POCreateScreenState extends State<POCreateScreen> {
  bool _loading = false;
  List<SupplierSummary> _suppliers = [];
  int? _selectedSupplierId;
  final _quantityController = TextEditingController();
  final _budgetController = TextEditingController(text: '10000.00');
  
  @override
  void initState() {
    super.initState();
    if (widget.quantity != null) {
      _quantityController.text = widget.quantity.toString();
    }
    _loadSuppliers();
  }

  Future<void> _loadSuppliers() async {
    setState(() => _loading = true);
    try {
      final suppliers = await widget.service.getSuppliers();
      if (mounted) {
        setState(() {
          _suppliers = suppliers;
          _selectedSupplierId = suppliers.isNotEmpty ? suppliers.first.id : null;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createManualPo() async {
    if (_selectedSupplierId == null) return;

    setState(() => _loading = true);
    try {
      final poData = {
        'supplierId': _selectedSupplierId,
        'currency': 'LKR',
        'budgetLimit': double.parse(_budgetController.text),
        'notes': 'Manual Purchase Order generated from mobile',
        'lines': [
          {
            'rawMaterialId': widget.materialId ?? 1,
            'description': 'Reorder for SKU: ${widget.sku ?? "UNKNOWN"}',
            'quantity': double.parse(_quantityController.text),
            'unitPrice': 15.50, // default or fetch from material
          }
        ]
      };

      final createdPo = await widget.service.createPurchaseOrder(poData);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Draft PO Created! Please submit for approval.'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, createdPo);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create PO: $e'), backgroundColor: Colors.red),
        );
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      appBar: AppBar(
        title: const Text('Create Manual PO'),
        backgroundColor: const Color(0xFF0F172A),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text('Select Supplier', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  initialValue: _selectedSupplierId,
                  dropdownColor: const Color(0xFF1E293B),
                  style: const TextStyle(color: Colors.white),
                  items: _suppliers.map((s) => DropdownMenuItem(
                    value: s.id,
                    child: Text(s.name),
                  )).toList(),
                  onChanged: (val) => setState(() => _selectedSupplierId = val),
                  decoration: const InputDecoration(
                    filled: true,
                    fillColor: Color(0xFF1E293B),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Quantity', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _quantityController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    filled: true,
                    fillColor: Color(0xFF1E293B),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Budget Limit (LKR)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _budgetController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    filled: true,
                    fillColor: Color(0xFF1E293B),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: _createManualPo,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: const Color(0xFF3B82F6),
                  ),
                  child: const Text('Create Draft PO', style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ],
            ),
    );
  }
}

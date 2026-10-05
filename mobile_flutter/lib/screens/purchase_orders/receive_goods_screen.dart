import 'package:flutter/material.dart';
import '../../services/api_client.dart';

class ReceiveGoodsScreen extends StatefulWidget {
  const ReceiveGoodsScreen({required this.purchaseOrderId, this.api, super.key});
  final int purchaseOrderId;
  final ApiClient? api;
  @override
  State<ReceiveGoodsScreen> createState() => _ReceiveGoodsScreenState();
}

class _ReceiveGoodsScreenState extends State<ReceiveGoodsScreen> {
  late final ApiClient _api = widget.api ?? ApiClient();
  final _formKey = GlobalKey<FormState>();
  final _quantity = TextEditingController();
  final _roll = TextEditingController();
  final _batch = TextEditingController();
  Map<String, dynamic>? _po;
  List<dynamic> _receipts = [];
  int? _lineId;
  bool _busy = false;
  String? _error;
  String _receiptKey = 'MOBILE-${DateTime.now().microsecondsSinceEpoch}';
  String get _path => '/purchase-orders/${widget.purchaseOrderId}';
  List<dynamic> get _lines => (_po?['orderLines'] ?? _po?['lines'] ?? []) as List<dynamic>;
  double _remaining(dynamic line) => (line['quantity'] as num).toDouble() - _receipts.where((r) => r['orderLineId'] == line['id']).fold<double>(0, (sum, r) => sum + (r['quantity'] as num).toDouble());

  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try {
      final values = await Future.wait([_api.get(_path), _api.get('$_path/receipts')]);
      if (mounted) setState(() { _po = values[0] as Map<String, dynamic>; _receipts = values[1] as List<dynamic>; _error = null; });
    } catch (error) { if (mounted) setState(() => _error = error.toString()); }
  }
  Future<void> _receive() async {
    if (!_formKey.currentState!.validate() || _lineId == null) return;
    setState(() { _busy = true; _error = null; });
    try {
      await _api.post('$_path/receipts', {'receiptKey': _receiptKey, 'orderLineId': _lineId, 'quantity': int.parse(_quantity.text), 'rollIdentifier': _roll.text.trim(), 'batchId': _batch.text.trim()});
      // Keep the key on failure so a network retry cannot count the same shipment twice.
      _receiptKey = 'MOBILE-${DateTime.now().microsecondsSinceEpoch}';
      _quantity.clear(); _roll.clear(); _batch.clear(); _lineId = null;
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Delivery received and stock updated.')));
    } catch (error) { if (mounted) setState(() => _error = error.toString()); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  @override
  void dispose() { _quantity.dispose(); _roll.dispose(); _batch.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final canReceive = ['Sent', 'InTransit'].contains(_po?['status']);
    return Scaffold(appBar: AppBar(title: const Text('Delivery receipts'), actions: [IconButton(onPressed: _busy ? null : _load, icon: const Icon(Icons.refresh))]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
        if (_po == null && _error == null) const Center(child: CircularProgressIndicator()),
        ..._receipts.map((r) => ListTile(title: Text('${r['rollIdentifier']} · ${r['quantity']} units'), subtitle: Text('Batch ${r['batchId']} · ${r['receivedAt']}'))),
        if (_po != null && _receipts.isEmpty) const Text('No arrivals recorded.'),
        if (canReceive) Form(key: _formKey, child: Column(children: [
          const Text('Record the physical quantity received for each roll. Partial delivery leaves the balance open.'),
          DropdownButtonFormField<int>(initialValue: _lineId, decoration: const InputDecoration(labelText: 'Order line'),
            items: _lines.where((line) => _remaining(line) > 0).map((line) => DropdownMenuItem(value: (line['id'] as num).toInt(), child: Text('${line['rawMaterialName'] ?? line['description']} · ${_remaining(line)} remaining'))).toList(),
            onChanged: _busy ? null : (value) => setState(() => _lineId = value), validator: (value) => value == null ? 'Choose a material' : null),
          TextFormField(controller: _quantity, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantity received'), validator: (value) => (int.tryParse(value ?? '') ?? 0) > 0 ? null : 'Enter positive whole units'),
          TextFormField(controller: _roll, maxLength: 120, decoration: const InputDecoration(labelText: 'Physical roll identifier'), validator: (value) => (value ?? '').trim().isEmpty ? 'Required' : null),
          TextFormField(controller: _batch, maxLength: 80, decoration: const InputDecoration(labelText: 'Batch identifier'), validator: (value) => (value ?? '').trim().isEmpty ? 'Required' : null),
          ElevatedButton(onPressed: _busy ? null : _receive, child: Text(_busy ? 'Recording…' : 'Record arrival')),
        ])),
      ]));
  }
}

import 'package:flutter/material.dart';

import '../models/worker_workflow_models.dart';
import '../services/api_client.dart';
import '../services/inventory_api_service.dart';
import '../services/quality_service.dart';
import '../views/scanner_view.dart';
import '../controllers/inventory_controller.dart';
import '../views/stock_view.dart';

class WorkerDashboardScreen extends StatefulWidget {
  const WorkerDashboardScreen({required this.qualityService, super.key});

  final QualityService qualityService;

  @override
  State<WorkerDashboardScreen> createState() => _WorkerDashboardScreenState();
}

class _WorkerDashboardScreenState extends State<WorkerDashboardScreen> {
  final _inventory = InventoryApiService();
  final _controller = InventoryController();
  int _index = 0;
  bool _loading = true;
  String? _error;
  List<InventoryItemModel> _items = [];
  List<InventoryRollModel> _rolls = [];
  List<RawMaterialModel> _materials = [];
  List<Map<String, dynamic>> _levels = [];
  List<StockAlertModel> _alerts = [];
  List<Map<String, dynamic>> _history = [];
  WorkerWorkflowResult? _workflow;
  String? _selectedMaterial;
  int? _selectedHistoryMaterialId;
  num _requiredQuantity = 2000;
  bool _triggeringAi = false;
  String _alertFilter = 'All';

  static const _tabs = [
    'Raw Materials & Items',
    'Inventory Rolls',
    'Stock Levels & Burn Rate',
    'Low Stock Alerts',
    'Inventory History',
    'AI Agent Coordinator',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _inventory.fetchOwnedInventory(),
        _inventory.fetchOwnedRolls(),
        _inventory.fetchRawMaterials(),
        _inventory.fetchStockLevels(),
        _inventory.fetchAlerts(),
      ]);
      if (!mounted) return;
      final materials = results[2] as List<RawMaterialModel>;
      final selectedHistoryId =
          _selectedHistoryMaterialId != null &&
              materials.any(
                (material) => material.id == _selectedHistoryMaterialId,
              )
          ? _selectedHistoryMaterialId
          : materials.firstOrNull?.id;
      setState(() {
        _items = results[0] as List<InventoryItemModel>;
        _rolls = results[1] as List<InventoryRollModel>;
        _materials = materials;
        _levels = results[3] as List<Map<String, dynamic>>;
        _alerts = results[4] as List<StockAlertModel>;
        _selectedMaterial ??= _levels.isNotEmpty
            ? _levels.first['skuCode']?.toString()
            : _materials.isNotEmpty
            ? _materials.first.skuCode
            : null;
        _selectedHistoryMaterialId = selectedHistoryId;
        _loading = false;
      });
      if (selectedHistoryId != null) {
        final history = await _inventory.fetchHistory(selectedHistoryId);
        if (mounted) {
          setState(() => _history = history);
        }
      }
    } on ApiException catch (exception) {
      if (mounted) {
        setState(() {
          _error = exception.message;
          _loading = false;
        });
      }
    }
  }

  Future<void> _runAiForMaterial(String materialId, num quantity) async {
    if (materialId.isEmpty || quantity < 100 || quantity % 100 != 0) {
      setState(
        () => _error = 'Quantity must be at least 100 and increase by 100.',
      );
      return;
    }
    setState(() {
      _triggeringAi = true;
      _error = null;
    });
    try {
      final result = await _inventory.triggerReplenishment(
        materialId: materialId,
        requiredQuantity: quantity,
      );
      if (mounted) {
        setState(() {
          _workflow = result;
          _triggeringAi = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Replenishment workflow initiated!')),
        );
        await _load();
      }
    } on ApiException catch (exception) {
      if (mounted) {
        setState(() {
          _error = exception.message;
          _triggeringAi = false;
        });
      }
    }
  }

  Future<void> _runAi() async {
    final materialId =
        _selectedMaterial ??
        (_levels.isNotEmpty
            ? _levels.first['skuCode']?.toString()
            : _materials.firstOrNull?.skuCode);
    if (materialId == null || materialId.isEmpty) return;
    await _runAiForMaterial(materialId, _requiredQuantity);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_tabs[_index]),
        actions: [
          IconButton(
            tooltip: 'Scan inventory roll',
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () => Navigator.push<void>(
              context,
              MaterialPageRoute(
                builder: (_) => ScannerView(controller: _controller),
              ),
            ),
          ),
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error!, textAlign: TextAlign.center),
              ),
            )
          : IndexedStack(
              index: _index,
              children: [
                _inventoryTab(),
                _rollsTab(),
                _levelsTab(),
                _alertsTab(),
                _historyTab(),
                _agentTab(),
              ],
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            label: 'Items',
          ),
          NavigationDestination(icon: Icon(Icons.qr_code_2), label: 'Rolls'),
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            label: 'Stock',
          ),
          NavigationDestination(
            icon: Icon(Icons.warning_amber),
            label: 'Alerts',
          ),
          NavigationDestination(icon: Icon(Icons.history), label: 'History'),
          NavigationDestination(
            icon: Icon(Icons.smart_toy_outlined),
            label: 'AI Agent',
          ),
        ],
      ),
    );
  }

  Widget _inventoryTab() => StockView(
    controller: _controller,
    triggeringAi: _triggeringAi,
    onTriggerAi: _runAiForMaterial,
  );

  Widget _rollsTab() => _rolls.isEmpty
      ? const Center(child: Text('No rolls created for this account.'))
      : ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _rolls.length,
          itemBuilder: (_, index) {
            final roll = _rolls[index];
            final material = _materials
                .where((item) => item.id == roll.rawMaterialId)
                .firstOrNull;
            return Card(
              child: ListTile(
                leading: const Icon(Icons.qr_code_2),
                title: Text(roll.rollIdentifier),
                subtitle: Text(
                  '${material?.skuCode ?? 'Unknown SKU'} • ${roll.currentQuantity} / ${roll.initialQuantity} units',
                ),
                trailing: Text(roll.status),
              ),
            );
          },
        );

  Widget _levelsTab() => _levels.isEmpty
      ? const Center(child: Text('No stock level data'))
      : ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _levels.length,
          itemBuilder: (_, index) {
            final level = _levels[index];
            final status = level['status']?.toString() ?? 'NORMAL';
            final sku = level['skuCode']?.toString() ?? '';
            final needsReorder = status == 'CRITICAL' || status == 'LOW';
            final hasActiveAlert = _alerts.any(
              (alert) =>
                  alert.sku.toLowerCase() == sku.toLowerCase() &&
                  const [
                    'Pending',
                    'Processing',
                    'Acknowledged',
                  ].contains(alert.status),
            );
            return Card(
              child: ListTile(
                title: Text(
                  level['materialName']?.toString() ??
                      level['skuCode']?.toString() ??
                      '',
                ),
                subtitle: Text(
                  '${level['skuCode'] ?? ''} • Burn rate: ${level['burnRate'] ?? 0} KG/day • ${level['daysRemaining'] ?? 0} days left',
                ),
                trailing: needsReorder
                    ? hasActiveAlert
                          ? const Text('In Progress')
                          : TextButton.icon(
                              onPressed: _triggeringAi
                                  ? null
                                  : () => _runAiForMaterial(sku, 2000),
                              icon: const Icon(Icons.auto_awesome, size: 16),
                              label: const Text('Reorder via AI'),
                            )
                    : Text(status),
              ),
            );
          },
        );

  Widget _alertsTab() {
    final filteredAlerts = _alertFilter == 'All'
        ? _alerts
        : _alerts.where((alert) => alert.status == _alertFilter).toList();
    const filters = [
      'All',
      'Pending',
      'Processing',
      'Acknowledged',
      'Resolved',
      'Dismissed',
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        FilledButton.icon(
          onPressed: _showAlertForm,
          icon: const Icon(Icons.add_alert),
          label: const Text('Log Low Stock Alert'),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: filters.map((filter) {
              final count = filter == 'All'
                  ? _alerts.length
                  : _alerts.where((alert) => alert.status == filter).length;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text('$filter ($count)'),
                  selected: _alertFilter == filter,
                  onSelected: (_) => setState(() => _alertFilter = filter),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
        if (filteredAlerts.isEmpty)
          Text(
            _alertFilter == 'All'
                ? 'All clear. No stock alerts logged.'
                : 'No $_alertFilter alerts.',
          )
        else
          ...filteredAlerts.map(
            (alert) => Card(
              child: ListTile(
                title: Text(alert.sku),
                subtitle: Text(
                  '${alert.packagingType} • Requested: ${alert.quantityRequested} units',
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (status) async {
                    await _inventory.updateAlertStatus(alert.id, status);
                    await _load();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'Acknowledged',
                      child: Text('Acknowledged'),
                    ),
                    PopupMenuItem(value: 'Resolved', child: Text('Resolved')),
                    PopupMenuItem(value: 'Dismissed', child: Text('Dismissed')),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _historyTab() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      const Text('Select Material:'),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _materials
            .map(
              (material) => ChoiceChip(
                label: Text('${material.skuCode} - ${material.name}'),
                selected: _selectedHistoryMaterialId == material.id,
                onSelected: (_) async {
                  setState(() => _selectedHistoryMaterialId = material.id);
                  final history = await _inventory.fetchHistory(material.id);
                  if (mounted) setState(() => _history = history);
                },
              ),
            )
            .toList(),
      ),
      const SizedBox(height: 16),
      if (_history.isEmpty)
        const Padding(
          padding: EdgeInsets.only(top: 40),
          child: Center(child: Text('No transactions recorded')),
        )
      else
        ..._history.map(
          (entry) => Card(
            child: ListTile(
              title: Text(entry['transactionType']?.toString() ?? ''),
              subtitle: Text(
                '${entry['reason'] ?? ''} • ${entry['quantity'] ?? 0} KG',
              ),
              trailing: Text(entry['newStock']?.toString() ?? ''),
            ),
          ),
        ),
    ],
  );

  Widget _agentTab() {
    final materialOptions = _levels.isNotEmpty
        ? _levels
              .map(
                (level) => <String, String>{
                  'sku': level['skuCode']?.toString() ?? '',
                  'name': level['materialName']?.toString() ?? '',
                },
              )
              .where((material) => material['sku']!.isNotEmpty)
              .toList()
        : _materials
              .map(
                (material) => <String, String>{
                  'sku': material.skuCode,
                  'name': material.name,
                },
              )
              .toList();

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16,
          constraints.maxHeight < 600 ? 12 : 24,
          16,
          24,
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: Icon(Icons.smart_toy_outlined, size: 48)),
              const SizedBox(height: 16),
              const Text(
                'LangGraph Multi-Agent Workflow',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Trigger autonomous replenishment through the ASP.NET Core API Gateway.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              if (materialOptions.isEmpty)
                const Text('No materials available for replenishment.')
              else ...[
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue:
                      materialOptions.any(
                        (material) => material['sku'] == _selectedMaterial,
                      )
                      ? _selectedMaterial
                      : materialOptions.first['sku'],
                  decoration: const InputDecoration(labelText: 'Material'),
                  items: materialOptions
                      .map(
                        (material) => DropdownMenuItem<String>(
                          value: material['sku'],
                          child: Text(
                            '${material['sku']} - ${material['name']}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: _triggeringAi
                      ? null
                      : (value) => setState(() => _selectedMaterial = value),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: _requiredQuantity.toString(),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Quantity (KG)'),
                  onChanged: (value) {
                    final parsed = num.tryParse(value);
                    if (parsed != null) _requiredQuantity = parsed;
                  },
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _triggeringAi ? null : _runAi,
                    icon: _triggeringAi
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome),
                    label: Text(
                      _triggeringAi ? 'Initiating...' : 'Run Auto Replenishment',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              if (_workflow != null) ...[
                const SizedBox(height: 20),
                _workflowResultCard(_workflow!),
              ],
            ],
        ),
      ),
    );
  }

  Widget _workflowResultCard(WorkerWorkflowResult result) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Workflow: ${result.workflowId ?? 'Active'}'),
          Text('Status: ${result.status ?? 'Active'}'),
          Text('Current Agent: ${result.currentAgent ?? 'Completed'}'),
          Text('Approval: ${result.approvalStatus ?? 'Pending'}'),
          Text('Requires Approval: ${result.requiresApproval ? 'Yes' : 'No'}'),
          if (result.materialName != null)
            Text(
              'Material: ${result.materialSku ?? ''} - ${result.materialName}',
            ),
          if (result.objective != null) Text('Objective: ${result.objective}'),
          if (result.poNumber != null) ...[
            const Divider(),
            Text('PO Generated: ${result.poNumber}'),
            Text('Supplier: ${result.supplierName ?? 'Unknown'}'),
            Text('Quantity: ${result.quantity ?? _requiredQuantity} units'),
            Text('Unit Price: ${result.unitPrice ?? 0}'),
            Text('Total Amount: ${result.totalAmount ?? 0}'),
            const SizedBox(height: 8),
            Text(
              result.requiresApproval
                  ? 'Pending Manager Approval'
                  : 'Workflow Completed',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: result.requiresApproval ? Colors.orange : Colors.green,
              ),
            ),
          ],
        ],
      ),
    ),
  );

  Future<void> _showAlertForm() async {
    final sku = TextEditingController(
      text: _items.isEmpty ? '' : _items.first.sku,
    );
    final packaging = TextEditingController(
      text: _items.isEmpty ? 'Standard Roll' : _items.first.category,
    );
    final quantity = TextEditingController(text: '500');
    final formKey = GlobalKey<FormState>();
    try {
      final saved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Log Low Stock Alert'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: sku,
                    decoration: const InputDecoration(
                      labelText: 'Material SKU',
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Material SKU is required.'
                        : null,
                  ),
                  TextFormField(
                    controller: packaging,
                    decoration: const InputDecoration(
                      labelText: 'Packaging Type',
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Packaging Type is required.'
                        : null,
                  ),
                  TextFormField(
                    controller: quantity,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Quantity Requested',
                    ),
                    validator: (value) =>
                        int.tryParse(value ?? '') == null ||
                            int.parse(value!) <= 0
                        ? 'Enter a positive quantity.'
                        : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final normalizedSku = sku.text.trim().toLowerCase();
                final duplicate = _alerts
                    .where(
                      (alert) =>
                          alert.sku.trim().toLowerCase() == normalizedSku &&
                          const [
                            'Pending',
                            'Processing',
                            'Acknowledged',
                          ].contains(alert.status),
                    )
                    .firstOrNull;
                if (duplicate != null) {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(
                        content: Text(
                          'An active replenishment alert (${duplicate.status}) already exists for ${sku.text.trim()}.',
                        ),
                      ),
                    );
                  }
                  return;
                }
                try {
                  await _inventory.createAlert(
                    sku: sku.text.trim(),
                    packagingType: packaging.text.trim(),
                    quantityRequested: int.parse(quantity.text),
                  );
                  if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                } on ApiException catch (exception) {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(
                      dialogContext,
                    ).showSnackBar(SnackBar(content: Text(exception.message)));
                  }
                }
              },
              child: const Text('Log Alert'),
            ),
          ],
        ),
      );
      if (saved == true && mounted) await _load();
    } finally {
      sku.dispose();
      packaging.dispose();
      quantity.dispose();
    }
  }
}

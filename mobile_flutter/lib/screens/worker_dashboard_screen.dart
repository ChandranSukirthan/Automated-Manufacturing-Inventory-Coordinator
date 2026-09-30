import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../services/api_client.dart';
import '../services/inventory_api_service.dart';
import '../services/quality_service.dart';
import '../views/scanner_view.dart';
import '../controllers/inventory_controller.dart';
import '../views/stock_view.dart';
import '../widgets/catalog_sku_fields.dart';

class WorkerDashboardScreen extends StatefulWidget {
  const WorkerDashboardScreen({
    required this.qualityService,
    this.initialIndex = 0,
    super.key,
  });

  final QualityService qualityService;
  final int initialIndex;

  @override
  State<WorkerDashboardScreen> createState() => _WorkerDashboardScreenState();
}

class _WorkerDashboardScreenState extends State<WorkerDashboardScreen> {
  final _inventory = InventoryApiService();
  final _controller = InventoryController();
  late int _index;
  bool _loading = true;
  String? _error;
  List<InventoryItemModel> _items = [];
  List<InventoryRollModel> _rolls = [];
  List<RawMaterialModel> _materials = [];
  List<PackagingTypeModel> _packagingTypes = [];
  List<Map<String, dynamic>> _levels = [];
  List<StockAlertModel> _alerts = [];
  List<Map<String, dynamic>> _history = [];
  Map<String, dynamic>? _analysis;
  String? _selectedMaterial;
  int? _selectedHistoryMaterialId;
  bool _analyzing = false;
  String _alertFilter = 'All';

  static const _tabs = [
    'Raw Materials & Items',
    'Inventory Rolls',
    'Stock Levels & Burn Rate',
    'Low Stock Alerts',
    'Inventory History',
    'Data Extraction Agent',
  ];

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, _tabs.length - 1).toInt();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<T> _loadSection<T>(
    Future<T> Function() request,
    T fallback,
    List<String> failures,
  ) async {
    try {
      return await request();
    } on ApiException catch (exception) {
      failures.add(exception.message);
      return fallback;
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final failures = <String>[];
    final items = await _loadSection(
      _inventory.fetchOwnedInventory,
      const <InventoryItemModel>[],
      failures,
    );
    final rolls = await _loadSection(
      _inventory.fetchOwnedRolls,
      const <InventoryRollModel>[],
      failures,
    );
    final materials = await _loadSection(
      _inventory.fetchRawMaterials,
      const <RawMaterialModel>[],
      failures,
    );
    final levels = await _loadSection(
      _inventory.fetchStockLevels,
      const <Map<String, dynamic>>[],
      failures,
    );
    final alerts = await _loadSection(
      _inventory.fetchAlerts,
      const <StockAlertModel>[],
      failures,
    );
    final packagingTypes = await _loadSection(
      _inventory.fetchPackagingTypes,
      const <PackagingTypeModel>[],
      failures,
    );
    if (!mounted) return;
    final selectedHistoryId =
        _selectedHistoryMaterialId != null &&
            materials.any(
              (material) => material.id == _selectedHistoryMaterialId,
            )
        ? _selectedHistoryMaterialId
        : materials.firstOrNull?.id;
    setState(() {
      _items = items;
      _rolls = rolls;
      _materials = materials;
      _packagingTypes = packagingTypes;
      _levels = levels;
      _alerts = alerts;
      _selectedMaterial ??= _levels.isNotEmpty
          ? _levels.first['skuCode']?.toString()
          : _materials.isNotEmpty
          ? _materials.first.skuCode
          : null;
      _selectedHistoryMaterialId = selectedHistoryId;
      _error = failures.isEmpty
          ? null
          : 'Some live inventory data is unavailable. Pull down or tap Retry to refresh.';
      _loading = false;
    });
    if (selectedHistoryId != null) {
      final history = await _loadSection(
        () => _inventory.fetchHistory(selectedHistoryId),
        const <Map<String, dynamic>>[],
        failures,
      );
      if (mounted) {
        setState(() {
          _history = history;
          _error = failures.isEmpty
              ? null
              : 'Some live inventory data is unavailable. Pull down or tap Retry to refresh.';
        });
      }
    }
  }

  Future<void> _openDataExtraction(String sku, num _) async {
    if (!mounted) return;
    setState(() {
      _selectedMaterial = sku;
      _analysis = null;
      _index = 5;
    });
  }

  Future<void> _openScanner() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => ScannerView(controller: _controller)),
    );
    if (mounted) await _load();
  }

  Future<void> _runDataExtraction() async {
    final materialSku = _selectedMaterial ?? _allMaterialOptions().firstOrNull?['sku'];
    if (materialSku == null || materialSku.isEmpty) {
      setState(() => _error = 'Select a material before analysing its stock data.');
      return;
    }

    setState(() {
      _analyzing = true;
      _error = null;
    });
    try {
      final levels = await _inventory.fetchStockLevels();
      final analysis = levels
          .where((level) =>
              level['skuCode']?.toString().toLowerCase() == materialSku.toLowerCase())
          .firstOrNull;
      if (!mounted) return;
      if (analysis == null) {
        setState(() {
          _levels = levels;
          _analysis = null;
          _error = 'No stock record exists yet for $materialSku.';
          _analyzing = false;
        });
        return;
      }
      setState(() {
        _levels = levels;
        _analysis = analysis;
        _analyzing = false;
      });
    } on ApiException catch (exception) {
      if (mounted) {
        setState(() {
          _error = exception.message;
          _analyzing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          tooltip: 'Back to Factory Assistant',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.maybePop(context),
        ),
        titleSpacing: 0,
        title: Text(_tabs[_index]),
        actions: [
          IconButton(
            tooltip: 'Scan inventory roll',
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: _openScanner,
          ),
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_error != null)
                  MaterialBanner(
                    backgroundColor: const Color(0xFF3A2424),
                    content: Text(_error!),
                    leading: const Icon(Icons.cloud_off_outlined),
                    actions: [
                      TextButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                Expanded(
                  child: IndexedStack(
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
                ),
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
            label: 'Data Agent',
          ),
        ],
      ),
    );
  }

  Widget _inventoryTab() => StockView(
    controller: _controller,
    onTriggerAi: _openDataExtraction,
  );

  Widget _rollsTab() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF161B2E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF2A3958)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.qr_code_scanner, color: AppColors.primaryLight),
                SizedBox(width: 10),
                Text(
                  'QR roll scanner',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Scan a material roll to identify its SKU and update the worker workspace.',
              style: TextStyle(color: AppColors.mutedText),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _openScanner,
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Open QR scanner'),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      Text(
        'Registered rolls (${_rolls.length})',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 8),
      if (_rolls.isEmpty)
        const Card(
          child: Padding(
            padding: EdgeInsets.all(18),
            child: Text('No rolls are registered yet. Scan or register a roll from the Inventory tab.'),
          ),
        )
      else
        ..._rolls.map((roll) {
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
        }),
    ],
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
                    ? TextButton.icon(
                              onPressed: () => _openDataExtraction(sku, 0),
                              icon: const Icon(Icons.auto_awesome, size: 16),
                              label: const Text('Analyze data'),
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

  List<Map<String, String>> _allMaterialOptions() {
    final optionsBySku = <String, Map<String, String>>{};
    void addMaterial(String sku, String name) {
      final cleanedSku = sku.trim();
      if (cleanedSku.isEmpty) return;
      optionsBySku.putIfAbsent(cleanedSku.toLowerCase(), () => {
        'sku': cleanedSku,
        'name': name.trim().isEmpty ? cleanedSku : name.trim(),
      });
    }

    for (final material in _materials) {
      addMaterial(material.skuCode, material.name);
    }
    for (final level in _levels) {
      addMaterial(
        level['skuCode']?.toString() ?? '',
        level['materialName']?.toString() ?? '',
      );
    }
    for (final item in _items) {
      addMaterial(item.sku, item.name);
    }
    return optionsBySku.values.toList()
      ..sort((left, right) => left['name']!.compareTo(right['name']!));
  }

  Widget _agentTab() {
    final materialOptions = _allMaterialOptions();

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
                'Data Extraction Agent',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Reads live stock, burn rate, days remaining, and low-stock status for the selected material.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              if (materialOptions.isEmpty)
                const Text('No materials are available yet. Add or refresh inventory materials first.')
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
                  onChanged: _analyzing
                      ? null
                      : (value) => setState(() => _selectedMaterial = value),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _analyzing ? null : _runDataExtraction,
                    icon: _analyzing
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome),
                    label: Text(
                      _analyzing ? 'Analysing...' : 'Analyze selected material',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              if (_analysis != null) ...[
                const SizedBox(height: 20),
                _analysisResultCard(_analysis!),
              ],
            ],
        ),
      ),
    );
  }

  Widget _analysisResultCard(Map<String, dynamic> result) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Live data extraction result',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text('Material: ${result['skuCode'] ?? ''} - ${result['materialName'] ?? ''}'),
          Text('Current stock: ${result['currentStock'] ?? 0}'),
          Text('Minimum stock: ${result['minimumStock'] ?? 0}'),
          Text('Burn rate: ${result['burnRate'] ?? 0} per day'),
          Text('Days remaining: ${result['daysRemaining'] ?? 0}'),
          const SizedBox(height: 8),
          Text(
            'Status: ${result['status'] ?? 'Unknown'}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: (result['status']?.toString() == 'NORMAL')
                  ? Colors.green
                  : Colors.orange,
            ),
          ),
        ],
      ),
    ),
  );

  Future<void> _showAlertForm() async {
    final skuNumber = TextEditingController();
    final quantity = TextEditingController(text: '500');
    final formKey = GlobalKey<FormState>();
    int? packagingTypeId = _packagingTypes.firstOrNull?.id;
    int? rawMaterialId = materialOptionsFor(packagingTypeId, _materials)
        .firstOrNull
        ?.id;
    try {
      final saved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
          title: const Text('Log Low Stock Alert'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CatalogSkuFields(
                    packagingTypes: _packagingTypes,
                    rawMaterials: _materials,
                    packagingTypeId: packagingTypeId,
                    rawMaterialId: rawMaterialId,
                    skuNumberController: skuNumber,
                    onPackagingTypeChanged: (value) => setDialogState(() {
                      packagingTypeId = value;
                      rawMaterialId = materialOptionsFor(
                        value,
                        _materials,
                      ).firstOrNull?.id;
                      skuNumber.clear();
                    }),
                    onRawMaterialChanged: (value) => setDialogState(() {
                      rawMaterialId = value;
                      skuNumber.clear();
                    }),
                    onSkuNumberChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 12),
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
                final packaging = packagingById(_packagingTypes, packagingTypeId)!;
                final material = materialById(_materials, rawMaterialId)!;
                final fullSku = buildSku(packaging, material, skuNumber.text);
                final normalizedSku = fullSku.toLowerCase();
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
                          'An active alert (${duplicate.status}) already exists for $fullSku.',
                        ),
                      ),
                    );
                  }
                  return;
                }
                try {
                  await _inventory.createAlert(
                    sku: fullSku,
                    packagingType: packaging.name,
                    quantityRequested: int.parse(quantity.text),
                    packagingTypeId: packagingTypeId,
                    rawMaterialId: rawMaterialId,
                    skuNumber: int.parse(skuNumber.text),
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
        ),
      );
      if (saved == true && mounted) await _load();
    } finally {
      // Dialog routes finish their exit animation after showDialog completes.
      // Delay disposal so Cancel cannot rebuild a field with a disposed
      // controller during that animation.
      await Future<void>.delayed(const Duration(milliseconds: 250));
      skuNumber.dispose();
      quantity.dispose();
    }
  }
}

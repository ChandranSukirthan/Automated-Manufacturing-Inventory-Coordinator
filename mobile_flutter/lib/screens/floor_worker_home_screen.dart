import 'package:flutter/material.dart';

import '../controllers/inventory_controller.dart';
import '../services/api_client.dart';
import '../services/inventory_api_service.dart';
import '../services/quality_service.dart';
import '../views/scanner_view.dart';
import '../widgets/catalog_sku_fields.dart';
import 'defect_form_screen.dart';
import 'production_status_screen.dart';
import 'supply_delivery_tracking_screen.dart';
import 'worker_dashboard_screen.dart';

/// The Floor Worker landing screen follows the original AMIC Factory Assistant
/// flow, while all data operations go through the authenticated ASP.NET API.
class FloorWorkerHomeScreen extends StatefulWidget {
  const FloorWorkerHomeScreen({
    required this.employeeId,
    required this.qualityService,
    this.onOpenProfile,
    super.key,
  });

  final String employeeId;
  final QualityService qualityService;
  final Future<void> Function()? onOpenProfile;

  @override
  State<FloorWorkerHomeScreen> createState() => _FloorWorkerHomeScreenState();
}

class _FloorWorkerHomeScreenState extends State<FloorWorkerHomeScreen> {
  static const _yellow = Color(0xFFFFD700);
  static const _background = Color(0xFF121212);
  static const _surface = Color(0xFF1E1E1E);
  static const _input = Color(0xFF262626);
  final _controller = InventoryController();
  final _inventory = InventoryApiService();
  late final TextEditingController _skuController;
  late final TextEditingController _quantityController;

  bool _loading = true;
  bool _submitting = false;
  String? _loadError;
  List<StockAlertModel> _alerts = const [];
  List<Map<String, dynamic>> _stockLevels = const [];
  List<PackagingTypeModel> _packagingTypes = const [];
  List<RawMaterialModel> _rawMaterials = const [];
  int? _packagingTypeId;
  int? _rawMaterialId;

  @override
  void initState() {
    super.initState();
    _skuController = TextEditingController(text: _controller.sku);
    _quantityController = TextEditingController();
    _refresh();
  }

  @override
  void dispose() {
    _skuController.dispose();
    _quantityController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }

    try {
      final results = await Future.wait([
        _inventory.fetchAlerts(),
        _inventory.fetchStockLevels(),
        _inventory.fetchPackagingTypes(),
        _inventory.fetchRawMaterials(),
      ]);
      if (!mounted) return;
      setState(() {
        _alerts = results[0] as List<StockAlertModel>;
        _stockLevels = results[1] as List<Map<String, dynamic>>;
        _packagingTypes = results[2] as List<PackagingTypeModel>;
        _rawMaterials = results[3] as List<RawMaterialModel>;
        _packagingTypeId ??= _packagingTypes.firstOrNull?.id;
        _rawMaterialId ??= materialOptionsFor(
          _packagingTypeId,
          _rawMaterials,
        ).firstOrNull?.id;
        _loadError = null;
        _loading = false;
      });
    } on ApiException catch (exception) {
      if (mounted) {
        setState(() {
          _loadError = exception.message;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadError = 'Live inventory could not be refreshed.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _openScanner() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => ScannerView(controller: _controller)),
    );
    if (mounted) {
      final parts = _controller.sku.split('-');
      if (parts.length == 3) {
        final packaging = _packagingTypes
            .where((type) => type.shortCode == parts[0])
            .firstOrNull;
        final material = _rawMaterials
            .where(
              (item) =>
                  item.packagingTypeId == packaging?.id &&
                  item.materialCode == parts[1],
            )
            .firstOrNull;
        setState(() {
          _packagingTypeId = packaging?.id;
          _rawMaterialId = material?.id;
          _skuController.text = int.tryParse(parts[2])?.toString() ?? '';
        });
      }
      await _refresh();
    }
  }

  Future<void> _openWorkspace(int initialIndex) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => WorkerDashboardScreen(
          qualityService: widget.qualityService,
          initialIndex: initialIndex,
        ),
      ),
    );
    if (mounted) await _refresh();
  }

  Future<void> _openProductionStatus() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => const ProductionStatusScreen()),
    );
  }

  Future<void> _openDeliveryTracking() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => const SupplyDeliveryTrackingScreen()),
    );
  }

  Future<void> _submitLowStockAlert() async {
    final packaging = packagingById(_packagingTypes, _packagingTypeId);
    final material = materialById(_rawMaterials, _rawMaterialId);
    final skuNumber = int.tryParse(_skuController.text.trim());
    if (packaging == null ||
        material == null ||
        skuNumber == null ||
        skuNumber < 1) {
      _showMessage(
        'Select a packaging type and raw material, then enter a valid SKU number.',
        isError: true,
      );
      return;
    }
    _controller
      ..setPackagingType(packaging.name)
      ..setSku(buildSku(packaging, material, _skuController.text))
      ..clearMessages();

    setState(() => _submitting = true);
    final saved = await _controller.submitLowStockAlert();
    if (!mounted) return;

    if (!saved) {
      setState(() => _submitting = false);
      _showMessage(
        _controller.errorMessage ?? 'The low-stock alert could not be saved.',
        isError: true,
      );
      return;
    }

    // A submitted alert is complete. Leave the worker with a blank form so a
    // later alert cannot accidentally reuse the previous SKU or quantity.
    _controller
      ..setPackagingType(null)
      ..setSku('')
      ..setQuantityRequested(0);
    _skuController.clear();
    setState(() {
      _packagingTypeId = _packagingTypes.firstOrNull?.id;
      _rawMaterialId = materialOptionsFor(
        _packagingTypeId,
        _rawMaterials,
      ).firstOrNull?.id;
    });
    _quantityController.clear();

    try {
      _showMessage(
        'Low-stock alert logged. Open Data Extraction Agent to inspect the live stock data.',
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
        await _refresh();
      }
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: isError ? const Color(0xFFB3261E) : _yellow,
          content: Text(
            message,
            style: TextStyle(
              color: isError ? Colors.white : Colors.black,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
  }

  void _setQuantity(int value) {
    final quantity = value < 0 ? 0 : value;
    final text = quantity == 0 ? '' : quantity.toString();
    _quantityController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _controller.setQuantityRequested(quantity);
  }

  void _incrementQuantity() {
    final current = int.tryParse(_quantityController.text.trim()) ?? 0;
    _setQuantity(current == 0 ? 1 : current + 1);
  }

  void _decrementQuantity() {
    final current = int.tryParse(_quantityController.text.trim()) ?? 0;
    if (current > 0) _setQuantity(current - 1);
  }

  int get _activeAlertCount => _alerts
      .where(
        (alert) => const {
          'pending',
          'processing',
          'acknowledged',
        }.contains(alert.status.toLowerCase()),
      )
      .length;

  int get _lowStockCount => _stockLevels
      .where(
        (level) => const {
          'low',
          'critical',
        }.contains((level['status']?.toString() ?? '').toLowerCase()),
      )
      .length;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _background,
    appBar: AppBar(
      backgroundColor: _background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleSpacing: 20,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'FACTORY ASSISTANT',
            style: TextStyle(
              color: _yellow,
              fontSize: 19,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          Text(
            widget.employeeId,
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Profile',
          onPressed: widget.onOpenProfile,
          icon: const Icon(
            Icons.account_circle_outlined,
            color: Colors.white70,
          ),
        ),
        const SizedBox(width: 6),
      ],
    ),
    body: RefreshIndicator(
      color: _yellow,
      backgroundColor: _surface,
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          _buildQuickActions(),
          const SizedBox(height: 18),
          _buildOperationsActions(),
          const SizedBox(height: 18),
          if (_loadError != null) _buildConnectionNotice(),
          _buildSummary(),
          const SizedBox(height: 18),
          _buildLowStockForm(),
          const SizedBox(height: 18),
          _buildDataExtractionCard(),
          const SizedBox(height: 18),
          _buildRecentAlerts(),
        ],
      ),
    ),
    bottomNavigationBar: NavigationBar(
      backgroundColor: _surface,
      indicatorColor: _yellow,
      selectedIndex: 0,
      onDestinationSelected: (index) {
        switch (index) {
          case 1:
            _openScanner();
            break;
          case 2:
            _openWorkspace(0);
            break;
          case 3:
            final messenger = ScaffoldMessenger.of(context);
            Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    DefectFormScreen(service: widget.qualityService),
              ),
            ).then((submitted) {
              if (!mounted || submitted != true) return;
              messenger.showSnackBar(
                const SnackBar(
                  content: Text(
                    'Defect report submitted to managers and admins.',
                  ),
                ),
              );
            });
            break;
        }
      },
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.qr_code_scanner),
          label: 'Scanner',
        ),
        NavigationDestination(
          icon: Icon(Icons.inventory_2_outlined),
          label: 'Inventory',
        ),
        NavigationDestination(
          icon: Icon(Icons.assignment_outlined),
          label: 'Report',
        ),
      ],
    ),
  );

  Widget _buildQuickActions() => Row(
    children: [
      Expanded(
        child: _quickAction(
          icon: Icons.qr_code_scanner,
          label: 'Scan roll',
          onPressed: _openScanner,
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _quickAction(
          icon: Icons.inventory_2_outlined,
          label: 'Inventory',
          onPressed: () => _openWorkspace(0),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _quickAction(
          icon: Icons.analytics_outlined,
          label: 'Stock level',
          onPressed: () => _openWorkspace(2),
        ),
      ),
    ],
  );

  Widget _buildOperationsActions() => Row(
    children: [
      Expanded(
        child: _quickAction(
          icon: Icons.precision_manufacturing_outlined,
          label: 'Production status',
          onPressed: _openProductionStatus,
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _quickAction(
          icon: Icons.local_shipping_outlined,
          label: 'Supply deliveries',
          onPressed: _openDeliveryTracking,
        ),
      ),
    ],
  );

  Widget _quickAction({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) => Material(
    color: _surface,
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, color: _yellow, size: 25),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _buildConnectionNotice() => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF3A2424),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFF8A80)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_outlined, color: Color(0xFFFF8A80)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Live inventory could not be refreshed. Pull down to retry.',
              style: const TextStyle(color: Colors.white70, height: 1.3),
            ),
          ),
          TextButton(onPressed: _refresh, child: const Text('Retry')),
        ],
      ),
    ),
  );

  Widget _buildSummary() => Row(
    children: [
      Expanded(
        child: _metricCard(
          icon: Icons.warning_amber_rounded,
          label: 'Low stock',
          value: _loading ? '—' : '$_lowStockCount',
          color: _lowStockCount == 0 ? const Color(0xFF6EE7B7) : _yellow,
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: _metricCard(
          icon: Icons.pending_actions_outlined,
          label: 'Active alerts',
          value: _loading ? '—' : '$_activeAlertCount',
          color: const Color(0xFF93C5FD),
        ),
      ),
    ],
  );

  Widget _metricCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.white12),
    ),
    child: Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                label,
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _buildLowStockForm() => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white12),
    ),
    child: AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_rounded, color: _yellow),
              SizedBox(width: 10),
              Text(
                'LOW-STOCK ALERT',
                style: TextStyle(
                  color: _yellow,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          CatalogSkuFields(
            packagingTypes: _packagingTypes,
            rawMaterials: _rawMaterials,
            packagingTypeId: _packagingTypeId,
            rawMaterialId: _rawMaterialId,
            skuNumberController: _skuController,
            dark: true,
            enabled: !_submitting && !_loading,
            onPackagingTypeChanged: (value) => setState(() {
              _packagingTypeId = value;
              _rawMaterialId = materialOptionsFor(
                value,
                _rawMaterials,
              ).firstOrNull?.id;
              _skuController.clear();
            }),
            onRawMaterialChanged: (value) => setState(() {
              _rawMaterialId = value;
              _skuController.clear();
            }),
            onSkuNumberChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          const Text(
            'QUANTITY REQUESTED',
            style: TextStyle(
              color: Colors.white60,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: .8,
            ),
          ),
          const SizedBox(height: 7),
          Container(
            decoration: BoxDecoration(
              color: _input,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Decrease quantity',
                  onPressed: _submitting ? null : _decrementQuantity,
                  icon: const Icon(Icons.remove, color: Colors.white70),
                ),
                Expanded(
                  child: TextField(
                    controller: _quantityController,
                    enabled: !_submitting,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _yellow,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Enter quantity',
                      hintStyle: TextStyle(color: Colors.white38, fontSize: 15),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      fillColor: Colors.transparent,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (value) => _controller.setQuantityRequested(
                      int.tryParse(value.trim()) ?? 0,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Increase quantity',
                  onPressed: _submitting ? null : _incrementQuantity,
                  icon: const Icon(Icons.add, color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _submitting ? null : _submitLowStockAlert,
              style: ElevatedButton.styleFrom(
                backgroundColor: _yellow,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: _submitting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        color: Colors.black,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.smart_toy_outlined),
              label: Text(
                _submitting ? 'SUBMITTING...' : 'SUBMIT LOW-STOCK ALERT',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  letterSpacing: .5,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildDataExtractionCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.analytics_outlined, color: Colors.white70),
              SizedBox(width: 10),
              Text(
                'DATA EXTRACTION',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _stockLevels.isEmpty
                ? 'No live material records are available yet.'
                : '$_lowStockCount low-stock material${_lowStockCount == 1 ? '' : 's'} found in ${_stockLevels.length} live inventory record${_stockLevels.length == 1 ? '' : 's'}.',
            style: const TextStyle(color: Colors.white70, height: 1.35),
          ),
          TextButton.icon(
            onPressed: () => _openWorkspace(5),
            icon: const Icon(Icons.open_in_new, size: 17),
            label: const Text('Open Data Extraction Agent'),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentAlerts() => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'RECENT ALERTS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .8,
                ),
              ),
            ),
            TextButton(
              onPressed: () => _openWorkspace(3),
              child: const Text('View all'),
            ),
          ],
        ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Center(child: CircularProgressIndicator(color: _yellow)),
          )
        else if (_alerts.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'No low-stock alerts have been logged.',
              style: TextStyle(color: Colors.white60),
            ),
          )
        else
          ..._alerts
              .take(3)
              .map(
                (alert) => Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.inventory_2_outlined,
                      color: _statusColor(alert.status),
                    ),
                    title: Text(
                      alert.sku,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      '${alert.packagingType} • ${alert.quantityRequested} units',
                      style: const TextStyle(color: Colors.white60),
                    ),
                    trailing: _statusBadge(alert.status),
                  ),
                ),
              ),
      ],
    ),
  );

  Color _statusColor(String status) => switch (status.toLowerCase()) {
    'resolved' => const Color(0xFF6EE7B7),
    'dismissed' => Colors.white54,
    _ => _yellow,
  };

  Widget _statusBadge(String status) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: _statusColor(status)),
      color: _statusColor(status).withValues(alpha: .12),
    ),
    child: Text(
      status,
      style: TextStyle(
        color: _statusColor(status),
        fontSize: 10,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

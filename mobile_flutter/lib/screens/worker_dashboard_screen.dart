import '../utils/locale.dart';
import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_state.dart';
import '../controllers/inventory_controller.dart';
import '../models/worker_workflow_models.dart';
import '../services/api_client.dart';
import '../services/inventory_api_service.dart';
import '../services/quality_service.dart';
import '../views/scanner_view.dart';
import 'profile_screen.dart';

class WorkerDashboardScreen extends StatefulWidget {
  const WorkerDashboardScreen({
    required this.qualityService,
    this.appState,
    this.initialIndex = 0,
    super.key,
  });

  final QualityService qualityService;
  final AppState? appState;
  final int initialIndex;

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
  final _aiQuantityController = TextEditingController(text: '2000');
  bool _triggeringAi = false;
  int _aiStep = 0;

  // Modern interactive filters & search
  String _alertFilter = 'All';
  String _alertSearch = '';
  String _rollFilter = 'All';
  String _rollSearch = '';
  String _levelFilter = 'All';
  String _levelSearch = '';
  String _historyFilter = 'All';

  static const _tabs = [
    'Overview & Health',
    'Inventory Rolls',
    'Stock & Items',
    'Low Stock Alerts',
    'Inventory History',
    'AI Coordinator',
  ];

  static const _tabIcons = [
    Icons.dashboard_outlined,
    Icons.qr_code_2_rounded,
    Icons.analytics_outlined,
    Icons.warning_amber_rounded,
    Icons.history_rounded,
    Icons.smart_toy_outlined,
  ];

  static const _tabShortLabels = [
    'Overview',
    'Rolls',
    'Stock',
    'Alerts',
    'History',
    'AI Agent',
  ];

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _load();
  }

  @override
  void dispose() {
    _aiQuantityController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load({bool showSpinner = true}) async {
    if (showSpinner) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
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
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Unable to load floor inventory. Please check connection.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _runAiForMaterial(String materialId, num quantity) async {
    if (materialId.isEmpty || quantity < 100 || quantity % 100 != 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Quantity must be at least 100 and increase by 100.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    setState(() {
      _triggeringAi = true;
      _aiStep = 1;
      _error = null;
      _workflow = null;
    });

    // Step progression animation
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && _triggeringAi) setState(() => _aiStep = 2);
    });
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted && _triggeringAi) setState(() => _aiStep = 3);
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
          _aiStep = result.requiresApproval ? 4 : 5;
          _index = 5; // Stay on AI Agent Coordinator tab
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Autonomous replenishment workflow initiated!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        // Silently update inventory data in the background without clearing the screen
        await _load(showSpinner: false);
      }
    } on ApiException catch (exception) {
      if (mounted) {
        setState(() {
          _error = exception.message;
          _triggeringAi = false;
          _aiStep = 0;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(exception.message),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _runAi() async {
    if (_selectedMaterial == null || _selectedMaterial!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a raw material SKU from the dropdown first.'),
          backgroundColor: Color(0xFF0284C7),
        ),
      );
      return;
    }
    await _runAiForMaterial(_selectedMaterial!, _requiredQuantity);
  }

  Future<void> _showProfilePopup() async {
    final user = widget.appState?.session?.user;
    if (user == null) return;

    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF1E293B), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0284C7).withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Text(
                      user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : 'W',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.fullName,
                          style: const TextStyle(
                            color: AppColors.strongText,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user.email,
                          style: const TextStyle(
                            color: AppColors.mutedText,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0B0F19),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF1E293B)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.badge_outlined, color: AppColors.primaryLight, size: 18),
                    const SizedBox(width: 8),
                    const Text(
                      'Assigned Role:',
                      style: TextStyle(color: AppColors.mutedText, fontSize: 12),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
                      ),
                      child: Text(
                        user.role,
                        style: const TextStyle(
                          color: AppColors.primaryLight,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  if (widget.appState != null) {
                    Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProfileScreen(appState: widget.appState!),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.person_outline_rounded, size: 18),
                label: const Text('My Profile', style: TextStyle(fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF38BDF8),
                  side: const BorderSide(color: Color(0xFF0284C7)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: () async {
                  Navigator.pop(dialogContext);
                  await widget.appState?.logout();
                },
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.w700)),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentTabTitle = _tabs[_index].toUpperCase();

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.precision_manufacturing_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    currentTabTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Row(
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                        child: SizedBox.square(dimension: 6),
                      ),
                      SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          'Floor Operations · Real-Time Control',
                          style: TextStyle(
                            color: Color(0xFF38BDF8),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Scan Inventory Roll',
            icon: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF38BDF8)),
            onPressed: () => Navigator.push<void>(
              context,
              MaterialPageRoute(
                builder: (_) => ScannerView(controller: _controller),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded, color: AppColors.secondaryText),
          ),
          if (widget.appState?.session?.user != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                onTap: _showProfilePopup,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B0F19),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF1E293B)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          widget.appState!.session!.user.fullName.isNotEmpty
                              ? widget.appState!.session!.user.fullName[0].toUpperCase()
                              : 'W',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 60),
                        child: Text(
                          widget.appState!.session!.user.fullName.split(' ').first,
                          style: const TextStyle(
                            color: AppColors.primaryText,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _items.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 40),
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.errorText, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : _buildActiveTabContent(),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  Widget _buildActiveTabContent() {
    switch (_index) {
      case 0:
        return _overviewDashboardTab();
      case 1:
        return _rollsTab();
      case 2:
        return _levelsTab();
      case 3:
        return _alertsTab();
      case 4:
        return _historyTab();
      case 5:
        return _agentTab();
      default:
        return _overviewDashboardTab();
    }
  }

  /// Tab 0: Clean, Executive Overview Dashboard
  Widget _overviewDashboardTab() {
    final criticalMaterials = _levels
        .where((l) => l['status'] == 'CRITICAL' || l['status'] == 'LOW')
        .toList();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          // Sleek, compact, mobile-responsive hero banner
          _buildCompactHeaderBanner(),
          const SizedBox(height: 12),
          _buildTopKpiCards(),
          const SizedBox(height: 14),
          _buildUrgentReplenishmentCtaBanner(criticalMaterials.length),
          const SizedBox(height: 14),

          // Critical Stock Watchlist
          Container(
            padding: const EdgeInsets.all(14),
            decoration: _cardBoxDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: criticalMaterials.isNotEmpty
                                ? AppColors.error.withValues(alpha: 0.15)
                                : const Color(0xFF10B981).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            criticalMaterials.isNotEmpty
                                ? Icons.warning_amber_rounded
                                : Icons.check_circle_outline_rounded,
                            color: criticalMaterials.isNotEmpty
                                ? const Color(0xFFF87171)
                                : const Color(0xFF34D399),
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Critical Stock Watchlist',
                              style: TextStyle(
                                color: AppColors.strongText,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              criticalMaterials.isNotEmpty
                                  ? '${criticalMaterials.length} materials below safe threshold'
                                  : '100% stock healthy across floor catalog',
                              style: const TextStyle(color: AppColors.mutedText, fontSize: 10),
                            ),
                          ],
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: () => setState(() => _index = 2),
                      style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                      child: const Text('View All', style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (criticalMaterials.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B0F19),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF1E293B)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.verified_outlined, color: Color(0xFF34D399), size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'All inventory items have optimal stock levels. No urgent replenishment required.',
                            style: TextStyle(color: AppColors.secondaryText, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: criticalMaterials.take(3).length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (_, index) {
                      final mat = criticalMaterials[index];
                      final sku = mat['skuCode']?.toString() ?? '';
                      final daysRemaining = mat['daysRemaining'] ?? 0;
                      final isCritical = mat['status'] == 'CRITICAL';

                      return Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0B0F19),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isCritical
                                ? const Color(0xFFEF4444).withValues(alpha: 0.4)
                                : const Color(0xFFF59E0B).withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    mat['materialName']?.toString() ?? sku,
                                    style: const TextStyle(
                                      color: AppColors.strongText,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'SKU: $sku · $daysRemaining days left',
                                    style: TextStyle(
                                      color: isCritical ? const Color(0xFFF87171) : const Color(0xFFFBBF24),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            FilledButton.icon(
                              onPressed: _triggeringAi
                                  ? null
                                  : () => _runAiForMaterial(sku, 2000),
                              icon: const Icon(Icons.auto_awesome, size: 12),
                              label: const Text('AI Reorder', style: TextStyle(fontSize: 10)),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Fast Navigation Shortcuts
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _index = 1),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF1E293B), width: 1.2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.qr_code_2_rounded, color: Color(0xFF34D399), size: 16),
                            ),
                            const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.mutedText, size: 11),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Floor Rolls',
                          style: TextStyle(color: AppColors.strongText, fontSize: 12, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          '${_rolls.length} active batch rolls',
                          style: const TextStyle(color: AppColors.mutedText, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _index = 5),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF1E293B), width: 1.2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.smart_toy_rounded, color: AppColors.primaryLight, size: 16),
                            ),
                            const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.mutedText, size: 11),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'LangGraph Agent',
                          style: TextStyle(color: AppColors.strongText, fontSize: 12, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 1),
                        const Text(
                          'Autonomous Replenish',
                          style: TextStyle(color: AppColors.mutedText, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUrgentReplenishmentCtaBanner(int criticalCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: criticalCount > 0
              ? [const Color(0xFF7F1D1D), const Color(0xFF991B1B)]
              : [const Color(0xFF064E3B), const Color(0xFF065F46)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: criticalCount > 0
              ? const Color(0xFFEF4444).withValues(alpha: 0.6)
              : const Color(0xFF10B981).withValues(alpha: 0.6),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: (criticalCount > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981)).withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              criticalCount > 0 ? Icons.flash_on_rounded : Icons.smart_toy_rounded,
              color: criticalCount > 0 ? const Color(0xFFFCA5A5) : const Color(0xFF6EE7B7),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  criticalCount > 0
                      ? 'Urgent Replenishment Required'
                      : 'AI Autonomous Coordinator',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  criticalCount > 0
                      ? '$criticalCount materials critical. Trigger AI multi-agent reorder pipeline.'
                      : 'Zero stock bottlenecks detected. Tap to run floor inventory agent.',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () => setState(() => _index = 5),
            icon: const Icon(Icons.arrow_forward_rounded, size: 14),
            label: const Text('Open Agent', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: criticalCount > 0 ? const Color(0xFF991B1B) : const Color(0xFF065F46),
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  /// Compact, responsive, modern header banner with non-yellow action buttons
  Widget _buildCompactHeaderBanner() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF0F2744), Color(0xFF0F172A), Color(0xFF0B132B)],
      ),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: const Color(0xFF38BDF8).withValues(alpha: 0.3),
        width: 1.2,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.3),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'FLOOR OPERATIONS',
              style: TextStyle(
                color: Color(0xFF93C5FD),
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                const Text(
                  'Live Control',
                  style: TextStyle(
                    color: Color(0xFF34D399),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Inventory & Machine Operations',
          style: TextStyle(
            color: AppColors.strongText,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 2),
        const Text(
          'Real-time roll tracking, stock triage, and LangGraph auto-replenishment.',
          style: TextStyle(
            color: AppColors.mutedText,
            fontSize: 11,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            OutlinedButton.icon(
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => ScannerView(controller: _controller),
                ),
              ),
              icon: const Icon(Icons.qr_code_scanner_rounded, size: 14),
              label: const Text('Scan QR Roll', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF38BDF8),
                side: const BorderSide(color: Color(0xFF0284C7)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                visualDensity: VisualDensity.compact,
              ),
            ),
            FilledButton.icon(
              onPressed: _showAlertForm,
              icon: const Icon(Icons.add_alert_rounded, size: 14),
              label: const Text('Log Stock Alert', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                visualDensity: VisualDensity.compact,
              ),
            ),
            FilledButton.icon(
              onPressed: _triggeringAi ? null : () => setState(() => _index = 5),
              icon: const Icon(Icons.auto_awesome_rounded, size: 14),
              label: const Text('AI Replenish', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _buildTopKpiCards() {
    final criticalCount = _levels
        .where((l) => l['status'] == 'CRITICAL' || l['status'] == 'LOW')
        .length;
    final pendingAlertsCount = _alerts
        .where((a) => a.status == 'Pending' || a.status == 'Processing')
        .length;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 1.6,
      children: [
        _buildKpiCard(
          'Owned Items',
          '${_items.length}',
          Icons.inventory_2_outlined,
          AppColors.primaryLight,
          'Active Catalog SKUs',
        ),
        _buildKpiCard(
          'Floor Rolls',
          '${_rolls.length}',
          Icons.qr_code_2_rounded,
          const Color(0xFF10B981),
          'Tracked Batch Units',
        ),
        _buildKpiCard(
          'Critical Stock',
          '$criticalCount',
          Icons.analytics_outlined,
          criticalCount > 0 ? AppColors.error : const Color(0xFF10B981),
          criticalCount > 0 ? 'Below Threshold' : 'All Levels Safe',
        ),
        _buildKpiCard(
          'Pending Alerts',
          '$pendingAlertsCount',
          Icons.warning_amber_rounded,
          pendingAlertsCount > 0 ? const Color(0xFF38BDF8) : AppColors.mutedText,
          'Awaiting Dispatch',
        ),
      ],
    );
  }

  Widget _buildKpiCard(
    String title,
    String value,
    IconData icon,
    Color color,
    String subtitle,
  ) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: const Color(0xFF0F172A),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFF1E293B), width: 1.2),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.2),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                title.toUpperCase(),
                style: const TextStyle(
                  color: AppColors.mutedText,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            Icon(icon, color: color, size: 14),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            fontFamily: 'monospace',
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        const SizedBox(height: 1),
        Text(
          subtitle,
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 8.5),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ],
    ),
  );

  /// Tab 1: Dedicated Full-Screen Inventory Rolls with "+ Register Roll" action
  Widget _rollsTab() {
    final filteredRolls = _rolls.where((roll) {
      final matchesSearch = _rollSearch.isEmpty ||
          roll.rollIdentifier.toLowerCase().contains(_rollSearch.toLowerCase());
      if (!matchesSearch) return false;
      if (_rollFilter == 'All') return true;
      if (_rollFilter == 'Available') {
        return roll.status.toLowerCase().contains('available') ||
            roll.status.toLowerCase().contains('in stock');
      }
      if (_rollFilter == 'Quarantine') {
        return roll.status.toLowerCase().contains('quarantine');
      }
      if (_rollFilter == 'In Use') {
        return roll.status.toLowerCase().contains('use') ||
            roll.status.toLowerCase().contains('allocated');
      }
      return true;
    }).toList();

    const rollFilters = ['All', 'Available', 'In Use', 'Quarantine'];

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: _cardBoxDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tracked Inventory Rolls',
                            style: TextStyle(
                              color: AppColors.strongText,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'Physical fabric batch roll units and floor status',
                            style: TextStyle(color: AppColors.mutedText, fontSize: 10.5),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _showRegisterRollForm,
                      icon: const Icon(Icons.add_rounded, size: 15),
                      label: const Text('Register Roll', style: TextStyle(fontSize: 11)),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Search Bar
                TextField(
                  onChanged: (val) => setState(() => _rollSearch = val.trim()),
                  style: const TextStyle(color: AppColors.strongText, fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'Search roll by ID or barcode...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 16, color: AppColors.mutedText),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    fillColor: const Color(0xFF0B0F19),
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF1E293B)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF1E293B)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: rollFilters.map((filter) {
                      final isSelected = _rollFilter == filter;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: FilterChip(
                          label: Text(filter),
                          selected: isSelected,
                          onSelected: (_) => setState(() => _rollFilter = filter),
                          selectedColor: AppColors.primary.withValues(alpha: 0.3),
                          backgroundColor: const Color(0xFF0B0F19),
                          labelStyle: TextStyle(
                            color: isSelected ? AppColors.primaryLight : AppColors.mutedText,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                              color: isSelected ? AppColors.primary : const Color(0xFF1E293B),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 10),

                if (filteredRolls.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 28),
                    child: Center(
                      child: Text(
                        'No matching inventory rolls found.',
                        style: TextStyle(color: AppColors.mutedText, fontSize: 12),
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredRolls.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, index) {
                      final roll = filteredRolls[index];
                      final material = _materials
                          .where((item) => item.id == roll.rawMaterialId)
                          .firstOrNull;
                      final isQuarantined = roll.status.toLowerCase().contains('quarantine');
                      final isAvailable = roll.status.toLowerCase().contains('available') ||
                          roll.status.toLowerCase().contains('in stock');
                      final statusColor = isQuarantined
                          ? AppColors.error
                          : (isAvailable ? const Color(0xFF10B981) : const Color(0xFF38BDF8));

                      final ratio = roll.initialQuantity > 0
                          ? (roll.currentQuantity / roll.initialQuantity).clamp(0.0, 1.0)
                          : 1.0;

                      return Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0B0F19),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF1E293B)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                                  ),
                                  child: const Icon(Icons.qr_code_2_rounded, color: AppColors.primaryLight, size: 18),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        roll.rollIdentifier,
                                        style: const TextStyle(
                                          color: Color(0xFF67E8F9),
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w800,
                                          fontFamily: 'monospace',
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${material?.skuCode ?? 'SKU'} · ${material?.name ?? 'Fabric Material'}',
                                        style: const TextStyle(color: AppColors.strongText, fontSize: 10.5),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${roll.currentQuantity} / ${roll.initialQuantity} units',
                                        style: const TextStyle(color: AppColors.mutedText, fontSize: 9.5, fontFamily: 'monospace'),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: statusColor.withValues(alpha: 0.35)),
                                  ),
                                  child: Text(
                                    roll.status,
                                    style: TextStyle(
                                      color: statusColor,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: ratio.toDouble(),
                                backgroundColor: const Color(0xFF1E293B),
                                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                                minHeight: 3.5,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Tab 2: Dedicated Full-Screen Stock Levels & Catalog with "+ Add Item"
  Widget _levelsTab() {
    final filteredLevels = _levels.where((level) {
      final sku = level['skuCode']?.toString().toLowerCase() ?? '';
      final name = level['materialName']?.toString().toLowerCase() ?? '';
      final matchesSearch = _levelSearch.isEmpty ||
          sku.contains(_levelSearch.toLowerCase()) ||
          name.contains(_levelSearch.toLowerCase());
      if (!matchesSearch) return false;

      final status = level['status']?.toString() ?? 'NORMAL';
      if (_levelFilter == 'All') return true;
      if (_levelFilter == 'Critical') return status == 'CRITICAL';
      if (_levelFilter == 'Low') return status == 'LOW';
      if (_levelFilter == 'Normal') return status == 'NORMAL' || status == 'HEALTHY';
      return true;
    }).toList();

    const levelFilters = ['All', 'Critical', 'Low', 'Normal'];

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: _cardBoxDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Stock Catalog & Burn Rate',
                            style: TextStyle(
                              color: AppColors.strongText,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'Catalog inventory items & real-time depletion monitoring',
                            style: TextStyle(color: AppColors.mutedText, fontSize: 10.5),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: () => _showItemForm(),
                      icon: const Icon(Icons.add_rounded, size: 15),
                      label: const Text('Add Item', style: TextStyle(fontSize: 11)),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Search Bar
                TextField(
                  onChanged: (val) => setState(() => _levelSearch = val.trim()),
                  style: const TextStyle(color: AppColors.strongText, fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'Search SKU or material name...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 16, color: AppColors.mutedText),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    fillColor: const Color(0xFF0B0F19),
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF1E293B)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF1E293B)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: levelFilters.map((filter) {
                      final isSelected = _levelFilter == filter;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: FilterChip(
                          label: Text(filter),
                          selected: isSelected,
                          onSelected: (_) => setState(() => _levelFilter = filter),
                          selectedColor: AppColors.primary.withValues(alpha: 0.3),
                          backgroundColor: const Color(0xFF0B0F19),
                          labelStyle: TextStyle(
                            color: isSelected ? AppColors.primaryLight : AppColors.mutedText,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                              color: isSelected ? AppColors.primary : const Color(0xFF1E293B),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 10),

                if (filteredLevels.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 28),
                    child: Center(
                      child: Text('No stock level data matches your filter.', style: TextStyle(color: AppColors.mutedText, fontSize: 12)),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredLevels.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, index) {
                      final level = filteredLevels[index];
                      final status = level['status']?.toString() ?? 'NORMAL';
                      final sku = level['skuCode']?.toString() ?? '';
                      final burnRate = num.tryParse(level['burnRate']?.toString() ?? '0') ?? 0;
                      final daysLeft = num.tryParse(level['daysRemaining']?.toString() ?? '0') ?? 0;
                      final needsReorder = status == 'CRITICAL' || status == 'LOW';

                      final matchingItem = _items
                          .where((i) => i.sku.toLowerCase() == sku.toLowerCase())
                          .firstOrNull;

                      final hasActiveAlert = _alerts.any(
                        (alert) =>
                            alert.sku.toLowerCase() == sku.toLowerCase() &&
                            const ['Pending', 'Processing', 'Acknowledged'].contains(alert.status),
                      );

                      final statusColor = status == 'CRITICAL'
                          ? AppColors.error
                          : (status == 'LOW' ? const Color(0xFFF59E0B) : const Color(0xFF10B981));

                      return Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0B0F19),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: needsReorder
                                ? statusColor.withValues(alpha: 0.4)
                                : const Color(0xFF1E293B),
                            width: needsReorder ? 1.4 : 1.0,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    level['materialName']?.toString() ?? sku,
                                    style: const TextStyle(
                                      color: AppColors.strongText,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                if (matchingItem != null)
                                  IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    icon: const Icon(Icons.edit_outlined, size: 15, color: AppColors.mutedText),
                                    onPressed: () => _showItemForm(matchingItem),
                                    tooltip: 'Edit Item',
                                  ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(5),
                                    border: Border.all(color: statusColor.withValues(alpha: 0.35)),
                                  ),
                                  child: Text(
                                    status,
                                    style: TextStyle(
                                      color: statusColor,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'SKU: $sku',
                                    style: const TextStyle(color: AppColors.mutedText, fontSize: 10.5, fontFamily: 'monospace'),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  'Burn: $burnRate KG/day',
                                  style: const TextStyle(color: AppColors.secondaryText, fontSize: 10.5, fontFamily: 'monospace'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: (daysLeft / 30).clamp(0.05, 1.0),
                                backgroundColor: const Color(0xFF1E293B),
                                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                                minHeight: 4,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '$daysLeft days remaining',
                                  style: TextStyle(
                                    color: statusColor,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (needsReorder)
                                  hasActiveAlert
                                      ? Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(5),
                                          ),
                                          child: const Text(
                                            'Alert In Progress',
                                            style: TextStyle(color: Color(0xFF38BDF8), fontSize: 9.5, fontWeight: FontWeight.w700),
                                          ),
                                        )
                                      : FilledButton.icon(
                                          onPressed: _triggeringAi
                                              ? null
                                              : () => _runAiForMaterial(sku, 2000),
                                          icon: const Icon(Icons.auto_awesome, size: 12),
                                          label: const Text('Reorder via AI', style: TextStyle(fontSize: 10)),
                                          style: FilledButton.styleFrom(
                                            backgroundColor: AppColors.primary,
                                            foregroundColor: Colors.white,
                                            visualDensity: VisualDensity.compact,
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          ),
                                        ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Tab 3: Dedicated Full-Screen Low Stock Alerts with Status Manager
  Widget _alertsTab() {
    final filteredAlerts = _alerts.where((alert) {
      final matchesSearch = _alertSearch.isEmpty ||
          alert.sku.toLowerCase().contains(_alertSearch.toLowerCase());
      if (!matchesSearch) return false;
      if (_alertFilter == 'All') return true;
      return alert.status == _alertFilter;
    }).toList();

    const filters = [
      'All',
      'Pending',
      'Processing',
      'Acknowledged',
      'Resolved',
      'Dismissed',
    ];

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: _cardBoxDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Low Stock Alerts',
                            style: TextStyle(
                              color: AppColors.strongText,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'Floor replenishment dispatch and triage',
                            style: TextStyle(color: AppColors.mutedText, fontSize: 10.5),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _showAlertForm,
                      icon: const Icon(Icons.add_rounded, size: 15),
                      label: const Text('Log Alert', style: TextStyle(fontSize: 11)),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Search Bar
                TextField(
                  onChanged: (val) => setState(() => _alertSearch = val.trim()),
                  style: const TextStyle(color: AppColors.strongText, fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'Search alert by SKU...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 16, color: AppColors.mutedText),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    fillColor: const Color(0xFF0B0F19),
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF1E293B)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF1E293B)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Horizontal Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: filters.map((filter) {
                      final count = filter == 'All'
                          ? _alerts.length
                          : _alerts.where((alert) => alert.status == filter).length;
                      final selected = _alertFilter == filter;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: FilterChip(
                          label: Text('$filter ($count)'),
                          selected: selected,
                          onSelected: (_) => setState(() => _alertFilter = filter),
                          selectedColor: AppColors.primary.withValues(alpha: 0.3),
                          backgroundColor: const Color(0xFF0B0F19),
                          labelStyle: TextStyle(
                            color: selected ? AppColors.primaryLight : AppColors.mutedText,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                              color: selected ? AppColors.primary : const Color(0xFF1E293B),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 10),

                if (filteredAlerts.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        _alertFilter == 'All'
                            ? 'All clear. No active stock alerts logged.'
                            : 'No $_alertFilter alerts found.',
                        style: const TextStyle(color: AppColors.mutedText, fontSize: 12),
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredAlerts.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, index) {
                      final alert = filteredAlerts[index];
                      final statusColor = alert.status == 'Pending'
                          ? AppColors.error
                          : alert.status == 'Processing'
                          ? const Color(0xFFF59E0B)
                          : alert.status == 'Resolved'
                          ? const Color(0xFF10B981)
                          : const Color(0xFF64748B);

                      return Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0B0F19),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF1E293B)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.warning_amber_rounded, color: statusColor, size: 16),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    alert.sku,
                                    style: const TextStyle(
                                      color: AppColors.strongText,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                      fontFamily: 'monospace',
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${alert.packagingType} · Req: ${alert.quantityRequested} units',
                                    style: const TextStyle(color: AppColors.mutedText, fontSize: 10.5),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            PopupMenuButton<String>(
                              color: const Color(0xFF0F172A),
                              icon: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: statusColor.withValues(alpha: 0.35)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      alert.status,
                                      style: TextStyle(
                                        color: statusColor,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(width: 2),
                                    Icon(Icons.arrow_drop_down, color: statusColor, size: 13),
                                  ],
                                ),
                              ),
                              onSelected: (newStatus) async {
                                try {
                                  await _inventory.updateAlertStatus(alert.id, newStatus);
                                  await _load();
                                } catch (_) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Failed to update alert status.'),
                                        backgroundColor: AppColors.error,
                                      ),
                                    );
                                  }
                                }
                              },
                              itemBuilder: (_) => [
                                'Pending',
                                'Processing',
                                'Acknowledged',
                                'Resolved',
                                'Dismissed',
                              ]
                                  .map(
                                    (status) => PopupMenuItem(
                                      value: status,
                                      child: Text(
                                        status,
                                        style: TextStyle(
                                          color: status == alert.status
                                              ? AppColors.primaryLight
                                              : AppColors.strongText,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Tab 4: Dedicated Full-Screen Inventory History with Material Selector & Type Filter
  Widget _historyTab() {
    final filteredHistory = _history.where((entry) {
      if (_historyFilter == 'All') return true;
      final type = entry['transactionType']?.toString().toUpperCase() ?? '';
      return type.contains(_historyFilter.toUpperCase());
    }).toList();

    const historyFilters = ['All', 'INTAKE', 'USAGE', 'ADJUSTMENT'];

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: _cardBoxDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Inventory Transaction History',
                  style: TextStyle(
                    color: AppColors.strongText,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Audit ledger for raw material intake, usage, and adjustments',
                  style: TextStyle(color: AppColors.mutedText, fontSize: 10.5),
                ),
                const SizedBox(height: 12),

                // Material selector button (mobile bottom sheet picker)
                if (_materials.isEmpty)
                  const Text('No materials found.', style: TextStyle(color: AppColors.mutedText))
                else
                  InkWell(
                    onTap: _showHistoryMaterialPickerSheet,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0B0F19),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF1E293B), width: 1.2),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.history_edu_outlined, size: 18, color: Color(0xFF38BDF8)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Material for Audit Ledger',
                                  style: TextStyle(color: AppColors.mutedText, fontSize: 10.5, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _selectedHistoryMaterialId != null &&
                                          _materials.any((m) => m.id == _selectedHistoryMaterialId)
                                      ? '${_materials.firstWhere((m) => m.id == _selectedHistoryMaterialId).skuCode} - ${_materials.firstWhere((m) => m.id == _selectedHistoryMaterialId).name}'
                                      : 'Tap to select raw material...',
                                  style: const TextStyle(
                                    color: AppColors.strongText,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down_rounded, color: AppColors.secondaryText, size: 24),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 10),

                // Transaction Type Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: historyFilters.map((type) {
                      final isSelected = _historyFilter == type;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: FilterChip(
                          label: Text(type),
                          selected: isSelected,
                          onSelected: (_) => setState(() => _historyFilter = type),
                          selectedColor: AppColors.primary.withValues(alpha: 0.3),
                          backgroundColor: const Color(0xFF0B0F19),
                          labelStyle: TextStyle(
                            color: isSelected ? AppColors.primaryLight : AppColors.mutedText,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                              color: isSelected ? AppColors.primary : const Color(0xFF1E293B),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 12),

                if (filteredHistory.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 28),
                    child: Center(
                      child: Text(
                        'No transactions recorded for this material.',
                        style: TextStyle(color: AppColors.mutedText, fontSize: 12),
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredHistory.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, index) {
                      final entry = filteredHistory[index];
                      final type = entry['transactionType']?.toString() ?? 'ADJUSTMENT';
                      final isIntake = type.toUpperCase().contains('INTAKE') ||
                          type.toUpperCase().contains('RECEIVE');
                      final isUsage = type.toUpperCase().contains('USAGE') ||
                          type.toUpperCase().contains('CONSUMPTION');
                      final tagColor = isIntake
                          ? const Color(0xFF10B981)
                          : (isUsage ? const Color(0xFFF59E0B) : const Color(0xFF38BDF8));

                      return Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0B0F19),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF1E293B)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: tagColor.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          type,
                                          style: TextStyle(
                                            color: tagColor,
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${entry['reason'] ?? 'Standard floor movement'} · ${entry['quantity'] ?? 0} KG',
                                    style: const TextStyle(color: AppColors.mutedText, fontSize: 10.5),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.35)),
                              ),
                              child: Text(
                                'Stock: ${entry['newStock'] ?? 'N/A'}',
                                style: const TextStyle(
                                  color: Color(0xFF34D399),
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showHistoryMaterialPickerSheet() async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: Color(0xFF1E293B)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Select Material for Audit Ledger',
                    style: TextStyle(
                      color: AppColors.strongText,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.mutedText),
                  ),
                ],
              ),
              const Divider(color: Color(0xFF1E293B)),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _materials.length,
                  separatorBuilder: (_, _) => const Divider(color: Color(0xFF1E293B), height: 1),
                  itemBuilder: (_, index) {
                    final mat = _materials[index];
                    final isSelected = mat.id == _selectedHistoryMaterialId;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      title: Text(
                        '${mat.skuCode} - ${mat.name}',
                        style: TextStyle(
                          color: isSelected ? AppColors.primaryLight : AppColors.strongText,
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20)
                          : const Icon(Icons.circle_outlined, color: AppColors.mutedText, size: 20),
                      onTap: () => Navigator.pop(sheetContext, mat.id),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected != null && mounted) {
      setState(() => _selectedHistoryMaterialId = selected);
      final history = await _inventory.fetchHistory(selected);
      if (mounted) setState(() => _history = history);
    }
  }

  Future<void> _showMaterialPickerSheet(List<Map<String, String>> options) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: Color(0xFF1E293B)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Select Raw Material SKU',
                    style: TextStyle(
                      color: AppColors.strongText,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.mutedText),
                  ),
                ],
              ),
              const Divider(color: Color(0xFF1E293B)),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: options.length,
                  separatorBuilder: (_, _) => const Divider(color: Color(0xFF1E293B), height: 1),
                  itemBuilder: (_, index) {
                    final opt = options[index];
                    final sku = opt['sku']!;
                    final name = opt['name']!;
                    final isSelected = sku == _selectedMaterial;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      title: Text(
                        '$sku - $name',
                        style: TextStyle(
                          color: isSelected ? AppColors.primaryLight : AppColors.strongText,
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20)
                          : const Icon(Icons.circle_outlined, color: AppColors.mutedText, size: 20),
                      onTap: () => Navigator.pop(sheetContext, sku),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected != null && mounted) {
      setState(() => _selectedMaterial = selected);
    }
  }

  /// Tab 5: Dedicated Full-Screen AI Agent Coordinator
  Widget _agentTab() {
    final Map<String, String> uniqueMaterialsMap = {};
    if (_levels.isNotEmpty) {
      for (final level in _levels) {
        final sku = level['skuCode']?.toString() ?? '';
        final name = level['materialName']?.toString() ?? '';
        if (sku.isNotEmpty && !uniqueMaterialsMap.containsKey(sku)) {
          uniqueMaterialsMap[sku] = name;
        }
      }
    }
    for (final material in _materials) {
      if (material.skuCode.isNotEmpty && !uniqueMaterialsMap.containsKey(material.skuCode)) {
        uniqueMaterialsMap[material.skuCode] = material.name;
      }
    }
    final materialOptions = uniqueMaterialsMap.entries
        .map((e) => <String, String>{'sku': e.key, 'name': e.value})
        .toList();

    const quickQuantities = [100, 500, 1000, 2000, 5000];

    final selectedMaterialInfo = _levels
        .where((l) => l['skuCode'] == _selectedMaterial)
        .firstOrNull;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: _cardBoxDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: const Icon(Icons.smart_toy_rounded, color: AppColors.primaryLight, size: 20),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AI Agent Coordinator',
                            style: TextStyle(
                              color: AppColors.strongText,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'Autonomous LangGraph replenishment dispatch',
                            style: TextStyle(color: AppColors.mutedText, fontSize: 10.5),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // 5-Stage Visual Workflow Pipeline
                _buildWorkflowPipeline(),
                const SizedBox(height: 14),

                if (materialOptions.isEmpty)
                  const Text('No materials available for replenishment.', style: TextStyle(color: AppColors.mutedText))
                else ...[
                  InkWell(
                    onTap: _triggeringAi ? null : () => _showMaterialPickerSheet(materialOptions),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0B0F19),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _selectedMaterial != null
                              ? AppColors.primary.withValues(alpha: 0.5)
                              : const Color(0xFF1E293B),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.category_outlined,
                            size: 18,
                            color: _selectedMaterial != null ? AppColors.primaryLight : AppColors.mutedText,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Raw Material SKU *',
                                  style: TextStyle(color: AppColors.mutedText, fontSize: 10.5, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _selectedMaterial != null &&
                                          materialOptions.any((m) => m['sku'] == _selectedMaterial)
                                      ? '${_selectedMaterial!} - ${materialOptions.firstWhere((m) => m['sku'] == _selectedMaterial)['name']}'
                                      : 'Tap to choose raw material SKU...',
                                  style: TextStyle(
                                    color: _selectedMaterial != null ? AppColors.strongText : AppColors.mutedText,
                                    fontSize: 12.5,
                                    fontWeight: _selectedMaterial != null ? FontWeight.w700 : FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down_rounded, color: AppColors.secondaryText, size: 24),
                        ],
                      ),
                    ),
                  ),

                  if (selectedMaterialInfo != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0B0F19),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF1E293B)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Burn Rate: ${selectedMaterialInfo['burnRate'] ?? 0} KG/day',
                            style: const TextStyle(color: AppColors.mutedText, fontSize: 11),
                          ),
                          Text(
                            'Days Left: ${selectedMaterialInfo['daysRemaining'] ?? 0} days',
                            style: TextStyle(
                              color: selectedMaterialInfo['status'] == 'CRITICAL'
                                  ? AppColors.error
                                  : const Color(0xFF34D399),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0B0F19),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF1E293B)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, color: Color(0xFF38BDF8), size: 16),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Select a material SKU above to configure quantity and dispatch multi-agent replenishment.',
                              style: TextStyle(color: AppColors.mutedText, fontSize: 10.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),

                  // Quick Quantity Presets
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Quick Quantity Presets (KG):',
                        style: TextStyle(color: AppColors.mutedText, fontSize: 10.5, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: quickQuantities.map((qty) {
                          final isSelected = _requiredQuantity == qty;
                          return ActionChip(
                            label: Text('+$qty KG'),
                            onPressed: () {
                              setState(() {
                                _requiredQuantity = qty;
                                _aiQuantityController.text = qty.toString();
                              });
                            },
                            backgroundColor: isSelected
                                ? AppColors.primary.withValues(alpha: 0.3)
                                : const Color(0xFF0B0F19),
                            labelStyle: TextStyle(
                              color: isSelected ? AppColors.primaryLight : AppColors.mutedText,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(
                                color: isSelected ? AppColors.primary : const Color(0xFF1E293B),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  TextFormField(
                    controller: _aiQuantityController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: AppColors.strongText, fontSize: 12),
                    decoration: const InputDecoration(
                      labelText: 'Custom Required Quantity (KG)',
                      isDense: true,
                    ),
                    onChanged: (value) {
                      final parsed = num.tryParse(value);
                      if (parsed != null) _requiredQuantity = parsed;
                    },
                  ),
                  const SizedBox(height: 14),

                  // Unified single responsive execution button / active progress card
                  if (_triggeringAi)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF0284C7).withValues(alpha: 0.2),
                            const Color(0xFF0369A1).withValues(alpha: 0.3),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.5), width: 1.2),
                      ),
                      child: Row(
                        children: [
                          const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2.2, color: Color(0xFF38BDF8)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _aiStep == 1
                                      ? 'Agent: Evaluating Material Forecast...'
                                      : _aiStep == 2
                                      ? 'Agent: Analyzing Lead Times & Suppliers...'
                                      : 'Agent: Generating Replenishment PO...',
                                  style: const TextStyle(
                                    color: Color(0xFF38BDF8),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'LangGraph Multi-Agent coordination active...',
                                  style: TextStyle(color: AppColors.secondaryText, fontSize: 10),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _runAi,
                        icon: const Icon(Icons.auto_awesome, size: 16),
                        label: const Text(
                          'Run Autonomous Replenishment',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                ],
                if (_workflow != null) ...[
                  const SizedBox(height: 14),
                  _workflowResultCard(_workflow!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkflowPipeline() {
    final stage1Active = _aiStep >= 1 || _workflow != null;
    final stage2Active = _aiStep >= 2 || _workflow != null;
    final stage3Active = _aiStep >= 3 || _workflow != null;
    final stage4Active = _workflow != null && _workflow!.requiresApproval;
    final stage5Active = _workflow != null && !_workflow!.requiresApproval;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0B0F19),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'LANGGRAPH PIPELINE ARCHITECTURE',
                style: TextStyle(
                  color: AppColors.primaryLight,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _triggeringAi
                      ? AppColors.primary.withValues(alpha: 0.2)
                      : _workflow != null
                      ? const Color(0xFF10B981).withValues(alpha: 0.15)
                      : const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _triggeringAi
                      ? 'EXECUTION ACTIVE'
                      : _workflow != null
                      ? 'COMPLETED'
                      : 'STANDBY',
                  style: TextStyle(
                    color: _triggeringAi
                        ? AppColors.primaryLight
                        : _workflow != null
                        ? const Color(0xFF34D399)
                        : AppColors.mutedText,
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(flex: 3, child: _pipelineStage('1', 'Monitor', stage1Active)),
              _pipelineConnector(stage1Active),
              Expanded(flex: 3, child: _pipelineStage('2', 'Forecast', stage2Active)),
              _pipelineConnector(stage2Active),
              Expanded(flex: 3, child: _pipelineStage('3', 'Procure', stage3Active)),
              _pipelineConnector(_workflow != null),
              Expanded(flex: 3, child: _pipelineStage('4', 'Manager', stage4Active)),
              _pipelineConnector(_workflow != null && !_workflow!.requiresApproval),
              Expanded(flex: 3, child: _pipelineStage('5', 'Intake', stage5Active)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pipelineStage(String step, String label, bool active) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 18,
        height: 18,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? AppColors.primary : const Color(0xFF1E293B),
          shape: BoxShape.circle,
        ),
        child: Text(
          step,
          style: TextStyle(
            color: active ? Colors.white : AppColors.mutedText,
            fontSize: 8.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      const SizedBox(height: 3),
      Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: active ? AppColors.primaryLight : AppColors.mutedText,
          fontSize: 7.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );

  Widget _pipelineConnector(bool active) => Expanded(
    flex: 2,
    child: Container(
      height: 2,
      margin: const EdgeInsets.only(bottom: 10),
      color: active ? AppColors.primary : const Color(0xFF1E293B),
    ),
  );

  Widget _workflowResultCard(WorkerWorkflowResult result) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFF0B0F19),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: result.requiresApproval
            ? const Color(0xFFF59E0B).withValues(alpha: 0.5)
            : const Color(0xFF10B981).withValues(alpha: 0.5),
        width: 1.2,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Workflow: ${result.workflowId ?? 'Active'}',
                style: const TextStyle(
                  color: AppColors.primaryLight,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'monospace',
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: result.requiresApproval
                    ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                    : const Color(0xFF10B981).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                result.requiresApproval ? 'PENDING APPROVAL' : 'COMPLETED',
                style: TextStyle(
                  color: result.requiresApproval ? const Color(0xFFFBBF24) : const Color(0xFF34D399),
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Current Agent: ${result.currentAgent ?? 'Execution'} · Approval: ${result.approvalStatus ?? 'Pending'}',
          style: const TextStyle(color: AppColors.secondaryText, fontSize: 10.5),
          overflow: TextOverflow.ellipsis,
        ),
        if (result.materialName != null)
          Text(
            'Material: ${result.materialSku ?? ''} - ${result.materialName}',
            style: const TextStyle(color: AppColors.strongText, fontSize: 11.5, fontWeight: FontWeight.w700),
            overflow: TextOverflow.ellipsis,
          ),
        if (result.objective != null)
          Text(
            'Objective: ${result.objective}',
            style: const TextStyle(color: AppColors.mutedText, fontSize: 10.5),
            overflow: TextOverflow.ellipsis,
          ),
        if (result.poNumber != null) ...[
          const Divider(height: 14, color: Color(0xFF1E293B)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'PO: ${result.poNumber}',
                  style: const TextStyle(
                    color: AppColors.strongText,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'monospace',
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Supplier: ${result.supplierName ?? 'Vendor'}',
                  style: const TextStyle(color: AppColors.secondaryText, fontSize: 10.5),
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Quantity: ${result.quantity ?? _requiredQuantity} units',
                  style: const TextStyle(color: AppColors.mutedText, fontSize: 10.5),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Total: ${formatMoney(result.totalAmount ?? 0, currency: result.currency)}',
                style: const TextStyle(
                  color: Color(0xFF34D399),
                  fontWeight: FontWeight.w800,
                  fontFamily: 'monospace',
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ],
    ),
  );

  Widget _buildBottomNavigation() => Container(
    decoration: const BoxDecoration(
      color: Color(0xFF0F172A),
      border: Border(top: BorderSide(color: Color(0xFF1E293B))),
    ),
    child: SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(
          children: List.generate(_tabs.length, (i) {
            final isSelected = _index == i;
            return Expanded(
              child: InkWell(
                onTap: () => setState(() => _index = i),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _tabIcons[i],
                        size: 20,
                        color: isSelected ? AppColors.primaryLight : AppColors.mutedText,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _tabShortLabels[i],
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                          color: isSelected ? AppColors.primaryLight : AppColors.mutedText,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    ),
  );

  BoxDecoration _cardBoxDecoration() => BoxDecoration(
    color: const Color(0xFF0F172A),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: const Color(0xFF1E293B), width: 1.2),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.3),
        blurRadius: 10,
        offset: const Offset(0, 3),
      ),
    ],
  );

  Future<void> _showRegisterRollForm() async {
    final saved = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (dialogContext) => _RegisterRollDialog(
        materials: _materials,
        items: _items,
        inventory: _inventory,
      ),
    );
    if (saved == true && mounted) await _load();
  }

  Future<void> _showItemForm([InventoryItemModel? item]) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (dialogContext) => _AddOrEditItemDialog(
        item: item,
        inventory: _inventory,
      ),
    );
    if (saved == true && mounted) await _load();
  }

  Future<void> _showAlertForm() async {
    final saved = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (dialogContext) => _LogStockAlertDialog(
        items: _items,
        alerts: _alerts,
        inventory: _inventory,
      ),
    );
    if (saved == true && mounted) await _load();
  }
}

class _RegisterRollDialog extends StatefulWidget {
  final List<RawMaterialModel> materials;
  final List<InventoryItemModel> items;
  final InventoryApiService inventory;

  const _RegisterRollDialog({
    required this.materials,
    required this.items,
    required this.inventory,
  });

  @override
  State<_RegisterRollDialog> createState() => _RegisterRollDialogState();
}

class _RegisterRollDialogState extends State<_RegisterRollDialog> {
  final _formKey = GlobalKey<FormState>();
  final _batch = TextEditingController();
  late final TextEditingController _quantity;
  int? _selectedMaterial;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _quantity = TextEditingController(text: '100');
    final ownedSkus = widget.items.map((item) => item.sku.toLowerCase()).toSet();
    final availableMaterials = widget.materials
        .where((material) => ownedSkus.isEmpty || ownedSkus.contains(material.skuCode.toLowerCase()))
        .toList();
    _selectedMaterial = availableMaterials.isEmpty
        ? (widget.materials.isNotEmpty ? widget.materials.first.id : null)
        : availableMaterials.first.id;
  }

  @override
  void dispose() {
    _batch.dispose();
    _quantity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ownedSkus = widget.items.map((item) => item.sku.toLowerCase()).toSet();
    final availableMaterials = widget.materials
        .where((material) => ownedSkus.isEmpty || ownedSkus.contains(material.skuCode.toLowerCase()))
        .toList();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF1E293B), width: 1.4),
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.qr_code_2_rounded, color: Color(0xFF38BDF8), size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Register New Roll',
                            style: TextStyle(
                              color: AppColors.strongText,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'Register incoming stock with its physical batch',
                            style: TextStyle(color: AppColors.mutedText, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.auto_awesome, color: Color(0xFF38BDF8), size: 18),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Barcode ID: Auto-Generated',
                              style: TextStyle(
                                color: Color(0xFF38BDF8),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Unique QR code and roll ID will be generated automatically.',
                              style: TextStyle(color: AppColors.mutedText, fontSize: 10.5),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (availableMaterials.isEmpty && widget.materials.isEmpty)
                  const Text('No materials available.', style: TextStyle(color: AppColors.errorText))
                else
                  InkWell(
                    onTap: () async {
                      final list = availableMaterials.isNotEmpty ? availableMaterials : widget.materials;
                      final selected = await showModalBottomSheet<int>(
                        context: context,
                        backgroundColor: const Color(0xFF0F172A),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                          side: BorderSide(color: Color(0xFF1E293B)),
                        ),
                        builder: (sheetCtx) => SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Select Raw Material SKU',
                                      style: TextStyle(
                                        color: AppColors.strongText,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () => Navigator.pop(sheetCtx),
                                      icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.mutedText),
                                    ),
                                  ],
                                ),
                                const Divider(color: Color(0xFF1E293B)),
                                Flexible(
                                  child: ListView.separated(
                                    shrinkWrap: true,
                                    itemCount: list.length,
                                    separatorBuilder: (_, _) => const Divider(color: Color(0xFF1E293B), height: 1),
                                    itemBuilder: (_, index) {
                                      final mat = list[index];
                                      final isSelected = mat.id == _selectedMaterial;
                                      return ListTile(
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        title: Text(
                                          '${mat.skuCode} - ${mat.name}',
                                          style: TextStyle(
                                            color: isSelected ? AppColors.primaryLight : AppColors.strongText,
                                            fontSize: 13,
                                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                          ),
                                        ),
                                        trailing: isSelected
                                            ? const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20)
                                            : const Icon(Icons.circle_outlined, color: AppColors.mutedText, size: 20),
                                        onTap: () => Navigator.pop(sheetCtx, mat.id),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                      if (selected != null && mounted) {
                        setState(() => _selectedMaterial = selected);
                      }
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0B0F19),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF1E293B), width: 1.2),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.inventory_2_outlined, size: 18, color: Color(0xFF38BDF8)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Raw Material SKU *',
                                  style: TextStyle(color: AppColors.mutedText, fontSize: 10.5, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _selectedMaterial != null &&
                                          (availableMaterials.isNotEmpty ? availableMaterials : widget.materials)
                                              .any((m) => m.id == _selectedMaterial)
                                      ? '${(availableMaterials.isNotEmpty ? availableMaterials : widget.materials).firstWhere((m) => m.id == _selectedMaterial).skuCode} - ${(availableMaterials.isNotEmpty ? availableMaterials : widget.materials).firstWhere((m) => m.id == _selectedMaterial).name}'
                                      : 'Tap to select raw material...',
                                  style: const TextStyle(
                                    color: AppColors.strongText,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down_rounded, color: AppColors.secondaryText, size: 24),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _quantity,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: AppColors.strongText, fontSize: 13),
                  decoration: const InputDecoration(labelText: 'Roll Quantity (Whole Units) *'),
                  validator: (value) {
                    final parsed = double.tryParse(value ?? '');
                    if (parsed == null || parsed <= 0 || parsed != parsed.roundToDouble()) return 'Enter a positive whole quantity.';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _batch,
                  maxLength: 80,
                  decoration: const InputDecoration(labelText: 'Physical Batch ID *'),
                  validator: (value) => value == null || value.trim().isEmpty ? 'Enter the physical batch ID.' : null,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _submitting ? null : () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.mutedText,
                          side: const BorderSide(color: Color(0xFF1E293B)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: _submitting
                            ? null
                            : () async {
                                if (!_formKey.currentState!.validate()) return;
                                if (_selectedMaterial == null) return;
                                final navigator = Navigator.of(context);
                                final messenger = ScaffoldMessenger.of(context);
                                setState(() => _submitting = true);
                                try {
                                  await widget.inventory.createRoll(
                                    rollIdentifier: '',
                                    batchId: _batch.text.trim(),
                                    quantity: double.parse(_quantity.text),
                                    rawMaterialId: _selectedMaterial!,
                                  );
                                  if (mounted) navigator.pop(true);
                                } on ApiException catch (exception) {
                                  if (mounted) {
                                    setState(() => _submitting = false);
                                    messenger.showSnackBar(
                                      SnackBar(content: Text(exception.message), backgroundColor: AppColors.error),
                                    );
                                  }
                                } catch (_) {
                                  if (mounted) setState(() => _submitting = false);
                                }
                              },
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0284C7),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: _submitting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Register Roll', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddOrEditItemDialog extends StatefulWidget {
  final InventoryItemModel? item;
  final InventoryApiService inventory;

  const _AddOrEditItemDialog({
    this.item,
    required this.inventory,
  });

  @override
  State<_AddOrEditItemDialog> createState() => _AddOrEditItemDialogState();
}

class _AddOrEditItemDialogState extends State<_AddOrEditItemDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _sku;
  late final TextEditingController _name;
  late final TextEditingController _category;
  late final TextEditingController _stock;
  late final TextEditingController _reorder;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _sku = TextEditingController(text: widget.item?.sku ?? '');
    _name = TextEditingController(text: widget.item?.name ?? '');
    _category = TextEditingController(text: widget.item?.category ?? 'Fabric Material');
    _stock = TextEditingController(text: '${widget.item?.stockLevel ?? 500}');
    _reorder = TextEditingController(text: '${widget.item?.reorderThreshold ?? 100}');
  }

  @override
  void dispose() {
    _sku.dispose();
    _name.dispose();
    _category.dispose();
    _stock.dispose();
    _reorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.item != null;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF1E293B), width: 1.4),
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.inventory_2_rounded, color: AppColors.primaryLight, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEditing ? 'Edit Catalog Item' : 'Add Catalog Item',
                            style: const TextStyle(
                              color: AppColors.strongText,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const Text(
                            'Manage owned inventory SKU and threshold',
                            style: TextStyle(color: AppColors.mutedText, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _sku,
                  style: const TextStyle(color: AppColors.strongText, fontSize: 13),
                  decoration: const InputDecoration(labelText: 'SKU Code *'),
                  validator: (value) => value == null || value.trim().isEmpty ? 'SKU is required.' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _name,
                  style: const TextStyle(color: AppColors.strongText, fontSize: 13),
                  decoration: const InputDecoration(labelText: 'Item Name *'),
                  validator: (value) => value == null || value.trim().isEmpty ? 'Name is required.' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _category,
                  style: const TextStyle(color: AppColors.strongText, fontSize: 13),
                  decoration: const InputDecoration(labelText: 'Category'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _stock,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: AppColors.strongText, fontSize: 13),
                  decoration: const InputDecoration(labelText: 'Current Stock (Units) *'),
                  validator: (value) => int.tryParse(value ?? '') == null ? 'Enter an integer.' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _reorder,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: AppColors.strongText, fontSize: 13),
                  decoration: const InputDecoration(labelText: 'Reorder Threshold (Units) *'),
                  validator: (value) => int.tryParse(value ?? '') == null ? 'Enter an integer.' : null,
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _submitting ? null : () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _submitting
                          ? null
                          : () async {
                              if (!_formKey.currentState!.validate()) return;
                              final navigator = Navigator.of(context);
                              final messenger = ScaffoldMessenger.of(context);
                              setState(() => _submitting = true);
                              try {
                                if (widget.item == null) {
                                  await widget.inventory.createItem(
                                    sku: _sku.text.trim(),
                                    name: _name.text.trim(),
                                    category: _category.text.trim(),
                                    stockLevel: int.parse(_stock.text),
                                    reorderThreshold: int.parse(_reorder.text),
                                  );
                                } else {
                                  await widget.inventory.updateItem(
                                    InventoryItemModel(
                                      id: widget.item!.id,
                                      sku: _sku.text.trim(),
                                      name: _name.text.trim(),
                                      category: _category.text.trim(),
                                      stockLevel: int.parse(_stock.text),
                                      reorderThreshold: int.parse(_reorder.text),
                                    ),
                                  );
                                }
                                if (mounted) navigator.pop(true);
                              } on ApiException catch (exception) {
                                if (mounted) {
                                  setState(() => _submitting = false);
                                  messenger.showSnackBar(
                                    SnackBar(content: Text(exception.message), backgroundColor: AppColors.error),
                                  );
                                }
                              } catch (_) {
                                if (mounted) setState(() => _submitting = false);
                              }
                            },
                      style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                      child: _submitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(isEditing ? 'Save Changes' : 'Create Item'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LogStockAlertDialog extends StatefulWidget {
  final List<InventoryItemModel> items;
  final List<StockAlertModel> alerts;
  final InventoryApiService inventory;

  const _LogStockAlertDialog({
    required this.items,
    required this.alerts,
    required this.inventory,
  });

  @override
  State<_LogStockAlertDialog> createState() => _LogStockAlertDialogState();
}

class _LogStockAlertDialogState extends State<_LogStockAlertDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _sku;
  late final TextEditingController _packaging;
  late final TextEditingController _quantity;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _sku = TextEditingController(
      text: widget.items.isEmpty ? '' : widget.items.first.sku,
    );
    _packaging = TextEditingController(
      text: widget.items.isEmpty ? 'Standard Roll' : widget.items.first.category,
    );
    _quantity = TextEditingController(text: '500');
  }

  @override
  void dispose() {
    _sku.dispose();
    _packaging.dispose();
    _quantity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF1E293B), width: 1.4),
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.add_alert_rounded, color: Color(0xFF38BDF8), size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Log Low Stock Alert',
                            style: TextStyle(
                              color: AppColors.strongText,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'Trigger floor replenishment request',
                            style: TextStyle(color: AppColors.mutedText, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _sku,
                  style: const TextStyle(color: AppColors.strongText, fontSize: 13),
                  decoration: const InputDecoration(labelText: 'Material SKU *'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Material SKU is required.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _packaging,
                  style: const TextStyle(color: AppColors.strongText, fontSize: 13),
                  decoration: const InputDecoration(labelText: 'Packaging Type *'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Packaging Type is required.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _quantity,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: AppColors.strongText, fontSize: 13),
                  decoration: const InputDecoration(labelText: 'Quantity Requested *'),
                  validator: (value) =>
                      int.tryParse(value ?? '') == null ||
                          int.parse(value!) <= 0
                      ? 'Enter a positive quantity.'
                      : null,
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _submitting ? null : () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _submitting
                          ? null
                          : () async {
                              if (!_formKey.currentState!.validate()) return;
                              final normalizedSku = _sku.text.trim().toLowerCase();
                              final duplicate = widget.alerts
                                  .where(
                                    (alert) =>
                                        alert.sku.trim().toLowerCase() == normalizedSku &&
                                        const ['Pending', 'Processing', 'Acknowledged'].contains(alert.status),
                                  )
                                  .firstOrNull;
                              final messenger = ScaffoldMessenger.of(context);
                              if (duplicate != null) {
                                if (mounted) {
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'An active replenishment alert (${duplicate.status}) already exists for ${_sku.text.trim()}.',
                                      ),
                                      backgroundColor: const Color(0xFF0284C7),
                                    ),
                                  );
                                }
                                return;
                              }
                              final navigator = Navigator.of(context);
                              setState(() => _submitting = true);
                              try {
                                await widget.inventory.createAlert(
                                  sku: _sku.text.trim(),
                                  packagingType: _packaging.text.trim(),
                                  quantityRequested: int.parse(_quantity.text),
                                );
                                if (mounted) navigator.pop(true);
                              } on ApiException catch (exception) {
                                if (mounted) {
                                  setState(() => _submitting = false);
                                  messenger.showSnackBar(
                                    SnackBar(content: Text(exception.message), backgroundColor: AppColors.error),
                                  );
                                }
                              } catch (_) {
                                if (mounted) setState(() => _submitting = false);
                              }
                            },
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0284C7)),
                      child: _submitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Log Alert'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

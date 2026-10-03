import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/quality_models.dart';
import '../services/api_client.dart';
import '../services/quality_service.dart';
import '../services/purchase_order_service.dart';
import 'worker_dashboard_screen.dart';
import 'supply_chain_manager_dashboard_screen.dart';
import '../widgets/app_widgets.dart';

class RoleDashboardScreen extends StatefulWidget {
  const RoleDashboardScreen({
    required this.service,
    required this.role,
    this.appState,
    super.key,
  });

  final QualityService service;
  final String role;
  final AppState? appState;

  @override
  State<RoleDashboardScreen> createState() => _RoleDashboardScreenState();
}

class _RoleDashboardScreenState extends State<RoleDashboardScreen> {
  String? _message;
  String? _error;
  List<DefectReport> _defects = const [];

  @override
  void initState() {
    super.initState();
    if (widget.role != 'FloorWorker' && widget.role != 'SupplyChainManager') _load();
  }

  Future<void> _load() async {
    setState(() {
      _message = null;
      _error = null;
    });
    try {
      final data = await widget.service.getRoleDashboard(widget.role);
      List<DefectReport> defects = const [];
      if (widget.role == 'SupplyChainManager') {
        try {
          defects = await widget.service.getDefects();
        } on ApiException {
          // The dashboard still works when report refresh is temporarily down.
        }
      }
      if (mounted) {
        setState(() {
          _message = data['message'] as String? ?? '';
          _defects = defects;
        });
      }
    } on ApiException catch (exception) {
      if (mounted) setState(() => _error = exception.message);
    }
  }

  @override
  Widget build(BuildContext context) {
if (widget.role == 'FloorWorker') {
      return WorkerDashboardScreen(
        qualityService: widget.service,
        appState: widget.appState,
      );
    }
    
    if (widget.role == 'SupplyChainManager') {
      return SupplyChainManagerDashboardScreen(
        service: PurchaseOrderService(ApiClient()),
        appState: widget.appState,
      );
    }
    if (_error != null) {
      return StateMessage(
        message: _error!,
        icon: Icons.cloud_off,
        action: _load,
      );
    }
    if (_message == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Dashboard',
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(_message!),
            ),
          ),
          if (widget.role == 'SupplyChainManager') ...[
            const SizedBox(height: 20),
            Text(
              'Incoming defect reports',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            if (_defects.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No defect reports are awaiting review.'),
                ),
              )
            else
              ..._defects.take(5).map(
                (defect) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.assignment_late_outlined),
                    title: Text(
                      defect.skuCode.isEmpty ? defect.batchId : defect.skuCode,
                    ),
                    subtitle: Text(
                      defect.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Text(defect.status),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

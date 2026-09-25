import 'package:flutter/foundation.dart';
import '../models/low_stock_alert.dart';
import '../services/api_service.dart';
import '../services/purchase_order_service.dart';

class InventoryController extends ChangeNotifier {
  final ApiService _apiService;
  final PurchaseOrderService? _poService;

  InventoryController({ApiService? apiService, PurchaseOrderService? poService})
      : _apiService = apiService ?? ApiService(),
        _poService = poService;

  String _materialName = 'Food Grade BOPP Film';
  String _packagingType = 'Box Pouch';
  String _sku = 'RM-PLASTIC-502';
  double _currentStock = 150.0;
  double _minimumStock = 500.0;
  double _productionRequirement = 800.0;
  int _quantityRequested = 500;
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  // Real-time procurement workflow integration state
  bool _procurementStarted = false;
  String? _workflowId;
  String? _currentStatus;
  int? _activeProcurementId;

  // Getters
  String get materialName => _materialName;
  String get packagingType => _packagingType;
  String get sku => _sku;
  double get currentStock => _currentStock;
  double get minimumStock => _minimumStock;
  double get productionRequirement => _productionRequirement;
  int get quantityRequested => _quantityRequested;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  bool get procurementStarted => _procurementStarted;
  String? get workflowId => _workflowId;
  String? get currentStatus => _currentStatus;
  int? get activeProcurementId => _activeProcurementId;

  /// Shortage = (Minimum Stock - Current Stock). If current >= minimum, shortage is 0.
  double get shortage {
    final diff = _minimumStock - _currentStock;
    return diff > 0 ? diff : 0.0;
  }

  /// Calculated Net Deficit = (Production Req + Minimum Stock) - Current Stock
  double get calculatedNetDeficit {
    final diff = (_productionRequirement + _minimumStock) - _currentStock;
    return diff > 0 ? diff : 0.0;
  }

  // Setters / State Mutators
  void setMaterialName(String value) {
    _materialName = value;
    notifyListeners();
  }

  void setPackagingType(String value) {
    _packagingType = value;
    notifyListeners();
  }

  void setSku(String value) {
    _sku = value;
    notifyListeners();
  }

  void setCurrentStock(double value) {
    _currentStock = value < 0 ? 0 : value;
    notifyListeners();
  }

  void setMinimumStock(double value) {
    _minimumStock = value < 0 ? 0 : value;
    notifyListeners();
  }

  void setProductionRequirement(double value) {
    _productionRequirement = value < 0 ? 0 : value;
    notifyListeners();
  }

  void setQuantityRequested(int value) {
    _quantityRequested = value < 0 ? 0 : value;
    notifyListeners();
  }

  void incrementQuantity([int amount = 50]) {
    _quantityRequested += amount;
    notifyListeners();
  }

  void decrementQuantity([int amount = 50]) {
    if (_quantityRequested - amount >= 0) {
      _quantityRequested -= amount;
    } else {
      _quantityRequested = 0;
    }
    notifyListeners();
  }

  /// Triggers the ASP.NET Core API when Floor Worker submits the Low Stock Alert.
  Future<bool> submitLowStockAlert() async {
    if (_packagingType.isEmpty || _sku.isEmpty || _quantityRequested <= 0) {
      _errorMessage = 'Please provide valid packaging type, SKU, and quantity > 0.';
      _successMessage = null;
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      if (_poService != null) {
        final alertResult = await _poService.submitLowStockAlert(
          sku: _sku,
          packagingType: _packagingType,
          quantityRequested: _quantityRequested,
          workerId: 'floor_worker_1',
        );

        final id = alertResult['id'] as int? ?? 101;
        _activeProcurementId = id;
        _workflowId = alertResult['workflowId'] as String? ?? 'WF-PROC-$id';
        _currentStatus = 'Procurement Started';
        _procurementStarted = true;
        _successMessage = 'Low stock alert for SKU "$_sku" submitted. Procurement started with Workflow ID: $_workflowId';
        return true;
      }

      final alert = LowStockAlert(
        packagingType: _packagingType,
        sku: _sku,
        quantityRequested: _quantityRequested,
      );

      final success = await _apiService.submitLowStockAlert(alert);

      if (success) {
        _activeProcurementId = 101;
        _workflowId = 'WF-PROC-101';
        _currentStatus = 'Procurement Started';
        _procurementStarted = true;
        _successMessage = 'Low stock alert for SKU "$_sku" submitted to ASP.NET Core. Procurement started with Workflow ID: $_workflowId';
      } else {
        _errorMessage = 'Failed to submit low stock alert to backend.';
      }
      return success;
    } catch (e) {
      _errorMessage = 'Error submitting alert: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void resetProcurementState() {
    _procurementStarted = false;
    _workflowId = null;
    _currentStatus = null;
    _activeProcurementId = null;
    notifyListeners();
  }

  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }
}


import 'package:flutter/foundation.dart';
import '../models/low_stock_alert.dart';
import '../services/api_service.dart';

class InventoryController extends ChangeNotifier {
  final ApiService _apiService;

  InventoryController({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  String _packagingType = '';
  String _sku = '';
  int _quantityRequested = 1;
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;
  String? _workflowStatus;
  DateTime? _workflowStartedAt;

  // Getters
  String get packagingType => _packagingType;
  String get sku => _sku;
  int get quantityRequested => _quantityRequested;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;
  String? get workflowStatus => _workflowStatus;
  DateTime? get workflowStartedAt => _workflowStartedAt;

  // Setters / State Mutators
  void setPackagingType(String value) {
    _packagingType = value.trim();
    notifyListeners();
  }

  void setSku(String value) {
    _sku = value.trim();
    notifyListeners();
  }

  void setQuantityRequested(int value) {
    _quantityRequested = value < 1 ? 1 : value;
    notifyListeners();
  }

  void incrementQuantity([int amount = 1]) {
    final step = amount < 1 ? 1 : amount;
    _quantityRequested += step;
    notifyListeners();
  }

  void decrementQuantity([int amount = 1]) {
    final step = amount < 1 ? 1 : amount;
    _quantityRequested = (_quantityRequested - step) < 1
        ? 1
        : _quantityRequested - step;
    notifyListeners();
  }

  /// Triggers the ApiService when the user submits the form.
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
      final alert = LowStockAlert(
        packagingType: _packagingType,
        sku: _sku,
        quantityRequested: _quantityRequested,
      );

      final success = await _apiService.submitLowStockAlert(alert);

      if (success) {
        _successMessage = 'Low stock alert for SKU "$_sku" ($_quantityRequested x $_packagingType) submitted to AI Coordinator!';
        _workflowStatus = 'Pending Approval';
        _workflowStartedAt = DateTime.now();
      } else {
        _errorMessage = 'Failed to submit low stock alert to backend.';
        _workflowStatus = 'Submission Failed';
      }
      return success;
    } catch (e) {
      _errorMessage = 'Error submitting alert: $e';
      _workflowStatus = 'Submission Failed';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  void setWorkflowStatus(String status) {
    _workflowStatus = status;
    notifyListeners();
  }
}

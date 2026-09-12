import 'package:flutter/foundation.dart';
import '../models/low_stock_alert.dart';
import '../services/api_service.dart';

class InventoryController extends ChangeNotifier {
  final ApiService _apiService;

  InventoryController({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  String _packagingType = 'Box Pouch';
  String _sku = 'RM-PLASTIC-502';
  int _quantityRequested = 500;
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  // Getters
  String get packagingType => _packagingType;
  String get sku => _sku;
  int get quantityRequested => _quantityRequested;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  // Setters / State Mutators
  void setPackagingType(String value) {
    _packagingType = value;
    notifyListeners();
  }

  void setSku(String value) {
    _sku = value;
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

  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }
}

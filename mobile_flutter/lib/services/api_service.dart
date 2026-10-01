import '../models/low_stock_alert.dart';
import 'api_client.dart';
import 'session_storage.dart';

class ApiService {
  ApiService({ApiClient? api})
    : _api = api ?? ApiClient(storage: SessionStorage());

  final ApiClient _api;

  Future<bool> submitLowStockAlert(LowStockAlert alert) async {
    await _api.post('/inventory/low-stock-alert', alert.toJson());
    return true;
  }
}

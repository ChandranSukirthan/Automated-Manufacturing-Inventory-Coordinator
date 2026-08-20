import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/low_stock_alert.dart';

class ApiService {
  final String baseUrl;

  ApiService({this.baseUrl = 'https://localhost:7001/api'});

  /// Simulates sending a POST request to an ASP.NET Core backend.
  Future<bool> submitLowStockAlert(LowStockAlert alert) async {
    final payloadJson = jsonEncode(alert.toJson());

    if (kDebugMode) {
      print('Simulating POST request to $baseUrl/inventory/low-stock-alert');
      print('Payload: $payloadJson');
    }

    // Simulate network delay to ASP.NET Core backend
    await Future.delayed(const Duration(seconds: 1));

    // Simulated successful HTTP 200 OK response from ASP.NET Core backend
    if (kDebugMode) {
      print('ASP.NET Core Backend response: 200 OK');
    }

    return true;
  }
}

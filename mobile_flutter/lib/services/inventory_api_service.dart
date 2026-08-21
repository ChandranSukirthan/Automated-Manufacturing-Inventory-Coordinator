import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class InventoryItemModel {
  final int id;
  final String sku;
  final String name;
  final String category;
  final int stockLevel;
  final int reorderThreshold;

  InventoryItemModel({
    required this.id,
    required this.sku,
    required this.name,
    required this.category,
    required this.stockLevel,
    required this.reorderThreshold,
  });

  factory InventoryItemModel.fromJson(Map<String, dynamic> json) {
    return InventoryItemModel(
      id: json['id'] ?? 0,
      sku: json['sku'] ?? '',
      name: json['name'] ?? '',
      category: json['category'] ?? '',
      stockLevel: json['stockLevel'] ?? 0,
      reorderThreshold: json['reorderThreshold'] ?? 0,
    );
  }
}

class StockAlertModel {
  final int id;
  final String sku;
  final String packagingType;
  final int quantityRequested;
  final String status;
  final String workerId;

  StockAlertModel({
    required this.id,
    required this.sku,
    required this.packagingType,
    required this.quantityRequested,
    required this.status,
    required this.workerId,
  });

  factory StockAlertModel.fromJson(Map<String, dynamic> json) {
    return StockAlertModel(
      id: json['id'] ?? 0,
      sku: json['sku'] ?? '',
      packagingType: json['packagingType'] ?? '',
      quantityRequested: json['quantityRequested'] ?? 0,
      status: json['status'] ?? '',
      workerId: json['workerId'] ?? '',
    );
  }
}

class InventoryApiService {
  String get baseUrl {
    // Android emulator maps 10.0.2.2 to the host machine's localhost
    if (!kIsWeb && Platform.isAndroid) {
      return 'http://10.0.2.2:5158/api/Inventory';
    }
    return 'http://localhost:5158/api/Inventory';
  }

  Future<List<InventoryItemModel>> fetchInventory() async {
    try {
      final response = await http.get(Uri.parse(baseUrl));
      if (response.statusCode == 200) {
        Iterable list = json.decode(response.body);
        return list.map((model) => InventoryItemModel.fromJson(model)).toList();
      } else {
        throw Exception('Failed to load inventory. Status Code: \${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching inventory: \$e');
      return [];
    }
  }

  Future<List<StockAlertModel>> fetchAlerts() async {
    try {
      final response = await http.get(Uri.parse('\$baseUrl/alerts'));
      if (response.statusCode == 200) {
        Iterable list = json.decode(response.body);
        return list.map((model) => StockAlertModel.fromJson(model)).toList();
      } else {
        throw Exception('Failed to load alerts. Status Code: \${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching alerts: \$e');
      return [];
    }
  }
}

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
// import '../auth/models/login_response.dart';
import '../services/storage_service.dart';
import '../utils/constants.dart';

class StockItem {
  final String id;
  final String description;
  final String plu;
  final String category;
  final String barcode;
  final double onHand;
  final double costPrice;
  final double sellPrice;
  final double unitWeight;
  final String stockId;
  final String unit;
  final List<StorageArea> storageAreas;

  StockItem({
    required this.id,
    required this.description,
    required this.plu,
    required this.category,
    required this.barcode,
    required this.onHand,
    required this.costPrice,
    required this.sellPrice,
    this.unitWeight = 0.0,
    required this.stockId,
    required this.unit,
    required this.storageAreas,
  });

  factory StockItem.fromJson(Map<String, dynamic> json) {
    // Parse storage areas
    List<StorageArea> storageAreas = [];
    if (json['storage_area'] != null && json['storage_area'] is List) {
      storageAreas = (json['storage_area'] as List)
          .map((area) => StorageArea.fromJson(area))
          .toList();
    }

    // Calculate total quantity from all storage areas
    double totalQty = 0.0;
    for (var area in storageAreas) {
      totalQty += area.totalQty;
    }

    return StockItem(
      id: json['commodity_code']?.toString() ?? '',
      description: json['commodity_name']?.toString() ?? '',
      plu: json['commodity_code']?.toString() ?? '',
      category: 'General', // API doesn't provide category, using default
      barcode: json['barcode']?.toString() ?? '',
      onHand: totalQty,
      costPrice: double.tryParse(json['cost_price']?.toString() ?? '0') ?? 0.0,
      sellPrice:
          double.tryParse(json['selling_price']?.toString() ?? '0') ?? 0.0,
      unitWeight: 0.0, // Not provided in API, default to 0
      stockId: json['store_id']?.toString() ?? '',
      unit: json['unit']?.toString() ?? '',
      storageAreas: storageAreas,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'description': description,
      'plu': plu,
      'category': category,
      'barcode': barcode,
      'on_hand': onHand,
      'cost_price': costPrice,
      'sell_price': sellPrice,
      'unit_weight': unitWeight,
      'stock_id': stockId,
      'unit': unit,
      'storage_areas': storageAreas.map((area) => area.toJson()).toList(),
    };
  }
}

class StorageArea {
  final String id;
  final String name;
  final double totalQty;
  final List<QtyListItem> qtyList;

  StorageArea({
    required this.id,
    required this.name,
    required this.totalQty,
    required this.qtyList,
  });

  factory StorageArea.fromJson(Map<String, dynamic> json) {
    List<QtyListItem> qtyList = [];
    if (json['qty_list'] != null && json['qty_list'] is List) {
      qtyList = (json['qty_list'] as List)
          .map((qty) => QtyListItem.fromJson(qty))
          .toList();
    }

    return StorageArea(
      id: json['storage_area_id']?.toString() ?? '',
      name: json['storage_area_name']?.toString() ?? '',
      totalQty: double.tryParse(json['total_qty']?.toString() ?? '0') ?? 0.0,
      qtyList: qtyList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'storage_area_id': id,
      'storage_area_name': name,
      'total_qty': totalQty,
      'qty_list': qtyList.map((qty) => qty.toJson()).toList(),
    };
  }
}

class QtyListItem {
  final String id;
  final double qty;
  final String date;
  final String expiryDate;
  final String lotNo;

  QtyListItem({
    required this.id,
    required this.qty,
    required this.date,
    required this.expiryDate,
    required this.lotNo,
  });

  factory QtyListItem.fromJson(Map<String, dynamic> json) {
    return QtyListItem(
      id: json['qty_list_id']?.toString() ?? '',
      qty: double.tryParse(json['qty']?.toString() ?? '0') ?? 0.0,
      date: json['date']?.toString() ?? '',
      expiryDate: json['expiry_date']?.toString() ?? '',
      lotNo: json['lot_no']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'qty_list_id': id,
      'qty': qty,
      'date': date,
      'expiry_date': expiryDate,
      'lot_no': lotNo,
    };
  }
}

class ApiResponse {
  final bool success;
  final String message;
  final List<StockItem> data;
  final int totalPages;
  final int currentPage;
  final int totalItems;

  ApiResponse({
    required this.success,
    required this.message,
    required this.data,
    this.totalPages = 1,
    this.currentPage = 1,
    this.totalItems = 0,
  });

  factory ApiResponse.fromJson(Map<String, dynamic> json) {
    var dataList = <StockItem>[];

    // Check if response is successful
    bool isSuccess = json['code'] == 0; // Your API uses code 0 for success
    String message = json['msg']?.toString() ?? '';

    if (isSuccess && json['data'] != null && json['data']['list'] != null) {
      var items = json['data']['list'] as List;
      dataList = items.map((item) => StockItem.fromJson(item)).toList();
    }

    // Get total count from API response
    int totalItems = 0;
    if (json['data'] != null && json['data']['count'] != null) {
      totalItems = int.tryParse(json['data']['count'].toString()) ?? 0;
    }

    // Calculate total pages (assuming 100 items per page)
    int totalPages = (totalItems / 100).ceil();
    if (totalPages == 0) totalPages = 1;

    return ApiResponse(
      success: isSuccess,
      message: message,
      data: dataList,
      totalPages: totalPages,
      currentPage: 1, // API doesn't return current page, default to 1
      totalItems: totalItems,
    );
  }
}

class StockApiService {
  static const String baseUrl = 'http://merckan.com/Openapi/Commodity';

  // Get merchant ID and store ID from stored login data
  static Future<Map<String, String?>> _getAuthCredentials() async {
    final loginResponse = await StorageService.getLoginResponse();
    final selectedStore = await StorageService.getSelectedStore();

    return {
      'merchantId': loginResponse?.data?.merchantId,
      'storeId':
          selectedStore?.storeId ??
          (loginResponse?.data?.storeList.isNotEmpty == true
              ? loginResponse!.data!.storeList.first.storeId
              : null),
      'token': loginResponse?.data?.token,
    };
  }

  static Future<ApiResponse> getAllStockInfo({
    int page = 1,
    int count = 50,
  }) async {
    try {
      // Get authentication credentials from stored login data
      final credentials = await _getAuthCredentials();
      final merchantId = credentials['merchantId'];
      final storeId = credentials['storeId'];
      final token = credentials['token'];

      if (merchantId == null || storeId == null) {
        return ApiResponse(
          success: false,
          message: 'Missing merchant ID or store ID. Please login again.',
          data: [],
        );
      }

      final url = Uri.parse(
        '$baseUrl/getAllStockInfo?merchant_id=$merchantId&store_id=$storeId&page=$page&count=$count',
      );

      print('🔍 Fetching stock data from: $url');
      print('🏪 Merchant ID: $merchantId, Store ID: $storeId');

      final response = await http
          .get(
            url,
            headers: {
              'Content-Type': 'application/json; charset=utf-8;',
              if (token != null) 'Authorization': 'Bearer $token',
              'Cookie':
                  'PHPSESSID=43b097mlncp048jh865ovk7ed1; think_language=en-us',
            },
          )
          .timeout(
            Constants.connectionTimeout,
            onTimeout: () {
              throw Exception(Constants.timeoutError);
            },
          );

      print('📡 Stock API Response Status: ${response.statusCode}');
      print('📄 Stock API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return ApiResponse.fromJson(jsonData);
      } else {
        return ApiResponse(
          success: false,
          message: 'Failed to load stock data: HTTP ${response.statusCode}',
          data: [],
        );
      }
    } catch (e) {
      print('❌ Stock API Error: $e');

      if (e.toString().contains('timeout')) {
        return ApiResponse(
          success: false,
          message: Constants.timeoutError,
          data: [],
        );
      } else if (e.toString().contains('SocketException') ||
          e.toString().contains('NetworkException')) {
        return ApiResponse(
          success: false,
          message: Constants.networkError,
          data: [],
        );
      } else {
        return ApiResponse(
          success: false,
          message: 'Error loading stock data: $e',
          data: [],
        );
      }
    }
  }

  static Future<List<StockItem>> loadAllStockPages() async {
    List<StockItem> allItems = [];
    int currentPage = 1;
    bool hasMorePages = true;
    int maxRetries = 3;
    int itemsPerPage = 100; // Adjust based on your API's pagination

    print('🔄 Starting to load all stock pages...');

    while (hasMorePages) {
      int retryCount = 0;
      ApiResponse? response;

      // Retry logic for each page
      while (retryCount < maxRetries) {
        try {
          response = await getAllStockInfo(
            page: currentPage,
            count: itemsPerPage,
          );
          break; // Success, exit retry loop
        } catch (e) {
          retryCount++;
          print('⚠️ Retry $retryCount for page $currentPage: $e');

          if (retryCount >= maxRetries) {
            throw Exception(
              'Failed to load page $currentPage after $maxRetries attempts: $e',
            );
          }

          // Wait before retrying
          await Future.delayed(Duration(seconds: retryCount));
        }
      }

      if (response != null && response.success && response.data.isNotEmpty) {
        allItems.addAll(response.data);
        print(
          '✅ Loaded page $currentPage: ${response.data.length} items (Total so far: ${allItems.length})',
        );

        // Check if there are more pages based on total items vs current items
        int expectedTotalItems = response.totalItems;
        if (allItems.length >= expectedTotalItems ||
            response.data.length < itemsPerPage) {
          hasMorePages = false;
          print(
            '🏁 Finished loading all pages. Total items: ${allItems.length}',
          );
        } else {
          currentPage++;
          print('📄 Moving to page $currentPage...');
        }
      } else {
        hasMorePages = false;
        if (response != null && !response.success) {
          throw Exception(
            response.message.isEmpty
                ? 'Failed to load stock data'
                : response.message,
          );
        } else if (response == null) {
          throw Exception('No response received from API');
        } else {
          // No more data available
          print(
            '🏁 No more data available. Total items loaded: ${allItems.length}',
          );
        }
      }
    }

    return allItems;
  }
}

class LocalStockStorage {
  static const String _stockKey = 'stored_stock_items';
  static const String _lastUpdateKey = 'stock_last_update';

  static Future<void> saveStockItems(List<StockItem> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Convert items to JSON strings
      final jsonList = items.map((item) => json.encode(item.toJson())).toList();

      // Save to SharedPreferences
      await prefs.setStringList(_stockKey, jsonList);
      await prefs.setString(_lastUpdateKey, DateTime.now().toIso8601String());

      print('✅ Saved ${items.length} stock items to local storage');
    } catch (e) {
      print('❌ Error saving stock items: $e');
      throw Exception('Failed to save stock items: $e');
    }
  }

  static Future<List<StockItem>> getStoredStockItems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = prefs.getStringList(_stockKey) ?? [];

      final items = jsonList
          .map((jsonStr) {
            try {
              return StockItem.fromJson(json.decode(jsonStr));
            } catch (e) {
              print('⚠️ Error parsing stored item: $e');
              return null;
            }
          })
          .where((item) => item != null)
          .cast<StockItem>()
          .toList();

      print('📦 Retrieved ${items.length} stock items from local storage');
      return items;
    } catch (e) {
      print('❌ Error retrieving stock items: $e');
      return [];
    }
  }

  static Future<DateTime?> getLastUpdateTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timeStr = prefs.getString(_lastUpdateKey);

      if (timeStr != null) {
        return DateTime.tryParse(timeStr);
      }
      return null;
    } catch (e) {
      print('❌ Error getting last update time: $e');
      return null;
    }
  }

  static Future<void> clearStoredStock() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_stockKey);
      await prefs.remove(_lastUpdateKey);
      print('🗑️ Cleared stored stock items');
    } catch (e) {
      print('❌ Error clearing stored stock: $e');
    }
  }

  static Future<List<StockItem>> searchStockItems(String query) async {
    try {
      final allItems = await getStoredStockItems();

      if (query.isEmpty) {
        return allItems;
      }

      final lowercaseQuery = query.toLowerCase();

      return allItems.where((item) {
        return item.description.toLowerCase().contains(lowercaseQuery) ||
            item.plu.toLowerCase().contains(lowercaseQuery) ||
            item.barcode.toLowerCase().contains(lowercaseQuery) ||
            item.category.toLowerCase().contains(lowercaseQuery) ||
            item.id.toLowerCase().contains(lowercaseQuery);
      }).toList();
    } catch (e) {
      print('❌ Error searching stock items: $e');
      return [];
    }
  }
}

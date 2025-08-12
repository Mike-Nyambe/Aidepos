import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// Import your existing services - adjust paths as needed
import '../../services/storage_service.dart';
import '../../utils/constants.dart';
import '../../models/login_response.dart';

class StartCountingScreen extends StatefulWidget {
  const StartCountingScreen({super.key});

  @override
  State<StartCountingScreen> createState() => _StartCountingScreenState();
}

class _StartCountingScreenState extends State<StartCountingScreen> {
  final _searchController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _pluController = TextEditingController();
  final _categoryController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _onHandController = TextEditingController();
  final _costPriceController = TextEditingController();
  final _sellPriceController = TextEditingController();
  final _unitWeightController = TextEditingController();
  final _tareController = TextEditingController();
  final _captureController = TextEditingController();
  final _manualController = TextEditingController();

  final double _totalStockCount = 0.000;
  bool _isLoading = false;
  List<StockItem> _stockItems = [];
  List<StockItem> _filteredItems = [];
  StockItem? _selectedItem;
  DateTime? _lastStockUpdate;
  String _userName = 'User';

  @override
  void initState() {
    super.initState();
    print('🚀 StartCountingScreen initialized');

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    );

    _initializeDefaultValues();
    _loadStoredStock();
    _loadUserInfo();
    _searchController.addListener(_onSearchChanged);
  }

  Future<void> _loadUserInfo() async {
    try {
      final userInfo = await StorageService.getUserInfo();
      if (userInfo != null && userInfo.name != null) {
        setState(() {
          _userName = userInfo.name!;
        });
      }
    } catch (e) {
      print('⚠️ Error loading user info: $e');
    }
  }

  void _initializeDefaultValues() {
    _unitWeightController.text = '0.000';
    _tareController.text = '0.000';
    _captureController.text = '0.000';
    _manualController.text = '0.000';
    _pluController.text = '0';
    _barcodeController.text = '0';
    _onHandController.text = '0';
    _costPriceController.text = '0';
    _sellPriceController.text = '0';
    _categoryController.text = 'Select Category';
    _descriptionController.text = 'Tap To Enter';
  }

  void _onSearchChanged() {
    final query = _searchController.text;
    if (query.isNotEmpty) {
      _searchStockItems(query);
    } else {
      setState(() {
        _filteredItems.clear();
      });
    }
  }

  Future<void> _loadStoredStock() async {
    try {
      final storedItems = await LocalStockStorage.getStoredStockItems();
      final lastUpdate = await LocalStockStorage.getLastUpdateTime();

      setState(() {
        _stockItems = storedItems;
        _lastStockUpdate = lastUpdate;
      });

      print('📦 Loaded ${storedItems.length} stored items');
    } catch (e) {
      print('❌ Error loading stored stock: $e');
    }
  }

  Future<void> _searchStockItems(String query) async {
    try {
      final results = await LocalStockStorage.searchStockItems(query);
      setState(() {
        _filteredItems = results;
      });
    } catch (e) {
      print('❌ Error searching stock items: $e');
    }
  }

  Future<void> _loadStockFromApi() async {
    print('🔄 Load Stock button pressed!');

    setState(() {
      _isLoading = true;
    });

    try {
      // Show loading dialog
      _showLoadingDialog();

      // Get authentication credentials from your existing services
      final loginResponse = await StorageService.getLoginResponse();
      final selectedStore = await StorageService.getSelectedStore();

      if (loginResponse == null || !loginResponse.isSuccess) {
        throw Exception('No valid login session found. Please login again.');
      }

      // Get merchant ID from login response
      final merchantId = loginResponse.data?.merchantId;
      if (merchantId == null || merchantId.isEmpty) {
        throw Exception('Merchant ID not found. Please login again.');
      }

      // Get store ID from selected store or first available store
      String? storeId;
      if (selectedStore != null) {
        storeId = selectedStore.storeId;
        print(
          '📍 Using selected store: ${selectedStore.storeName} (${selectedStore.storeId})',
        );
      } else if (loginResponse.data?.storeList.isNotEmpty == true) {
        storeId = loginResponse.data!.storeList.first.storeId;
        print(
          '📍 Using first available store: ${loginResponse.data!.storeList.first.storeName} (${storeId})',
        );
      }

      if (storeId == null || storeId.isEmpty) {
        throw Exception('Store ID not found. Please select a store.');
      }

      // Get authentication token from login response
      final token = loginResponse.data?.token;
      if (token == null || token.isEmpty) {
        throw Exception('Authentication token not found. Please login again.');
      }

      print('🏪 Using Merchant ID: $merchantId, Store ID: $storeId');
      print('🔑 Token available: ${token.isNotEmpty}');
      print('👤 User: ${loginResponse.data?.userInfo?.name ?? "Unknown"}');

      // Fetch all stock items from API
      final stockItems = await StockApiService.loadAllStockPages(
        merchantId,
        storeId,
        token,
      );

      // Save to local storage
      await LocalStockStorage.saveStockItems(stockItems);

      // Update UI
      setState(() {
        _stockItems = stockItems;
        _lastStockUpdate = DateTime.now();
      });

      // Hide loading dialog
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      // Show success message
      _showSuccessMessage(
        'Successfully loaded ${stockItems.length} stock items',
      );

      print('✅ Stock loading completed successfully');
    } catch (e) {
      print('❌ Error in _loadStockFromApi: $e');

      // Hide loading dialog
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      // Show error message with specific guidance
      String errorMessage = 'Failed to load stock: $e';
      if (e.toString().contains('login') ||
          e.toString().contains('token') ||
          e.toString().contains('session')) {
        errorMessage = 'Session expired. Please logout and login again.';
      }

      _showErrorMessage(errorMessage);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: Color(0xFFFF6B35)),
                const SizedBox(width: 20),
                const Text("Loading stock items..."),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  void _selectStockItem(StockItem item) {
    setState(() {
      _selectedItem = item;
      _descriptionController.text = item.description;
      _pluController.text = item.plu;
      _categoryController.text = item.category;
      _barcodeController.text = item.barcode;
      _onHandController.text = '${item.onHand.toStringAsFixed(3)} ${item.unit}';
      _costPriceController.text = item.costPrice.toStringAsFixed(2);
      _sellPriceController.text = item.sellPrice.toStringAsFixed(2);
      _unitWeightController.text = item.unitWeight.toStringAsFixed(3);

      // Clear search results
      _filteredItems.clear();
      _searchController.clear();
    });

    // Show storage areas info if available
    if (item.storageAreas.isNotEmpty) {
      _showStorageAreasDialog(item);
    }
  }

  void _showStorageAreasDialog(StockItem item) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Storage Areas - ${item.description}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: item.storageAreas.length,
              itemBuilder: (context, index) {
                final area = item.storageAreas[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          area.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFFF6B35),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Total Qty: ${area.totalQty.toStringAsFixed(3)} ${item.unit}',
                          style: const TextStyle(fontSize: 14),
                        ),
                        if (area.qtyList.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'Quantity Details:',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                          ...area.qtyList.map(
                            (qty) => Padding(
                              padding: const EdgeInsets.only(left: 16, top: 4),
                              child: Text(
                                '• ${qty.qty.toStringAsFixed(3)} ${item.unit} (${qty.date})',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Close',
                style: TextStyle(color: Color(0xFFFF6B35)),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _descriptionController.dispose();
    _pluController.dispose();
    _categoryController.dispose();
    _barcodeController.dispose();
    _onHandController.dispose();
    _costPriceController.dispose();
    _sellPriceController.dispose();
    _unitWeightController.dispose();
    _tareController.dispose();
    _captureController.dispose();
    _manualController.dispose();
    super.dispose();
  }

  void _clearForm() {
    setState(() {
      _selectedItem = null;
      _initializeDefaultValues();
      _filteredItems.clear();
      _searchController.clear();
    });
  }

  void _zeroWeight() {
    setState(() {
      _unitWeightController.text = '0.000';
    });
  }

  void _setTare() {
    setState(() {
      _tareController.text = _unitWeightController.text;
    });
  }

  void _saveItem() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Item saved successfully!'),
        backgroundColor: Color(0xFFFF6B35),
      ),
    );
  }

  void _handleQuit() {
    Navigator.pop(context);
  }

  Widget _buildSearchResults() {
    if (_filteredItems.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFFF6B35)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFFFF6B35),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(6),
                topRight: Radius.circular(6),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.search, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Search Results (${_filteredItems.length})',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Container(
            constraints: const BoxConstraints(maxHeight: 250),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _filteredItems.length,
              itemBuilder: (context, index) {
                final item = _filteredItems[index];
                return ListTile(
                  dense: true,
                  title: Text(
                    item.description,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Code: ${item.plu} | Barcode: ${item.barcode}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      Text(
                        'On Hand: ${item.onHand.toStringAsFixed(3)} ${item.unit} | Price: \$${item.sellPrice.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFFF6B35),
                        ),
                      ),
                    ],
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Color(0xFFFF6B35),
                  ),
                  onTap: () => _selectStockItem(item),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStockStatus() {
    if (_lastStockUpdate == null) {
      return const Text(
        'No stock data loaded',
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    final timeAgo = DateTime.now().difference(_lastStockUpdate!);
    String timeText;

    if (timeAgo.inMinutes < 60) {
      timeText = '${timeAgo.inMinutes} minutes ago';
    } else if (timeAgo.inHours < 24) {
      timeText = '${timeAgo.inHours} hours ago';
    } else {
      timeText = '${timeAgo.inDays} days ago';
    }

    return Text(
      'Last updated: $timeText (${_stockItems.length} items)',
      style: const TextStyle(
        fontSize: 12,
        color: Colors.grey,
        fontStyle: FontStyle.italic,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.arrow_back,
                        color: Color(0xFFFF6B35),
                        size: 24,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Hello $_userName',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFFF6B35),
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),

                const SizedBox(height: 16),

                // Load Stock List Header
                Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFFF6B35),
                      ),
                      child: const Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Load Stock List',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    const Spacer(),
                    const Text(
                      'Stock ID:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Stock Status
                _buildStockStatus(),

                const SizedBox(height: 12),

                // Enter PLU CODE header
                const Text(
                  'Enter PLU CODE | SCAN | DESCRIPTION',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black,
                  ),
                ),

                const SizedBox(height: 12),

                // Search Bar
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: const Color(0xFFFF6B35),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'SEARCH ITEMS',
                      hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                      border: InputBorder.none,
                      suffixIcon: Icon(Icons.search, color: Color(0xFFFF6B35)),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),

                // Search Results
                _buildSearchResults(),

                const SizedBox(height: 16),

                // First Form Card - Item Details
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: const Color(0xFFFF6B35),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      // Description Row
                      Container(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 80,
                              child: Text(
                                'Description',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                _descriptionController.text,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: _selectedItem != null
                                      ? Colors.black
                                      : Colors.grey,
                                  fontWeight: _selectedItem != null
                                      ? FontWeight.w500
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: _clearForm,
                              icon: const Icon(
                                Icons.close,
                                color: Color(0xFFFF6B35),
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                      ),

                      Container(height: 1, color: const Color(0xFFFF6B35)),

                      // PLU and Category Row
                      Container(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'PLU',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _pluController.text,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: _selectedItem != null
                                          ? Colors.black
                                          : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 40,
                              color: const Color(0xFFFF6B35),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Category',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _categoryController.text,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: _selectedItem != null
                                          ? Colors.black
                                          : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      Container(height: 1, color: const Color(0xFFFF6B35)),

                      // Barcode and On Hand Row
                      Container(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Barcode',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _barcodeController.text,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: _selectedItem != null
                                          ? Colors.black
                                          : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 40,
                              color: const Color(0xFFFF6B35),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'On Hand',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _onHandController.text,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: _selectedItem != null
                                          ? Colors.black
                                          : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      Container(height: 1, color: const Color(0xFFFF6B35)),

                      // Cost Price and Sell Price Row
                      Container(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Cost Price',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _costPriceController.text,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: _selectedItem != null
                                          ? Colors.black
                                          : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 40,
                              color: const Color(0xFFFF6B35),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Sell Price',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _sellPriceController.text,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: _selectedItem != null
                                          ? Colors.black
                                          : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Second Card - Weight Management
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: const Color(0xFFFF6B35),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      // Unit/Weight and Tare Row
                      Container(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Unit/Weight (kg)',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _unitWeightController.text,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: _zeroWeight,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFFFF6B35,
                                        ),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 8,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                      ),
                                      child: const Text('Zero'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Tare (kg)',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _tareController.text,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: _setTare,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFFFF6B35,
                                        ),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 8,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                      ),
                                      child: const Text('Tare'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      Container(height: 1, color: const Color(0xFFFF6B35)),

                      // Capture and Manual Row
                      Container(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Capture (kg)',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _captureController.text,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: _saveItem,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFFFF6B35,
                                        ),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 8,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                      ),
                                      child: const Text('Save'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Manual (kg)',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _manualController.text,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: _saveItem,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFFFF6B35,
                                        ),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 8,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                      ),
                                      child: const Text('Save'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Action Buttons Row 1
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          // TODO: Upload Stock Take
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF6B35),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        child: const Text('Upload Stock Take'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF6B35),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'Total Stock Count',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _totalStockCount.toStringAsFixed(3),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Action Buttons Row 2
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _loadStockFromApi,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF6B35),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        child: _isLoading
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    height: 16,
                                    width: 16,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Text('Loading...'),
                                ],
                              )
                            : const Text('Load Stock Take'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          // TODO: Save and Continue
                          print('💾 Save and Continue pressed');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF6B35),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        child: const Text('Save and Continue'),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Action Buttons Row 3
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // TODO: Email Stock Take
                        },
                        icon: const Icon(Icons.email, size: 16),
                        label: const Text('Email Stock Take'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF6B35),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // TODO: Save To Local CSV
                        },
                        icon: const Icon(Icons.save, size: 16),
                        label: const Text('Save To Local (CSV)'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF6B35),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Quit button
                Align(
                  alignment: Alignment.bottomRight,
                  child: TextButton.icon(
                    onPressed: _handleQuit,
                    icon: const Icon(
                      Icons.logout,
                      color: Color(0xFFFF6B35),
                      size: 20,
                    ),
                    label: const Text(
                      'Quit',
                      style: TextStyle(
                        color: Color(0xFFFF6B35),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Data Models matching your API response
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
    try {
      // Parse storage areas with error handling
      List<StorageArea> storageAreas = [];
      if (json['storage_area'] != null && json['storage_area'] is List) {
        for (var areaData in json['storage_area']) {
          try {
            storageAreas.add(StorageArea.fromJson(areaData));
          } catch (e) {
            print('⚠️ Error parsing storage area: $e');
          }
        }
      }

      // Calculate total quantity from all storage areas
      double totalQty = 0.0;
      for (var area in storageAreas) {
        totalQty += area.totalQty;
      }

      // Parse basic fields with fallbacks
      String commodityCode = '';
      String commodityName = '';
      String barcode = '';
      String unit = '';
      String storeId = '';
      double costPrice = 0.0;
      double sellPrice = 0.0;

      try {
        commodityCode = json['commodity_code']?.toString() ?? '';
        commodityName = json['commodity_name']?.toString() ?? '';
        barcode = json['barcode']?.toString() ?? '';
        unit = json['unit']?.toString() ?? '';
        storeId = json['store_id']?.toString() ?? '';

        costPrice =
            double.tryParse(json['cost_price']?.toString() ?? '0') ?? 0.0;
        sellPrice =
            double.tryParse(json['selling_price']?.toString() ?? '0') ?? 0.0;
      } catch (e) {
        print('⚠️ Error parsing basic fields: $e');
      }

      return StockItem(
        id: commodityCode,
        description: commodityName,
        plu: commodityCode,
        category: 'General', // API doesn't provide category
        barcode: barcode,
        onHand: totalQty,
        costPrice: costPrice,
        sellPrice: sellPrice,
        unitWeight: 0.0, // Not provided in API
        stockId: storeId,
        unit: unit,
        storageAreas: storageAreas,
      );
    } catch (e) {
      print('❌ Error in StockItem.fromJson: $e');
      print('❌ JSON data: $json');
      rethrow;
    }
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

// API Service for stock operations
class StockApiService {
  static const String baseUrl = 'http://merckan.com/Openapi/Commodity';

  static Future<List<StockItem>> loadAllStockPages(
    String merchantId,
    String storeId,
    String token,
  ) async {
    List<StockItem> allItems = [];
    int currentPage = 1;
    bool hasMorePages = true;
    int maxRetries = 3;
    int itemsPerPage = 100;

    print('🔄 Starting to load all stock pages...');
    print('🏪 Merchant ID: $merchantId, Store ID: $storeId');

    while (hasMorePages) {
      int retryCount = 0;
      Map<String, dynamic>? response;

      // Retry logic for each page
      while (retryCount < maxRetries) {
        try {
          response = await _getAllStockInfo(
            merchantId: merchantId,
            storeId: storeId,
            token: token,
            page: currentPage,
            count: itemsPerPage,
          );
          break;
        } catch (e) {
          retryCount++;
          print('⚠️ Retry $retryCount for page $currentPage: $e');

          if (retryCount >= maxRetries) {
            throw Exception(
              'Failed to load page $currentPage after $maxRetries attempts: $e',
            );
          }

          await Future.delayed(Duration(seconds: retryCount));
        }
      }

      if (response != null &&
          response['success'] == true &&
          response['data'] != null) {
        List<StockItem> pageItems = response['data'];
        allItems.addAll(pageItems);
        print(
          '✅ Loaded page $currentPage: ${pageItems.length} items (Total so far: ${allItems.length})',
        );

        // Check if there are more pages
        int expectedTotalItems = response['totalItems'] ?? 0;
        if (allItems.length >= expectedTotalItems ||
            pageItems.length < itemsPerPage) {
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
        if (response != null && response['success'] != true) {
          throw Exception(response['message'] ?? 'Failed to load stock data');
        }
      }
    }

    return allItems;
  }

  static Future<Map<String, dynamic>> _getAllStockInfo({
    required String merchantId,
    required String storeId,
    required String token,
    int page = 1,
    int count = 50,
  }) async {
    try {
      final url = Uri.parse(
        '$baseUrl/getAllStockInfo?merchant_id=$merchantId&store_id=$storeId&page=$page&count=$count',
      );

      print('🌐 API Request: $url');
      print('🔑 Using token: ${token.substring(0, 20)}...');

      final response = await http
          .get(
            url,
            headers: {
              'Content-Type': 'application/json; charset=utf-8;',
              'Authorization':
                  token, // Remove 'Bearer ' prefix to match your curl
              'Cookie':
                  'PHPSESSID=43b097mlncp048jh865ovk7ed1; think_language=en-us',
            },
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception(
                'Connection timeout. Please check your internet connection and try again.',
              );
            },
          );

      print('📡 Stock API Response Status: ${response.statusCode}');
      print('📄 Response Length: ${response.body.length} characters');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);

        // Log the response structure safely
        print('📄 Response Code: ${jsonData['code']}');
        print('📄 Response Message: ${jsonData['msg']}');

        // Parse according to your API format
        bool isSuccess = jsonData['code'] == 0;
        String message = jsonData['msg']?.toString() ?? '';

        List<StockItem> stockItems = [];
        int totalItems = 0;

        if (isSuccess &&
            jsonData['data'] != null &&
            jsonData['data']['list'] != null) {
          var items = jsonData['data']['list'] as List;

          print('🔄 Parsing ${items.length} items...');

          // Parse each item with error handling
          for (int i = 0; i < items.length; i++) {
            try {
              var item = items[i];
              var stockItem = StockItem.fromJson(item);
              stockItems.add(stockItem);

              if (i < 3) {
                // Log first 3 items for debugging
                print(
                  '📦 Item ${i + 1}: ${stockItem.description} (${stockItem.plu})',
                );
              }
            } catch (e) {
              print('⚠️ Error parsing item ${i + 1}: $e');
              print('⚠️ Item data: ${items[i]}');
            }
          }

          if (jsonData['data']['count'] != null) {
            totalItems =
                int.tryParse(jsonData['data']['count'].toString()) ?? 0;
          }

          print(
            '✅ Successfully parsed ${stockItems.length} out of ${items.length} items',
          );
        } else {
          print('❌ API returned unsuccessful response or no data');
          print('❌ Success: $isSuccess, Message: $message');
        }

        return {
          'success': isSuccess,
          'message': message,
          'data': stockItems,
          'totalItems': totalItems,
        };
      } else {
        print('❌ HTTP Error ${response.statusCode}');
        print(
          '❌ Response body: ${response.body.length > 500 ? response.body.substring(0, 500) + "..." : response.body}',
        );

        return {
          'success': false,
          'message': 'HTTP Error ${response.statusCode}',
          'data': <StockItem>[],
          'totalItems': 0,
        };
      }
    } catch (e) {
      print('❌ Stock API Error: $e');
      print('❌ Error type: ${e.runtimeType}');

      // If it's a parsing error, let's see what we're trying to parse
      if (e.toString().contains('RangeError') ||
          e.toString().contains('FormatException')) {
        print('❌ This looks like a JSON parsing error');
      }

      return {
        'success': false,
        'message': 'Error loading stock data: $e',
        'data': <StockItem>[],
        'totalItems': 0,
      };
    }
  }
}

// Local storage for stock items
class LocalStockStorage {
  static const String _stockKey = 'stored_stock_items';
  static const String _lastUpdateKey = 'stock_last_update';

  static Future<void> saveStockItems(List<StockItem> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final jsonList = items.map((item) => json.encode(item.toJson())).toList();

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

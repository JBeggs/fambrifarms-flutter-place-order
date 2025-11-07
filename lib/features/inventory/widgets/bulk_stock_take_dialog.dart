import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:excel/excel.dart' as excel;
import '../../../models/product.dart';
import '../../../providers/inventory_provider.dart';
import '../../../providers/products_provider.dart';
import '../../../services/api_service.dart';

class BulkStockTakeDialog extends ConsumerStatefulWidget {
  final List<Product> products;

  const BulkStockTakeDialog({
    super.key,
    required this.products,
  });

  @override
  ConsumerState<BulkStockTakeDialog> createState() => _BulkStockTakeDialogState();
}

class _BulkStockTakeDialogState extends ConsumerState<BulkStockTakeDialog> {
  final Map<int, TextEditingController> _controllers = {};
  final Map<int, TextEditingController> _commentControllers = {};
  final Map<int, TextEditingController> _wastageControllers = {};
  final Map<int, String> _wastageReasons = {};
  final Map<int, double> _originalStock = {};
  final TextEditingController _searchController = TextEditingController(); // Search field controller
  // Dynamic list of products in stock take (can be added/removed)
  List<Product> _stockTakeProducts = [];
  // All products for searching (loaded from inventory provider)
  List<Product> _allProducts = [];
  bool _isLoading = false;
  bool _isLoadingProducts = true; // Track if products are still loading
  String _searchQuery = '';
  List<Map<String, dynamic>> _stockHistory = [];
  bool _showHistory = false;
  
  // Auto-save functionality
  Timer? _autoSaveTimer;
  bool _hasUnsavedChanges = false;

  @override
  void initState() {
    super.initState();
    // Initialize with products that have stock (passed from parent)
    _stockTakeProducts = List.from(widget.products);
    
    // Try to use already loaded products first (for performance)
    final productsState = ref.read(productsProvider);
    _allProducts = productsState.products;
    _isLoadingProducts = productsState.isLoading;
    
    print('[BULK_STOCK_TAKE] Initial products from provider: ${_allProducts.length}, loading: $_isLoadingProducts');
    
    // Always ensure products are loaded for search functionality
    if (_allProducts.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _refreshProductsList();
      });
    }
    
    // Provider changes are now listened to in build method via ref.watch
    
    for (final product in _stockTakeProducts) {
      _controllers[product.id] = TextEditingController();
      _commentControllers[product.id] = TextEditingController(); // Initialize comment controllers
      _wastageControllers[product.id] = TextEditingController(); // Initialize wastage controllers
      _wastageReasons[product.id] = 'Spoilage'; // Default wastage reason
      _originalStock[product.id] = product.stockLevel;
      _controllers[product.id]!.text = product.stockLevel % 1 == 0
          ? product.stockLevel.toInt().toString()
          : product.stockLevel.toStringAsFixed(2);
    }
    _loadStockHistory();
    // Auto-load saved progress after frame is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSavedProgress(autoLoad: true);
    });
  }
  
  // Get project root directory with fallback options
  String _getProjectRoot() {
    // First try: Current working directory (should work when app is run from project root)
    final currentDir = Directory.current.path;
    
    // Check if we're in the Flutter project directory by looking for pubspec.yaml
    final pubspecFile = File('$currentDir${Platform.pathSeparator}pubspec.yaml');
    if (pubspecFile.existsSync()) {
      return currentDir;
    }
    
    // Fallback: Try to find project root by looking for pubspec.yaml in parent directories
    var dir = Directory(currentDir);
    for (int i = 0; i < 5; i++) { // Check up to 5 levels up
      final pubspec = File('${dir.path}${Platform.pathSeparator}pubspec.yaml');
      if (pubspec.existsSync()) {
        return dir.path;
      }
      final parent = dir.parent;
      if (parent.path == dir.path) break; // Reached filesystem root
      dir = parent;
    }
    
    // Final fallback: Use current directory
    return currentDir;
  }

  // Auto-save functionality
  void _scheduleAutoSave() {
    _autoSaveTimer?.cancel();
    _hasUnsavedChanges = true;
    
    // Auto-save after 2 seconds of inactivity
    _autoSaveTimer = Timer(const Duration(seconds: 2), () {
      if (_hasUnsavedChanges && mounted) {
        _autoSaveProgress();
      }
    });
  }
  
  Future<void> _autoSaveProgress() async {
    if (!mounted || _stockTakeProducts.isEmpty) return;
    
    try {
      await _saveProgressInternal(showSnackbar: false);
      _hasUnsavedChanges = false;
      print('[BULK_STOCK_TAKE] Auto-saved progress');
    } catch (e) {
      print('[BULK_STOCK_TAKE] Auto-save failed: $e');
    }
  }

  // Save current progress to file (manual save with snackbar)
  Future<void> _saveProgress() async {
    await _saveProgressInternal(showSnackbar: true);
  }
  
  // Internal save method
  Future<void> _saveProgressInternal({bool showSnackbar = true}) async {
    try {
      // Get project root (works on Mac/Linux/Windows)
      final projectRoot = _getProjectRoot();
      final file = File('$projectRoot${Platform.pathSeparator}bulk_stock_take_progress.json');
      
      print('[BULK_STOCK_TAKE] Project root: $projectRoot');
      print('[BULK_STOCK_TAKE] Saving to: ${file.path}');
      
      final progressData = {
        'timestamp': DateTime.now().toIso8601String(),
        'products': _stockTakeProducts.map((product) {
          final controller = _controllers[product.id];
          final commentController = _commentControllers[product.id];
          final wastageController = _wastageControllers[product.id];
          
          return {
            'id': product.id,
            'name': product.name,
            'department': product.department,
            'unit': product.unit,
            'stockLevel': product.stockLevel,
            'minimumStock': product.minimumStock,
            'price': product.price,
            'enteredValue': controller?.text ?? '',
            'comment': commentController?.text ?? '',
            'wastageValue': wastageController?.text ?? '',
            'wastageReason': _wastageReasons[product.id] ?? 'Spoilage',
          };
        }).toList(),
      };
      
      await file.writeAsString(jsonEncode(progressData));
      print('[BULK_STOCK_TAKE] Progress saved to ${file.path}');
      
      if (mounted && showSnackbar) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Progress saved successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('[BULK_STOCK_TAKE] Error saving progress: $e');
      if (mounted && showSnackbar) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error saving progress: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
  
  // Load saved progress from file
  Future<void> _loadSavedProgress({bool autoLoad = false}) async {
    try {
      // Get project root (works on Mac/Linux/Windows)
      final projectRoot = _getProjectRoot();
      final file = File('$projectRoot${Platform.pathSeparator}bulk_stock_take_progress.json');
      
      print('[BULK_STOCK_TAKE] Project root: $projectRoot');
      print('[BULK_STOCK_TAKE] Loading from: ${file.path}');
      
      if (!await file.exists()) {
        print('[BULK_STOCK_TAKE] No saved progress file found');
        if (!autoLoad && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ No saved progress file found\n${file.path}'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return;
      }
      
      final content = await file.readAsString();
      final progressData = jsonDecode(content) as Map<String, dynamic>;
      final savedProducts = progressData['products'] as List<dynamic>;
      
      print('[BULK_STOCK_TAKE] Found saved progress with ${savedProducts.length} products');
      
      // Auto-load on init, or ask when manually triggered
      if (autoLoad) {
        _restoreProgress(savedProducts);
      } else {
        _showRestoreDialog(progressData, savedProducts);
      }
    } catch (e) {
      print('[BULK_STOCK_TAKE] Error loading saved progress: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error loading progress: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
  
  Future<void> _showRestoreDialog(Map<String, dynamic> progressData, List<dynamic> savedProducts) async {
    if (!mounted || savedProducts.isEmpty) return;
    
    final shouldRestore = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Saved Progress?'),
        content: Text('Found saved progress from ${DateTime.parse(progressData['timestamp']).toString().split('.')[0]} with ${savedProducts.length} products. Restore it?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes, Restore'),
          ),
        ],
      ),
    );
    
    if (shouldRestore == true) {
      _restoreProgress(savedProducts);
    }
  }
  
  // Restore progress from saved data
  void _restoreProgress(List<dynamic> savedProducts) {
    try {
      // CLEAR THE SEARCH FIRST!
      _searchController.clear();
      
      setState(() {
        _searchQuery = '';  // Clear search query
        _stockTakeProducts.clear();
        _controllers.clear();
        _commentControllers.clear();
        _wastageControllers.clear();
        _wastageReasons.clear();
        
        for (final productData in savedProducts) {
          final product = Product(
            id: productData['id'],
            name: productData['name'],
            department: productData['department'],
            unit: productData['unit'],
            stockLevel: (productData['stockLevel'] as num).toDouble(),
            minimumStock: (productData['minimumStock'] as num).toDouble(),
            price: (productData['price'] as num).toDouble(),
          );
          
          _stockTakeProducts.add(product);
          
          final controller = TextEditingController(text: productData['enteredValue']);
          final commentController = TextEditingController(text: productData['comment']);
          final wastageController = TextEditingController(text: productData['wastageValue']);
          
          _controllers[product.id] = controller;
          _commentControllers[product.id] = commentController;
          _wastageControllers[product.id] = wastageController;
          _wastageReasons[product.id] = productData['wastageReason'];
          _originalStock[product.id] = product.stockLevel;
        }
      });
      
      print('[BULK_STOCK_TAKE] Restored ${savedProducts.length} products from saved progress');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Restored ${savedProducts.length} products from saved progress'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('[BULK_STOCK_TAKE] Error restoring progress: $e');
    }
  }
  
  // Clear saved progress file
  Future<void> _clearSavedProgress() async {
    try {
      // Get project root (works on Mac/Linux/Windows)
      final projectRoot = _getProjectRoot();
      final file = File('$projectRoot${Platform.pathSeparator}bulk_stock_take_progress.json');
      
      if (await file.exists()) {
        await file.delete();
        print('[BULK_STOCK_TAKE] Cleared saved progress file');
      }
    } catch (e) {
      print('[BULK_STOCK_TAKE] Error clearing saved progress: $e');
    }
  }
  
  // Refresh the products list from products provider (optimized to avoid unnecessary API calls)
  Future<void> _refreshProductsList() async {
    try {
      print('[BULK_STOCK_TAKE] Checking if products need refresh...');
      
      final productsState = ref.read(productsProvider);
      
      // If products are already loaded and not stale, use them
      if (productsState.products.isNotEmpty && !productsState.isLoading) {
        setState(() {
          _allProducts = productsState.products;
          _isLoadingProducts = false;
        });
        print('[BULK_STOCK_TAKE] Using cached products: ${_allProducts.length}');
        return;
      }
      
      // Only make API call if products are empty or there's an error
      setState(() {
        _isLoadingProducts = true;
      });
      
      print('[BULK_STOCK_TAKE] Loading products from API...');
      await ref.read(productsProvider.notifier).loadProducts();
      
      final updatedState = ref.read(productsProvider);
      setState(() {
        _allProducts = updatedState.products;
        _isLoadingProducts = false;
      });
      
      print('[BULK_STOCK_TAKE] Loaded ${_allProducts.length} products from API');
    } catch (e) {
      print('[BULK_STOCK_TAKE] Error refreshing products: $e');
      setState(() {
        _isLoadingProducts = false;
      });
    }
  }

  // Add a product to the stock take list
  void _addProductToStockTake(Product product) {
    if (_stockTakeProducts.any((p) => p.id == product.id)) {
      // Already in list, just scroll to it
      return;
    }
    
    setState(() {
      _stockTakeProducts.add(product);
      _controllers[product.id] = TextEditingController();
      _commentControllers[product.id] = TextEditingController(); // Initialize comment controller for new products
      _wastageControllers[product.id] = TextEditingController(); // Initialize wastage controller for new products
      _wastageReasons[product.id] = 'Spoilage'; // Default wastage reason for new products
      _originalStock[product.id] = product.stockLevel;
      _controllers[product.id]!.text = product.stockLevel % 1 == 0
          ? product.stockLevel.toInt().toString()
          : product.stockLevel.toStringAsFixed(2);
    });
    
    // Trigger auto-save when product is added
    _scheduleAutoSave();
  }
  
  // Remove a product from the stock take list
  void _removeProductFromStockTake(int productId) {
    setState(() {
      _stockTakeProducts.removeWhere((p) => p.id == productId);
      _controllers[productId]?.dispose();
      _commentControllers[productId]?.dispose(); // Dispose comment controller
      _wastageControllers[productId]?.dispose(); // Dispose wastage controller
      _controllers.remove(productId);
      _commentControllers.remove(productId); // Remove comment controller
      _wastageControllers.remove(productId); // Remove wastage controller
      _wastageReasons.remove(productId); // Remove wastage reason
      _originalStock.remove(productId);
    });
    
    // Trigger auto-save when product is removed
    _scheduleAutoSave();
  }

  Future<void> _loadStockHistory() async {
    try {
      final apiService = ref.read(apiServiceProvider);
      final result = await apiService.getStockUpdateHistory();
      
      if (result['status'] == 'success') {
        setState(() {
          _stockHistory = List<Map<String, dynamic>>.from(result['history'] ?? []);
        });
      }
    } catch (e) {
      // Silently fail - history is optional
      print('Failed to load stock history: $e');
    }
  }

  @override
  void dispose() {
    // Cancel auto-save timer
    _autoSaveTimer?.cancel();
    
    _searchController.dispose(); // Dispose search controller
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    for (final controller in _commentControllers.values) {
      controller.dispose(); // Dispose all comment controllers
    }
    for (final controller in _wastageControllers.values) {
      controller.dispose(); // Dispose all wastage controllers
    }
    super.dispose();
  }

  // Get products currently in the stock take list (filtered by search, sorted alphabetically)
  List<Product> get _filteredStockTakeProducts {
    List<Product> products;
    
    if (_searchQuery.isEmpty) {
      products = List.from(_stockTakeProducts);
    } else {
      products = _stockTakeProducts.where((product) {
        final name = product.name.toLowerCase();
        final sku = product.sku?.toLowerCase() ?? '';
        final query = _searchQuery.toLowerCase();
        return name.contains(query) || sku.contains(query);
      }).toList();
    }
    
    // Sort alphabetically by product name
    products.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    
    return products;
  }
  
  // Get products from all products that match search but aren't in stock take list (sorted alphabetically)
  List<Product> get _searchResultsNotInList {
    if (_searchQuery.isEmpty) return [];
    
    final query = _searchQuery.toLowerCase();
    final stockTakeIds = _stockTakeProducts.map((p) => p.id).toSet();
    
    final results = _allProducts.where((product) {
      final name = product.name.toLowerCase();
      final sku = product.sku?.toLowerCase() ?? '';
      final matchesSearch = name.contains(query) || sku.contains(query);
      final notInList = !stockTakeIds.contains(product.id);
      return matchesSearch && notInList;
    }).toList();
    
    // Sort alphabetically by product name
    results.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    
    // Debug search results
    print('[BULK_STOCK_TAKE] Search query: "$query"');
    print('[BULK_STOCK_TAKE] Total products to search: ${_allProducts.length}');
    print('[BULK_STOCK_TAKE] Products already in stock take: ${stockTakeIds.length}');
    print('[BULK_STOCK_TAKE] Search results: ${results.length}');
    if (results.isNotEmpty) {
      print('[BULK_STOCK_TAKE] Found products: ${results.map((p) => p.name).join(', ')}');
    }
    
    return results;
  }

  // Check if search query doesn't match any existing products
  bool get _shouldShowAddProductButton {
    if (_searchQuery.trim().isEmpty) return false;
    if (_isLoadingProducts) return false; // Don't show button while loading
    
    final query = _searchQuery.toLowerCase().trim();
    
    // Check if any product name exactly matches or starts with the search query
    // This is more restrictive than contains() to show the button more often
    final hasMatchingProduct = _allProducts.any((product) {
      final name = product.name.toLowerCase();
      final sku = product.sku?.toLowerCase() ?? '';
      return name == query || name.startsWith(query) || 
             sku == query || sku.startsWith(query);
    });
    
    // Debug info
    print('[BULK_STOCK_TAKE] Search query: "$query"');
    print('[BULK_STOCK_TAKE] Total products: ${_allProducts.length}');
    print('[BULK_STOCK_TAKE] Has matching product: $hasMatchingProduct');
    print('[BULK_STOCK_TAKE] Is loading products: $_isLoadingProducts');
    print('[BULK_STOCK_TAKE] Should show add button: ${!hasMatchingProduct}');
    
    return !hasMatchingProduct;
  }

  // Create a new product and add it to the stock take list
  Future<void> _createAndAddProduct() async {
    print('[BULK_STOCK_TAKE] _createAndAddProduct called');
    final productName = _searchQuery.trim();
    if (productName.isEmpty) {
      print('[BULK_STOCK_TAKE] Empty product name, returning');
      return;
    }

    print('[BULK_STOCK_TAKE] Showing add product dialog for: $productName');
    
    // Show dialog to get additional product details
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _AddProductDialog(productName: productName),
    );

    print('[BULK_STOCK_TAKE] Dialog result: $result');
    if (result == null) {
      print('[BULK_STOCK_TAKE] Dialog cancelled');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final apiService = ref.read(apiServiceProvider);
      
      // Create product using the standard products endpoint
      // The result should already contain the department ID from the dialog
      final newProduct = await apiService.createProduct({
        'name': result['name'],
        'unit': result['unit'],
        'price': result['price'],
        'department': result['department_id'], // Use department ID from dialog
        'is_active': true,
        // Don't include stock_level - it's read-only according to serializer
        'minimum_stock': 5.0,
      });
      
      // Refresh products list to get the new product
      await _refreshProductsList();
      
      // Add the new product to stock take list
      _addProductToStockTake(newProduct);
      
      // Clear search query
      _searchController.clear();
      setState(() {
        _searchQuery = '';
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Product "${newProduct.name}" created and added to stock take'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to create product: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<String?> _generateStockTakePdf(List<Map<String, dynamic>> entries) async {
    try {
      print('[STOCK_TAKE_PDF] Generating PDF for ${entries.length} entries');
      
      // Sort entries by product name alphabetically
      final sortedEntries = List<Map<String, dynamic>>.from(entries)
        ..sort((a, b) {
          final productA = _stockTakeProducts.where((p) => p.id == a['product_id']).firstOrNull;
          final productB = _stockTakeProducts.where((p) => p.id == b['product_id']).firstOrNull;
          if (productA == null || productB == null) {
            print('[PDF] ERROR: Missing product in sort - A: ${productA?.name}, B: ${productB?.name}');
            return 0; // Keep original order if products not found
          }
          return productA.name.toLowerCase().compareTo(productB.name.toLowerCase());
        });
      print('[STOCK_TAKE_PDF] Sorted ${sortedEntries.length} entries alphabetically by product name');
      
      // Get current date for filename
      final now = DateTime.now();
      final dateStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      final timeStr = '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      final filename = 'BulkStockTake_${dateStr}_$timeStr.pdf';
      
      // Get Documents directory with better error handling
      Directory? documentsDir;
      try {
        if (Platform.isLinux || Platform.isMacOS) {
          final homeDir = Platform.environment['HOME'];
          print('[STOCK_TAKE_PDF] Home directory: $homeDir');
          if (homeDir != null) {
            documentsDir = Directory('$homeDir/Documents');
            print('[STOCK_TAKE_PDF] Documents directory path: ${documentsDir.path}');
            print('[STOCK_TAKE_PDF] Documents directory exists: ${documentsDir.existsSync()}');
            
            // Create Documents directory if it doesn't exist
            if (!documentsDir.existsSync()) {
              print('[STOCK_TAKE_PDF] Creating Documents directory...');
              documentsDir.createSync(recursive: true);
            }
          }
        } else if (Platform.isWindows) {
          documentsDir = await getApplicationDocumentsDirectory();
          print('[STOCK_TAKE_PDF] Windows documents directory: ${documentsDir?.path}');
        }
      } catch (e) {
        print('[STOCK_TAKE_PDF] Error getting documents directory: $e');
        throw Exception('Failed to access Documents directory: $e');
      }
      
      if (documentsDir == null) {
        throw Exception('Could not determine Documents directory path');
      }
      
      final filePath = '${documentsDir.path}/$filename';
      print('[STOCK_TAKE_PDF] Full file path: $filePath');
      
      // Create PDF document
      final pdf = pw.Document();
      
      // Build PDF content
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              // Header
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'BULK STOCK TAKE REPORT',
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      'Date: ${now.day}/${now.month}/${now.year}',
                      style: const pw.TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              
              pw.SizedBox(height: 20),
              
              // Table Header
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: const pw.BoxDecoration(
                  color: PdfColors.grey200,
                ),
                  child: pw.Row(
                    children: [
                      pw.Expanded(flex: 3, child: pw.Text('Product Name', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                      pw.Expanded(flex: 2, child: pw.Text('Counted Stock', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                      pw.Expanded(flex: 1, child: pw.Text('Unit', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                      pw.Expanded(flex: 3, child: pw.Text('Comments', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                      pw.Expanded(flex: 2, child: pw.Text('Wastage', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                      pw.Expanded(flex: 2, child: pw.Text('Wastage Reason', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                    ],
                  ),
              ),
              
              // Table Rows
              ...sortedEntries.map((entry) {
                final productId = entry['product_id'] as int;
                final product = _stockTakeProducts.where((p) => p.id == productId).firstOrNull;
                if (product == null) {
                  print('[PDF] ERROR: Product with ID $productId not found in _stockTakeProducts');
                  return pw.Container(); // Skip this entry
                }
                final countedStock = entry['counted_quantity'] as double;
                final wastageQuantity = entry['wastage_quantity'] as double? ?? 0.0;
                final wastageReason = entry['wastage_reason'] as String? ?? '';
                final comment = entry['comment'] as String? ?? '';
                
                print('[PDF] Processing ${product.name}: counted=$countedStock, wastage=$wastageQuantity, reason="$wastageReason"');
                
                return pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(
                      bottom: pw.BorderSide(color: PdfColors.grey300),
                    ),
                  ),
                  child: pw.Row(
                    children: [
                      pw.Expanded(flex: 3, child: pw.Text(product.name, style: const pw.TextStyle(fontSize: 10))),
                      pw.Expanded(flex: 2, child: pw.Text(
                        countedStock % 1 == 0 ? countedStock.toInt().toString() : countedStock.toStringAsFixed(2),
                        style: const pw.TextStyle(fontSize: 10),
                      )),
                      pw.Expanded(flex: 1, child: pw.Text(product.unit, style: const pw.TextStyle(fontSize: 10))),
                      pw.Expanded(flex: 3, child: pw.Text(comment.isEmpty ? '-' : comment, style: const pw.TextStyle(fontSize: 9))),
                      pw.Expanded(flex: 2, child: pw.Text(
                        wastageQuantity > 0 ? (wastageQuantity % 1 == 0 ? wastageQuantity.toInt().toString() : wastageQuantity.toStringAsFixed(2)) : '-',
                        style: pw.TextStyle(fontSize: 10, color: wastageQuantity > 0 ? PdfColors.red : PdfColors.black),
                      )),
                      pw.Expanded(flex: 2, child: pw.Text(
                        wastageQuantity > 0 ? wastageReason : '-',
                        style: const pw.TextStyle(fontSize: 9),
                      )),
                    ],
                  ),
                );
              }).toList(),
              
              pw.SizedBox(height: 20),
              
              // Footer
              pw.Text(
                'Generated by Fambri Farms Stock Management System',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey600,
                  fontStyle: pw.FontStyle.italic,
                ),
              ),
            ];
          },
        ),
      );
      
      // Save PDF to file
      try {
        print('[STOCK_TAKE_PDF] Generating PDF bytes...');
        final pdfBytes = await pdf.save();
        print('[STOCK_TAKE_PDF] PDF bytes generated: ${pdfBytes.length} bytes');
        
        final file = File(filePath);
        print('[STOCK_TAKE_PDF] Writing to file: $filePath');
        await file.writeAsBytes(pdfBytes);
        
        // Verify file was created
        if (file.existsSync()) {
          final fileSize = file.lengthSync();
          print('[STOCK_TAKE_PDF] ✅ PDF saved successfully!');
          print('[STOCK_TAKE_PDF] File: $filePath');
          print('[STOCK_TAKE_PDF] Size: $fileSize bytes');
          return filePath; // Return the successful file path
        } else {
          throw Exception('File was not created after write operation');
        }
      } catch (e) {
        print('[STOCK_TAKE_PDF] Error writing PDF file: $e');
        throw Exception('Failed to save PDF file: $e');
      }
      
    } catch (e) {
      print('[STOCK_TAKE_PDF] Error generating PDF: $e');
      // Return null on failure - PDF generation failure shouldn't stop stock take completion
      return null;
    }
  }

  Future<String?> _generateStockTakeExcel(List<Map<String, dynamic>> entries) async {
    try {
      print('[STOCK_TAKE_EXCEL] Generating Excel for ${entries.length} entries');
      
      // Sort entries by product name alphabetically
      final sortedEntries = List<Map<String, dynamic>>.from(entries)
        ..sort((a, b) {
          final productA = _stockTakeProducts.where((p) => p.id == a['product_id']).firstOrNull;
          final productB = _stockTakeProducts.where((p) => p.id == b['product_id']).firstOrNull;
          if (productA == null || productB == null) {
            print('[EXCEL] ERROR: Missing product in sort - A: ${productA?.name}, B: ${productB?.name}');
            return 0; // Keep original order if products not found
          }
          return productA.name.toLowerCase().compareTo(productB.name.toLowerCase());
        });
      print('[STOCK_TAKE_EXCEL] Sorted ${sortedEntries.length} entries alphabetically by product name');
      
      // Get current date for filename
      final now = DateTime.now();
      final dateStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      final timeStr = '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      final filename = 'BulkStockTake_${dateStr}_$timeStr.xlsx';
      
      // Get Documents directory
      Directory? documentsDir;
      try {
        if (Platform.isLinux || Platform.isMacOS) {
          final homeDir = Platform.environment['HOME'];
          print('[STOCK_TAKE_EXCEL] Home directory: $homeDir');
          if (homeDir != null) {
            documentsDir = Directory('$homeDir/Documents');
            print('[STOCK_TAKE_EXCEL] Documents directory path: ${documentsDir.path}');
            
            // Create Documents directory if it doesn't exist
            if (!documentsDir.existsSync()) {
              print('[STOCK_TAKE_EXCEL] Creating Documents directory...');
              documentsDir.createSync(recursive: true);
            }
          }
        } else if (Platform.isWindows) {
          documentsDir = await getApplicationDocumentsDirectory();
          print('[STOCK_TAKE_EXCEL] Windows documents directory: ${documentsDir?.path}');
        }
      } catch (e) {
        print('[STOCK_TAKE_EXCEL] Error getting documents directory: $e');
        throw Exception('Failed to access Documents directory: $e');
      }
      
      if (documentsDir == null) {
        throw Exception('Could not determine Documents directory path');
      }
      
      final filePath = '${documentsDir.path}/$filename';
      print('[STOCK_TAKE_EXCEL] Full file path: $filePath');
      
      // Create Excel workbook
      final excelFile = excel.Excel.createExcel();
      final sheet = excelFile['Stock Take'];
      
      // Remove default sheet if it exists
      if (excelFile.sheets.containsKey('Sheet1')) {
        excelFile.delete('Sheet1');
      }
      
      // Add header row
      final headerRow = [
        excel.TextCellValue('Product Name'),
        excel.TextCellValue('Counted Stock'),
        excel.TextCellValue('Unit'),
        excel.TextCellValue('Comments'),
        excel.TextCellValue('Wastage Qty'),
        excel.TextCellValue('Wastage Reason'),
      ];
      
      sheet.appendRow(headerRow);
      
      // Style header row
      for (int i = 0; i < headerRow.length; i++) {
        final cell = sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.cellStyle = excel.CellStyle(
          bold: true,
          horizontalAlign: excel.HorizontalAlign.Center,
        );
      }
      
      // Add data rows
      for (final entry in sortedEntries) {
        final productId = entry['product_id'] as int;
        final product = _stockTakeProducts.where((p) => p.id == productId).firstOrNull;
        if (product == null) {
          print('[EXCEL] ERROR: Product with ID $productId not found in _stockTakeProducts');
          continue; // Skip this entry
        }
        final countedStock = entry['counted_quantity'] as double;
        final wastageQuantity = entry['wastage_quantity'] as double? ?? 0.0;
        final wastageReason = entry['wastage_reason'] as String? ?? '';
        final comment = entry['comment'] as String? ?? '';
        
        print('[EXCEL] Processing ${product.name}: counted=$countedStock, wastage=$wastageQuantity, reason="$wastageReason"');
        
        final dataRow = [
          excel.TextCellValue(product.name),
          excel.DoubleCellValue(countedStock),
          excel.TextCellValue(product.unit),
          excel.TextCellValue(comment.isEmpty ? '-' : comment),
          wastageQuantity > 0 ? excel.DoubleCellValue(wastageQuantity) : excel.TextCellValue('-'),
          excel.TextCellValue(wastageQuantity > 0 ? wastageReason : '-'),
        ];
        
        sheet.appendRow(dataRow);
      }
      
      // Auto-fit columns
      sheet.setColumnAutoFit(0); // Product Name
      sheet.setColumnAutoFit(1); // Counted Stock
      sheet.setColumnAutoFit(2); // Unit
      sheet.setColumnAutoFit(3); // Comments
      sheet.setColumnAutoFit(4); // Wastage Qty
      sheet.setColumnAutoFit(5); // Wastage Reason
      
      // Save Excel file
      try {
        print('[STOCK_TAKE_EXCEL] Generating Excel bytes...');
        final excelBytes = excelFile.save();
        
        if (excelBytes != null) {
          print('[STOCK_TAKE_EXCEL] Excel bytes generated: ${excelBytes.length} bytes');
          
          final file = File(filePath);
          print('[STOCK_TAKE_EXCEL] Writing to file: $filePath');
          await file.writeAsBytes(excelBytes);
          
          // Verify file was created
          if (file.existsSync()) {
            final fileSize = file.lengthSync();
            print('[STOCK_TAKE_EXCEL] ✅ Excel saved successfully!');
            print('[STOCK_TAKE_EXCEL] File: $filePath');
            print('[STOCK_TAKE_EXCEL] Size: $fileSize bytes');
            return filePath; // Return the successful file path
          } else {
            throw Exception('File was not created after write operation');
          }
        } else {
          throw Exception('Failed to generate Excel bytes');
        }
      } catch (e) {
        print('[STOCK_TAKE_EXCEL] Error writing Excel file: $e');
        throw Exception('Failed to save Excel file: $e');
      }
      
    } catch (e) {
      print('[STOCK_TAKE_EXCEL] Error generating Excel: $e');
      // Return null on failure - Excel generation failure shouldn't stop stock take completion
      return null;
    }
  }

  String _buildSuccessMessage(int entryCount, String? pdfPath, String? excelPath) {
    final buffer = StringBuffer();
    buffer.write('Bulk stock take completed for $entryCount products.');
    
    if (pdfPath != null && excelPath != null) {
      buffer.write('\n✅ PDF saved: $pdfPath');
      buffer.write('\n✅ Excel saved: $excelPath');
    } else if (pdfPath != null) {
      buffer.write('\n✅ PDF saved: $pdfPath');
      buffer.write('\n❌ Excel generation failed - check console for details.');
    } else if (excelPath != null) {
      buffer.write('\n❌ PDF generation failed - check console for details.');
      buffer.write('\n✅ Excel saved: $excelPath');
    } else {
      buffer.write('\n❌ Both PDF and Excel generation failed - check console for details.');
    }
    
    return buffer.toString();
  }

  Future<void> _submitBulkStockTake() async {
    setState(() => _isLoading = true);
    
    // Cancel auto-save timer when completing stock take
    _autoSaveTimer?.cancel();

    try {
      final entries = <Map<String, dynamic>>[];
      
      // Process ALL product IDs that have any controller data
      final allProductIds = <int>{};
      allProductIds.addAll(_controllers.keys);
      allProductIds.addAll(_commentControllers.keys);
      allProductIds.addAll(_wastageControllers.keys);
      allProductIds.addAll(_stockTakeProducts.map((p) => p.id));
      
      for (final productId in allProductIds) {
        // Get product info (use from list or create minimal info)
        final product = _stockTakeProducts.where((p) => p.id == productId).firstOrNull;
        
        final controller = _controllers[productId];
        final commentController = _commentControllers[productId];
        final wastageController = _wastageControllers[productId];
        
        // Check if ANY data was entered for this product
        final hasCountedQuantity = controller != null && controller.text.trim().isNotEmpty;
        final hasComment = commentController != null && commentController.text.trim().isNotEmpty;
        final hasWastage = wastageController != null && wastageController.text.trim().isNotEmpty;
        
        // Skip products with NO data at all
        if (!hasCountedQuantity && !hasComment && !hasWastage) continue;
        
        // Parse as double to support kg and other decimal units
        final countedQuantity = double.tryParse(controller?.text ?? '') ?? 0.0;
        final currentStock = _originalStock[productId] ?? 0.0;
        
        // Get comment from comment controller
        final comment = commentController?.text.trim() ?? '';
        
        // Get wastage data with explicit null checking and verification
        final wastageText = wastageController?.text?.trim() ?? '';
        // Remove any units (kg, g, etc.) from the wastage text before parsing
        final cleanWastageText = wastageText.replaceAll(RegExp(r'[a-zA-Z]'), '').trim();
        final wastageQuantity = double.tryParse(cleanWastageText) ?? 0.0;
        final wastageReason = _wastageReasons[productId] ?? 'Spoilage';
        
        final productName = product?.name ?? 'Unknown Product';
        
        print('[STOCK_TAKE] Including $productName: counted=$countedQuantity, wastage=$wastageQuantity, comment="$comment"');
        
        // Include ALL entries with ANY data (counted quantities, wastage, or comments)
        entries.add({
          'product_id': productId,
          'counted_quantity': countedQuantity,
          'current_stock': currentStock,
          'wastage_quantity': wastageQuantity,
          'wastage_reason': wastageReason,
          'comment': comment,
        });
      }

      if (entries.isEmpty) {
        // Check if user entered ANY data at all (counted quantities, wastage, or comments)
        bool hasAnyEntries = false;
        for (final product in _stockTakeProducts) {
          final controller = _controllers[product.id];
          final commentController = _commentControllers[product.id];
          final wastageController = _wastageControllers[product.id];
          
          final hasCountedQuantity = controller != null && controller.text.isNotEmpty;
          final hasComment = commentController != null && commentController.text.trim().isNotEmpty;
          final hasWastage = wastageController != null && wastageController.text.isNotEmpty;
          
          if (hasCountedQuantity || hasComment || hasWastage) {
            hasAnyEntries = true;
            break;
          }
        }
        
        if (!hasAnyEntries) {
          throw Exception('Please enter data (counted quantities, wastage, or comments) for at least one product to complete the stock take');
        }
      }

      // Submit stock take and wait for completion
      await ref.read(inventoryProvider.notifier).bulkStockTake(entries);
      
      // Force refresh inventory data
      await ref.read(inventoryProvider.notifier).refreshAll();
      
      // Force UI refresh
      ref.read(inventoryProvider.notifier).forceRefresh();

      // Generate PDF and Excel reports
      print('[STOCK_TAKE] ===== GENERATING REPORTS WITH ${entries.length} ENTRIES =====');
      for (int i = 0; i < entries.length; i++) {
        final entry = entries[i];
        print('[STOCK_TAKE] Entry $i: ProductID=${entry['product_id']}, Counted=${entry['counted_quantity']}, Wastage=${entry['wastage_quantity']}, Reason="${entry['wastage_reason']}"');
      }
      print('[STOCK_TAKE] ====================================');
      
      String? pdfPath;
      String? excelPath;
      try {
        pdfPath = await _generateStockTakePdf(entries);
      } catch (e) {
        print('[STOCK_TAKE] PDF generation failed: $e');
      }
      
      try {
        excelPath = await _generateStockTakeExcel(entries);
      } catch (e) {
        print('[STOCK_TAKE] Excel generation failed: $e');
      }

      // Keep saved progress file for reference (removed auto-delete)
      
      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_buildSuccessMessage(entries.length, pdfPath, excelPath)),
            backgroundColor: (pdfPath != null || excelPath != null) ? Colors.green : Colors.orange,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _fillWithCurrentStock() {
    for (final product in _stockTakeProducts) {
      final controller = _controllers[product.id];
      if (controller != null) {
        controller.text = product.stockLevel % 1 == 0
            ? product.stockLevel.toInt().toString()
            : product.stockLevel.toStringAsFixed(2);
      }
    }
    setState(() {});
  }

  void _clearAllEntries() {
    for (final controller in _controllers.values) {
      controller.clear();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // Listen to products provider changes and update _allProducts accordingly
    final productsState = ref.watch(productsProvider);
    
    // Update _allProducts when provider state changes
    if (productsState.products != _allProducts) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _allProducts = productsState.products;
            _isLoadingProducts = productsState.isLoading;
          });
          print('[BULK_STOCK_TAKE] Updated products from provider: ${_allProducts.length}, loading: $_isLoadingProducts');
        }
      });
    }
    
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.95,
        height: MediaQuery.of(context).size.height * 0.9,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.inventory, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Bulk Stock Take',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _showHistory = !_showHistory;
                    });
                  },
                  icon: Icon(_showHistory ? Icons.history_toggle_off : Icons.history),
                  tooltip: _showHistory ? 'Hide WhatsApp History' : 'Show WhatsApp History',
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const Divider(),

            // WhatsApp Stock History (if shown)
            if (_showHistory) ...[
              Container(
                height: 200,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(8),
                          topRight: Radius.circular(8),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.message, color: Colors.blue[700], size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'Recent WhatsApp Stock Updates',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Colors.blue[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _stockHistory.isEmpty
                          ? const Center(
                              child: Text(
                                'No recent stock updates found',
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _stockHistory.length,
                              itemBuilder: (context, index) {
                                final update = _stockHistory[index];
                                final timestamp = DateTime.parse(update['timestamp']);
                                return ListTile(
                                  dense: true,
                                  leading: CircleAvatar(
                                    radius: 12,
                                    backgroundColor: Colors.green[100],
                                    child: Text(
                                      '${update['items_count']}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.green[700],
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    '${update['sender_name']} - ${update['order_day']}',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                  ),
                                  subtitle: Text(
                                    '${timestamp.day}/${timestamp.month}/${timestamp.year} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')} - ${update['items_count']} items',
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                  trailing: update['processed']
                                      ? Icon(Icons.check_circle, color: Colors.green[600], size: 16)
                                      : Icon(Icons.pending, color: Colors.orange[600], size: 16),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ],

            // Search and Actions
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search products...',
                      prefixIcon: const Icon(Icons.search),
                      border: const OutlineInputBorder(),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                              tooltip: 'Clear search',
                            )
                          : null,
                    ),
                    onChanged: (value) {
                      print('[BULK_STOCK_TAKE] Search field changed: "$value"');
                      setState(() => _searchQuery = value);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // Save progress button
                IconButton(
                  icon: const Icon(Icons.save),
                  onPressed: _saveProgress,
                  tooltip: 'Save progress',
                ),
                const SizedBox(width: 8),
                // Load progress button
                IconButton(
                  icon: const Icon(Icons.folder_open),
                  onPressed: () => _loadSavedProgress(autoLoad: false),
                  tooltip: 'Load saved progress',
                  color: Colors.blue,
                ),
                const SizedBox(width: 8),
                // Refresh products button
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _refreshProductsList,
                  tooltip: 'Refresh products list',
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) {
                    switch (value) {
                      case 'fill_current':
                        _fillWithCurrentStock();
                        break;
                      case 'clear_all':
                        _clearAllEntries();
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'fill_current',
                      child: Row(
                        children: [
                          Icon(Icons.content_copy),
                          SizedBox(width: 8),
                          Text('Fill with Current Stock'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'clear_all',
                      child: Row(
                        children: [
                          Icon(Icons.clear_all),
                          SizedBox(width: 8),
                          Text('Clear All'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Products List
            Expanded(
              child: Column(
                children: [
                  // Add Product Button (when no products match search)
                  if (_shouldShowAddProductButton) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        border: Border.all(color: Colors.orange[200]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.add_circle_outline, color: Colors.orange[700]),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Product not found: "$_searchQuery"',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: Colors.orange[800],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Create this product and add it to the stock take',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _isLoading ? null : _createAndAddProduct,
                            icon: _isLoading 
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.add, size: 18),
                            label: const Text('Add Product'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange[600],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  
                  // Search Results (products not in stock take list) or loading indicator
                  if (_searchQuery.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(8),
                      color: Colors.blue[50],
                      child: Row(
                        children: [
                          Icon(Icons.search, size: 16, color: Colors.blue[700]),
                          const SizedBox(width: 8),
                          _isLoadingProducts
                              ? Text(
                                  'Loading products...',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: Colors.blue[700],
                                    fontSize: 12,
                                  ),
                                )
                              : Text(
                                  'Add from search (${_searchResultsNotInList.length})',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: Colors.blue[700],
                                    fontSize: 12,
                                  ),
                                ),
                          if (_isLoadingProducts) ...[
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[700]!),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 200,
                      child: _isLoadingProducts
                          ? const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(height: 8),
                                  Text('Loading products...'),
                                ],
                              ),
                            )
                          : _searchResultsNotInList.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
                                      SizedBox(height: 8),
                                      Text(
                                        'No products found matching "${_searchQuery}"',
                                        style: TextStyle(color: Colors.grey[600]),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _searchResultsNotInList.length,
                                  itemBuilder: (context, index) {
                                    final product = _searchResultsNotInList[index];
                                    return Card(
                                      margin: const EdgeInsets.all(4),
                                      child: Padding(
                                        padding: const EdgeInsets.all(8),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                SizedBox(
                                                  width: 150,
                                                  child: Text(
                                                    product.name,
                                                    style: const TextStyle(fontWeight: FontWeight.w500),
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                Text(
                                                  'Current: ${product.stockLevel % 1 == 0 ? product.stockLevel.toInt() : product.stockLevel.toStringAsFixed(2)} ${product.unit}',
                                                  style: TextStyle(
                                                    color: Colors.grey[600],
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(width: 8),
                                            IconButton(
                                              icon: const Icon(Icons.add_circle, color: Colors.green),
                                              onPressed: () => _addProductToStockTake(product),
                                              tooltip: 'Add to stock take',
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                    ),
                    const Divider(),
                  ],
                  
                  // Stock Take Products
                  Expanded(
                    child: _filteredStockTakeProducts.isEmpty
                        ? Center(
                            child: Text(
                              _searchQuery.isEmpty
                                  ? 'No products in stock take'
                                  : 'No products match your search',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _filteredStockTakeProducts.length,
                            itemBuilder: (context, index) {
                              final product = _filteredStockTakeProducts[index];
                              final controller = _controllers[product.id];
                              final originalStock = _originalStock[product.id] ?? 0.0;
                              if (controller == null) return const SizedBox.shrink();
                  
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          // Main row with product info, count field, difference, delete
                          Row(
                            children: [
                              // Product Info
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      product.name,
                                      style: const TextStyle(fontWeight: FontWeight.w500),
                                    ),
                                    if (product.sku != null)
                                      Text(
                                        'SKU: ${product.sku}',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12,
                                        ),
                                      ),
                                    Text(
                                      'Current: ${originalStock % 1 == 0 ? originalStock.toInt() : originalStock.toStringAsFixed(2)} ${product.unit}',
                                      style: TextStyle(
                                        color: Colors.blue[700],
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      'From SHALLOME stock updates',
                                      style: TextStyle(
                                        color: Colors.green[600],
                                        fontSize: 10,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              
                              // Stock Entry Field
                              Expanded(
                                child: TextFormField(
                                  controller: controller,
                                  decoration: InputDecoration(
                                    labelText: 'Counted',
                                    border: const OutlineInputBorder(),
                                    suffixText: product.unit,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                  ),
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                                  ],
                                  onChanged: (value) {
                                    setState(() {}); // Trigger rebuild for difference calculation
                                    _scheduleAutoSave(); // Auto-save when stock count changes
                                  },
                                ),
                              ),
                              
                              // Difference Indicator
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 60,
                                child: Builder(
                                  builder: (context) {
                                    final countedText = controller.text;
                                    if (countedText.isEmpty) return const SizedBox();
                                    
                                    final counted = double.tryParse(countedText) ?? 0.0;
                                    final difference = counted - originalStock;
                                    
                                    if (difference.abs() < 0.001) {
                                      return const Icon(Icons.check, color: Colors.green, size: 20);
                                    }
                                    
                                    return Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          difference > 0 ? Icons.arrow_upward : Icons.arrow_downward,
                                          color: difference > 0 ? Colors.green : Colors.red,
                                          size: 16,
                                        ),
                                        Text(
                                          difference.abs() % 1 == 0
                                              ? difference.abs().toInt().toString()
                                              : difference.abs().toStringAsFixed(2),
                                          style: TextStyle(
                                            color: difference > 0 ? Colors.green : Colors.red,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                              
                              // Delete Button
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: () => _removeProductFromStockTake(product.id),
                                tooltip: 'Remove from stock take',
                                iconSize: 20,
                              ),
                            ],
                          ),
                          
                          // Comment field row
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _commentControllers[product.id],
                            decoration: const InputDecoration(
                              labelText: 'Comments (Optional)',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.comment_outlined, size: 18),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              isDense: true,
                            ),
                            style: const TextStyle(fontSize: 14),
                            maxLines: 1,
                            onChanged: (value) {
                              _scheduleAutoSave(); // Auto-save when comment changes
                            },
                          ),
                          
                          // Wastage fields row
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              // Wastage quantity field
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: _wastageControllers[product.id],
                                  decoration: const InputDecoration(
                                    labelText: 'Wastage Qty',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.delete_outline, size: 18),
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    isDense: true,
                                  ),
                                  style: const TextStyle(fontSize: 14),
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                                  ],
                                  onChanged: (value) {
                                    _scheduleAutoSave(); // Auto-save when wastage quantity changes
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Wastage reason dropdown
                              Expanded(
                                flex: 3,
                                child: DropdownButtonFormField<String>(
                                  value: _wastageReasons[product.id],
                                  decoration: const InputDecoration(
                                    labelText: 'Wastage Reason',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    isDense: true,
                                  ),
                                  style: const TextStyle(fontSize: 14),
                                  items: const [
                                    DropdownMenuItem(value: 'Spoilage', child: Text('Spoilage')),
                                    DropdownMenuItem(value: 'Damage', child: Text('Damage')),
                                    DropdownMenuItem(value: 'Expiry', child: Text('Expiry')),
                                    DropdownMenuItem(value: 'Theft', child: Text('Theft')),
                                    DropdownMenuItem(value: 'Processing Loss', child: Text('Processing Loss')),
                                    DropdownMenuItem(value: 'Other', child: Text('Other')),
                                  ],
                                  onChanged: (value) {
                                    setState(() {
                                      _wastageReasons[product.id] = value ?? 'Spoilage';
                                    });
                                    _scheduleAutoSave(); // Auto-save when wastage reason changes
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                            },
                          ),
                  ),
                ],
              ),
            ),

            // Summary and Actions
            const Divider(),
            Row(
              children: [
                Text(
                  '${_stockTakeProducts.length} products in stock take',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isLoading ? null : _submitBulkStockTake,
                  child: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Complete Stock Take'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AddProductDialog extends ConsumerStatefulWidget {
  final String productName;

  const _AddProductDialog({required this.productName});

  @override
  ConsumerState<_AddProductDialog> createState() => _AddProductDialogState();
}

class _AddProductDialogState extends ConsumerState<_AddProductDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  
  String _selectedUnit = 'piece';
  String _selectedDepartment = 'Vegetables';
  
  List<Map<String, dynamic>> _units = [];
  List<Map<String, dynamic>> _departments = [];
  bool _isLoadingData = true;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.productName;
    _loadBackendData();
  }

  Future<void> _loadBackendData() async {
    print('[ADD_PRODUCT] Starting to load backend data...');
    
    // NO FALLBACK DATA - LOAD FROM BACKEND ONLY
    _departments = [];
    _units = [];
    _selectedDepartment = '';
    _selectedUnit = '';
    
    // Keep loading until we get data from backend
    setState(() {
      _isLoadingData = true;
    });
    
    // Try to load from backend in background
    try {
      print('[ADD_PRODUCT] Attempting to load from API...');
      final apiService = ref.read(apiServiceProvider);
      
      final departments = await apiService.getDepartments();
      final units = await apiService.getUnitsOfMeasure();
      
      print('[ADD_PRODUCT] Successfully loaded ${departments.length} departments and ${units.length} units');
      print('[ADD_PRODUCT] Units: ${units.map((u) => '${u['name']} (${u['abbreviation']})').join(', ')}');
      print('[ADD_PRODUCT] Departments: ${departments.map((d) => d['name']).join(', ')}');
      
      setState(() {
        _departments = departments;
        _units = units;
        
        // Update selected values if they exist in new data
        final validDepartments = _departments.where((d) => d['name'] != null).toList();
        // Use 'name' field for units since abbreviation is null from backend
        final validUnits = _units.where((u) => u['name'] != null).toList();
        
        print('[ADD_PRODUCT] Valid units after filtering: ${validUnits.map((u) => u['name']).join(', ')}');
        print('[ADD_PRODUCT] Current selected unit: $_selectedUnit');
        
        // Set first valid values as defaults (from backend only)
        if (validDepartments.isNotEmpty) {
          _selectedDepartment = validDepartments.first['name'];
          print('[ADD_PRODUCT] Set selected department to: $_selectedDepartment');
        }
        
        if (validUnits.isNotEmpty) {
          _selectedUnit = validUnits.first['name']; // Use name instead of abbreviation
          print('[ADD_PRODUCT] Set selected unit to: $_selectedUnit');
        }
        
        // Mark as loaded
        _isLoadingData = false;
      });
      
      print('[ADD_PRODUCT] Backend data loaded successfully');
    } catch (e) {
      print('[ADD_PRODUCT] Failed to load backend data: $e');
      // If API fails, close dialog and show error
      if (mounted) {
        setState(() {
          _isLoadingData = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load product data from server: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
        Navigator.of(context).pop(); // Close dialog on API failure
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add New Product'),
      content: SizedBox(
        width: 400,
        child: _isLoadingData
            ? const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading departments and units...'),
                ],
              )
            : Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Product Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Product name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _units.any((u) => u['name'] == _selectedUnit) ? _selectedUnit : null,
                      decoration: const InputDecoration(
                        labelText: 'Unit',
                        border: OutlineInputBorder(),
                      ),
                      items: _units.where((unit) => unit['name'] != null).map((unit) => DropdownMenuItem(
                        value: unit['name'] as String,
                        child: Text(unit['name'] as String),
                      )).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedUnit = value!;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select a unit';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _priceController,
                      decoration: const InputDecoration(
                        labelText: 'Price',
                        border: OutlineInputBorder(),
                        prefixText: 'R ',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Price is required';
                        }
                        final price = double.tryParse(value);
                        if (price == null || price < 0) {
                          return 'Enter a valid price';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              DropdownButtonFormField<String>(
                value: _departments.any((d) => d['name'] == _selectedDepartment) ? _selectedDepartment : null,
                decoration: const InputDecoration(
                  labelText: 'Department',
                  border: OutlineInputBorder(),
                ),
                items: _departments.where((dept) => dept['name'] != null).map((dept) => DropdownMenuItem(
                  value: dept['name'] as String,
                  child: Text(dept['name'] as String),
                )).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedDepartment = value!;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a department';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        if (!_isLoadingData)
          ElevatedButton(
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                // Find the selected department to get its ID
                final selectedDept = _departments.firstWhere(
                  (d) => d['name'] == _selectedDepartment,
                  orElse: () => _departments.first,
                );
                
                Navigator.of(context).pop({
                  'name': _nameController.text.trim(),
                  'unit': _selectedUnit,
                  'price': double.parse(_priceController.text),
                  'department': _selectedDepartment,
                  'department_id': selectedDept['id'],
                });
              }
            },
            child: const Text('Create Product'),
          ),
      ],
    );
  }
}

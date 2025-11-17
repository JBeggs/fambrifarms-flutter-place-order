import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/product.dart';
import '../../../providers/inventory_provider.dart';
import '../../../providers/products_provider.dart';
import '../../../services/api_service.dart';
import '../utils/bulk_stock_take_pdf_generator.dart';

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
  final Map<int, TextEditingController> _wastageReasonControllers = {};
  final Map<int, TextEditingController> _weightControllers = {};
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
      _wastageReasonControllers[product.id] = TextEditingController(); // Initialize wastage reason controllers
      _weightControllers[product.id] = TextEditingController(); // Initialize weight controllers
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
          final weightController = _weightControllers[product.id];
          
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
            'wastageReason': _wastageReasonControllers[product.id]?.text ?? '',
            'weight': weightController?.text ?? '',
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
        _wastageReasonControllers.clear();
        _weightControllers.clear();
        
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
          _wastageReasonControllers[product.id] = TextEditingController(text: productData['wastageReason']);
          _weightControllers[product.id] = TextEditingController(text: productData['weight'] ?? '');
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
      // Insert at the beginning (index 0) so new products appear at the top
      _stockTakeProducts.insert(0, product);
      _controllers[product.id] = TextEditingController();
      _commentControllers[product.id] = TextEditingController(); // Initialize comment controller for new products
      _wastageControllers[product.id] = TextEditingController(); // Initialize wastage controller for new products
      _wastageReasonControllers[product.id] = TextEditingController(); // Initialize wastage reason controller for new products
      _weightControllers[product.id] = TextEditingController(); // Initialize weight controller for new products
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
      _wastageReasonControllers[productId]?.dispose(); // Dispose wastage reason controller
      _weightControllers[productId]?.dispose(); // Dispose weight controller
      _controllers.remove(productId);
      _commentControllers.remove(productId); // Remove comment controller
      _wastageControllers.remove(productId); // Remove wastage controller
      _wastageReasonControllers.remove(productId); // Remove wastage reason controller
      _weightControllers.remove(productId); // Remove weight controller
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
    for (final controller in _wastageReasonControllers.values) {
      controller.dispose(); // Dispose all wastage reason controllers
    }
    for (final controller in _weightControllers.values) {
      controller.dispose(); // Dispose all weight controllers
    }
    super.dispose();
  }

  // Get products currently in the stock take list (filtered by search, keeping insertion order)
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
    
    // Keep products in the order they were added (newest first)
    // No sorting - this preserves the insertion order
    
    return products;
  }
  
  // Get products from all products that match search but aren't in stock take list (sorted by relevance)
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
    
    // Sort by relevance: products starting with query first, then by alphabetical
    results.sort((a, b) {
      final aName = a.name.toLowerCase();
      final bName = b.name.toLowerCase();
      
      // Check if product name starts with the search query
      final aStartsWith = aName.startsWith(query);
      final bStartsWith = bName.startsWith(query);
      
      // Check if first word matches the search query
      final aFirstWord = aName.split(' ').first;
      final bFirstWord = bName.split(' ').first;
      final aFirstWordMatches = aFirstWord == query || aFirstWord.startsWith(query);
      final bFirstWordMatches = bFirstWord == query || bFirstWord.startsWith(query);
      
      // Priority 1: Exact match on first word
      if (aFirstWord == query && bFirstWord != query) return -1;
      if (bFirstWord == query && aFirstWord != query) return 1;
      
      // Priority 2: First word starts with query
      if (aFirstWordMatches && !bFirstWordMatches) return -1;
      if (bFirstWordMatches && !aFirstWordMatches) return 1;
      
      // Priority 3: Product name starts with query
      if (aStartsWith && !bStartsWith) return -1;
      if (bStartsWith && !aStartsWith) return 1;
      
      // Priority 4: Alphabetical order
      return aName.compareTo(bName);
    });
    
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

  // Check if search query has no results - only show create button when no search results found
  bool get _shouldShowAddProductButton {
    if (_searchQuery.trim().isEmpty) return false;
    if (_isLoadingProducts) return false; // Don't show button while loading
    
    // Only show create button when search query exists but no products match the search
    final shouldShow = _searchResultsNotInList.isEmpty;
    
    // Debug info
    print('[BULK_STOCK_TAKE] Search query: "${_searchQuery.trim()}"');
    print('[BULK_STOCK_TAKE] Search results count: ${_searchResultsNotInList.length}');
    print('[BULK_STOCK_TAKE] Is loading products: $_isLoadingProducts');
    print('[BULK_STOCK_TAKE] Should show add button: $shouldShow');
    
    return shouldShow;
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
        'department': result['department_id'], // Backend expects 'department' field with ID value
        'is_active': true,
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

  // Use shared utility for PDF generation (same logic as Android)
  Future<String?> _generateStockTakePdf(List<Map<String, dynamic>> entries) async {
    return await BulkStockTakePdfGenerator.generateStockTakePdf(
      entries: entries,
      stockTakeProducts: _stockTakeProducts,
    );
  }

  // Use shared utility for Excel generation (same logic as Android)
  Future<String?> _generateStockTakeExcel(List<Map<String, dynamic>> entries) async {
    return await BulkStockTakePdfGenerator.generateStockTakeExcel(
      entries: entries,
      stockTakeProducts: _stockTakeProducts,
    );
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

  Future<void> _completeBulkStockTake() async {
    // Build entries to check count
    final entries = <Map<String, dynamic>>[];
    
    final allProductIds = <int>{};
    allProductIds.addAll(_controllers.keys);
    allProductIds.addAll(_commentControllers.keys);
    allProductIds.addAll(_wastageControllers.keys);
    allProductIds.addAll(_stockTakeProducts.map((p) => p.id));
    
    for (final productId in allProductIds) {
      final controller = _controllers[productId];
      final commentController = _commentControllers[productId];
      final wastageController = _wastageControllers[productId];
      
      final hasCountedQuantity = controller != null && controller.text.trim().isNotEmpty;
      final hasComment = commentController != null && commentController.text.trim().isNotEmpty;
      final hasWastage = wastageController != null && wastageController.text.trim().isNotEmpty;
      
      if (!hasCountedQuantity && !hasComment && !hasWastage) continue;
      
      final wastageText = wastageController?.text?.trim() ?? '';
      final cleanWastageText = wastageText.replaceAll(RegExp(r'[a-zA-Z]'), '').trim();
      final wastageQuantity = double.tryParse(cleanWastageText) ?? 0.0;
      
      entries.add({'wastage_quantity': wastageQuantity});
    }
    
    if (entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter stock counts, wastage, or comments for at least one product'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    // Show confirmation dialog with stock adjustment mode choice
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _StockTakeConfirmationDialog(
        entryCount: entries.length,
        wastageCount: entries.where((e) => (e['wastage_quantity'] as double? ?? 0.0) > 0).length,
      ),
    );

    if (result?['confirmed'] == true) {
      final adjustmentMode = result!['mode'] as String;
      await _submitBulkStockTake(adjustmentMode: adjustmentMode);
    }
  }

  Future<void> _submitBulkStockTake({String adjustmentMode = 'set'}) async {
    setState(() => _isLoading = true);
    
    // Cancel auto-save timer when completing stock take
    _autoSaveTimer?.cancel();

    try {
      final entries = <Map<String, dynamic>>[];
      
      print('[STOCK_TAKE] Submitting bulk stock take (mode: $adjustmentMode)');
      
      // Process ALL product IDs that have any controller data
      final allProductIds = <int>{};
      allProductIds.addAll(_controllers.keys);
      allProductIds.addAll(_commentControllers.keys);
      allProductIds.addAll(_wastageControllers.keys);
      allProductIds.addAll(_weightControllers.keys);
      allProductIds.addAll(_stockTakeProducts.map((p) => p.id));
      
      for (final productId in allProductIds) {
        // Get product info (use from list or create minimal info)
        final product = _stockTakeProducts.where((p) => p.id == productId).firstOrNull;
        
        final controller = _controllers[productId];
        final commentController = _commentControllers[productId];
        final wastageController = _wastageControllers[productId];
        final weightController = _weightControllers[productId];
        
        // Check if ANY data was entered for this product
        final hasCountedQuantity = controller != null && controller.text.trim().isNotEmpty;
        final hasComment = commentController != null && commentController.text.trim().isNotEmpty;
        final hasWastage = wastageController != null && wastageController.text.trim().isNotEmpty;
        final hasWeight = weightController != null && weightController.text.trim().isNotEmpty;
        
        // Skip products with NO data at all
        if (!hasCountedQuantity && !hasComment && !hasWastage && !hasWeight) continue;
        
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
        final wastageReason = _wastageReasonControllers[productId]?.text?.trim() ?? '';
        
        // Get weight data
        final weightText = weightController?.text?.trim() ?? '';
        final cleanWeightText = weightText.replaceAll(RegExp(r'[a-zA-Z]'), '').trim();
        final weight = double.tryParse(cleanWeightText) ?? 0.0;
        
        final productName = product?.name ?? 'Unknown Product';
        
        print('[STOCK_TAKE] Including $productName: counted=$countedQuantity, wastage=$wastageQuantity, weight=$weight, comment="$comment"');
        
        // Include ALL entries with ANY data (counted quantities, wastage, weight, or comments)
        entries.add({
          'product_id': productId,
          'counted_quantity': countedQuantity,
          'current_stock': currentStock,
          'wastage_quantity': wastageQuantity,
          'wastage_reason': wastageReason,
          'weight': weight,
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
          final weightController = _weightControllers[product.id];
          
          final hasCountedQuantity = controller != null && controller.text.isNotEmpty;
          final hasComment = commentController != null && commentController.text.trim().isNotEmpty;
          final hasWastage = wastageController != null && wastageController.text.isNotEmpty;
          final hasWeight = weightController != null && weightController.text.trim().isNotEmpty;
          
          if (hasCountedQuantity || hasComment || hasWastage || hasWeight) {
            hasAnyEntries = true;
            break;
          }
        }
        
        if (!hasAnyEntries) {
          throw Exception('Please enter data (counted quantities, wastage, or comments) for at least one product to complete the stock take');
        }
      }

      // Submit stock take and wait for completion with adjustment mode
      await ref.read(inventoryProvider.notifier).bulkStockTake(entries, adjustmentMode: adjustmentMode);
      
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
    for (final controller in _commentControllers.values) {
      controller.clear();
    }
    for (final controller in _wastageControllers.values) {
      controller.clear();
    }
    for (final controller in _wastageReasonControllers.values) {
      controller.clear();
    }
    for (final controller in _weightControllers.values) {
      controller.clear();
    }
    setState(() {});
  }

  Widget _buildMainContent() {
    return Column(
      children: [
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
                      Icon(Icons.history, color: Colors.blue[700]),
                      const SizedBox(width: 8),
                      Text(
                        'WhatsApp Stock Messages',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[700],
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_stockHistory.length} messages',
                        style: TextStyle(
                          color: Colors.blue[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _stockHistory.isEmpty
                      ? const Center(
                          child: Text(
                            'No stock messages found',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _stockHistory.length,
                          itemBuilder: (context, index) {
                            final message = _stockHistory[index];
                            return ListTile(
                              dense: true,
                              title: Text(
                                message['content'] ?? 'No content',
                                style: const TextStyle(fontSize: 12),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                'From: ${message['sender'] ?? 'Unknown'} • ${message['timestamp'] ?? 'No date'}',
                                style: const TextStyle(fontSize: 10),
                              ),
                              trailing: message['processed'] == true
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

        // Search and Add Products
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search products to add to stock...',
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                ),
                onChanged: (value) {
                  setState(() => _searchQuery = value);
                },
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _fillWithCurrentStock,
              icon: const Icon(Icons.auto_fix_high, size: 18),
              label: const Text('Fill Current'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ],
        ),

        // Search Results (if searching)
        if (_searchQuery.isNotEmpty && _searchResultsNotInList.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            height: 200, // Bigger like the old version
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8),
                      topRight: Radius.circular(8),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.search, color: Colors.green[700], size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Search Results (${_searchResultsNotInList.length})',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal, // Horizontal scrolling like old version
                    itemCount: _searchResultsNotInList.length,
                    itemBuilder: (context, index) {
                      final product = _searchResultsNotInList[index];
                      final isAlreadyAdded = _stockTakeProducts.any((p) => p.id == product.id);
                      
                      return Container(
                        width: 200, // Fixed width for horizontal cards
                        margin: const EdgeInsets.only(right: 8),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  product.name, 
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Stock: ${product.stockLevel} ${product.unit}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                Text(
                                  'R${product.price.toStringAsFixed(2)}',
                                  style: const TextStyle(fontSize: 12, color: Colors.green),
                                ),
                                const Spacer(),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    isAlreadyAdded
                                        ? Icon(Icons.check_circle, color: Colors.green[600], size: 20)
                                        : IconButton(
                                            icon: const Icon(Icons.add_circle_outline, size: 20),
                                            onPressed: () => _addProductToStockTake(product),
                                          ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 16),

        // Stock Take Products List
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8),
                      topRight: Radius.circular(8),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.inventory_2, color: Colors.grey[700]),
                      const SizedBox(width: 8),
                      Text(
                        'Products in Stock (${_stockTakeProducts.length})',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                      const Spacer(),
                      if (_stockTakeProducts.isNotEmpty)
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              for (final product in _stockTakeProducts) {
                                _controllers[product.id]?.dispose();
                                _commentControllers[product.id]?.dispose();
                                _wastageControllers[product.id]?.dispose();
                                _wastageReasonControllers[product.id]?.dispose();
                                _weightControllers[product.id]?.dispose();
                              }
                              _controllers.clear();
                              _commentControllers.clear();
                              _wastageControllers.clear();
                              _wastageReasonControllers.clear();
                              _weightControllers.clear();
                              _originalStock.clear();
                              _stockTakeProducts.clear();
                            });
                            _scheduleAutoSave();
                          },
                          icon: const Icon(Icons.clear_all, size: 16),
                          label: const Text('Clear All'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red[600],
                          ),
                        ),
                    ],
                  ),
                ),
                
                // Products List
                Expanded(
                  child: _isLoadingProducts
                      ? const Center(child: CircularProgressIndicator())
                      : _stockTakeProducts.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.inventory_2_outlined,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No products in stock',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Search and add products above, or use "Fill Current" to add all products with stock',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[500],
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: _filteredStockTakeProducts.length,
                              itemBuilder: (context, index) {
                                final product = _filteredStockTakeProducts[index];
                                final originalStock = _originalStock[product.id] ?? 0.0;
                                
                                return Card(
                                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                                                    '\$${product.price.toStringAsFixed(2)} per ${product.unit}',
                                                    style: TextStyle(
                                                      color: Colors.grey[600],
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            
                                            const SizedBox(width: 12),
                                            
                                            // Count Field
                                            Expanded(
                                              flex: 1,
                                              child: TextFormField(
                                                controller: _controllers[product.id],
                                                decoration: const InputDecoration(
                                                  labelText: 'Counted',
                                                  border: OutlineInputBorder(),
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
                                                  _scheduleAutoSave(); // Auto-save when count changes
                                                },
                                              ),
                                            ),
                                            
                                            const SizedBox(width: 12),
                                            
                                            // Difference Display
                                            Expanded(
                                              flex: 1,
                                              child: Builder(
                                                builder: (context) {
                                                  final countedText = _controllers[product.id]?.text ?? '';
                                                  final countedValue = double.tryParse(countedText) ?? 0.0;
                                                  final difference = countedValue - originalStock;
                                                  
                                                  Color diffColor = Colors.grey[600]!;
                                                  String diffPrefix = '';
                                                  if (difference > 0) {
                                                    diffColor = Colors.green[600]!;
                                                    diffPrefix = '+';
                                                  } else if (difference < 0) {
                                                    diffColor = Colors.red[600]!;
                                                  }
                                                  
                                                  return Column(
                                                    crossAxisAlignment: CrossAxisAlignment.center,
                                                    children: [
                                                      Text(
                                                        'Difference',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color: Colors.grey[600],
                                                        ),
                                                      ),
                                                      Text(
                                                        '$diffPrefix${difference % 1 == 0 ? difference.toInt() : difference.toStringAsFixed(2)}',
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          fontWeight: FontWeight.bold,
                                                          color: diffColor,
                                                        ),
                                                      ),
                                                    ],
                                                  );
                                                },
                                              ),
                                            ),
                                            
                                            const SizedBox(width: 8),
                                            
                                            // Delete Button
                                            IconButton(
                                              onPressed: () => _removeProductFromStockTake(product.id),
                                              icon: const Icon(Icons.delete_outline),
                                              color: Colors.red[600],
                                              tooltip: 'Remove from stock',
                                            ),
                                          ],
                                        ),
                                        
                                        const SizedBox(height: 8),
                                        
                                        // Comment field
                                        TextFormField(
                                          controller: _commentControllers[product.id],
                                          decoration: const InputDecoration(
                                            labelText: 'Comments (optional)',
                                            hintText: 'Add notes about this product...',
                                            border: OutlineInputBorder(),
                                            prefixIcon: Icon(Icons.comment_outlined, size: 18),
                                            contentPadding: EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                            isDense: true,
                                          ),
                                          style: const TextStyle(fontSize: 14),
                                          maxLines: 2,
                                          onChanged: (value) {
                                            _scheduleAutoSave(); // Auto-save when comment changes
                                          },
                                        ),
                                        
                                        const SizedBox(height: 8),
                                        
                                        // Weight field
                                        TextFormField(
                                          controller: _weightControllers[product.id],
                                          decoration: const InputDecoration(
                                            labelText: 'Weight (kg)',
                                            hintText: 'Enter weight if applicable',
                                            border: OutlineInputBorder(),
                                            prefixIcon: Icon(Icons.scale, size: 18),
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
                                            _scheduleAutoSave(); // Auto-save when weight changes
                                          },
                                        ),
                                        
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
                                            // Wastage reason text input
                                            Expanded(
                                              flex: 3,
                                              child: TextFormField(
                                                controller: _wastageReasonControllers[product.id],
                                                decoration: const InputDecoration(
                                                  labelText: 'Wastage Reason',
                                                  hintText: 'e.g. Spoilage, Damage, Expiry',
                                                  border: OutlineInputBorder(),
                                                  contentPadding: EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 8,
                                                  ),
                                                  isDense: true,
                                                ),
                                                style: const TextStyle(fontSize: 14),
                                                onChanged: (value) {
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
        ),
      ],
    );
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
    
    // Check if we're on mobile (screen width < 600px) or tablet/desktop
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    
    if (isMobile) {
      // Full screen on mobile
      return Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Icon(Icons.inventory, color: Theme.of(context).primaryColor),
              const SizedBox(width: 8),
              const Text('Stock'),
            ],
          ),
          actions: [
            IconButton(
              onPressed: () {
                setState(() {
                  _showHistory = !_showHistory;
                });
              },
              icon: Icon(_showHistory ? Icons.history_toggle_off : Icons.history),
              tooltip: _showHistory ? 'Hide WhatsApp History' : 'Show WhatsApp History',
            ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Expanded(child: _buildMainContent()),
                // Mobile action buttons
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    border: Border(
                      top: BorderSide(color: Colors.grey[300]!),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '${_stockTakeProducts.length} products in stock',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _completeBulkStockTake,
                        child: _isLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Complete Stock'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      // Desktop/tablet - use dialog
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
                      'Stock',
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
              Expanded(child: _buildMainContent()),
              // Desktop action buttons
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
                    onPressed: _isLoading ? null : _completeBulkStockTake,
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
  
  String? _selectedUnit;
  String? _selectedDepartment;
  
  List<Map<String, dynamic>> _units = [];
  List<Map<String, dynamic>> _departments = [];
  bool _isLoadingData = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.productName;
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      print('[ADD_PRODUCT] Loading units and departments...');
      
      // Load units
      try {
        final unitsData = await ref.read(apiServiceProvider).getUnitsOfMeasure();
        print('[ADD_PRODUCT] Units loaded: ${unitsData.length}');
        print('[ADD_PRODUCT] Units data: $unitsData');
        _units = unitsData;
      } catch (e) {
        print('[ADD_PRODUCT] Error loading units: $e');
        throw Exception('Failed to load units: $e');
      }
      
      // Load departments
      try {
        final deptsData = await ref.read(apiServiceProvider).getDepartments();
        print('[ADD_PRODUCT] Departments loaded: ${deptsData.length}');
        print('[ADD_PRODUCT] Departments data: $deptsData');
        _departments = deptsData;
      } catch (e) {
        print('[ADD_PRODUCT] Error loading departments: $e');
        throw Exception('Failed to load departments: $e');
      }
      
      // Validate we got data
      if (_units.isEmpty) {
        throw Exception('No units available. Please check your backend configuration.');
      }
      if (_departments.isEmpty) {
        throw Exception('No departments available. Please check your backend configuration.');
      }
      
      // Set default values after loading data
      if (_units.isNotEmpty) {
        // Try to find 'piece' or 'kg', otherwise use first unit
        final pieceUnit = _units.firstWhere(
          (u) => u['name']?.toString().toLowerCase() == 'piece',
          orElse: () => _units.firstWhere(
            (u) => u['name']?.toString().toLowerCase() == 'kg',
            orElse: () => _units.first,
          ),
        );
        _selectedUnit = pieceUnit['name'];
        print('[ADD_PRODUCT] Selected default unit: $_selectedUnit');
      }
      
      if (_departments.isNotEmpty) {
        // Try to find 'Vegetables', otherwise use first department
        final vegDept = _departments.firstWhere(
          (d) => d['name']?.toString() == 'Vegetables',
          orElse: () => _departments.first,
        );
        _selectedDepartment = vegDept['name'];
        print('[ADD_PRODUCT] Selected default department: $_selectedDepartment');
      }
      
      print('[ADD_PRODUCT] Data loading complete - Unit: $_selectedUnit, Dept: $_selectedDepartment');
    } catch (e, stackTrace) {
      print('[ADD_PRODUCT] Error loading data: $e');
      print('[ADD_PRODUCT] Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _loadError = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingData = false);
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
            ? const Center(child: CircularProgressIndicator())
            : _loadError != null
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: Colors.red[700]),
                      const SizedBox(height: 16),
                      Text(
                        'Failed to Load Data',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.red[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _loadError!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _isLoadingData = true;
                            _loadError = null;
                          });
                          _loadData();
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
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
                        labelText: 'Product Name *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a product name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    DropdownButtonFormField<String>(
                      value: _selectedUnit,
                      decoration: const InputDecoration(
                        labelText: 'Unit *',
                        border: OutlineInputBorder(),
                      ),
                      items: _units.map((unit) {
                        return DropdownMenuItem<String>(
                          value: unit['name'],
                          child: Text(unit['name']),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedUnit = value);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _priceController,
                      decoration: const InputDecoration(
                        labelText: 'Price per Unit *',
                        border: OutlineInputBorder(),
                        prefixText: '\$',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a price';
                        }
                        final price = double.tryParse(value);
                        if (price == null || price <= 0) {
                          return 'Please enter a valid price';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    DropdownButtonFormField<String>(
                      value: _selectedDepartment,
                      decoration: const InputDecoration(
                        labelText: 'Department *',
                        border: OutlineInputBorder(),
                      ),
                      items: _departments.map((dept) {
                        return DropdownMenuItem<String>(
                          value: dept['name'],
                          child: Text(dept['name']),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedDepartment = value);
                        }
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
        ElevatedButton(
          onPressed: _isLoadingData || _selectedUnit == null || _selectedDepartment == null ? null : () {
            if (_formKey.currentState!.validate()) {
              // Find the selected department ID
              final selectedDept = _departments.firstWhere(
                (d) => d['name'] == _selectedDepartment,
                orElse: () => _departments.first,
              );
              
              Navigator.of(context).pop({
                'name': _nameController.text.trim(),
                'unit': _selectedUnit!,
                'price': double.parse(_priceController.text),
                'department': _selectedDepartment!,
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

// Stock Take Confirmation Dialog with Mode Selection
class _StockTakeConfirmationDialog extends StatefulWidget {
  final int entryCount;
  final int wastageCount;

  const _StockTakeConfirmationDialog({
    required this.entryCount,
    required this.wastageCount,
  });

  @override
  State<_StockTakeConfirmationDialog> createState() => _StockTakeConfirmationDialogState();
}

class _StockTakeConfirmationDialogState extends State<_StockTakeConfirmationDialog> {
  String _selectedMode = 'set'; // Default to "set" mode

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Complete Stock?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('You are about to complete stock with:'),
            const SizedBox(height: 12),
            Text('• ${widget.entryCount} products', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('• ${widget.wastageCount} with wastage', style: const TextStyle(fontWeight: FontWeight.bold)),
            
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),
            
            // Stock Adjustment Mode Selection
            const Text(
              'Stock Adjustment Mode:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 12),
            
            // Set Stock (Replace) - DEFAULT
            RadioListTile<String>(
              title: const Text(
                'Set Stock (Replace)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text(
                'Replace current stock with counted values\n✓ Recommended for most stock',
                style: TextStyle(fontSize: 12),
              ),
              value: 'set',
              groupValue: _selectedMode,
              onChanged: (value) {
                setState(() {
                  _selectedMode = value!;
                });
              },
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
            
            // Add to Stock
            RadioListTile<String>(
              title: const Text('Add to Stock'),
              subtitle: const Text(
                'Add counted values to current stock\n⚠️ Use only for receiving new stock',
                style: TextStyle(fontSize: 12),
              ),
              value: 'add',
              groupValue: _selectedMode,
              onChanged: (value) {
                setState(() {
                  _selectedMode = value!;
                });
              },
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
            
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            
            const Text('This will:'),
            const Text('✓ Update stock levels'),
            const Text('✓ Generate PDF & Excel reports'),
            const Text('✓ Auto-share the reports'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, {'confirmed': false}),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context, {
              'confirmed': true,
              'mode': _selectedMode,
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
          child: Text(_selectedMode == 'set' ? 'Set Stock' : 'Add to Stock'),
        ),
      ],
    );
  }
}

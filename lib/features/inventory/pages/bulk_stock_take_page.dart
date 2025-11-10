import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../../models/product.dart';
import '../../../providers/inventory_provider.dart';
import '../../../providers/products_provider.dart';
import '../../../services/api_service.dart';
import '../utils/bulk_stock_take_logic.dart';
import '../utils/bulk_stock_take_pdf_generator.dart';
import '../utils/bulk_stock_take_persistence.dart';

class BulkStockTakePage extends ConsumerStatefulWidget {
  final List<Product> products;

  const BulkStockTakePage({
    super.key,
    required this.products,
  });

  @override
  ConsumerState<BulkStockTakePage> createState() => _BulkStockTakePageState();
}

class _BulkStockTakePageState extends ConsumerState<BulkStockTakePage> {
  final Map<int, TextEditingController> _controllers = {};
  final Map<int, TextEditingController> _commentControllers = {};
  final Map<int, TextEditingController> _wastageControllers = {};
  final Map<int, TextEditingController> _wastageReasonControllers = {};
  final Map<int, double> _originalStock = {};
  final Map<int, DateTime> _addedTimestamps = {}; // Track when products were added
  final TextEditingController _searchController = TextEditingController();
  
  // Dynamic list of products in stock take (can be added/removed)
  List<Product> _stockTakeProducts = [];
  // All products for searching (loaded from inventory provider)
  List<Product> _allProducts = [];
  bool _isLoading = false;
  bool _isLoadingProducts = true;
  String _searchQuery = '';
  List<Map<String, dynamic>> _stockHistory = [];
  bool _showHistory = false;
  
  // Auto-save functionality
  Timer? _autoSaveTimer;
  
  // Search debouncing
  Timer? _searchDebounceTimer;
  
  // Scroll controller for the stock items list
  final ScrollController _scrollController = ScrollController();

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
    
    for (final product in _stockTakeProducts) {
      _controllers[product.id] = TextEditingController();
      _commentControllers[product.id] = TextEditingController();
      _wastageControllers[product.id] = TextEditingController();
      _wastageReasonControllers[product.id] = TextEditingController();
      _originalStock[product.id] = product.stockLevel;
      // Initial products get older timestamps (so new ones appear on top)
      _addedTimestamps[product.id] = DateTime.now().subtract(Duration(hours: 1));
      _controllers[product.id]!.text = product.stockLevel % 1 == 0
          ? product.stockLevel.toInt().toString()
          : product.stockLevel.toStringAsFixed(2);
    }
    
    
    // Load saved progress and stock history
    _loadSavedProgress(autoLoad: true);
    _loadStockHistory();
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _searchDebounceTimer?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    for (final controller in _commentControllers.values) {
      controller.dispose();
    }
    for (final controller in _wastageControllers.values) {
      controller.dispose();
    }
    for (final controller in _wastageReasonControllers.values) {
      controller.dispose();
    }
    _addedTimestamps.clear(); // Clean up timestamps
    super.dispose();
  }


  // Save progress using utility
  Future<void> _saveProgress({bool showSnackbar = false}) async {
    await BulkStockTakePersistence.saveProgress(
      stockTakeProducts: _stockTakeProducts,
      controllers: _controllers,
      commentControllers: _commentControllers,
      wastageControllers: _wastageControllers,
      wastageReasonControllers: _wastageReasonControllers,
      addedTimestamps: _addedTimestamps,
      showSnackbar: showSnackbar,
      context: mounted ? context : null,
    );
  }
  
  // Load saved progress using utility
  Future<void> _loadSavedProgress({bool autoLoad = false}) async {
    final progressData = await BulkStockTakePersistence.loadSavedProgress();
    
    if (progressData == null) {
      if (!autoLoad && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ No saved progress found'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }
    
    final savedProducts = progressData['products'] as List<dynamic>;
    
    // Auto-load on init, or ask when manually triggered
    if (autoLoad) {
      _restoreProgressFromData(progressData);
    } else {
      _showRestoreDialog(progressData, savedProducts);
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
      _restoreProgressFromData(progressData);
    }
  }
  
  // Restore progress from saved data using utility
  void _restoreProgressFromData(Map<String, dynamic> progressData) {
    final result = BulkStockTakePersistence.restoreProgress(progressData);
    
    if (!result.success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Error restoring progress'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }
    
    _searchController.clear();
    
    setState(() {
      _searchQuery = '';
      _stockTakeProducts.clear();
      _controllers.clear();
      _commentControllers.clear();
      _wastageControllers.clear();
      _wastageReasonControllers.clear();
      _addedTimestamps.clear();
      
      for (final product in result.products) {
        _stockTakeProducts.add(product);
        
        final entryData = result.entries[product.id]!;
        _controllers[product.id] = TextEditingController(text: entryData['enteredValue']);
        _commentControllers[product.id] = TextEditingController(text: entryData['comment']);
        _wastageControllers[product.id] = TextEditingController(text: entryData['wastageValue']);
        _wastageReasonControllers[product.id] = TextEditingController(text: entryData['wastageReason']);
        _originalStock[product.id] = product.stockLevel;
        
        // Restore timestamp if available
        final timestampStr = entryData['addedTimestamp'];
        if (timestampStr != null && timestampStr.isNotEmpty) {
          _addedTimestamps[product.id] = DateTime.fromMillisecondsSinceEpoch(int.parse(timestampStr));
        } else {
          _addedTimestamps[product.id] = DateTime.now().subtract(const Duration(hours: 2));
        }
      }
    });
    
    print('[BULK_STOCK_TAKE] Restored ${result.products.length} products from saved progress');
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Restored ${result.products.length} products from saved progress'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _refreshProductsList() async {
    try {
      print('[BULK_STOCK_TAKE] Checking if products need refresh...');
      
      final productsState = ref.read(productsProvider);
      
      if (productsState.products.isNotEmpty && !productsState.isLoading) {
        setState(() {
          _allProducts = productsState.products;
          _isLoadingProducts = false;
        });
        print('[BULK_STOCK_TAKE] Using cached products: ${_allProducts.length}');
        return;
      }
      
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
      print('Failed to load stock history: $e');
    }
  }

  void _addProductToStockTake(Product product) {
    if (_stockTakeProducts.any((p) => p.id == product.id)) return;
    
    setState(() {
      _stockTakeProducts.add(product);
      _controllers[product.id] = TextEditingController();
      _commentControllers[product.id] = TextEditingController();
      _wastageControllers[product.id] = TextEditingController();
      _wastageReasonControllers[product.id] = TextEditingController();
      _originalStock[product.id] = product.stockLevel;
      _addedTimestamps[product.id] = DateTime.now(); // Record when added
      _controllers[product.id]!.text = product.stockLevel % 1 == 0
          ? product.stockLevel.toInt().toString()
          : product.stockLevel.toStringAsFixed(2);
      
      // Clear search after adding product
      _searchController.clear();
      _searchQuery = '';
    });
    
    // Hide keyboard and focus
    FocusScope.of(context).unfocus();
    
    _scheduleAutoSave();
    
    print('[BULK_STOCK_TAKE] Added ${product.name} at ${_addedTimestamps[product.id]} - will appear at top');
  }

  void _removeProductFromStockTake(int productId) {
    setState(() {
      _stockTakeProducts.removeWhere((p) => p.id == productId);
      _controllers[productId]?.dispose();
      _controllers.remove(productId);
      _commentControllers[productId]?.dispose();
      _commentControllers.remove(productId);
      _wastageControllers[productId]?.dispose();
      _wastageControllers.remove(productId);
      _wastageReasonControllers[productId]?.dispose();
      _wastageReasonControllers.remove(productId);
      _originalStock.remove(productId);
      _addedTimestamps.remove(productId); // Remove timestamp
    });
    
    _scheduleAutoSave();
  }

  void _scheduleAutoSave() {
    _autoSaveTimer?.cancel();
    
    _autoSaveTimer = Timer(const Duration(seconds: 5), () {
      _saveProgress();
    });
  }

  // Get products currently in the stock take list (using logic utility)
  List<Product> get _filteredStockTakeProducts {
    final filtered = BulkStockTakeLogic.filterProducts(_stockTakeProducts, _searchQuery);
    return BulkStockTakeLogic.sortProducts(filtered, _addedTimestamps);
  }
  
  // Get products from all products that match search but aren't in stock take list
  List<Product> get _searchResultsNotInList {
    return BulkStockTakeLogic.getSearchResultsNotInList(
      searchQuery: _searchQuery,
      allProducts: _allProducts,
      stockTakeProducts: _stockTakeProducts,
    );
  }

  // Check if search query has no results
  bool get _shouldShowAddProductButton {
    return BulkStockTakeLogic.shouldShowAddProductButton(
      searchQuery: _searchQuery,
      isLoadingProducts: _isLoadingProducts,
      searchResultsNotInList: _searchResultsNotInList,
    );
  }

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
      
      final newProduct = await apiService.createProduct({
        'name': result['name'],
        'unit': result['unit'],
        'price': result['price'],
        'department': result['department_id'],
        'is_active': true,
        'minimum_stock': 5.0,
      });
      
      await _refreshProductsList();
      _addProductToStockTake(newProduct);
      
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

  // Preview Excel - View/share report WITHOUT submitting to backend
  Future<void> _previewStockTakePdf() async {
    setState(() => _isLoading = true);
    
    try {
      // Build entries using shared logic utility
      final entries = BulkStockTakeLogic.buildStockTakeEntries(
        stockTakeProducts: _stockTakeProducts,
        controllers: _controllers,
        commentControllers: _commentControllers,
        wastageControllers: _wastageControllers,
        wastageReasonControllers: _wastageReasonControllers,
        originalStock: _originalStock,
      );

      if (entries.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter stock counts, wastage, or comments for at least one product to preview'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Generate preview Excel using utility (without submitting to backend)
      print('[PREVIEW] Generating preview Excel with ${entries.length} entries');
      final excelPath = await BulkStockTakePdfGenerator.generateStockTakeExcel(
        entries: entries,
        stockTakeProducts: _stockTakeProducts,
      );
      
      if (mounted) {
        if (excelPath != null) {
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('📊 Preview generated! Stock NOT submitted yet.'),
              backgroundColor: Colors.blue,
              duration: Duration(seconds: 2),
            ),
          );
          
          // Show Excel and allow sharing
          await Share.shareXFiles(
            [XFile(excelPath)],
            text: 'Stock Take Preview (NOT submitted) - ${DateTime.now().toString().split(' ')[0]}',
            subject: 'Stock Take Preview',
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Failed to generate preview Excel'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('[PREVIEW] Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error generating preview: $e'),
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

  // Show confirmation dialog before completing stock take
  Future<void> _confirmAndSubmit() async {
    final entries = BulkStockTakeLogic.buildStockTakeEntries(
      stockTakeProducts: _stockTakeProducts,
      controllers: _controllers,
      commentControllers: _commentControllers,
      wastageControllers: _wastageControllers,
      wastageReasonControllers: _wastageReasonControllers,
      originalStock: _originalStock,
    );

    if (entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter stock counts, wastage, or comments for at least one product'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete Stock Take?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('You are about to complete the stock take with:'),
            const SizedBox(height: 12),
            Text('• ${entries.length} products', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('• ${entries.where((e) => (e['wastage_quantity'] as double? ?? 0.0) > 0).length} with wastage', 
              style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text('This will:'),
            const Text('✓ Update stock levels'),
            const Text('✓ Generate PDF & Excel reports'),
            const Text('✓ Auto-share the reports'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Complete Stock Take'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _submitBulkStockTake();
    }
  }

  Future<void> _submitBulkStockTake() async {
    _autoSaveTimer?.cancel();

    try {
      // Build entries using shared logic utility
      final entries = BulkStockTakeLogic.buildStockTakeEntries(
        stockTakeProducts: _stockTakeProducts,
        controllers: _controllers,
        commentControllers: _commentControllers,
        wastageControllers: _wastageControllers,
        wastageReasonControllers: _wastageReasonControllers,
        originalStock: _originalStock,
      );

      if (entries.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter stock counts, wastage, or comments for at least one product'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      setState(() => _isLoading = true);
      
      print('[BULK_STOCK_TAKE] Submitting ${entries.length} entries');
      
      // Submit to inventory provider
      await ref.read(inventoryProvider.notifier).bulkStockTake(entries);
      
      // Generate PDF and Excel reports using utility
      final pdfPath = await BulkStockTakePdfGenerator.generateStockTakePdf(
        entries: entries,
        stockTakeProducts: _stockTakeProducts,
      );
      final excelPath = await BulkStockTakePdfGenerator.generateStockTakeExcel(
        entries: entries,
        stockTakeProducts: _stockTakeProducts,
      );
      
      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('✅ Stock Take Complete! ${entries.length} entries processed.'),
                if (pdfPath != null) const Text('📄 PDF generated'),
                if (excelPath != null) const Text('📊 Excel generated'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        
        // Auto-share files if generated successfully
        if (pdfPath != null || excelPath != null) {
          await _shareFiles(pdfPath: pdfPath, excelPath: excelPath);
        }
        
        Navigator.pop(context, true);
      }
      
    } catch (e) {
      print('[BULK_STOCK_TAKE] Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to complete stock take: $e'),
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


  Future<void> _clearProgress() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Progress'),
        content: const Text('Are you sure you want to clear all entered data?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
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
      _addedTimestamps.clear(); // Clear timestamps too
      setState(() {});
    }
  }

  // Share files via WhatsApp or other apps
  Future<void> _shareFiles({String? pdfPath, String? excelPath}) async {
    try {
      final List<XFile> files = [];
      
      if (pdfPath != null && await File(pdfPath).exists()) {
        files.add(XFile(pdfPath));
      }
      
      if (excelPath != null && await File(excelPath).exists()) {
        files.add(XFile(excelPath));
      }
      
      if (files.isNotEmpty) {
        await Share.shareXFiles(
          files,
          text: 'Stock Take Report - ${DateTime.now().toString().split(' ')[0]}',
          subject: 'Bulk Stock Take Results',
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ No files available to share'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      print('[BULK_STOCK_TAKE] Error sharing files: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error sharing files: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Share progress file
  Future<void> _shareProgress() async {
    try {
      final directory = await BulkStockTakePersistence.getStorageDirectory();
      final file = File('${directory.path}/bulk_stock_take_progress.json');
      
      if (await file.exists()) {
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Stock Take Progress - ${DateTime.now().toString().split(' ')[0]}',
          subject: 'Bulk Stock Take Progress',
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ No saved progress to share'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      print('[BULK_STOCK_TAKE] Error sharing progress: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error sharing progress: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
    
    return Scaffold(
      resizeToAvoidBottomInset: true, // Important for keyboard handling
      appBar: AppBar(
        title: const Text('Bulk Stock Take'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _refreshProductsList,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh products list',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'save':
                  _saveProgress(showSnackbar: true);
                  break;
                case 'load':
                  _loadSavedProgress();
                  break;
                case 'share_progress':
                  _shareProgress();
                  break;
                case 'clear':
                  _clearProgress();
                  break;
                case 'history':
                  setState(() {
                    _showHistory = !_showHistory;
                  });
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'save',
                child: Row(
                  children: [
                    Icon(Icons.save, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Save Progress'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'load',
                child: Row(
                  children: [
                    Icon(Icons.restore, color: Colors.green),
                    SizedBox(width: 8),
                    Text('Load Progress'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'share_progress',
                child: Row(
                  children: [
                    Icon(Icons.share, color: Colors.purple),
                    SizedBox(width: 8),
                    Text('Share Progress'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'history',
                child: Row(
                  children: [
                    Icon(_showHistory ? Icons.history_toggle_off : Icons.history),
                    const SizedBox(width: 8),
                    Text(_showHistory ? 'Hide History' : 'Show History'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.clear_all, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('Clear Progress', style: TextStyle(color: Colors.orange)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
          // WhatsApp Stock History (if shown)
          if (_showHistory) ...[
            Container(
              height: 200,
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.history, color: Colors.blue[700]),
                        const SizedBox(width: 8),
                        Text(
                          'WhatsApp Stock History',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
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
                              'No stock history available',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _stockHistory.length,
                            itemBuilder: (context, index) {
                              final item = _stockHistory[index];
                              return ListTile(
                                dense: true,
                                leading: CircleAvatar(
                                  radius: 16,
                                  backgroundColor: Colors.blue[100],
                                  child: Icon(
                                    Icons.inventory,
                                    size: 16,
                                    color: Colors.blue[700],
                                  ),
                                ),
                                title: Text(
                                  item['product_name'] ?? 'Unknown Product',
                                  style: const TextStyle(fontSize: 14),
                                ),
                                subtitle: Text(
                                  '${item['action']} - ${item['timestamp']}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                trailing: Text(
                                  '${item['quantity']}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue[700],
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

          // Search and Add Section
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Search Bar - Double Height for Mobile
                Container(
                  height: 64,
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(fontSize: 18),
                    textInputAction: TextInputAction.search,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      hintText: 'Search products to add...',
                      hintStyle: TextStyle(fontSize: 16, color: Colors.grey[500]),
                      prefixIcon: const Icon(Icons.search, size: 28),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(width: 2),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 28),
                              onPressed: () {
                                _searchController.clear();
                                _searchDebounceTimer?.cancel(); // Cancel any pending search
                                setState(() => _searchQuery = '');
                                FocusScope.of(context).unfocus(); // Hide keyboard
                              },
                              tooltip: 'Clear search',
                            )
                          : null,
                    ),
                    onChanged: (value) {
                      // Debounce search to avoid frequent rebuilds
                      _searchDebounceTimer?.cancel();
                      _searchDebounceTimer = Timer(const Duration(milliseconds: 300), () {
                        if (mounted) {
                          setState(() => _searchQuery = value);
                        }
                      });
                    },
                    onSubmitted: (value) {
                      // Hide keyboard when search submitted
                      FocusScope.of(context).unfocus();
                    },
                  ),
                ),

                const SizedBox(height: 16),

                // Add Product Button (when no products match search)
                if (_shouldShowAddProductButton) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      border: Border.all(color: Colors.orange[200]!),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.add_circle_outline, color: Colors.orange[700]),
                            const SizedBox(width: 8),
                            Text(
                              'Product not found: "$_searchQuery"',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Colors.orange[800],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _createAndAddProduct,
                            icon: const Icon(Icons.add),
                            label: const Text('Create and Add to Stock Take'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange[600],
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Search Results (products not in stock take list) - IMPROVED DESCRIPTIONS
                if (_searchQuery.isNotEmpty && _searchResultsNotInList.isNotEmpty) ...[
                  Container(
                    height: 250, // Much bigger search results box for mobile
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.green[300]!),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(12),
                              topRight: Radius.circular(12),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.search, color: Colors.green[700], size: 16),
                              const SizedBox(width: 8),
                              Text(
                                'Add from search (${_searchResultsNotInList.length})',
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
                            itemCount: _searchResultsNotInList.length,
                            itemBuilder: (context, index) {
                              final product = _searchResultsNotInList[index];
                              return ListTile(
                                dense: false,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // More padding
                                title: Text(
                                  product.name, 
                                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600), // Slightly bigger
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'SKU: ${product.sku ?? 'No SKU'} • Unit: ${product.unit}',
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                    Text(
                                      'Stock: ${product.stockLevel} ${product.unit} • Department: ${product.department}',
                                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                    ),
                                    Text(
                                      'Price: R${product.price.toStringAsFixed(2)} per ${product.unit}',
                                      style: TextStyle(fontSize: 12, color: Colors.green[700], fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                                trailing: IconButton(
                                  icon: Icon(Icons.add_circle, color: Colors.green[600], size: 32), // Bigger add button
                                  onPressed: () => _addProductToStockTake(product),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Products List
          Expanded(
            child: _filteredStockTakeProducts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _searchQuery.isEmpty
                              ? Icons.inventory_2_outlined
                              : Icons.search_off,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty
                              ? 'No products added to stock take yet.\nUse the search above to add products.'
                              : 'No products found matching "$_searchQuery"',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual, // Prevent keyboard from closing on scroll
                    physics: const ClampingScrollPhysics(), // Prevent bounce that causes rebuilds
                    itemCount: _filteredStockTakeProducts.length + 1, // +1 for Complete Stock Take button
                    itemBuilder: (context, index) {
                      // If this is the last item, show the action buttons
                      if (index == _filteredStockTakeProducts.length) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
                          child: Row(
                            children: [
                              // Preview Button
                              Expanded(
                                child: SizedBox(
                                  height: 56,
                                  child: ElevatedButton.icon(
                                    onPressed: _isLoading ? null : _previewStockTakePdf,
                                    icon: const Icon(Icons.preview, size: 20),
                                    label: const Text(
                                      'Preview',
                                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                    ),
                                  ),
                                ),
                              ),
                              
                              const SizedBox(width: 12),
                              
                              // Complete Stock Take Button
                              Expanded(
                                child: SizedBox(
                                  height: 56,
                                  child: ElevatedButton.icon(
                                    onPressed: _isLoading ? null : _confirmAndSubmit,
                                    icon: _isLoading
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                            ),
                                          )
                                        : const Icon(Icons.check, size: 20),
                                    label: Text(
                                      _isLoading ? 'Submitting...' : 'Complete',
                                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      final product = _filteredStockTakeProducts[index];
                      final controller = _controllers[product.id]!;
                      final commentController = _commentControllers[product.id]!;
                      final wastageController = _wastageControllers[product.id]!;
                      final wastageReasonController = _wastageReasonControllers[product.id]!;
                      final originalStock = _originalStock[product.id] ?? 0.0;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Product Header
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          product.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${product.sku ?? 'No SKU'} • Current: $originalStock ${product.unit}',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () => _removeProductFromStockTake(product.id),
                                    icon: const Icon(Icons.close, color: Colors.red),
                                    tooltip: 'Remove from stock take',
                                  ),
                                ],
                              ),

                              const SizedBox(height: 16),

                              // Input Row
                              Row(
                                children: [
                                  // Stock Count Input
                                  Expanded(
                                    flex: 2,
                                    child: TextField(
                                      controller: controller,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      textInputAction: TextInputAction.next, // Better keyboard navigation
                                      enableInteractiveSelection: true, // Keep keyboard active
                                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                                      decoration: InputDecoration(
                                        labelText: 'Count (${product.unit})',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 16, // More padding for easier touch
                                        ),
                                      ),
                                      onChanged: (value) {
                                        _scheduleAutoSave();
                                      },
                                      onTap: () {
                                        // Ensure keyboard stays open
                                      },
                                    ),
                                  ),

                                  const SizedBox(width: 12),

                                  // Wastage Input
                                  Expanded(
                                    flex: 2,
                                    child: TextField(
                                      controller: wastageController,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      textInputAction: TextInputAction.next,
                                      enableInteractiveSelection: true, // Keep keyboard active
                                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                                      decoration: InputDecoration(
                                        labelText: 'Wastage (${product.unit})',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 16, // More padding for easier touch
                                        ),
                                      ),
                                      onChanged: (value) {
                                        _scheduleAutoSave();
                                      },
                                      onTap: () {
                                        // Ensure keyboard stays open
                                      },
                                    ),
                                  ),

                                  const SizedBox(width: 8),

                                  // Difference Indicator
                                  SizedBox(
                                    width: 40,
                                    child: Builder(
                                      builder: (context) {
                                        final countedText = controller.text;
                                        if (countedText.isEmpty) return const SizedBox();
                                        
                                        final counted = double.tryParse(countedText) ?? 0.0;
                                        final difference = counted - originalStock;
                                        
                                        if (difference.abs() < 0.001) {
                                          return const Icon(Icons.check, color: Colors.green, size: 20);
                                        }
                                        
                                        return Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: difference > 0 ? Colors.green[100] : Colors.red[100],
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            difference > 0 ? '+${difference.toStringAsFixed(1)}' : difference.toStringAsFixed(1),
                                            style: TextStyle(
                                              color: difference > 0 ? Colors.green[700] : Colors.red[700],
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 16),

                              // Wastage Reason Section with Enhanced UI
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: wastageReasonController.text.isNotEmpty 
                                    ? Colors.orange[50] 
                                    : Colors.grey[50],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: wastageReasonController.text.isNotEmpty 
                                      ? Colors.orange[300]! 
                                      : Colors.grey[300]!,
                                    width: wastageReasonController.text.isNotEmpty ? 2 : 1,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.delete_outline,
                                          size: 20,
                                          color: wastageReasonController.text.isNotEmpty 
                                            ? Colors.orange[700] 
                                            : Colors.grey[600],
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Wastage Reason',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: wastageReasonController.text.isNotEmpty 
                                              ? Colors.orange[900] 
                                              : Colors.grey[700],
                                          ),
                                        ),
                                        if (wastageReasonController.text.isNotEmpty)
                                          Container(
                                            margin: const EdgeInsets.only(left: 8),
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.orange[700],
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: const Text(
                                              'SAVED',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: wastageReasonController,
                                      textInputAction: TextInputAction.next,
                                      textCapitalization: TextCapitalization.words,
                                      enableInteractiveSelection: true,
                                      style: const TextStyle(fontSize: 16, color: Colors.black),
                                      decoration: InputDecoration(
                                        hintText: 'e.g., Spoilage, Damaged, Expired',
                                        hintStyle: TextStyle(color: Colors.grey[400]),
                                        filled: true,
                                        fillColor: Colors.white,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide.none,
                                        ),
                                        contentPadding: const EdgeInsets.all(14),
                                      ),
                                      onChanged: (value) {
                                        setState(() {}); // Update UI when text changes
                                        _scheduleAutoSave();
                                      },
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 16),

                              // Comments Section with Enhanced UI
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: commentController.text.isNotEmpty 
                                    ? Colors.blue[50] 
                                    : Colors.grey[50],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: commentController.text.isNotEmpty 
                                      ? Colors.blue[300]! 
                                      : Colors.grey[300]!,
                                    width: commentController.text.isNotEmpty ? 2 : 1,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.comment_outlined,
                                          size: 20,
                                          color: commentController.text.isNotEmpty 
                                            ? Colors.blue[700] 
                                            : Colors.grey[600],
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Additional Comments',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: commentController.text.isNotEmpty 
                                              ? Colors.blue[900] 
                                              : Colors.grey[700],
                                          ),
                                        ),
                                        if (commentController.text.isNotEmpty)
                                          Container(
                                            margin: const EdgeInsets.only(left: 8),
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.blue[700],
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: const Text(
                                              'SAVED',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: commentController,
                                      maxLines: 3,
                                      minLines: 1,
                                      textInputAction: TextInputAction.newline,
                                      textCapitalization: TextCapitalization.sentences,
                                      enableInteractiveSelection: true,
                                      style: const TextStyle(fontSize: 16, color: Colors.black),
                                      decoration: InputDecoration(
                                        hintText: 'Tap to add notes about this product...',
                                        hintStyle: TextStyle(color: Colors.grey[400]),
                                        filled: true,
                                        fillColor: Colors.white,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide.none,
                                        ),
                                        contentPadding: const EdgeInsets.all(14),
                                      ),
                                      onChanged: (value) {
                                        setState(() {}); // Update UI when text changes
                                        _scheduleAutoSave();
                                      },
                                      onTap: () {
                                        commentController.selection = TextSelection.fromPosition(
                                          TextPosition(offset: commentController.text.length),
                                        );
                                      },
                                    ),
                                  ],
                                ),
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
  );
}
}

// Add Product Dialog for creating new products
class _AddProductDialog extends ConsumerStatefulWidget {
  final String productName;

  const _AddProductDialog({required this.productName});

  @override
  ConsumerState<_AddProductDialog> createState() => _AddProductDialogState();
}

class _AddProductDialogState extends ConsumerState<_AddProductDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  String? _selectedUnit;
  int? _selectedDepartmentId;
  String? _selectedDepartmentName;
  
  List<Map<String, dynamic>> _units = [];
  List<Map<String, dynamic>> _departments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.productName);
    _priceController = TextEditingController(text: '0.00');
    _loadData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final apiService = ref.read(apiServiceProvider);
      
      final unitsResult = await apiService.getUnitsOfMeasure();
      final departmentsResult = await apiService.getDepartments();
      
      setState(() {
        _units = unitsResult;
        _departments = departmentsResult;
        _isLoading = false;
      });
      
      print('[ADD_PRODUCT] Loaded ${_units.length} units and ${_departments.length} departments');
    } catch (e) {
      print('[ADD_PRODUCT] Error loading data: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        Navigator.pop(context); // Close dialog on error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to load units and departments: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const AlertDialog(
        content: SizedBox(
          height: 100,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return AlertDialog(
      title: const Text('Create New Product'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Product Name *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value?.trim().isEmpty == true ? 'Name is required' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedUnit,
                decoration: const InputDecoration(
                  labelText: 'Unit of Measure *',
                  border: OutlineInputBorder(),
                ),
                items: _units.where((unit) => unit['name'] != null).map<DropdownMenuItem<String>>((unit) {
                  return DropdownMenuItem<String>(
                    value: unit['name'],
                    child: Text(unit['name']),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _selectedUnit = value),
                validator: (value) => value == null ? 'Unit is required' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: _selectedDepartmentId,
                decoration: const InputDecoration(
                  labelText: 'Department *',
                  border: OutlineInputBorder(),
                ),
                items: _departments.map<DropdownMenuItem<int>>((dept) {
                  return DropdownMenuItem<int>(
                    value: dept['id'],
                    child: Text(dept['name'] ?? 'Unknown'),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedDepartmentId = value;
                    _selectedDepartmentName = _departments.firstWhere((d) => d['id'] == value)['name'];
                  });
                },
                validator: (value) => value == null ? 'Department is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: 'Price (R)',
                  border: OutlineInputBorder(),
                  prefixText: 'R ',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  final price = double.tryParse(value ?? '');
                  return price == null || price < 0 ? 'Valid price required' : null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState?.validate() == true) {
              Navigator.pop(context, {
                'name': _nameController.text.trim(),
                'unit': _selectedUnit!,
                'price': double.parse(_priceController.text),
                'department_id': _selectedDepartmentId!,
                'department_name': _selectedDepartmentName!,
              });
            }
          },
          child: const Text('Create Product'),
        ),
      ],
    );
  }
}

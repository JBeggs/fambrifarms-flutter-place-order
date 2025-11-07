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
  final Map<int, String> _wastageReasons = {};
  final Map<int, double> _originalStock = {};
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
      _commentControllers[product.id] = TextEditingController();
      _wastageControllers[product.id] = TextEditingController();
      _wastageReasons[product.id] = 'Spoilage'; // Default wastage reason
      _originalStock[product.id] = product.stockLevel;
    }
    
    // Load saved progress
    _loadProgress();
    
    // Load stock history
    _loadStockHistory();
  }

  @override
  void dispose() {
    // Cancel auto-save timer
    _autoSaveTimer?.cancel();
    
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
    
    return results;
  }

  // Check if search query doesn't match any existing products
  bool get _shouldShowAddProductButton {
    if (_searchQuery.trim().isEmpty) return false;
    if (_isLoadingProducts) return false;
    
    final query = _searchQuery.toLowerCase().trim();
    
    // Check if any product name exactly matches or starts with the search query
    final hasMatchingProduct = _allProducts.any((product) {
      final name = product.name.toLowerCase();
      final sku = product.sku?.toLowerCase() ?? '';
      return name == query || name.startsWith(query) || 
             sku == query || sku.startsWith(query);
    });
    
    return !hasMatchingProduct;
  }

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

  Future<void> _loadProgress() async {
    // Implementation for loading saved progress
    // (keeping existing logic from dialog)
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
      _wastageReasons[product.id] = 'Spoilage';
      _originalStock[product.id] = product.stockLevel;
    });
    
    _scheduleAutoSave();
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
      _wastageReasons.remove(productId);
      _originalStock.remove(productId);
    });
    
    _scheduleAutoSave();
  }

  void _scheduleAutoSave() {
    _autoSaveTimer?.cancel();
    _hasUnsavedChanges = true;
    
    _autoSaveTimer = Timer(const Duration(seconds: 2), () {
      _saveProgress();
      _hasUnsavedChanges = false;
    });
  }

  Future<void> _saveProgress() async {
    // Implementation for saving progress
    // (keeping existing logic from dialog)
  }

  Future<void> _submitBulkStockTake() async {
    // Cancel auto-save timer
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
        final wastageQuantity = double.tryParse(wastageText) ?? 0.0;
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
      
      // Show success message and navigate back
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Stock take completed successfully with ${entries.length} entries'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Navigate back to previous screen
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
      body: Column(
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
                // Search Bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search products...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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
                    setState(() => _searchQuery = value);
                  },
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

                // Search Results (products not in stock take list)
                if (_searchQuery.isNotEmpty && _searchResultsNotInList.isNotEmpty) ...[
                  Container(
                    height: 120,
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
                                dense: true,
                                title: Text(product.name, style: const TextStyle(fontSize: 14)),
                                subtitle: Text(
                                  '${product.sku ?? 'No SKU'} • Stock: ${product.stockLevel}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                trailing: IconButton(
                                  icon: Icon(Icons.add_circle, color: Colors.green[600]),
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
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filteredStockTakeProducts.length,
                    itemBuilder: (context, index) {
                      final product = _filteredStockTakeProducts[index];
                      final controller = _controllers[product.id]!;
                      final commentController = _commentControllers[product.id]!;
                      final wastageController = _wastageControllers[product.id]!;
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
                                          '${product.sku ?? 'No SKU'} • Current: $originalStock',
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
                                      decoration: InputDecoration(
                                        labelText: 'Count',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                      ),
                                      onChanged: (value) {
                                        _scheduleAutoSave();
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
                                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                                      decoration: InputDecoration(
                                        labelText: 'Wastage',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                      ),
                                      onChanged: (value) {
                                        _scheduleAutoSave();
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

                              const SizedBox(height: 12),

                              // Comment Input
                              TextField(
                                controller: commentController,
                                maxLines: 2,
                                decoration: InputDecoration(
                                  labelText: 'Comment (optional)',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  contentPadding: const EdgeInsets.all(12),
                                ),
                                onChanged: (value) {
                                  _scheduleAutoSave();
                                },
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
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.3),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Summary Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Column(
                    children: [
                      Text(
                        '${_stockTakeProducts.length}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      const Text('Products', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                  Column(
                    children: [
                      Text(
                        '${_controllers.values.where((c) => c.text.isNotEmpty).length}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      const Text('Counted', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                  Column(
                    children: [
                      Text(
                        '${_wastageControllers.values.where((c) => c.text.isNotEmpty).length}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                      const Text('Wastage', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _submitBulkStockTake,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.check_circle),
                  label: Text(
                    _isLoading ? 'Processing...' : 'Complete Stock Take',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createAndAddProduct() async {
    final productName = _searchQuery.trim();
    if (productName.isEmpty) return;

    // For now, show a simple input dialog for creating products
    // In the full implementation, you'd create a dedicated dialog like in the original
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Product'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              initialValue: productName,
              decoration: const InputDecoration(labelText: 'Product Name'),
              onChanged: (value) {
                // Store product name
              },
            ),
            const SizedBox(height: 16),
            const Text('This is a simplified version for demonstration.\nFull implementation would have unit selection, etc.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, {
              'name': productName,
              'unit': 'piece',
              'price': 0.0,
              'department_id': 1,
            }),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (result == null) return;

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
      setState(() => _searchQuery = '');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Product "${newProduct.name}" created and added'),
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
      setState(() {});
    }
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:state_notifier/state_notifier.dart';
import '../services/api_service.dart';
import '../models/product.dart';
import '../models/stock_alert.dart';

class InventoryState {
  final List<Product> products; // Use Product objects instead of Map
  final List<Product> lowStockProducts;
  final List<Product> outOfStockProducts;
  final List<StockAlert> stockAlerts;
  final List<Map<String, dynamic>> stockMovements;
  final bool isLoading;
  final String? error;
  final DateTime lastUpdated;

  InventoryState({
    this.products = const [],
    this.lowStockProducts = const [],
    this.outOfStockProducts = const [],
    this.stockAlerts = const [],
    this.stockMovements = const [],
    this.isLoading = false,
    this.error,
    DateTime? lastUpdated,
  }) : lastUpdated = lastUpdated ?? DateTime.now();

  InventoryState copyWith({
    List<Product>? products,
    List<Product>? lowStockProducts,
    List<Product>? outOfStockProducts,
    List<StockAlert>? stockAlerts,
    List<Map<String, dynamic>>? stockMovements,
    bool? isLoading,
    String? error,
    DateTime? lastUpdated,
  }) {
    return InventoryState(
      products: products ?? this.products,
      lowStockProducts: lowStockProducts ?? this.lowStockProducts,
      outOfStockProducts: outOfStockProducts ?? this.outOfStockProducts,
      stockAlerts: stockAlerts ?? this.stockAlerts,
      stockMovements: stockMovements ?? this.stockMovements,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      lastUpdated: lastUpdated ?? DateTime.now(),
    );
  }
}

class InventoryNotifier extends StateNotifier<InventoryState> {
  final ApiService _apiService;

  double _parseQuantity(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  // Debug method to check specific product stock
  void debugProductStock(int productId) {
    final product = state.products.firstWhere(
      (p) => p.id == productId, 
      orElse: () => const Product(
        id: -1, 
        name: 'Not found', 
        price: 0.0,
        unit: 'each',
        department: 'Unknown'
      )
    );
    print('[INVENTORY DEBUG] Product $productId: ${product.name} - Stock: ${product.stockLevel}');
  }

  InventoryNotifier(this._apiService) : super(InventoryState());

  Future<void> loadStockLevels() async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      print('[INVENTORY] Loading stock levels at $timestamp...');
      
      // Use only the stock levels API which contains complete product + inventory data
      final stockLevels = await _apiService.getStockLevels();
      
      print('[INVENTORY] Loaded ${stockLevels.length} products with stock data');
      
      // Convert stock level data to Product objects
      final products = stockLevels.map((stockData) {
        return Product(
          id: stockData['product_id'] as int,
          name: stockData['product_name'] as String,
          department: stockData['department'] as String,
          stockLevel: _parseQuantity(stockData['available_quantity']),
          minimumStock: _parseQuantity(stockData['minimum_level']),
          price: _parseQuantity(stockData['average_cost']),
          unit: stockData['unit'] as String? ?? 'each',
        );
      }).toList();
      
      print('[INVENTORY] Converted ${products.length} stock records to Product objects');
      
      // Categorize products by stock status
      final lowStockProducts = products.where((p) => 
        p.stockLevel > 0 && p.stockLevel <= p.minimumStock).toList();
      final outOfStockProducts = products.where((p) => 
        p.stockLevel <= 0).toList();
      
      print('[INVENTORY] Products: ${products.length}, Low stock: ${lowStockProducts.length}, Out of stock: ${outOfStockProducts.length}');
      
      // Create completely new state to force rebuild
      final newState = InventoryState(
        products: products,
        lowStockProducts: lowStockProducts,
        outOfStockProducts: outOfStockProducts,
        stockAlerts: state.stockAlerts,
        stockMovements: state.stockMovements,
        isLoading: false,
        error: null,
        lastUpdated: DateTime.now(),
      );
      
      state = newState;
      
      print('[INVENTORY] Stock levels loaded successfully - State updated with ${state.products.length} products');
    } catch (e) {
      print('[INVENTORY] Error loading stock levels: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load inventory from products: ${e.toString()}',
      );
    }
  }

  Future<void> loadStockAlerts() async {
    try {
      print('[INVENTORY] Loading stock alerts...');
      final alertsData = await _apiService.getStockAlerts();
      print('[INVENTORY] Received ${alertsData.length} alerts from API');
      final alerts = alertsData.map((data) => StockAlert.fromJson(data)).toList();
      print('[INVENTORY] Parsed ${alerts.length} StockAlert objects');
      state = state.copyWith(stockAlerts: alerts);
    } catch (e) {
      print('[INVENTORY] Error loading stock alerts: $e');
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> loadStockMovements({int? productId, int? limit}) async {
    try {
      final movements = await _apiService.getStockMovements(
        productId: productId,
        limit: limit,
      );
      state = state.copyWith(stockMovements: movements);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }


  Future<void> refreshAll() async {
    print('[INVENTORY] Starting refreshAll...');
    await Future.wait([
      loadStockLevels(),
      loadStockAlerts(),
      loadStockMovements(limit: 50),
    ]);
    print('[INVENTORY] refreshAll completed - Products: ${state.products.length}, Low: ${state.lowStockProducts.length}, Out: ${state.outOfStockProducts.length}');
  }

  // Force complete UI refresh
  void forceRefresh() {
    print('[INVENTORY] Forcing UI refresh with timestamp update');
    state = state.copyWith(lastUpdated: DateTime.now());
  }

  Future<void> adjustStock({
    required int productId,
    required String adjustment_type,
    required double quantity,
    required String reason,
    String? notes,
  }) async {
    try {
      print('[INVENTORY] Starting stock adjustment for product $productId: $adjustment_type $quantity');
      
      // Get current product state before adjustment
      final currentProduct = state.products.firstWhere((p) => p.id == productId);
      print('[INVENTORY] Current stock level before adjustment: ${currentProduct.stockLevel}');
      
      // Ensure notes is never empty
      final finalNotes = (notes == null || notes.trim().isEmpty) 
          ? 'Stock adjustment: $reason' 
          : notes.trim();
      
      await _apiService.adjustStock(productId, {
        'adjustment_type': adjustment_type,
        'quantity': quantity,
        'reason': reason,
        'notes': finalNotes,
      });

      print('[INVENTORY] Stock adjustment API call completed');

      // Refresh data after successful adjustment
      await refreshAll();
      
      // Force a small delay to ensure backend processing is complete
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Do another refresh to be absolutely sure
      await loadStockLevels();
      
      // Verify the update worked
      final updatedProduct = state.products.firstWhere((p) => p.id == productId);
      print('[INVENTORY] Stock level after refresh: ${updatedProduct.stockLevel}');
      
      // Debug: Check if the product was actually updated
      debugProductStock(productId);
      
    } catch (e) {
      print('[INVENTORY] Error in adjustStock: $e');
      throw Exception('Failed to adjust stock: $e');
    }
  }

  Future<void> bulkStockTake(List<Map<String, dynamic>> entries, {String adjustmentMode = 'set'}) async {
    print('[INVENTORY] Starting bulk stock take with ${entries.length} entries (mode: $adjustmentMode)');
    
    try {
      print('[INVENTORY] Starting complete stock take with ${entries.length} entries');
      
      // Step 1: Get all product IDs that were counted
      final countedProductIds = entries.map((entry) => entry['product_id'] as int).toSet();
      print('[INVENTORY] Products being counted: ${countedProductIds.length}');
      
      // Step 2: Reset ALL products to zero first (only for 'set' mode)
      final allProducts = state.products;
      int resetCount = 0;
      if (adjustmentMode == 'set') {
        print('[INVENTORY] Resetting all products to zero for complete stock take (SET mode)');
        
        // Process resets sequentially with better error handling
        for (final product in allProducts) {
          if (product.stockLevel > 0) {
            try {
              await _apiService.adjustStock(product.id, {
                'adjustment_type': 'finished_waste',
                'quantity': product.stockLevel,
                'reason': 'complete_stock_take_reset',
                'notes': 'Complete stock take: Reset to zero before setting counted quantities',
              });
              resetCount++;
            } catch (e) {
              print('[INVENTORY] ⚠️ Failed to reset product ${product.name} (ID: ${product.id}, stock: ${product.stockLevel}): $e');
              // Continue with other products even if one fails
            }
          }
        }
        print('[INVENTORY] Reset $resetCount products to zero');
      } else {
        print('[INVENTORY] Skipping reset (ADD mode - will add to existing stock)');
      }
      
      // Step 3: Process wastage and set counted quantities
      print('[INVENTORY] Processing wastage and setting counted quantities');
      
      // Generate reference_number in same format as management command: STOCK-TAKE-YYYYMMDD
      final now = DateTime.now();
      final referenceNumber = 'STOCK-TAKE-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      
      int adjustmentCount = 0;
      for (final entry in entries) {
        final productId = entry['product_id'] as int;
        final countedQuantity = (entry['counted_quantity'] as double);
        final wastageQuantity = (entry['wastage_quantity'] as double? ?? 0.0);
        final wastageReason = entry['wastage_reason'] as String? ?? '';
        final weight = entry['weight'] as double? ?? 0.0;
        final comment = entry['comment'] as String? ?? '';
        
        // Get product name from entry first (most reliable), then fallback to state lookup
        String productName = entry['product_name'] as String? ?? 'Unknown';
        if (productName == 'Unknown') {
          final product = allProducts.where((p) => p.id == productId).firstOrNull;
          if (product != null) {
            productName = product.name;
          } else {
            // Product not in current state, log the entry data for debugging
            print('[INVENTORY] ⚠️ Product ID $productId not found in state.products (${allProducts.length} products)');
            print('[INVENTORY] Entry data: counted=$countedQuantity, wastage=$wastageQuantity, current_stock=${entry['current_stock']}');
          }
        }
        
        // Record wastage if any - store just the reason value (no prefix)
        if (wastageQuantity > 0) {
          try {
            await _apiService.adjustStock(productId, {
              'adjustment_type': 'finished_waste',
              'quantity': wastageQuantity,
              'reason': 'stock_take_wastage',
              'notes': wastageReason, // Just the reason value, no prefix
              'reference_number': referenceNumber,
            });
            adjustmentCount++;
            print('[INVENTORY] ✓ Recorded wastage for $productName (ID: $productId): $wastageQuantity');
          } catch (e) {
            print('[INVENTORY] ⚠️ Failed wastage for $productName (ID: $productId, qty: $wastageQuantity): $e');
            // Continue with other products
          }
        }
        
        // Set or add counted quantities (only products with stock > 0)
        if (countedQuantity > 0) {
          final adjustmentType = adjustmentMode == 'set' ? 'finished_set' : 'finished_adjust';
          final actionText = adjustmentMode == 'set' ? 'Set' : 'Added';
          
          try {
            // Build notes with comment if provided (weight is now a separate field)
            String notes = 'Complete stock take: $actionText counted quantity to $countedQuantity';
            if (comment.isNotEmpty) {
              notes += '. $comment';
            }
            
            await _apiService.adjustStock(productId, {
              'adjustment_type': adjustmentType,
              'quantity': countedQuantity,
              'reason': adjustmentMode == 'set' ? 'complete_stock_take_set' : 'complete_stock_take_add',
              'notes': notes,
              'reference_number': referenceNumber,
              if (weight > 0) 'weight': weight,
            });
            adjustmentCount++;
            print('[INVENTORY] ✓ $actionText stock for $productName (ID: $productId): $countedQuantity');
          } catch (e) {
            print('[INVENTORY] ⚠️ Failed to $actionText stock for $productName (ID: $productId, qty: $countedQuantity): $e');
            // Continue with other products
          }
        }
      }
      
      print('[INVENTORY] Processed $adjustmentCount stock adjustments (wastage + counts)');

      // Force a complete refresh after all operations are done
      await Future.delayed(const Duration(milliseconds: 1000)); // Give backend time to process
      await loadStockLevels();
    } catch (e) {
      state = state.copyWith(error: 'Failed to complete bulk stock take: $e');
      throw Exception('Failed to complete bulk stock take: $e');
    }
  }

  // New method to update product stock level
  Future<void> updateProductStock(int productId, double newStockLevel, String reason) async {
    try {
      // Update product stock level in database
      await _apiService.updateProduct(productId, {'stock_level': newStockLevel});
      
      // Log the stock adjustment (if API exists)
      try {
        await _apiService.logStockAdjustment(productId, newStockLevel, reason);
      } catch (e) {
        // Log adjustment API might not exist yet, continue anyway
        print('Stock adjustment logging failed: $e');
      }
      
      // Refresh inventory to show updated data
      await loadStockLevels();
    } catch (e) {
      state = state.copyWith(error: 'Failed to update stock: ${e.toString()}');
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  // Helper methods for UI
  List<Product> getLowStockItems() {
    return state.lowStockProducts;
  }

  List<Product> getOutOfStockItems() {
    return state.outOfStockProducts;
  }

  int getTotalAlerts() {
    return state.lowStockProducts.length + state.outOfStockProducts.length;
  }

  double getTotalInventoryValue() {
    return state.products.fold(0.0, (sum, product) {
      return sum + (product.stockLevel * product.price);
    });
  }
}

final inventoryProvider = StateNotifierProvider<InventoryNotifier, InventoryState>((ref) {
  final apiService = ref.read(apiServiceProvider);
  return InventoryNotifier(apiService);
});

// Convenience providers for specific data
final stockLevelsProvider = Provider<List<Product>>((ref) {
  return ref.watch(inventoryProvider).products;
});

final stockAlertsProvider = Provider<List<Product>>((ref) {
  final inventory = ref.watch(inventoryProvider);
  return [...inventory.lowStockProducts, ...inventory.outOfStockProducts];
});

final lowStockItemsProvider = Provider<List<Product>>((ref) {
  return ref.read(inventoryProvider.notifier).getLowStockItems();
});

final outOfStockItemsProvider = Provider<List<Product>>((ref) {
  return ref.read(inventoryProvider.notifier).getOutOfStockItems();
});

final inventoryValueProvider = Provider<double>((ref) {
  return ref.read(inventoryProvider.notifier).getTotalInventoryValue();
});

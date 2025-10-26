import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:state_notifier/state_notifier.dart';
import '../models/product.dart' as product_model;
import '../models/order.dart';

class ProductStockState {
  final Map<int, double> stockHealthScores;
  final Map<int, Map<String, dynamic>> stockAnalytics;
  final Map<int, List<Map<String, dynamic>>> stockHistory;
  final bool isLoading;
  final String? error;

  const ProductStockState({
    this.stockHealthScores = const {},
    this.stockAnalytics = const {},
    this.stockHistory = const {},
    this.isLoading = false,
    this.error,
  });

  ProductStockState copyWith({
    Map<int, double>? stockHealthScores,
    Map<int, Map<String, dynamic>>? stockAnalytics,
    Map<int, List<Map<String, dynamic>>>? stockHistory,
    bool? isLoading,
    String? error,
  }) {
    return ProductStockState(
      stockHealthScores: stockHealthScores ?? this.stockHealthScores,
      stockAnalytics: stockAnalytics ?? this.stockAnalytics,
      stockHistory: stockHistory ?? this.stockHistory,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class ProductStockNotifier extends StateNotifier<ProductStockState> {
  ProductStockNotifier() : super(const ProductStockState());

  // Calculate comprehensive stock health score (0-100)
  double calculateStockHealthScore(product_model.Product product, List<Order> orders) {
    // 1. Stock Level Score (40% weight)
    double levelScore = 0.0;
    if (product.minimumStock > 0) {
      levelScore = (product.stockLevel / product.minimumStock).clamp(0, 2.0);
      if (levelScore > 1.0) {
        levelScore = 1.0 + (levelScore - 1.0) * 0.5; // Diminishing returns for excess stock
      }
      levelScore = levelScore.clamp(0, 1.0);
    } else {
      levelScore = product.stockLevel > 0 ? 0.8 : 0.0;
    }

    // 2. Turnover Score (30% weight)
    double turnoverScore = _calculateTurnoverScore(product, orders);

    // 3. Demand Consistency Score (20% weight)
    double demandScore = _calculateDemandConsistencyScore(product, orders);

    // 4. Stock Trend Score (10% weight)
    double trendScore = _calculateStockTrendScore(product);

    // Weighted final score
    double finalScore = (levelScore * 0.4 + turnoverScore * 0.3 + demandScore * 0.2 + trendScore * 0.1) * 100;
    
    return finalScore.clamp(0, 100);
  }

  double _calculateTurnoverScore(product_model.Product product, List<Order> orders) {
    // Calculate how frequently this product is ordered
    final productOrders = orders.where((order) => 
      order.items.any((item) => item.product.id == product.id)
    ).length;

    if (orders.isEmpty) return 0.5; // Neutral score if no order history

    double turnoverRate = productOrders / orders.length;
    
    // Optimal turnover rate is around 0.3-0.7 (30-70% of orders contain this product)
    if (turnoverRate >= 0.3 && turnoverRate <= 0.7) {
      return 1.0; // Perfect score
    } else if (turnoverRate < 0.3) {
      return turnoverRate / 0.3; // Scale up to 1.0
    } else {
      return 1.0 - ((turnoverRate - 0.7) / 0.3).clamp(0, 0.5); // Diminishing returns for high turnover
    }
  }

  double _calculateDemandConsistencyScore(product_model.Product product, List<Order> orders) {
    // Calculate consistency of demand over time
    final productOrderQuantities = <double>[];
    
    for (final order in orders) {
      for (final item in order.items) {
        if (item.product.id == product.id) {
          productOrderQuantities.add(item.quantity);
        }
      }
    }

    if (productOrderQuantities.isEmpty) return 0.5; // Neutral score
    if (productOrderQuantities.length == 1) return 0.8; // Single order, good but not perfect

    // Calculate coefficient of variation (lower is better for consistency)
    double mean = productOrderQuantities.reduce((a, b) => a + b) / productOrderQuantities.length;
    double variance = productOrderQuantities.map((q) => (q - mean) * (q - mean)).reduce((a, b) => a + b) / productOrderQuantities.length;
    double stdDev = variance > 0 ? variance : 0.0;
    double cv = mean > 0 ? stdDev / mean : 1.0;

    // Convert CV to score (lower CV = higher score)
    return (1.0 / (1.0 + cv)).clamp(0, 1.0);
  }

  double _calculateStockTrendScore(product_model.Product product) {
    // Simplified trend score based on current stock vs minimum stock ratio
    if (product.minimumStock <= 0) return 0.5;
    
    double ratio = product.stockLevel / product.minimumStock;
    
    if (ratio >= 1.5) return 1.0; // Well stocked
    if (ratio >= 1.0) return 0.8; // Adequately stocked
    if (ratio >= 0.5) return 0.6; // Low stock
    if (ratio > 0) return 0.3; // Critical stock
    return 0.0; // Out of stock
  }

  // Calculate comprehensive stock analytics for a product
  Map<String, dynamic> calculateStockAnalytics(product_model.Product product, List<Order> orders) {
    final productOrders = orders.where((order) => 
      order.items.any((item) => item.product.id == product.id)
    ).toList();

    double totalQuantityOrdered = 0;
    double totalRevenue = 0;
    int orderFrequency = productOrders.length;

    for (final order in productOrders) {
      for (final item in order.items) {
        if (item.product.id == product.id) {
          totalQuantityOrdered += item.quantity;
          totalRevenue += item.totalPrice;
        }
      }
    }

    double averageOrderQuantity = orderFrequency > 0 ? totalQuantityOrdered / orderFrequency : 0;
    double stockValue = product.stockLevel * product.price;
    double stockTurnoverRate = product.stockLevel > 0 ? totalQuantityOrdered / product.stockLevel : 0;
    
    // Days of stock remaining (simplified calculation)
    double dailyDemand = orderFrequency > 0 ? totalQuantityOrdered / (orders.length * 1.0) : 0;
    double daysOfStock = dailyDemand > 0 ? product.stockLevel / dailyDemand : double.infinity;

    // Reorder recommendations
    bool shouldReorder = product.stockLevel <= product.minimumStock;
    double recommendedOrderQuantity = _calculateRecommendedOrderQuantity(product, averageOrderQuantity, dailyDemand);

    return {
      'healthScore': calculateStockHealthScore(product, orders),
      'stockValue': stockValue,
      'totalQuantityOrdered': totalQuantityOrdered,
      'totalRevenue': totalRevenue,
      'orderFrequency': orderFrequency,
      'averageOrderQuantity': averageOrderQuantity,
      'stockTurnoverRate': stockTurnoverRate,
      'daysOfStock': daysOfStock.isFinite ? daysOfStock : 999,
      'shouldReorder': shouldReorder,
      'recommendedOrderQuantity': recommendedOrderQuantity,
      'stockStatus': _getStockStatus(product),
      'demandTrend': _getDemandTrend(productOrders),
      'lastOrderDate': productOrders.isNotEmpty ? productOrders.last.orderDate : null,
    };
  }

  double _calculateRecommendedOrderQuantity(product_model.Product product, double averageOrderQuantity, double dailyDemand) {
    // Economic Order Quantity (EOQ) simplified calculation
    // Factors: average demand, lead time, safety stock
    
    double leadTimeDays = 7; // Assume 7 days lead time
    double safetyStockDays = 3; // 3 days safety stock
    
    double leadTimeDemand = dailyDemand * leadTimeDays;
    double safetyStock = dailyDemand * safetyStockDays;
    double reorderPoint = leadTimeDemand + safetyStock;
    
    // Recommended order quantity to reach optimal stock level
    double optimalStock = reorderPoint + (averageOrderQuantity * 2); // 2x average order as buffer
    double currentDeficit = optimalStock - product.stockLevel;
    
    return currentDeficit > 0 ? currentDeficit : averageOrderQuantity;
  }

  String _getStockStatus(product_model.Product product) {
    if (product.stockLevel <= 0) return 'Out of Stock';
    if (product.stockLevel <= product.minimumStock * 0.5) return 'Critical';
    if (product.stockLevel <= product.minimumStock) return 'Low';
    if (product.stockLevel <= product.minimumStock * 2) return 'Good';
    return 'Excellent';
  }

  String _getDemandTrend(List<Order> productOrders) {
    if (productOrders.length < 2) return 'Insufficient Data';
    
    // Simple trend analysis based on order frequency over time
    final recentOrders = productOrders.length >= 5 ? productOrders.sublist(productOrders.length - 5) : productOrders;
    final olderOrders = productOrders.length >= 10 ? productOrders.sublist(0, productOrders.length - 5) : [];
    
    if (olderOrders.isEmpty) return 'New Product';
    
    double recentAverage = recentOrders.length.toDouble();
    double olderAverage = olderOrders.length.toDouble();
    
    if (recentAverage > olderAverage * 1.2) return 'Increasing';
    if (recentAverage < olderAverage * 0.8) return 'Decreasing';
    return 'Stable';
  }

  // Update analytics for all products
  Future<void> updateAllProductAnalytics(List<product_model.Product> products, List<Order> orders) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final Map<int, double> healthScores = {};
      final Map<int, Map<String, dynamic>> analytics = {};
      
      for (final product in products) {
        healthScores[product.id] = calculateStockHealthScore(product, orders);
        analytics[product.id] = calculateStockAnalytics(product, orders);
      }
      
      state = state.copyWith(
        stockHealthScores: healthScores,
        stockAnalytics: analytics,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to update product analytics: $e',
      );
    }
  }

  // Get analytics for a specific product
  Map<String, dynamic>? getProductAnalytics(int productId) {
    return state.stockAnalytics[productId];
  }

  // Get health score for a specific product
  double? getProductHealthScore(int productId) {
    return state.stockHealthScores[productId];
  }

  // Get products sorted by health score
  List<MapEntry<int, double>> getProductsByHealthScore({bool ascending = false}) {
    final entries = state.stockHealthScores.entries.toList();
    entries.sort((a, b) => ascending ? a.value.compareTo(b.value) : b.value.compareTo(a.value));
    return entries;
  }

  // Get products that need reordering
  List<int> getProductsNeedingReorder() {
    return state.stockAnalytics.entries
        .where((entry) => entry.value['shouldReorder'] == true)
        .map((entry) => entry.key)
        .toList();
  }
}

final productStockProvider = StateNotifierProvider<ProductStockNotifier, ProductStockState>((ref) {
  return ProductStockNotifier();
});

// Convenience providers
final productHealthScoresProvider = Provider<Map<int, double>>((ref) {
  return ref.watch(productStockProvider).stockHealthScores;
});

final productAnalyticsProvider = Provider<Map<int, Map<String, dynamic>>>((ref) {
  return ref.watch(productStockProvider).stockAnalytics;
});

final productsNeedingReorderProvider = Provider<List<int>>((ref) {
  return ref.read(productStockProvider.notifier).getProductsNeedingReorder();
});

final topPerformingProductsProvider = Provider<List<MapEntry<int, double>>>((ref) {
  return ref.read(productStockProvider.notifier).getProductsByHealthScore(ascending: false);
});

final poorPerformingProductsProvider = Provider<List<MapEntry<int, double>>>((ref) {
  return ref.read(productStockProvider.notifier).getProductsByHealthScore(ascending: true);
});

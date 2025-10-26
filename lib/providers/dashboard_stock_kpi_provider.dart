import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/product.dart' as product_model;
import '../models/order.dart';
import '../providers/inventory_provider.dart';
import '../providers/orders_provider.dart';
import '../providers/products_provider.dart';

// Advanced KPI calculations for dashboard stock analytics
final dashboardStockKPIProvider = Provider<Map<String, dynamic>>((ref) {
  final inventory = ref.watch(inventoryProvider);
  final orders = ref.watch(ordersProvider);
  // final products = ref.watch(productsProvider); // Not used in this calculation

  if (inventory.products.isEmpty || orders.orders.isEmpty) {
    return _getEmptyKPIs();
  }

  return _calculateAdvancedStockKPIs(inventory.products, orders.orders.cast<Order>());
});

Map<String, dynamic> _getEmptyKPIs() {
  return {
    'stockTurnoverRate': 0.0,
    'stockAccuracy': 100.0,
    'fillRate': 100.0,
    'stockoutFrequency': 0.0,
    'carryingCostEfficiency': 0.0,
    'demandForecastAccuracy': 0.0,
    'averageDaysOfStock': 0.0,
    'stockVelocity': 0.0,
    'reorderPointAccuracy': 100.0,
    'excessStockPercentage': 0.0,
    'stockHealthScore': 100.0,
    'criticalStockItems': 0,
    'totalStockValue': 0.0,
    'stockMovementTrend': 'stable',
    'topPerformingProducts': <Map<String, dynamic>>[],
    'underperformingProducts': <Map<String, dynamic>>[],
  };
}

Map<String, dynamic> _calculateAdvancedStockKPIs(List<product_model.Product> products, List<Order> orders) {
  // 1. Stock Turnover Rate
  double stockTurnoverRate = _calculateStockTurnoverRate(products, orders);
  
  // 2. Stock Accuracy (theoretical vs actual)
  double stockAccuracy = _calculateStockAccuracy(products);
  
  // 3. Fill Rate (orders fulfilled vs total orders)
  double fillRate = _calculateFillRate(orders, products);
  
  // 4. Stockout Frequency
  double stockoutFrequency = _calculateStockoutFrequency(products);
  
  // 5. Carrying Cost Efficiency
  double carryingCostEfficiency = _calculateCarryingCostEfficiency(products);
  
  // 6. Demand Forecast Accuracy
  double demandForecastAccuracy = _calculateDemandForecastAccuracy(products, orders);
  
  // 7. Average Days of Stock
  double averageDaysOfStock = _calculateAverageDaysOfStock(products, orders);
  
  // 8. Stock Velocity
  double stockVelocity = _calculateStockVelocity(products, orders);
  
  // 9. Reorder Point Accuracy
  double reorderPointAccuracy = _calculateReorderPointAccuracy(products, orders);
  
  // 10. Excess Stock Percentage
  double excessStockPercentage = _calculateExcessStockPercentage(products);
  
  // 11. Overall Stock Health Score
  double stockHealthScore = _calculateOverallStockHealthScore(
    stockTurnoverRate, stockAccuracy, fillRate, stockoutFrequency, 
    carryingCostEfficiency, demandForecastAccuracy
  );
  
  // 12. Critical Stock Items Count
  int criticalStockItems = _countCriticalStockItems(products);
  
  // 13. Total Stock Value
  double totalStockValue = _calculateTotalStockValue(products);
  
  // 14. Stock Movement Trend
  String stockMovementTrend = _analyzeStockMovementTrend(products, orders);
  
  // 15. Performance Analysis
  List<Map<String, dynamic>> topPerformingProducts = _getTopPerformingProducts(products, orders);
  List<Map<String, dynamic>> underperformingProducts = _getUnderperformingProducts(products, orders);

  return {
    'stockTurnoverRate': stockTurnoverRate,
    'stockAccuracy': stockAccuracy,
    'fillRate': fillRate,
    'stockoutFrequency': stockoutFrequency,
    'carryingCostEfficiency': carryingCostEfficiency,
    'demandForecastAccuracy': demandForecastAccuracy,
    'averageDaysOfStock': averageDaysOfStock,
    'stockVelocity': stockVelocity,
    'reorderPointAccuracy': reorderPointAccuracy,
    'excessStockPercentage': excessStockPercentage,
    'stockHealthScore': stockHealthScore,
    'criticalStockItems': criticalStockItems,
    'totalStockValue': totalStockValue,
    'stockMovementTrend': stockMovementTrend,
    'topPerformingProducts': topPerformingProducts,
    'underperformingProducts': underperformingProducts,
  };
}

double _calculateStockTurnoverRate(List<product_model.Product> products, List<Order> orders) {
  if (products.isEmpty) return 0.0;
  
  double totalCOGS = 0.0; // Cost of Goods Sold
  double averageInventoryValue = 0.0;
  
  // Calculate total revenue from orders (proxy for COGS)
  for (final order in orders) {
    for (final item in order.items) {
      totalCOGS += item.totalPrice;
    }
  }
  
  // Calculate average inventory value
  for (final product in products) {
    averageInventoryValue += product.stockLevel * product.price;
  }
  
  return averageInventoryValue > 0 ? totalCOGS / averageInventoryValue : 0.0;
}

double _calculateStockAccuracy(List<product_model.Product> products) {
  if (products.isEmpty) return 100.0;
  
  // Simplified accuracy calculation based on stock levels vs minimum stock
  int accurateProducts = 0;
  
  for (final product in products) {
    // Consider accurate if stock is between 50% and 200% of minimum stock
    if (product.minimumStock > 0) {
      double ratio = product.stockLevel / product.minimumStock;
      if (ratio >= 0.5 && ratio <= 2.0) {
        accurateProducts++;
      }
    } else if (product.stockLevel > 0) {
      accurateProducts++; // If no minimum set but has stock, consider accurate
    }
  }
  
  return (accurateProducts / products.length) * 100;
}

double _calculateFillRate(List<Order> orders, List<product_model.Product> products) {
  if (orders.isEmpty) return 100.0;
  
  int fulfillableOrders = 0;
  
  for (final order in orders) {
    bool canFulfill = true;
    
    for (final item in order.items) {
      final product = products.firstWhere(
        (p) => p.id == item.product.id,
        orElse: () => product_model.Product(
          id: item.product.id,
          name: item.product.name,
          department: 'Other',
          price: item.product.price,
          unit: 'each',
          stockLevel: 0,
          minimumStock: 0,
        ),
      );
      
      if (product.stockLevel < item.quantity) {
        canFulfill = false;
        break;
      }
    }
    
    if (canFulfill) fulfillableOrders++;
  }
  
  return (fulfillableOrders / orders.length) * 100;
}

double _calculateStockoutFrequency(List<product_model.Product> products) {
  if (products.isEmpty) return 0.0;
  
  int stockoutProducts = products.where((p) => p.stockLevel <= 0).length;
  return (stockoutProducts / products.length) * 100;
}

double _calculateCarryingCostEfficiency(List<product_model.Product> products) {
  if (products.isEmpty) return 0.0;
  
  double totalStockValue = 0.0;
  double optimalStockValue = 0.0;
  
  for (final product in products) {
    double currentValue = product.stockLevel * product.price;
    double optimalValue = product.minimumStock * 1.5 * product.price; // 1.5x minimum as optimal
    
    totalStockValue += currentValue;
    optimalStockValue += optimalValue;
  }
  
  return optimalStockValue > 0 ? (optimalStockValue / totalStockValue) * 100 : 0.0;
}

double _calculateDemandForecastAccuracy(List<product_model.Product> products, List<Order> orders) {
  if (products.isEmpty || orders.isEmpty) return 100.0;
  
  // Simplified forecast accuracy based on stock levels vs actual demand
  double totalAccuracy = 0.0;
  int validProducts = 0;
  
  for (final product in products) {
    // Calculate actual demand from orders
    double actualDemand = 0.0;
    for (final order in orders) {
      for (final item in order.items) {
        if (item.product.id == product.id) {
          actualDemand += item.quantity;
        }
      }
    }
    
    if (actualDemand > 0) {
      // Compare forecasted stock (minimum stock) with actual demand
      double forecastAccuracy = product.minimumStock > 0 
          ? (1.0 - (actualDemand - product.minimumStock).abs() / actualDemand).clamp(0, 1)
          : 0.5;
      
      totalAccuracy += forecastAccuracy;
      validProducts++;
    }
  }
  
  return validProducts > 0 ? (totalAccuracy / validProducts) * 100 : 100.0;
}

double _calculateAverageDaysOfStock(List<product_model.Product> products, List<Order> orders) {
  if (products.isEmpty || orders.isEmpty) return 0.0;
  
  double totalDays = 0.0;
  int validProducts = 0;
  
  for (final product in products) {
    // Calculate daily demand
    double totalDemand = 0.0;
    for (final order in orders) {
      for (final item in order.items) {
        if (item.product.id == product.id) {
          totalDemand += item.quantity;
        }
      }
    }
    
    double dailyDemand = totalDemand / orders.length;
    if (dailyDemand > 0) {
      double daysOfStock = product.stockLevel / dailyDemand;
      totalDays += daysOfStock;
      validProducts++;
    }
  }
  
  return validProducts > 0 ? totalDays / validProducts : 0.0;
}

double _calculateStockVelocity(List<product_model.Product> products, List<Order> orders) {
  if (products.isEmpty || orders.isEmpty) return 0.0;
  
  double totalVelocity = 0.0;
  int validProducts = 0;
  
  for (final product in products) {
    double totalSold = 0.0;
    for (final order in orders) {
      for (final item in order.items) {
        if (item.product.id == product.id) {
          totalSold += item.quantity;
        }
      }
    }
    
    if (product.stockLevel > 0) {
      double velocity = totalSold / product.stockLevel;
      totalVelocity += velocity;
      validProducts++;
    }
  }
  
  return validProducts > 0 ? totalVelocity / validProducts : 0.0;
}

double _calculateReorderPointAccuracy(List<product_model.Product> products, List<Order> orders) {
  if (products.isEmpty) return 100.0;
  
  int accurateReorderPoints = 0;
  
  for (final product in products) {
    // Check if reorder point (minimum stock) is appropriate
    bool hasRecentOrders = orders.any((order) => 
      order.items.any((item) => item.product.id == product.id)
    );
    
    if (hasRecentOrders) {
      // If product is ordered and stock > minimum, reorder point is accurate
      if (product.stockLevel >= product.minimumStock) {
        accurateReorderPoints++;
      }
    } else {
      // If product is not ordered recently, having stock above minimum is good
      if (product.stockLevel >= product.minimumStock) {
        accurateReorderPoints++;
      }
    }
  }
  
  return (accurateReorderPoints / products.length) * 100;
}

double _calculateExcessStockPercentage(List<product_model.Product> products) {
  if (products.isEmpty) return 0.0;
  
  int excessStockProducts = 0;
  
  for (final product in products) {
    // Consider excess if stock is more than 3x minimum stock
    if (product.minimumStock > 0 && product.stockLevel > product.minimumStock * 3) {
      excessStockProducts++;
    }
  }
  
  return (excessStockProducts / products.length) * 100;
}

double _calculateOverallStockHealthScore(
  double turnoverRate, double accuracy, double fillRate, 
  double stockoutFreq, double carryingCost, double forecastAccuracy
) {
  // Weighted average of all metrics
  double score = (
    (turnoverRate.clamp(0, 5) / 5) * 0.2 +  // 20% weight
    (accuracy / 100) * 0.2 +                 // 20% weight
    (fillRate / 100) * 0.25 +                // 25% weight
    ((100 - stockoutFreq) / 100) * 0.15 +    // 15% weight
    (carryingCost / 100) * 0.1 +             // 10% weight
    (forecastAccuracy / 100) * 0.1           // 10% weight
  ) * 100;
  
  return score.clamp(0, 100);
}

int _countCriticalStockItems(List<product_model.Product> products) {
  return products.where((p) => 
    p.stockLevel <= 0 || p.stockLevel <= p.minimumStock * 0.5
  ).length;
}

double _calculateTotalStockValue(List<product_model.Product> products) {
  return products.fold(0.0, (sum, product) => 
    sum + (product.stockLevel * product.price)
  );
}

String _analyzeStockMovementTrend(List<product_model.Product> products, List<Order> orders) {
  if (orders.length < 2) return 'insufficient_data';
  
  // Simple trend analysis based on recent vs older orders
  final recentOrders = orders.length >= 10 ? orders.sublist(orders.length - 5) : orders;
  final olderOrders = orders.length >= 10 ? orders.sublist(0, 5) : [];
  
  if (olderOrders.isEmpty) return 'new_data';
  
  double recentActivity = _calculateOrderActivity(recentOrders.cast<Order>());
  double olderActivity = _calculateOrderActivity(olderOrders.cast<Order>());
  
  if (recentActivity > olderActivity * 1.2) return 'increasing';
  if (recentActivity < olderActivity * 0.8) return 'decreasing';
  return 'stable';
}

double _calculateOrderActivity(List<Order> orders) {
  double totalItems = 0.0;
  for (final order in orders) {
    totalItems += order.items.length;
  }
  return totalItems;
}

List<Map<String, dynamic>> _getTopPerformingProducts(List<product_model.Product> products, List<Order> orders) {
  final productPerformance = <Map<String, dynamic>>[];
  
  for (final product in products) {
    double totalRevenue = 0.0;
    int orderCount = 0;
    
    for (final order in orders) {
      for (final item in order.items) {
        if (item.product.id == product.id) {
          totalRevenue += item.totalPrice;
          orderCount++;
        }
      }
    }
    
    if (totalRevenue > 0) {
      productPerformance.add({
        'id': product.id,
        'name': product.name,
        'revenue': totalRevenue,
        'orderCount': orderCount,
        'stockLevel': product.stockLevel,
        'performance': totalRevenue / (product.stockLevel * product.price).clamp(1, double.infinity),
      });
    }
  }
  
  productPerformance.sort((a, b) => (b['performance'] as double).compareTo(a['performance'] as double));
  return productPerformance.take(5).toList();
}

List<Map<String, dynamic>> _getUnderperformingProducts(List<product_model.Product> products, List<Order> orders) {
  final productPerformance = <Map<String, dynamic>>[];
  
  for (final product in products) {
    double totalRevenue = 0.0;
    int orderCount = 0;
    
    for (final order in orders) {
      for (final item in order.items) {
        if (item.product.id == product.id) {
          totalRevenue += item.totalPrice;
          orderCount++;
        }
      }
    }
    
    // Include products with low performance or high stock but low sales
    double performance = totalRevenue / (product.stockLevel * product.price).clamp(1, double.infinity);
    
    productPerformance.add({
      'id': product.id,
      'name': product.name,
      'revenue': totalRevenue,
      'orderCount': orderCount,
      'stockLevel': product.stockLevel,
      'performance': performance,
    });
  }
  
  productPerformance.sort((a, b) => (a['performance'] as double).compareTo(b['performance'] as double));
  return productPerformance.take(5).toList();
}

// Real-time stock monitoring provider
final realTimeStockMonitorProvider = Provider<Map<String, dynamic>>((ref) {
  final inventory = ref.watch(inventoryProvider);
  final products = inventory.products;
  
  if (products.isEmpty) {
    return {
      'liveStockLevels': <Map<String, dynamic>>[],
      'criticalAlerts': <Map<String, dynamic>>[],
      'stockMovements': <Map<String, dynamic>>[],
      'stockVelocityMetrics': <Map<String, dynamic>>[],
    };
  }
  
  return {
    'liveStockLevels': _getLiveStockLevels(products),
    'criticalAlerts': _getCriticalStockAlerts(products),
    'stockMovements': _getRecentStockMovements(products),
    'stockVelocityMetrics': _getStockVelocityMetrics(products),
  };
});

List<Map<String, dynamic>> _getLiveStockLevels(List<product_model.Product> products) {
  return products.map((product) => {
    'id': product.id,
    'name': product.name,
    'currentStock': product.stockLevel,
    'minimumStock': product.minimumStock,
    'status': _getStockStatus(product),
    'percentage': product.minimumStock > 0 ? (product.stockLevel / product.minimumStock * 100).clamp(0, 200) : 100,
  }).toList();
}

List<Map<String, dynamic>> _getCriticalStockAlerts(List<product_model.Product> products) {
  return products.where((product) => 
    product.stockLevel <= 0 || product.stockLevel <= product.minimumStock
  ).map((product) => {
    'id': product.id,
    'name': product.name,
    'currentStock': product.stockLevel,
    'minimumStock': product.minimumStock,
    'alertLevel': product.stockLevel <= 0 ? 'critical' : 'warning',
    'message': product.stockLevel <= 0 ? 'Out of stock' : 'Below minimum stock level',
  }).toList();
}

Map<String, dynamic> _getRecentStockMovements(List<product_model.Product> products) {
  // Simplified stock movements (would normally come from stock transaction history)
  return {
    'totalMovements': products.length,
    'inbound': products.where((p) => p.stockLevel > p.minimumStock).length,
    'outbound': products.where((p) => p.stockLevel < p.minimumStock).length,
    'adjustments': 0, // Would track manual adjustments
  };
}

Map<String, dynamic> _getStockVelocityMetrics(List<product_model.Product> products) {
  double fastMoving = 0;
  double slowMoving = 0;
  double normal = 0;
  
  for (final product in products) {
    if (product.minimumStock > 0) {
      double ratio = product.stockLevel / product.minimumStock;
      if (ratio < 0.5) {
        fastMoving++;
      } else if (ratio > 2.0) {
        slowMoving++;
      } else {
        normal++;
      }
    }
  }
  
  return {
    'fastMoving': fastMoving,
    'slowMoving': slowMoving,
    'normal': normal,
    'total': products.length,
  };
}

String _getStockStatus(product_model.Product product) {
  if (product.stockLevel <= 0) return 'out_of_stock';
  if (product.stockLevel <= product.minimumStock * 0.5) return 'critical';
  if (product.stockLevel <= product.minimumStock) return 'low';
  if (product.stockLevel <= product.minimumStock * 2) return 'good';
  return 'excellent';
}

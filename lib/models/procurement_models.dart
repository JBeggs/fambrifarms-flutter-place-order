// Procurement Intelligence Models for Karl's Market Magic
// These models handle the intelligent market recommendations that save Karl hours!

class MarketRecommendation {
  final int id;
  final DateTime createdAt;
  final DateTime forDate;
  double totalEstimatedCost; // Made mutable for recalculation
  final String status;
  final Map<String, dynamic> analysisData;
  final String notes;
  final List<MarketRecommendationItem> items;
  final int itemsCount;

  MarketRecommendation({
    required this.id,
    required this.createdAt,
    required this.forDate,
    required this.totalEstimatedCost,
    required this.status,
    required this.analysisData,
    required this.notes,
    required this.items,
    required this.itemsCount,
  });

  factory MarketRecommendation.fromJson(Map<String, dynamic> json) {
    return MarketRecommendation(
      id: json['id'],
      createdAt: DateTime.parse(json['created_at']),
      forDate: DateTime.parse(json['for_date']),
      totalEstimatedCost: double.parse(json['total_estimated_cost'].toString()),
      status: json['status'],
      analysisData: json['analysis_data'] ?? {},
      notes: json['notes'] ?? '',
      items: (json['items'] as List?)
          ?.map((item) => MarketRecommendationItem.fromJson(item))
          .toList() ?? [],
      itemsCount: json['items_count'] ?? 0,
    );
  }

  String get statusDisplay {
    switch (status) {
      case 'pending': return 'Pending Review';
      case 'approved': return 'Approved by Karl';
      case 'purchased': return 'Purchased at Market';
      case 'cancelled': return 'Cancelled';
      default: return status;
    }
  }

  String get statusEmoji {
    switch (status) {
      case 'pending': return '⏳';
      case 'approved': return '✅';
      case 'purchased': return '🛒';
      case 'cancelled': return '❌';
      default: return '📋';
    }
  }

  // Time-saving insights for Karl
  String get timeSavingInsight {
    if (itemsCount == 0) return "No items needed - you can skip the market today! 🎉";
    
    final estimatedMarketTime = (itemsCount * 3) + 30; // 3 mins per item + 30 mins travel
    final manualPlanningTime = itemsCount * 5; // 5 mins manual planning per item
    final timeSaved = manualPlanningTime;
    
    return "This recommendation saves you $timeSaved minutes of planning time! Market trip: ~$estimatedMarketTime minutes total.";
  }

  double get totalBufferSavings {
    return items.fold(0.0, (sum, item) => sum + (item.recommendedQuantity - item.neededQuantity) * item.estimatedUnitPrice);
  }
}

class MarketRecommendationItem {
  final int id;
  final String productName;
  final String? productDepartment;
  final String unit;
  final double neededQuantity;
  double recommendedQuantity; // Made mutable for editing
  final double estimatedUnitPrice;
  double estimatedTotalCost; // Made mutable for recalculation
  final String reasoning;
  final String priority;
  final List<int> sourceOrders;

  MarketRecommendationItem({
    required this.id,
    required this.productName,
    this.productDepartment,
    required this.unit,
    required this.neededQuantity,
    required this.recommendedQuantity,
    required this.estimatedUnitPrice,
    required this.estimatedTotalCost,
    required this.reasoning,
    required this.priority,
    required this.sourceOrders,
  });

  factory MarketRecommendationItem.fromJson(Map<String, dynamic> json) {
    return MarketRecommendationItem(
      id: json['id'],
      productName: json['product_name'],
      productDepartment: json['product_department'],
      unit: json['unit'] ?? 'kg',
      neededQuantity: double.parse(json['needed_quantity'].toString()),
      recommendedQuantity: double.parse(json['recommended_quantity'].toString()),
      estimatedUnitPrice: double.parse(json['estimated_unit_price'].toString()),
      estimatedTotalCost: double.parse(json['estimated_total_cost'].toString()),
      reasoning: json['reasoning'] ?? '',
      priority: json['priority'],
      sourceOrders: List<int>.from(json['source_orders'] ?? []),
    );
  }

  String get priorityEmoji {
    switch (priority) {
      case 'critical': return '🔴';
      case 'high': return '🟠';
      case 'medium': return '🟡';
      case 'low': return '🟢';
      default: return '⚪';
    }
  }

  String get priorityDisplay {
    switch (priority) {
      case 'critical': return 'CRITICAL';
      case 'high': return 'HIGH';
      case 'medium': return 'MEDIUM';
      case 'low': return 'LOW';
      default: return priority.toUpperCase();
    }
  }

  double get bufferPercentage {
    if (neededQuantity == 0) return 0;
    final buffer = recommendedQuantity - neededQuantity;
    final percentage = (buffer / neededQuantity) * 100;
    // Round to fix floating point precision issues
    return (percentage * 100).round() / 100;
  }
  
  double get bufferQuantity {
    final buffer = recommendedQuantity - neededQuantity;
    // Round to fix floating point precision issues  
    return (buffer * 10).round() / 10;
  }

  String get smartSummary {
    return "$productName: ${recommendedQuantity.toStringAsFixed(1)}kg @ R${estimatedUnitPrice.toStringAsFixed(2)}/kg = R${estimatedTotalCost.toStringAsFixed(2)}";
  }
}

class ProcurementBuffer {
  final int id;
  final int productId;
  final String productName;
  final String? productDepartment;
  final double spoilageRate;
  final double cuttingWasteRate;
  final double qualityRejectionRate;
  final double totalBufferRate;
  final double marketPackSize;
  final String marketPackUnit;
  final bool isSeasonal;
  final List<int> peakSeasonMonths;
  final double peakSeasonBufferMultiplier;

  ProcurementBuffer({
    required this.id,
    required this.productId,
    required this.productName,
    this.productDepartment,
    required this.spoilageRate,
    required this.cuttingWasteRate,
    required this.qualityRejectionRate,
    required this.totalBufferRate,
    required this.marketPackSize,
    required this.marketPackUnit,
    required this.isSeasonal,
    required this.peakSeasonMonths,
    required this.peakSeasonBufferMultiplier,
  });

  factory ProcurementBuffer.fromJson(Map<String, dynamic> json) {
    return ProcurementBuffer(
      id: json['id'],
      productId: json['product'],
      productName: json['product_name'] ?? 'Unknown Product',
      productDepartment: json['product_department'],
      spoilageRate: double.parse(json['spoilage_rate'].toString()),
      cuttingWasteRate: double.parse(json['cutting_waste_rate'].toString()),
      qualityRejectionRate: double.parse(json['quality_rejection_rate'].toString()),
      totalBufferRate: double.parse(json['total_buffer_rate'].toString()),
      marketPackSize: double.parse(json['market_pack_size'].toString()),
      marketPackUnit: json['market_pack_unit'],
      isSeasonal: json['is_seasonal'] ?? false,
      peakSeasonMonths: List<int>.from(json['peak_season_months'] ?? []),
      peakSeasonBufferMultiplier: double.parse(json['peak_season_buffer_multiplier'].toString()),
    );
  }

  String get bufferSummary {
    final spoilage = (spoilageRate * 100).toStringAsFixed(1);
    final cutting = (cuttingWasteRate * 100).toStringAsFixed(1);
    final quality = (qualityRejectionRate * 100).toStringAsFixed(1);
    final total = (totalBufferRate * 100).toStringAsFixed(1);
    
    return "Spoilage: ${spoilage}% • Cutting: ${cutting}% • Quality: ${quality}% = ${total}% total buffer";
  }

  bool get isCurrentlyInSeason {
    if (!isSeasonal) return false;
    final currentMonth = DateTime.now().month;
    return peakSeasonMonths.contains(currentMonth);
  }

  String get seasonalStatus {
    if (!isSeasonal) return "Not seasonal";
    if (isCurrentlyInSeason) return "🌱 IN SEASON (${peakSeasonBufferMultiplier}x buffer)";
    return "Off season";
  }
}

class ProcurementDashboardData {
  final List<MarketRecommendation> recentRecommendations;
  final List<ProcurementBuffer> criticalStockItems;
  final int productsWithRecipes;
  final double totalProcurementValue30d;
  final int recommendationsCount;
  final int criticalItemsCount;

  ProcurementDashboardData({
    required this.recentRecommendations,
    required this.criticalStockItems,
    required this.productsWithRecipes,
    required this.totalProcurementValue30d,
    required this.recommendationsCount,
    required this.criticalItemsCount,
  });

  factory ProcurementDashboardData.fromJson(Map<String, dynamic> json) {
    final dashboardData = json['dashboard_data'];
    
    return ProcurementDashboardData(
      recentRecommendations: (dashboardData['recent_recommendations'] as List?)
          ?.map((item) => MarketRecommendation.fromJson(item))
          .toList() ?? [],
      criticalStockItems: (dashboardData['critical_stock_items'] as List?)
          ?.map((item) => ProcurementBuffer.fromJson(item))
          .toList() ?? [],
      productsWithRecipes: dashboardData['products_with_recipes'] ?? 0,
      totalProcurementValue30d: double.parse(dashboardData['total_procurement_value_30d'].toString()),
      recommendationsCount: dashboardData['recommendations_count'] ?? 0,
      criticalItemsCount: dashboardData['critical_items_count'] ?? 0,
    );
  }

  String get monthlySpendingSummary {
    return "R${totalProcurementValue30d.toStringAsFixed(2)} spent on market procurement in the last 30 days";
  }

  String get efficiencyInsight {
    if (recommendationsCount == 0) return "No recent recommendations - system is learning your patterns!";
    
    final avgRecommendationValue = totalProcurementValue30d / recommendationsCount;
    return "Average market trip: R${avgRecommendationValue.toStringAsFixed(2)} • ${recommendationsCount} trips saved you planning time!";
  }
}

class ProductRecipe {
  final int id;
  final int productId;
  final String productName;
  final List<Map<String, dynamic>> ingredients;
  final String instructions;
  final int prepTimeMinutes;
  final double yieldQuantity;
  final String yieldUnit;

  ProductRecipe({
    required this.id,
    required this.productId,
    required this.productName,
    required this.ingredients,
    required this.instructions,
    required this.prepTimeMinutes,
    required this.yieldQuantity,
    required this.yieldUnit,
  });

  factory ProductRecipe.fromJson(Map<String, dynamic> json) {
    return ProductRecipe(
      id: json['id'],
      productId: json['product'],
      productName: json['product_name'] ?? 'Unknown Product',
      ingredients: List<Map<String, dynamic>>.from(json['ingredients'] ?? []),
      instructions: json['instructions'] ?? '',
      prepTimeMinutes: json['prep_time_minutes'] ?? 0,
      yieldQuantity: double.parse(json['yield_quantity'].toString()),
      yieldUnit: json['yield_unit'] ?? 'piece',
    );
  }

  String get ingredientsSummary {
    if (ingredients.isEmpty) return "No ingredients defined";
    
    final ingredientNames = ingredients
        .map((ing) => ing['product_name'] ?? 'Unknown')
        .take(3)
        .join(', ');
    
    final remaining = ingredients.length - 3;
    if (remaining > 0) {
      return "$ingredientNames + $remaining more";
    }
    
    return ingredientNames;
  }

  double get totalIngredientCost {
    // This would be calculated based on current market prices
    // For now, return estimated cost
    return ingredients.length * 15.0; // R15 average per ingredient
  }
}


// Karl's Market Procurement Intelligence Service
// This service connects to the backend's smart procurement system

import 'package:dio/dio.dart';
import '../models/procurement_models.dart';
import '../config/app_config.dart';

class ProcurementService {
  final Dio _dio;
  static String get _baseUrl => '${AppConfig.djangoBaseUrl}/products/procurement';

  ProcurementService(this._dio);

  // Generate intelligent market recommendation
  Future<MarketRecommendation> generateMarketRecommendation({DateTime? forDate}) async {
    try {
      final data = <String, dynamic>{};
      if (forDate != null) {
        data['for_date'] = forDate.toIso8601String().split('T')[0];
      }

      final response = await _dio.post(
        '$_baseUrl/generate-recommendation/',
        data: data,
      );

      if (response.data['success'] == true) {
        return MarketRecommendation.fromJson(response.data['recommendation']);
      } else {
        throw Exception(response.data['error'] ?? 'Failed to generate recommendation');
      }
    } catch (e) {
      throw Exception('Failed to generate market recommendation: $e');
    }
  }

  // Get list of market recommendations
  Future<List<MarketRecommendation>> getMarketRecommendations({
    String? status,
    int daysBack = 30,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'days_back': daysBack.toString(),
      };
      
      if (status != null) {
        queryParams['status'] = status;
      }

      final response = await _dio.get(
        '$_baseUrl/recommendations/',
        queryParameters: queryParams,
      );

      if (response.data['success'] == true) {
        final recommendations = (response.data['recommendations'] as List)
            .map((json) => MarketRecommendation.fromJson(json))
            .toList();
        return recommendations;
      } else {
        throw Exception(response.data['error'] ?? 'Failed to fetch recommendations');
      }
    } catch (e) {
      throw Exception('Failed to fetch market recommendations: $e');
    }
  }

  // Approve a market recommendation
  Future<MarketRecommendation> approveMarketRecommendation(
    int recommendationId, {
    String? notes,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (notes != null && notes.isNotEmpty) {
        data['notes'] = notes;
      }

      final response = await _dio.post(
        '$_baseUrl/recommendations/$recommendationId/approve/',
        data: data,
      );

      if (response.data['success'] == true) {
        return MarketRecommendation.fromJson(response.data['recommendation']);
      } else {
        throw Exception(response.data['error'] ?? 'Failed to approve recommendation');
      }
    } catch (e) {
      throw Exception('Failed to approve recommendation: $e');
    }
  }

  // Get procurement buffers
  Future<List<ProcurementBuffer>> getProcurementBuffers() async {
    try {
      final response = await _dio.get('$_baseUrl/buffers/');

      if (response.data['success'] == true) {
        final buffers = (response.data['buffers'] as List)
            .map((json) => ProcurementBuffer.fromJson(json))
            .toList();
        return buffers;
      } else {
        throw Exception(response.data['error'] ?? 'Failed to fetch buffers');
      }
    } catch (e) {
      throw Exception('Failed to fetch procurement buffers: $e');
    }
  }

  // Update procurement buffer for a product
  Future<ProcurementBuffer> updateProcurementBuffer(
    int productId,
    Map<String, dynamic> bufferData,
  ) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/buffers/$productId/',
        data: bufferData,
      );

      if (response.data['success'] == true) {
        return ProcurementBuffer.fromJson(response.data['buffer']);
      } else {
        throw Exception(response.data['error'] ?? 'Failed to update buffer');
      }
    } catch (e) {
      throw Exception('Failed to update procurement buffer: $e');
    }
  }

  // Get product recipes
  Future<List<ProductRecipe>> getProductRecipes() async {
    try {
      final response = await _dio.get('$_baseUrl/recipes/');

      if (response.data['success'] == true) {
        final recipes = (response.data['recipes'] as List)
            .map((json) => ProductRecipe.fromJson(json))
            .toList();
        return recipes;
      } else {
        throw Exception(response.data['error'] ?? 'Failed to fetch recipes');
      }
    } catch (e) {
      throw Exception('Failed to fetch product recipes: $e');
    }
  }

  // Create veggie box recipes
  Future<List<String>> createVeggieBoxRecipes() async {
    try {
      final response = await _dio.post('$_baseUrl/recipes/create-veggie-boxes/');

      if (response.data['success'] == true) {
        return List<String>.from(response.data['recipes_created'] ?? []);
      } else {
        throw Exception(response.data['error'] ?? 'Failed to create recipes');
      }
    } catch (e) {
      throw Exception('Failed to create veggie box recipes: $e');
    }
  }

  // Get comprehensive procurement dashboard data
  Future<ProcurementDashboardData> getProcurementDashboardData() async {
    try {
      final response = await _dio.get('$_baseUrl/dashboard/');

      if (response.data['success'] == true) {
        return ProcurementDashboardData.fromJson(response.data);
      } else {
        throw Exception(response.data['error'] ?? 'Failed to fetch dashboard data');
      }
    } catch (e) {
      throw Exception('Failed to fetch procurement dashboard data: $e');
    }
  }

  // Helper method to calculate time savings
  Map<String, dynamic> calculateTimeSavings(MarketRecommendation recommendation) {
    final itemsCount = recommendation.itemsCount;
    
    // Time calculations (in minutes)
    final manualPlanningTime = itemsCount * 5; // 5 minutes per item to plan manually
    final marketNavigationTime = itemsCount * 2; // 2 minutes per item to find in market
    final priceComparisonTime = itemsCount * 3; // 3 minutes per item to compare prices
    final quantityCalculationTime = itemsCount * 2; // 2 minutes per item to calculate quantities
    
    final totalManualTime = manualPlanningTime + marketNavigationTime + priceComparisonTime + quantityCalculationTime;
    final systemTime = 2; // 2 minutes to review recommendation
    final timeSaved = totalManualTime - systemTime;
    
    // Market trip estimation
    final travelTime = 30; // 30 minutes travel time
    final shoppingTime = itemsCount * 3; // 3 minutes per item with recommendation
    final totalTripTime = travelTime + shoppingTime;
    
    // Cost savings from buffer optimization
    final bufferSavings = recommendation.totalBufferSavings;
    
    return {
      'time_saved_minutes': timeSaved,
      'time_saved_hours': (timeSaved / 60).toStringAsFixed(1),
      'total_trip_time_minutes': totalTripTime,
      'manual_planning_time': totalManualTime,
      'system_time': systemTime,
      'efficiency_improvement': totalManualTime > 0 ? ((timeSaved / totalManualTime) * 100).toStringAsFixed(1) : '0',
      'buffer_cost_savings': bufferSavings,
      'items_optimized': itemsCount,
    };
  }

  // Generate market trip summary for Karl
  String generateTripSummary(MarketRecommendation recommendation) {
    final savings = calculateTimeSavings(recommendation);
    final timeSaved = savings['time_saved_hours'];
    final tripTime = savings['total_trip_time_minutes'];
    final efficiency = savings['efficiency_improvement'];
    final costSavings = savings['buffer_cost_savings'];
    
    return """
🎉 KARL'S SMART MARKET TRIP SUMMARY

⏰ Time Savings: ${timeSaved}h saved on planning
🚗 Trip Duration: ~${tripTime} minutes total
📈 Efficiency: ${efficiency}% improvement over manual planning
💰 Buffer Optimization: R${costSavings.toStringAsFixed(2)} in smart purchasing

🛒 ${recommendation.itemsCount} items optimized with intelligent buffers
🧠 Spoilage, waste, and quality factors automatically calculated
📊 Based on upcoming orders and stock levels

Ready to make Karl's life easier! 🚀
    """.trim();
  }
}


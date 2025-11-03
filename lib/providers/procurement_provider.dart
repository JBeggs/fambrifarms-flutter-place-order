// Karl's Procurement Intelligence Provider
// State management for the market procurement system that saves Karl time!

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:state_notifier/state_notifier.dart';
import '../models/procurement_models.dart';
import '../models/product.dart';
import '../services/api_service.dart';
import '../providers/inventory_provider.dart';

// Procurement service provider - now uses centralized ApiService
final procurementServiceProvider = Provider<ApiService>((ref) {
  return ref.read(apiServiceProvider);
});

// Procurement dashboard data provider
final procurementDashboardProvider = FutureProvider<ProcurementDashboardData>((ref) async {
  final apiService = ref.read(procurementServiceProvider);
  final response = await apiService.getProcurementDashboardData();
  return ProcurementDashboardData.fromJson(response);
});

// Market recommendations provider
final marketRecommendationsProvider = FutureProvider.family<List<MarketRecommendation>, String?>((ref, status) async {
  final apiService = ref.read(procurementServiceProvider);
  final response = await apiService.getMarketRecommendations();
  return (response as List)
      .map((json) => MarketRecommendation.fromJson(json))
      .toList();
});

// Procurement buffers provider
final procurementBuffersProvider = FutureProvider<List<ProcurementBuffer>>((ref) async {
  final apiService = ref.read(procurementServiceProvider);
  final response = await apiService.getProcurementBuffers();
  return (response as List)
      .map((json) => ProcurementBuffer.fromJson(json))
      .toList();
});

// Product recipes provider
final productRecipesProvider = FutureProvider<List<ProductRecipe>>((ref) async {
  final apiService = ref.read(procurementServiceProvider);
  final response = await apiService.getProductRecipes();
  return (response as List)
      .map((json) => ProductRecipe.fromJson(json))
      .toList();
});

// Stock-based procurement providers
final stockBasedProcurementNeedsProvider = Provider<List<Product>>((ref) {
  final inventory = ref.watch(inventoryProvider);
  
  // Products that need urgent restocking (out of stock or critically low)
  return inventory.products.where((product) {
    return product.stockLevel <= (product.minimumStock * 0.5); // 50% of minimum stock
  }).toList();
});

final lowStockProcurementProvider = Provider<List<Product>>((ref) {
  final inventory = ref.watch(inventoryProvider);
  
  // Products approaching low stock threshold
  return inventory.products.where((product) {
    return product.stockLevel > 0 && 
           product.stockLevel <= product.minimumStock &&
           product.stockLevel > (product.minimumStock * 0.5);
  }).toList();
});

final stockHealthMetricsProvider = Provider<Map<String, dynamic>>((ref) {
  final inventory = ref.watch(inventoryProvider);
  final products = inventory.products;
  
  if (products.isEmpty) {
    return {
      'totalProducts': 0,
      'inStock': 0,
      'lowStock': 0,
      'outOfStock': 0,
      'criticalStock': 0,
      'stockHealthPercentage': 0.0,
      'totalStockValue': 0.0,
      'averageStockLevel': 0.0,
    };
  }
  
  final inStock = products.where((p) => p.stockLevel > p.minimumStock).length;
  final lowStock = products.where((p) => p.stockLevel > 0 && p.stockLevel <= p.minimumStock).length;
  final outOfStock = products.where((p) => p.stockLevel <= 0).length;
  final criticalStock = products.where((p) => p.stockLevel <= (p.minimumStock * 0.5)).length;
  
  final totalStockValue = products.fold(0.0, (sum, p) => sum + (p.stockLevel * p.price));
  final averageStockLevel = products.fold(0.0, (sum, p) => sum + p.stockLevel) / products.length;
  final stockHealthPercentage = (inStock / products.length) * 100;
  
  return {
    'totalProducts': products.length,
    'inStock': inStock,
    'lowStock': lowStock,
    'outOfStock': outOfStock,
    'criticalStock': criticalStock,
    'stockHealthPercentage': stockHealthPercentage,
    'totalStockValue': totalStockValue,
    'averageStockLevel': averageStockLevel,
  };
});

// Procurement state management
class ProcurementState {
  final List<MarketRecommendation> recommendations;
  final List<ProcurementBuffer> buffers;
  final List<ProductRecipe> recipes;
  final ProcurementDashboardData? dashboardData;
  final bool isLoading;
  final String? error;
  final MarketRecommendation? activeRecommendation;

  ProcurementState({
    this.recommendations = const [],
    this.buffers = const [],
    this.recipes = const [],
    this.dashboardData,
    this.isLoading = false,
    this.error,
    this.activeRecommendation,
  });

  ProcurementState copyWith({
    List<MarketRecommendation>? recommendations,
    List<ProcurementBuffer>? buffers,
    List<ProductRecipe>? recipes,
    ProcurementDashboardData? dashboardData,
    bool? isLoading,
    String? error,
    MarketRecommendation? activeRecommendation,
  }) {
    return ProcurementState(
      recommendations: recommendations ?? this.recommendations,
      buffers: buffers ?? this.buffers,
      recipes: recipes ?? this.recipes,
      dashboardData: dashboardData ?? this.dashboardData,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      activeRecommendation: activeRecommendation ?? this.activeRecommendation,
    );
  }

  // Computed properties for Karl's insights
  int get totalRecommendations => recommendations.length;
  int get pendingRecommendations => recommendations.where((r) => r.status == 'pending').length;
  int get approvedRecommendations => recommendations.where((r) => r.status == 'approved').length;
  
  double get totalEstimatedSpending => recommendations
      .where((r) => r.status == 'approved')
      .fold(0.0, (sum, r) => sum + r.totalEstimatedCost);
  
  int get criticalItems => buffers.where((b) => b.totalBufferRate > 0.3).length; // >30% buffer = critical
  
  String get karlsTimeSavingSummary {
    if (recommendations.isEmpty) return "No recommendations yet - system is learning your patterns!";
    
    final totalItems = recommendations.fold(0, (sum, r) => sum + r.itemsCount);
    final timeSavedHours = (totalItems * 12) / 60; // 12 minutes saved per item
    
    return "You've saved ${timeSavedHours.toStringAsFixed(1)} hours with ${totalRecommendations} smart recommendations!";
  }
}

// Procurement state notifier
class ProcurementNotifier extends StateNotifier<ProcurementState> {
  final ApiService _apiService;

  ProcurementNotifier(this._apiService) : super(ProcurementState());

  // Clear error state
  void clearError() {
    state = state.copyWith(error: null);
  }

  // Load all procurement data
  Future<void> loadProcurementData() async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      // Load data sequentially to reduce server load and avoid connection issues
      print('[PROCUREMENT] Loading recommendations...');
      final recommendationsData = await _apiService.getMarketRecommendations();
      
      // Small delay between API calls to avoid overwhelming the server
      await Future.delayed(const Duration(milliseconds: 200));
      
      print('[PROCUREMENT] Loading dashboard data...');
      final dashboardData = await _apiService.getProcurementDashboardData();
      
      await Future.delayed(const Duration(milliseconds: 200));
      
      print('[PROCUREMENT] Loading buffers...');
      final buffersData = await _apiService.getProcurementBuffers();
      
      // Load optional data (recipes) separately to avoid breaking the app
      List<ProductRecipe> loadedRecipes = [];
      try {
        await Future.delayed(const Duration(milliseconds: 200));
        print('[PROCUREMENT] Loading recipes (optional)...');
        final recipesData = await _apiService.getProductRecipes();
        loadedRecipes = (recipesData as List).map((json) => ProductRecipe.fromJson(json)).toList();
      } catch (recipesError) {
        // Recipes are optional - log error but continue
        print('⚠️ Failed to load recipes (optional): $recipesError');
      }

      state = state.copyWith(
        recommendations: (recommendationsData as List).map((json) => MarketRecommendation.fromJson(json)).toList(),
        buffers: (buffersData as List).map((json) => ProcurementBuffer.fromJson(json)).toList(),
        recipes: loadedRecipes, // Use loaded recipes or empty list if failed
        dashboardData: ProcurementDashboardData.fromJson(dashboardData),
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  // Generate new market recommendation - Karl's magic moment!
  Future<MarketRecommendation?> generateMarketRecommendation({DateTime? forDate}) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final requestData = <String, dynamic>{};
      if (forDate != null) {
        requestData['for_date'] = forDate.toIso8601String().split('T')[0];
      }
      
      final result = await _apiService.generateMarketRecommendation(requestData);
      final recommendation = MarketRecommendation.fromJson(result['recommendation']);
      
      // Add to recommendations list
      final updatedRecommendations = [recommendation, ...state.recommendations];
      
      state = state.copyWith(
        recommendations: updatedRecommendations,
        activeRecommendation: recommendation,
        isLoading: false,
      );
      
      return recommendation;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return null;
    }
  }

  // Approve recommendation - Karl says "Yes, let's do this!"
  Future<bool> approveRecommendation(int recommendationId, {String? notes}) async {
    try {
      final result = await _apiService.approveMarketRecommendation(recommendationId);
      final approvedRecommendation = MarketRecommendation.fromJson(result['recommendation']);
      
      // Update the recommendation in the list
      final updatedRecommendations = state.recommendations.map((r) {
        return r.id == recommendationId ? approvedRecommendation : r;
      }).toList();
      
      state = state.copyWith(
        recommendations: updatedRecommendations,
        activeRecommendation: approvedRecommendation,
      );
      
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  // Delete market recommendation - remove from state after successful deletion
  Future<bool> deleteRecommendation(int recommendationId) async {
    try {
      await _apiService.deleteMarketRecommendation(recommendationId);
      
      // Remove the recommendation from the list
      final updatedRecommendations = state.recommendations.where((r) => r.id != recommendationId).toList();
      
      state = state.copyWith(
        recommendations: updatedRecommendations,
        // Clear active recommendation if it was the deleted one
        activeRecommendation: state.activeRecommendation?.id == recommendationId ? null : state.activeRecommendation,
      );
      
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  // Update buffer settings for a product
  Future<bool> updateProductBuffer(int productId, Map<String, dynamic> bufferData) async {
    try {
      final result = await _apiService.updateProcurementBuffer(productId, bufferData);
      final updatedBuffer = ProcurementBuffer.fromJson(result);
      
      // Update the buffer in the list
      final updatedBuffers = state.buffers.map((b) {
        return b.productId == productId ? updatedBuffer : b;
      }).toList();
      
      state = state.copyWith(buffers: updatedBuffers);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  // Create veggie box recipes
  Future<List<String>> createVeggieBoxRecipes() async {
    try {
      final result = await _apiService.createVeggieBoxRecipes({});
      final createdRecipes = List<String>.from(result['recipes_created'] ?? []);
      
      // Try to reload recipes to get the new ones
      try {
        final recipesResponse = await _apiService.getProductRecipes();
        final updatedRecipes = (recipesResponse as List).map((json) => ProductRecipe.fromJson(json)).toList();
        state = state.copyWith(recipes: updatedRecipes);
      } catch (recipesError) {
        // If recipes reload fails, just log it - don't break the veggie box creation
        print('⚠️ Failed to reload recipes after creation: $recipesError');
      }
      
      return createdRecipes;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return [];
    }
  }

  // Clear error
  // Set active recommendation
  void setActiveRecommendation(MarketRecommendation recommendation) {
    state = state.copyWith(activeRecommendation: recommendation);
  }

  // Get time savings analysis for Karl
  Map<String, dynamic> getTimeSavingsAnalysis() {
    if (state.recommendations.isEmpty) {
      return {
        'total_time_saved_hours': 0.0,
        'total_items_optimized': 0,
        'efficiency_improvement': 0.0,
        'recommendations_count': 0,
        'message': 'Start generating recommendations to see your time savings!',
      };
    }

    final totalItems = state.recommendations.fold(0, (sum, r) => sum + r.itemsCount);
    final totalTimeSavedMinutes = totalItems * 12; // 12 minutes saved per item
    final totalTimeSavedHours = totalTimeSavedMinutes / 60;
    
    final manualTimeMinutes = totalItems * 15; // 15 minutes manual time per item
    final efficiencyImprovement = manualTimeMinutes > 0 
        ? (totalTimeSavedMinutes / manualTimeMinutes) * 100 
        : 0.0;

    return {
      'total_time_saved_hours': totalTimeSavedHours,
      'total_time_saved_minutes': totalTimeSavedMinutes,
      'total_items_optimized': totalItems,
      'efficiency_improvement': efficiencyImprovement,
      'recommendations_count': state.recommendations.length,
      'message': 'You\'ve saved ${totalTimeSavedHours.toStringAsFixed(1)} hours with smart procurement!',
    };
  }
}

// Main procurement provider
final procurementProvider = StateNotifierProvider<ProcurementNotifier, ProcurementState>((ref) {
  final apiService = ref.read(procurementServiceProvider);
  return ProcurementNotifier(apiService);
});

// Convenience providers for specific data
final pendingRecommendationsProvider = Provider<List<MarketRecommendation>>((ref) {
  final state = ref.watch(procurementProvider);
  return state.recommendations.where((r) => r.status == 'pending').toList();
});

final approvedRecommendationsProvider = Provider<List<MarketRecommendation>>((ref) {
  final state = ref.watch(procurementProvider);
  return state.recommendations.where((r) => r.status == 'approved').toList();
});

final criticalBuffersProvider = Provider<List<ProcurementBuffer>>((ref) {
  final state = ref.watch(procurementProvider);
  return state.buffers.where((b) => b.totalBufferRate > 0.3).toList();
});

final seasonalProductsProvider = Provider<List<ProcurementBuffer>>((ref) {
  final state = ref.watch(procurementProvider);
  return state.buffers.where((b) => b.isSeasonal && b.isCurrentlyInSeason).toList();
});

final timeSavingsProvider = Provider<Map<String, dynamic>>((ref) {
  final notifier = ref.read(procurementProvider.notifier);
  return notifier.getTimeSavingsAnalysis();
});


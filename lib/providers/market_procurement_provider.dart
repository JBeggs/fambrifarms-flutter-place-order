import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:state_notifier/state_notifier.dart';
import '../models/market_procurement.dart';

// Market procurement state
class MarketProcurementState {
  final List<MarketProcurement> procurements;
  final List<MarketProcurement> filteredProcurements;
  final bool isLoading;
  final String? error;
  final String searchQuery;
  final ProcurementStatus? selectedStatus;
  final MarketAnalytics? analytics;

  const MarketProcurementState({
    this.procurements = const [],
    this.filteredProcurements = const [],
    this.isLoading = false,
    this.error,
    this.searchQuery = '',
    this.selectedStatus,
    this.analytics,
  });

  MarketProcurementState copyWith({
    List<MarketProcurement>? procurements,
    List<MarketProcurement>? filteredProcurements,
    bool? isLoading,
    String? error,
    String? searchQuery,
    ProcurementStatus? selectedStatus,
    MarketAnalytics? analytics,
  }) {
    return MarketProcurementState(
      procurements: procurements ?? this.procurements,
      filteredProcurements: filteredProcurements ?? this.filteredProcurements,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedStatus: selectedStatus ?? this.selectedStatus,
      analytics: analytics ?? this.analytics,
    );
  }
}

// Market procurement provider
class MarketProcurementNotifier extends StateNotifier<MarketProcurementState> {
  MarketProcurementNotifier() : super(const MarketProcurementState()) {
    loadProcurements();
  }

  // Load all market procurements
  Future<void> loadProcurements() async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      
      // For now, we'll create sample data based on the Tshwane Market receipts
      final procurements = _generateSampleProcurements();
      final analytics = _calculateAnalytics(procurements);
      
      state = state.copyWith(
        procurements: procurements,
        filteredProcurements: procurements,
        analytics: analytics,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load market procurements: ${e.toString()}',
      );
    }
  }

  // Generate sample procurements based on Tshwane Market receipts
  List<MarketProcurement> _generateSampleProcurements() {
    final now = DateTime.now();
    
    return [
      // Recent procurement - Tuesday
      MarketProcurement(
        id: 1,
        purchaseDate: now.subtract(const Duration(days: 2)),
        marketName: 'Tshwane Fresh Produce Market',
        receiptNumber: 'TSH001234',
        totalAmount: 3247.50,
        vatAmount: 423.19,
        subtotal: 2824.31,
        status: ProcurementStatus.stockTaken,
        notes: 'Good quality overall, some tomato wastage',
        stockTakeDate: now.subtract(const Duration(days: 2, hours: 2)),
        stockTakeNotes: 'Verified weights and quality. 5% wastage on tomatoes.',
        items: [
          MarketPurchaseItem(
            id: 1,
            productCode: 'POT001',
            description: 'POTATO MONDIAL 1KG',
            category: 'Vegetables',
            quantity: 50,
            unit: 'kg',
            unitPrice: 25.00,
            totalCost: 1250.00,
            quality: 'Good',
            verifiedQuantity: 49,
            verifiedQuality: 'Good',
            wastage: 1.0,
          ),
          MarketPurchaseItem(
            id: 2,
            productCode: 'TOM001',
            description: 'TOMATOES',
            category: 'Vegetables',
            quantity: 30,
            unit: 'kg',
            unitPrice: 45.00,
            totalCost: 1350.00,
            quality: 'Mixed',
            verifiedQuantity: 28,
            verifiedQuality: 'Good',
            wastage: 2.0,
          ),
          MarketPurchaseItem(
            id: 3,
            productCode: 'ONI001',
            description: 'ONIONS BROWN',
            category: 'Vegetables',
            quantity: 25,
            unit: 'kg',
            unitPrice: 35.00,
            totalCost: 875.00,
            quality: 'Excellent',
            verifiedQuantity: 25,
            verifiedQuality: 'Excellent',
          ),
          MarketPurchaseItem(
            id: 4,
            productCode: 'CAR001',
            description: 'CARROTS',
            category: 'Vegetables',
            quantity: 20,
            unit: 'kg',
            unitPrice: 28.00,
            totalCost: 560.00,
            quality: 'Good',
            verifiedQuantity: 20,
            verifiedQuality: 'Good',
          ),
          MarketPurchaseItem(
            id: 5,
            productCode: 'LET001',
            description: 'LETTUCE',
            category: 'Vegetables',
            quantity: 15,
            unit: 'heads',
            unitPrice: 12.00,
            totalCost: 180.00,
            quality: 'Fresh',
            verifiedQuantity: 15,
            verifiedQuality: 'Fresh',
          ),
        ],
      ),
      
      // Previous procurement - Friday
      MarketProcurement(
        id: 2,
        purchaseDate: now.subtract(const Duration(days: 5)),
        marketName: 'Tshwane Fresh Produce Market',
        receiptNumber: 'TSH001189',
        totalAmount: 2856.75,
        vatAmount: 372.38,
        subtotal: 2484.37,
        status: ProcurementStatus.completed,
        notes: 'Weekly fruit and herb restock',
        stockTakeDate: now.subtract(const Duration(days: 5, hours: 1)),
        stockTakeNotes: 'All items verified. Excellent quality.',
        items: [
          MarketPurchaseItem(
            id: 6,
            productCode: 'APP001',
            description: 'APPLES GOLDEN DELICIOUS',
            category: 'Fruits',
            quantity: 20,
            unit: 'kg',
            unitPrice: 45.00,
            totalCost: 900.00,
            quality: 'Premium',
            verifiedQuantity: 20,
            verifiedQuality: 'Premium',
          ),
          MarketPurchaseItem(
            id: 7,
            productCode: 'BAN001',
            description: 'BANANAS',
            category: 'Fruits',
            quantity: 15,
            unit: 'kg',
            unitPrice: 25.00,
            totalCost: 375.00,
            quality: 'Good',
            verifiedQuantity: 15,
            verifiedQuality: 'Good',
          ),
          MarketPurchaseItem(
            id: 8,
            productCode: 'HER001',
            description: 'HERBS MIXED',
            category: 'Herbs',
            quantity: 10,
            unit: 'bunches',
            unitPrice: 15.00,
            totalCost: 150.00,
            quality: 'Fresh',
            verifiedQuantity: 10,
            verifiedQuality: 'Fresh',
          ),
          MarketPurchaseItem(
            id: 9,
            productCode: 'SPI001',
            description: 'SPINACH',
            category: 'Vegetables',
            quantity: 12,
            unit: 'bunches',
            unitPrice: 8.00,
            totalCost: 96.00,
            quality: 'Fresh',
            verifiedQuantity: 12,
            verifiedQuality: 'Fresh',
          ),
          MarketPurchaseItem(
            id: 10,
            productCode: 'CAB001',
            description: 'CABBAGE',
            category: 'Vegetables',
            quantity: 18,
            unit: 'heads',
            unitPrice: 22.00,
            totalCost: 396.00,
            quality: 'Good',
            verifiedQuantity: 18,
            verifiedQuality: 'Good',
          ),
        ],
      ),
      
      // Older procurement - Monday
      MarketProcurement(
        id: 3,
        purchaseDate: now.subtract(const Duration(days: 8)),
        marketName: 'Tshwane Fresh Produce Market',
        receiptNumber: 'TSH001156',
        totalAmount: 4125.80,
        vatAmount: 537.75,
        subtotal: 3588.05,
        status: ProcurementStatus.completed,
        notes: 'Large weekly restock - all categories',
        stockTakeDate: now.subtract(const Duration(days: 8, hours: 1)),
        stockTakeNotes: 'Full inventory verified. Minor wastage on leafy greens.',
        items: [
          MarketPurchaseItem(
            id: 11,
            productCode: 'POT002',
            description: 'POTATOES BABY',
            category: 'Vegetables',
            quantity: 40,
            unit: 'kg',
            unitPrice: 32.00,
            totalCost: 1280.00,
            quality: 'Premium',
            verifiedQuantity: 40,
            verifiedQuality: 'Premium',
          ),
          MarketPurchaseItem(
            id: 12,
            productCode: 'PEP001',
            description: 'PEPPERS MIXED',
            category: 'Vegetables',
            quantity: 25,
            unit: 'kg',
            unitPrice: 55.00,
            totalCost: 1375.00,
            quality: 'Good',
            verifiedQuantity: 24,
            verifiedQuality: 'Good',
            wastage: 1.0,
          ),
          MarketPurchaseItem(
            id: 13,
            productCode: 'CUC001',
            description: 'CUCUMBERS',
            category: 'Vegetables',
            quantity: 30,
            unit: 'kg',
            unitPrice: 28.00,
            totalCost: 840.00,
            quality: 'Fresh',
            verifiedQuantity: 30,
            verifiedQuality: 'Fresh',
          ),
          MarketPurchaseItem(
            id: 14,
            productCode: 'BRO001',
            description: 'BROCCOLI',
            category: 'Vegetables',
            quantity: 15,
            unit: 'heads',
            unitPrice: 18.00,
            totalCost: 270.00,
            quality: 'Fresh',
            verifiedQuantity: 14,
            verifiedQuality: 'Fresh',
            wastage: 1.0,
          ),
        ],
      ),
    ];
  }

  // Calculate analytics from procurements
  MarketAnalytics _calculateAnalytics(List<MarketProcurement> procurements) {
    if (procurements.isEmpty) {
      return const MarketAnalytics(
        totalSpent: 0,
        totalTrips: 0,
        averageSpendPerTrip: 0,
        categorySpending: {},
        categoryQuantities: {},
        totalWastage: 0,
        averageMarkup: 0,
      );
    }

    final totalSpent = procurements.fold<double>(
        0.0, (sum, p) => sum + p.totalAmount);
    
    final totalTrips = procurements.length;
    final averageSpendPerTrip = totalSpent / totalTrips;

    // Category analysis
    final categorySpending = <String, double>{};
    final categoryQuantities = <String, int>{};
    double totalWastage = 0.0;
    int totalItems = 0;
    double totalMarkup = 0.0;

    for (final procurement in procurements) {
      for (final item in procurement.items) {
        categorySpending[item.category] = 
            (categorySpending[item.category] ?? 0.0) + item.totalCost;
        categoryQuantities[item.category] = 
            (categoryQuantities[item.category] ?? 0) + item.quantity;
        
        if (item.wastage != null) {
          totalWastage += item.wastagePercentage;
          totalItems++;
        }
        
        // Calculate markup (retail potential vs wholesale cost)
        final markup = ((item.estimatedRetailValue - item.totalCost) / item.totalCost) * 100;
        totalMarkup += markup;
      }
    }

    final averageWastage = totalItems > 0 ? totalWastage / totalItems : 0.0;
    final averageMarkup = procurements.fold<int>(0, (sum, p) => sum + p.items.length) > 0 
        ? totalMarkup / procurements.fold<int>(0, (sum, p) => sum + p.items.length)
        : 0.0;

    return MarketAnalytics(
      totalSpent: totalSpent,
      totalTrips: totalTrips,
      averageSpendPerTrip: averageSpendPerTrip,
      categorySpending: categorySpending,
      categoryQuantities: categoryQuantities,
      totalWastage: averageWastage,
      averageMarkup: averageMarkup,
    );
  }

  // Search procurements
  void searchProcurements(String query) {
    state = state.copyWith(searchQuery: query);
    _applyFilters();
  }

  // Filter by status
  void filterByStatus(ProcurementStatus? status) {
    state = state.copyWith(selectedStatus: status);
    _applyFilters();
  }

  // Apply filters
  void _applyFilters() {
    var filtered = state.procurements;

    // Apply status filter
    if (state.selectedStatus != null) {
      filtered = filtered.where((p) => p.status == state.selectedStatus).toList();
    }

    // Apply search filter
    if (state.searchQuery.isNotEmpty) {
      final query = state.searchQuery.toLowerCase();
      filtered = filtered.where((p) =>
          p.receiptNumber.toLowerCase().contains(query) ||
          p.marketName.toLowerCase().contains(query) ||
          p.items.any((item) => 
              item.description.toLowerCase().contains(query) ||
              item.category.toLowerCase().contains(query))
      ).toList();
    }

    // Sort by date (newest first)
    filtered.sort((a, b) => b.purchaseDate.compareTo(a.purchaseDate));

    state = state.copyWith(filteredProcurements: filtered);
  }

  // Refresh procurements
  Future<void> refresh() async {
    await loadProcurements();
  }

  // Clear filters
  void clearAllFilters() {
    state = state.copyWith(
      searchQuery: '',
      selectedStatus: null,
    );
    _applyFilters();
  }

  // Get procurement by ID
  MarketProcurement? getProcurementById(int id) {
    try {
      return state.procurements.firstWhere((p) => p.id == id);
    } catch (e) {
      return null;
    }
  }

  // Get recent procurements (last 7 days)
  List<MarketProcurement> getRecentProcurements() {
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    return state.procurements
        .where((p) => p.purchaseDate.isAfter(weekAgo))
        .toList();
  }

  // Get procurements needing stock take
  List<MarketProcurement> getProcurementsNeedingStockTake() {
    return state.procurements
        .where((p) => p.needsStockTake)
        .toList();
  }
}

// Provider for market procurements
final marketProcurementProvider = StateNotifierProvider<MarketProcurementNotifier, MarketProcurementState>((ref) {
  return MarketProcurementNotifier();
});

// Convenience providers
final marketProcurementsListProvider = Provider<List<MarketProcurement>>((ref) {
  return ref.watch(marketProcurementProvider).filteredProcurements;
});

final marketAnalyticsProvider = Provider<MarketAnalytics?>((ref) {
  return ref.watch(marketProcurementProvider).analytics;
});

final recentProcurementsProvider = Provider<List<MarketProcurement>>((ref) {
  return ref.read(marketProcurementProvider.notifier).getRecentProcurements();
});

final procurementsNeedingStockTakeProvider = Provider<List<MarketProcurement>>((ref) {
  return ref.read(marketProcurementProvider.notifier).getProcurementsNeedingStockTake();
});


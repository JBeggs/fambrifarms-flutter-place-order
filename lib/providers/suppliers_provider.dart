import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:state_notifier/state_notifier.dart';
import '../models/supplier.dart';
import '../services/api_service.dart';

// Suppliers state
class SuppliersState {
  final List<Supplier> suppliers;
  final List<Supplier> filteredSuppliers;
  final bool isLoading;
  final String? error;
  final String searchQuery;
  final SupplierType selectedType;

  const SuppliersState({
    this.suppliers = const [],
    this.filteredSuppliers = const [],
    this.isLoading = false,
    this.error,
    this.searchQuery = '',
    this.selectedType = SupplierType.all,
  });

  SuppliersState copyWith({
    List<Supplier>? suppliers,
    List<Supplier>? filteredSuppliers,
    bool? isLoading,
    String? error,
    String? searchQuery,
    SupplierType? selectedType,
  }) {
    return SuppliersState(
      suppliers: suppliers ?? this.suppliers,
      filteredSuppliers: filteredSuppliers ?? this.filteredSuppliers,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedType: selectedType ?? this.selectedType,
    );
  }
}

// Suppliers provider
class SuppliersNotifier extends StateNotifier<SuppliersState> {
  final ApiService _apiService;

  SuppliersNotifier(this._apiService) : super(const SuppliersState()) {
    loadSuppliers();
  }

  // Load all suppliers (frontend pagination approach)
  Future<void> loadSuppliers() async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      
      final suppliersData = await _apiService.getSuppliers();
      final suppliers = suppliersData.map((data) => Supplier.fromJson(data)).toList();
      
      state = state.copyWith(
        suppliers: suppliers,
        filteredSuppliers: suppliers,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load suppliers: ${e.toString()}',
      );
    }
  }

  // Search suppliers (client-side filtering)
  void searchSuppliers(String query) {
    state = state.copyWith(searchQuery: query);
    _applyFilters();
  }

  // Filter by supplier type
  void filterByType(SupplierType type) {
    state = state.copyWith(selectedType: type);
    _applyFilters();
  }

  // Apply search and type filters
  void _applyFilters() {
    var filtered = state.suppliers;

    // Apply type filter
    if (state.selectedType != SupplierType.all) {
      String filterType;
      switch (state.selectedType) {
        case SupplierType.internal:
          filterType = 'internal';
          break;
        case SupplierType.external:
          filterType = 'external';
          break;
        default:
          filterType = '';
      }
      
      if (filterType.isNotEmpty) {
        filtered = filtered.where((supplier) => 
            supplier.supplierType.toLowerCase() == filterType.toLowerCase()
        ).toList();
      }
    }

    // Apply search filter
    if (state.searchQuery.isNotEmpty) {
      filtered = filtered.where((supplier) => 
          supplier.matchesSearch(state.searchQuery)
      ).toList();
    }

    // Sort by name for consistent display
    filtered.sort((a, b) => a.name.compareTo(b.name));

    state = state.copyWith(filteredSuppliers: filtered);
  }

  // Refresh suppliers
  Future<void> refresh() async {
    await loadSuppliers();
  }

  // Clear search
  void clearSearch() {
    state = state.copyWith(searchQuery: '');
    _applyFilters();
  }

  // Clear all filters
  void clearAllFilters() {
    state = state.copyWith(
      searchQuery: '',
      selectedType: SupplierType.all,
    );
    _applyFilters();
  }

  // Clear error
  void clearError() {
    if (state.error != null) {
      state = state.copyWith(error: null);
    }
  }

  // Get supplier by ID
  Supplier? getSupplierById(int id) {
    try {
      return state.suppliers.firstWhere((supplier) => supplier.id == id);
    } catch (e) {
      return null;
    }
  }

  // Get suppliers by type
  List<Supplier> getSuppliersByType(String type) {
    return state.suppliers.where((supplier) => 
        supplier.supplierType.toLowerCase() == type.toLowerCase()).toList();
  }

  // CRUD Operations
  Future<bool> createSupplier(Map<String, dynamic> supplierData) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final newSupplierData = await _apiService.createSupplier(supplierData);
      final newSupplier = Supplier.fromJson(newSupplierData);
      
      final updatedSuppliers = [...state.suppliers, newSupplier];
      state = state.copyWith(
        suppliers: updatedSuppliers,
        isLoading: false,
      );
      
      _applyFilters(); // Reapply filters to include new supplier
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to create supplier: ${e.toString()}',
      );
      return false;
    }
  }

  Future<bool> updateSupplier(int supplierId, Map<String, dynamic> supplierData) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final updatedSupplierData = await _apiService.updateSupplier(supplierId, supplierData);
      final updatedSupplier = Supplier.fromJson(updatedSupplierData);
      
      final updatedSuppliers = state.suppliers.map((supplier) {
        if (supplier.id == supplierId) {
          return updatedSupplier;
        }
        return supplier;
      }).toList();
      
      state = state.copyWith(
        suppliers: updatedSuppliers,
        isLoading: false,
      );
      
      _applyFilters(); // Reapply filters with updated data
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to update supplier: ${e.toString()}',
      );
      return false;
    }
  }

  Future<bool> deleteSupplier(int supplierId) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      await _apiService.deleteSupplier(supplierId);
      
      final updatedSuppliers = state.suppliers.where((supplier) => supplier.id != supplierId).toList();
      state = state.copyWith(
        suppliers: updatedSuppliers,
        isLoading: false,
      );
      
      _applyFilters(); // Reapply filters with updated data
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to delete supplier: ${e.toString()}',
      );
      return false;
    }
  }

  Future<Map<String, dynamic>?> getSupplierDetails(int supplierId) async {
    try {
      return await _apiService.getSupplier(supplierId);
    } catch (e) {
      state = state.copyWith(error: 'Failed to get supplier details: ${e.toString()}');
      return null;
    }
  }

  // Get active suppliers
  List<Supplier> getActiveSuppliers() {
    return state.suppliers.where((supplier) => supplier.isActive).toList();
  }

  // Get recent suppliers
  List<Supplier> getRecentSuppliers() {
    return state.suppliers.where((supplier) => supplier.isRecentSupplier).toList();
  }

  // Get supplier statistics
  Map<String, dynamic> getSupplierStats() {
    final suppliers = state.suppliers;
    final activeSuppliers = suppliers.where((s) => s.isActive).length;
    final recentSuppliers = suppliers.where((s) => s.isRecentSupplier).length;
    final totalOrderValue = suppliers.fold<double>(
        0.0, (sum, supplier) => sum + supplier.totalOrderValue);
    
    final typeBreakdown = <String, int>{};
    for (final supplier in suppliers) {
      typeBreakdown[supplier.supplierType] = 
          (typeBreakdown[supplier.supplierType] ?? 0) + 1;
    }

    final totalSalesReps = suppliers.fold<int>(
        0, (sum, supplier) => sum + supplier.salesReps.length);

    final averageOrderValue = suppliers.isNotEmpty 
        ? totalOrderValue / suppliers.length
        : 0.0;

    return {
      'total': suppliers.length,
      'active': activeSuppliers,
      'recent': recentSuppliers,
      'total_value': totalOrderValue,
      'average_order_value': averageOrderValue,
      'type_breakdown': typeBreakdown,
      'total_sales_reps': totalSalesReps,
    };
  }
}

// Provider for suppliers
final suppliersProvider = StateNotifierProvider<SuppliersNotifier, SuppliersState>((ref) {
  final apiService = ref.read(apiServiceProvider);
  return SuppliersNotifier(apiService);
});

// Convenience providers
final suppliersListProvider = Provider<List<Supplier>>((ref) {
  return ref.watch(suppliersProvider).filteredSuppliers;
});

final suppliersLoadingProvider = Provider<bool>((ref) {
  return ref.watch(suppliersProvider).isLoading;
});

final suppliersErrorProvider = Provider<String?>((ref) {
  return ref.watch(suppliersProvider).error;
});

final suppliersStatsProvider = Provider<Map<String, dynamic>>((ref) {
  return ref.read(suppliersProvider.notifier).getSupplierStats();
});

final activeSuppliersProvider = Provider<List<Supplier>>((ref) {
  return ref.read(suppliersProvider.notifier).getActiveSuppliers();
});

final recentSuppliersProvider = Provider<List<Supplier>>((ref) {
  return ref.read(suppliersProvider.notifier).getRecentSuppliers();
});

// Provider for specific supplier
final supplierProvider = Provider.family<Supplier?, int>((ref, supplierId) {
  return ref.read(suppliersProvider.notifier).getSupplierById(supplierId);
});


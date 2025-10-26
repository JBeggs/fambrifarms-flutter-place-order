import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:state_notifier/state_notifier.dart';
import '../models/product.dart';
import '../services/api_service.dart';

// Products state
class ProductsState {
  final List<Product> products;
  final List<Product> filteredProducts;
  final bool isLoading;
  final String? error;
  final String searchQuery;
  final ProductDepartment selectedDepartment;
  final StockStatus selectedStockStatus;

  const ProductsState({
    this.products = const [],
    this.filteredProducts = const [],
    this.isLoading = false,
    this.error,
    this.searchQuery = '',
    this.selectedDepartment = ProductDepartment.all,
    this.selectedStockStatus = StockStatus.all,
  });

  ProductsState copyWith({
    List<Product>? products,
    List<Product>? filteredProducts,
    bool? isLoading,
    String? error,
    String? searchQuery,
    ProductDepartment? selectedDepartment,
    StockStatus? selectedStockStatus,
  }) {
    return ProductsState(
      products: products ?? this.products,
      filteredProducts: filteredProducts ?? this.filteredProducts,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedDepartment: selectedDepartment ?? this.selectedDepartment,
      selectedStockStatus: selectedStockStatus ?? this.selectedStockStatus,
    );
  }
}

// Products provider
class ProductsNotifier extends StateNotifier<ProductsState> {
  final ApiService _apiService;

  ProductsNotifier(this._apiService) : super(const ProductsState()) {
    loadProducts();
  }

  // Load all products (frontend pagination approach)
  Future<void> loadProducts() async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      
      final products = await _apiService.getProducts();
      
      state = state.copyWith(
        products: products.cast<Product>(),
        filteredProducts: products.cast<Product>(),
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load products: ${e.toString()}',
      );
    }
  }

  // Search products (client-side filtering)
  void searchProducts(String query) {
    state = state.copyWith(searchQuery: query);
    _applyFilters();
  }

  // Filter by department
  void filterByDepartment(ProductDepartment department) {
    state = state.copyWith(selectedDepartment: department);
    _applyFilters();
  }

  // Filter by stock status
  void filterByStockStatus(StockStatus stockStatus) {
    state = state.copyWith(selectedStockStatus: stockStatus);
    _applyFilters();
  }

  // Apply all filters
  void _applyFilters() {
    var filtered = state.products;

    // Apply department filter
    if (state.selectedDepartment != ProductDepartment.all) {
      final departmentName = state.selectedDepartment.displayName;
      filtered = filtered.where((product) => 
          product.department.toLowerCase().contains(departmentName.toLowerCase()) ||
          departmentName.toLowerCase().contains(product.department.toLowerCase())
      ).toList();
    }

    // Apply stock status filter
    if (state.selectedStockStatus != StockStatus.all) {
      switch (state.selectedStockStatus) {
        case StockStatus.inStock:
          filtered = filtered.where((product) => product.isInStock).toList();
          break;
        case StockStatus.lowStock:
          filtered = filtered.where((product) => product.isLowStock).toList();
          break;
        case StockStatus.outOfStock:
          filtered = filtered.where((product) => product.isOutOfStock).toList();
          break;
        case StockStatus.all:
          break;
      }
    }

    // Apply search filter
    if (state.searchQuery.isNotEmpty) {
      filtered = filtered.where((product) => 
          product.matchesSearch(state.searchQuery)
      ).toList();
    }

    // Sort by name for consistent display
    filtered.sort((a, b) => a.name.compareTo(b.name));

    state = state.copyWith(filteredProducts: filtered);
  }

  // Refresh products
  Future<void> refresh() async {
    await loadProducts();
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
      selectedDepartment: ProductDepartment.all,
      selectedStockStatus: StockStatus.all,
    );
    _applyFilters();
  }

  // Clear error
  void clearError() {
    if (state.error != null) {
      state = state.copyWith(error: null);
    }
  }

  // Get product by ID
  Product? getProductById(int id) {
    try {
      return state.products.firstWhere((product) => product.id == id);
    } catch (e) {
      return null;
    }
  }

  // Get products by department
  List<Product> getProductsByDepartment(String department) {
    return state.products.where((product) => 
        product.department.toLowerCase() == department.toLowerCase()).toList();
  }

  // Get low stock products
  List<Product> getLowStockProducts() {
    return state.products.where((product) => product.isLowStock).toList();
  }

  // Get out of stock products
  List<Product> getOutOfStockProducts() {
    return state.products.where((product) => product.isOutOfStock).toList();
  }

  // Get product statistics
  Map<String, dynamic> getProductStats() {
    final products = state.products;
    final activeProducts = products.where((p) => p.isActive).length;
    final inStockProducts = products.where((p) => p.isInStock).length;
    final lowStockProducts = products.where((p) => p.isLowStock).length;
    final outOfStockProducts = products.where((p) => p.isOutOfStock).length;
    
    final departmentBreakdown = <String, int>{};
    for (final product in products) {
      departmentBreakdown[product.department] = 
          (departmentBreakdown[product.department] ?? 0) + 1;
    }

    final averagePrice = products.isNotEmpty 
        ? products.fold<double>(0.0, (sum, product) => sum + product.price) / products.length
        : 0.0;

    return {
      'total': products.length,
      'active': activeProducts,
      'in_stock': inStockProducts,
      'low_stock': lowStockProducts,
      'out_of_stock': outOfStockProducts,
      'department_breakdown': departmentBreakdown,
      'average_price': averagePrice,
    };
  }
}

// Provider for products
final productsProvider = StateNotifierProvider<ProductsNotifier, ProductsState>((ref) {
  final apiService = ref.read(apiServiceProvider);
  return ProductsNotifier(apiService);
});

// Convenience providers
final productsListProvider = Provider<List<Product>>((ref) {
  return ref.watch(productsProvider).filteredProducts;
});

final productsLoadingProvider = Provider<bool>((ref) {
  return ref.watch(productsProvider).isLoading;
});

final productsErrorProvider = Provider<String?>((ref) {
  return ref.watch(productsProvider).error;
});

final productsStatsProvider = Provider<Map<String, dynamic>>((ref) {
  ref.watch(productsProvider); // Watch state changes
  return ref.read(productsProvider.notifier).getProductStats();
});

final lowStockProductsProvider = Provider<List<Product>>((ref) {
  ref.watch(productsProvider); // Watch state changes
  return ref.read(productsProvider.notifier).getLowStockProducts();
});

final outOfStockProductsProvider = Provider<List<Product>>((ref) {
  ref.watch(productsProvider); // Watch state changes
  return ref.read(productsProvider.notifier).getOutOfStockProducts();
});

// Provider for specific product
final productProvider = Provider.family<Product?, int>((ref, productId) {
  return ref.read(productsProvider.notifier).getProductById(productId);
});


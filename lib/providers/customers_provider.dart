import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:state_notifier/state_notifier.dart';
import '../models/customer.dart';
import '../services/api_service.dart';

// Customer state
class CustomersState {
  final List<Customer> customers;
  final List<Customer> filteredCustomers;
  final bool isLoading;
  final String? error;
  final String searchQuery;
  final String selectedType;

  const CustomersState({
    this.customers = const [],
    this.filteredCustomers = const [],
    this.isLoading = false,
    this.error,
    this.searchQuery = '',
    this.selectedType = 'all',
  });

  CustomersState copyWith({
    List<Customer>? customers,
    List<Customer>? filteredCustomers,
    bool? isLoading,
    String? error,
    String? searchQuery,
    String? selectedType,
  }) {
    return CustomersState(
      customers: customers ?? this.customers,
      filteredCustomers: filteredCustomers ?? this.filteredCustomers,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedType: selectedType ?? this.selectedType,
    );
  }
}

// Customers provider
class CustomersNotifier extends StateNotifier<CustomersState> {
  final ApiService _apiService;

  CustomersNotifier(this._apiService) : super(const CustomersState()) {
    loadCustomers();
  }

  // Load all customers (frontend pagination approach)
  Future<void> loadCustomers() async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      
      final customers = await _apiService.getCustomers();
      
      state = state.copyWith(
        customers: customers.cast<Customer>(),
        filteredCustomers: customers.cast<Customer>(),
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load customers: ${e.toString()}',
      );
    }
  }

  // Search customers (client-side filtering)
  void searchCustomers(String query) {
    state = state.copyWith(searchQuery: query);
    _applyFilters();
  }

  // Filter by customer type
  void filterByType(String type) {
    state = state.copyWith(selectedType: type);
    _applyFilters();
  }

  // Apply search and type filters
  void _applyFilters() {
    var filtered = state.customers;

    // Apply type filter
    if (state.selectedType != 'all') {
      filtered = filtered.where((customer) => 
          customer.customerType == state.selectedType).toList();
    }

    // Apply search filter
    if (state.searchQuery.isNotEmpty) {
      final query = state.searchQuery.toLowerCase();
      filtered = filtered.where((customer) =>
          customer.name.toLowerCase().contains(query) ||
          customer.email.toLowerCase().contains(query) ||
          customer.phone.contains(query) ||
          (customer.profile?.businessName?.toLowerCase().contains(query) ?? false)
      ).toList();
    }

    state = state.copyWith(filteredCustomers: filtered);
  }

  // Refresh customers
  Future<void> refresh() async {
    await loadCustomers();
  }

  // Clear search
  void clearSearch() {
    state = state.copyWith(searchQuery: '');
    _applyFilters();
  }

  // Clear error
  void clearError() {
    if (state.error != null) {
      state = state.copyWith(error: null);
    }
  }

  // Get customer by ID
  Customer? getCustomerById(int id) {
    try {
      return state.customers.firstWhere((customer) => customer.id == id);
    } catch (e) {
      return null;
    }
  }

  // Get customers by type
  List<Customer> getCustomersByType(String type) {
    return state.customers.where((customer) => 
        customer.customerType == type).toList();
  }

  // Add new customer
  Future<void> addCustomer(Map<String, dynamic> customerData) async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      
      final newCustomer = await _apiService.createCustomer(customerData);
      
      // Add to the customers list
      final updatedCustomers = [...state.customers, newCustomer];
      state = state.copyWith(
        customers: updatedCustomers,
        isLoading: false,
      );
      
      // Reapply filters to include the new customer
      _applyFilters();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to add customer: $e',
      );
      rethrow;
    }
  }

  // Update existing customer
  Future<void> updateCustomer(int customerId, Map<String, dynamic> customerData) async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      
      final updatedCustomer = await _apiService.updateCustomer(customerId, customerData);
      
      // Update in the customers list
      final updatedCustomers = state.customers.map((customer) {
        return customer.id == customerId ? updatedCustomer : customer;
      }).toList();
      
      state = state.copyWith(
        customers: updatedCustomers,
        isLoading: false,
      );
      
      // Reapply filters
      _applyFilters();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to update customer: $e',
      );
      rethrow;
    }
  }

  // Get customer statistics
  Map<String, dynamic> getCustomerStats() {
    final customers = state.customers;
    final activeCustomers = customers.where((c) => c.isActive).length;
    final recentCustomers = customers.where((c) => c.isRecentCustomer).length;
    final totalOrderValue = customers.fold<double>(
        0.0, (sum, customer) => sum + customer.totalOrderValue);
    
    final typeBreakdown = <String, int>{};
    for (final customer in customers) {
      typeBreakdown[customer.customerType] = 
          (typeBreakdown[customer.customerType] ?? 0) + 1;
    }

    return {
      'total': customers.length,
      'active': activeCustomers,
      'recent': recentCustomers,
      'total_value': totalOrderValue,
      'type_breakdown': typeBreakdown,
    };
  }
}

// Provider for customers
final customersProvider = StateNotifierProvider<CustomersNotifier, CustomersState>((ref) {
  final apiService = ref.read(apiServiceProvider);
  return CustomersNotifier(apiService);
});

// Convenience providers
final customersListProvider = Provider<List<Customer>>((ref) {
  return ref.watch(customersProvider).filteredCustomers;
});

final customersLoadingProvider = Provider<bool>((ref) {
  return ref.watch(customersProvider).isLoading;
});

final customersErrorProvider = Provider<String?>((ref) {
  return ref.watch(customersProvider).error;
});

final customersStatsProvider = Provider<Map<String, dynamic>>((ref) {
  return ref.read(customersProvider.notifier).getCustomerStats();
});

// Provider for specific customer
final customerProvider = Provider.family<Customer?, int>((ref, customerId) {
  return ref.read(customersProvider.notifier).getCustomerById(customerId);
});


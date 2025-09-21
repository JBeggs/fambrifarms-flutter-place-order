import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/order.dart';
import '../models/product.dart' as product_model;
import '../services/api_service.dart';
import '../providers/inventory_provider.dart';

class OrdersState {
  final List<Order> orders;
  final bool isLoading;
  final String? error;
  final Order? selectedOrder;

  const OrdersState({
    this.orders = const [],
    this.isLoading = false,
    this.error,
    this.selectedOrder,
  });

  OrdersState copyWith({
    List<Order>? orders,
    bool? isLoading,
    String? error,
    Order? selectedOrder,
  }) {
    return OrdersState(
      orders: orders ?? this.orders,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      selectedOrder: selectedOrder ?? this.selectedOrder,
    );
  }
}

class OrdersNotifier extends StateNotifier<OrdersState> {
  final ApiService _apiService;

  OrdersNotifier(this._apiService) : super(const OrdersState());

  Future<void> loadOrders() async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final orders = await _apiService.getOrders();
      state = state.copyWith(
        orders: orders,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> refreshOrders() async {
    await loadOrders();
  }

  Future<Order?> createOrder(Map<String, dynamic> orderData) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final newOrder = await _apiService.createOrder(orderData);
      
      // Add the new order to the list
      final updatedOrders = [...state.orders, newOrder];
      state = state.copyWith(
        orders: updatedOrders,
        isLoading: false,
        selectedOrder: newOrder,
      );
      
      return newOrder;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return null;
    }
  }

  Future<void> updateOrder(int orderId, Map<String, dynamic> orderData) async {
    try {
      final updatedOrder = await _apiService.updateOrder(orderId, orderData);
      
      // Update the order in the list
      final updatedOrders = state.orders.map((order) {
        if (order.id == orderId) {
          return updatedOrder;
        }
        return order;
      }).toList();
      
      state = state.copyWith(
        orders: updatedOrders,
        selectedOrder: state.selectedOrder?.id == orderId ? updatedOrder : state.selectedOrder,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> updateOrderStatus(int orderId, String status) async {
    try {
      final updatedOrder = await _apiService.updateOrderStatus(orderId, status);
      
      // Update the order in the list
      final updatedOrders = state.orders.map((order) {
        if (order.id == orderId) {
          return updatedOrder;
        }
        return order;
      }).toList();
      
      state = state.copyWith(orders: updatedOrders);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> loadOrderDetails(int orderId) async {
    try {
      final order = await _apiService.getOrder(orderId);
      state = state.copyWith(selectedOrder: order);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  // Order Items Management
  Future<void> addOrderItem(int orderId, Map<String, dynamic> itemData) async {
    try {
      await _apiService.addOrderItem(orderId, itemData);
      // Refresh the order details to get updated items
      await loadOrderDetails(orderId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> updateOrderItem(int orderId, int itemId, Map<String, dynamic> itemData) async {
    try {
      await _apiService.updateOrderItem(orderId, itemId, itemData);
      // Refresh the order details to get updated items
      await loadOrderDetails(orderId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> deleteOrderItem(int orderId, int itemId) async {
    try {
      await _apiService.deleteOrderItem(orderId, itemId);
      // Refresh the order details to get updated items
      await loadOrderDetails(orderId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> deleteOrder(int orderId) async {
    try {
      await _apiService.deleteOrder(orderId);
      
      // Remove the order from the list
      final updatedOrders = state.orders.where((order) => order.id != orderId).toList();
      state = state.copyWith(orders: updatedOrders);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  void selectOrder(Order? order) {
    state = state.copyWith(selectedOrder: order);
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  // Stock-related order methods
  List<OrderItem> getOrderItemsWithStockIssues(Order order, List<product_model.Product> products) {
    final stockIssues = <OrderItem>[];
    
    for (final item in order.items) {
      final product = products.firstWhere(
        (p) => p.id == item.product.id,
        orElse: () => product_model.Product(
          id: item.product.id,
          name: item.product.name,
          department: 'Other', // Default department for fallback products
          price: item.product.price,
          unit: 'each', // Default unit for fallback products
          stockLevel: 0, // Assume no stock if not found
          minimumStock: 0,
        ),
      );
      
      // Check if there's insufficient stock
      if (product.stockLevel < item.quantity) {
        stockIssues.add(item);
      }
    }
    
    return stockIssues;
  }

  double calculateOrderStockImpact(Order order, List<product_model.Product> products) {
    double totalImpact = 0.0;
    
    for (final item in order.items) {
      final product = products.firstWhere(
        (p) => p.id == item.product.id,
        orElse: () => product_model.Product(
          id: item.product.id,
          name: item.product.name,
          department: 'Other', // Default department for fallback products
          price: item.product.price,
          unit: 'each', // Default unit for fallback products
          stockLevel: 0,
          minimumStock: 0,
        ),
      );
      
      // Calculate percentage of stock this order would consume
      if (product.stockLevel > 0) {
        final impactPercentage = (item.quantity / product.stockLevel) * 100;
        totalImpact += impactPercentage;
      }
    }
    
    return totalImpact / order.items.length; // Average impact across all items
  }

  bool canFulfillOrder(Order order, List<product_model.Product> products) {
    for (final item in order.items) {
      final product = products.firstWhere(
        (p) => p.id == item.product.id,
        orElse: () => product_model.Product(
          id: item.product.id,
          name: item.product.name,
          department: 'Other', // Default department for fallback products
          price: item.product.price,
          unit: 'each', // Default unit for fallback products
          stockLevel: 0,
          minimumStock: 0,
        ),
      );
      
      if (product.stockLevel < item.quantity) {
        return false;
      }
    }
    return true;
  }

  Map<String, dynamic> getOrderStockSummary(Order order, List<product_model.Product> products) {
    int itemsWithStock = 0;
    int itemsWithLowStock = 0;
    int itemsOutOfStock = 0;
    double totalStockValue = 0.0;
    
    for (final item in order.items) {
      final product = products.firstWhere(
        (p) => p.id == item.product.id,
        orElse: () => product_model.Product(
          id: item.product.id,
          name: item.product.name,
          department: 'Other', // Default department for fallback products
          price: item.product.price,
          unit: 'each', // Default unit for fallback products
          stockLevel: 0,
          minimumStock: 0,
        ),
      );
      
      totalStockValue += product.stockLevel * product.price;
      
      if (product.stockLevel >= item.quantity) {
        itemsWithStock++;
      } else if (product.stockLevel > 0) {
        itemsWithLowStock++;
      } else {
        itemsOutOfStock++;
      }
    }
    
    return {
      'itemsWithStock': itemsWithStock,
      'itemsWithLowStock': itemsWithLowStock,
      'itemsOutOfStock': itemsOutOfStock,
      'totalItems': order.items.length,
      'totalStockValue': totalStockValue,
      'canFulfill': itemsOutOfStock == 0 && itemsWithLowStock == 0,
      'stockHealthPercentage': (itemsWithStock / order.items.length) * 100,
    };
  }
}

final ordersProvider = StateNotifierProvider<OrdersNotifier, OrdersState>((ref) {
  final apiService = ref.read(apiServiceProvider);
  return OrdersNotifier(apiService);
});

// Stock-based order providers
final ordersWithStockIssuesProvider = Provider<List<Order>>((ref) {
  final orders = ref.watch(ordersProvider).orders;
  final inventory = ref.watch(inventoryProvider);
  final ordersNotifier = ref.read(ordersProvider.notifier);
  
  return orders.where((order) {
    final stockIssues = ordersNotifier.getOrderItemsWithStockIssues(order, inventory.products);
    return stockIssues.isNotEmpty;
  }).toList();
});

final unfulfillableOrdersProvider = Provider<List<Order>>((ref) {
  final orders = ref.watch(ordersProvider).orders;
  final inventory = ref.watch(inventoryProvider);
  final ordersNotifier = ref.read(ordersProvider.notifier);
  
  return orders.where((order) {
    return !ordersNotifier.canFulfillOrder(order, inventory.products);
  }).toList();
});

final orderStockImpactProvider = Provider.family<double, Order>((ref, order) {
  final inventory = ref.watch(inventoryProvider);
  final ordersNotifier = ref.read(ordersProvider.notifier);
  
  return ordersNotifier.calculateOrderStockImpact(order, inventory.products);
});

final orderStockSummaryProvider = Provider.family<Map<String, dynamic>, Order>((ref, order) {
  final inventory = ref.watch(inventoryProvider);
  final ordersNotifier = ref.read(ordersProvider.notifier);
  
  return ordersNotifier.getOrderStockSummary(order, inventory.products);
});

final orderStockHealthProvider = Provider<Map<String, dynamic>>((ref) {
  final orders = ref.watch(ordersProvider).orders;
  final inventory = ref.watch(inventoryProvider);
  final ordersNotifier = ref.read(ordersProvider.notifier);
  
  if (orders.isEmpty) {
    return {
      'totalOrders': 0,
      'fulfillableOrders': 0,
      'ordersWithStockIssues': 0,
      'averageStockImpact': 0.0,
      'orderFulfillmentRate': 100.0,
    };
  }
  
  int fulfillableOrders = 0;
  int ordersWithStockIssues = 0;
  double totalStockImpact = 0.0;
  
  for (final order in orders) {
    if (ordersNotifier.canFulfillOrder(order, inventory.products)) {
      fulfillableOrders++;
    }
    
    final stockIssues = ordersNotifier.getOrderItemsWithStockIssues(order, inventory.products);
    if (stockIssues.isNotEmpty) {
      ordersWithStockIssues++;
    }
    
    totalStockImpact += ordersNotifier.calculateOrderStockImpact(order, inventory.products);
  }
  
  return {
    'totalOrders': orders.length,
    'fulfillableOrders': fulfillableOrders,
    'ordersWithStockIssues': ordersWithStockIssues,
    'averageStockImpact': totalStockImpact / orders.length,
    'orderFulfillmentRate': (fulfillableOrders / orders.length) * 100,
  };
});

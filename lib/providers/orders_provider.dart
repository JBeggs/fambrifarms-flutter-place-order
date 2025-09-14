import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/order.dart';
import '../services/api_service.dart';

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
}

final ordersProvider = StateNotifierProvider<OrdersNotifier, OrdersState>((ref) {
  final apiService = ref.read(apiServiceProvider);
  return OrdersNotifier(apiService);
});

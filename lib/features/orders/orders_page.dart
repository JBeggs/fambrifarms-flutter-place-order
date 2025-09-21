import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/order.dart';
import '../../models/customer.dart';
import '../../providers/orders_provider.dart';
import '../../providers/inventory_provider.dart';
import 'widgets/order_card.dart';
import 'widgets/order_status_chip.dart';
import 'widgets/create_order_dialog.dart';

class OrdersPage extends ConsumerStatefulWidget {
  const OrdersPage({super.key});

  @override
  ConsumerState<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends ConsumerState<OrdersPage> {
  String _selectedStatusFilter = 'all';
  String _selectedStockFilter = 'all'; // New stock filter
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Load orders when page opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(ordersProvider.notifier).loadOrders();
    });
  }

  List<Order> get filteredOrders {
    var orders = ref.watch(ordersProvider).orders;
    final inventory = ref.watch(inventoryProvider);
    final ordersNotifier = ref.read(ordersProvider.notifier);
    
    // Filter by status
    if (_selectedStatusFilter != 'all') {
      orders = orders.where((order) => order.status == _selectedStatusFilter).toList();
    }
    
    // Filter by stock availability
    if (_selectedStockFilter != 'all') {
      orders = orders.where((order) {
        switch (_selectedStockFilter) {
          case 'fulfillable':
            return ordersNotifier.canFulfillOrder(order, inventory.products);
          case 'stock_issues':
            final stockIssues = ordersNotifier.getOrderItemsWithStockIssues(order, inventory.products);
            return stockIssues.isNotEmpty;
          case 'unfulfillable':
            return !ordersNotifier.canFulfillOrder(order, inventory.products);
          default:
            return true;
        }
      }).toList();
    }
    
    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      orders = orders.where((order) {
        return order.orderNumber.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               order.restaurant.displayName.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }
    
    return orders;
  }

  @override
  Widget build(BuildContext context) {
    final ordersState = ref.watch(ordersProvider);
    final ordersNotifier = ref.read(ordersProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Orders'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: ordersNotifier.refreshOrders,
            tooltip: 'Refresh Orders',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filters and Search
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
            ),
            child: Column(
              children: [
                // Search Bar
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search orders by number or customer...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
                
                const SizedBox(height: 12),
                
                // Status Filter
                Row(
                  children: [
                    const Text('Status: '),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildStatusFilterChip('all', 'All'),
                            const SizedBox(width: 8),
                            _buildStatusFilterChip('received', 'Received'),
                            const SizedBox(width: 8),
                            _buildStatusFilterChip('parsed', 'Parsed'),
                            const SizedBox(width: 8),
                            _buildStatusFilterChip('confirmed', 'Confirmed'),
                            const SizedBox(width: 8),
                            _buildStatusFilterChip('po_sent', 'PO Sent'),
                            const SizedBox(width: 8),
                            _buildStatusFilterChip('delivered', 'Delivered'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Stock Filter
                Row(
                  children: [
                    const Text('Stock: '),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildStockFilterChip('all', 'All Orders'),
                            const SizedBox(width: 8),
                            _buildStockFilterChip('fulfillable', 'Fulfillable'),
                            const SizedBox(width: 8),
                            _buildStockFilterChip('stock_issues', 'Stock Issues'),
                            const SizedBox(width: 8),
                            _buildStockFilterChip('unfulfillable', 'Unfulfillable'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Stock Health Summary
                _buildStockHealthSummary(),
              ],
            ),
          ),
          
          // Orders List
          Expanded(
            child: ordersState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : ordersState.error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 64,
                              color: Theme.of(context).colorScheme.error,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Error loading orders',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              ordersState.error!,
                              style: Theme.of(context).textTheme.bodyMedium,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: ordersNotifier.loadOrders,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : filteredOrders.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.shopping_cart_outlined,
                                  size: 64,
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No orders found',
                                  style: Theme.of(context).textTheme.headlineSmall,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Create orders from WhatsApp messages to see them here.',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: () => context.go('/messages'),
                                  child: const Text('Go to Messages'),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: filteredOrders.length,
                            itemBuilder: (context, index) {
                              final order = filteredOrders[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: OrderCard(
                                  order: order,
                                  onTap: () => _showOrderDetails(context, order),
                                  onStatusChanged: (newStatus) {
                                    ordersNotifier.updateOrderStatus(order.id, newStatus);
                                  },
                                  onDelete: () => _confirmDeleteOrder(context, order, ordersNotifier),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateOrderDialog,
        child: const Icon(Icons.add),
        tooltip: 'Create New Order',
      ),
    );
  }

  void _showCreateOrderDialog() {
    showDialog(
      context: context,
      builder: (context) => const CreateOrderDialog(),
    ).then((newOrder) {
      if (newOrder != null) {
        // Refresh the orders list
        ref.read(ordersProvider.notifier).refreshOrders();
      }
    });
  }

  Widget _buildStatusFilterChip(String value, String label) {
    final isSelected = _selectedStatusFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedStatusFilter = value;
        });
      },
    );
  }

  Widget _buildStockFilterChip(String value, String label) {
    final isSelected = _selectedStockFilter == value;
    final ordersWithStockIssues = ref.watch(ordersWithStockIssuesProvider);
    final unfulfillableOrders = ref.watch(unfulfillableOrdersProvider);
    
    // Add count badges for stock filters
    String displayLabel = label;
    Color? badgeColor;
    
    switch (value) {
      case 'stock_issues':
        if (ordersWithStockIssues.isNotEmpty) {
          displayLabel = '$label (${ordersWithStockIssues.length})';
          badgeColor = Colors.orange;
        }
        break;
      case 'unfulfillable':
        if (unfulfillableOrders.isNotEmpty) {
          displayLabel = '$label (${unfulfillableOrders.length})';
          badgeColor = Colors.red;
        }
        break;
    }
    
    return FilterChip(
      label: Text(displayLabel),
      selected: isSelected,
      backgroundColor: badgeColor?.withValues(alpha: 0.1),
      selectedColor: badgeColor?.withValues(alpha: 0.2),
      onSelected: (selected) {
        setState(() {
          _selectedStockFilter = value;
        });
      },
    );
  }

  Widget _buildStockHealthSummary() {
    final orderStockHealth = ref.watch(orderStockHealthProvider);
    final fulfillmentRate = orderStockHealth['orderFulfillmentRate'] as double;
    final ordersWithIssues = orderStockHealth['ordersWithStockIssues'] as int;
    final totalOrders = orderStockHealth['totalOrders'] as int;
    
    if (totalOrders == 0) {
      return const SizedBox.shrink();
    }
    
    Color healthColor;
    IconData healthIcon;
    String healthText;
    
    if (fulfillmentRate >= 90) {
      healthColor = Colors.green;
      healthIcon = Icons.check_circle;
      healthText = 'Excellent';
    } else if (fulfillmentRate >= 70) {
      healthColor = Colors.orange;
      healthIcon = Icons.warning;
      healthText = 'Good';
    } else {
      healthColor = Colors.red;
      healthIcon = Icons.error;
      healthText = 'Needs Attention';
    }
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: healthColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: healthColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(healthIcon, color: healthColor, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Order Stock Health: $healthText',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: healthColor,
                  ),
                ),
                Text(
                  '${fulfillmentRate.toStringAsFixed(1)}% fulfillable • $ordersWithIssues of $totalOrders orders have stock issues',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: healthColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${fulfillmentRate.toStringAsFixed(0)}%',
              style: TextStyle(
                color: healthColor,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showOrderDetails(BuildContext context, Order order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Order ${order.orderNumber}'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Customer Info
              Text(
                'Customer: ${order.restaurant.isRestaurant && order.restaurant.profile?.businessName != null ? order.restaurant.profile!.businessName! : order.restaurant.displayName}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              
              // Dates
              Text('Order Date: ${order.orderDate}'),
              Text('Delivery Date: ${order.deliveryDate}'),
              const SizedBox(height: 8),
              
              // Status
              Row(
                children: [
                  const Text('Status: '),
                  OrderStatusChip(status: order.status),
                ],
              ),
              const SizedBox(height: 16),
              
              // Items
              Text(
                'Items (${order.items.length}):',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: order.items.length,
                  itemBuilder: (context, index) {
                    final item = order.items[index];
                    return ListTile(
                      dense: true,
                      title: Text(item.product.name),
                      subtitle: Text(item.originalText ?? ''),
                      trailing: Text(
                        '${item.displayQuantity} @ R${item.price.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    );
                  },
                ),
              ),
              
              if (order.totalAmount != null) ...[
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total:',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      'R${order.totalAmount!.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteOrder(BuildContext context, Order order, OrdersNotifier notifier) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Order'),
        content: Text(
          'Are you sure you want to delete order ${order.orderNumber}?\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await notifier.deleteOrder(order.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Order ${order.orderNumber} deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete order: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/order.dart';
import '../../providers/orders_provider.dart';
import '../../providers/inventory_provider.dart';
import 'widgets/order_card.dart';
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
                        : Column(
                            children: [
                              // Orders List
                              Expanded(
                                child: ListView.builder(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: filteredOrders.length + (ordersState.hasNextPage ? 1 : 0),
                                  itemBuilder: (context, index) {
                                    // Load more item at the end
                                    if (index == filteredOrders.length) {
                                      return _buildLoadMoreItem(context, ordersNotifier, ordersState);
                                    }
                                    
                                    final order = filteredOrders[index];
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 12),
                                      child: OrderCard(
                                        order: order,
                                        onTap: () => _showOrderDetails(context, order),
                                        onStatusChanged: (newStatus) {
                                          ordersNotifier.updateOrderStatus(order.id, newStatus);
                                        },
                                        onOrderUpdated: () {
                                          // Refresh orders when an order is updated
                                          ordersNotifier.refreshOrders();
                                        },
                                        onOrderDeleted: () {
                                          // Refresh orders when an order is deleted
                                          ordersNotifier.refreshOrders();
                                        },
                                      ),
                                    );
                                  },
                                ),
                              ),
                              
                              // Pagination Info
                              if (ordersState.totalCount > 0)
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                                    border: Border(
                                      top: BorderSide(
                                        color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Showing ${filteredOrders.length} of ${ordersState.totalCount} orders',
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                      if (ordersState.hasNextPage)
                                        Text(
                                          'Page ${ordersState.currentPage}',
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: Theme.of(context).colorScheme.primary,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                            ],
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

  Widget _buildLoadMoreItem(BuildContext context, OrdersNotifier ordersNotifier, OrdersState ordersState) {
    if (ordersState.isLoadingMore) {
      return Container(
        padding: const EdgeInsets.all(24),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ElevatedButton.icon(
          onPressed: () => ordersNotifier.loadMoreOrders(),
          icon: const Icon(Icons.expand_more),
          label: const Text('Load More Orders'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
      ),
    );
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
        title: Text('View Order ${order.orderNumber}'),
        content: SizedBox(
          width: 800, // Much wider for better viewing
          height: 600,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Customer Information
                Card(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Customer Information',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildDetailRow(context, 'Business Name', 
                          order.restaurant.isRestaurant && order.restaurant.profile?.businessName != null 
                            ? order.restaurant.profile!.businessName! 
                            : order.restaurant.displayName),
                        _buildDetailRow(context, 'Contact', order.restaurant.email),
                        if (order.restaurant.phone != null && order.restaurant.phone!.isNotEmpty)
                          _buildDetailRow(context, 'Phone', order.restaurant.phone!),
                        _buildDetailRow(context, 'Customer ID', order.restaurant.id.toString()),
                        if (order.restaurant.customerSegment != null)
                          _buildDetailRow(context, 'Segment', order.restaurant.customerSegment!),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Order Context
                Card(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Order Context',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildDetailRow(context, 'Order Date', order.orderDate),
                        _buildDetailRow(context, 'Delivery Date', order.deliveryDate),
                        _buildDetailRow(context, 'Status', order.statusDisplay),
                        if (order.whatsappMessageId != null)
                          _buildDetailRow(context, 'WhatsApp ID', order.whatsappMessageId!),
                        if (order.parsedByAi == true)
                          _buildDetailRow(context, 'AI Parsed', 'Yes', valueColor: Colors.blue),
                        if (order.subtotal != null)
                          _buildDetailRow(context, 'Subtotal', 'R${order.subtotal!.toStringAsFixed(2)}'),
                        if (order.totalAmount != null)
                          _buildDetailRow(context, 'Total Amount', 'R${order.totalAmount!.toStringAsFixed(2)}'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Original WhatsApp Message
                if (order.originalMessage != null && order.originalMessage!.isNotEmpty) ...[
                  Card(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Original WhatsApp Message',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(8.0),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              order.originalMessage!,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                
                // Order Items with Pricing Details
                Text(
                  'Order Items (${order.items.length}):',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: order.items.length,
                  itemBuilder: (context, index) {
                    final item = order.items[index];
                    return Card(
                      child: ExpansionTile(
                        title: Text(
                          item.product.name,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${item.quantity} ${item.unit} × R${item.price.toStringAsFixed(2)}'),
                            if (item.originalText != null && item.originalText!.isNotEmpty)
                              Text(
                                'Original: "${item.originalText}"',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontStyle: FontStyle.italic,
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                              ),
                          ],
                        ),
                        trailing: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'R${item.totalPrice.toStringAsFixed(2)}',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            if (item.confidenceScore != null)
                              Text(
                                '${(item.confidenceScore! * 100).toInt()}% confidence',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: item.confidenceScore! > 0.8 
                                    ? Colors.green 
                                    : item.confidenceScore! > 0.6 
                                      ? Colors.orange 
                                      : Colors.red,
                                ),
                              ),
                          ],
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Product Details
                                _buildDetailRow(context, 'Product ID', item.product.id.toString()),
                                if (item.product.description != null && item.product.description!.isNotEmpty)
                                  _buildDetailRow(context, 'Description', item.product.description!),
                                if (item.product.department != null)
                                  _buildDetailRow(context, 'Department', item.product.department!.name),
                                
                                const Divider(),
                                
                                // Pricing Details
                                Text(
                                  'Pricing Breakdown',
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _buildDetailRow(context, 'Base Product Price', 'R${item.product.price.toStringAsFixed(2)}'),
                                _buildDetailRow(context, 'Applied Price', 'R${item.price.toStringAsFixed(2)}'),
                                if (item.price != item.product.price)
                                  _buildDetailRow(
                                    context, 
                                    'Price Difference', 
                                    '${item.price > item.product.price ? '+' : ''}R${(item.price - item.product.price).toStringAsFixed(2)}',
                                    valueColor: item.price > item.product.price ? Colors.red : Colors.green,
                                  ),
                                _buildDetailRow(context, 'Quantity', '${item.quantity} ${item.unit}'),
                                _buildDetailRow(context, 'Line Total', 'R${item.totalPrice.toStringAsFixed(2)}'),
                                
                                if (item.notes != null && item.notes!.isNotEmpty) ...[
                                  const Divider(),
                                  _buildDetailRow(context, 'Notes', item.notes!),
                                ],
                                
                                // AI Parsing Details
                                if (item.originalText != null || item.confidenceScore != null || item.manuallyCorrected == true) ...[
                                  const Divider(),
                                  Text(
                                    'AI Parsing Details',
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  if (item.originalText != null)
                                    _buildDetailRow(context, 'Original Text', '"${item.originalText}"'),
                                  if (item.confidenceScore != null)
                                    _buildDetailRow(
                                      context, 
                                      'AI Confidence', 
                                      '${(item.confidenceScore! * 100).toInt()}%',
                                      valueColor: item.confidenceScore! > 0.8 
                                        ? Colors.green 
                                        : item.confidenceScore! > 0.6 
                                          ? Colors.orange 
                                          : Colors.red,
                                    ),
                                  if (item.manuallyCorrected == true)
                                    _buildDetailRow(context, 'Status', 'Manually Corrected', valueColor: Colors.blue),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
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

  Widget _buildDetailRow(BuildContext context, String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: valueColor,
              ),
            ),
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

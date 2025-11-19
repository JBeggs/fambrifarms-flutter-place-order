import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:excel/excel.dart' as excel;
import '../../models/order.dart';
import '../../models/product.dart' as product_model;
import '../../providers/orders_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/products_provider.dart';
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
          // Mark All Confirmed as Delivered button
          IconButton(
            icon: const Icon(Icons.check_circle_outline),
            onPressed: _markAllConfirmedAsDelivered,
            tooltip: 'Mark All Confirmed Orders as Delivered',
          ),
          IconButton(
            icon: const Icon(Icons.table_chart),
            onPressed: () => _generateWorkbook(context, ordersState.orders),
            tooltip: 'Generate Workbook',
          ),
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

  Future<void> _markAllConfirmedAsDelivered() async {
    final ordersNotifier = ref.read(ordersProvider.notifier);
    final confirmedOrders = ref.read(ordersProvider).orders
        .where((order) => order.status == 'confirmed')
        .toList();
    
    if (confirmedOrders.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ℹ️ No confirmed orders to mark as delivered'),
            backgroundColor: Colors.blue,
          ),
        );
      }
      return;
    }
    
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark Orders as Delivered?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('You are about to mark ${confirmedOrders.length} confirmed orders as delivered.'),
            const SizedBox(height: 16),
            const Text(
              'This will:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('✓ Free up reserved stock'),
            const Text('✓ Allow new orders to be taken'),
            const Text('✓ Update order statuses to "delivered"'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Mark as Delivered'),
          ),
        ],
      ),
    );
    
    if (confirmed != true || !mounted) return;
    
    // Show loading indicator
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            const SizedBox(width: 16),
            Text('Marking ${confirmedOrders.length} orders as delivered...'),
          ],
        ),
        duration: const Duration(seconds: 30),
      ),
    );
    
    // Mark each order as delivered
    int successCount = 0;
    int failCount = 0;
    String? lastError;
    
    for (final order in confirmedOrders) {
      try {
        await ordersNotifier.updateOrderStatus(order.id, 'delivered');
        successCount++;
      } catch (e) {
        lastError = e.toString();
        print('[ORDERS] Failed to mark order ${order.orderNumber} as delivered: $e');
        failCount++;
      }
    }
    
    // Refresh orders list
    await ordersNotifier.refreshOrders();
    
    // Show result
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      
      // Check if failed due to permissions (403 error)
      final isPermissionError = failCount > 0 && 
                                 lastError != null && 
                                 lastError.contains('403');
      
      if (isPermissionError) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '🔒 Permission Denied: Your account doesn\'t have permission to mark orders as delivered. Please contact an administrator.',
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 6),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              failCount == 0
                  ? '✅ Successfully marked $successCount orders as delivered!'
                  : '⚠️ Marked $successCount orders as delivered, $failCount failed',
            ),
            backgroundColor: failCount == 0 ? Colors.green : Colors.orange,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
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
                                
                                // Source product info if available
                                if (item.sourceProductName != null && item.sourceQuantity != null) ...[
                                  const Divider(),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.orange[50],
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.orange[200]!),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(Icons.inventory_2, size: 16, color: Colors.orange[700]),
                                            const SizedBox(width: 6),
                                            Text(
                                              'Source Product Reservation',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.orange[700],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        _buildDetailRow(context, 'Source Product', item.sourceProductName!),
                                        _buildDetailRow(context, 'Reserved Quantity', '${item.sourceQuantity}${item.sourceProductUnit ?? ''}'),
                                        _buildDetailRow(context, 'Status', '✅ Reserved'),
                                      ],
                                    ),
                                  ),
                                ],
                                
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

  /// Generate workbook with all received orders
  Future<void> _generateWorkbook(BuildContext context, List<Order> allOrders) async {
    try {
      print('[WORKBOOK] Starting workbook generation for ${allOrders.length} orders');
      
      // Filter for received orders only
      final receivedOrders = allOrders.where((order) => order.status == 'received').toList();
      
      if (receivedOrders.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ No received orders to export'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }
      
      print('[WORKBOOK] Found ${receivedOrders.length} received orders');
      
      // Generate filename with current date
      final now = DateTime.now();
      final dateStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      final timeStr = '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      final filename = 'ReceivedOrders_${dateStr}_$timeStr.xlsx';
      
      // Get Documents directory (cross-platform)
      Directory? documentsDir;
      try {
        if (Platform.isLinux || Platform.isMacOS) {
          final homeDir = Platform.environment['HOME'];
          if (homeDir != null) {
            documentsDir = Directory('$homeDir/Documents');
            if (!documentsDir.existsSync()) {
              documentsDir.createSync(recursive: true);
            }
          }
        } else if (Platform.isWindows) {
          final homeDir = Platform.environment['USERPROFILE'];
          if (homeDir != null) {
            documentsDir = Directory('$homeDir\\Documents');
            if (!documentsDir.existsSync()) {
              documentsDir.createSync(recursive: true);
            }
          }
        }
      } catch (e) {
        print('[WORKBOOK] Error getting documents directory: $e');
        throw Exception('Failed to access Documents directory: $e');
      }
      
      if (documentsDir == null) {
        throw Exception('Could not determine Documents directory path');
      }
      
      final filePath = '${documentsDir.path}/$filename';
      print('[WORKBOOK] Saving to: $filePath');
      
      // Create Excel workbook
      final workbook = excel.Excel.createExcel();
      
      // Get products data for checking unlimited stock
      final productsState = ref.read(productsProvider);
      final products = productsState.products;
      
      // Create a sheet for each order
      for (final order in receivedOrders) {
        // Use business name from profile, fallback to restaurant name
        String businessName = order.restaurant.profile?.businessName ?? order.restaurant.name;
        
        // Use business name as sheet name (sanitize for Excel)
        String sheetName = businessName
            .replaceAll(RegExp(r'[^\w\s-]'), '')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        
        // Excel sheet names must be max 31 chars and unique
        if (sheetName.length > 31) {
          sheetName = sheetName.substring(0, 31);
        }
        
        // Make sure sheet name is unique
        int counter = 1;
        String uniqueSheetName = sheetName;
        while (workbook.sheets.containsKey(uniqueSheetName)) {
          final suffix = '_$counter';
          final maxLength = 31 - suffix.length;
          uniqueSheetName = '${sheetName.substring(0, maxLength < sheetName.length ? maxLength : sheetName.length)}$suffix';
          counter++;
        }
        
        print('[WORKBOOK] Creating sheet: $uniqueSheetName for order ${order.orderNumber}');
        
        final sheet = workbook[uniqueSheetName];
        
        // Add professional header with business name
        sheet.cell(excel.CellIndex.indexByString('A1')).value = excel.TextCellValue(businessName.toUpperCase());
        sheet.cell(excel.CellIndex.indexByString('A1')).cellStyle = excel.CellStyle(
          bold: true,
          fontSize: 18,
        );
        
        // Contact information row
        int currentRow = 2;
        List<String> contactParts = [];
        if (order.restaurant.email.isNotEmpty) {
          contactParts.add('Email: ${order.restaurant.email}');
        }
        if (order.restaurant.phone.isNotEmpty) {
          contactParts.add('Tel: ${order.restaurant.phone}');
        }
        if (contactParts.isNotEmpty) {
          sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).value = excel.TextCellValue(contactParts.join(' | '));
          sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).cellStyle = excel.CellStyle(
            fontSize: 10,
          );
          currentRow++;
        }
        
        // Address information
        if (order.restaurant.profile?.deliveryAddress?.isNotEmpty == true) {
          final addressParts = [order.restaurant.profile!.deliveryAddress!];
          if (order.restaurant.profile?.city?.isNotEmpty == true) {
            addressParts.add(order.restaurant.profile!.city!);
          }
          if (order.restaurant.profile?.postalCode?.isNotEmpty == true) {
            addressParts.add(order.restaurant.profile!.postalCode!);
          }
          sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).value = excel.TextCellValue(addressParts.join(', '));
          sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).cellStyle = excel.CellStyle(
            fontSize: 10,
          );
          currentRow++;
        }
        
        currentRow++; // Add space
        
        // Order details section
        sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).value = excel.TextCellValue('ORDER DETAILS');
        sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).cellStyle = excel.CellStyle(
          bold: true,
          fontSize: 14,
        );
        currentRow += 2;
        
        // Order information
        sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).value = excel.TextCellValue('Order Number:');
        sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).cellStyle = excel.CellStyle(bold: true);
        sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow)).value = excel.TextCellValue(order.orderNumber);
        currentRow++;
        
        sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).value = excel.TextCellValue('Order Date:');
        sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).cellStyle = excel.CellStyle(bold: true);
        sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow)).value = excel.TextCellValue(order.orderDate);
        currentRow++;
        
        sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).value = excel.TextCellValue('Delivery Date:');
        sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).cellStyle = excel.CellStyle(bold: true);
        sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow)).value = excel.TextCellValue(order.deliveryDate);
        currentRow++;
        
        sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).value = excel.TextCellValue('Status:');
        sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).cellStyle = excel.CellStyle(bold: true);
        sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow)).value = excel.TextCellValue(order.status.toUpperCase());
        currentRow += 2;
        
        // Order items table
        sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).value = excel.TextCellValue('ORDER ITEMS');
        sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).cellStyle = excel.CellStyle(
          bold: true,
          fontSize: 14,
        );
        currentRow += 2;
        
        // Table headers - add Errors/Issues column
        final headers = ['Product', 'Quantity', 'Unit', 'Stock Status', 'Errors/Issues', 'Notes'];
        for (int i = 0; i < headers.length; i++) {
          sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: currentRow)).value = excel.TextCellValue(headers[i]);
          sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: currentRow)).cellStyle = excel.CellStyle(
            bold: true,
            horizontalAlign: excel.HorizontalAlign.Center,
          );
        }
        currentRow++;
        
        // Add order items
        for (final item in order.items) {
          // Product name with notes
          String productName = item.product.name;
          if (item.notes?.isNotEmpty == true) {
            productName += ' (${item.notes})';
          }
          
          // Stock status - check if product is always available
          String stockStatus = 'Unknown';
          final product = products.where((p) => p.id == item.product.id).firstOrNull;
          
          if (product?.unlimitedStock == true) {
            stockStatus = '🌱 Always Available';
          } else if (item.isStockReserved) {
            stockStatus = 'Reserved';
          } else if (item.isNoReserve) {
            stockStatus = 'No Reserve';
          } else if (item.isStockReservationFailed) {
            stockStatus = 'Reservation Failed';
          }
          
          // Extract error information from stockResult
          String errorField = '';
          final List<String> errors = [];
          
          // Check for stock reservation failures
          if (item.isStockReservationFailed && item.stockResult != null) {
            final message = item.stockResult!['message'] as String?;
            if (message != null && message.isNotEmpty) {
              errors.add('Stock Reservation Failed: $message');
            } else {
              errors.add('Stock Reservation Failed: Insufficient stock available');
            }
            
            // Check for available stock info
            final availableStock = item.stockResult!['available_stock'];
            if (availableStock != null) {
              errors.add('Available Stock: $availableStock ${item.product.unit}');
            }
            
            // Check for required quantity
            final requiredQuantity = item.stockResult!['required_quantity'];
            if (requiredQuantity != null) {
              errors.add('Required: $requiredQuantity ${item.product.unit}');
            }
          }
          
          // Check for source product issues
          if (item.sourceProductId != null && item.sourceProductName != null) {
            final sourceQty = item.sourceQuantity;
            final sourceStock = item.sourceProductStockLevel;
            if (sourceStock != null && sourceQty != null && sourceQty > 0) {
              if (sourceQty > sourceStock) {
                errors.add('Source Product Insufficient: ${item.sourceProductName} has ${sourceStock}${item.sourceProductUnit ?? ''}, need ${sourceQty}${item.sourceProductUnit ?? ''}');
              }
            }
          }
          
          // Check for no reserve items - use products list to check stock level
          if (item.isNoReserve) {
            final productFromList = products.where((p) => p.id == item.product.id).firstOrNull;
            if (productFromList != null && productFromList.stockLevel <= 0) {
              errors.add('No Stock Available: Product is out of stock and no reservation was made');
            }
          }
          
          errorField = errors.join('\n');
          
          final rowData = [
            excel.TextCellValue(productName),
            excel.DoubleCellValue(item.quantity),
            excel.TextCellValue(item.product.unit),
            excel.TextCellValue(stockStatus),
            excel.TextCellValue(errorField),  // Errors/Issues column
            excel.TextCellValue(item.notes ?? ''),
          ];
          
          for (int i = 0; i < rowData.length; i++) {
            sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: currentRow)).value = rowData[i];
          }
          currentRow++;
        }
        
        // Auto-fit columns
        for (int i = 0; i < headers.length; i++) {
          sheet.setColumnAutoFit(i);
        }
      }
      
      // Add Reserved Stock sheet
      _addReservedStockSheet(workbook, receivedOrders, products);
      
      // Add Stock to be Ordered sheet
      _addStockToOrderSheet(workbook, receivedOrders, products);
      
      // Add Errors sheet (if there are any errors)
      _addErrorsSheet(workbook, receivedOrders, products);
      
      // Remove default Sheet1 AFTER creating all custom sheets
      if (workbook.sheets.containsKey('Sheet1')) {
        workbook.delete('Sheet1');
        print('[WORKBOOK] Removed default Sheet1');
      }
      
      // Save Excel file
      print('[WORKBOOK] Generating Excel bytes...');
      final excelBytes = workbook.save();
      
      if (excelBytes != null) {
        print('[WORKBOOK] Excel bytes generated: ${excelBytes.length} bytes');
        
        final file = File(filePath);
        await file.writeAsBytes(excelBytes);
        
        // Verify file was created
        if (file.existsSync()) {
          final fileSize = file.lengthSync();
          print('[WORKBOOK] ✅ Workbook saved successfully!');
          print('[WORKBOOK] File: $filePath');
          print('[WORKBOOK] Size: $fileSize bytes');
          
          // Show success message
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✅ Workbook saved with ${receivedOrders.length} orders:\n$filePath'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        } else {
          throw Exception('File was not created after write operation');
        }
      } else {
        throw Exception('Failed to generate Excel bytes');
      }
      
    } catch (e) {
      print('[WORKBOOK] Error generating workbook: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error generating workbook: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  /// Add Reserved Stock sheet to workbook
  void _addReservedStockSheet(excel.Excel workbook, List<Order> orders, List<product_model.Product> products) {
    print('[WORKBOOK] Creating Reserved Stock sheet');
    
    final sheet = workbook['Reserved Stock'];
    
    // Sheet title
    sheet.cell(excel.CellIndex.indexByString('A1')).value = excel.TextCellValue('RESERVED STOCK - ALL ORDERS');
    sheet.cell(excel.CellIndex.indexByString('A1')).cellStyle = excel.CellStyle(
      bold: true,
      fontSize: 16,
    );
    
    int currentRow = 3;
    sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).value = excel.TextCellValue('Summary of all reserved stock across all received orders');
    currentRow += 2;
    
    // Table headers
    final headers = ['Order #', 'Business Name', 'Product', 'Ordered Qty', 'Unit', 'Reserved Qty', 'Stock Level', 'Status'];
    for (int i = 0; i < headers.length; i++) {
      sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: currentRow)).value = excel.TextCellValue(headers[i]);
      sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: currentRow)).cellStyle = excel.CellStyle(
        bold: true,
        horizontalAlign: excel.HorizontalAlign.Center,
      );
    }
    currentRow++;
    
    // Collect all reserved stock items from all orders
    List<Map<String, dynamic>> reservedItems = [];
    for (final order in orders) {
      for (final item in order.items.where((item) => item.isStockReserved)) {
        reservedItems.add({
          'order': order,
          'item': item,
        });
      }
    }
    
    // Sort by product name
    reservedItems.sort((a, b) => a['item'].product.name.compareTo(b['item'].product.name));
    
    // Add reserved stock items to sheet
    bool hasReservedItems = reservedItems.isNotEmpty;
    for (final reservedData in reservedItems) {
      final order = reservedData['order'] as Order;
      final item = reservedData['item'] as OrderItem;
      
      // Find corresponding product in products list
      final product = products.firstWhere(
        (p) => p.id == item.product.id,
        orElse: () => product_model.Product(
          id: item.product.id,
          name: item.product.name,
          department: 'Other',
          price: item.product.price,
          unit: item.product.unit,
          stockLevel: 0,
          minimumStock: 0,
        ),
      );
      
      final rowData = [
        excel.TextCellValue(order.orderNumber),
        excel.TextCellValue(order.restaurant.profile?.businessName ?? order.restaurant.name),
        excel.TextCellValue(item.product.name),
        excel.DoubleCellValue(item.quantity),
        excel.TextCellValue(item.product.unit),
        excel.DoubleCellValue(item.quantity), // Assuming full quantity is reserved
        excel.DoubleCellValue(product.stockLevel),
        excel.TextCellValue('✅ Reserved'),
      ];
      
      for (int i = 0; i < rowData.length; i++) {
        sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: currentRow)).value = rowData[i];
      }
      currentRow++;
    }
    
    // If no reserved items, show message
    if (!hasReservedItems) {
      sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).value = excel.TextCellValue('No items have reserved stock across all orders');
      sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).cellStyle = excel.CellStyle(
        italic: true,
      );
    }
    
    // Auto-fit columns
    for (int i = 0; i < headers.length; i++) {
      sheet.setColumnAutoFit(i);
    }
    
    print('[WORKBOOK] Reserved Stock sheet created successfully');
  }

  /// Add Stock to be Ordered sheet to workbook
  void _addStockToOrderSheet(excel.Excel workbook, List<Order> orders, List<product_model.Product> products) {
    print('[WORKBOOK] Creating Stock to Order sheet');
    
    final sheet = workbook['Stock to Order'];
    
    // Sheet title
    sheet.cell(excel.CellIndex.indexByString('A1')).value = excel.TextCellValue('STOCK TO BE ORDERED - ALL ORDERS');
    sheet.cell(excel.CellIndex.indexByString('A1')).cellStyle = excel.CellStyle(
      bold: true,
      fontSize: 16,
    );
    
    int currentRow = 3;
    sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).value = excel.TextCellValue('Items that need to be ordered across all received orders');
    currentRow += 2;
    
    // Table headers
    final headers = ['Order #', 'Business Name', 'Product', 'Ordered Qty', 'Unit', 'Current Stock', 'Shortage', 'Need to Order', 'Status'];
    for (int i = 0; i < headers.length; i++) {
      sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: currentRow)).value = excel.TextCellValue(headers[i]);
      sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: currentRow)).cellStyle = excel.CellStyle(
        bold: true,
        horizontalAlign: excel.HorizontalAlign.Center,
      );
    }
    currentRow++;
    
    // Collect all items that need to be ordered from all orders
    // Only include items with failed reservations or no reserve (excluding unlimited stock products)
    List<Map<String, dynamic>> itemsToOrder = [];
    
    print('[WORKBOOK] Processing ${orders.length} orders for Stock to Order sheet');
    int totalItems = 0;
    int noReserveCount = 0;
    int failedReserveCount = 0;
    int unlimitedStockCount = 0;
    
    for (final order in orders) {
      print('[WORKBOOK] Order ${order.orderNumber}: ${order.items.length} items');
      for (final item in order.items) {
        totalItems++;
        print('[WORKBOOK]   - ${item.product.name}: stockAction=${item.stockAction}, isNoReserve=${item.isNoReserve}, isFailed=${item.isStockReservationFailed}');
        
        // Find corresponding product in products list
        final product = products.firstWhere(
          (p) => p.id == item.product.id,
          orElse: () => product_model.Product(
            id: item.product.id,
            name: item.product.name,
            department: 'Other',
            price: item.product.price,
            unit: item.product.unit,
            stockLevel: 0,
            minimumStock: 0,
          ),
        );
        
        // Skip unlimited stock products (they're always available, no need to order)
        if (product.unlimitedStock) {
          print('[WORKBOOK]     -> Skipping ${item.product.name} (unlimited stock)');
          unlimitedStockCount++;
          continue;
        }
        
        // Check if this item needs to be ordered:
        // 1. Stock reservation failed (out of stock)
        // 2. No reservation was made (intentional no-reserve for bulk items)
        // Also check stockAction directly as fallback
        final isNoReserve = item.isNoReserve || item.stockAction == 'no_reserve';
        final isFailed = item.isStockReservationFailed || 
            (item.stockAction == 'reserve' && item.stockResult != null && 
             !(item.stockResult!['success'] as bool? ?? true));
        final needsOrdering = isFailed || isNoReserve;
        
        if (needsOrdering) {
          if (isNoReserve) noReserveCount++;
          if (isFailed) failedReserveCount++;
          
          final shortage = (item.quantity - product.stockLevel).clamp(0.0, double.infinity).toDouble();
          print('[WORKBOOK]     -> Adding ${item.product.name} to Stock to Order sheet (isNoReserve=$isNoReserve, isFailed=$isFailed, stockAction=${item.stockAction})');
          itemsToOrder.add({
            'order': order,
            'item': item,
            'product': product,
            'shortage': shortage,
          });
        } else {
          print('[WORKBOOK]     -> Skipping ${item.product.name} (stockAction=${item.stockAction}, isNoReserve=${item.isNoReserve}, isFailed=${item.isStockReservationFailed})');
        }
      }
    }
    
    print('[WORKBOOK] Stock to Order summary: Total items=$totalItems, NoReserve=$noReserveCount, Failed=$failedReserveCount, UnlimitedStock=$unlimitedStockCount, ToOrder=${itemsToOrder.length}');
    
    // Sort by product name
    itemsToOrder.sort((a, b) => a['item'].product.name.compareTo(b['item'].product.name));
    
    // Add items to sheet
    bool hasItemsToOrder = itemsToOrder.isNotEmpty;
    for (final orderData in itemsToOrder) {
      final order = orderData['order'] as Order;
      final item = orderData['item'] as OrderItem;
      final product = orderData['product'] as product_model.Product;
      final shortage = orderData['shortage'] as double;
      
      String status = '';
      if (item.isStockReservationFailed) {
        status = '❌ Reservation Failed';
      } else if (item.isNoReserve) {
        status = '🔓 No Reservation';
      } else if (shortage > 0) {
        status = '📦 Insufficient Stock';
      }
      
      final rowData = [
        excel.TextCellValue(order.orderNumber),
        excel.TextCellValue(order.restaurant.profile?.businessName ?? order.restaurant.name),
        excel.TextCellValue(item.product.name),
        excel.DoubleCellValue(item.quantity),
        excel.TextCellValue(item.product.unit),
        excel.DoubleCellValue(product.stockLevel),
        excel.DoubleCellValue(shortage),
        excel.DoubleCellValue(shortage > 0 ? shortage : item.quantity),
        excel.TextCellValue(status),
      ];
      
      for (int i = 0; i < rowData.length; i++) {
        sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: currentRow)).value = rowData[i];
      }
      currentRow++;
    }
    
    // If no items need ordering, show message
    if (!hasItemsToOrder) {
      sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).value = excel.TextCellValue('All items are available in stock across all orders');
      sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).cellStyle = excel.CellStyle(
        italic: true,
      );
    }
    
    // Auto-fit columns
    for (int i = 0; i < headers.length; i++) {
      sheet.setColumnAutoFit(i);
    }
    
    print('[WORKBOOK] Stock to Order sheet created successfully');
  }

  /// Add Errors sheet - lists all items with errors/issues across all orders
  void _addErrorsSheet(excel.Excel workbook, List<Order> orders, List<product_model.Product> products) {
    print('[WORKBOOK] Building Errors sheet');
    
    // Collect all items with errors from all orders
    final List<Map<String, dynamic>> itemsWithErrors = [];
    
    for (final order in orders) {
      for (final item in order.items) {
        // Check for stock reservation failures
        if (item.isStockReservationFailed) {
          itemsWithErrors.add({
            'order': order,
            'item': item,
          });
        }
        // Check for source product issues
        else if (item.sourceProductId != null) {
          final sourceQty = item.sourceQuantity;
          final sourceStock = item.sourceProductStockLevel;
          if (sourceStock != null && sourceQty != null && sourceQty > 0) {
            if (sourceQty > sourceStock) {
              itemsWithErrors.add({
                'order': order,
                'item': item,
              });
            }
          }
        }
        // Check for no reserve items with no stock
        else if (item.isNoReserve) {
          final productFromList = products.where((p) => p.id == item.product.id).firstOrNull;
          if (productFromList != null && productFromList.stockLevel <= 0) {
            itemsWithErrors.add({
              'order': order,
              'item': item,
            });
          }
        }
      }
    }
    
    // If no errors, skip creating the sheet
    if (itemsWithErrors.isEmpty) {
      print('[WORKBOOK] No items with errors - skipping Errors sheet');
      return;
    }
    
    final sheet = workbook['Errors'];
    
    // Sheet title
    sheet.cell(excel.CellIndex.indexByString('A1')).value = excel.TextCellValue('ITEMS WITH ERRORS/ISSUES - ALL ORDERS');
    sheet.cell(excel.CellIndex.indexByString('A1')).cellStyle = excel.CellStyle(
      bold: true,
      fontSize: 16,
    );
    
    // Table headers
    int currentRow = 3;
    final headers = ['Order Number', 'Restaurant', 'Product', 'Quantity', 'Unit', 'Error Type', 'Error Details', 'Action Required'];
    for (int i = 0; i < headers.length; i++) {
      sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: currentRow)).value = excel.TextCellValue(headers[i]);
      sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: currentRow)).cellStyle = excel.CellStyle(
        bold: true,
        horizontalAlign: excel.HorizontalAlign.Center,
      );
    }
    currentRow++;
    
    // Add error items
    for (final errorData in itemsWithErrors) {
      final order = errorData['order'] as Order;
      final item = errorData['item'] as OrderItem;
      
      String errorType = 'Unknown';
      String errorDetails = '';
      String actionRequired = '';
      
      // Determine error type and details
      if (item.isStockReservationFailed && item.stockResult != null) {
        errorType = 'Stock Reservation Failed';
        final message = item.stockResult!['message'] as String?;
        if (message != null && message.isNotEmpty) {
          errorDetails = message;
        } else {
          errorDetails = 'Insufficient stock available';
        }
        
        // Add stock details
        final availableStock = item.stockResult!['available_stock'];
        final requiredQuantity = item.stockResult!['required_quantity'];
        if (availableStock != null || requiredQuantity != null) {
          errorDetails += '\n';
          if (availableStock != null) {
            errorDetails += 'Available: $availableStock ${item.product.unit}\n';
          }
          if (requiredQuantity != null) {
            errorDetails += 'Required: $requiredQuantity ${item.product.unit}';
          }
        }
        
        actionRequired = 'Order stock or find alternative product';
      } else if (item.sourceProductId != null) {
        final sourceQty = item.sourceQuantity;
        final sourceStock = item.sourceProductStockLevel;
        if (sourceStock != null && sourceQty != null && sourceQty > 0) {
          if (sourceQty > sourceStock) {
            errorType = 'Source Product Insufficient';
            errorDetails = 'Source product ${item.sourceProductName} has insufficient stock.\n'
                'Available: ${sourceStock}${item.sourceProductUnit ?? ''}\n'
                'Required: ${sourceQty}${item.sourceProductUnit ?? ''}';
            actionRequired = 'Check source product stock or use different source';
          }
        }
      } else if (item.isNoReserve) {
        final productFromList = products.where((p) => p.id == item.product.id).firstOrNull;
        if (productFromList != null && productFromList.stockLevel <= 0) {
          errorType = 'No Stock Available';
          errorDetails = 'Product is out of stock and no reservation was made.\n'
              'Current Stock: ${productFromList.stockLevel} ${item.product.unit}';
          actionRequired = 'Order stock or confirm customer wants to proceed without stock';
        }
      }
      
      final restaurantName = order.restaurant.profile?.businessName ?? order.restaurant.name;
      
      final rowData = [
        excel.TextCellValue(order.orderNumber),
        excel.TextCellValue(restaurantName),
        excel.TextCellValue(item.product.name),
        excel.DoubleCellValue(item.quantity),
        excel.TextCellValue(item.product.unit ?? ''),
        excel.TextCellValue(errorType),
        excel.TextCellValue(errorDetails),
        excel.TextCellValue(actionRequired),
      ];
      
      for (int i = 0; i < rowData.length; i++) {
        sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: currentRow)).value = rowData[i];
      }
      currentRow++;
    }
    
    // Auto-fit columns
    for (int i = 0; i < headers.length; i++) {
      sheet.setColumnAutoFit(i);
    }
    
    print('[WORKBOOK] Errors sheet built successfully with ${itemsWithErrors.length} items');
  }
}

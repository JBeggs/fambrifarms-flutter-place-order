import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/order.dart';
import '../../providers/orders_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/products_provider.dart';
import 'widgets/mobile_order_card.dart';
import 'widgets/reserved_stock_view.dart';

class MobileOrdersPage extends ConsumerStatefulWidget {
  const MobileOrdersPage({super.key});

  @override
  ConsumerState<MobileOrdersPage> createState() => _MobileOrdersPageState();
}

class _MobileOrdersPageState extends ConsumerState<MobileOrdersPage>
    with SingleTickerProviderStateMixin {
  String _selectedStatusFilter = 'all';
  String _searchQuery = '';
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Load data when page opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(ordersProvider.notifier).loadOrders();
      ref.read(inventoryProvider.notifier).loadStockLevels();
      ref.read(productsProvider.notifier).loadProducts();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Order> get filteredOrders {
    var orders = ref.watch(ordersProvider).orders;
    
    // Filter by status
    if (_selectedStatusFilter != 'all') {
      orders = orders.where((order) => order.status == _selectedStatusFilter).toList();
    }
    
    // Filter by search query (include business name)
    if (_searchQuery.isNotEmpty) {
      orders = orders.where((order) {
        final query = _searchQuery.toLowerCase();
        final businessName = order.restaurant.profile?.businessName?.toLowerCase() ?? '';
        return order.orderNumber.toLowerCase().contains(query) ||
               order.restaurant.displayName.toLowerCase().contains(query) ||
               businessName.contains(query);
      }).toList();
    }
    
    return orders;
  }

  @override
  Widget build(BuildContext context) {
    final ordersState = ref.watch(ordersProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Orders Management',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(
              icon: Icon(Icons.list_alt),
              text: 'Orders List',
            ),
            Tab(
              icon: Icon(Icons.inventory_2),
              text: 'Reserved Stock',
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(ordersProvider.notifier).refreshOrders();
              ref.read(inventoryProvider.notifier).loadStockLevels();
            },
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Orders List Tab
          _buildOrdersList(),
          // Reserved Stock Tab
          const ReservedStockView(),
        ],
      ),
    );
  }

  Widget _buildOrdersList() {
    final ordersState = ref.watch(ordersProvider);
    
    return Column(
      children: [
        // Search and Filters
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Search Bar
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search orders, restaurants, or business names...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                style: const TextStyle(fontSize: 16),
              ),
              
              const SizedBox(height: 16),
              
              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('All', 'all', _selectedStatusFilter, (value) {
                      setState(() {
                        _selectedStatusFilter = value;
                      });
                    }),
                    const SizedBox(width: 8),
                    _buildFilterChip('Received', 'received', _selectedStatusFilter, (value) {
                      setState(() {
                        _selectedStatusFilter = value;
                      });
                    }),
                    const SizedBox(width: 8),
                    _buildFilterChip('Confirmed', 'confirmed', _selectedStatusFilter, (value) {
                      setState(() {
                        _selectedStatusFilter = value;
                      });
                    }),
                    const SizedBox(width: 8),
                    _buildFilterChip('PO Sent', 'po_sent', _selectedStatusFilter, (value) {
                      setState(() {
                        _selectedStatusFilter = value;
                      });
                    }),
                    const SizedBox(width: 8),
                    _buildFilterChip('Delivered', 'delivered', _selectedStatusFilter, (value) {
                      setState(() {
                        _selectedStatusFilter = value;
                      });
                    }),
                    const SizedBox(width: 8),
                    _buildFilterChip('Cancelled', 'cancelled', _selectedStatusFilter, (value) {
                      setState(() {
                        _selectedStatusFilter = value;
                      });
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        // Orders List
        Expanded(
          child: ordersState.isLoading
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Loading orders...'),
                    ],
                  ),
                )
              : ordersState.error != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Colors.red[300],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Error loading orders',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            ordersState.error!,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () => ref.read(ordersProvider.notifier).refreshOrders(),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
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
                                color: Colors.grey[300],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No orders found',
                                style: Theme.of(context).textTheme.headlineSmall,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Try adjusting your search or filters',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.grey[600],
                                ),
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
                              child: MobileOrderCard(
                                order: order,
                                onTap: () => _showOrderDetails(context, order),
                                onStatusChanged: (newStatus) {
                                  ref.read(ordersProvider.notifier).updateOrderStatus(order.id, newStatus);
                                },
                              ),
                            );
                          },
                        ),
        ),
        
        // Summary Footer
        if (filteredOrders.isNotEmpty)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${filteredOrders.length} orders',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),
                _buildQuickStats(),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String value, String currentValue, Function(String) onSelected) {
    final isSelected = currentValue == value;
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.blue,
          fontWeight: FontWeight.w600,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        onSelected(selected ? value : 'all');
      },
      backgroundColor: Colors.white,
      selectedColor: Colors.blue,
      checkmarkColor: Colors.white,
      side: BorderSide(
        color: isSelected ? Colors.blue : Colors.blue.withOpacity(0.5),
      ),
    );
  }

  Widget _buildQuickStats() {
    final pendingCount = filteredOrders.where((order) => 
      order.status == 'received' || order.status == 'parsed').length;
    
    final deliveredCount = filteredOrders.where((order) => 
      order.status == 'delivered').length;

    return Row(
      children: [
        _buildStatBadge(
          icon: Icons.pending,
          count: pendingCount,
          color: Colors.orange,
          label: 'Pending',
        ),
        const SizedBox(width: 12),
        _buildStatBadge(
          icon: Icons.check_circle,
          count: deliveredCount,
          color: Colors.green,
          label: 'Delivered',
        ),
      ],
    );
  }

  Widget _buildStatBadge({
    required IconData icon,
    required int count,
    required Color color,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: color,
            size: 16,
          ),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  void _showOrderDetails(BuildContext context, Order order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  height: 4,
                  width: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                
                // Order details content
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(20),
                    child: _buildOrderDetailsContent(order),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildOrderDetailsContent(Order order) {

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.orderNumber,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    order.restaurant.displayName,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _getStatusColor(order.status).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                order.status.toUpperCase(),
                style: TextStyle(
                  color: _getStatusColor(order.status),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 24),
        
        // Order Items
        const Text(
          'Order Items',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        
        ...order.items.map((item) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.product.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Quantity: ${item.quantity} ${item.product.unit}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
        
        const SizedBox(height: 24),
        
        // Actions
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: order.status != 'delivered' ? () async {
              // Update order status based on current status
              String nextStatus;
              switch (order.status) {
                case 'received':
                  nextStatus = 'confirmed';
                  break;
                case 'confirmed':
                  nextStatus = 'po_sent';
                  break;
                case 'po_sent':
                  nextStatus = 'po_confirmed';
                  break;
                case 'po_confirmed':
                  nextStatus = 'delivered';
                  break;
                default:
                  nextStatus = 'delivered';
              }
              
              try {
                print('[DEBUG] MobileOrdersPage: Attempting to update order ${order.id} status to $nextStatus');
                await ref.read(ordersProvider.notifier).updateOrderStatus(order.id, nextStatus);
                
                // Check if there was an error after the update
                final ordersState = ref.read(ordersProvider);
                if (ordersState.error != null) {
                  print('[ERROR] MobileOrdersPage: Order update failed with error: ${ordersState.error}');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('❌ Failed to update order: ${ordersState.error}'),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 5),
                      ),
                    );
                  }
                  return; // Don't close the dialog if there was an error
                }
                
                print('[DEBUG] MobileOrdersPage: Order status updated successfully');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('✅ Order status updated to ${_getStatusDisplayName(nextStatus)}'),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                  Navigator.pop(context);
                }
              } catch (e) {
                print('[ERROR] MobileOrdersPage: Exception during order update: $e');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('❌ Error updating order: $e'),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 5),
                    ),
                  );
                }
              }
            } : null,
            icon: const Icon(Icons.arrow_forward),
            label: Text(_getNextStatusLabel(order.status)),
            style: ElevatedButton.styleFrom(
              backgroundColor: order.status != 'delivered' ? Colors.blue : Colors.grey,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  String _getStatusDisplayName(String status) {
    switch (status) {
      case 'received':
        return 'Received';
      case 'confirmed':
        return 'Confirmed';
      case 'po_sent':
        return 'PO Sent';
      case 'po_confirmed':
        return 'PO Confirmed';
      case 'delivered':
        return 'Delivered';
      default:
        return status.replaceAll('_', ' ').split(' ').map((word) => 
          word.isNotEmpty ? word[0].toUpperCase() + word.substring(1) : word
        ).join(' ');
    }
  }

  String _getNextStatusLabel(String currentStatus) {
    switch (currentStatus) {
      case 'received':
        return 'Confirm Order';
      case 'confirmed':
        return 'Send PO';
      case 'po_sent':
        return 'Confirm PO';
      case 'po_confirmed':
        return 'Mark Delivered';
      case 'delivered':
        return 'Already Delivered';
      default:
        return 'Update Status';
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'received':
        return Colors.blue;
      case 'parsed':
        return Colors.indigo;
      case 'confirmed':
        return Colors.orange;
      case 'po_sent':
        return Colors.purple;
      case 'po_confirmed':
        return Colors.teal;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

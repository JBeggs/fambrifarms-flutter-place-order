import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/customer.dart';
import '../../models/order.dart';
import '../../providers/customers_provider.dart';
import '../../core/professional_theme.dart';
import 'widgets/edit_customer_dialog.dart';
import 'customer_orders_page.dart'; // For the customerOrdersProvider

class CustomerDetailPage extends ConsumerWidget {
  final int customerId;

  const CustomerDetailPage({
    super.key,
    required this.customerId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customersState = ref.watch(customersProvider);
    final customer = customersState.customers
        .where((c) => c.id == customerId)
        .firstOrNull;

    if (customer == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Customer Not Found'),
          backgroundColor: AppColors.primaryGreen,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_off, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Customer not found',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: Text(customer.displayName),
        backgroundColor: AppColors.primaryGreen,
        elevation: 1,
        actions: [
          // Edit button
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => EditCustomerDialog(customer: customer),
              );
            },
          ),
          // More options
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'view_orders':
                  context.push('/customers/${customer.id}/orders');
                  break;
                case 'deactivate':
                  _showDeactivateDialog(context, customer);
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'view_orders',
                child: Row(
                  children: [
                    Icon(Icons.shopping_cart, size: 18),
                    SizedBox(width: 8),
                    Text('View Orders'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'deactivate',
                child: Row(
                  children: [
                    Icon(
                      customer.isActive ? Icons.block : Icons.check_circle,
                      size: 18,
                      color: customer.isActive ? Colors.red : Colors.green,
                    ),
                    const SizedBox(width: 8),
                    Text(customer.isActive ? 'Deactivate' : 'Activate'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Customer Header Card
            _buildHeaderCard(context, customer),
            
            const SizedBox(height: 16),
            
            // Order Statistics Card
            _buildOrderStatsCard(context, customer),
            
            const SizedBox(height: 16),
            
            // Contact Information Card
            _buildContactInfoCard(context, customer),
            
            const SizedBox(height: 16),
            
            // Business/Profile Information Card
            if (customer.profile != null)
              _buildProfileInfoCard(context, customer.profile!),
            
            const SizedBox(height: 16),
            
            // Recent Activity Card (placeholder for now)
            _buildRecentActivityCard(context, customer),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context, Customer customer) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            // Customer Avatar
            CircleAvatar(
              radius: 40,
              backgroundColor: _getCustomerTypeColor(customer.customerType),
              child: Text(
                customer.initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                ),
              ),
            ),
            
            const SizedBox(width: 24),
            
            // Customer Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name and Business Name
                  Text(
                    customer.profile?.businessName ?? customer.displayName,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  
                  if (customer.profile?.businessName != null && 
                      customer.profile!.businessName != customer.displayName)
                    Text(
                      customer.displayName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  
                  const SizedBox(height: 8),
                  
                  // Customer Type and Status
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _getCustomerTypeColor(customer.customerType)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          customer.customerTypeDisplay,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _getCustomerTypeColor(customer.customerType),
                          ),
                        ),
                      ),
                      
                      const SizedBox(width: 12),
                      
                      // Status indicator
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: customer.isActive 
                              ? Colors.green.withValues(alpha: 0.1)
                              : Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: customer.isActive ? Colors.green : Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              customer.statusDisplay,
                              style: TextStyle(
                                fontSize: 14,
                                color: customer.isActive ? Colors.green : Colors.red,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderStatsCard(BuildContext context, Customer customer) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.analytics, color: Color(0xFF2D5016)),
                const SizedBox(width: 8),
                Text(
                  'Order Statistics',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2D5016),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    context,
                    'Total Orders',
                    customer.totalOrders.toString(),
                    Icons.shopping_cart_outlined,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    context,
                    'Order Value',
                    'R${customer.totalOrderValue.toStringAsFixed(0)}',
                    Icons.attach_money,
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    context,
                    'Frequency',
                    customer.orderFrequency,
                    Icons.trending_up,
                    Colors.orange,
                  ),
                ),
                if (customer.lastOrderDate != null)
                  Expanded(
                    child: _buildStatItem(
                      context,
                      'Last Order',
                      _formatLastOrderDate(customer.lastOrderDate!),
                      Icons.schedule,
                      Colors.purple,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactInfoCard(BuildContext context, Customer customer) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.contact_mail, color: Color(0xFF2D5016)),
                const SizedBox(width: 8),
                Text(
                  'Contact Information',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2D5016),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            _buildContactItem(
              context,
              Icons.email,
              'Email',
              customer.email,
              onTap: () {
                // TODO: Open email client
              },
            ),
            
            const SizedBox(height: 12),
            
            _buildContactItem(
              context,
              Icons.phone,
              'Phone',
              customer.phone.isNotEmpty ? customer.phone : 'Not provided',
              onTap: customer.phone.isNotEmpty ? () {
                // TODO: Open phone dialer
              } : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileInfoCard(BuildContext context, CustomerProfile profile) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.business, color: Color(0xFF2D5016)),
                const SizedBox(width: 8),
                Text(
                  'Business Information',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2D5016),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            if (profile.businessName != null)
              _buildInfoItem(context, 'Business Name', profile.businessName!),
            
            if (profile.deliveryAddress != null)
              _buildInfoItem(context, 'Delivery Address', profile.deliveryAddress!),
            
            if (profile.deliveryNotes != null && profile.deliveryNotes!.isNotEmpty)
              _buildInfoItem(context, 'Delivery Notes', profile.deliveryNotes!),
            
            if (profile.orderPattern != null && profile.orderPattern!.isNotEmpty)
              _buildInfoItem(context, 'Order Pattern', profile.orderPattern!),
            
            if (profile.paymentTermsDays != null)
              _buildInfoItem(context, 'Payment Terms', '${profile.paymentTermsDays} days'),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivityCard(BuildContext context, Customer customer) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.history, color: Color(0xFF2D5016)),
                const SizedBox(width: 8),
                Text(
                  'Recent Activity',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2D5016),
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    context.push('/customers/${customer.id}/orders');
                  },
                  child: const Text('View All Orders'),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Recent orders
            Consumer(
              builder: (context, ref, child) {
                final ordersAsync = ref.watch(customerOrdersProvider(customer.id));
                
                return ordersAsync.when(
                  data: (orders) {
                    if (orders.isEmpty) {
                      return Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.shopping_cart_outlined,
                              size: 48,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No orders yet',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Orders will appear here once the customer places them',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.grey[500],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }

                    // Show recent orders (up to 3)
                    final recentOrders = orders.take(3).toList();
                    return Column(
                      children: recentOrders.map((order) => _buildRecentOrderCard(context, order)).toList(),
                    );
                  },
                  loading: () => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  error: (error, stack) => Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.red[400],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Failed to load recent orders',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.red[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildContactItem(BuildContext context, IconData icon, String label, String value, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Colors.grey[600]),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.open_in_new, size: 16, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Color _getCustomerTypeColor(String type) {
    switch (type) {
      case 'restaurant':
        return const Color(0xFF2D5016); // Farm green
      case 'private':
        return const Color(0xFF6366F1); // Indigo
      case 'internal':
        return const Color(0xFFE67E22); // Orange
      default:
        return Colors.grey;
    }
  }

  String _formatLastOrderDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()}w ago';
    } else {
      return '${(difference.inDays / 30).floor()}m ago';
    }
  }

  Widget _buildRecentOrderCard(BuildContext context, Order order) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Order number and status
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order #${order.orderNumber}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getOrderStatusColor(order.status).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          order.statusDisplay,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: _getOrderStatusColor(order.status),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        order.orderDate,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Order value and items
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'R${(order.totalAmount ?? 0.0).toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2D5016),
                  ),
                ),
                Text(
                  '${order.items.length} items',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            
            const SizedBox(width: 8),
            
            // Arrow icon
            Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  Color _getOrderStatusColor(String status) {
    switch (status) {
      case 'received':
        return Colors.blue;
      case 'parsed':
        return Colors.orange;
      case 'confirmed':
        return Colors.green;
      case 'po_sent':
        return Colors.purple;
      case 'po_confirmed':
        return Colors.indigo;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _showDeactivateDialog(BuildContext context, Customer customer) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(customer.isActive ? 'Deactivate Customer' : 'Activate Customer'),
        content: Text(
          customer.isActive
              ? 'Are you sure you want to deactivate ${customer.displayName}? They will no longer be able to place orders.'
              : 'Are you sure you want to activate ${customer.displayName}? They will be able to place orders again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: Implement activate/deactivate functionality
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    customer.isActive
                        ? '${customer.displayName} deactivated'
                        : '${customer.displayName} activated',
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: customer.isActive ? Colors.red : Colors.green,
              foregroundColor: Colors.white,
            ),
            child: Text(customer.isActive ? 'Deactivate' : 'Activate'),
          ),
        ],
      ),
    );
  }
}

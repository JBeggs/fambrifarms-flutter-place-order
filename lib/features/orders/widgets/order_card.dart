import 'package:flutter/material.dart';
import '../../../models/order.dart';
import 'order_status_chip.dart';

class OrderCard extends StatelessWidget {
  final Order order;
  final VoidCallback? onTap;
  final Function(String)? onStatusChanged;
  final VoidCallback? onDelete;

  const OrderCard({
    super.key,
    required this.order,
    this.onTap,
    this.onStatusChanged,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  // Order Number
                  Expanded(
                    child: Text(
                      order.orderNumber,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  
                  // Status
                  OrderStatusChip(status: order.status),
                  
                  // Actions Menu
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      switch (value) {
                        case 'edit':
                          _showEditOrderDialog(context);
                          break;
                        case 'status':
                          _showStatusChangeDialog(context);
                          break;
                        case 'delete':
                          onDelete?.call();
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit),
                            SizedBox(width: 8),
                            Text('Edit Order'),
                          ],  
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'status',
                        child: Row(
                          children: [
                            Icon(Icons.swap_horiz),
                            SizedBox(width: 8),
                            Text('Change Status'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              
              const SizedBox(height: 8),
              
              // Customer Name
              Row(
                children: [
                  Icon(
                    Icons.business,
                    size: 16,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    order.restaurant.displayName,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
              
              const SizedBox(height: 4),
              
              // Dates
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Order: ${order.orderDate}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.local_shipping,
                    size: 16,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Delivery: ${order.deliveryDate}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              
              const SizedBox(height: 8),
              
              // Items Summary
              Row(
                children: [
                  Icon(
                    Icons.shopping_cart,
                    size: 16,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${order.items.length} items',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  
                  // Product Issues Indicator
                  if (_hasProductIssues()) ...[
                    const SizedBox(width: 8),
                    Icon(
                      Icons.warning,
                      size: 16,
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Issues',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.orange,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  
                  if (order.totalAmount != null) ...[
                    const Spacer(),
                    Text(
                      'R${order.totalAmount!.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ],
              ),
              
              // WhatsApp Message Indicator
              if (order.whatsappMessageId != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.chat,
                      size: 16,
                      color: Colors.green,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'From WhatsApp',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.green,
                      ),
                    ),
                    if (order.parsedByAi == true) ...[
                      const SizedBox(width: 8),
                      Icon(
                        Icons.psychology,
                        size: 16,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'AI Parsed',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showEditOrderDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Order ${order.orderNumber}'),
        content: SizedBox(
          width: 500,
          height: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Restaurant Info
              Text(
                'Restaurant: ${order.restaurant.displayName}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              
              // Order Items
              Text(
                'Order Items:',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              
              Expanded(
                child: ListView.builder(
                  itemCount: order.items.length,
                  itemBuilder: (context, index) {
                    final item = order.items[index];
                    return Card(
                      child: ListTile(
                        title: Text(item.product.name),
                        subtitle: Text('${item.quantity} ${item.unit}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('\$${item.totalPrice.toStringAsFixed(2)}'),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.edit, size: 16),
                              onPressed: () {
                                _showEditItemDialog(context, item);
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                              onPressed: () {
                                // TODO: Remove item
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              
              // Add Item Button
              ElevatedButton.icon(
                onPressed: () {
                  _showAddItemDialog(context);
                },
                icon: const Icon(Icons.add),
                label: const Text('Add Item'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: Save order changes
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Order updated successfully')),
              );
            },
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }
  
  void _showEditItemDialog(BuildContext context, OrderItem item) {
    final quantityController = TextEditingController(text: item.quantity.toString());
    final priceController = TextEditingController(text: item.price.toString());
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit ${item.product.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: quantityController,
              decoration: const InputDecoration(
                labelText: 'Quantity',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: priceController,
              decoration: const InputDecoration(
                labelText: 'Price per unit',
                border: OutlineInputBorder(),
                prefixText: '\$',
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: Update item
              Navigator.of(context).pop();
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }
  
  void _showAddItemDialog(BuildContext context) {
    final productController = TextEditingController();
    final quantityController = TextEditingController();
    final priceController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: productController,
              decoration: const InputDecoration(
                labelText: 'Product Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: quantityController,
              decoration: const InputDecoration(
                labelText: 'Quantity',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: priceController,
              decoration: const InputDecoration(
                labelText: 'Price per unit',
                border: OutlineInputBorder(),
                prefixText: '\$',
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: Add new item
              Navigator.of(context).pop();
            },
            child: const Text('Add Item'),
          ),
        ],
      ),
    );
  }

  void _showStatusChangeDialog(BuildContext context) {
    final statuses = [
      'received',
      'parsed',
      'confirmed',
      'po_sent',
      'po_confirmed',
      'delivered',
      'cancelled',
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Order Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: statuses.map((status) {
            return ListTile(
              title: Text(Order(
                id: 0,
                orderNumber: '',
                restaurant: const Customer(
                  id: 0,
                  email: '',
                  userType: '',
                  isActive: false,
                ),
                orderDate: '',
                deliveryDate: '',
                status: status,
                items: [],
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ).statusDisplay),
              leading: Radio<String>(
                value: status,
                groupValue: order.status,
                onChanged: (value) {
                  if (value != null) {
                    Navigator.of(context).pop();
                    onStatusChanged?.call(value);
                  }
                },
              ),
              onTap: () {
                Navigator.of(context).pop();
                onStatusChanged?.call(status);
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
  
  bool _hasProductIssues() {
    return order.items.any((item) => _hasItemIssues(item));
  }
  
  bool _hasItemIssues(OrderItem item) {
    // Check for common product issues
    return item.price <= 0 || // No price set
           item.product.name.toLowerCase().contains('needs setup') || // Auto-created product
           item.totalPrice <= 0; // Invalid total
  }
  
  String _getProductIssuesSummary() {
    final issueCount = order.items.where((item) => _hasItemIssues(item)).length;
    final issues = <String>[];
    
    if (order.items.any((item) => item.price <= 0)) {
      issues.add('missing prices');
    }
    if (order.items.any((item) => item.product.name.toLowerCase().contains('needs setup'))) {
      issues.add('auto-created products');
    }
    
    return '$issueCount ${issueCount == 1 ? 'item has' : 'items have'} ${issues.join(', ')}';
  }
}

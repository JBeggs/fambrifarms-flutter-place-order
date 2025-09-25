import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/order.dart';
import '../../../models/customer.dart';
import '../../../providers/orders_provider.dart';
import '../../../services/api_service.dart';
import 'order_status_chip.dart';

class OrderCard extends ConsumerWidget {
  final Order order;
  final VoidCallback? onTap;
  final Function(String)? onStatusChanged;
  final VoidCallback? onDelete;
  final VoidCallback? onOrderUpdated;

  const OrderCard({
    super.key,
    required this.order,
    this.onTap,
    this.onStatusChanged,
    this.onDelete,
    this.onOrderUpdated,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderStockSummary = ref.watch(orderStockSummaryProvider(order));
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
                    order.restaurant.isRestaurant && order.restaurant.profile?.businessName != null 
                        ? order.restaurant.profile!.businessName! 
                        : order.restaurant.displayName,
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
                  
                  // Stock Availability Indicator
                  _buildStockIndicator(context, orderStockSummary),
                  
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
          width: 800, // Much wider like view order
          height: 600,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Restaurant Info
              Card(
                color: Theme.of(context).colorScheme.surfaceVariant,
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
                color: Theme.of(context).colorScheme.surfaceVariant,
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
                  color: Theme.of(context).colorScheme.surfaceVariant,
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
                              color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
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
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Column(
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
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.edit, size: 16),
                              onPressed: () {
                                _showEditItemDialog(context, item);
                              },
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
            onPressed: () async {
              try {
                // Close dialog first
                Navigator.of(context).pop();
                
                // Show loading
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Saving order changes...'),
                    duration: Duration(seconds: 1),
                  ),
                );
                
                // Trigger order refresh to get latest data
                onOrderUpdated?.call();
                
                // Show success message
                await Future.delayed(const Duration(milliseconds: 500));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Order changes saved successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error saving changes: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
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
              decoration: InputDecoration(
                labelText: 'Price per unit',
                border: const OutlineInputBorder(),
                prefixText: 'R ',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Get customer price',
                  onPressed: () async {
                    try {
                      final apiService = ApiService();
                      // Get customer-specific price from the backend
                      final response = await apiService.dio.get(
                        '/products/products/${item.product.id}/customer-price/',
                        queryParameters: {'customer_id': order.restaurant.id},
                      );
                      
                      if (response.statusCode == 200) {
                        final customerPrice = response.data['customer_price'] ?? item.product.price;
                        priceController.text = customerPrice.toString();
                        
                        // Show pricing context
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Customer price: R${customerPrice.toStringAsFixed(2)} '
                              '(Base: R${item.product.price.toStringAsFixed(2)})'
                            ),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } else {
                        priceController.text = item.product.price.toString();
                      }
                    } catch (e) {
                      // Fallback to base price
                      priceController.text = item.product.price.toString();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Using base price: R${item.product.price.toStringAsFixed(2)}'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    }
                  },
                ),
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
            onPressed: () async {
              try {
                final quantity = double.tryParse(quantityController.text);
                final price = double.tryParse(priceController.text);
                
                if (quantity == null || quantity <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a valid quantity'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                
                if (price == null || price <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a valid price'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                
                // Update the specific order item
                final apiService = ApiService();
                
                final response = await apiService.dio.put(
                  '/orders/${order.id}/items/${item.id}/',
                  data: {
                    'quantity': quantity,
                    'price': price,
                  },
                );
                
                Navigator.of(context).pop();
                
                // Refresh the order data
                if (onOrderUpdated != null) {
                  onOrderUpdated!();
                }
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Order item updated successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to update item: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
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
    final unitController = TextEditingController(text: 'piece');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Item'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: productController,
                decoration: const InputDecoration(
                  labelText: 'Product Name',
                  border: OutlineInputBorder(),
                  hintText: 'Enter product name',
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: quantityController,
                      decoration: const InputDecoration(
                        labelText: 'Quantity',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: unitController,
                      decoration: const InputDecoration(
                        labelText: 'Unit',
                        border: OutlineInputBorder(),
                        hintText: 'kg, piece, etc.',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: priceController,
                decoration: const InputDecoration(
                  labelText: 'Price per unit',
                  border: OutlineInputBorder(),
                  prefixText: 'R ',
                ),
                keyboardType: TextInputType.number,
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
            onPressed: () async {
              try {
                final productName = productController.text.trim();
                final quantity = double.tryParse(quantityController.text);
                final unit = unitController.text.trim();
                final price = double.tryParse(priceController.text);
                
                if (productName.isEmpty || quantity == null || unit.isEmpty || price == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please fill in all fields with valid values'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                
                final apiService = ApiService();
                
                // Add item to order via API
                final response = await apiService.dio.post(
                  '/orders/${order.id}/items/',
                  data: {
                    'product_name': productName,
                    'quantity': quantity,
                    'unit': unit,
                    'price': price,
                  },
                );
                
                if (response.statusCode == 201) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Item added successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  // Trigger order refresh
                  onOrderUpdated?.call();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to add item: ${response.statusMessage}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error adding item: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
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
                  name: '',
                  email: '',
                  phone: '',
                  customerType: 'restaurant',
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
  
  Widget _buildStockIndicator(BuildContext context, Map<String, dynamic> stockSummary) {
    final canFulfill = stockSummary['canFulfill'] as bool;
    final itemsOutOfStock = stockSummary['itemsOutOfStock'] as int;
    final itemsWithLowStock = stockSummary['itemsWithLowStock'] as int;
    
    if (canFulfill && itemsWithLowStock == 0) {
      // All items have sufficient stock
      return Row(
        children: [
          const SizedBox(width: 8),
          Icon(
            Icons.check_circle,
            size: 16,
            color: Colors.green,
          ),
          const SizedBox(width: 4),
          Text(
            'In Stock',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.green,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    } else if (itemsOutOfStock > 0) {
      // Some items are out of stock
      return Row(
        children: [
          const SizedBox(width: 8),
          Icon(
            Icons.error,
            size: 16,
            color: Colors.red,
          ),
          const SizedBox(width: 4),
          Text(
            'Out of Stock',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.red,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    } else if (itemsWithLowStock > 0) {
      // Some items have low stock
      return Row(
        children: [
          const SizedBox(width: 8),
          Icon(
            Icons.warning,
            size: 16,
            color: Colors.orange,
          ),
          const SizedBox(width: 4),
          Text(
            'Low Stock',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.orange,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }
    
    return const SizedBox.shrink();
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
  
}

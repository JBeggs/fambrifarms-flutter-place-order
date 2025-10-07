import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/order.dart';
import '../../../services/api_service.dart';
import 'order_status_chip.dart';
import '../edit_order_page.dart';

class OrderCard extends ConsumerWidget {
  final Order order;
  final VoidCallback? onTap;
  final Function(String)? onStatusChanged;
  final VoidCallback? onOrderUpdated;
  final VoidCallback? onOrderDeleted;

  const OrderCard({
    super.key,
    required this.order,
    this.onTap,
    this.onStatusChanged,
    this.onOrderUpdated,
    this.onOrderDeleted,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                      order.orderNumber,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                        const SizedBox(height: 4),
                        Text(
                          order.restaurant.name,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                        if (order.restaurant.profile?.businessName != null && 
                            order.restaurant.profile!.businessName!.isNotEmpty &&
                            order.restaurant.profile!.businessName != order.restaurant.name)
                          Text(
                            order.restaurant.profile!.businessName!,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[500],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          ],
                        ),
                      ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                      OrderStatusChip(status: order.status),
                      const SizedBox(height: 4),
                      Text(
                        'R${order.totalAmount?.toStringAsFixed(2) ?? '0.00'}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Order Details
              Row(
                children: [
                  Expanded(
                    child: _buildDetailItem(
                      context,
                      Icons.calendar_today,
                      'Order Date',
                      order.orderDate,
                    ),
                  ),
                  Expanded(
                    child: _buildDetailItem(
                      context,
                      Icons.local_shipping,
                      'Delivery',
                      order.deliveryDate,
                    ),
                  ),
                  Expanded(
                    child: _buildDetailItem(
                      context,
                      Icons.shopping_cart,
                      'Items',
                      '${order.items.length}',
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showViewOrderDialog(context),
                      icon: const Icon(Icons.visibility, size: 16),
                      label: const Text('View'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showEditOrderDialog(context),
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('Edit'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  if (onOrderDeleted != null) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showDeleteConfirmation(context, ref),
                        icon: const Icon(Icons.delete_outline, size: 16),
                        label: const Text('Delete'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red.shade700,
                          side: BorderSide(color: Colors.red.shade300),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem(BuildContext context, IconData icon, String label, String value) {
    return Row(
            children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              Text(
                value,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showViewOrderDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Order ${order.orderNumber}'),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
                    children: [
                // Customer Info
                      Text(
                  'Customer: ${order.restaurant.displayName}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('Email: ${order.restaurant.email}'),
                if (order.restaurant.phone != null && order.restaurant.phone!.isNotEmpty)
                  Text('Phone: ${order.restaurant.phone}'),
                
                const SizedBox(height: 16),
                
                // Order Details
                Text('Order Date: ${order.orderDate}'),
                Text('Delivery Date: ${order.deliveryDate}'),
                Text('Status: ${order.statusDisplay}'),
                Text('Total: R${order.totalAmount?.toStringAsFixed(2) ?? '0.00'}'),
                
              const SizedBox(height: 16),
              
                // Items with Pricing Breakdown
                const Text(
                  'Items:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...order.items.map((item) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Item header
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.product.name,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                                Text(
                                  'R${item.totalPrice.toStringAsFixed(2)}',
                              style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('${item.quantity} ${item.unit} × R${item.price.toStringAsFixed(2)}'),
                        
                        // Pricing breakdown if available
                        if (item.pricingBreakdown != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.blue[200]!),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.info_outline, size: 16, color: Colors.blue),
                                    const SizedBox(width: 4),
                                Text(
                                      'Pricing Details',
                                      style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                        color: Colors.blue[700],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                _buildPricingRow('Customer Segment', item.pricingBreakdown!.customerSegmentDisplay),
                                _buildPricingRow('Pricing Source', item.pricingBreakdown!.pricingSourceDisplay),
                                _buildPricingRow('Base Price', 'R${item.pricingBreakdown!.basePrice.toStringAsFixed(2)}'),
                                _buildPricingRow('Customer Price', 'R${item.pricingBreakdown!.customerPrice.toStringAsFixed(2)}'),
                                if (item.pricingBreakdown!.markupPercentage != 0)
                                  _buildPricingRow('Markup', item.pricingBreakdown!.markupDisplay),
                                if (item.pricingBreakdown!.pricingRule != null)
                                  _buildPricingRow('Pricing Rule', item.pricingBreakdown!.pricingRule!.name),
                                if (item.pricingBreakdown!.priceListItem != null)
                                  _buildPricingRow('Price List', item.pricingBreakdown!.priceListItem!.priceListName),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                )),
                
                // Original Message
                if (order.originalMessage != null && order.originalMessage!.isNotEmpty) ...[
            const SizedBox(height: 16),
                  const Text(
                    'Original WhatsApp Message:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      order.originalMessage!,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    ),
                  ),
                ],
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

  void _showEditOrderDialog(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EditOrderPage(order: order),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Order'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete order ${order.orderNumber}?'),
            const SizedBox(height: 8),
            Text(
              'Customer: ${order.restaurant.name}',
              style: TextStyle(color: Colors.grey[600]),
            ),
            Text(
              'Total: R${order.totalAmount?.toStringAsFixed(2) ?? '0.00'}',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.red.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This action cannot be undone. All order items and related data will be permanently deleted.',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => _deleteOrder(context, ref),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete Order'),
          ),
        ],
      ),
    );
  }

  void _deleteOrder(BuildContext context, WidgetRef ref) async {
    // Close confirmation dialog first
    Navigator.of(context).pop();

    // Store the context for safe usage
    if (!context.mounted) return;

    bool isLoadingDialogOpen = false;
    
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Deleting order...'),
            ],
          ),
        ),
      );
      isLoadingDialogOpen = true;

      // Delete the order
      final apiService = ref.read(apiServiceProvider);
      
      // Check authentication before attempting delete
      if (!apiService.isAuthenticated) {
        throw Exception('Authentication required. Please log in again.');
      }
      
      await apiService.deleteOrder(order.id);

      // Close loading dialog
      if (context.mounted && isLoadingDialogOpen) {
        Navigator.of(context).pop();
        isLoadingDialogOpen = false;
      }

      // Show success message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order ${order.orderNumber} deleted successfully'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      // Call the callback to refresh the orders list
      onOrderDeleted?.call();

    } catch (e) {
      // Close loading dialog if still open
      if (context.mounted && isLoadingDialogOpen) {
        Navigator.of(context).pop();
        isLoadingDialogOpen = false;
      }
      
      // Handle different error types
      String errorMessage = 'Error deleting order';
      
      if (e.toString().contains('401') || e.toString().contains('Unauthorized')) {
        errorMessage = 'Authentication expired. Please log in again.';
      } else if (e.toString().contains('403') || e.toString().contains('Forbidden')) {
        errorMessage = 'You don\'t have permission to delete this order.';
      } else if (e.toString().contains('404') || e.toString().contains('not found')) {
        errorMessage = 'Order not found. It may have already been deleted.';
      } else if (e.toString().contains('network') || e.toString().contains('connection')) {
        errorMessage = 'Network error. Please check your connection and try again.';
      } else {
        errorMessage = 'Error deleting order: ${e.toString()}';
      }
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: e.toString().contains('401') || e.toString().contains('Unauthorized')
                ? SnackBarAction(
                    label: 'Login',
                    textColor: Colors.white,
                    onPressed: () {
                      // Navigate to login page or trigger re-authentication
                      // This depends on your app's navigation structure
                    },
                  )
                : null,
          ),
        );
      }
    }
  }
  
  Widget _buildPricingRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.0),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
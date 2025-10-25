import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:file_picker/file_picker.dart';
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
                  Expanded(
                    child: _buildParsingQualityItem(context),
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
      builder: (context) => Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.9,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with title and actions
              Row(
                children: [
                  Icon(
                    Icons.receipt_long,
                    color: Theme.of(context).colorScheme.primary,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Order ${order.orderNumber}',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _printOrder(context),
                    icon: const Icon(Icons.print, size: 18),
                    label: const Text('Print'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    tooltip: 'Close',
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
          child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
                    children: [
                      // Customer Info Section
                      _buildDetailSection(
                        context,
                        'Customer Information',
                        Icons.person,
                        [
                          _buildDetailRow('Name', order.restaurant.displayName),
                          _buildDetailRow('Email', order.restaurant.email),
                          if (order.restaurant.phone != null && order.restaurant.phone!.isNotEmpty)
                            _buildDetailRow('Phone', order.restaurant.phone!),
                          _buildDetailRow('Type', order.restaurant.customerType),
                        ],
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Order Details Section
                      _buildDetailSection(
                        context,
                        'Order Details',
                        Icons.receipt,
                        [
                          _buildDetailRow('Order Number', order.orderNumber),
                          _buildDetailRow('Order Date', order.orderDate),
                          _buildDetailRow('Delivery Date', order.deliveryDate),
                          _buildDetailRow('Status', order.statusDisplay, statusColor: _getStatusColor(order.status)),
                          _buildDetailRow('Total Amount', 'R${order.totalAmount?.toStringAsFixed(2) ?? '0.00'}', 
                            valueStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
                          _buildDetailRow('Items Count', '${order.items.length} item${order.items.length == 1 ? '' : 's'}'),
                        ],
                      ),
                
                      const SizedBox(height: 24),
                      
                      // Items Section
                      _buildDetailSection(
                        context,
                        'Order Items',
                        Icons.shopping_cart,
                        [],
                        customContent: Column(
                          children: order.items.map((item) => Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                                // Item header with confidence score
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.product.name,
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                              ),
                            ),
                                    if (item.confidenceScore != null) ...[
                                      const SizedBox(width: 8),
                                      _buildConfidenceChip(item.confidenceScore!),
                                      const SizedBox(width: 8),
                                    ],
                                Text(
                                  'R${item.totalPrice.toStringAsFixed(2)}',
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Text(
                                      '${item.quantity} ${item.unit} × R${item.price.toStringAsFixed(2)}',
                                      style: Theme.of(context).textTheme.bodyMedium,
                                    ),
                                    const Spacer(),
                                    if (item.manuallyCorrected == true)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Colors.orange.withOpacity(0.3)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.edit, size: 12, color: Colors.orange[700]),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Manually Corrected',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.orange[700],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                                
                                // Split item notes if available
                                if (item.notes != null && item.notes!.contains('Split item')) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.splitscreen, size: 14, color: Colors.blue[700]),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Partial Stock Split: ',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.blue[700],
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            item.notes!.replaceAll('Split item - ', ''),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.blue[700],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                
                                // Original text if available
                                if (item.originalText != null && item.originalText!.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.chat_bubble_outline, size: 14, color: Colors.grey[600]),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Original: ',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            '"${item.originalText}"',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontStyle: FontStyle.italic,
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                        
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
                  )).toList(),
                    ),
                  ),
                
                      // Original Message Section
                if (order.originalMessage != null && order.originalMessage!.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        _buildDetailSection(
                          context,
                          'Original WhatsApp Message',
                          Icons.chat,
                          [],
                          customContent: Container(
                    width: double.infinity,
                            padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.withOpacity(0.2)),
                    ),
                    child: Text(
                      order.originalMessage!,
                              style: const TextStyle(
                                fontFamily: 'monospace', 
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
            ],
          ),
        ),
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

    // Keep track of loading dialog using a completer for more reliable management
    bool isLoadingDialogOpen = false;
    
    try {
      // Show loading dialog
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => WillPopScope(
            onWillPop: () async => false, // Prevent back button from closing
            child: const AlertDialog(
              content: Row(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 16),
                  Text('Deleting order...'),
                ],
              ),
            ),
          ),
        );
        isLoadingDialogOpen = true;
      }

      // Delete the order
      final apiService = ref.read(apiServiceProvider);
      
      // Check authentication before attempting delete
      if (!apiService.isAuthenticated) {
        throw Exception('Authentication required. Please log in again.');
      }
      
      await apiService.deleteOrder(order.id);

      // Success: Show success message and call callback
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
    } finally {
      // CRITICAL: Always close loading dialog in finally block
      if (isLoadingDialogOpen && context.mounted) {
        try {
          Navigator.of(context).pop();
        } catch (e) {
          // If popping fails, try to pop until we can't anymore (clear any stuck dialogs)
          print('Error closing dialog: $e');
          try {
            Navigator.of(context).popUntil((route) => !route.isFirst || route.settings.name != null);
          } catch (e2) {
            print('Error with popUntil: $e2');
          }
        }
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

  Widget _buildParsingQualityItem(BuildContext context) {
    // Calculate parsing quality metrics
    final itemsWithConfidence = order.items.where((item) => item.confidenceScore != null).toList();
    final highConfidenceItems = itemsWithConfidence.where((item) => item.confidenceScore! >= 80).length;
    final mediumConfidenceItems = itemsWithConfidence.where((item) => item.confidenceScore! >= 60 && item.confidenceScore! < 80).length;
    final lowConfidenceItems = itemsWithConfidence.where((item) => item.confidenceScore! < 60).length;
    
    Color qualityColor;
    IconData qualityIcon;
    String qualityLabel;
    
    if (itemsWithConfidence.isEmpty) {
      qualityColor = Colors.grey;
      qualityIcon = Icons.help_outline;
      qualityLabel = 'Unknown';
    } else {
      final highPercentage = (highConfidenceItems / itemsWithConfidence.length) * 100;
      if (highPercentage >= 80) {
        qualityColor = Colors.green;
        qualityIcon = Icons.check_circle;
        qualityLabel = 'Excellent';
      } else if (highPercentage >= 60) {
        qualityColor = Colors.orange;
        qualityIcon = Icons.warning;
        qualityLabel = 'Good';
      } else {
        qualityColor = Colors.red;
        qualityIcon = Icons.error;
        qualityLabel = 'Needs Review';
      }
    }
    
    return Row(
      children: [
        Icon(qualityIcon, size: 16, color: qualityColor),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Parsing',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              Text(
                qualityLabel,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: qualityColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailSection(
    BuildContext context,
    String title,
    IconData icon,
    List<Widget> children, {
    Widget? customContent,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (children.isNotEmpty) ...[
            const SizedBox(height: 16),
            ...children,
          ],
          if (customContent != null) ...[
            const SizedBox(height: 16),
            customContent,
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    Color? statusColor,
    TextStyle? valueStyle,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: valueStyle ?? TextStyle(
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'preparing':
        return Colors.purple;
      case 'ready':
        return Colors.green;
      case 'delivered':
        return Colors.teal;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildConfidenceChip(double confidence) {
    Color chipColor;
    String label;
    
    if (confidence >= 80) {
      chipColor = Colors.green;
      label = 'High';
    } else if (confidence >= 60) {
      chipColor = Colors.orange;
      label = 'Med';
    } else {
      chipColor = Colors.red;
      label = 'Low';
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: chipColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.psychology,
            size: 12,
            color: chipColor,
          ),
          const SizedBox(width: 4),
          Text(
            '$label ${confidence.toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: chipColor,
            ),
          ),
        ],
      ),
    );
  }

  void _printOrder(BuildContext context) async {
    // Show print preview dialog
    await showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.9,
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Dialog header
              Row(
                children: [
                  const Icon(Icons.print, size: 24),
                  const SizedBox(width: 12),
                  const Text(
                    'Print Preview',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 16),
              
              // Print preview content
              Expanded(
                child: SingleChildScrollView(
                  child: _buildPrintPreview(),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Save PDF button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _savePdfWithDialog(context),
                  icon: const Icon(Icons.save),
                  label: const Text('Save PDF'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrintPreview() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with company name and customer address
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: Company info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'FAMBRI FARMS',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D5016),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Order Confirmation',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Right: Customer address
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    order.restaurant.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.right,
                  ),
                  if (order.restaurant.profile?.businessName != null &&
                      order.restaurant.profile!.businessName!.isNotEmpty)
                    Text(
                      order.restaurant.profile!.businessName!,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      textAlign: TextAlign.right,
                    ),
                  if (order.restaurant.profile?.deliveryAddress != null &&
                      order.restaurant.profile!.deliveryAddress!.isNotEmpty)
                    Container(
                      constraints: const BoxConstraints(maxWidth: 250),
                      child: Text(
                        order.restaurant.profile!.deliveryAddress!,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  if (order.restaurant.profile?.city != null)
                    Text(
                      '${order.restaurant.profile!.city}${order.restaurant.profile?.postalCode != null ? ', ${order.restaurant.profile!.postalCode}' : ''}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      textAlign: TextAlign.right,
                    ),
                  if (order.restaurant.phone.isNotEmpty)
                    Text(
                      order.restaurant.phone,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      textAlign: TextAlign.right,
                    ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          
          // Order details
          Row(
            children: [
              Expanded(
                child: _buildInfoRow('Order Number:', order.orderNumber),
              ),
              Expanded(
                child: _buildInfoRow('Order Date:', order.orderDate),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildInfoRow('Delivery Date:', DateTime.now().add(const Duration(days: 1)).toString().split(' ')[0]),
              ),
              Expanded(
                child: _buildInfoRow('Status:', order.statusDisplay),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Items table
          Table(
            border: TableBorder.all(color: Colors.grey.shade300, width: 1),
            columnWidths: const {
              0: FlexColumnWidth(3),
              1: FlexColumnWidth(1),
              2: FlexColumnWidth(1),
              3: FlexColumnWidth(1.5),
              4: FlexColumnWidth(1.5),
            },
            children: [
              // Header row
              TableRow(
                decoration: BoxDecoration(color: Colors.grey[100]),
                children: [
                  _buildTableHeader('Product'),
                  _buildTableHeader('Qty'),
                  _buildTableHeader('Price'),
                  _buildTableHeader('Total'),
                  _buildTableHeader('Stock Status'),
                ],
              ),
              // Item rows
              ...order.items.map((item) => TableRow(
                children: [
                  _buildTableCell(item.product.name),
                  _buildTableCell('${item.quantity.toStringAsFixed(item.quantity.truncateToDouble() == item.quantity ? 0 : 1)} ${item.unit ?? ''}'),
                  _buildTableCell('R${item.price.toStringAsFixed(2)}'),
                  _buildTableCell('R${item.totalPrice.toStringAsFixed(2)}', bold: true),
                  _buildStockStatusCell(item),
                ],
              )),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Stock summary
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              border: Border.all(color: Colors.blue.shade200),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStockSummaryItem(
                  '✅ Reserved',
                  order.items.where((i) => i.isStockReserved).length,
                  Colors.green.shade700,
                ),
                _buildStockSummaryItem(
                  '🔄 Converted',
                  order.items.where((i) => i.isConvertedToBulkKg).length,
                  Colors.blue.shade700,
                ),
                _buildStockSummaryItem(
                  '📦 To Order',
                  order.items.where((i) => i.isNoReserve || i.isStockReservationFailed).length,
                  Colors.orange.shade700,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Total
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF2D5016).withOpacity(0.1),
              border: Border.all(color: const Color(0xFF2D5016), width: 2),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'TOTAL',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'R${order.totalAmount?.toStringAsFixed(2) ?? '0.00'}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D5016),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Footer
          Center(
            child: Text(
              'Thank you for your business!',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTableCell(String text, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildStockStatusCell(OrderItem item) {
    String statusText;
    Color statusColor;
    IconData statusIcon;

    if (item.isStockReserved) {
      statusText = '✅ Reserved';
      statusColor = Colors.green.shade700;
      statusIcon = Icons.check_circle;
    } else if (item.isConvertedToBulkKg) {
      statusText = '🔄 Converted to Kg';
      statusColor = Colors.blue.shade700;
      statusIcon = Icons.sync;
    } else if (item.isNoReserve) {
      statusText = '📦 To Order';
      statusColor = Colors.orange.shade700;
      statusIcon = Icons.shopping_cart;
    } else if (item.isStockReservationFailed) {
      statusText = '❌ Need to Order';
      statusColor = Colors.red.shade700;
      statusIcon = Icons.error;
    } else {
      statusText = 'Unknown';
      statusColor = Colors.grey.shade600;
      statusIcon = Icons.help;
    }

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, size: 12, color: statusColor),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              statusText,
              style: TextStyle(
                fontSize: 10,
                color: statusColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStockSummaryItem(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  void _savePdfWithDialog(BuildContext context) async {
    try {
      print('[PDF SAVE] Starting PDF generation...');
      
      // Generate PDF
      final pdf = pw.Document();
      await _buildPdfDocument(pdf);
      final bytes = await pdf.save();
      
      print('[PDF SAVE] PDF generated, size: ${bytes.length} bytes');
      print('[PDF SAVE] Opening file picker dialog...');
      
      // Open Save As dialog - works on Windows, macOS, Linux
      String? outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Order PDF',
        fileName: 'Order_${order.orderNumber}.pdf',
      );
      
      print('[PDF SAVE] File picker returned: $outputPath');
      
      if (outputPath != null) {
        print('[PDF SAVE] Saving to: $outputPath');
        
        // Ensure .pdf extension
        if (!outputPath.toLowerCase().endsWith('.pdf')) {
          outputPath = '$outputPath.pdf';
        }
        
        // User selected a location, save the file
        final file = File(outputPath);
        await file.writeAsBytes(bytes);
        
        print('[PDF SAVE] File saved successfully');
        
        if (context.mounted) {
          Navigator.of(context).pop(); // Close the preview
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
                  const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
                    child: Text('PDF saved: ${outputPath.split('/').last}'),
            ),
          ],
        ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        print('[PDF SAVE] User cancelled or dialog failed to open');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Save cancelled - if dialog did not open, check app permissions'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      print('[PDF SAVE] ERROR: $e');
      print('[PDF SAVE] Stack trace: $stackTrace');
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving PDF: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _buildPdfDocument(pw.Document pdf) async {
    print('[PDF BUILD] Building PDF for order: ${order.orderNumber}');
    print('[PDF BUILD] Order has ${order.items.length} items');
    
    // Capture data BEFORE the build context
    final items = order.items;
    final restaurantName = order.restaurant.name;
    final businessName = order.restaurant.profile?.businessName ?? '';
    final deliveryAddress = order.restaurant.profile?.deliveryAddress ?? '';
    final city = order.restaurant.profile?.city ?? '';
    final postalCode = order.restaurant.profile?.postalCode ?? '';
    final phone = order.restaurant.phone ?? '';
    final orderNumber = order.orderNumber;
    final orderDate = order.orderDate;
    final deliveryDate = order.deliveryDate;
    final statusDisplay = order.statusDisplay;
    final totalAmount = order.totalAmount;
    
    print('[PDF BUILD] Captured ${items.length} items before build context');
    
    // FIRST: Add the main order page (preview style - all items together)
    await _addMainOrderPage(pdf, items, restaurantName, businessName, deliveryAddress, city, postalCode, phone, orderNumber, orderDate, deliveryDate, statusDisplay, totalAmount);
    
    // THEN: Add sectioned pages for reserved and to order items
    final reservedItems = items.where((item) => item.isStockReserved).toList();
    final toOrderItems = items.where((item) => item.isNoReserve || item.isStockReservationFailed).toList();
    
    print('[PDF BUILD] Reserved: ${reservedItems.length}, To Order: ${toOrderItems.length}');
    
    // Add reserved items page if there are any
    if (reservedItems.isNotEmpty) {
      final reservedTotal = reservedItems.fold(0.0, (sum, item) => sum + item.totalPrice);
      await _addSectionPage(pdf, 'RESERVED STOCK', '✅ Stock Reserved from Inventory', reservedItems, reservedTotal,
          restaurantName, businessName, deliveryAddress, city, postalCode, phone, orderNumber, orderDate, deliveryDate, statusDisplay);
    }
    
    // Add to order items page if there are any
    if (toOrderItems.isNotEmpty) {
      final toOrderTotal = toOrderItems.fold(0.0, (sum, item) => sum + item.totalPrice);
      await _addSectionPage(pdf, 'TO ORDER', '📦 Items for Procurement', toOrderItems, toOrderTotal,
          restaurantName, businessName, deliveryAddress, city, postalCode, phone, orderNumber, orderDate, deliveryDate, statusDisplay);
    }
  }

  String _getStockStatusText(OrderItem item) {
    if (item.isStockReserved) {
      return 'Reserved';
    } else if (item.isConvertedToBulkKg) {
      return 'Converted to Kg';
    } else if (item.isNoReserve) {
      return 'To Order';
    } else if (item.isStockReservationFailed) {
      return 'Need to Order';
    } else {
      return 'Unknown';
    }
  }

  pw.Widget _buildProductNameWithNotes(OrderItem item) {
    // Check if this is a split item based on notes
    bool isSplitItem = item.notes?.contains('Split item') == true;
    
    if (isSplitItem) {
      String splitInfo = '';
      if (item.notes?.contains('Reserved from stock') == true) {
        splitInfo = '[Reserved Part]';
      } else if (item.notes?.contains('Needs procurement') == true) {
        splitInfo = '[To Order Part]';
      }
      
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(item.product.name, style: const pw.TextStyle(fontSize: 8)),
          if (splitInfo.isNotEmpty)
            pw.Text(splitInfo, style: pw.TextStyle(fontSize: 6, color: PdfColors.blue700)),
        ],
      );
    }
    
    return pw.Text(item.product.name, style: const pw.TextStyle(fontSize: 8));
  }

  Future<void> _addMainOrderPage(pw.Document pdf, List<OrderItem> items, String restaurantName, String businessName, String deliveryAddress, String city, String postalCode, String phone, String orderNumber, String orderDate, String deliveryDate, String statusDisplay, double? totalAmount) async {
    // Split items into chunks of 25 for pagination - fit more per page
    final itemsPerPage = 25;
    final totalPages = (items.length / itemsPerPage).ceil();
    
    for (int pageIndex = 0; pageIndex < totalPages; pageIndex++) {
      final startIndex = pageIndex * itemsPerPage;
      final endIndex = (startIndex + itemsPerPage).clamp(0, items.length);
      final pageItems = items.sublist(startIndex, endIndex);
      final isFirstPage = pageIndex == 0;
      final isLastPage = pageIndex == totalPages - 1;
      
      print('[PDF BUILD] Creating main page ${pageIndex + 1}/$totalPages with ${pageItems.length} items');
    
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(16),
          build: (pw.Context context) {
            // Build item rows BEFORE the column
            final List<pw.Widget> itemRows = [];
            for (var item in pageItems) {
              itemRows.add(
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300)),
                  ),
                  child: pw.Row(
                    children: [
                      pw.Expanded(flex: 4, child: _buildProductNameWithNotes(item)),
                      pw.Expanded(flex: 2, child: pw.Text('${item.quantity} ${item.unit ?? ''}', style: const pw.TextStyle(fontSize: 8))),
                      // pw.Expanded(flex: 2, child: pw.Text('R${item.price.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 8))),
                      // pw.Expanded(flex: 2, child: pw.Text('R${item.totalPrice.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                      pw.Expanded(flex: 2, child: pw.Text(_getStockStatusText(item), style: const pw.TextStyle(fontSize: 7))),
                    ],
                  ),
                ),
              );
            }
            
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header - only on first page
                if (isFirstPage) ...[
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'FAMBRI FARMS',
                          style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          'Order Confirmation',
                          style: const pw.TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          restaurantName,
                          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                        ),
                        if (businessName.isNotEmpty)
                          pw.Text(businessName, style: const pw.TextStyle(fontSize: 11)),
                        if (deliveryAddress.isNotEmpty)
                          pw.Container(
                            width: 200,
                            child: pw.Text(
                              deliveryAddress,
                              style: const pw.TextStyle(fontSize: 11),
                              textAlign: pw.TextAlign.right,
                            ),
                          ),
                        if (city.isNotEmpty)
                          pw.Text(
                            '$city${postalCode.isNotEmpty ? ', $postalCode' : ''}',
                            style: const pw.TextStyle(fontSize: 11),
                          ),
                        if (phone.isNotEmpty)
                          pw.Text(phone, style: const pw.TextStyle(fontSize: 11)),
                      ],
                    ),
                  ],
                ),
                
                pw.SizedBox(height: 8),
                pw.Divider(),
                pw.SizedBox(height: 6),
                
                // Order info
                pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Order Number: $orderNumber', style: const pw.TextStyle(fontSize: 11)),
                          pw.SizedBox(height: 4),
                          pw.Text('Generated: ${DateTime.now().toString().split('.')[0]}', style: const pw.TextStyle(fontSize: 11)),
                        ],
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Delivery Date: ${DateTime.now().add(const Duration(days: 1)).toString().split(' ')[0]}', style: const pw.TextStyle(fontSize: 11)),
                          pw.SizedBox(height: 4),
                          pw.Text('Status: $statusDisplay', style: const pw.TextStyle(fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),
                
                pw.SizedBox(height: 8),
                ],
                
                // Page header for continuation pages
                if (!isFirstPage) ...[
                  pw.Text('$restaurantName - Order $orderNumber (continued)', 
                    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 16),
                ],
                
                // Table header
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey200,
                    border: pw.Border.all(),
                  ),
                  child: pw.Row(
                    children: [
                      pw.Expanded(flex: 4, child: pw.Text('PRODUCT', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                      pw.Expanded(flex: 2, child: pw.Text('QTY', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                      // pw.Expanded(flex: 2, child: pw.Text('PRICE', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                      // pw.Expanded(flex: 2, child: pw.Text('TOTAL', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                      pw.Expanded(flex: 2, child: pw.Text('STATUS', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                    ],
                  ),
                ),
                
                // Items
                ...itemRows,
                
                pw.SizedBox(height: 8),
                
                // Total (always show on last page) - COMMENTED OUT
                // if (isLastPage)
                //   pw.Container(
                //     padding: const pw.EdgeInsets.all(12),
                //     decoration: pw.BoxDecoration(
                //       border: pw.Border.all(width: 2),
                //     ),
                //     child: pw.Row(
                //       mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                //       children: [
                //         pw.Text('TOTAL', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                //         pw.Text(
                //           'R${totalAmount?.toStringAsFixed(2) ?? '0.00'}',
                //           style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
                //         ),
                //       ],
                //     ),
                //   ),
                
                pw.Spacer(),
                
                pw.Center(
                  child: pw.Text(
                    isLastPage ? 'Order Complete - Additional details on following pages' : 'Continued on next page...',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ),
              ],
            );
          },
        ),
      );
    }
  }

  Future<void> _addSectionPage(pw.Document pdf, String sectionTitle, String sectionSubtitle, List<OrderItem> sectionItems, double sectionTotal,
      String restaurantName, String businessName, String deliveryAddress, String city, String postalCode, String phone,
      String orderNumber, String orderDate, String deliveryDate, String statusDisplay) async {
    
    // Paginate items within section (25 per page)
    final itemsPerPage = 25;
    final totalPages = (sectionItems.length / itemsPerPage).ceil();
    
    for (int pageIndex = 0; pageIndex < totalPages; pageIndex++) {
      final startIndex = pageIndex * itemsPerPage;
      final endIndex = (startIndex + itemsPerPage).clamp(0, sectionItems.length);
      final pageItems = sectionItems.sublist(startIndex, endIndex);
      final isFirstSectionPage = pageIndex == 0;
      final isLastSectionPage = pageIndex == totalPages - 1;
      
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(16),
          build: (pw.Context context) {
            // Build item rows
            final List<pw.Widget> itemRows = [];
            for (var item in pageItems) {
              itemRows.add(
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300)),
                  ),
                  child: pw.Row(
                    children: [
                      pw.Expanded(flex: 4, child: _buildProductNameWithNotes(item)),
                      pw.Expanded(flex: 2, child: pw.Text('${item.quantity} ${item.unit ?? ''}', style: const pw.TextStyle(fontSize: 8))),
                      // pw.Expanded(flex: 2, child: pw.Text('R${item.price.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 8))),
                      // pw.Expanded(flex: 2, child: pw.Text('R${item.totalPrice.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                      pw.Expanded(flex: 2, child: pw.Text(_getStockStatusText(item), style: const pw.TextStyle(fontSize: 7))),
                    ],
        ),
      ),
    );
  }
            
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header - only on first page of section
                if (isFirstSectionPage) ...[
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('FAMBRI FARMS', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                          pw.Text('Order Confirmation', style: const pw.TextStyle(fontSize: 12)),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(restaurantName, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                          if (businessName.isNotEmpty) pw.Text(businessName, style: const pw.TextStyle(fontSize: 11)),
                          if (deliveryAddress.isNotEmpty)
                            pw.Container(
                              width: 200,
                              child: pw.Text(deliveryAddress, style: const pw.TextStyle(fontSize: 11), textAlign: pw.TextAlign.right),
                            ),
                          if (city.isNotEmpty || postalCode.isNotEmpty) pw.Text('$city $postalCode'.trim(), style: const pw.TextStyle(fontSize: 11)),
                          if (phone.isNotEmpty) pw.Text(phone, style: const pw.TextStyle(fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 16),
                  // Order info
                  pw.Row(
                    children: [
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('Order Number: $orderNumber', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                            pw.SizedBox(height: 4),
                            pw.Text('Generated: ${DateTime.now().toString().split('.')[0]}', style: const pw.TextStyle(fontSize: 11)),
                          ],
                        ),
                      ),
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('Delivery Date: $deliveryDate', style: const pw.TextStyle(fontSize: 11)),
                            pw.SizedBox(height: 4),
                            pw.Text('Status: $statusDisplay', style: const pw.TextStyle(fontSize: 11)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 16),
                ],
                
                // Section title
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blue50,
                    border: pw.Border.all(color: PdfColors.blue700, width: 2),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Text(sectionTitle, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue700)),
                      pw.SizedBox(height: 4),
                      pw.Text(sectionSubtitle, style: pw.TextStyle(fontSize: 12, color: PdfColors.blue600)),
                    ],
                  ),
                ),
                
                pw.SizedBox(height: 8),
                
                // Table header
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey200,
                    border: pw.Border.all(),
                  ),
                  child: pw.Row(
                    children: [
                      pw.Expanded(flex: 4, child: pw.Text('PRODUCT', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                      pw.Expanded(flex: 2, child: pw.Text('QTY', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                      // pw.Expanded(flex: 2, child: pw.Text('PRICE', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                      // pw.Expanded(flex: 2, child: pw.Text('TOTAL', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                      pw.Expanded(flex: 2, child: pw.Text('STATUS', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                    ],
                  ),
                ),
                
                // Items
                ...itemRows,
                
                pw.SizedBox(height: 8),
                
                // Section total (show on last page of section) - COMMENTED OUT
                // if (isLastSectionPage)
                //   pw.Container(
                //     padding: const pw.EdgeInsets.all(12),
                //     decoration: pw.BoxDecoration(border: pw.Border.all(width: 2)),
                //     child: pw.Row(
                //       mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                //       children: [
                //         pw.Text('$sectionTitle TOTAL', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                //         pw.Text('R${sectionTotal.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                //       ],
                //     ),
                //   ),
                
                pw.Spacer(),
                
                pw.Center(
                  child: pw.Text(
                    isLastSectionPage ? 'Section Complete' : 'Continued on next page...',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ),
              ],
            );
          },
        ),
      );
    }
  }

}
import 'package:flutter/material.dart';
import 'quick_add_product_dialog.dart';

class ProcessingResultDialog extends StatefulWidget {
  final Map<String, dynamic> result;
  final VoidCallback? onRetry;

  const ProcessingResultDialog({
    super.key,
    required this.result,
    this.onRetry,
  });

  @override
  State<ProcessingResultDialog> createState() => _ProcessingResultDialogState();
}

class _ProcessingResultDialogState extends State<ProcessingResultDialog> {

  @override
  Widget build(BuildContext context) {
    final ordersCreated = widget.result['orders_created'] ?? 0;
    final errors = widget.result['errors'] as List<dynamic>? ?? [];
    final warnings = widget.result['warnings'] as List<dynamic>? ?? [];
    
    final hasErrors = errors.isNotEmpty;
    final hasWarnings = warnings.isNotEmpty;
    final hasSuccess = ordersCreated > 0;

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            hasErrors ? Icons.error : hasSuccess ? Icons.check_circle : Icons.info,
            color: hasErrors ? Colors.red : hasSuccess ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 8),
          Text(hasErrors ? 'Processing Failed' : hasSuccess ? 'Processing Complete' : 'Processing Result'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Success summary
            if (hasSuccess) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 20),
                    const SizedBox(width: 8),
                    Text('$ordersCreated order${ordersCreated == 1 ? '' : 's'} created successfully'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Errors section
            if (hasErrors) ...[
              const Text(
                'Failed Products:',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
              ),
              const SizedBox(height: 8),
              ...errors.map((error) => _buildErrorItem(error)).toList(),
              const SizedBox(height: 16),
            ],

            // Warnings section
            if (hasWarnings) ...[
              const Text(
                'Warnings:',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
              ),
              const SizedBox(height: 8),
              ...warnings.map((warning) => _buildWarningItem(warning)).toList(),
            ],
          ],
        ),
      ),
      actions: [
        if (hasErrors && widget.onRetry != null)
          TextButton(
            onPressed: widget.onRetry,
            child: const Text('Retry'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildErrorItem(dynamic error) {
    if (error is Map<String, dynamic>) {
      final failedProducts = error['failed_products'] as List<dynamic>? ?? [];
      final message = error['message'] as String? ?? error['error'] as String? ?? 'Unknown error';
      
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.error, color: Colors.red, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(message, style: const TextStyle(fontWeight: FontWeight.w500))),
              ],
            ),
            if (failedProducts.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('Products not found:', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 4),
              ...failedProducts.map((product) => _buildFailedProduct(product)).toList(),
            ],
          ],
        ),
      );
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error, color: Colors.red, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(error.toString())),
        ],
      ),
    );
  }

  Widget _buildFailedProduct(dynamic product) {
    if (product is Map<String, dynamic>) {
      final name = product['original_name'] ?? 'Unknown';
      final quantity = product['quantity'] ?? 1;
      final unit = product['unit'] ?? '';
      final reason = product['failure_reason'] ?? 'Product not found';
      final suggestions = product['suggestions'] as List<dynamic>? ?? [];
      
      return Container(
        margin: const EdgeInsets.only(left: 16, bottom: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.grey.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.close, color: Colors.red, size: 14),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$quantity${unit.isNotEmpty ? ' $unit' : ''} $name - $reason',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            
            // Show suggestions if available
            if (suggestions.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'Did you mean:',
                style: TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              ...suggestions.take(3).map((suggestion) => _buildSuggestion(suggestion)).toList(),
            ],
            
            // Quick add product button
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () {
                    // TODO: Implement quick add product
                    _showQuickAddDialog(name, quantity, unit);
                  },
                  icon: const Icon(Icons.add, size: 14),
                  label: const Text('Quick Add Product', style: TextStyle(fontSize: 11)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }
    
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 4),
      child: Text('• ${product.toString()}', style: const TextStyle(fontSize: 12)),
    );
  }

  Widget _buildSuggestion(dynamic suggestion) {
    if (suggestion is Map<String, dynamic>) {
      final name = suggestion['name'] ?? 'Unknown';
      final confidence = suggestion['confidence'] ?? 0.0;
      final unit = suggestion['unit'] ?? '';
      final price = suggestion['price'] ?? 0.0;
      
      return Padding(
        padding: const EdgeInsets.only(left: 8, bottom: 2),
        child: InkWell(
          onTap: () {
            // TODO: Implement suggestion selection
            _selectSuggestion(suggestion);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lightbulb_outline, color: Colors.blue, size: 12),
                const SizedBox(width: 4),
                Text(
                  '$name${unit.isNotEmpty ? ' ($unit)' : ''} - R${price.toStringAsFixed(2)} (${confidence.toStringAsFixed(0)}% match)',
                  style: const TextStyle(fontSize: 10, color: Colors.blue),
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    return const SizedBox.shrink();
  }

  void _showQuickAddDialog(String productName, dynamic quantity, String unit) async {
    
    final result = await showDialog<dynamic>(
      context: context,
      builder: (context) => QuickAddProductDialog(
        suggestedName: productName,
        quantity: quantity,
        unit: unit,
        onProductAdded: () {
          // Could trigger a refresh or retry here
          widget.onRetry?.call();
        },
      ),
    );
    
    if (result != null) {
      // Product was created successfully
      print('Product created: ${result.name}');
    }
  }

  void _selectSuggestion(Map<String, dynamic> suggestion) {
    
    // Show confirmation dialog for suggestion selection
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Use Suggested Product?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Replace with: ${suggestion['name']}'),
            const SizedBox(height: 8),
            Text('Unit: ${suggestion['unit']}'),
            Text('Price: R${suggestion['price'].toStringAsFixed(2)}'),
            Text('Match confidence: ${suggestion['confidence'].toStringAsFixed(0)}%'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: Implement suggestion replacement in the original message
              print('Using suggestion: ${suggestion['name']}');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Selected "${suggestion['name']}" - you can now retry processing'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Use This Product'),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningItem(dynamic warning) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning, color: Colors.orange, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(warning.toString())),
        ],
      ),
    );
  }
}

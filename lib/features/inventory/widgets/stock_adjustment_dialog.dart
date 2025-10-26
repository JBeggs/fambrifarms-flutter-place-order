import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/inventory_provider.dart';
import '../../../providers/products_provider.dart';
import '../../../services/api_service.dart';
import '../../../widgets/common/error_display.dart';

class StockAdjustmentDialog extends ConsumerStatefulWidget {
  final int? productId;
  final VoidCallback? onAdjustmentComplete;

  const StockAdjustmentDialog({
    super.key,
    this.productId,
    this.onAdjustmentComplete,
  });

  @override
  ConsumerState<StockAdjustmentDialog> createState() => _StockAdjustmentDialogState();
}

class _StockAdjustmentDialogState extends ConsumerState<StockAdjustmentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _reasonController = TextEditingController();
  
  int? _selectedProductId;
  String _adjustmentType = 'increase';
  String _reason = 'manual_adjustment';

  List<Map<String, dynamic>> _adjustmentTypes = [];
  final List<String> _reasons = [
    'manual_adjustment',
    'stock_take',
    'damaged_goods',
    'expired_goods',
    'theft_loss',
    'supplier_delivery',
    'customer_return',
    'production_output',
    'other',
  ];

  @override
  void initState() {
    super.initState();
    _selectedProductId = widget.productId;
    
    // Load adjustment types from API
    _loadAdjustmentTypes();
    
    // Load products if not pre-selected
    if (_selectedProductId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(productsProvider.notifier).loadProducts();
      });
    }
  }

  void _loadAdjustmentTypes() {
    // Load adjustment types from API service
    _adjustmentTypes = ApiService.getFormOptions('adjustment_types');
    if (_adjustmentTypes.isNotEmpty) {
      _adjustmentType = _adjustmentTypes.first['name'] ?? 'increase';
    }
    setState(() {});
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  String _getReasonDisplayName(String reason) {
    switch (reason) {
      case 'manual_adjustment':
        return 'Manual Adjustment';
      case 'stock_take':
        return 'Stock Take Correction';
      case 'damaged_goods':
        return 'Damaged Goods';
      case 'expired_goods':
        return 'Expired Goods';
      case 'theft_loss':
        return 'Theft/Loss';
      case 'supplier_delivery':
        return 'Supplier Delivery';
      case 'customer_return':
        return 'Customer Return';
      case 'production_output':
        return 'Production Output';
      case 'other':
        return 'Other';
      default:
        return reason;
    }
  }

  Future<void> _submitAdjustment() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProductId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a product')),
      );
      return;
    }

    final quantity = double.tryParse(_quantityController.text);
    if (quantity == null || quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid quantity')),
      );
      return;
    }


    final inventoryNotifier = ref.read(inventoryProvider.notifier);
    await inventoryNotifier.adjustStock(
      productId: _selectedProductId!,
      adjustment_type: _adjustmentType == 'decrease' ? 'finished_waste' : 'finished_adjust',
      quantity: quantity.abs(),
      reason: _reason,
      notes: _reasonController.text.trim(),
    );

    final inventoryState = ref.read(inventoryProvider);
    if (inventoryState.error == null && mounted) {
      Navigator.of(context).pop();
      widget.onAdjustmentComplete?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stock adjustment completed successfully')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final productsState = ref.watch(productsProvider);
    final inventoryState = ref.watch(inventoryProvider);

    return AlertDialog(
      title: const Text('Stock Adjustment'),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Selection (if not pre-selected)
              if (_selectedProductId == null) ...[
                const Text('Product *', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  value: _selectedProductId,
                  decoration: const InputDecoration(
                    hintText: 'Select a product',
                    border: OutlineInputBorder(),
                  ),
                  items: productsState.products.map((product) {
                    return DropdownMenuItem<int>(
                      value: product.id,
                      child: Text('${product.name} (${product.unit})'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedProductId = value;
                    });
                  },
                  validator: (value) {
                    if (value == null) {
                      return 'Please select a product';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
              ] else ...[
                // Show selected product info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.inventory_2),
                      const SizedBox(width: 8),
                      Text(
                        'Product ID: $_selectedProductId',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Adjustment Type
              const Text('Adjustment Type *', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _adjustmentType,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
                items: _adjustmentTypes.map((type) {
                  final typeName = type['name'] ?? '';
                  final displayName = type['display_name'] ?? typeName;
                  return DropdownMenuItem<String>(
                    value: typeName,
                    child: Row(
                      children: [
                        Icon(
                          typeName == 'increase' ? Icons.add_circle : Icons.remove_circle,
                          color: typeName == 'increase' ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Text(displayName),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _adjustmentType = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),

              // Quantity
              const Text('Quantity *', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _quantityController,
                decoration: const InputDecoration(
                  hintText: 'Enter quantity to adjust',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a quantity';
                  }
                  final quantity = double.tryParse(value);
                  if (quantity == null || quantity <= 0) {
                    return 'Please enter a valid positive number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Reason
              const Text('Reason *', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _reason,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
                items: _reasons.map((reason) {
                  return DropdownMenuItem<String>(
                    value: reason,
                    child: Text(_getReasonDisplayName(reason)),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _reason = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),

              // Additional Notes
              const Text('Notes', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _reasonController,
                decoration: const InputDecoration(
                  hintText: 'Additional notes (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),

              // Error Display
              if (inventoryState.error != null) ...[
                const SizedBox(height: 16),
                ErrorDisplay(
                  message: inventoryState.error!,
                  onRetry: () => ref.read(inventoryProvider.notifier).clearError(),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: inventoryState.isLoading ? null : _submitAdjustment,
          child: inventoryState.isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Adjust Stock'),
        ),
      ],
    );
  }
}

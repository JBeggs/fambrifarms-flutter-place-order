import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/product.dart';
import '../../../providers/inventory_provider.dart';

class StockEntryDialog extends ConsumerStatefulWidget {
  final Product product;
  final double currentStock;

  const StockEntryDialog({
    super.key,
    required this.product,
    required this.currentStock,
  });

  @override
  ConsumerState<StockEntryDialog> createState() => _StockEntryDialogState();
}

class _StockEntryDialogState extends ConsumerState<StockEntryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _referenceController = TextEditingController();
  final _notesController = TextEditingController();
  final _unitCostController = TextEditingController();
  
  String _movementType = 'stock_take';
  bool _isLoading = false;

  final Map<String, String> _movementTypes = {
    'stock_take': 'Stock Take',
    'receipt': 'Stock Receipt',
    'adjustment': 'Manual Adjustment',
    'waste': 'Waste/Spoilage',
  };

  @override
  void initState() {
    super.initState();
    _unitCostController.text = widget.product.price.toString();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _referenceController.dispose();
    _notesController.dispose();
    _unitCostController.dispose();
    super.dispose();
  }

  Future<void> _submitStockEntry() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final quantity = double.parse(_quantityController.text);
      // final unitCost = double.parse(_unitCostController.text); // Not used in stock take
      
      // For stock take, calculate the difference from current stock
      double adjustmentQuantity;
      String adjustmentType;
      
      if (_movementType == 'stock_take') {
        // Stock take: set to exact quantity (calculate difference)
        adjustmentQuantity = (quantity - widget.currentStock).abs();
        adjustmentType = quantity > widget.currentStock ? 'finished_adjust' : 'finished_waste';
      } else if (_movementType == 'waste') {
        // Waste: always decrease
        adjustmentQuantity = quantity.abs();
        adjustmentType = 'finished_waste';
      } else {
        // Receipt/Adjustment: use quantity as-is
        adjustmentQuantity = quantity.abs();
        adjustmentType = quantity >= 0 ? 'finished_adjust' : 'finished_waste';
      }
      
      // Only proceed if there's an actual change for stock take
      if (_movementType == 'stock_take' && quantity == widget.currentStock) {
        if (mounted) {
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No change in stock level'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
      
      // Ensure notes is never empty
      final notes = '${_referenceController.text}\n${_notesController.text}'.trim();
      final finalNotes = notes.isEmpty ? 'Stock adjustment via Flutter app' : notes;
      
      await ref.read(inventoryProvider.notifier).adjustStock(
        productId: widget.product.id,
        adjustment_type: adjustmentType,
        quantity: adjustmentQuantity,
        reason: _movementType,
        notes: finalNotes,
      );

      // Force refresh inventory data
      await ref.read(inventoryProvider.notifier).refreshAll();
      
      // Force UI refresh
      ref.read(inventoryProvider.notifier).forceRefresh();

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Stock ${_movementTypes[_movementType]} completed successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.inventory_2, color: Theme.of(context).primaryColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Stock Entry'),
                Text(
                  widget.product.name,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Current Stock Info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'Current Stock: ${widget.currentStock.toInt()} ${widget.product.unit}',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Movement Type
                DropdownButtonFormField<String>(
                  value: _movementType,
                  decoration: const InputDecoration(
                    labelText: 'Movement Type',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.category),
                  ),
                  items: _movementTypes.entries.map((entry) {
                    return DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _movementType = value!);
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select a movement type';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Quantity
                TextFormField(
                  controller: _quantityController,
                  decoration: InputDecoration(
                    labelText: 'Quantity',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.numbers),
                    suffixText: widget.product.unit,
                    helperText: _movementType == 'stock_take' 
                        ? 'Enter the actual counted quantity'
                        : 'Enter positive for increase, negative for decrease',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d*')),
                  ],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a quantity';
                    }
                    final quantity = double.tryParse(value);
                    if (quantity == null) {
                      return 'Please enter a valid number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Unit Cost
                TextFormField(
                  controller: _unitCostController,
                  decoration: const InputDecoration(
                    labelText: 'Unit Cost',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.attach_money),
                    prefixText: 'R ',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                  ],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a unit cost';
                    }
                    final cost = double.tryParse(value);
                    if (cost == null || cost < 0) {
                      return 'Please enter a valid cost';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Reference Number
                TextFormField(
                  controller: _referenceController,
                  decoration: const InputDecoration(
                    labelText: 'Reference Number (Optional)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.receipt),
                    helperText: 'Invoice number, batch number, etc.',
                  ),
                ),
                const SizedBox(height: 16),

                // Notes
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes (Optional)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.note),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submitStockEntry,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Submit'),
        ),
      ],
    );
  }
}

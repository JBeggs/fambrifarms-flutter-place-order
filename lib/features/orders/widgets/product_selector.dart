import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/product.dart' as product_model;
import '../../../models/order.dart';
import '../../../providers/products_provider.dart';
import '../../../core/professional_theme.dart';

class ProductSelector extends ConsumerStatefulWidget {
  final Function(OrderItem) onProductAdded;
  final List<OrderItem> currentItems;

  const ProductSelector({
    super.key,
    required this.onProductAdded,
    required this.currentItems,
  });

  @override
  ConsumerState<ProductSelector> createState() => _ProductSelectorState();
}

class _ProductSelectorState extends ConsumerState<ProductSelector> {
  product_model.Product? _selectedProduct;
  final _quantityController = TextEditingController(text: '1');
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _quantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _addProduct() {
    if (_selectedProduct == null) return;

    final quantity = double.tryParse(_quantityController.text) ?? 1.0;
    if (quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid quantity')),
      );
      return;
    }

    // Check if product has enough stock
    if (quantity > _selectedProduct!.stockLevel) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Insufficient stock. Available: ${_selectedProduct!.stockLevel} ${_selectedProduct!.unit}',
          ),
          backgroundColor: AppColors.accentRed,
        ),
      );
      return;
    }

    // Create order item - convert from product_model.Product to order.Product
    final orderProduct = Product(
      id: _selectedProduct!.id,
      name: _selectedProduct!.name,
      price: _selectedProduct!.price,
      isActive: _selectedProduct!.isActive,
      description: _selectedProduct!.description,
    );

    final orderItem = OrderItem(
      id: DateTime.now().millisecondsSinceEpoch, // Temporary ID
      product: orderProduct,
      quantity: quantity,
      unit: _selectedProduct!.unit,
      price: _selectedProduct!.price,
      totalPrice: _selectedProduct!.price * quantity,
      notes: _notesController.text.isEmpty ? null : _notesController.text,
    );

    widget.onProductAdded(orderItem);

    // Reset form
    setState(() {
      _selectedProduct = null;
    });
    _quantityController.text = '1';
    _notesController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final productsState = ref.watch(productsProvider);

    if (productsState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (productsState.error != null) {
      return Text(
        'Error loading products: ${productsState.error}',
        style: TextStyle(color: AppColors.accentRed),
      );
    }

    final availableProducts = productsState.products
        .where((product) => product.stockLevel > 0)
        .toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.professionalCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add Products to Order',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // Product Selection Dropdown
          DropdownButtonFormField<product_model.Product>(
            value: _selectedProduct,
            decoration: InputDecoration(
              labelText: 'Select Product',
              labelStyle: TextStyle(color: AppColors.textSecondary),
              border: OutlineInputBorder(
                borderSide: BorderSide(color: AppColors.borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: AppColors.borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: AppColors.primaryGreen),
              ),
            ),
            dropdownColor: AppColors.surfaceDark,
            items: availableProducts.map((product) {
              return DropdownMenuItem<product_model.Product>(
                value: product,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: TextStyle(color: AppColors.textPrimary),
                    ),
                    Text(
                      'R${product.price.toStringAsFixed(2)} • Stock: ${product.stockLevel} ${product.unit}',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            onChanged: (product) {
              setState(() {
                _selectedProduct = product;
              });
            },
          ),
          const SizedBox(height: 16),

          if (_selectedProduct != null) ...[
            // Quantity Input
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _quantityController,
                    decoration: InputDecoration(
                      labelText: 'Quantity (${_selectedProduct!.unit})',
                      labelStyle: TextStyle(color: AppColors.textSecondary),
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: AppColors.borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: AppColors.borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: AppColors.primaryGreen),
                      ),
                    ),
                    style: TextStyle(color: AppColors.textPrimary),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.borderColor),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Total',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        'R${(_selectedProduct!.price * (double.tryParse(_quantityController.text) ?? 1)).toStringAsFixed(2)}',
                        style: TextStyle(
                          color: AppColors.primaryGreen,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Notes Input
            TextFormField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: 'Notes (optional)',
                labelStyle: TextStyle(color: AppColors.textSecondary),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.primaryGreen),
                ),
              ),
              style: TextStyle(color: AppColors.textPrimary),
              maxLines: 2,
            ),
            const SizedBox(height: 16),

            // Add Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _addProduct,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: AppColors.textPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Add to Order'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/order.dart';
import '../../models/product.dart' as ProductModel;
import '../../services/api_service.dart';
import '../../providers/orders_provider.dart';
import '../../providers/products_provider.dart';

class EditOrderPage extends ConsumerStatefulWidget {
  final Order order;

  const EditOrderPage({super.key, required this.order});

  @override
  ConsumerState<EditOrderPage> createState() => _EditOrderPageState();
}

class _EditOrderPageState extends ConsumerState<EditOrderPage> {
  late Order _currentOrder;
  bool _isLoading = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _currentOrder = widget.order;
  }

  void _markAsChanged() {
    if (!_hasChanges) {
      setState(() {
        _hasChanges = true;
      });
    }
  }

  Future<void> _saveChanges() async {
    // Individual items are now saved automatically when edited
    // This method is kept for potential future order-level changes
    setState(() {
      _hasChanges = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All changes have been saved automatically'),
          backgroundColor: Colors.green,
        ),
      );
      context.pop();
    }
  }

  void _showAddItemDialog() {
    showDialog(
      context: context,
      builder: (context) => _AddItemDialog(
        orderId: _currentOrder.id,
        onItemAdded: () {
          _markAsChanged();
          ref.read(ordersProvider.notifier).refreshOrders();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Order ${_currentOrder.orderNumber}'),
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
        actions: [
          if (_hasChanges)
            TextButton(
              onPressed: _isLoading ? null : _saveChanges,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Save Changes'),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order Summary Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.receipt_long, color: Theme.of(context).primaryColor),
                        const SizedBox(width: 8),
                        Text(
                          'Order Summary',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Total: R${_currentOrder.totalAmount?.toStringAsFixed(2) ?? '0.00'}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildInfoTile('Customer', _currentOrder.restaurant.displayName),
                        ),
                        Expanded(
                          child: _buildInfoTile('Order Date', _currentOrder.orderDate),
                        ),
                        Expanded(
                          child: _buildInfoTile('Delivery Date', _currentOrder.deliveryDate),
                        ),
                        Expanded(
                          child: _buildInfoTile('Status', _currentOrder.statusDisplay),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Order Items Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.shopping_cart, color: Theme.of(context).primaryColor),
                        const SizedBox(width: 8),
                        Text(
                          'Order Items',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${_currentOrder.items.length} item${_currentOrder.items.length == 1 ? '' : 's'}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Items List
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _currentOrder.items.length,
                      separatorBuilder: (context, index) => const Divider(),
                      itemBuilder: (context, index) {
                        final item = _currentOrder.items[index];
                        return _EditableOrderItem(
                          item: item,
                          onItemUpdated: (updatedItem) async {
                            try {
                              setState(() {
                                _isLoading = true;
                              });
                              
                              // Prepare item data for API
                              final itemData = {
                                'quantity': updatedItem.quantity,
                                'unit': updatedItem.unit,
                                'price': updatedItem.price,
                                'total_price': updatedItem.totalPrice,
                                'manually_corrected': updatedItem.manuallyCorrected,
                                'notes': updatedItem.notes,
                              };
                              
                              // Update item in backend
                              await ref.read(ordersProvider.notifier).updateOrderItem(
                                _currentOrder.id,
                                updatedItem.id,
                                itemData,
                              );
                              
                              // Update local state
                              setState(() {
                                _currentOrder.items[index] = updatedItem;
                                _isLoading = false;
                              });
                              
                              // Show success message
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Order item updated successfully'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            } catch (e) {
                              setState(() {
                                _isLoading = false;
                              });
                              
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Failed to update order item: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                          onItemDeleted: () async {
                            try {
                              setState(() {
                                _isLoading = true;
                              });
                              
                              // Delete item from backend
                              await ref.read(ordersProvider.notifier).deleteOrderItem(
                                _currentOrder.id,
                                item.id,
                              );
                              
                              // Update local state
                              setState(() {
                                _currentOrder.items.removeAt(index);
                                _isLoading = false;
                              });
                              
                              // Show success message
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Order item deleted successfully'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            } catch (e) {
                              setState(() {
                                _isLoading = false;
                              });
                              
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Failed to delete order item: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                        );
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Add Item Button
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: _showAddItemDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Item'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Original WhatsApp Message (if available)
            if (_currentOrder.originalMessage != null && _currentOrder.originalMessage!.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.chat, color: Theme.of(context).primaryColor),
                          const SizedBox(width: 8),
                          Text(
                            'Original WhatsApp Message',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Text(
                          _currentOrder.originalMessage!,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// Separate dialog widget for adding items
class _AddItemDialog extends ConsumerStatefulWidget {
  final int orderId;
  final VoidCallback onItemAdded;

  const _AddItemDialog({
    required this.orderId,
    required this.onItemAdded,
  });

  @override
  ConsumerState<_AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends ConsumerState<_AddItemDialog> {
  ProductModel.Product? selectedProduct;
  final quantityController = TextEditingController();
  final priceController = TextEditingController();
  String selectedUnit = 'piece';
  List<String> availableUnits = ['piece'];
  bool isLoadingUnits = true;
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadUnits();
  }

  void _loadUnits() async {
    try {
      final units = await ref.read(apiServiceProvider).getUnitsOfMeasure();
      if (mounted) {
        setState(() {
          availableUnits = units
              .where((unit) => unit['is_active'] == true)
              .map<String>((unit) => unit['abbreviation'] as String)
              .toList();
          availableUnits.sort();
          isLoadingUnits = false;
          
          if (!availableUnits.contains(selectedUnit)) {
            selectedUnit = availableUnits.isNotEmpty ? availableUnits.first : 'piece';
          }
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          isLoadingUnits = false;
          availableUnits = ['piece', 'kg', 'box', 'bunch', 'each'];
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add New Item'),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Product Search - Direct Implementation
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Search Products',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) {
                    setState(() {
                      searchQuery = value;
                    });
                  },
                ),
                if (searchQuery.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Consumer(
                      builder: (context, ref, child) {
                        final productsState = ref.watch(productsProvider);
                        final filteredProducts = productsState.products
                            .where((p) => p.name.toLowerCase().contains(searchQuery.toLowerCase()))
                            .take(10)
                            .toList();
                        
                        return ListView.builder(
                          itemCount: filteredProducts.length,
                          itemBuilder: (context, index) {
                            final product = filteredProducts[index];
                            return ListTile(
                              leading: CircleAvatar(
                                child: Text(product.name.substring(0, 1).toUpperCase()),
                              ),
                              title: Text(product.name),
                              subtitle: Text('R${product.price.toStringAsFixed(2)} per ${product.unit}'),
                              onTap: () {
                                print('DEBUG: Direct ListTile onTap called for ${product.name}');
                        setState(() {
                          selectedProduct = product;
                          priceController.text = product.price.toStringAsFixed(2);
                          // Set unit to product's default unit
                          if (availableUnits.contains(product.unit)) {
                            selectedUnit = product.unit;
                          } else {
                            // Add product's unit to available units if not present
                            availableUnits.add(product.unit);
                            selectedUnit = product.unit;
                          }
                          searchQuery = '';
                        });
                                print('DEBUG: Direct selection completed');
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
            
            // Selected Product Display
            if (selectedProduct != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  border: Border.all(color: Colors.green[200]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '✓ Selected: ${selectedProduct!.name}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    Text(
                      'Department: ${selectedProduct!.department}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    Text(
                      'Base Price: R${selectedProduct!.price.toStringAsFixed(2)} per ${selectedProduct!.unit}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 16),
            
            // Quantity and Unit
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: quantityController,
                    decoration: const InputDecoration(
                      labelText: 'Quantity',
                      border: OutlineInputBorder(),
                      hintText: 'e.g., 5',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: isLoadingUnits
                      ? TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'Unit',
                            border: OutlineInputBorder(),
                            suffixIcon: SizedBox(
                              width: 20,
                              height: 20,
                              child: Padding(
                                padding: EdgeInsets.all(12.0),
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          ),
                          enabled: false,
                          initialValue: 'Loading...',
                        )
                      : DropdownButtonFormField<String>(
                          value: availableUnits.contains(selectedUnit) ? selectedUnit : null,
                          decoration: InputDecoration(
                            labelText: 'Unit',
                            border: const OutlineInputBorder(),
                            helperText: '${availableUnits.length} units available',
                          ),
                          items: availableUnits.map((unit) {
                            return DropdownMenuItem<String>(
                              value: unit,
                              child: Text(unit),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                selectedUnit = value;
                              });
                            }
                          },
                        ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Price
            TextFormField(
              controller: priceController,
              decoration: const InputDecoration(
                labelText: 'Price per Unit',
                border: OutlineInputBorder(),
                prefixText: 'R',
                hintText: 'e.g., 25.50',
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
          onPressed: selectedProduct == null || 
                      quantityController.text.isEmpty || 
                      priceController.text.isEmpty
              ? null
              : () async {
                  try {
                    final quantity = double.tryParse(quantityController.text);
                    final price = double.tryParse(priceController.text);
                    
                    if (quantity == null || price == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter valid quantity and price'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    
                    final apiService = ref.read(apiServiceProvider);
                    
                    await apiService.dio.post(
                      '/orders/${widget.orderId}/items/',
                      data: {
                        'product_name': selectedProduct!.name,
                        'quantity': quantity,
                        'unit': selectedUnit,
                        'price': price,
                      },
                    );
                    
                    Navigator.of(context).pop();
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Added ${selectedProduct!.name} to order'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    
                    // Call the callback to refresh the parent
                    widget.onItemAdded();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to add item: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
          child: const Text('Add Item'),
        ),
      ],
    );
  }
}

class _EditableOrderItem extends StatefulWidget {
  final OrderItem item;
  final Future<void> Function(OrderItem) onItemUpdated;
  final Future<void> Function() onItemDeleted;

  const _EditableOrderItem({
    required this.item,
    required this.onItemUpdated,
    required this.onItemDeleted,
  });

  @override
  State<_EditableOrderItem> createState() => _EditableOrderItemState();
}

class _EditableOrderItemState extends State<_EditableOrderItem> {
  late TextEditingController _quantityController;
  late TextEditingController _priceController;
  late String _selectedUnit;
  List<String> _availableUnits = ['piece'];
  bool _isEditing = false;
  bool _isLoadingUnits = false;

  @override
  void initState() {
    super.initState();
    _quantityController = TextEditingController(text: widget.item.quantity.toString());
    _priceController = TextEditingController(text: widget.item.price.toStringAsFixed(2));
    // Use the item's current unit first (respects manual corrections), then fall back to product's default unit
    _selectedUnit = widget.item.unit ?? widget.item.product.unit ?? 'piece';
    _loadUnits();
  }

  void _loadUnits() async {
    setState(() {
      _isLoadingUnits = true;
    });

    try {
      // Get the API service from the context
      final container = ProviderScope.containerOf(context);
      final apiService = container.read(apiServiceProvider);
      
      final units = await apiService.getUnitsOfMeasure();
      if (mounted) {
        setState(() {
          _availableUnits = units
              .where((unit) => unit['is_active'] == true)
              .map<String>((unit) => unit['abbreviation'] as String)
              .toList();
          _availableUnits.sort();
          _isLoadingUnits = false;
          
          // Ensure selected unit is in the list
          if (!_availableUnits.contains(_selectedUnit)) {
            _availableUnits.add(_selectedUnit);
          }
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isLoadingUnits = false;
          // Fallback units on error
          _availableUnits = ['piece', 'kg', 'box', 'bunch', 'each', 'punnet', 'head', 'packet'];
          if (!_availableUnits.contains(_selectedUnit)) {
            _availableUnits.add(_selectedUnit);
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    final quantity = double.tryParse(_quantityController.text);
    final price = double.tryParse(_priceController.text);

    if (quantity == null || price == null || quantity <= 0 || price < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter valid quantity and price'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final updatedItem = OrderItem(
      id: widget.item.id,
      product: widget.item.product,
      quantity: quantity,
      unit: _selectedUnit,
      price: price,
      totalPrice: quantity * price,
      originalText: widget.item.originalText,
      confidenceScore: widget.item.confidenceScore,
      manuallyCorrected: true,
      notes: widget.item.notes,
    );

    await widget.onItemUpdated(updatedItem);
    setState(() {
      _isEditing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isEditing) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.edit,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.item.product.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TextFormField(
                        controller: _quantityController,
                        decoration: InputDecoration(
                          labelText: 'Quantity',
                          labelStyle: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.transparent,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        keyboardType: TextInputType.number,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _isLoadingUnits
                          ? TextFormField(
                              decoration: InputDecoration(
                                labelText: 'Unit',
                                labelStyle: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide.none,
                                ),
                                filled: true,
                                fillColor: Colors.transparent,
                                suffixIcon: const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: Padding(
                                    padding: EdgeInsets.all(12.0),
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                              enabled: false,
                              initialValue: 'Loading...',
                            )
                          : DropdownButtonFormField<String>(
                              value: _availableUnits.contains(_selectedUnit) ? _selectedUnit : null,
                              decoration: InputDecoration(
                                labelText: 'Unit',
                                labelStyle: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide.none,
                                ),
                                filled: true,
                                fillColor: Colors.transparent,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              items: _availableUnits.map((unit) {
                                return DropdownMenuItem<String>(
                                  value: unit,
                                  child: Text(
                                    unit,
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onSurface,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _selectedUnit = value;
                                  });
                                }
                              },
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TextFormField(
                        controller: _priceController,
                        decoration: InputDecoration(
                          labelText: 'Price',
                          labelStyle: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.transparent,
                          prefixText: 'R ',
                          prefixStyle: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        keyboardType: TextInputType.number,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => setState(() => _isEditing = false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _saveChanges,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 2,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.save, size: 18),
                        const SizedBox(width: 6),
                        const Text(
                          'Save',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: ExpansionTile(
        title: Row(
          children: [
            Expanded(child: Text(widget.item.product.name)),
            if (widget.item.confidenceScore != null) ...[
              const SizedBox(width: 8),
              _buildConfidenceChip(widget.item.confidenceScore!),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${widget.item.quantity} ${widget.item.unit} × R${widget.item.price.toStringAsFixed(2)}'),
            if (widget.item.originalText != null && widget.item.originalText!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Original: "${widget.item.originalText}"',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('R${widget.item.totalPrice.toStringAsFixed(2)}', 
                 style: const TextStyle(fontWeight: FontWeight.bold)),
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'edit') {
                  setState(() => _isEditing = true);
                } else if (value == 'reprocess') {
                  await _showReprocessDialog();
                } else if (value == 'delete') {
                  await widget.onItemDeleted();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                if (widget.item.originalText != null && widget.item.originalText!.isNotEmpty)
                  const PopupMenuItem(
                    value: 'reprocess', 
                    child: Row(
                      children: [
                        Icon(Icons.refresh, size: 16),
                        SizedBox(width: 8),
                        Text('Reprocess with Suggestions'),
                      ],
                    ),
                  ),
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ],
        ),
        children: [
          if (widget.item.pricingBreakdown != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
                        const SizedBox(width: 4),
                        Text(
                          'Pricing Breakdown',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildPricingDetailRow('Customer Segment', widget.item.pricingBreakdown!.customerSegmentDisplay),
                    _buildPricingDetailRow('Pricing Source', widget.item.pricingBreakdown!.pricingSourceDisplay),
                    _buildPricingDetailRow('Base Price', 'R${widget.item.pricingBreakdown!.basePrice.toStringAsFixed(2)}'),
                    _buildPricingDetailRow('Customer Price', 'R${widget.item.pricingBreakdown!.customerPrice.toStringAsFixed(2)}'),
                    if (widget.item.pricingBreakdown!.markupPercentage != 0)
                      _buildPricingDetailRow('Markup', widget.item.pricingBreakdown!.markupDisplay),
                    if (widget.item.pricingBreakdown!.pricingRule != null)
                      _buildPricingDetailRow('Pricing Rule', widget.item.pricingBreakdown!.pricingRule!.name),
                    if (widget.item.pricingBreakdown!.priceListItem != null)
                      _buildPricingDetailRow('Price List', widget.item.pricingBreakdown!.priceListItem!.priceListName),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPricingDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
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

  Future<void> _showReprocessDialog() async {
    if (widget.item.originalText == null || widget.item.originalText!.isEmpty) {
      return;
    }

    // Show a simpler reprocess dialog for now
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.refresh,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Reprocess Item'),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Original Text:',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.blue[700],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '"${widget.item.originalText}"',
                    style: const TextStyle(
                      fontStyle: FontStyle.italic,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Current Match:',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.blue[700],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${widget.item.product.name} (${widget.item.confidenceScore?.toStringAsFixed(1) ?? 'Unknown'}% confidence)',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'This will reprocess the item using the latest parsing and matching improvements. The item will be sent back through the improved suggestions system.',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reprocess'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      // For now, show a message that this feature will be fully implemented soon
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.info, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Reprocessing "${widget.item.originalText}" with improved suggestions - Full implementation coming soon!'),
              ),
            ],
          ),
          backgroundColor: Colors.blue,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }
}
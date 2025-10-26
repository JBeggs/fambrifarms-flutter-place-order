import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AddProductDialog extends ConsumerStatefulWidget {
  const AddProductDialog({super.key});

  @override
  ConsumerState<AddProductDialog> createState() => _AddProductDialogState();
}

class _AddProductDialogState extends ConsumerState<AddProductDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockLevelController = TextEditingController();
  final _minimumStockController = TextEditingController();
  final _unitController = TextEditingController();
  final _skuController = TextEditingController();
  
  String _selectedDepartment = 'Vegetables';
  bool _isActive = true;
  bool _isLoading = false;

  final List<String> _departments = [
    'Vegetables',
    'Fruits',
    'Herbs',
    'Dairy',
    'Meat',
    'Bakery',
    'Pantry',
    'Beverages',
    'Other',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _stockLevelController.dispose();
    _minimumStockController.dispose();
    _unitController.dispose();
    _skuController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 600,
        height: 700,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.add_box, size: 28, color: Color(0xFF2D5016)),
                const SizedBox(width: 12),
                Text(
                  'Add New Product',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2D5016),
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Form
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Basic Information Section
                      Text(
                        'Basic Information',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF2D5016),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Product Name
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Product Name *',
                          prefixIcon: Icon(Icons.inventory),
                          border: OutlineInputBorder(),
                          hintText: 'e.g., Organic Tomatoes',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Product name is required';
                          }
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Department and Active Status Row
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedDepartment,
                              decoration: const InputDecoration(
                                labelText: 'Department *',
                                prefixIcon: Icon(Icons.category),
                                border: OutlineInputBorder(),
                              ),
                              items: _departments.map((department) {
                                return DropdownMenuItem(
                                  value: department,
                                  child: Text(department),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedDepartment = value!;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Row(
                              children: [
                                Checkbox(
                                  value: _isActive,
                                  onChanged: (value) {
                                    setState(() {
                                      _isActive = value!;
                                    });
                                  },
                                ),
                                const Text('Active Product'),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Description
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          prefixIcon: Icon(Icons.description),
                          border: OutlineInputBorder(),
                          hintText: 'Product description and details',
                        ),
                        maxLines: 3,
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Pricing & Inventory Section
                      Text(
                        'Pricing & Inventory',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF2D5016),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Price and Unit Row
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _priceController,
                              decoration: const InputDecoration(
                                labelText: 'Price (R) *',
                                prefixIcon: Icon(Icons.attach_money),
                                border: OutlineInputBorder(),
                                hintText: '0.00',
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Price is required';
                                }
                                if (double.tryParse(value) == null) {
                                  return 'Enter a valid price';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _unitController,
                              decoration: const InputDecoration(
                                labelText: 'Unit of Measure',
                                prefixIcon: Icon(Icons.straighten),
                                border: OutlineInputBorder(),
                                hintText: 'kg, piece, bunch, etc.',
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Stock Level and Minimum Stock Row
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _stockLevelController,
                              decoration: const InputDecoration(
                                labelText: 'Initial Stock Level',
                                prefixIcon: Icon(Icons.inventory_2),
                                border: OutlineInputBorder(),
                                hintText: '0',
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _minimumStockController,
                              decoration: const InputDecoration(
                                labelText: 'Minimum Stock Level',
                                prefixIcon: Icon(Icons.warning),
                                border: OutlineInputBorder(),
                                hintText: '5',
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Product Identification Section
                      Text(
                        'Product Identification',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF2D5016),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // SKU Row
                      TextFormField(
                        controller: _skuController,
                        decoration: const InputDecoration(
                          labelText: 'SKU (Stock Keeping Unit)',
                          prefixIcon: Icon(Icons.qr_code),
                          border: OutlineInputBorder(),
                          hintText: 'AUTO-GENERATED',
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
            
            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _isLoading ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2D5016),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Add Product'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // TODO: Prepare product data when API is ready
      // final productData = {
      //   'name': _nameController.text.trim(),
      //   'description': _descriptionController.text.trim(),
      //   'price': double.parse(_priceController.text.trim()),
      //   'department': _selectedDepartment,
      //   'is_active': _isActive,
      //   'stock_level': _stockLevelController.text.isNotEmpty 
      //       ? double.parse(_stockLevelController.text.trim()) 
      //       : 0.0,
      //   'minimum_stock': _minimumStockController.text.isNotEmpty 
      //       ? double.parse(_minimumStockController.text.trim()) 
      //       : 5.0,
      //   'unit_of_measure': _unitController.text.trim().isNotEmpty 
      //       ? _unitController.text.trim() 
      //       : 'piece',
      //   'sku': _skuController.text.trim(),
      // };

      // TODO: Implement actual API call when backend endpoint is ready
      // await ref.read(productsProvider.notifier).addProduct(productData);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Add product functionality will be implemented when backend API is ready'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding product: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}

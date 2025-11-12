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
  bool _unlimitedStock = false;
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
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Add New Product'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Basic Information Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                    
                    // Department
                    DropdownButtonFormField<String>(
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
                    
                    const SizedBox(height: 16),
                    
                  // Active Status and Unlimited Stock
                  Row(
                    children: [
                      Checkbox(
                        value: _isActive,
                        onChanged: (value) {
                          setState(() {
                            _isActive = value!;
                          });
                        },
                      ),
                      const Text('Active'),
                    ],
                  ),
                  
                  const SizedBox(height: 8),
                  
                  Row(
                    children: [
                      Checkbox(
                        value: _unlimitedStock,
                        onChanged: (value) {
                          setState(() {
                            _unlimitedStock = value!;
                          });
                        },
                      ),
                      const Expanded(
                        child: Text(
                          'Always Available (Garden-Grown)',
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.only(left: 48, top: 4),
                    child: Text(
                      'Orders won\'t reserve stock for this product',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
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
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Pricing & Inventory Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pricing & Inventory',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF2D5016),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Price
                    TextFormField(
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
                    
                    const SizedBox(height: 16),
                    
                    // Unit
                    TextFormField(
                      controller: _unitController,
                      decoration: const InputDecoration(
                        labelText: 'Unit of Measure',
                        prefixIcon: Icon(Icons.straighten),
                        border: OutlineInputBorder(),
                        hintText: 'kg, piece, bunch, etc.',
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Stock Level
                    TextFormField(
                      controller: _stockLevelController,
                      decoration: const InputDecoration(
                        labelText: 'Initial Stock Level',
                        prefixIcon: Icon(Icons.inventory_2),
                        border: OutlineInputBorder(),
                        hintText: '0',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Minimum Stock
                    TextFormField(
                      controller: _minimumStockController,
                      decoration: const InputDecoration(
                        labelText: 'Minimum Stock Level',
                        prefixIcon: Icon(Icons.warning),
                        border: OutlineInputBorder(),
                        hintText: '5',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Product Identification Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Product Identification',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF2D5016),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // SKU
                    TextFormField(
                      controller: _skuController,
                      decoration: const InputDecoration(
                        labelText: 'SKU (Stock Keeping Unit)',
                        prefixIcon: Icon(Icons.qr_code),
                        border: OutlineInputBorder(),
                        hintText: 'AUTO-GENERATED',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
          ],
        ),
      ),
      
      // Bottom Action Bar
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2D5016),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
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
              ),
            ],
          ),
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/product.dart';
import '../../../services/api_service.dart';
import '../../../providers/products_provider.dart';

class EditProductDialog extends ConsumerStatefulWidget {
  final Product product;

  const EditProductDialog({
    super.key,
    required this.product,
  });

  @override
  ConsumerState<EditProductDialog> createState() => _EditProductDialogState();
}

class _EditProductDialogState extends ConsumerState<EditProductDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockLevelController = TextEditingController();
  final _minimumStockController = TextEditingController();
  final _skuController = TextEditingController();
  
  String _selectedDepartment = '';
  String _selectedUnit = '';
  bool _isActive = true;
  bool _unlimitedStock = false;
  bool _isLoading = true;

  List<Map<String, dynamic>> _departments = [];
  List<Map<String, dynamic>> _units = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final apiService = ref.read(apiServiceProvider);
      print('[EDIT_PRODUCT] Loading departments and units...');
      
      final departments = await apiService.getDepartments();
      print('[EDIT_PRODUCT] Loaded ${departments.length} departments: ${departments.map((d) => d['name']).join(', ')}');
      
      final units = await apiService.getUnitsOfMeasure();
      print('[EDIT_PRODUCT] Loaded ${units.length} units');
      print('[EDIT_PRODUCT] First unit structure: ${units.isNotEmpty ? units.first : "none"}');
      
      // Filter out null values and create proper unit list
      final filteredUnits = units.where((u) => u['name'] != null).toList();
      print('[EDIT_PRODUCT] Filtered units: ${filteredUnits.map((u) => u['name']).join(', ')}');
      
      setState(() {
        _departments = departments;
        _units = filteredUnits;
        _isLoading = false;
      });
      
      _populateFields();
    } catch (e) {
      print('[EDIT_PRODUCT] Error loading data: $e');
      // Fallback to hardcoded values if API fails
      setState(() {
        _departments = [
          {'id': 1, 'name': 'Vegetables'},
          {'id': 2, 'name': 'Fruits'},
          {'id': 3, 'name': 'Herbs & Spices'},
          {'id': 4, 'name': 'Mushrooms'},
          {'id': 5, 'name': 'Specialty Items'},
        ];
        _units = [
          {'id': 1, 'name': 'kg', 'display_name': 'Kilogram'},
          {'id': 2, 'name': 'g', 'display_name': 'Gram'},
          {'id': 3, 'name': 'each', 'display_name': 'Each'},
          {'id': 4, 'name': 'piece', 'display_name': 'Piece'},
          {'id': 5, 'name': 'bunch', 'display_name': 'Bunch'},
          {'id': 6, 'name': 'box', 'display_name': 'Box'},
          {'id': 7, 'name': 'bag', 'display_name': 'Bag'},
        ];
        _isLoading = false;
      });
      _populateFields();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Using offline data. API error: $e')),
        );
      }
    }
  }

  void _populateFields() {
    print('[EDIT_PRODUCT] Populating fields for product: ${widget.product.name}');
    print('[EDIT_PRODUCT] Product stockLevel: ${widget.product.stockLevel}');
    print('[EDIT_PRODUCT] Product minimumStock: ${widget.product.minimumStock}');
    print('[EDIT_PRODUCT] Product price: ${widget.product.price}');
    
    _nameController.text = widget.product.name;
    _descriptionController.text = widget.product.description ?? '';
    _priceController.text = widget.product.price.toString();
    _stockLevelController.text = widget.product.stockLevel.toString();
    _minimumStockController.text = widget.product.minimumStock.toString();
    _skuController.text = widget.product.sku ?? '';
    
    print('[EDIT_PRODUCT] Set stockLevelController to: ${_stockLevelController.text}');
    print('[EDIT_PRODUCT] Set minimumStockController to: ${_minimumStockController.text}');
    
    _selectedDepartment = widget.product.department;
    _selectedUnit = widget.product.unit;
    _isActive = widget.product.isActive;
    _unlimitedStock = widget.product.unlimitedStock;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _stockLevelController.dispose();
    _minimumStockController.dispose();
    _skuController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          title: const Text('Edit Product'),
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading product data...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Edit Product'),
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
            // Product Info Banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Editing: ${widget.product.name}',
                      style: const TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
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
                      items: _departments.map<DropdownMenuItem<String>>((department) {
                        return DropdownMenuItem<String>(
                          value: department['name'],
                          child: Text(department['name']),
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
                    DropdownButtonFormField<String>(
                      value: _selectedUnit.isNotEmpty && _units.any((u) => u['name'] == _selectedUnit) ? _selectedUnit : null,
                      decoration: const InputDecoration(
                        labelText: 'Unit of Measure',
                        prefixIcon: Icon(Icons.straighten),
                        border: OutlineInputBorder(),
                      ),
                      items: _units.map<DropdownMenuItem<String>>((unit) {
                        final name = unit['name'] ?? '';
                        final displayName = unit['display_name'] ?? unit['name'] ?? '';
                        return DropdownMenuItem<String>(
                          value: name,
                          child: Text(displayName.isNotEmpty ? displayName : name),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedUnit = newValue ?? '';
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select a unit of measure';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Stock Level
                    TextFormField(
                      controller: _stockLevelController,
                      decoration: const InputDecoration(
                        labelText: 'Current Stock Level',
                        prefixIcon: Icon(Icons.inventory_2),
                        border: OutlineInputBorder(),
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
                      : const Text('Update Product'),
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
      // Find department and unit IDs
      final departmentId = _departments.firstWhere(
        (d) => d['name'] == _selectedDepartment,
        orElse: () => {'id': null},
      )['id'];
      
      // Unit should be the name string (e.g., 'kg', 'piece', 'box')
      final unitName = _selectedUnit;
      
      print('[EDIT_PRODUCT] Selected department: $_selectedDepartment -> ID: $departmentId');
      print('[EDIT_PRODUCT] Selected unit: $_selectedUnit -> name: $unitName');

      final productData = {
        'id': widget.product.id,
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'price': double.parse(_priceController.text.trim()),
        'department': departmentId,
        'is_active': _isActive,
        'unlimited_stock': _unlimitedStock,
        'stock_level': _stockLevelController.text.isNotEmpty 
            ? double.parse(_stockLevelController.text.trim()) 
            : 0.0,
        'minimum_stock': _minimumStockController.text.isNotEmpty 
            ? double.parse(_minimumStockController.text.trim()) 
            : 5.0,
        'unit': unitName,
        'sku': _skuController.text.trim(),
      };

      print('[EDIT_PRODUCT] Sending productData: $productData');

      final apiService = ref.read(apiServiceProvider);
      await apiService.updateProduct(widget.product.id, productData);

      if (mounted) {
        // Refresh the products list to show updated data
        ref.read(productsProvider.notifier).refresh();
        
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Product updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating product: $e'),
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

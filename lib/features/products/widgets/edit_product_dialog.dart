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
      print('[EDIT_PRODUCT] Loaded ${units.length} units: ${units.map((u) => u['abbreviation']).join(', ')}');
      
      setState(() {
        _departments = departments;
        _units = units;
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
          {'id': 1, 'name': 'Kilogram', 'abbreviation': 'kg'},
          {'id': 2, 'name': 'Gram', 'abbreviation': 'g'},
          {'id': 3, 'name': 'Each', 'abbreviation': 'each'},
          {'id': 4, 'name': 'Piece', 'abbreviation': 'piece'},
          {'id': 5, 'name': 'Bunch', 'abbreviation': 'bunch'},
          {'id': 6, 'name': 'Box', 'abbreviation': 'box'},
          {'id': 7, 'name': 'Bag', 'abbreviation': 'bag'},
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
      return const Dialog(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading product data...'),
            ],
          ),
        ),
      );
    }

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
                const Icon(Icons.edit, size: 28, color: Color(0xFF2D5016)),
                const SizedBox(width: 12),
                Text(
                  'Edit Product',
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
            
            const SizedBox(height: 8),
            
            // Product info subtitle
            Text(
              'Editing: ${widget.product.name}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
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
                            child: DropdownButtonFormField<String>(
                              value: _selectedUnit.isNotEmpty && _units.any((u) => u['abbreviation'] == _selectedUnit) ? _selectedUnit : null,
                              decoration: const InputDecoration(
                                labelText: 'Unit of Measure',
                                prefixIcon: Icon(Icons.straighten),
                                border: OutlineInputBorder(),
                              ),
                              items: _units.map<DropdownMenuItem<String>>((unit) {
                                return DropdownMenuItem<String>(
                                  value: unit['abbreviation'],
                                  child: Text('${unit['name']} (${unit['abbreviation']})'),
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
                                labelText: 'Current Stock Level',
                                prefixIcon: Icon(Icons.inventory_2),
                                border: OutlineInputBorder(),
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
                      : const Text('Update Product'),
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
      // Find department and unit IDs
      final departmentId = _departments.firstWhere(
        (d) => d['name'] == _selectedDepartment,
        orElse: () => {'id': null},
      )['id'];
      
      // Unit should be the abbreviation string, not ID
      final unitAbbreviation = _selectedUnit;
      
      print('[EDIT_PRODUCT] Selected department: $_selectedDepartment -> ID: $departmentId');
      print('[EDIT_PRODUCT] Selected unit: $_selectedUnit -> abbreviation: $unitAbbreviation');

      final productData = {
        'id': widget.product.id,
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'price': double.parse(_priceController.text.trim()),
        'department': departmentId,
        'is_active': _isActive,
        'stock_level': _stockLevelController.text.isNotEmpty 
            ? double.parse(_stockLevelController.text.trim()) 
            : 0.0,
        'minimum_stock': _minimumStockController.text.isNotEmpty 
            ? double.parse(_minimumStockController.text.trim()) 
            : 5.0,
        'unit': unitAbbreviation,
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

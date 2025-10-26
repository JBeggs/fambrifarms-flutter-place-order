import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/api_service.dart';

class QuickAddProductDialog extends ConsumerStatefulWidget {
  final String suggestedName;
  final dynamic quantity;
  final String unit;
  final VoidCallback? onProductAdded;

  const QuickAddProductDialog({
    super.key,
    required this.suggestedName,
    required this.quantity,
    required this.unit,
    this.onProductAdded,
  });

  @override
  ConsumerState<QuickAddProductDialog> createState() => _QuickAddProductDialogState();
}

class _QuickAddProductDialogState extends ConsumerState<QuickAddProductDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();
  
  String _selectedUnit = 'kg';
  String _selectedDepartment = 'Fresh Produce';
  bool _isLoading = false;
  
  List<Map<String, dynamic>> _units = [];
  
  final List<String> _departments = [
    'Fresh Produce', 'Dairy', 'Meat', 'Bakery', 'Pantry', 'Frozen', 'Beverages', 'Other'
  ];

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.suggestedName;
    _selectedUnit = widget.unit.isNotEmpty ? widget.unit : 'kg';
    _priceController.text = '10.00'; // Default price
    _stockController.text = '100'; // Default stock
    _loadUnits();
  }

  Future<void> _loadUnits() async {
    try {
      final units = ApiService.getFormOptions('units_of_measure');
      setState(() {
        _units = units;
        // Set default unit if current selection is not available
        if (_units.isNotEmpty && !_units.any((unit) => unit['name'] == _selectedUnit)) {
          _selectedUnit = _units.first['name'] ?? 'kg';
        }
      });
    } catch (e) {
      // Fallback to hardcoded units if API fails
      setState(() {
        _units = [
          {'name': 'kg', 'display_name': 'Kilogram'},
          {'name': 'g', 'display_name': 'Gram'},
          {'name': 'piece', 'display_name': 'Piece'},
          {'name': 'each', 'display_name': 'Each'},
          {'name': 'bag', 'display_name': 'Bag'},
          {'name': 'box', 'display_name': 'Box'},
          {'name': 'bunch', 'display_name': 'Bunch'},
          {'name': 'head', 'display_name': 'Head'},
          {'name': 'packet', 'display_name': 'Packet'},
          {'name': 'punnet', 'display_name': 'Punnet'},
          {'name': 'tray', 'display_name': 'Tray'},
        ];
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  Future<void> _createProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final apiService = ApiService();
      
      final productData = {
        'name': _nameController.text.trim(),
        'unit': _selectedUnit,
        'price': double.parse(_priceController.text),
        'stock_level': double.parse(_stockController.text),
        'department': _selectedDepartment,
        'is_active': true,
        'description': 'Quick-added product from message processing',
      };

      final product = await apiService.createProduct(productData);
      
      if (mounted) {
        Navigator.of(context).pop(product);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Product "${product.name}" created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        
        widget.onProductAdded?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create product: $e'),
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.add_box, color: Colors.green),
          SizedBox(width: 8),
          Text('Quick Add Product'),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Adding product for: ${widget.quantity} ${widget.unit} ${widget.suggestedName}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 16),
              
              // Product Name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Product Name *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.shopping_basket),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Product name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Unit and Department Row
              Row(
                children: [
                  // Unit Dropdown
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedUnit,
                      decoration: const InputDecoration(
                        labelText: 'Unit *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.straighten),
                      ),
                      items: _units.map((unit) {
                        return DropdownMenuItem<String>(
                          value: unit['name'],
                          child: Text(unit['display_name'] ?? unit['name']),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedUnit = value!;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  // Department Dropdown
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedDepartment,
                      decoration: const InputDecoration(
                        labelText: 'Department *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.category),
                      ),
                      items: _departments.map((dept) {
                        return DropdownMenuItem(
                          value: dept,
                          child: Text(dept),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedDepartment = value!;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Price and Stock Row
              Row(
                children: [
                  // Price
                  Expanded(
                    child: TextFormField(
                      controller: _priceController,
                      decoration: const InputDecoration(
                        labelText: 'Price (R) *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.attach_money),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                      ],
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Price is required';
                        }
                        final price = double.tryParse(value);
                        if (price == null || price <= 0) {
                          return 'Enter a valid price';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  // Stock Level
                  Expanded(
                    child: TextFormField(
                      controller: _stockController,
                      decoration: const InputDecoration(
                        labelText: 'Stock Level *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.inventory),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                      ],
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Stock level is required';
                        }
                        final stock = double.tryParse(value);
                        if (stock == null || stock < 0) {
                          return 'Enter a valid stock level';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Info text
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info, color: Colors.blue, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This product will be immediately available for order processing.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.blue[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _createProduct,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create Product'),
        ),
      ],
    );
  }
}

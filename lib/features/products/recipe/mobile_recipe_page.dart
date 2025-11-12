import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../models/product.dart';
import '../../../services/api_service.dart';
import '../../../providers/products_provider.dart';

class MobileRecipePage extends ConsumerStatefulWidget {
  final Product product;

  const MobileRecipePage({super.key, required this.product});

  @override
  ConsumerState<MobileRecipePage> createState() => _MobileRecipePageState();
}

class _MobileRecipePageState extends ConsumerState<MobileRecipePage> {
  final _instructionsController = TextEditingController();
  final _prepTimeController = TextEditingController();
  final _yieldQuantityController = TextEditingController();
  String _yieldUnit = 'piece';
  
  List<Map<String, dynamic>> _ingredients = [];
  List<Product> _allProducts = [];
  bool _isLoading = false;
  bool _hasRecipe = false;
  Map<String, dynamic>? _existingRecipe;

  @override
  void initState() {
    super.initState();
    // Validate that product is a box before allowing recipe management
    if (!_isBoxProduct(widget.product)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recipes can only be added to box products'),
            backgroundColor: Colors.orange,
          ),
        );
      });
      return;
    }
    _loadRecipe();
    _loadProducts();
  }

  bool _isBoxProduct(Product product) {
    // Check if product is a box by unit or name
    final unitLower = product.unit.toLowerCase();
    final nameLower = product.name.toLowerCase();
    return unitLower == 'box' || nameLower.contains('box');
  }

  @override
  void dispose() {
    _instructionsController.dispose();
    _prepTimeController.dispose();
    _yieldQuantityController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    try {
      final apiService = ref.read(apiServiceProvider);
      final products = await apiService.getProducts();
      setState(() {
        _allProducts = products;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading products: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _loadRecipe() async {
    setState(() => _isLoading = true);
    try {
      final apiService = ref.read(apiServiceProvider);
      // Use the new endpoint
      final response = await apiService.dio.get(
        '/products/procurement/recipes/product/${widget.product.id}/'
      );
      
      if (response.data['success'] == true && response.data['recipe'] != null) {
        final recipe = response.data['recipe'];
        setState(() {
          _hasRecipe = true;
          _existingRecipe = recipe;
          _instructionsController.text = recipe['instructions'] ?? '';
          _prepTimeController.text = (recipe['prep_time_minutes'] ?? 30).toString();
          _yieldQuantityController.text = (recipe['yield_quantity'] ?? 1).toString();
          _yieldUnit = recipe['yield_unit'] ?? 'piece';
          _ingredients = List<Map<String, dynamic>>.from(recipe['ingredients'] ?? []);
        });
      }
    } catch (e) {
      // Recipe doesn't exist yet - that's fine
      setState(() {
        _hasRecipe = false;
        _yieldQuantityController.text = '1';
        _prepTimeController.text = '30';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveRecipe() async {
    if (_ingredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one ingredient'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final apiService = ref.read(apiServiceProvider);
      
      // Prepare ingredients with minimal structure (product_id + quantity)
      final ingredientsData = _ingredients.map((ing) => {
        'product_id': ing['product_id'],
        'quantity': ing['quantity'],
      }).toList();

      final recipeData = {
        'ingredients': ingredientsData,
        'instructions': _instructionsController.text,
        'prep_time_minutes': int.tryParse(_prepTimeController.text) ?? 30,
        'yield_quantity': double.tryParse(_yieldQuantityController.text) ?? 1,
        'yield_unit': _yieldUnit,
      };

      final method = _hasRecipe ? 'PUT' : 'POST';
      final response = await apiService.dio.request(
        '/products/procurement/recipes/product/${widget.product.id}/',
        data: recipeData,
        options: Options(method: method),
      );

      if (response.data['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.data['message'] ?? 'Recipe saved successfully'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } else {
        throw Exception(response.data['error'] ?? 'Failed to save recipe');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving recipe: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _addIngredient() {
    showDialog(
      context: context,
      builder: (context) => _AddIngredientDialog(
        allProducts: _allProducts,
        onAdd: (productId, quantity) {
          final product = _allProducts.firstWhere((p) => p.id == productId);
          setState(() {
            _ingredients.add({
              'product_id': productId,
              'product_name': product.name,
              'quantity': quantity,
              'unit': product.unit,
            });
          });
        },
      ),
    );
  }

  void _removeIngredient(int index) {
    setState(() {
      _ingredients.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text('Recipe: ${widget.product.name}'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading ? null : _saveRecipe,
            tooltip: 'Save Recipe',
          ),
        ],
      ),
      body: _isLoading && !_hasRecipe
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Recipe Info Section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Recipe Information',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _instructionsController,
                            decoration: const InputDecoration(
                              labelText: 'Instructions',
                              hintText: 'Recipe preparation instructions',
                              border: OutlineInputBorder(),
                            ),
                            maxLines: 3,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _prepTimeController,
                                  decoration: const InputDecoration(
                                    labelText: 'Prep Time (minutes)',
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextField(
                                  controller: _yieldQuantityController,
                                  decoration: const InputDecoration(
                                    labelText: 'Yield Quantity',
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _yieldUnit,
                                  decoration: const InputDecoration(
                                    labelText: 'Yield Unit',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: ['piece', 'box', 'kg', 'g', 'bag', 'bunch'].map((unit) {
                                    return DropdownMenuItem(value: unit, child: Text(unit));
                                  }).toList(),
                                  onChanged: (value) => setState(() => _yieldUnit = value ?? 'piece'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Ingredients Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Ingredients',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      ElevatedButton.icon(
                        onPressed: _addIngredient,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add Ingredient'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Ingredients List
                  if (_ingredients.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.restaurant_menu, size: 48, color: Colors.grey[300]),
                              const SizedBox(height: 16),
                              Text(
                                'No ingredients added',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tap "Add Ingredient" to get started',
                                style: TextStyle(color: Colors.grey[500], fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    ..._ingredients.asMap().entries.map((entry) {
                      final index = entry.key;
                      final ingredient = entry.value;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.purple.withOpacity(0.1),
                            child: Icon(Icons.inventory_2, color: Colors.purple),
                          ),
                          title: Text(ingredient['product_name'] ?? 'Unknown'),
                          subtitle: Text(
                            '${ingredient['quantity']} ${ingredient['unit'] ?? ''}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _removeIngredient(index),
                          ),
                        ),
                      );
                    }),

                  const SizedBox(height: 24),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveRecipe,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                            )
                          : const Text('Save Recipe', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _AddIngredientDialog extends StatefulWidget {
  final List<Product> allProducts;
  final Function(int productId, double quantity) onAdd;

  const _AddIngredientDialog({
    required this.allProducts,
    required this.onAdd,
  });

  @override
  State<_AddIngredientDialog> createState() => _AddIngredientDialogState();
}

class _AddIngredientDialogState extends State<_AddIngredientDialog> {
  Product? _selectedProduct;
  final _quantityController = TextEditingController();
  final _searchController = TextEditingController();
  List<Product> _filteredProducts = [];

  @override
  void initState() {
    super.initState();
    _filteredProducts = widget.allProducts;
    _searchController.addListener(_filterProducts);
    _quantityController.addListener(_updateButtonState);
  }

  void _filterProducts() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredProducts = widget.allProducts;
      } else {
        _filteredProducts = widget.allProducts.where((product) {
          return product.name.toLowerCase().contains(query) ||
                 (product.description?.toLowerCase().contains(query) ?? false) ||
                 product.department.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  void _updateButtonState() {
    setState(() {
      // Trigger rebuild to update button state
    });
  }

  bool _canAddIngredient() {
    if (_selectedProduct == null) return false;
    final quantityText = _quantityController.text.trim();
    if (quantityText.isEmpty) return false;
    final quantity = double.tryParse(quantityText);
    return quantity != null && quantity > 0;
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Add Ingredient',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            // Search Field
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search products...',
                hintStyle: TextStyle(color: Colors.grey[600]),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.purple, width: 2),
                ),
                filled: true,
                fillColor: Colors.grey[50],
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              style: const TextStyle(fontSize: 16, color: Colors.black87),
              autofocus: true,
            ),
            
            const SizedBox(height: 16),
            
            // Product List
            Expanded(
              child: _filteredProducts.isEmpty
                  ? Center(
                      child: Text(
                        _searchController.text.isEmpty
                            ? 'No products available'
                            : 'No products found',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filteredProducts.length,
                      itemBuilder: (context, index) {
                        final product = _filteredProducts[index];
                        final isSelected = _selectedProduct?.id == product.id;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          color: isSelected ? Colors.purple.withOpacity(0.1) : Colors.white,
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isSelected
                                  ? Colors.purple
                                  : Colors.grey[300],
                              child: Icon(
                                Icons.inventory_2,
                                color: isSelected ? Colors.white : Colors.grey[600],
                              ),
                            ),
                            title: Text(
                              product.name,
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? Colors.purple : Colors.black87,
                              ),
                            ),
                            subtitle: Text(
                              '${product.department} • ${product.unit}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            trailing: isSelected
                                ? const Icon(Icons.check_circle, color: Colors.purple)
                                : null,
                            onTap: () {
                              setState(() {
                                _selectedProduct = product;
                              });
                              // Update button state when product is selected
                              _updateButtonState();
                            },
                          ),
                        );
                      },
                    ),
            ),
            
            const SizedBox(height: 16),
            
            // Selected Product Display
            if (_selectedProduct != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.purple.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.purple, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Selected: ${_selectedProduct!.name}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.purple,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            
            const SizedBox(height: 16),
            
            // Quantity Field
            TextField(
              controller: _quantityController,
              decoration: const InputDecoration(
                labelText: 'Quantity',
                hintText: 'e.g., 10.0',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.numbers),
              ),
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 16, color: Colors.black87),
            ),
            
            const SizedBox(height: 24),
            
            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _canAddIngredient()
                      ? () {
                          final quantity = double.tryParse(_quantityController.text.trim()) ?? 0;
                          if (quantity > 0 && _selectedProduct != null) {
                            widget.onAdd(_selectedProduct!.id, quantity);
                            Navigator.pop(context);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter a valid quantity greater than 0'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          }
                        }
                      : null,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
                  child: const Text('Add'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


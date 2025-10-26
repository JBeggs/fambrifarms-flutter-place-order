// Product Search Field - Searchable product picker for order items
// Replaces simple dropdown with intelligent search functionality

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/product.dart';
import '../../../providers/products_provider.dart';
import '../../../services/api_service.dart';

class ProductSearchField extends ConsumerStatefulWidget {
  final Function(Product) onProductSelected;
  final String? initialValue;
  final String? hintText;

  const ProductSearchField({
    super.key,
    required this.onProductSelected,
    this.initialValue,
    this.hintText,
  });

  @override
  ConsumerState<ProductSearchField> createState() => _ProductSearchFieldState();
}

class _ProductSearchFieldState extends ConsumerState<ProductSearchField> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<Product> _filteredProducts = [];
  bool _showSuggestions = false;
  Product? _selectedProduct;

  @override
  void initState() {
    super.initState();
    if (widget.initialValue != null) {
      _controller.text = widget.initialValue!;
    }
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus && _controller.text.isNotEmpty) {
      _filterProducts(_controller.text);
    } else {
      setState(() {
        _showSuggestions = false;
      });
    }
  }

  void _filterProducts(String query) {
    final productsState = ref.read(productsProvider);
    
    if (productsState.products.isEmpty) {
      // Load products if not already loaded
      ref.read(productsProvider.notifier).loadProducts();
      return;
    }

    if (query.isEmpty) {
      setState(() {
        _filteredProducts = [];
        _showSuggestions = false;
      });
      return;
    }

    final filtered = productsState.products.where((product) {
      final name = product.name.toLowerCase();
      final searchQuery = query.toLowerCase();
      
      // Match by name, department, or partial matches
      return name.contains(searchQuery) ||
             (product.department?.toLowerCase().contains(searchQuery) ?? false) ||
             name.split(' ').any((word) => word.startsWith(searchQuery));
    }).toList();

    // Sort by relevance - exact matches first, then starts with, then contains
    filtered.sort((a, b) {
      final aName = a.name.toLowerCase();
      final bName = b.name.toLowerCase();
      final queryLower = query.toLowerCase();

      // Exact match
      if (aName == queryLower) return -1;
      if (bName == queryLower) return 1;

      // Starts with
      if (aName.startsWith(queryLower) && !bName.startsWith(queryLower)) return -1;
      if (bName.startsWith(queryLower) && !aName.startsWith(queryLower)) return 1;

      // Alphabetical for same relevance
      return aName.compareTo(bName);
    });

    setState(() {
      _filteredProducts = filtered.take(10).toList(); // Limit to 10 suggestions
      _showSuggestions = filtered.isNotEmpty;
    });
  }

  void _selectProduct(Product product) {
    print('DEBUG: _selectProduct called for ${product.name}');
    setState(() {
      _selectedProduct = product;
      _controller.text = product.name;
      _showSuggestions = false;
    });
    _focusNode.unfocus();
    print('DEBUG: About to call onProductSelected callback');
    widget.onProductSelected?.call(product);
    print('DEBUG: onProductSelected callback completed');
  }

  void _createNewProduct() async {
    final productName = _controller.text.trim();
    if (productName.isEmpty) return;

    try {
      // Create new product via API
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.dio.post('/products/products/', data: {
        'name': productName,
        'price': 0.0,
        'unit': 'piece',
        'is_active': true,
        'department': 1, // Default department ID
      });
      
      final newProductData = response.data;

      final newProduct = Product.fromJson(newProductData);
      
      // Refresh products list
      ref.read(productsProvider.notifier).loadProducts();
      
      // Select the new product
      _selectProduct(newProduct);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Created new product: $productName'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to create product: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final productsState = ref.watch(productsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search field
        TextFormField(
          controller: _controller,
          focusNode: _focusNode,
          decoration: InputDecoration(
            labelText: 'Product Name',
            hintText: widget.hintText ?? 'Search or type product name...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _controller.clear();
                      setState(() {
                        _filteredProducts = [];
                        _showSuggestions = false;
                        _selectedProduct = null;
                      });
                    },
                  )
                : null,
            border: const OutlineInputBorder(),
          ),
          onChanged: _filterProducts,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter a product name';
            }
            return null;
          },
        ),

        // Loading indicator
        if (productsState.isLoading)
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),

        // Suggestions dropdown
        if (_showSuggestions && _filteredProducts.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            constraints: const BoxConstraints(maxHeight: 250), // Increased height
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header showing result count
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
                  ),
                  child: Text(
                    '${_filteredProducts.length} product${_filteredProducts.length == 1 ? '' : 's'} found',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                // Product list
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _filteredProducts.length,
                    itemBuilder: (context, index) {
                      final product = _filteredProducts[index];
                      return ElevatedButton(
                        onPressed: () {
                          print('DEBUG: ElevatedButton onPressed called for ${product.name}');
                          _selectProduct(product);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black87,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero,
                            side: index < _filteredProducts.length - 1 
                                ? BorderSide(color: Colors.grey[200]!)
                                : BorderSide.none,
                          ),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: Colors.green[100],
                              child: Text(
                                product.name.substring(0, 1).toUpperCase(),
                                style: TextStyle(
                                  color: Colors.green[700],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    product.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                      color: Colors.black87,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    product.department,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.blue,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'R${product.price.toStringAsFixed(2)} per ${product.unit}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.green,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

        // Create new product option
        if (_showSuggestions && 
            _filteredProducts.isEmpty && 
            _controller.text.trim().isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
              color: Colors.blue[50],
            ),
            child: ListTile(
              dense: true,
              leading: CircleAvatar(
                backgroundColor: Colors.blue[100],
                child: Icon(Icons.add, color: Colors.blue[700]),
              ),
              title: Text('Create "${_controller.text.trim()}"'),
              subtitle: const Text('Add as new product'),
              onTap: _createNewProduct,
            ),
          ),

        // Selected product info
        if (_selectedProduct != null)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green[700], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Selected: ${_selectedProduct!.name}',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.green[700],
                        ),
                      ),
                      Text(
                        'R${_selectedProduct!.price.toStringAsFixed(2)}/${_selectedProduct!.unit}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:excel/excel.dart' as excel;
import '../../models/product.dart';
import '../../providers/products_provider.dart';
import '../../services/api_service.dart';
import 'widgets/add_product_dialog.dart';
import 'widgets/edit_product_dialog.dart';
import 'recipe/mobile_recipe_page.dart';

/// Mobile-optimized products management page
class MobileProductsPage extends ConsumerStatefulWidget {
  const MobileProductsPage({super.key});

  @override
  ConsumerState<MobileProductsPage> createState() => _MobileProductsPageState();
}

class _MobileProductsPageState extends ConsumerState<MobileProductsPage> {
  String _searchQuery = '';
  String _selectedDepartment = 'all';
  Map<int, Map<String, dynamic>> _productRecipes = {}; // productId -> recipe data
  Set<int> _loadingRecipes = {}; // Track which recipes are being loaded

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(productsProvider.notifier).loadProducts();
    });
  }

  Future<void> _loadRecipeForProduct(Product product) async {
    if (!_isBoxProduct(product) || _productRecipes.containsKey(product.id) || _loadingRecipes.contains(product.id)) {
      return;
    }

    setState(() {
      _loadingRecipes.add(product.id);
    });

    try {
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.dio.get(
        '/products/procurement/recipes/product/${product.id}/'
      );
      
      if (response.data['success'] == true && response.data['recipe'] != null) {
        setState(() {
          _productRecipes[product.id] = response.data['recipe'];
          _loadingRecipes.remove(product.id);
        });
      } else {
        setState(() {
          _loadingRecipes.remove(product.id);
        });
      }
    } catch (e) {
      // Recipe doesn't exist - that's fine
      setState(() {
        _loadingRecipes.remove(product.id);
      });
    }
  }

  List<Product> get filteredProducts {
    final productsState = ref.watch(productsProvider);
    var products = productsState.filteredProducts;

    // Filter by search
    if (_searchQuery.isNotEmpty) {
      products = products.where((p) {
        final query = _searchQuery.toLowerCase();
        return p.name.toLowerCase().contains(query) ||
               (p.description?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    // Filter by department
    if (_selectedDepartment != 'all') {
      products = products.where((p) => p.department == _selectedDepartment).toList();
    }

    return products;
  }

  @override
  Widget build(BuildContext context) {
    final productsState = ref.watch(productsProvider);
    final filteredList = filteredProducts;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Products',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AddProductDialog(),
                  fullscreenDialog: true,
                ),
              );
            },
            tooltip: 'Add Product',
          ),
          IconButton(
            icon: const Icon(Icons.table_chart),
            onPressed: _exportToExcel,
            tooltip: 'Export to Excel',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(productsProvider.notifier).refresh();
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and Filters
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Search Bar
                TextField(
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
                      borderSide: const BorderSide(color: Colors.green, width: 2),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                  style: const TextStyle(fontSize: 16, color: Colors.black87),
                ),
              ],
            ),
          ),

          // Products List
          Expanded(
            child: productsState.isLoading && productsState.products.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : productsState.error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, size: 64, color: Colors.red),
                            const SizedBox(height: 16),
                            Text('Error loading products', style: Theme.of(context).textTheme.headlineSmall),
                            const SizedBox(height: 8),
                            Text(productsState.error!, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: () => ref.read(productsProvider.notifier).refresh(),
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : filteredList.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[300]),
                                const SizedBox(height: 16),
                                Text('No products found', style: Theme.of(context).textTheme.headlineSmall),
                                const SizedBox(height: 8),
                                Text('Try adjusting your search', style: TextStyle(color: Colors.grey[600])),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: () => ref.read(productsProvider.notifier).refresh(),
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: filteredList.length,
                              itemBuilder: (context, index) {
                                final product = filteredList[index];
                                return _buildProductCard(product);
                              },
                            ),
                          ),
          ),

          // Summary Footer
          if (filteredList.isNotEmpty)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${filteredList.length} products',
                    style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.grey),
                  ),
                  Text(
                    '${filteredList.where((p) => p.stockLevel <= p.minimumStock).length} low stock',
                    style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.orange),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProductCard(Product product) {
    final isLowStock = product.stockLevel <= product.minimumStock;
    final isOutOfStock = product.stockLevel <= 0;
    final isBox = _isBoxProduct(product);
    final recipe = isBox ? _productRecipes[product.id] : null;
    
    // Load recipe if it's a box and we haven't loaded it yet
    if (isBox && !_productRecipes.containsKey(product.id) && !_loadingRecipes.contains(product.id)) {
      _loadRecipeForProduct(product);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: InkWell(
        onTap: () => _showProductDetails(product),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  Expanded(
                    child: Text(
                      product.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // Stock Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isOutOfStock
                          ? Colors.red.withOpacity(0.1)
                          : isLowStock
                              ? Colors.orange.withOpacity(0.1)
                              : Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isOutOfStock
                          ? 'OUT'
                          : isLowStock
                              ? 'LOW'
                              : 'OK',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isOutOfStock
                            ? Colors.red
                            : isLowStock
                                ? Colors.orange
                                : Colors.green,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Department and Price
              Row(
                children: [
                  Icon(Icons.category, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    product.department,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  const Spacer(),
                  Text(
                    'R${product.price.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Stock Level
              Row(
                children: [
                  Icon(Icons.inventory_2, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    'Stock: ${product.stockLevel.toStringAsFixed(1)} ${product.unit}',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Min: ${product.minimumStock.toStringAsFixed(1)}',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),

              // Recipe Breakdown (for box products)
              if (isBox && recipe != null && recipe['ingredients'] != null)
                _buildRecipeBreakdown(recipe['ingredients'] as List<dynamic>)
              else if (isBox && _loadingRecipes.contains(product.id))
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Loading recipe...',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 12),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _editProduct(product),
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('Edit'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  if (_isBoxProduct(product)) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _manageRecipe(product),
                        icon: const Icon(Icons.restaurant_menu, size: 16),
                        label: const Text('Recipe'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showProductDetails(Product product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product.name,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildDetailRow('Department', product.department),
              _buildDetailRow('Price', 'R${product.price.toStringAsFixed(2)}'),
              _buildDetailRow('Unit', product.unit),
              _buildDetailRow('Stock Level', '${product.stockLevel.toStringAsFixed(1)} ${product.unit}'),
              _buildDetailRow('Minimum Stock', '${product.minimumStock.toStringAsFixed(1)} ${product.unit}'),
              if (product.description != null && product.description!.isNotEmpty)
                _buildDetailRow('Description', product.description!),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _editProduct(product);
                      },
                      child: const Text('Edit'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  if (_isBoxProduct(product))
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _manageRecipe(product);
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
                        child: const Text('Manage Recipe'),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[700]),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _editProduct(Product product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditProductDialog(product: product),
        fullscreenDialog: true,
      ),
    );
  }

  Widget _buildRecipeBreakdown(List<dynamic> ingredients) {
    if (ingredients.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.purple.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.purple.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.restaurant_menu, size: 16, color: Colors.purple),
              const SizedBox(width: 4),
              Text(
                'Contains:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...ingredients.take(3).map((ingredient) {
            final productName = ingredient['product_name'] ?? 'Unknown';
            final quantity = ingredient['quantity'] ?? 0;
            final unit = ingredient['unit'] ?? '';
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  const SizedBox(width: 20),
                  Text(
                    '• $productName: ',
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                  Text(
                    '$quantity $unit',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          if (ingredients.length > 3)
            Padding(
              padding: const EdgeInsets.only(left: 20, top: 4),
              child: Text(
                '+ ${ingredients.length - 3} more ingredient${ingredients.length - 3 > 1 ? 's' : ''}',
                style: TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey[600],
                ),
              ),
            ),
        ],
      ),
    );
  }

  bool _isBoxProduct(Product product) {
    // Check if product is a box by unit or name
    final unitLower = product.unit.toLowerCase();
    final nameLower = product.name.toLowerCase();
    return unitLower == 'box' || nameLower.contains('box');
  }

  void _manageRecipe(Product product) {
    // Only allow recipe management for box products
    if (!_isBoxProduct(product)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Recipes can only be added to box products'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MobileRecipePage(product: product),
      ),
    );
  }

  Future<void> _exportToExcel() async {
    try {
      print('[PRODUCTS_EXCEL] Starting Excel export...');
      
      // Show loading
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(width: 16),
              Text('Generating Excel file...'),
            ],
          ),
          duration: Duration(seconds: 3),
        ),
      );

      final productsState = ref.read(productsProvider);
      final products = productsState.products;
      
      // Filter to only include products with stock > 0
      final productsInStock = products.where((p) => p.stockLevel > 0).toList();
      
      if (productsInStock.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No products with stock to export'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Sort products alphabetically by name
      final sortedProducts = List<Product>.from(productsInStock)
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      print('[PRODUCTS_EXCEL] Exporting ${sortedProducts.length} products with stock (filtered from ${products.length} total)');

      // Generate filename
      final now = DateTime.now();
      final dateStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      final timeStr = '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      final filename = 'FambriProducts_${dateStr}_$timeStr.xlsx';

      // Get documents directory
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$filename';

      // Create Excel workbook
      final excelFile = excel.Excel.createExcel();
      final sheet = excelFile['Products'];

      // Remove default sheet if it exists
      if (excelFile.sheets.containsKey('Sheet1')) {
        excelFile.delete('Sheet1');
      }

      // Add title and metadata
      final reportDate = '${now.day}/${now.month}/${now.year}';
      final reportTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      
      sheet.appendRow([
        excel.TextCellValue('FAMBRI FARMS - PRODUCTS REPORT'),
      ]);
      sheet.appendRow([
        excel.TextCellValue('Generated: $reportDate at $reportTime'),
      ]);
      sheet.appendRow([
        excel.TextCellValue(''),
      ]);
      
      // Add summary (all products in export have stock > 0 by design)
      final lowStockCount = sortedProducts.where((p) => p.stockLevel <= p.minimumStock).length;
      final goodStockCount = sortedProducts.length - lowStockCount;
      
      sheet.appendRow([
        excel.TextCellValue('Summary:'),
        excel.TextCellValue('Products with Stock: ${sortedProducts.length}'),
        excel.TextCellValue('Good Stock: $goodStockCount'),
        excel.TextCellValue('Low Stock: $lowStockCount'),
      ]);
      sheet.appendRow([
        excel.TextCellValue(''),
      ]);

      // Add header row
      final headerRow = [
        excel.TextCellValue('Product Name'),
        excel.TextCellValue('Department'),
        excel.TextCellValue('Price (R)'),
        excel.TextCellValue('Current Stock'),
        excel.TextCellValue('Unit'),
        excel.TextCellValue('Minimum Stock'),
        excel.TextCellValue('Status'),
        excel.TextCellValue('SKU'),
        excel.TextCellValue('Active'),
      ];
      sheet.appendRow(headerRow);

      // Add data rows (all products have stock > 0)
      for (final product in sortedProducts) {
        final status = product.stockLevel <= product.minimumStock
            ? 'LOW STOCK'
            : 'OK';

        final dataRow = [
          excel.TextCellValue(product.name),
          excel.TextCellValue(product.department),
          excel.DoubleCellValue(product.price),
          excel.DoubleCellValue(product.stockLevel),
          excel.TextCellValue(product.unit),
          excel.DoubleCellValue(product.minimumStock),
          excel.TextCellValue(status),
          excel.TextCellValue(product.sku ?? '-'),
          excel.TextCellValue(product.isActive ? 'Yes' : 'No'),
        ];
        sheet.appendRow(dataRow);
      }

      // Auto-fit columns
      for (int i = 0; i < headerRow.length; i++) {
        sheet.setColumnAutoFit(i);
      }

      // Save Excel file
      print('[PRODUCTS_EXCEL] Generating Excel bytes...');
      final excelBytes = excelFile.save();

      if (excelBytes != null) {
        print('[PRODUCTS_EXCEL] Excel bytes generated: ${excelBytes.length} bytes');
        
        final file = File(filePath);
        print('[PRODUCTS_EXCEL] Writing to file: $filePath');
        await file.writeAsBytes(excelBytes);

        // Verify file was created
        if (file.existsSync()) {
          final fileSize = file.lengthSync();
          print('[PRODUCTS_EXCEL] ✅ Excel saved successfully!');
          print('[PRODUCTS_EXCEL] File: $filePath');
          print('[PRODUCTS_EXCEL] Size: $fileSize bytes');

          // Share the file
          await Share.shareXFiles(
            [XFile(filePath)],
            subject: 'Fambri Products Report - $reportDate',
            text: 'Products report generated on $reportDate at $reportTime',
          );

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Excel exported: ${sortedProducts.length} products'),
              backgroundColor: Colors.green,
              action: SnackBarAction(
                label: 'Share Again',
                textColor: Colors.white,
                onPressed: () {
                  Share.shareXFiles(
                    [XFile(filePath)],
                    subject: 'Fambri Products Report - $reportDate',
                  );
                },
              ),
            ),
          );
        } else {
          throw Exception('File was not created after write operation');
        }
      } else {
        throw Exception('Failed to generate Excel bytes');
      }
    } catch (e) {
      print('[PRODUCTS_EXCEL] Error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error exporting Excel: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}


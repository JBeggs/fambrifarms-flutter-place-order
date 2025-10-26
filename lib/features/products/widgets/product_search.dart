import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/products_provider.dart';
import '../../../models/product.dart';

class ProductSearch extends ConsumerStatefulWidget {
  const ProductSearch({super.key});

  @override
  ConsumerState<ProductSearch> createState() => _ProductSearchState();
}

class _ProductSearchState extends ConsumerState<ProductSearch> {
  final _searchController = TextEditingController();
  ProductDepartment _selectedDepartment = ProductDepartment.all;
  StockStatus _selectedStockStatus = StockStatus.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productsState = ref.watch(productsProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Search bar
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search products by name, department, or SKU...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: productsState.searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        ref.read(productsProvider.notifier).clearSearch();
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            onChanged: (value) {
              ref.read(productsProvider.notifier).searchProducts(value);
            },
          ),
          
          const SizedBox(height: 16),
          
          // Department filter chips
          Row(
            children: [
              Text(
                'Department:',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              
              const SizedBox(width: 12),
              
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ProductDepartment.values.map((department) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _buildDepartmentChip(department),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Stock status filter chips
          Row(
            children: [
              Text(
                'Stock Status:',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              
              const SizedBox(width: 12),
              
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: StockStatus.values.map((status) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _buildStockStatusChip(status),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Results summary
          _buildResultsSummary(context, productsState),
        ],
      ),
    );
  }

  Widget _buildDepartmentChip(ProductDepartment department) {
    final isSelected = _selectedDepartment == department;
    
    return FilterChip(
      selected: isSelected,
      label: Text(department.fullDisplay),
      onSelected: (selected) {
        setState(() {
          _selectedDepartment = department;
        });
        ref.read(productsProvider.notifier).filterByDepartment(department);
      },
      selectedColor: _getDepartmentColor(department.displayName),
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.grey[700],
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        fontSize: 12,
      ),
    );
  }

  Widget _buildStockStatusChip(StockStatus status) {
    final isSelected = _selectedStockStatus == status;
    
    return FilterChip(
      selected: isSelected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getStockStatusIcon(status),
            size: 16,
            color: isSelected ? Colors.white : _getStockStatusColor(status),
          ),
          const SizedBox(width: 4),
          Text(status.displayName),
        ],
      ),
      onSelected: (selected) {
        setState(() {
          _selectedStockStatus = status;
        });
        ref.read(productsProvider.notifier).filterByStockStatus(status);
      },
      selectedColor: _getStockStatusColor(status),
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.grey[700],
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        fontSize: 12,
      ),
    );
  }

  Widget _buildResultsSummary(BuildContext context, ProductsState state) {
    final totalProducts = state.products.length;
    final filteredProducts = state.filteredProducts.length;
    final hasFilters = state.searchQuery.isNotEmpty || 
                      state.selectedDepartment != ProductDepartment.all ||
                      state.selectedStockStatus != StockStatus.all;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              hasFilters
                  ? 'Showing $filteredProducts of $totalProducts products'
                  : 'Showing all $totalProducts products',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.blue[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          
          if (hasFilters) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _selectedDepartment = ProductDepartment.all;
                  _selectedStockStatus = StockStatus.all;
                });
                ref.read(productsProvider.notifier).clearAllFilters();
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Clear filters',
                style: TextStyle(
                  color: Colors.blue[700],
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getDepartmentColor(String department) {
    switch (department.toLowerCase()) {
      case 'vegetables':
        return const Color(0xFF27AE60); // Green
      case 'fruits':
        return const Color(0xFFE74C3C); // Red
      case 'herbs & spices':
        return const Color(0xFF2ECC71); // Light green
      case 'mushrooms':
        return const Color(0xFF8E44AD); // Purple
      case 'specialty items':
        return const Color(0xFFF39C12); // Orange
      default:
        return const Color(0xFF2D5016); // Farm green
    }
  }

  IconData _getStockStatusIcon(StockStatus status) {
    switch (status) {
      case StockStatus.all:
        return Icons.inventory;
      case StockStatus.inStock:
        return Icons.check_circle;
      case StockStatus.lowStock:
        return Icons.warning;
      case StockStatus.outOfStock:
        return Icons.error;
    }
  }

  Color _getStockStatusColor(StockStatus status) {
    switch (status) {
      case StockStatus.all:
        return const Color(0xFF2D5016); // Farm green
      case StockStatus.inStock:
        return const Color(0xFF27AE60); // Green
      case StockStatus.lowStock:
        return const Color(0xFFF39C12); // Orange
      case StockStatus.outOfStock:
        return const Color(0xFFE74C3C); // Red
    }
  }
}


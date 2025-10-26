import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/professional_theme.dart';
import '../../providers/products_provider.dart';
import '../../features/auth/karl_auth_provider.dart';
import '../../models/product.dart';
import 'widgets/product_card.dart';
import 'widgets/product_search.dart';
import 'widgets/add_product_dialog.dart';
import 'widgets/edit_product_dialog.dart';

class ProductsPage extends ConsumerWidget {
  const ProductsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final karl = ref.watch(karlAuthProvider).user;
    final productsState = ref.watch(productsProvider);
    final productsList = ref.watch(productsListProvider);
    final productsStats = ref.watch(productsStatsProvider);
    final lowStockProducts = ref.watch(lowStockProductsProvider);
    final outOfStockProducts = ref.watch(outOfStockProductsProvider);

    if (karl == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/login');
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundDark, // Professional dark background
      appBar: AppBar(
        title: const Text('Product Catalog'),
        backgroundColor: AppColors.primaryGreen, // Professional green AppBar
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/karl-dashboard'),
        ),
        actions: [
          // Stock alerts indicator
          if (lowStockProducts.isNotEmpty || outOfStockProducts.isNotEmpty)
            IconButton(
              icon: Badge(
                label: Text('${lowStockProducts.length + outOfStockProducts.length}'),
                child: const Icon(Icons.warning),
              ),
              onPressed: () {
                _showStockAlertsDialog(context, lowStockProducts, outOfStockProducts);
              },
            ),
          
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(productsProvider.notifier).refresh();
            },
          ),
          
          // Add product button
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => const AddProductDialog(),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Stats header
          _buildStatsHeader(context, productsStats),
          
          // Search and filters
          const ProductSearch(),
          
          // Products list
          Expanded(
            child: _buildProductsList(context, ref, productsState, productsList),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsHeader(BuildContext context, Map<String, dynamic> stats) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        children: [
          // First row of stats
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  context,
                  'Total Products',
                  stats['total'].toString(),
                  Icons.inventory,
                  const Color(0xFF2D5016),
                ),
              ),
              
              const SizedBox(width: 12),
              
              Expanded(
                child: _buildStatCard(
                  context,
                  'In Stock',
                  stats['in_stock'].toString(),
                  Icons.check_circle,
                  Colors.green,
                ),
              ),
              
              const SizedBox(width: 12),
              
              Expanded(
                child: _buildStatCard(
                  context,
                  'Low Stock',
                  stats['low_stock'].toString(),
                  Icons.warning,
                  Colors.orange,
                ),
              ),
              
              const SizedBox(width: 12),
              
              Expanded(
                child: _buildStatCard(
                  context,
                  'Out of Stock',
                  stats['out_of_stock'].toString(),
                  Icons.error,
                  Colors.red,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Second row of stats
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  context,
                  'Active Products',
                  stats['active'].toString(),
                  Icons.visibility,
                  Colors.blue,
                ),
              ),
              
              const SizedBox(width: 12),
              
              Expanded(
                child: _buildStatCard(
                  context,
                  'Avg Price',
                  'R${(stats['average_price'] as double).toStringAsFixed(2)}',
                  Icons.attach_money,
                  Colors.purple,
                ),
              ),
              
              const SizedBox(width: 12),
              
              Expanded(
                child: _buildStatCard(
                  context,
                  'Departments',
                  (stats['department_breakdown'] as Map).length.toString(),
                  Icons.category,
                  Colors.teal,
                ),
              ),
              
              const SizedBox(width: 12),
              
              // Placeholder for symmetry
              const Expanded(child: SizedBox()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildProductsList(
    BuildContext context,
    WidgetRef ref,
    ProductsState state,
    List<dynamic> products,
  ) {
    if (state.isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading products...'),
          ],
        ),
      );
    }

    if (state.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[300],
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading products',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              state.error!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                ref.read(productsProvider.notifier).refresh();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (products.isEmpty) {
      final hasFilters = state.searchQuery.isNotEmpty || 
                        state.selectedDepartment != ProductDepartment.all ||
                        state.selectedStockStatus != StockStatus.all;
      
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasFilters ? Icons.search_off : Icons.inventory_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              hasFilters ? 'No products found' : 'No products yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasFilters 
                  ? 'Try adjusting your search or filters'
                  : 'Products will appear here once they\'re added',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            if (hasFilters) ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  ref.read(productsProvider.notifier).clearAllFilters();
                },
                child: const Text('Clear filters'),
              ),
            ],
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(productsProvider.notifier).refresh(),
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 16),
        itemCount: products.length,
        itemBuilder: (context, index) {
          final product = products[index];
          return ProductCard(
            product: product,
            onTap: () {
              context.push('/products/${product.id}');
            },
            onEdit: () {
              showDialog(
                context: context,
                builder: (context) => EditProductDialog(product: product),
              );
            },
            onViewStock: () {
              // TODO: Navigate to stock management page
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Stock management for ${product.displayName}'),
                ),
              );
            },
            onAddToOrder: () {
              // TODO: Add to order functionality
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Added ${product.displayName} to order'),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showStockAlertsDialog(
    BuildContext context, 
    List<dynamic> lowStock, 
    List<dynamic> outOfStock,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('Stock Alerts'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (outOfStock.isNotEmpty) ...[
                Text(
                  'Out of Stock (${outOfStock.length})',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 8),
                ...outOfStock.take(5).map((product) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('• ${product.displayName}'),
                )),
                if (outOfStock.length > 5)
                  Text('... and ${outOfStock.length - 5} more'),
                const SizedBox(height: 16),
              ],
              
              if (lowStock.isNotEmpty) ...[
                Text(
                  'Low Stock (${lowStock.length})',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(height: 8),
                ...lowStock.take(5).map((product) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('• ${product.displayName} (${product.stockLevel} left)'),
                )),
                if (lowStock.length > 5)
                  Text('... and ${lowStock.length - 5} more'),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: Navigate to stock management
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Stock management feature coming soon!'),
                ),
              );
            },
            child: const Text('Manage Stock'),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/product.dart';
import '../../providers/products_provider.dart';
import '../../core/professional_theme.dart';
import 'widgets/edit_product_dialog.dart';

class ProductDetailPage extends ConsumerWidget {
  final int productId;

  const ProductDetailPage({
    super.key,
    required this.productId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsList = ref.watch(productsListProvider);
    
    // Find the product in the list
    final product = productsList.whereType<Product>()
        .where((p) => p.id == productId)
        .firstOrNull;

    if (product == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Product Not Found'),
          backgroundColor: AppColors.primaryGreen,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inventory_outlined, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Product not found',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: Text(product.name),
        backgroundColor: AppColors.primaryGreen,
        elevation: 1,
        actions: [
          // Edit button
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => EditProductDialog(product: product),
              );
            },
          ),
          // More options
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'duplicate':
                  _showDuplicateDialog(context, product);
                  break;
                case 'deactivate':
                  _showDeactivateDialog(context, ref, product);
                  break;
                case 'delete':
                  _showDeleteDialog(context, ref, product);
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'duplicate',
                child: Row(
                  children: [
                    Icon(Icons.copy, size: 18),
                    SizedBox(width: 8),
                    Text('Duplicate Product'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'deactivate',
                child: Row(
                  children: [
                    Icon(
                      product.isActive ? Icons.visibility_off : Icons.visibility,
                      size: 18,
                      color: product.isActive ? Colors.orange : Colors.green,
                    ),
                    const SizedBox(width: 8),
                    Text(product.isActive ? 'Deactivate' : 'Activate'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, size: 18, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete Product'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Header Card
            _buildHeaderCard(context, product),
            
            const SizedBox(height: 16),
            
            // Stock Information Card
            _buildStockInfoCard(context, product),
            
            const SizedBox(height: 16),
            
            // Pricing Information Card
            _buildPricingInfoCard(context, product),
            
            const SizedBox(height: 16),
            
            // Product Details Card
            _buildProductDetailsCard(context, product),
            
            const SizedBox(height: 16),
            
            // Recent Activity Card (placeholder)
            _buildRecentActivityCard(context, product),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context, Product product) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            // Product Icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _getDepartmentColor(product.department).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _getDepartmentColor(product.department).withValues(alpha: 0.3),
                ),
              ),
              child: Icon(
                _getDepartmentIcon(product.department),
                size: 40,
                color: _getDepartmentColor(product.department),
              ),
            ),
            
            const SizedBox(width: 24),
            
            // Product Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name and Status
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          product.name,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: product.isActive 
                              ? Colors.green.withValues(alpha: 0.1)
                              : Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: product.isActive ? Colors.green : Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              product.isActive ? 'Active' : 'Inactive',
                              style: TextStyle(
                                fontSize: 14,
                                color: product.isActive ? Colors.green : Colors.red,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Department and SKU
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _getDepartmentColor(product.department).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          product.department,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _getDepartmentColor(product.department),
                          ),
                        ),
                      ),
                      
                      if (product.sku != null && product.sku!.isNotEmpty) ...[
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            'SKU: ${product.sku}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  
                  if (product.description != null && product.description!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      product.description!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStockInfoCard(BuildContext context, Product product) {
    final stockStatus = _getStockStatus(product.stockLevel, product.minimumStock);
    
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.inventory_2, color: Color(0xFF2D5016)),
                const SizedBox(width: 8),
                Text(
                  'Stock Information',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2D5016),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            Row(
              children: [
                Expanded(
                  child: _buildStockStatItem(
                    context,
                    'Current Stock',
                    '${product.stockLevel.toInt()} ${product.unit}',
                    Icons.inventory,
                    stockStatus.color,
                  ),
                ),
                Expanded(
                  child: _buildStockStatItem(
                    context,
                    'Minimum Level',
                    '${product.minimumStock.toInt()} ${product.unit}',
                    Icons.warning_outlined,
                    Colors.orange,
                  ),
                ),
                Expanded(
                  child: _buildStockStatItem(
                    context,
                    'Stock Status',
                    stockStatus.label,
                    stockStatus.icon,
                    stockStatus.color,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPricingInfoCard(BuildContext context, Product product) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.attach_money, color: Color(0xFF2D5016)),
                const SizedBox(width: 8),
                Text(
                  'Pricing Information',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2D5016),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            Row(
              children: [
                Expanded(
                  child: _buildPriceStatItem(
                    context,
                    'Current Price',
                    'R${product.price.toStringAsFixed(2)}',
                    'per ${product.unit}',
                  ),
                ),
                Expanded(
                  child: _buildPriceStatItem(
                    context,
                    'Stock Value',
                    'R${(product.price * product.stockLevel).toStringAsFixed(2)}',
                    '${product.stockLevel.toInt()} × R${product.price.toStringAsFixed(2)}',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductDetailsCard(BuildContext context, Product product) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline, color: Color(0xFF2D5016)),
                const SizedBox(width: 8),
                Text(
                  'Product Details',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2D5016),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            _buildDetailItem(context, 'Product ID', product.id.toString()),
            _buildDetailItem(context, 'Unit of Measure', product.unit),
            if (product.sku != null && product.sku!.isNotEmpty)
              _buildDetailItem(context, 'SKU', product.sku!),
            _buildDetailItem(context, 'Department', product.department),
            _buildDetailItem(context, 'Status', product.isActive ? 'Active' : 'Inactive'),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivityCard(BuildContext context, Product product) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.history, color: Color(0xFF2D5016)),
                const SizedBox(width: 8),
                Text(
                  'Recent Activity',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2D5016),
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    // TODO: Navigate to full activity log
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Activity log feature coming soon!'),
                      ),
                    );
                  },
                  child: const Text('View All'),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Placeholder for activity
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.timeline,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No recent activity',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Stock movements and price changes will appear here',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[500],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStockStatItem(BuildContext context, String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPriceStatItem(BuildContext context, String label, String value, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2D5016).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: const Color(0xFF2D5016),
            ),
          ),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Color _getDepartmentColor(String? department) {
    switch (department?.toLowerCase()) {
      case 'vegetables':
        return Colors.green;
      case 'fruits':
        return Colors.orange;
      case 'herbs':
        return Colors.lightGreen;
      case 'dairy':
        return Colors.blue;
      case 'meat':
        return Colors.red;
      case 'bakery':
        return Colors.brown;
      case 'pantry':
        return Colors.purple;
      case 'beverages':
        return Colors.cyan;
      default:
        return Colors.grey;
    }
  }

  IconData _getDepartmentIcon(String? department) {
    switch (department?.toLowerCase()) {
      case 'vegetables':
        return Icons.eco;
      case 'fruits':
        return Icons.apple;
      case 'herbs':
        return Icons.grass;
      case 'dairy':
        return Icons.local_drink;
      case 'meat':
        return Icons.set_meal;
      case 'bakery':
        return Icons.cake;
      case 'pantry':
        return Icons.kitchen;
      case 'beverages':
        return Icons.local_cafe;
      default:
        return Icons.inventory;
    }
  }

  ({String label, IconData icon, Color color}) _getStockStatus(double current, double minimum) {
    if (current <= 0) {
      return (label: 'Out of Stock', icon: Icons.error, color: Colors.red);
    } else if (current <= minimum) {
      return (label: 'Low Stock', icon: Icons.warning, color: Colors.orange);
    } else {
      return (label: 'In Stock', icon: Icons.check_circle, color: Colors.green);
    }
  }

  void _showDuplicateDialog(BuildContext context, Product product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Duplicate Product'),
        content: Text('Create a copy of "${product.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Product duplication feature coming soon!'),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2D5016),
              foregroundColor: Colors.white,
            ),
            child: const Text('Duplicate'),
          ),
        ],
      ),
    );
  }

  void _showDeactivateDialog(BuildContext context, WidgetRef ref, Product product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(product.isActive ? 'Deactivate Product' : 'Activate Product'),
        content: Text(
          product.isActive
              ? 'Are you sure you want to deactivate "${product.name}"? It will no longer be available for orders.'
              : 'Are you sure you want to activate "${product.name}"? It will be available for orders again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    product.isActive
                        ? '${product.name} deactivated'
                        : '${product.name} activated',
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: product.isActive ? Colors.orange : Colors.green,
              foregroundColor: Colors.white,
            ),
            child: Text(product.isActive ? 'Deactivate' : 'Activate'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref, Product product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text(
          'Are you sure you want to delete "${product.name}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Product deletion feature coming soon!'),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

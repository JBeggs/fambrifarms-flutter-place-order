import 'package:flutter/material.dart';
import '../../../models/product.dart';

class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onViewStock;
  final VoidCallback? onAddToOrder;

  const ProductCard({
    super.key,
    required this.product,
    this.onTap,
    this.onEdit,
    this.onViewStock,
    this.onAddToOrder,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  // Product department icon
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _getDepartmentColor(product.department).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _getDepartmentColor(product.department).withOpacity(0.3),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        _getDepartmentEmoji(product.department),
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 16),
                  
                  // Product info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Product name
                        Text(
                          product.displayName,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        
                        const SizedBox(height: 4),
                        
                        // Department and SKU
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _getDepartmentColor(product.department)
                                    .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                product.departmentDisplay,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _getDepartmentColor(product.department),
                                ),
                              ),
                            ),
                            
                            if (product.sku != null) ...[
                              const SizedBox(width: 8),
                              Text(
                                'SKU: ${product.sku}',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Action buttons
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      switch (value) {
                        case 'edit':
                          onEdit?.call();
                          break;
                        case 'stock':
                          onViewStock?.call();
                          break;
                        case 'add_order':
                          onAddToOrder?.call();
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 18),
                            SizedBox(width: 8),
                            Text('Edit Product'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'stock',
                        child: Row(
                          children: [
                            Icon(Icons.inventory, size: 18),
                            SizedBox(width: 8),
                            Text('View Stock'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'add_order',
                        child: Row(
                          children: [
                            Icon(Icons.add_shopping_cart, size: 18),
                            SizedBox(width: 8),
                            Text('Add to Order'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Price and unit information
              Row(
                children: [
                  Expanded(
                    child: _buildInfoItem(
                      context,
                      Icons.attach_money,
                      'Price',
                      product.fullPriceDisplay,
                      color: const Color(0xFF27AE60),
                    ),
                  ),
                  
                  const SizedBox(width: 16),
                  
                  Expanded(
                    child: _buildInfoItem(
                      context,
                      Icons.inventory_2_outlined,
                      'Stock Level',
                      '${product.stockLevel} ${product.unitDisplay}',
                      color: product.stockStatusColor,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Stock status bar
              _buildStockStatusBar(context),
              
              const SizedBox(height: 16),
              
              // Product description (if available)
              if (product.description != null && product.description!.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          product.description!,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              // Product statistics
              Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      context,
                      'Min Stock',
                      '${product.minimumStock}',
                      Icons.warning_outlined,
                    ),
                  ),
                  
                  Expanded(
                    child: _buildStatItem(
                      context,
                      'Status',
                      product.stockStatusDisplay,
                      _getStockStatusIcon(product),
                    ),
                  ),
                  
                  Expanded(
                    child: _buildStatItem(
                      context,
                      'Active',
                      product.isActive ? 'Yes' : 'No',
                      product.isActive ? Icons.check_circle : Icons.cancel,
                    ),
                  ),
                  
                  if (product.lastUpdated != null)
                    Expanded(
                      child: _buildStatItem(
                        context,
                        'Updated',
                        _formatLastUpdated(product.lastUpdated!),
                        Icons.schedule,
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

  Widget _buildInfoItem(BuildContext context, IconData icon, String label, String value, {Color? color}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color ?? Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                  fontSize: 11,
                ),
              ),
              Text(
                value,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStockStatusBar(BuildContext context) {
    final percentage = product.stockPercentage.clamp(0.0, 100.0);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Stock Level',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              product.stockStatusDisplay,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: product.stockStatusColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 8),
        
        Container(
          height: 8,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(4),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: percentage / 100,
            child: Container(
              decoration: BoxDecoration(
                color: product.stockStatusColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(BuildContext context, String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
            fontSize: 10,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Color _getDepartmentColor(String department) {
    switch (department.toLowerCase()) {
      case 'vegetables':
        return const Color(0xFF27AE60); // Green
      case 'fruits':
        return const Color(0xFFE74C3C); // Red
      case 'herbs & spices':
      case 'herbs':
      case 'spices':
        return const Color(0xFF2ECC71); // Light green
      case 'mushrooms':
        return const Color(0xFF8E44AD); // Purple
      case 'specialty items':
      case 'specialty':
        return const Color(0xFFF39C12); // Orange
      default:
        return const Color(0xFF34495E); // Dark gray
    }
  }

  String _getDepartmentEmoji(String department) {
    switch (department.toLowerCase()) {
      case 'vegetables':
        return '🥬';
      case 'fruits':
        return '🍎';
      case 'herbs & spices':
      case 'herbs':
      case 'spices':
        return '🌿';
      case 'mushrooms':
        return '🍄';
      case 'specialty items':
      case 'specialty':
        return '⭐';
      default:
        return '📦';
    }
  }

  IconData _getStockStatusIcon(Product product) {
    if (product.isOutOfStock) return Icons.error;
    if (product.isLowStock) return Icons.warning;
    return Icons.check_circle;
  }

  String _formatLastUpdated(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()}w ago';
    } else {
      return '${(difference.inDays / 30).floor()}m ago';
    }
  }
}


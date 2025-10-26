import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/product.dart';
import '../../../providers/products_provider.dart';
import '../../../providers/inventory_provider.dart';
import '../../../core/professional_theme.dart';

class BulkStockOperations extends ConsumerStatefulWidget {
  final List<Product> selectedProducts;
  final Function(List<Product>) onSelectionChanged;

  const BulkStockOperations({
    super.key,
    required this.selectedProducts,
    required this.onSelectionChanged,
  });

  @override
  ConsumerState<BulkStockOperations> createState() => _BulkStockOperationsState();
}

class _BulkStockOperationsState extends ConsumerState<BulkStockOperations> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final productsState = ref.watch(productsProvider);
    
    return Container(
      decoration: AppDecorations.professionalCard,
      child: Card(
        elevation: 0,
        color: Colors.transparent,
        child: ExpansionTile(
        leading: Icon(
          Icons.inventory_2,
          color: AppColors.primaryGreen,
        ),
        title: Text(
          'Bulk Stock Operations',
          style: AppTextStyles.titleMedium.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Text(
          '${widget.selectedProducts.length} products selected',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.selectedProducts.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${widget.selectedProducts.length}',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.primaryGreen,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            const SizedBox(width: 8),
            Icon(
              _isExpanded ? Icons.expand_less : Icons.expand_more,
              color: AppColors.textSecondary,
            ),
          ],
        ),
        onExpansionChanged: (expanded) {
          setState(() {
            _isExpanded = expanded;
          });
        },
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSelectionControls(productsState.products),
                const SizedBox(height: 16),
                _buildBulkOperations(),
                if (widget.selectedProducts.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildSelectedProductsList(),
                ],
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildSelectionControls(List<Product> allProducts) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Product Selection',
            style: AppTextStyles.titleSmall.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildSelectionChip(
                'Select All',
                Icons.select_all,
                () => widget.onSelectionChanged(allProducts),
              ),
              _buildSelectionChip(
                'Clear All',
                Icons.clear_all,
                () => widget.onSelectionChanged([]),
              ),
              _buildSelectionChip(
                'Low Stock',
                Icons.warning,
                () => _selectByCondition((p) => p.stockLevel <= p.minimumStock),
              ),
              _buildSelectionChip(
                'Out of Stock',
                Icons.error,
                () => _selectByCondition((p) => p.stockLevel <= 0),
              ),
              _buildSelectionChip(
                'Overstocked',
                Icons.inventory,
                () => _selectByCondition((p) => p.stockLevel > p.minimumStock * 3),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionChip(String label, IconData icon, VoidCallback onPressed) {
    return ActionChip(
      avatar: Icon(icon, size: 16, color: AppColors.primaryGreen),
      label: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.textPrimary,
        ),
      ),
      onPressed: onPressed,
      backgroundColor: AppColors.surfaceDark,
      side: BorderSide(color: AppColors.borderColor),
    );
  }

  Widget _buildBulkOperations() {
    final hasSelection = widget.selectedProducts.isNotEmpty;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bulk Operations',
            style: AppTextStyles.titleSmall.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: [
              _buildOperationButton(
                'Bulk Adjustment',
                Icons.edit,
                hasSelection ? () => _showBulkAdjustmentDialog() : null,
                AppColors.accentBlue,
              ),
              _buildOperationButton(
                'Bulk Reorder',
                Icons.shopping_cart,
                hasSelection ? () => _showBulkReorderDialog() : null,
                AppColors.accentGreen,
              ),
              _buildOperationButton(
                'Export Data',
                Icons.download,
                hasSelection ? () => _exportSelectedProducts() : null,
                AppColors.accentOrange,
              ),
              _buildOperationButton(
                'Import Data',
                Icons.upload,
                () => _showImportDialog(),
                AppColors.primaryGreen,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOperationButton(String label, IconData icon, VoidCallback? onPressed, Color color) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(
        label,
        style: AppTextStyles.labelSmall,
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: onPressed != null ? color.withValues(alpha: 0.2) : AppColors.borderColor,
        foregroundColor: onPressed != null ? color : AppColors.textMuted,
        side: BorderSide(color: onPressed != null ? color : AppColors.borderColor),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  Widget _buildSelectedProductsList() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Selected Products',
                style: AppTextStyles.titleSmall.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => widget.onSelectionChanged([]),
                child: Text(
                  'Clear All',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.accentRed,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          SizedBox(
            height: 120,
            child: ListView.builder(
              itemCount: widget.selectedProducts.length,
              itemBuilder: (context, index) {
                final product = widget.selectedProducts[index];
                return ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.primaryGreen.withValues(alpha: 0.2),
                    child: Text(
                      product.name.substring(0, 1).toUpperCase(),
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.primaryGreen,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    product.name,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Stock: ${product.stockLevel} ${product.unit}',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.remove_circle_outline, size: 16),
                    color: AppColors.accentRed,
                    onPressed: () {
                      final newSelection = List<Product>.from(widget.selectedProducts);
                      newSelection.removeAt(index);
                      widget.onSelectionChanged(newSelection);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _selectByCondition(bool Function(Product) condition) {
    final allProducts = ref.read(productsProvider).products;
    final filteredProducts = allProducts.where(condition).toList();
    widget.onSelectionChanged(filteredProducts);
  }

  void _showBulkAdjustmentDialog() {
    final adjustmentController = TextEditingController();
    String adjustmentType = 'add'; // 'add', 'subtract', 'set'
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Bulk Stock Adjustment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Adjusting ${widget.selectedProducts.length} products'),
              const SizedBox(height: 16),
              
              DropdownButtonFormField<String>(
                value: adjustmentType,
                decoration: const InputDecoration(
                  labelText: 'Adjustment Type',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'add', child: Text('Add to current stock')),
                  DropdownMenuItem(value: 'subtract', child: Text('Subtract from current stock')),
                  DropdownMenuItem(value: 'set', child: Text('Set absolute value')),
                ],
                onChanged: (value) {
                  setState(() {
                    adjustmentType = value!;
                  });
                },
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: adjustmentController,
                decoration: const InputDecoration(
                  labelText: 'Quantity',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                _performBulkAdjustment(adjustmentType, adjustmentController.text);
                Navigator.of(context).pop();
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  void _showBulkReorderDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bulk Reorder'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Create reorder requests for ${widget.selectedProducts.length} products'),
            const SizedBox(height: 16),
            
            ...widget.selectedProducts.map((product) => ListTile(
              dense: true,
              title: Text(product.name),
              subtitle: Text('Current: ${product.stockLevel}, Min: ${product.minimumStock}'),
              trailing: Text('Need: ${(product.minimumStock * 2 - product.stockLevel).clamp(0, double.infinity).toStringAsFixed(0)}'),
            )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _performBulkReorder();
              Navigator.of(context).pop();
            },
            child: const Text('Create Reorders'),
          ),
        ],
      ),
    );
  }

  void _showImportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import Stock Data'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Import stock levels from CSV file'),
            SizedBox(height: 16),
            Text('Expected format: Product Name, Stock Level, Unit'),
            SizedBox(height: 8),
            Text('Example: Tomatoes, 50, kg'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _performImport();
              Navigator.of(context).pop();
            },
            child: const Text('Select File'),
          ),
        ],
      ),
    );
  }

  void _performBulkAdjustment(String type, String quantityStr) {
    final quantity = double.tryParse(quantityStr);
    if (quantity == null) {
      _showErrorSnackBar('Invalid quantity entered');
      return;
    }

    // TODO: Implement actual bulk adjustment API calls
    for (final product in widget.selectedProducts) {
      double newStock;
      switch (type) {
        case 'add':
          newStock = product.stockLevel + quantity;
          break;
        case 'subtract':
          newStock = (product.stockLevel - quantity).clamp(0, double.infinity);
          break;
        case 'set':
          newStock = quantity;
          break;
        default:
          continue;
      }
      
      // Update inventory via provider
      ref.read(inventoryProvider.notifier).updateProductStock(
        product.id,
        newStock,
        'Bulk adjustment: $type $quantity',
      );
    }

    _showSuccessSnackBar('Bulk adjustment applied to ${widget.selectedProducts.length} products');
  }

  void _performBulkReorder() {
    // TODO: Implement actual bulk reorder functionality
    _showSuccessSnackBar('Reorder requests created for ${widget.selectedProducts.length} products');
  }

  void _exportSelectedProducts() {
    // TODO: Implement actual export functionality
    // final csvData = widget.selectedProducts.map((product) => 
    //   '${product.name},${product.stockLevel},${product.unit},${product.price}'
    // ).join('\n');
    
    _showSuccessSnackBar('Exported ${widget.selectedProducts.length} products to CSV');
  }

  void _performImport() {
    // TODO: Implement actual file picker and import functionality
    _showSuccessSnackBar('Import functionality will be implemented');
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.accentGreen,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.accentRed,
      ),
    );
  }
}

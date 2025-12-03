import 'package:flutter/material.dart';
import '../../../models/order.dart';
import '../../../core/professional_theme.dart';

class OrderItemsList extends StatelessWidget {
  final List<OrderItem> items;
  final Function(OrderItem) onRemoveItem;
  final Function(OrderItem, double) onUpdateQuantity;
  final Function(OrderItem)? onEditItem;

  const OrderItemsList({
    super.key,
    required this.items,
    required this.onRemoveItem,
    required this.onUpdateQuantity,
    this.onEditItem,
  });

  /// Format quantity to show up to 2 decimal places, removing trailing zeros
  /// Examples: 1.0 → "1", 0.75 → "0.75", 1.5 → "1.5"
  static String formatQuantity(double quantity) {
    if (quantity == quantity.toInt()) {
      return quantity.toInt().toString();
    }
    // Format to 2 decimal places and remove trailing zeros
    final formatted = quantity.toStringAsFixed(2);
    if (formatted.endsWith('.00')) {
      return quantity.toInt().toString();
    } else if (formatted.endsWith('0')) {
      return formatted.substring(0, formatted.length - 1);
    }
    return formatted;
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: AppDecorations.professionalCard,
        child: Column(
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 48,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 16),
            Text(
              'No items added yet',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Select products above to add them to this order',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: AppDecorations.professionalCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Order Items (${items.length})',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Total: R${_calculateTotal().toStringAsFixed(2)}',
                  style: TextStyle(
                    color: AppColors.primaryGreen,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: AppColors.borderColor, height: 1),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (context, index) => const Divider(
              color: AppColors.borderColor,
              height: 1,
            ),
            itemBuilder: (context, index) {
              final item = items[index];
              return _buildOrderItem(context, item);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItem(BuildContext context, OrderItem item) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Product Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.name,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'R${item.price.toStringAsFixed(2)} per ${item.unit}',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                if (item.notes != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Note: ${item.notes}',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                // Source product info if available
                if (item.sourceProductName != null && item.sourceQuantity != null) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.orange[200]!),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.link,
                          size: 12,
                          color: Colors.orange[700],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Stock Reserved from: ${item.sourceProductName} (${item.sourceQuantity}${item.sourceProductUnit ?? ''})',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.orange[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                // Stock reservation status
                if (item.hasStockReservation && item.sourceProductName == null) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.stockStatusDisplay,
                    style: TextStyle(
                      color: item.isStockReserved 
                          ? AppColors.primaryGreen
                          : item.isStockReservationFailed 
                              ? AppColors.accentRed
                              : AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          // Quantity Controls
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.borderColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () {
                    if (item.quantity > 1) {
                      onUpdateQuantity(item, item.quantity - 1);
                    }
                  },
                  icon: Icon(
                    Icons.remove,
                    color: item.quantity > 1 
                        ? AppColors.textPrimary 
                        : AppColors.textMuted,
                    size: 16,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    formatQuantity(item.quantity),
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    // Allow quantity increase (stock validation handled at product selection)
                    onUpdateQuantity(item, item.quantity + 1);
                  },
                  icon: Icon(
                    Icons.add,
                    color: AppColors.textPrimary,
                    size: 16,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(width: 16),
          
          // Total Price
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'R${item.totalPrice.toStringAsFixed(2)}',
                style: TextStyle(
                  color: AppColors.primaryGreen,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${formatQuantity(item.quantity)} ${item.unit}',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          
          const SizedBox(width: 8),
          
          // Edit Button (if callback provided)
          if (onEditItem != null)
            IconButton(
              onPressed: () => onEditItem!(item),
              icon: Icon(
                Icons.edit,
                color: AppColors.primaryGreen,
                size: 20,
              ),
              tooltip: 'Edit item',
            ),
          
          // Remove Button
          IconButton(
            onPressed: () => onRemoveItem(item),
            icon: Icon(
              Icons.delete_outline,
              color: AppColors.accentRed,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  double _calculateTotal() {
    return items.fold(0.0, (total, item) => total + item.totalPrice);
  }
}

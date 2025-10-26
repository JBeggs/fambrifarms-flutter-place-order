import 'package:flutter/material.dart';
import '../../../models/order.dart';
import '../../../core/professional_theme.dart';

class OrderItemsList extends StatelessWidget {
  final List<OrderItem> items;
  final Function(OrderItem) onRemoveItem;
  final Function(OrderItem, double) onUpdateQuantity;

  const OrderItemsList({
    super.key,
    required this.items,
    required this.onRemoveItem,
    required this.onUpdateQuantity,
  });

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
                // Stock reservation status
                if (item.hasStockReservation) ...[
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
                    item.quantity.toStringAsFixed(item.quantity == item.quantity.toInt() ? 0 : 1),
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
                '${item.quantity.toStringAsFixed(item.quantity == item.quantity.toInt() ? 0 : 1)} ${item.unit}',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          
          const SizedBox(width: 8),
          
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

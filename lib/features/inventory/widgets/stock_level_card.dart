import 'package:flutter/material.dart';

class StockLevelCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback? onAdjustStock;

  const StockLevelCard({
    super.key,
    required this.item,
    this.onAdjustStock,
  });

  @override
  Widget build(BuildContext context) {
    final productName = item['product_name']?.toString() ?? 'Unknown Product';
    final currentStock = item['current_stock'] as num? ?? 0;
    final minimumStock = item['minimum_stock'] as num? ?? 0;
    final unit = item['unit']?.toString() ?? 'units';
    final unitPrice = item['unit_price'] as num? ?? 0;
    final totalValue = currentStock * unitPrice;
    
    final isLowStock = currentStock <= minimumStock;
    final isOutOfStock = currentStock <= 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        productName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (item['sku'] != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'SKU: ${item['sku']}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                _buildStockStatus(isOutOfStock, isLowStock),
              ],
            ),
            const SizedBox(height: 12),
            
            Row(
              children: [
                Expanded(
                  child: _buildStockInfo('Current Stock', '$currentStock $unit'),
                ),
                Expanded(
                  child: _buildStockInfo('Min Stock', '$minimumStock $unit'),
                ),
                Expanded(
                  child: _buildStockInfo('Unit Price', 'R${unitPrice.toStringAsFixed(2)}'),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            Row(
              children: [
                Expanded(
                  child: _buildStockInfo('Total Value', 'R${totalValue.toStringAsFixed(2)}'),
                ),
                if (onAdjustStock != null) ...[
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: onAdjustStock,
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Adjust'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ],
            ),
            
            // Stock Level Progress Bar
            const SizedBox(height: 12),
            _buildStockProgressBar(currentStock, minimumStock, isLowStock, isOutOfStock),
          ],
        ),
      ),
    );
  }

  Widget _buildStockStatus(bool isOutOfStock, bool isLowStock) {
    if (isOutOfStock) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'OUT OF STOCK',
          style: TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    } else if (isLowStock) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.orange,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'LOW STOCK',
          style: TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.green,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'IN STOCK',
          style: TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
  }

  Widget _buildStockInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildStockProgressBar(num currentStock, num minimumStock, bool isLowStock, bool isOutOfStock) {
    final maxStock = minimumStock * 3; // Assume good stock is 3x minimum
    final progress = maxStock > 0 ? (currentStock / maxStock).clamp(0.0, 1.0) : 0.0;
    
    Color progressColor;
    if (isOutOfStock) {
      progressColor = Colors.red;
    } else if (isLowStock) {
      progressColor = Colors.orange;
    } else {
      progressColor = Colors.green;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Stock Level',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            Text(
              '${(progress * 100).toInt()}%',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation<Color>(progressColor),
        ),
      ],
    );
  }
}

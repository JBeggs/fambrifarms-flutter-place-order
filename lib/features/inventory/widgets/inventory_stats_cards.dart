import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/inventory_provider.dart';

class InventoryStatsCards extends ConsumerWidget {
  const InventoryStatsCards({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inventoryState = ref.watch(inventoryProvider);
    final inventoryNotifier = ref.read(inventoryProvider.notifier);

    final totalItems = inventoryState.products.length;
    final lowStockItems = inventoryNotifier.getLowStockItems().length;
    final outOfStockItems = inventoryNotifier.getOutOfStockItems().length;
    final totalAlerts = inventoryNotifier.getTotalAlerts();
    final totalValue = inventoryNotifier.getTotalInventoryValue();

    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'Total Items',
              totalItems.toString(),
              Icons.inventory,
              Colors.blue,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildStatCard(
              'Low Stock',
              lowStockItems.toString(),
              Icons.warning,
              Colors.orange,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildStatCard(
              'Out of Stock',
              outOfStockItems.toString(),
              Icons.error,
              Colors.red,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildStatCard(
              'Active Alerts',
              totalAlerts.toString(),
              Icons.notifications,
              Colors.purple,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildStatCard(
              'Total Value',
              'R${totalValue.toStringAsFixed(0)}',
              Icons.attach_money,
              Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

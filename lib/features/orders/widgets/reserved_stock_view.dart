import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../../models/order.dart';
import '../../../models/product.dart' as product_model;
import '../../../providers/orders_provider.dart';
import '../../../providers/inventory_provider.dart';
import '../../../providers/products_provider.dart';

class ReservedStockView extends ConsumerStatefulWidget {
  const ReservedStockView({super.key});

  @override
  ConsumerState<ReservedStockView> createState() => _ReservedStockViewState();
}

class _ReservedStockViewState extends ConsumerState<ReservedStockView> {
  String _searchQuery = '';

  Map<String, Map<String, dynamic>> get reservedStockData {
    final orders = ref.watch(ordersProvider).orders;
    final products = ref.watch(productsProvider).products;
    final inventory = ref.watch(inventoryProvider).products;
    
    final reservedStock = <String, Map<String, dynamic>>{};
    
    // Calculate reserved stock from active orders (not delivered or cancelled)
    for (final order in orders) {
      // Count all orders that aren't delivered or cancelled as having reserved stock
      if (order.status != 'delivered' && order.status != 'cancelled') {
        for (final item in order.items) {
          final productName = item.product.name;
          
          if (!reservedStock.containsKey(productName)) {
            // Find the product details
            final productDetails = products.where((p) => p.name == productName).firstOrNull;
            final inventoryItem = inventory.where((p) => p.name == productName).firstOrNull;
            
            reservedStock[productName] = {
              'product': productDetails ?? item.product,
              'reservedQuantity': 0.0,
              'currentStock': inventoryItem?.stockLevel ?? 0.0,
              'unit': item.product.unit,
              'orders': <Map<String, dynamic>>[],
            };
          }
          
          reservedStock[productName]!['reservedQuantity'] += item.quantity;
          reservedStock[productName]!['orders'].add({
            'orderNumber': order.orderNumber,
            'restaurant': order.restaurant.displayName,
            'quantity': item.quantity,
            'status': order.status,
          });
        }
      }
    }
    
    return reservedStock;
  }

  List<MapEntry<String, Map<String, dynamic>>> get filteredReservedStock {
    final data = reservedStockData;
    
    if (_searchQuery.isEmpty) {
      return data.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    }
    
    return data.entries
        .where((entry) => entry.key.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));
  }

  @override
  Widget build(BuildContext context) {
    final ordersState = ref.watch(ordersProvider);
    final productsState = ref.watch(productsProvider);
    final inventoryState = ref.watch(inventoryProvider);
    
    final isLoading = ordersState.isLoading || 
                     productsState.isLoading || 
                     inventoryState.isLoading;
    
    return Column(
      children: [
        // Search Bar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search reserved stock...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.share),
                    onPressed: _shareReservedStockReport,
                    tooltip: 'Share Report',
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                style: const TextStyle(fontSize: 16),
              ),
              
              const SizedBox(height: 12),
              
              // Summary Stats
              _buildSummaryStats(),
            ],
          ),
        ),
        
        // Reserved Stock List
        Expanded(
          child: isLoading
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Loading reserved stock...'),
                    ],
                  ),
                )
              : filteredReservedStock.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 64,
                            color: Colors.grey[300],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No reserved stock',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _searchQuery.isNotEmpty 
                              ? 'No products match your search'
                              : 'No pending orders with stock reservations',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredReservedStock.length,
                      itemBuilder: (context, index) {
                        final entry = filteredReservedStock[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildReservedStockCard(
                            entry.key, 
                            entry.value,
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildSummaryStats() {
    final reservedStock = reservedStockData;
    final totalProducts = reservedStock.length;
    final totalReserved = reservedStock.values
        .fold<double>(0, (sum, item) => sum + (item['reservedQuantity'] as double));
    final productsWithIssues = reservedStock.values
        .where((item) => (item['reservedQuantity'] as double) > (item['currentStock'] as double))
        .length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[50]!, Colors.blue[100]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem(
              icon: Icons.inventory_2,
              label: 'Products',
              value: '$totalProducts',
              color: Colors.blue,
            ),
          ),
          Container(
            height: 40,
            width: 1,
            color: Colors.blue[300],
          ),
          Expanded(
            child: _buildStatItem(
              icon: Icons.shopping_cart,
              label: 'Reserved',
              value: totalReserved.toStringAsFixed(0),
              color: Colors.green,
            ),
          ),
          Container(
            height: 40,
            width: 1,
            color: Colors.blue[300],
          ),
          Expanded(
            child: _buildStatItem(
              icon: Icons.warning,
              label: 'Issues',
              value: '$productsWithIssues',
              color: Colors.orange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(
          icon,
          color: color,
          size: 24,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildReservedStockCard(String productName, Map<String, dynamic> data) {
    final product = data['product'] as product_model.Product;
    final reservedQuantity = data['reservedQuantity'] as double;
    final currentStock = data['currentStock'] as double;
    final unit = data['unit'] as String;
    final orders = data['orders'] as List<Map<String, dynamic>>;
    
    final hasStockIssue = reservedQuantity > currentStock;
    final availableAfterReservation = currentStock - reservedQuantity;

    return Material(
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => _showReservedStockDetails(productName, data),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasStockIssue 
                ? Colors.red.withOpacity(0.3)
                : Colors.grey.withOpacity(0.2),
              width: hasStockIssue ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Header
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          productName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          product.department ?? 'Unknown Department',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (hasStockIssue)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red[200]!),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.warning,
                            color: Colors.red[700],
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Shortage',
                            style: TextStyle(
                              color: Colors.red[700],
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 16),

              // Stock Information
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _buildStockInfoRow(
                      'Current Stock',
                      '${currentStock.toStringAsFixed(1)} $unit',
                      Colors.blue,
                      Icons.inventory,
                    ),
                    const SizedBox(height: 8),
                    _buildStockInfoRow(
                      'Reserved for Orders',
                      '${reservedQuantity.toStringAsFixed(1)} $unit',
                      Colors.orange,
                      Icons.shopping_cart,
                    ),
                    const SizedBox(height: 8),
                    Divider(color: Colors.grey[300]),
                    const SizedBox(height: 8),
                    _buildStockInfoRow(
                      'Available After Reservation',
                      '${availableAfterReservation.toStringAsFixed(1)} $unit',
                      hasStockIssue ? Colors.red : Colors.green,
                      hasStockIssue ? Icons.error : Icons.check_circle,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Orders Summary
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.receipt_long,
                      color: Colors.blue[700],
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${orders.length} pending order${orders.length != 1 ? 's' : ''}',
                        style: TextStyle(
                          color: Colors.blue[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.blue[400],
                      size: 16,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStockInfoRow(String label, String value, Color color, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          color: color,
          size: 18,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  void _showReservedStockDetails(String productName, Map<String, dynamic> data) {
    final orders = data['orders'] as List<Map<String, dynamic>>;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  height: 4,
                  width: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    productName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                
                const SizedBox(height: 8),
                
                Text(
                  'Reserved in ${orders.length} order${orders.length != 1 ? 's' : ''}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Orders list
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: orders.length,
                    itemBuilder: (context, index) {
                      final order = orders[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    order['orderNumber'],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    order['restaurant'],
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${order['quantity']} ${data['unit']}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(order['status']).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    order['status'].toString().toUpperCase(),
                                    style: TextStyle(
                                      color: _getStatusColor(order['status']),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'processing':
        return Colors.blue;
      case 'fulfilled':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _shareReservedStockReport() {
    final reservedStock = reservedStockData;
    final report = StringBuffer();
    
    report.writeln('RESERVED STOCK REPORT');
    report.writeln('Generated: ${DateTime.now().toString().split('.')[0]}');
    report.writeln('');
    
    if (reservedStock.isEmpty) {
      report.writeln('No reserved stock found.');
    } else {
      report.writeln('Products with Reserved Stock:');
      report.writeln('');
      
      for (final entry in reservedStock.entries) {
        final productName = entry.key;
        final data = entry.value;
        final reservedQuantity = data['reservedQuantity'] as double;
        final currentStock = data['currentStock'] as double;
        final unit = data['unit'] as String;
        final orders = data['orders'] as List<Map<String, dynamic>>;
        
        report.writeln('$productName:');
        report.writeln('  Current Stock: ${currentStock.toStringAsFixed(1)} $unit');
        report.writeln('  Reserved: ${reservedQuantity.toStringAsFixed(1)} $unit');
        report.writeln('  Available: ${(currentStock - reservedQuantity).toStringAsFixed(1)} $unit');
        report.writeln('  Orders: ${orders.length}');
        
        for (final order in orders) {
          report.writeln('    - ${order['orderNumber']}: ${order['quantity']} $unit (${order['restaurant']})');
        }
        
        report.writeln('');
      }
    }
    
    Share.share(
      report.toString(),
      subject: 'Reserved Stock Report - ${DateTime.now().toString().split(' ')[0]}',
    );
  }
}

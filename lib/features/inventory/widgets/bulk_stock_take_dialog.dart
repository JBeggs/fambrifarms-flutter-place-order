import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/product.dart';
import '../../../providers/inventory_provider.dart';
import '../../../services/api_service.dart';

class BulkStockTakeDialog extends ConsumerStatefulWidget {
  final List<Product> products;

  const BulkStockTakeDialog({
    super.key,
    required this.products,
  });

  @override
  ConsumerState<BulkStockTakeDialog> createState() => _BulkStockTakeDialogState();
}

class _BulkStockTakeDialogState extends ConsumerState<BulkStockTakeDialog> {
  final Map<int, TextEditingController> _controllers = {};
  final Map<int, int> _originalStock = {};
  bool _isLoading = false;
  String _searchQuery = '';
  List<Map<String, dynamic>> _stockHistory = [];
  bool _showHistory = false;

  @override
  void initState() {
    super.initState();
    for (final product in widget.products) {
      _controllers[product.id] = TextEditingController();
      _originalStock[product.id] = product.stockLevel.toInt();
      _controllers[product.id]!.text = product.stockLevel.toInt().toString();
    }
    _loadStockHistory();
  }

  Future<void> _loadStockHistory() async {
    try {
      final apiService = ref.read(apiServiceProvider);
      final result = await apiService.getStockUpdateHistory();
      
      if (result['status'] == 'success') {
        setState(() {
          _stockHistory = List<Map<String, dynamic>>.from(result['history'] ?? []);
        });
      }
    } catch (e) {
      // Silently fail - history is optional
      print('Failed to load stock history: $e');
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  List<Product> get _filteredProducts {
    if (_searchQuery.isEmpty) return widget.products;
    
    return widget.products.where((product) {
      final name = product.name.toLowerCase();
      final sku = product.sku?.toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || sku.contains(query);
    }).toList();
  }

  Future<void> _submitBulkStockTake() async {
    setState(() => _isLoading = true);

    try {
      final entries = <Map<String, dynamic>>[];
      
      for (final product in widget.products) {
        final controller = _controllers[product.id]!;
        if (controller.text.isNotEmpty) {
          final countedQuantity = int.tryParse(controller.text) ?? 0;
          final currentStock = _originalStock[product.id] ?? 0;
          
          // Only add if there's an actual change in stock
          if (countedQuantity != currentStock) {
            entries.add({
              'product_id': product.id,
              'counted_quantity': countedQuantity,
              'current_stock': currentStock,
            });
          }
        }
      }

      if (entries.isEmpty) {
        throw Exception('No stock entries to process');
      }

      // Submit stock take and wait for completion
      await ref.read(inventoryProvider.notifier).bulkStockTake(entries);
      
      // Force refresh inventory data
      await ref.read(inventoryProvider.notifier).refreshAll();
      
      // Force UI refresh
      ref.read(inventoryProvider.notifier).forceRefresh();

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bulk stock take completed for ${entries.length} products'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _fillWithCurrentStock() {
    for (final product in widget.products) {
      _controllers[product.id]!.text = product.stockLevel.toString();
    }
    setState(() {});
  }

  void _clearAllEntries() {
    for (final controller in _controllers.values) {
      controller.clear();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final filteredProducts = _filteredProducts;
    
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.95,
        height: MediaQuery.of(context).size.height * 0.9,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.inventory, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Bulk Stock Take',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _showHistory = !_showHistory;
                    });
                  },
                  icon: Icon(_showHistory ? Icons.history_toggle_off : Icons.history),
                  tooltip: _showHistory ? 'Hide WhatsApp History' : 'Show WhatsApp History',
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const Divider(),

            // WhatsApp Stock History (if shown)
            if (_showHistory) ...[
              Container(
                height: 200,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(8),
                          topRight: Radius.circular(8),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.message, color: Colors.blue[700], size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'Recent WhatsApp Stock Updates',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Colors.blue[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _stockHistory.isEmpty
                          ? const Center(
                              child: Text(
                                'No recent stock updates found',
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _stockHistory.length,
                              itemBuilder: (context, index) {
                                final update = _stockHistory[index];
                                final timestamp = DateTime.parse(update['timestamp']);
                                return ListTile(
                                  dense: true,
                                  leading: CircleAvatar(
                                    radius: 12,
                                    backgroundColor: Colors.green[100],
                                    child: Text(
                                      '${update['items_count']}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.green[700],
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    '${update['sender_name']} - ${update['order_day']}',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                  ),
                                  subtitle: Text(
                                    '${timestamp.day}/${timestamp.month}/${timestamp.year} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')} - ${update['items_count']} items',
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                  trailing: update['processed']
                                      ? Icon(Icons.check_circle, color: Colors.green[600], size: 16)
                                      : Icon(Icons.pending, color: Colors.orange[600], size: 16),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ],

            // Search and Actions
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search products...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setState(() => _searchQuery = value);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) {
                    switch (value) {
                      case 'fill_current':
                        _fillWithCurrentStock();
                        break;
                      case 'clear_all':
                        _clearAllEntries();
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'fill_current',
                      child: Row(
                        children: [
                          Icon(Icons.content_copy),
                          SizedBox(width: 8),
                          Text('Fill with Current Stock'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'clear_all',
                      child: Row(
                        children: [
                          Icon(Icons.clear_all),
                          SizedBox(width: 8),
                          Text('Clear All'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Products List
            Expanded(
              child: ListView.builder(
                itemCount: filteredProducts.length,
                itemBuilder: (context, index) {
                  final product = filteredProducts[index];
                  final controller = _controllers[product.id]!;
                  final originalStock = _originalStock[product.id] ?? 0;
                  
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          // Product Info
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  product.name,
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                                if (product.sku != null)
                                  Text(
                                    'SKU: ${product.sku}',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                Text(
                                  'Current: $originalStock ${product.unit}',
                                  style: TextStyle(
                                    color: Colors.blue[700],
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  'From SHALLOME stock updates',
                                  style: TextStyle(
                                    color: Colors.green[600],
                                    fontSize: 10,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          // Stock Entry Field
                          Expanded(
                            child: TextFormField(
                              controller: controller,
                              decoration: InputDecoration(
                                labelText: 'Counted',
                                border: const OutlineInputBorder(),
                                suffixText: product.unit,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                              ],
                              onChanged: (value) {
                                setState(() {}); // Trigger rebuild for difference calculation
                              },
                            ),
                          ),
                          
                          // Difference Indicator
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 60,
                            child: Builder(
                              builder: (context) {
                                final countedText = controller.text;
                                if (countedText.isEmpty) return const SizedBox();
                                
                                final counted = int.tryParse(countedText) ?? 0;
                                final difference = counted - originalStock;
                                
                                if (difference == 0) {
                                  return const Icon(Icons.check, color: Colors.green, size: 20);
                                }
                                
                                return Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      difference > 0 ? Icons.arrow_upward : Icons.arrow_downward,
                                      color: difference > 0 ? Colors.green : Colors.red,
                                      size: 16,
                                    ),
                                    Text(
                                      difference.abs().toString(),
                                      style: TextStyle(
                                        color: difference > 0 ? Colors.green : Colors.red,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Summary and Actions
            const Divider(),
            Row(
              children: [
                Text(
                  '${filteredProducts.length} products',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isLoading ? null : _submitBulkStockTake,
                  child: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Complete Stock Take'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
